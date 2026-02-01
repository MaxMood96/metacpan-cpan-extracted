#!/usr/bin/env perl
use strict;
use warnings;
use Benchmark qw(cmpthese);
use lib 'blib/lib', 'blib/arch';

use slot qw(slot_counter);

# Hash-based "object"
my $hash = { counter => 0 };

# Pure Perl accessor (hash-based OO style)
{
    package PurePerl::Hash;
    sub new { bless { counter => 0 }, shift }
    sub counter {
        my $self = shift;
        $self->{counter} = shift if @_;
        $self->{counter};
    }
}

# Pure Perl accessor (closure/inside-out style)
{
    package PurePerl::Closure;
    my %data;
    sub new { my $x = 0; bless \$x, shift }
    sub counter {
        my $self = shift;
        $data{$$self} = shift if @_;
        $data{$$self};
    }
    sub DESTROY { delete $data{${$_[0]}} }
}

my $pp_hash = PurePerl::Hash->new;
my $pp_closure = PurePerl::Closure->new;

# Initialize
slot_counter(0);
$pp_closure->counter(0);

print "=== SETTER BENCHMARK ===\n\n";

cmpthese(-2, {
    'slot'        => sub { slot_counter(1) },
    'pp_hash'     => sub { $pp_hash->counter(1) },
    'pp_closure'  => sub { $pp_closure->counter(1) },
    'raw_hash'    => sub { $hash->{counter} = 1 },
});

print "\n=== GETTER BENCHMARK ===\n\n";

cmpthese(-2, {
    'slot'        => sub { my $x = slot_counter() },
    'pp_hash'     => sub { my $x = $pp_hash->counter },
    'pp_closure'  => sub { my $x = $pp_closure->counter },
    'raw_hash'    => sub { my $x = $hash->{counter} },
});

print "\n=== VS MOO (if available) ===\n\n";

if (eval { require Moo; 1 }) {
    eval q{
        package MooCounter;
        use Moo;
        has counter => (is => 'rw', default => 0);
    };

    my $moo = MooCounter->new;

    cmpthese(-2, {
        'slot'      => sub { slot_counter(1) },
        'pp_hash'   => sub { $pp_hash->counter(1) },
        'moo'       => sub { $moo->counter(1) },
    });
} else {
    print "Moo not available, skipping\n";
}
