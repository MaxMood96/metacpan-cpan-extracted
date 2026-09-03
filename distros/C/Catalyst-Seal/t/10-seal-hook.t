#!/usr/bin/env perl
use strict;
use warnings;

use FindBin ();
use lib "$FindBin::Bin/lib";

use Test::More;

BEGIN { $ENV{CATALYST_DEBUG} = 0 }

require Catalyst::Seal;
require SealTest;

pass('Catalyst::Seal loaded');

# Steps registered before the application is compiled run in order, against the
# application class.
my @ran;
Catalyst::Seal::register_step('t-first'  => sub { push @ran, "first:$_[0]" });
Catalyst::Seal::register_step('t-second' => sub { push @ran, "second:$_[0]" });

# A step that dies must not stop the ones after it, and must not disappear.
Catalyst::Seal::register_step('t-dies' => sub { die "deliberate\n" });
Catalyst::Seal::register_step('t-last' => sub { push @ran, "last:$_[0]" });

my @warnings;
{
    local $SIG{__WARN__} = sub { push @warnings, $_[0] };
    require TestApp;
}

ok(TestApp->setup_finished, 'the application set up');
is_deeply(
    [grep { /^(?:first|second|last):/ } @ran],
    ['first:TestApp', 'second:TestApp', 'last:TestApp'],
    'every step ran, in order, against the application class',
);

ok(
    (scalar grep { /step 't-dies' failed for TestApp: deliberate/ } @warnings),
    'a step that died warned rather than vanishing into the hook',
) or diag explain \@warnings;

is(
    scalar(grep { $_->{step} eq 't-dies' } Catalyst::Seal::failures()),
    1,
    'the failure was recorded',
);

# Sealing twice is a no-op.
my $before = @ran;
Catalyst::Seal->seal('TestApp');
is(scalar @ran, $before, 'seal() is idempotent for one application');

# The application still serves requests with a failed step in the list.
my $app = TestApp->psgi_app;
my $res = SealTest::response($app);
is($res->[0], 200, 'the application still answers') or diag explain $res;
is(join('', @{ $res->[2] }), 'hello', 'and answers correctly');

done_testing;
