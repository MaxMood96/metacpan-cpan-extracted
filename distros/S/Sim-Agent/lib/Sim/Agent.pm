package Sim::Agent;

use strict;
use warnings;

our $VERSION = '0.009';

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

Sim::Agent - Deterministic Orchestration Framework for Structured LLM Agent Experiments

=head1 SYNOPSIS

  use Sim::Agent;

  my $sim = Sim::Agent->new(plan => 'plan.sexpr');
  $sim->run;

=head1 ABSTRACT

Sim::Agent is a deterministic, single-threaded orchestration framework for
Large Language Model (LLM) agents defined through a strict S-expression DSL.
It is designed for controlled experimentation, auditability, and explicit
coordination semantics rather than autonomous or emergent behavior.

The system enforces explicit topology, bounded self-reflection, critic gating,
and reproducible journaling. It is particularly suited for research scenarios
where repeatability, traceability, and architectural clarity are required.

=head1 MOTIVATION

Contemporary LLM agent frameworks often prioritize flexibility and autonomy
over determinism and inspectability. This introduces:

=over 4

=item *

Implicit control flow

=item *

Non-reproducible behavior

=item *

Unbounded reflection loops

=item *

Opaque state transitions

=item *

Hidden concurrency

=back

Sim::Agent is intentionally designed in opposition to these tendencies.
It treats agent orchestration as a formally structured computational graph
with explicit routing, bounded cycles, and file-backed journaling.

The framework is not intended to simulate cognition; it is intended to
simulate coordination.

=head1 DESIGN PRINCIPLES

=head2 1. Determinism

Scheduling is FIFO and single-threaded. There is no concurrency,
no asynchronous dispatch, and no hidden background processes.

=head2 2. Explicit Topology

All control flow is declared in a strict S-expression DSL. There are
no implicit retries, no emergent routing rules, and no hidden dependencies.

=head2 3. Bounded Self-Reflection

Workers may self-criticize and revise their outputs, but cycles are
explicitly bounded via C<max_self_cycles>.

=head2 4. Critic Gating

Critics determine whether outputs propagate forward in the graph.
Critics return structured status:

  { status => 'ok' }
  { status => 'fail', critique => '...' }

=head2 5. Ping-Pong Protection

Repeated critic-worker failure loops are bounded by C<max_pingpong>.
Upon exhaustion, flow proceeds with taint annotation.

=head2 6. Auditability

Every run produces a time-stamped journal directory containing:

=over 4

=item *

Archived plan

=item *

Prompts and outputs per agent

=item *

Execution log

=back

The journal provides full replay-level transparency.

=head2 7. No Hidden State

State is owned by the Runner and passed explicitly between agents.
There is no shared mutable global context.

=head1 ARCHITECTURE

The system is composed of:

=over 4

=item Parser

Tokenizes and parses the S-expression DSL into an AST.

=item Compiler

Validates references, resolves routing, injects default limits,
and constructs the executable graph.

=item Runner

Owns execution state, performs scheduling, invokes hooks,
handles LLM calls, and manages routing.

=item Engine

Pure helper logic for guard checks and dependency resolution.

=item Hook System

Loads dynamic hook files returning coderefs for prompts,
self-critique, revision, and critic parsing.

=item Journal

Creates and manages run directories and structured logging.

=item LLM Adapter

Current implementation uses shell-based Ollama invocation.
Adapters are intentionally isolated from orchestration logic.

=back

=head1 DSL OVERVIEW

Plans are defined as S-expressions:

  (system
    (limits ...)
    (entry Worker1)
    (agent Worker1 ...)
    (agent Critic1 ...)
  )

The DSL is declarative. The graph is compiled before execution.
Invalid references are rejected at compile time.

=head1 RESEARCH APPLICATIONS

Sim::Agent is appropriate for:

=over 4

=item *

Structured evaluation of agent topologies

=item *

Controlled experiments in critic-based validation

=item *

Deterministic comparison of orchestration strategies

=item *

Exploration of bounded self-improvement cycles

=item *

Reproducible LLM workflow research

=back

It is not intended as a production automation system.
It is a research instrument.

=head1 LIMITATIONS

=over 4

=item *

No concurrency

=item *

No distributed execution

=item *

No web browsing or tool autonomy

=item *

LLM-dependent variability in content (though structure is enforced)

=back

These constraints are deliberate.

=head1 PHILOSOPHY

Sim::Agent rejects "vibe coding" and emergent orchestration.
Every transition is declared. Every loop is bounded.
Every output is journaled.

The framework assumes that coordination, not creativity,
is the primary engineering challenge in multi-agent systems.

=head1 FUTURE DIRECTIONS

Potential research extensions include:

=over 4

=item *

Deterministic replay mode

=item *

Formal schema declaration in DSL

=item *

Structured journal export (e.g., JSON traces)

=item *

Model-agnostic adapter abstraction

=item *

Patch-based self-improvement experiments under controlled conditions

=back

=head1 AUTHOR

Gian Luca Brunetti (2026), gianluca.brunetti@gmail.com

AI tools were used to accelerate drafting and refactoring. No changes were merged without human review; the maintainer remains the sole accountable party for correctness, security, and licensing compliance.

=head1 LICENSE

GNU General Public License, Version 3.

=cut
