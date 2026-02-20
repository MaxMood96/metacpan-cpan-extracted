package Sim::AgentSoar;

use strict;
use warnings;

our $VERSION = '0.06';

# Load the distribution's public modules so "use Sim::AgentSoar" is enough
# for common consumers.
use Sim::AgentSoar::AgentSoar ();
use Sim::AgentSoar::Engine   ();
use Sim::AgentSoar::Node     ();
use Sim::AgentSoar::Worker   ();

1;

=pod

=head1 NAME

Sim::AgentSoar - SOAR-inspired explicit search with a pluggable LLM worker

=head1 SYNOPSIS

  use Sim::AgentSoar;
  use Sim::AgentSoar::AgentSoar;
  use Sim::AgentSoar::Worker;

  my $worker = Sim::AgentSoar::Worker->new(model => 'llama3.2:1b');

  my $search = Sim::AgentSoar::AgentSoar->new(
      worker               => $worker,
      branching_factor     => 2,
      regression_tolerance => 2,
      max_depth            => 20,
  );

  my $path = $search->run(start => 4, target => 19);

=head1 DESCRIPTION

This distribution implements a deterministic, inspectable best-first search
controller (L<Sim::AgentSoar::AgentSoar>) plus a deterministic environment
(L<Sim::AgentSoar::Engine>) and an optional LLM-backed operator proposer
(L<Sim::AgentSoar::Worker>).

=head1 AUTHOR

Gian Luca Brunetti (2026), gianluca.brunetti\@gmail.com

=head1 LICENSE

GPLv3.

=cut
