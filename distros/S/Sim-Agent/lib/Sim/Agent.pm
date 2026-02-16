package Sim::Agent;

use strict;
use warnings;

our $VERSION = '0.01';

use Sim::Agent::Parser;
use Sim::Agent::Compiler;
use Sim::Agent::Runner;
use Sim::Agent::Journal;

sub new 
{
    my ($class, %opts) = @_;

    die "plan required" unless $opts{plan};

    my $self = 
    {
        plan => $opts{plan},
        dev  => $opts{dev} || 0,
    };

    bless $self, $class;
    return $self;
}

sub run 
{
    my ($self) = @_;

    # ----------------------------
    # Parse
    # ----------------------------
    my $parser = Sim::Agent::Parser->new;
    my $ast    = $parser->parse_file($self->{plan});

    # ----------------------------
    # Compile
    # ----------------------------
    my $compiler = Sim::Agent::Compiler->new;
    my $graph    = $compiler->compile($ast);

    # ----------------------------
    # Journal
    # ----------------------------
    my $journal = Sim::Agent::Journal->new;
    $journal->archive_plan($self->{plan});

    # ----------------------------
    # Runner
    # ----------------------------
    my $runner = Sim::Agent::Runner->new(
        graph   => $graph,
        journal => $journal,
        dev     => $self->{dev},
    );

    $runner->run;
}

1;


=pod

=head1 NAME

Sim::Agent - Deterministic, file-backed orchestration of LLM workers and critics via a small S-expression DSL

=head1 SYNOPSIS

  use Sim::Agent;

  my $sa = Sim::Agent->new(
    plan => 'examples/join.sexpr',
    dev  => 0,
  );

  $sa->run;

CLI:

  perl -Ilib bin/sim-agent examples/join.sexpr

=head1 DESCRIPTION

Sim::Agent runs a directed control-flow graph of named agents. Agents are defined in a small S-expression DSL and executed deterministically in a single-thread FIFO scheduler.

The design targets local-first operation and minimal platform dependence. Prompts and model outputs are written to files under a per-run directory, and model execution is performed via shell calls (Ollama by default).

Agents typically come in pairs: a B<worker> produces an artifact, reflects recursively about it, then a B<critic> validates it. Critics can branch control flow on success/failure, and critical review loops can be bounded so the system progresses with the best available partial result (tainted) instead of looping forever.

=head1 RATIONALE

This distribution is a reaction to the risk of surrendering to "vibe coding" that chained-reasoning LLMs can encourage. When interaction with agents becomes purely conversational, it is easy to drift into a passivizing relationship where the system architecture is accidental rather than designed.

Agent orchestration instead aims to (1) make LLM contributions composable inside explicit, inspectable information flows, and (2) keep the human programmer in the creative role of orchestrator—similar to traditional programming, where one composes explicit functions into systems, except that the composed units here are agent capabilities and their textual interfaces.

=head1 PLAN DSL

The plan is an S-expression file. Comments start with a semicolon C<;> and extend to end of line.

Root form:

  (system
    (limits ...)
    (entry AgentName)
    (agent ...)
    ...)

=head2 limits

  (limits
    (max_iterations 200)
    (max_self_cycles 3)
    (max_pingpong 4))

=over 4

=item * max_iterations

Hard cap on total activations (global guard).

=item * max_self_cycles

Cap on self-reflection cycles inside a worker (self-critic + revision loop). When reached, the worker proceeds with its current output and sets C<tainted>.

=item * max_pingpong

Cap on critic<->worker ping-pong loops for a given (Worker -> Critic) pair. When exceeded, the critic is forced to accept (status becomes OK), the payload is marked tainted, and execution proceeds.

=back

=head2 agent

Workers:

  (agent Worker1
    (role worker)
    (model "llama3.2:1b")
    (prompt-file "examples/hooks/worker_prompt.pl")
    (self-critic-file "examples/hooks/selfcrit.pl")
    (revision-file "examples/hooks/revision.pl")
    (send-to Critic1))

Critics:

  (agent Critic1
    (role critic)
    (parse-file "examples/hooks/critic_parse.pl")
    (on-ok (NextA NextB))
    (on-fail (Worker1)))

Chief:

  (agent Chief1
    (role chief)
    (parse-file "examples/hooks/chief_parse.pl))

Joins:

  (agent Worker4
    (role worker)
    (wait-for (Worker2 Worker3))
    ...)

=head1 EXECUTION MODEL

Execution is single-threaded and deterministic:

=over 4

=item * FIFO queue: activations occur in the order they are enqueued.

=item * wait-for: an agent activates only when all listed dependencies exist in C<completed> with status OK.

=item * fan-out: critics can enqueue multiple targets via C<on-ok> or C<on-fail>.

=item * join: a worker may C<wait-for> multiple upstream workers; critic pass-through preserves original worker keys so joins remain meaningful through critic gates.

=back

=head1 HOOKS

Hooks are Perl files that must return a coderef. Hooks are reloaded on each invocation (useful for development).

Signature:

  sub {
    my ($context, $agent, $runner) = @_;
    ...
  }

=head2 Worker hooks

=over 4

=item * prompt-file

Must return a prompt string. The runner sends it to the LLM adapter.

=item * self-critic-file

Returns either:

  { status => 'ok' }

or:

  { status => 'revise', critique => '...' }

=item * revision-file

Given current output and critique, returns a revised output string.

=back

=head2 Critic / Chief hooks

=parse-file

Must return:

  { status => 'ok' }   or
  { status => 'fail' } or
  { status => 'stop' }  (chief only)

=head1 ARTIFACTS ON DISK

Each run creates a directory:

  run_YYYYMMDD_HHMMSS/
    journal.log
    plan.sexpr
    agents/<AgentName>/
      001_prompt.txt
      001_output.txt
      ...

=head1 SECURITY NOTES

Hook files are arbitrary Perl code and run with the privileges of the current user. Plans and hooks should be treated as trusted inputs.

=head1 SEE ALSO

L<Sim::Agent::Runner>, L<Sim::Agent::Compiler>, L<Sim::Agent::Parser>, L<Sim::Agent::LLM::Ollama>

=head1 AUTHOR

Gian Luca Brunetti (2026), gianluca.brunetti@gmail.com

AI tools were used to accelerate drafting and refactoring. No changes were merged without human review; the maintainer remains the sole accountable party for correctness, security, and licensing compliance.

=head1 LICENSE

The GNU General Public License v3.0

=cut

