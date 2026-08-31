package Sim::OPT::Stats::Correlation;

use strict;
use warnings;
use parent 'Sim::OPT::Stats::_BinaryBase';

sub query
{
    my ($self) = @_;

    my @x = $self->{v1}->query();
    my @y = $self->{v2}->query();

    return 0 if !@x || @x != @y;

    my $covariance = Sim::OPT::Stats::Covariance->new(
        $self->{v1}, $self->{v2}
    )->query();

    my $stddev_x = Sim::OPT::Stats::StdDev->new($self->{v1})->query();
    my $stddev_y = Sim::OPT::Stats::StdDev->new($self->{v2})->query();
    my $denominator = $stddev_x * $stddev_y;

    return 0 if $denominator == 0;
    return $covariance / $denominator;
}

1;
