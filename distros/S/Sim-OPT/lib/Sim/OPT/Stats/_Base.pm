package Sim::OPT::Stats::_Base;

use strict;
use warnings;
use Carp ();
use Scalar::Util ();
use overload
    '0+'     => sub { $_[0]->query() },
    '""'     => sub { q{} . $_[0]->query() },
    'bool'   => sub { $_[0]->query() ? 1 : 0 },
    fallback => 1;

sub new
{
    my ($class, $vector) = @_;

    if (!Scalar::Util::blessed($vector)
        || !$vector->isa('Sim::OPT::Stats::Vector'))
    {
        $vector = Sim::OPT::Stats::_as_vector($vector);
    }

    return bless { v => $vector }, $class;
}

1;
