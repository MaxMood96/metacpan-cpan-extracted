package Sim::Agent::Runner;

use strict;
use warnings;

use Sim::Agent::Engine;
use Sim::Agent::Hook;
use Sim::Agent::LLM::Ollama;

sub new 
{
    my ($class, %opts) = @_;

    die "graph required"   unless $opts{graph};
    die "journal required" unless $opts{journal};

    my $self = 
    {
        graph   => $opts{graph},
        journal => $opts{journal},
        dev     => $opts{dev} || 0,
        state   => {},
    };

    bless $self, $class;
    return $self;
}

sub run 
{
    my ($self) = @_;

    $self->_initialize_state;
    $self->_main_loop;
}

sub _initialize_state 
{
    my ($self) = @_;

    $self->{state} = 
    {
	  queue => [],
	  completed => {},
	  pending_inputs => {},
	  iteration_count => 0,
	  active => {},
	  call_count => {},
	  pingpong => {},
    };

    push @{ $self->{state}->{queue} }, $self->{graph}->{entry};

    $self->{journal}->log("[START] entry=$self->{graph}->{entry}");
}

sub _main_loop 
{
    my ($self) = @_;

    my $graph = $self->{graph};
    my $state = $self->{state};

    while (@{ $state->{queue} }) 
    {

        $state->{iteration_count}++;

        if ($state->{iteration_count} > $graph->{limits}->{max_iterations}) 
        {
            $self->{journal}->log("[ABORT] max_iterations reached");
            last;
        }

        my $agent_name = shift @{ $state->{queue} };

        next if $state->{active}->{$agent_name};

        my $agent = $graph->{agents}->{$agent_name}
            or die "Unknown agent: $agent_name";

        $self->{journal}->log("[ACTIVATE] $agent_name");

        unless (Sim::Agent::Engine::dependencies_satisfied($agent, $state)) 
        {
            push @{ $state->{queue} }, $agent_name;
            next;
        }

        $state->{active}->{$agent_name} = 1;

        my $result;

        if ($agent->{role} eq 'worker') 
        {
            $result = $self->_run_worker($agent);
        }
        elsif ($agent->{role} eq 'critic') 
        {
            $result = $self->_run_critic($agent);
        }
        elsif ($agent->{role} eq 'chief') 
        {
            $result = $self->_run_critic($agent);  # chief behaves like critic
        }
        else 
        {
            die "Unknown role: $agent->{role}";
        }

        delete $state->{active}->{$agent_name};

        $state->{completed}->{$agent_name} = $result;

        if ($agent->{role} eq 'chief' && $result->{status} eq 'stop') 
        {
            $self->{journal}->log("[STOP] chief terminated execution");
            last;
        }

        $self->_route_result($agent, $result);
    }

    $self->{journal}->log("[END]");
}


sub _run_worker {
    my ($self, $agent) = @_;

    my $graph = $self->{graph};
    my $state = $self->{state};
    my $name  = $agent->{name};

    my $inputs = delete $state->{pending_inputs}->{$name} || {};

    $self->{journal}->log("[WORKER] $name");

    # Initial generation (this should call prompt hook + LLM)
    my $output = $self->_call_prompt($agent, $inputs);

    my $cycles     = 0;
    my $max_cycles = $graph->{limits}->{max_self_cycles};
    $max_cycles = 0 unless defined $max_cycles;

    my $tainted      = 0;
    my $taint_reason = undef;

    my $prev_output = undef;

    # Self-reflection loop (bounded)
    while ($max_cycles > 0) 
    {

        my $crit = $self->_call_selfcrit($agent, $output);

        die "Self-critic hook must return a hashref"
            unless ref($crit) eq 'HASH';

        my $st = $crit->{status} // die "Self-critic hook must return { status => ... }";

        if ($st eq 'ok') 
        {
            last;
        }
        elsif ($st eq 'revise') 
        {

            $cycles++;
            if ($cycles >= $max_cycles) 
            {
                $tainted = 1;
                $taint_reason = 'max_self_cycles';
                last;
            }

            my $revised = $self->_call_revision($agent, $output, $crit);

            die "Revision hook must return a scalar string"
                if ref($revised);

            if (defined $prev_output && defined $revised && $revised eq $prev_output) 
            {
                $tainted = 1;
                $taint_reason = 'stagnation';
                last;
            }

            $prev_output = $output;
            $output = $revised;
            next;
        }
        else 
        {
            die "Self-critic status must be 'ok' or 'revise' (got '$st')";
        }
    }

    my %meta = ( cycles => $cycles );
    if ($tainted) 
    {
        $meta{taint_reason} = $taint_reason || 'unknown';
    }

    return 
    {
        agent   => $name,
        status  => 'ok',
        output  => $output,
        tainted => $tainted ? 1 : 0,
        meta    => \%meta,
    };
}


sub _run_critic 
{
    my ($self, $agent) = @_;

    my $graph = $self->{graph};
    my $state = $self->{state};
    my $name  = $agent->{name};

    my $inputs = delete $state->{pending_inputs}->{$name} || {};

    my @senders = keys %$inputs;
    die "Critic $name activated with no inputs"
        unless @senders;

    die "Critic $name expects exactly one input, got: " . join(",", @senders)
        unless @senders == 1;

    my $sender = $senders[0];
    my $packet = $inputs->{$sender};

    my $parse = $self->_call_critic_parse($agent, $packet);

    die "Critic parse hook must return a hashref"
        unless ref($parse) eq 'HASH';

    my $status = $parse->{status} // die "Critic parse hook must return { status => ... }";

    # ------------------------------------------------------------
    # Ping-pong limiter: after N consecutive FAILs for (sender->critic),
    # force OK and continue downstream with taint.
    # ------------------------------------------------------------
    my $max_pp = $graph->{limits}->{max_pingpong};
    $max_pp = 0 unless defined $max_pp;

    my $pp_key = "$sender->$name";
    my $forced_ok = 0;

    if ($status eq 'ok') {
        delete $state->{pingpong}->{$pp_key};
    }
    elsif ($status eq 'fail' && $max_pp > 0) 
    {

        $state->{pingpong}->{$pp_key}++;
        my $n = $state->{pingpong}->{$pp_key};

        if ($n >= $max_pp) {
            $forced_ok = 1;
            $status = 'ok';
            delete $state->{pingpong}->{$pp_key};

            $self->{journal}->log("[FORCE-OK] $name accepted $sender after $max_pp fails");
        }
    }
    elsif ($status eq 'stop') 
    {
        # Chief can return stop. No pingpong logic applies.
    }
    else 
    {
        die "Critic status must be 'ok', 'fail', or 'stop' (got '$status')";
    }

    # ------------------------------------------------------------
    # Pass-through payload on OK (and forced OK):
    # - output is original sender output
    # - source aliases downstream key to original sender (crucial for wait-for joins)
    # On FAIL:
    # - no source alias (downstream sees key CriticName)
    # - output is still pass-through (useful), critique goes in meta
    # ------------------------------------------------------------

    my $source = ($status eq 'ok') ? $sender : undef;

    my %meta = (
        reviewed => $sender,
    );

    $meta{critique} = $parse->{critique} if exists $parse->{critique};
    if ($forced_ok) 
    {
        $meta{forced_ok} = 1;
        $meta{pingpong_fails} = $max_pp;
    }

    my $tainted = ($packet->{tainted} ? 1 : 0);
    $tainted = 1 if $forced_ok;

    return 
    {
        agent   => $name,
        source  => $source,                 # used by routing key alias
        status  => $status,                 # ok|fail|stop
        output  => $packet->{output},        # pass-through payload
        tainted => $tainted,
        meta    => \%meta,
    };
}


sub _route_result 
{
    my ($self, $agent, $result) = @_;

    my $state = $self->{state};
    my $graph = $self->{graph};

    my @targets;

    if ($agent->{role} eq 'worker') 
    {
        push @targets, $agent->{send_to};
    }
    elsif ($agent->{role} eq 'critic' || $agent->{role} eq 'chief') {

        if ($result->{status} eq 'ok') 
        {
            @targets = @{ $agent->{on_ok} };
        } 
        else 
        {
            @targets = @{ $agent->{on_fail} };
        }
    }

    for my $target (@targets) {

        $self->{journal}->log("[ROUTE] $agent->{name} -> $target");

        my $key = $result->{source} // $agent->{name};
        $state->{pending_inputs}->{$target}->{$key} = $result;

        unless (Sim::Agent::Engine::is_enqueued_or_active($state, $target)) 
        {
            if (Sim::Agent::Engine::dependencies_satisfied($graph->{agents}->{$target}, $state)) 
            {
                push @{ $state->{queue} }, $target;
            }
        }
    }
}


sub _call_prompt {
    my ($self, $agent, $inputs) = @_;

    my $hook = Sim::Agent::Hook::load($agent->{prompt_file});
    my $prompt = Sim::Agent::Hook::invoke($hook, { inputs => $inputs }, $agent, $self);

    $self->{state}->{call_count}->{ $agent->{name} }++;
    my $call_id = $self->{state}->{call_count}->{ $agent->{name} };

    my $agent_dir = $self->{journal}->agent_dir($agent->{name});

    return Sim::Agent::LLM::Ollama::call_model(
        model     => $agent->{model},
        prompt    => $prompt,
        agent_dir => $agent_dir,
        call_id   => $call_id,
    );
}

sub _call_prompt_DELETED 
{
    my ($self, $agent, $inputs) = @_;

    my $hook = Sim::Agent::Hook::load($agent->{prompt_file});
    my $prompt = Sim::Agent::Hook::invoke($hook, { inputs => $inputs }, $agent, $self);

    $self->{state}->{call_count}->{ $agent->{name} }++;
    my $call_id = $self->{state}->{call_count}->{ $agent->{name} };

    return $prompt;
}

sub _call_selfcrit 
{
    my ($self, $agent, $output) = @_;

    my $hook = Sim::Agent::Hook::load($agent->{selfcrit_file});
    return Sim::Agent::Hook::invoke($hook, { current_output => $output }, $agent, $self);
}

sub _call_revision 
{
    my ($self, $agent, $output, $crit) = @_;

    my $hook = Sim::Agent::Hook::load($agent->{revision_file});
    return Sim::Agent::Hook::invoke($hook, 
    {
        current_output => $output,
        critique       => $crit->{critique},
    }, $agent, $self);
}

sub _call_critic_parse 
{
    my ($self, $agent, $packet) = @_;

    my $hook = Sim::Agent::Hook::load($agent->{parse_file});
    return Sim::Agent::Hook::invoke($hook, { input_packet => $packet }, $agent, $self);
}



1;


=pod

=head1 NAME

Sim::Agent::Runner - Executes a compiled Sim::Agent graph (FIFO scheduler, hook invocation, journaling)

=head1 DESCRIPTION

Internal runner for Sim::Agent. Owns runtime state (queue, pending inputs, completed packets, counters) and coordinates hook invocation, LLM calls, and deterministic routing.

See L<Sim::Agent> for the user-facing DSL and behavior.

=head1 AUTHOR

Gian Luca Brunetti (2026), gianluca.brunetti@gmail.com

=head1 LICENSE

The GNU General Public License v3.0

=cut

