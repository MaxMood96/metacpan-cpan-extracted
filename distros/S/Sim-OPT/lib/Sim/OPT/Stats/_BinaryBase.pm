package Sim::OPT::Stats::_BinaryBase;

use strict;
use warnings;
use Scalar::Util ();
use overload
    '0+'     => sub { $_[0]->query() },
    '""'     => sub { q{} . $_[0]->query() },
    'bool'   => sub { $_[0]->query() ? 1 : 0 },
    fallback => 1;

sub new
{
    my ($class, $vector1, $vector2) = @_;

    if (!Scalar::Util::blessed($vector1)
        || !$vector1->isa('Sim::OPT::Stats::Vector'))
    {
        $vector1 = Sim::OPT::Stats::_as_vector($vector1);
    }

    if (!Scalar::Util::blessed($vector2)
        || !$vector2->isa('Sim::OPT::Stats::Vector'))
    {
        $vector2 = Sim::OPT::Stats::_as_vector($vector2);
    }

    return bless { v1 => $vector1, v2 => $vector2 }, $class;
}

1;
