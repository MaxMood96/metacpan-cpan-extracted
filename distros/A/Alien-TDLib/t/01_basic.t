use strict;
use warnings;
use Test::More;
use Test::Alien;
use Alien::TDLib;

alien_ok 'Alien::TDLib';

my $type = Alien::TDLib->install_type;
like $type, qr/^(system|share)$/, "install_type is system or share (got $type)";

ok length(Alien::TDLib->libs), 'libs is non-empty';
like(Alien::TDLib->libs, qr/tdjson/, 'libs mentions tdjson');

# Which version was installed is a runtime decision (newest published, or
# ALIEN_TDLIB_VERSION), so assert the invariants rather than one release.
if ($type eq 'share') {
    like(Alien::TDLib->commit, qr/^[0-9a-f]{40}$/,
        'share install records the commit it installed');
    like(Alien::TDLib->version, qr/^[0-9]+(?:\.[0-9]+){1,3}$/,
        'share install records a version');

} else {
    is(Alien::TDLib->commit, undef, 'system install records no commit');
    like(Alien::TDLib->version, qr/^[0-9]+(?:\.[0-9]+){1,3}$/,
        'system install reports the probed version');
}

done_testing;
