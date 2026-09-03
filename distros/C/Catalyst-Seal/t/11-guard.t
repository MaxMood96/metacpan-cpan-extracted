#!/usr/bin/env perl
use strict;
use warnings;

use FindBin ();
use lib "$FindBin::Bin/lib";

use Test::More;

BEGIN { $ENV{CATALYST_DEBUG} = 0 }

require Catalyst;
require Catalyst::Seal;
require Catalyst::Seal::Guard;

# replace/restore round trip. The original is not only a convenience for the
# test suite: several replacements call the subroutine they shadowed, and
# %ORIGINAL is where they find it.
{
    my $stock = Catalyst->can('prepare');
    my $fake  = sub { 'fake' };

    ok(Catalyst::Seal::Guard::replace('Catalyst::prepare' => $fake), 'replaced');
    is(Catalyst->can('prepare'), $fake, 'the replacement is installed');
    is(
        $Catalyst::Seal::Guard::ORIGINAL{'Catalyst::prepare'},
        $stock,
        'and the original is where a replacement would look for it',
    );

    ok(Catalyst::Seal::Guard::restore('Catalyst::prepare'), 'restored');
    is(Catalyst->can('prepare'), $stock, 'the original is back');
    ok(!Catalyst::Seal::Guard::restore('Catalyst::prepare'), 'restoring twice is a no-op');
}

# Replacing twice keeps the first original, not the second. Otherwise a step
# that ran again would record its own replacement as the thing to fall back to,
# and the fallback would call itself.
{
    my $stock = Catalyst->can('prepare');
    my $one   = sub { 'one' };
    my $two   = sub { 'two' };

    Catalyst::Seal::Guard::replace('Catalyst::prepare' => $one);
    Catalyst::Seal::Guard::replace('Catalyst::prepare' => $two);
    is(
        $Catalyst::Seal::Guard::ORIGINAL{'Catalyst::prepare'},
        $stock,
        'the first original survives a second replace',
    );

    Catalyst::Seal::Guard::restore('Catalyst::prepare');
    is(Catalyst->can('prepare'), $stock, 'and restore puts that one back');
}

# A patch site that is not there is a Catalyst that is not the one this was
# written for. Installing anyway would define the subroutine rather than
# replace it, and every call that used to fall through to a parent class would
# stop doing so.
{
    my $before = scalar Catalyst::Seal::notes();

    ok(
        !Catalyst::Seal::Guard::replace('Catalyst::no_such_patch_site' => sub { 'nope' }),
        'a subroutine that does not exist is not replaced',
    );
    ok(
        !defined(Catalyst->can('no_such_patch_site')),
        'and was not created on the way past',
    );
    cmp_ok(scalar Catalyst::Seal::notes(), '>', $before, 'a note says why');
    ok(
        !exists $Catalyst::Seal::Guard::ORIGINAL{'Catalyst::no_such_patch_site'},
        'and nothing was recorded to restore',
    );
}

done_testing;
