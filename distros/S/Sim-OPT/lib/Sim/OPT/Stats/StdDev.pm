package Sim::OPT::Stats::StdDev;

use strict;
use warnings;
use parent 'Sim::OPT::Stats::_Base';

sub query
{
    my ($self) = @_;

    my $variance = Sim::OPT::Stats::Variance->new($self->{v})->query();
    return sqrt($variance);
}

1;
