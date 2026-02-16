package Sim::Agent::Compiler;

use strict;
use warnings;

sub new 
{
    my ($class) = @_;
    bless {}, $class;
}

sub compile 
{
    my ($self, $ast) = @_;

    die "Root must be (system ...)"
        unless ref($ast) eq 'ARRAY'
            && @$ast
            && $ast->[0] eq 'system';

    my $graph = 
    {
        entry  => undef,
        chief  => undef,
        limits => _default_limits(),
        agents => {},
    };

    # Process system body
    for my $form (@$ast[1 .. $#$ast]) 
    {

        die "Invalid form in system"
            unless ref($form) eq 'ARRAY';

        my $keyword = $form->[0];

        if ($keyword eq 'limits') 
        {
            _compile_limits($graph, $form);
        }
        elsif ($keyword eq 'entry') 
        {
            _compile_entry($graph, $form);
        }
        elsif ($keyword eq 'agent') 
        {
            _compile_agent($graph, $form);
        }
        else 
        {
            die "Unknown system keyword: $keyword";
        }
    }

    _finalize_graph($graph);

    return $graph;
}

# -------------------------------------------------------------------
# Internal Helpers (Private)
# -------------------------------------------------------------------

sub _default_limits 
{
    return 
    {
        max_depth        => 5,
        max_agents       => 50,
        max_iterations   => 100,
        max_self_cycles  => 5,
        max_pingpong => 4,
    };
}

sub _compile_limits 
{
    my ($graph, $form) = @_;

    for my $item (@$form[1 .. $#$form]) 
    {

        die "Invalid limit entry"
            unless ref($item) eq 'ARRAY'
                && @$item == 2;

        my ($key, $value) = @$item;

        die "Unknown limit: $key"
            unless exists $graph->{limits}->{$key};

        die "Limit must be integer"
            unless defined $value && $value =~ /^\d+$/;

        $graph->{limits}->{$key} = int($value);
    }
}

sub _compile_entry 
{
    my ($graph, $form) = @_;

    die "Entry form must be (entry AgentName)"
        unless @$form == 2;

    die "Multiple entry declarations"
        if defined $graph->{entry};

    $graph->{entry} = $form->[1];
}

sub _compile_agent 
{
    my ($graph, $form) = @_;

    die "Agent form too short"
        unless @$form >= 3;

    my $name = $form->[1];

    die "Duplicate agent: $name"
        if exists $graph->{agents}->{$name};

    my $agent = 
    {
        name          => $name,
        role          => undef,
        model         => undef,
        prompt_file   => undef,
        selfcrit_file => undef,
        revision_file => undef,
        parse_file    => undef,
        send_to       => undef,
        on_ok         => [],
        on_fail       => [],
        wait_for      => [],
    };

    for my $attr (@$form[2 .. $#$form]) {

        die "Invalid agent attribute"
            unless ref($attr) eq 'ARRAY';

        my $key = $attr->[0];

        if ($key eq 'role') 
        {
            die "Role form invalid" unless @$attr == 2;
            $agent->{role} = $attr->[1];
        }
        elsif ($key eq 'model') 
        {
            die "Model form invalid" unless @$attr == 2;
            $agent->{model} = $attr->[1];
        }
        elsif ($key eq 'prompt-file') 
        {
            die "prompt-file invalid" unless @$attr == 2;
            $agent->{prompt_file} = $attr->[1];
        }
        elsif ($key eq 'self-critic-file') 
        {
            die "self-critic-file invalid" unless @$attr == 2;
            $agent->{selfcrit_file} = $attr->[1];
        }
        elsif ($key eq 'revision-file') 
        {
            die "revision-file invalid" unless @$attr == 2;
            $agent->{revision_file} = $attr->[1];
        }
        elsif ($key eq 'parse-file') 
        {
            die "parse-file invalid" unless @$attr == 2;
            $agent->{parse_file} = $attr->[1];
        }
        elsif ($key eq 'send-to') 
        {
            die "send-to must have exactly one target"
                unless @$attr == 2;
            $agent->{send_to} = $attr->[1];
        }
        elsif ($key eq 'on-ok') 
        {
            $agent->{on_ok} = _extract_list($attr);
        }
        elsif ($key eq 'on-fail') 
        {
            $agent->{on_fail} = _extract_list($attr);
        }
        elsif ($key eq 'wait-for') 
        {
            $agent->{wait_for} = _extract_list($attr);
        }
        else 
        {
            die "Unknown agent attribute: $key";
        }
    }

    die "Agent $name missing role"
        unless $agent->{role};

    $graph->{agents}->{$name} = $agent;
}

sub _extract_list 
{
    my ($form) = @_;

    die "Expected list form"
        unless @$form == 2
            && ref($form->[1]) eq 'ARRAY';

    return $form->[1];
}

sub _finalize_graph 
{
    my ($graph) = @_;

    die "Missing entry"
        unless defined $graph->{entry};

    die "Entry agent not defined"
        unless exists $graph->{agents}->{ $graph->{entry} };

    my $chief_count = 0;

    for my $agent (values %{ $graph->{agents} }) {

        # Count chief
        if ($agent->{role} eq 'chief') 
        {
            $chief_count++;
            $graph->{chief} = $agent->{name};
        }

        die "Invalid role: $agent->{role}"
            unless $agent->{role} =~ /^(worker|critic|chief)$/;

        if ($agent->{role} eq 'worker') 
        {
            die "Worker $agent->{name} missing send-to"
                unless defined $agent->{send_to};
        }

        if ($agent->{role} eq 'critic') 
        {
            die "Critic $agent->{name} missing on-ok"
                unless @{ $agent->{on_ok} };
            die "Critic $agent->{name} missing on-fail"
                unless @{ $agent->{on_fail} };
        }

        for my $target (
            @{ $agent->{on_ok} },
            @{ $agent->{on_fail} },
            @{ $agent->{wait_for} },
            (defined $agent->{send_to} ? ($agent->{send_to}) : ())
        ) 
        {
            die "Undefined agent reference: $target"
                unless exists $graph->{agents}->{$target};
        }
    }

    die "Exactly one chief required"
        unless $chief_count == 1;
}

1;

=pod

=head1 NAME

Sim::Agent::Compiler - Compiles the S-expression AST into a validated execution graph

=head1 DESCRIPTION

Takes the parsed AST and produces a normalized graph structure: limits, agents, routing, and reference validation.

See L<Sim::Agent> for DSL details.

=head1 AUTHOR

Gian Luca Brunetti (2026), gianluca.brunetti@gmail.com

=head1 LICENSE

The GNU General Public License v3.0

=cut


