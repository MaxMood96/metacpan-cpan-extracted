#!/usr/bin/env perl
use strict;
use warnings;

use FindBin ();
use lib "$FindBin::Bin/lib";

use Test::More;
use Scalar::Util ();

# A modifier that arrives after the seal. A plugin applying a role at first
# request adds to a modifier table this phase has already read, and Class::MOP
# rebuilds the composed body without knowing that the old one is now installed
# under the method's own name. The method has to go back to being a real wrapped
# method before that happens.

BEGIN { $ENV{CATALYST_DEBUG} = 0 }

use Catalyst::Seal ();
require Catalyst::Seal::Modifiers;

eval { require Moose; require Moose::Util; 1 }
    or plan skip_all => 'Moose is not installed';

our @LOG;

{
    package Seal::Late;
    use Moose;
    sub greet { push @LOG, 'body'; return 'hi' }
    before greet => sub { push @LOG, 'early' };
    __PACKAGE__->meta->make_immutable;
}

my $meta = Class::MOP::class_of('Seal::Late');

is(Catalyst::Seal::Modifiers::flatten_class('Seal::Late'), 1, 'greet was flattened');
is_deeply([grep { $_ eq 'Seal::Late::greet' } Catalyst::Seal::Modifiers::flattened()],
    ['Seal::Late::greet'], 'and is on the register');

@LOG = ();
is(Seal::Late->greet, 'hi', 'the flattened method answers');
is(join('|', @LOG), 'early|body', 'with the modifier it had at seal time');

# The path every modifier addition goes through, whether it came from
# Moose's add_before_method_modifier, from role application, or from a caller
# holding the metamethod itself.
my $wrapped = $meta->get_method('greet');
my $flat    = Seal::Late->can('greet');
$wrapped->add_before_modifier(sub { push @LOG, 'late' });

is_deeply([grep { $_ eq 'Seal::Late::greet' } Catalyst::Seal::Modifiers::flattened()],
    [], 'the method came off the register');
isnt(Scalar::Util::refaddr(Seal::Late->can('greet')), Scalar::Util::refaddr($flat),
    'and the flattened body is no longer installed');
is(Scalar::Util::refaddr(Seal::Late->can('greet')), Scalar::Util::refaddr($wrapped->body),
    'the stock trampoline is back');

@LOG = ();
is(Seal::Late->greet, 'hi', 'the method still answers');
is(join('|', @LOG), 'late|early|body', 'and the late modifier runs, in the right place');

# A role applied through Moose is the shape this is really guarding against.
# Moose refuses to apply a role to an immutable class at all, so the sequence a
# plugin has to use is make_mutable, apply, make_immutable, and that re-wraps
# the method from scratch rather than adding to the table this phase read.
{
    package Seal::Late::Role;
    use Moose::Role;
    before greet => sub { push @LOG, 'role' };
}
{
    $meta->make_mutable;
    Moose::Util::apply_all_roles('Seal::Late', 'Seal::Late::Role');
    $meta->make_immutable;

    @LOG = ();
    is(Seal::Late->greet, 'hi', 'the method answers after a role was applied');
    is(join('|', @LOG), 'role|late|early|body', 'and every modifier runs, oldest last');
}

# Re-flattening after all that is the same operation on the new wrapped method.
{
    is(Catalyst::Seal::Modifiers::flatten_class('Seal::Late'), 1, 're-flattened');
    @LOG = ();
    is(Seal::Late->greet, 'hi', 'and still answers');
    is(join('|', @LOG), 'role|late|early|body', 'with the same four modifiers');
}

# An un-flatten for a method that was never flattened is a no-op, not a write to
# somebody else's symbol table.
{
    package Seal::Late::Other;
    use Moose;
    sub thing { 'thing' }
    before thing => sub { };
    __PACKAGE__->meta->make_immutable;
}
{
    my $other = Class::MOP::class_of('Seal::Late::Other')->get_method('thing');
    my $body  = Seal::Late::Other->can('thing');
    is(Catalyst::Seal::Modifiers::unflatten_method($other), 0,
        'un-flattening a method that was never flattened does nothing');
    is(Scalar::Util::refaddr(Seal::Late::Other->can('thing')), Scalar::Util::refaddr($body),
        'and leaves the symbol table alone');
    is(Catalyst::Seal::Modifiers::unflatten_method('not an object'), 0,
        'and neither does a string');
}

done_testing;
