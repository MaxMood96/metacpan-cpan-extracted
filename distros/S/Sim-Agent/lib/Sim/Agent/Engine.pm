package Sim::Agent::Engine;

use strict;
use warnings;

package Sim::Agent::Engine;

use strict;
use warnings;

sub dependencies_satisfied 
{
    my ($agent, $state) = @_;

    return 1 unless @{ $agent->{wait_for} || [] };

    for my $dep (@{ $agent->{wait_for} }) 
    {
        return 0 unless exists $state->{completed}->{$dep};
        return 0 unless $state->{completed}->{$dep}->{status} eq 'ok';
    }

    return 1;
}

sub is_enqueued_or_active 
{
    my ($state, $agent) = @_;

    return 1 if $state->{active}->{$agent};

    for my $queued (@{ $state->{queue} }) 
    {
        return 1 if $queued eq $agent;
    }

    return 0;
}


1;

=pod

=head1 NAME

Sim::Agent::Engine - Small pure helper routines used by the runner

=head1 DESCRIPTION

Internal helpers used by the runner (e.g. dependency checks, queue guards). Intentionally minimal and side-effect free.

See L<Sim::Agent>.

=head1 AUTHOR

Gian Luca Brunetti (2026), gianluca.brunetti@gmail.com

=head1 LICENSE

The GNU General Public License v3.0

=cut

