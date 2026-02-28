#!/usr/bin/env perl
# Tests for IO::K8s::Types library (IntOrStr, Quantity, Time)

use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../lib";

use IO::K8s::Types qw( IntOrStr Quantity Time );

ok(1, 'IO::K8s::Types loaded');

# ---- IntOrStr ----

subtest 'IntOrStr type' => sub {
    isa_ok(IntOrStr, 'Type::Tiny', 'IntOrStr is Type::Tiny');
    is(IntOrStr->name, 'IntOrStr', 'name is IntOrStr');
    ok(IntOrStr->check('hello'), 'accepts string');
    ok(IntOrStr->check('8080'), 'accepts numeric string');
    ok(IntOrStr->check('25%'), 'accepts percentage');
    ok(IntOrStr->check(''), 'accepts empty string');
};

# ---- Quantity ----

subtest 'Quantity type' => sub {
    isa_ok(Quantity, 'Type::Tiny', 'Quantity is Type::Tiny');
    is(Quantity->name, 'Quantity', 'name is Quantity');

    # Valid quantities
    for my $valid (qw(100m 5Gi 1.5 0.001 12e6 12E3 1k 1M 1G 1T 1P 1E
                      1Ki 1Mi 1Ti 1Pi 1Ei 500m .5 3. +100m -1k 0)) {
        ok(Quantity->check($valid), "valid: '$valid'");
    }

    # Invalid quantities
    for my $invalid ('abc', '1X', '1ki', '1mI', '100m%', '', '1 Gi') {
        ok(!Quantity->check($invalid), "invalid: '$invalid'");
    }
};

# ---- Time ----

subtest 'Time type' => sub {
    isa_ok(Time, 'Type::Tiny', 'Time is Type::Tiny');
    is(Time->name, 'Time', 'name is Time');

    # Valid RFC3339 timestamps
    for my $valid (
        '2024-01-15T10:30:45Z',
        '2026-02-28T00:00:00Z',
        '2024-01-15T10:30:45+01:00',
        '2024-01-15T10:30:45-05:00',
        '2024-01-15T10:30:45.123Z',
        '2024-01-15T10:30:45.123456Z',
    ) {
        ok(Time->check($valid), "valid: '$valid'");
    }

    # Invalid timestamps
    for my $invalid ('not-a-date', '2024-01-15', '2024-01-15 10:30:45',
                     '2024-01-15T10:30:45', '10:30:45Z', '') {
        ok(!Time->check($invalid), "invalid: '$invalid'");
    }
};

# ---- Import via import::into ----

subtest 'import::into works' => sub {
    require Import::Into;

    {
        package TestImportTarget;
        IO::K8s::Types->import::into(__PACKAGE__, qw( IntOrStr Quantity Time ));
    }

    ok(TestImportTarget->can('IntOrStr'), 'IntOrStr imported into target');
    ok(TestImportTarget->can('Quantity'), 'Quantity imported into target');
    ok(TestImportTarget->can('Time'), 'Time imported into target');
};

# ---- Types usable with Moo isa ----

subtest 'types work with Moo' => sub {
    {
        package TestMooWithTypes;
        use Moo;
        use IO::K8s::Types qw( IntOrStr Quantity Time );
        use Types::Standard qw( Maybe );

        has port     => (is => 'ro', isa => IntOrStr);
        has capacity => (is => 'ro', isa => Maybe[Quantity]);
        has created  => (is => 'ro', isa => Maybe[Time]);
    }

    my $obj = TestMooWithTypes->new(
        port     => '8080',
        capacity => '100Gi',
        created  => '2024-01-15T10:30:45Z',
    );
    is($obj->port, '8080', 'IntOrStr attribute works');
    is($obj->capacity, '100Gi', 'Quantity attribute works');
    is($obj->created, '2024-01-15T10:30:45Z', 'Time attribute works');

    # Undef allowed for Maybe types
    my $obj2 = TestMooWithTypes->new(port => 'http');
    is($obj2->capacity, undef, 'Maybe[Quantity] allows undef');
};

done_testing;
