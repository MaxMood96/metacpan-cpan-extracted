package SealTest::Acc;

use strict;
use warnings;

use Moose;

# Every attribute shape the sealed reader has to get right, in a class small
# enough to reason about. The lazy one counts its builds, because "the builder
# ran exactly once" is the whole correctness question for a lazy attribute and
# is invisible from the value alone.

our $BUILDS = 0;

has plain   => (is => 'rw');
has withdef => (is => 'rw', default => 0);
has roone   => (is => 'ro', default => sub { [] });
has falsy   => (is => 'rw', default => '');
has lazyone => (
    is        => 'rw',
    lazy      => 1,
    default   => sub { $BUILDS++; 'built' },
    predicate => 'has_lazyone',
);

sub attributes { qw(plain withdef roone falsy lazyone) }

__PACKAGE__->meta->make_immutable;

1;
