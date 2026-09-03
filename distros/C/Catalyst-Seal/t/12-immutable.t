#!/usr/bin/env perl
use strict;
use warnings;

use FindBin ();
use lib "$FindBin::Bin/lib";

use Test::More;

BEGIN { $ENV{CATALYST_DEBUG} = 0 }

require Class::MOP;
require Catalyst::Seal;
require TestApp;

my $meta = Class::MOP::class_of('TestApp');
ok($meta->is_immutable, 'the application class was made immutable');
ok(
    Class::MOP::class_of('TestApp::Controller::Root')->is_immutable,
    'and so was the controller',
);

# Immutable means an inlined constructor, so construction no longer goes
# through Class::MOP::Class::_construct_instance.
ok(
    $meta->has_method('new'),
    'an inlined constructor was installed',
);
isnt(
    TestApp->can('new'),
    Moose::Object->can('new'),
    'and it is not Moose::Object::new',
);

# A class that asked for inline_constructor => 0 keeps it. Catalyst::Log is the
# one in the tree that does.
{
    require Catalyst::Log;
    my $log = Class::MOP::class_of('Catalyst::Log');
    ok($log->is_immutable, 'Catalyst::Log is immutable');
    my %opts = $log->immutable_options;
    is($opts{inline_constructor}, 0, 'and kept inline_constructor => 0');
}

# Sealing a class we cannot make immutable records a note and does not die.
{
    package Seal::NotAMooseClass;
    sub new { bless {}, shift }
}
{
    my $before = scalar Catalyst::Seal::notes();
    my $ok = eval { Catalyst::Seal::Immutable::_seal_class('Seal::NotAMooseClass'); 1 };
    ok($ok, 'a non-Moose class does not blow up the step');
    cmp_ok(scalar Catalyst::Seal::notes(), '>', $before, 'and records why it was skipped');
}

# Already immutable is a no-op rather than an error.
is(Catalyst::Seal::Immutable::_seal_class('TestApp'), 0,
    'an already immutable class is left alone');

# The application still works.
require SealTest;
my $res = SealTest::response(TestApp->psgi_app);
is($res->[0], 200, 'the immutable application answers');
is(join('', @{ $res->[2] }), 'hello', 'with the right body');

# Catalyst sets context_class lazily, on the first prepare, so this is only
# true after a request has been served. The application class being the context
# class is the whole reason making it immutable matters.
is(TestApp->context_class, 'TestApp', 'the context class is the application class');

done_testing;
