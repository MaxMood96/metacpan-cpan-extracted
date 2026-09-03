#!/usr/bin/env perl
use strict;
use warnings;

use FindBin ();
use lib "$FindBin::Bin/lib";

use Test::More;
use Scalar::Util ();

# A synthetic class carrying every combination of modifier, run before and after
# flattening. The comparison is the whole test: what a wrapped method does in
# list, scalar and void context is Class::MOP's business, and flattening is only
# correct if it changes none of it.

BEGIN { $ENV{CATALYST_DEBUG} = 0 }

use Catalyst::Seal ();
require Catalyst::Seal::Modifiers;

eval { require Moose; 1 } or plan skip_all => 'Moose is not installed';

our @LOG;

{
    package Seal::Order;
    use Moose;

    sub multi  { push @LOG, 'body(' . (wantarray ? 'list' : defined wantarray ? 'scalar' : 'void') . ')'; return (1, 2, 3) }
    sub only_b { push @LOG, 'b.body'; return 'b' }
    sub only_a { push @LOG, 'a.body'; return 'a' }
    sub only_r { push @LOG, 'r.body'; return 'r' }

    before multi => sub { push @LOG, 'before1' };
    before multi => sub { push @LOG, 'before2' };
    after  multi => sub { push @LOG, 'after1'  };
    after  multi => sub { push @LOG, 'after2'  };
    around multi => sub { my $o = shift; push @LOG, 'around1.in';
                          my @r = $_[0]->$o(@_[1 .. $#_]);
                          push @LOG, 'around1.out'; return @r };
    around multi => sub { my $o = shift; push @LOG, 'around2.in';
                          my @r = $_[0]->$o(@_[1 .. $#_]);
                          push @LOG, 'around2.out'; return @r };

    before only_b => sub { push @LOG, 'b.before' };
    after  only_a => sub { push @LOG, 'a.after'  };
    around only_r => sub { my $o = shift; push @LOG, 'r.around';
                           return $_[0]->$o(@_[1 .. $#_]) };

    __PACKAGE__->meta->make_immutable;
}

# One call in each context, reported as the log it produced and what came back.
sub run {
    my ($method) = @_;
    my %out;

    @LOG = ();
    my @list = Seal::Order->$method;
    $out{list} = join('|', @LOG) . ' => ' . join(',', map { defined $_ ? $_ : '(undef)' } @list);

    @LOG = ();
    my $scalar = Seal::Order->$method;
    $out{scalar} = join('|', @LOG) . ' => ' . (defined $scalar ? $scalar : '(undef)');

    @LOG = ();
    Seal::Order->$method;
    $out{void} = join('|', @LOG);

    return \%out;
}

my @METHODS = qw(multi only_b only_a only_r);
my %before = map { $_ => run($_) } @METHODS;

# The test would pass on a class where no modifier ran at all, so say what the
# unflattened class actually did before believing the comparison.
like($before{multi}{list},
    qr/\Abefore2\|before1\|around2\.in\|around1\.in\|body\(list\)\|around1\.out\|around2\.out\|after1\|after2 => 1,2,3\z/,
    'all six modifiers on multi ran, in Class::MOP order, in list context');
is($before{multi}{scalar},
    'before2|before1|around2.in|around1.in|body(list)|around1.out|around2.out|after1|after2 => 3',
    'and in scalar context');

my $meta = Class::MOP::class_of('Seal::Order');
my %was_wrapped = map {
    $_ => Scalar::Util::blessed($meta->get_method($_))->isa('Class::MOP::Method::Wrapped') ? 1 : 0
} @METHODS;
is_deeply(\%was_wrapped, { map { $_ => 1 } @METHODS }, 'every method under test was wrapped');

is(Catalyst::Seal::Modifiers::flatten_class('Seal::Order'), scalar @METHODS,
    'all four flattened');

for my $method (@METHODS) {
    my $installed = Seal::Order->can($method);
    my $body      = $meta->get_method($method)->body;
    isnt(Scalar::Util::refaddr($installed), Scalar::Util::refaddr($body),
        "$method is no longer the trampoline");
    is(
        Scalar::Util::refaddr($installed),
        Scalar::Util::refaddr($meta->get_method($method)->{modifier_table}{cache}),
        "$method is the composed body Class::MOP built",
    );
}

my %after = map { $_ => run($_) } @METHODS;
is_deeply(\%after, \%before, 'flattening changed nothing, in any context, for any shape');

# A method that is still mutable is left alone: the state a class is in while it
# is still being built is not a state to compile anything from.
{
    package Seal::Order::Mutable;
    use Moose;
    sub thing { 'thing' }
    before thing => sub { };
}
{
    my $notes = scalar Catalyst::Seal::notes();
    is(Catalyst::Seal::Modifiers::flatten_class('Seal::Order::Mutable'), 0,
        'a mutable class is not flattened');
    cmp_ok(scalar Catalyst::Seal::notes(), '>', $notes, 'and says so');
}

# Catalyst::Log is where several debugging plugins hang their wrappers.
{
    require Catalyst::Log;
    is(Catalyst::Seal::Modifiers::flatten_class('Catalyst::Log'), 0,
        'Catalyst::Log is skipped whatever is on it');
}

done_testing;
