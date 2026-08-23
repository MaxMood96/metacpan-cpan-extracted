#!perl

# Nothing may spend a reference it does not own on one of perl's immortal
# SVs. Handing &PL_sv_yes to hv_store, or letting &PL_sv_undef become an
# SV * RETVAL (which xsubpp mortalises), buys a SvREFCNT_dec nobody paid
# for. From perl 5.20 the immortals are immune - sv_free resets their
# refcount - so the damage is invisible and every test passes. Before 5.20
# the refcount really moves, and the process dies when it reaches zero.
#
# So assert the invariant rather than the symptom: the refcount of the
# immortal must not move across any number of these calls.
#
# On perl before 5.20 it moves whatever we do - those perls filled the
# slots av_extend allocated with &PL_sv_undef and released every slot on
# free, so an ordinary array hole spends immortal references by itself -
# which is why this file checks a plain-Perl control before it measures
# and skips where the control moves. The tool for those perls is the
# probe header, include/pox/pox_immortal_probe.h (-DPOX_IMMORTAL_PROBE).

use 5.010;
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/lib";
use Test::More;

BEGIN {
    plan skip_all => 'Devel::Peek required to read an immortal refcount'
        unless eval { require Devel::Peek; 1 };
}

use Punk::OAuth2;
use Punk::OAuth2::Checker;
use Crypt::JWS qw(sign);
use Crypt::JWS::Key ();
use File::Raw::JSON ();

# Devel::Peek dumps to STDERR; \undef is PL_sv_undef itself, so the last
# REFCNT in the dump is the immortal's.
sub immortal_refcount {
    my $out = '';
    open my $save, '>&', \*STDERR or return;
    close STDERR;
    open STDERR, '>', \$out       or do { open STDERR, '>&', $save; return };
    Devel::Peek::Dump(\undef);
    open STDERR, '>&', $save      or return;
    my @n = $out =~ /REFCNT = (\d+)/g;
    return $n[-1];
}

plan skip_all => 'cannot read the immortal refcount on this perl'
    unless defined immortal_refcount() && immortal_refcount() =~ /^\d+$/;

# The control: plain Perl, one array, one hole, no XS anywhere near it.
{
    my $before = immortal_refcount();
    for (1 .. 20) { my @a; $a[3] = 1; }
    plan skip_all => 'this perl spends immortal references on ordinary '
        . 'array holes (before 5.20 av_extend filled unused slots with '
        . '&PL_sv_undef), so its own bookkeeping cannot be told from a leak'
        if $before != immortal_refcount();
}

# $n runs of $code must leave the immortal exactly where it started.
sub holds_steady {
    my ($name, $code, $n) = @_;
    $n ||= 50;
    $code->() for 1 .. 3;              # warm up: one-off setup is not a leak
    my $before = immortal_refcount();
    $code->() for 1 .. $n;
    my $spent = $before - immortal_refcount();
    is $spent, 0, $name
        or diag "spent $spent immortal references over $n calls"
              . " - fatal on perl before 5.20";
}

# The accessor that returned an immortal as an SV * RETVAL on the branch
# with nothing to return.
holds_steady 'same_origin_path rejecting a path owns no immortal', sub {
    my $r = Punk::OAuth2::same_origin_path('//evil.example');
};

# The checker's scope set: one slot per scope the token carries, each of
# which was &PL_sv_yes stored bare, and the set is freed on every check.
my $KEY = Crypt::JWS::Key->generate('ES256');
my $KID = $KEY->thumbprint;
my $ISS = 'https://idp.test';
my $AUD = 'https://api.test';

sub token {
    my (%claims) = @_;
    my $now = time;
    return sign($KEY, File::Raw::JSON::file_json_encode({
        iss => $ISS, aud => $AUD, sub => 'user-1',
        exp => $now + 300, iat => $now, scope => 'read write admin',
        %claims,
    }), alg => 'ES256', kid => $KID);
}

my $jwt = Punk::OAuth2::Checker->jwt(
    issuer => $ISS, audience => $AUD, key => $KEY, algs => ['ES256']);
my $ctx = FakeCtx->new;

{
    my $scope = token();
    my $scp   = token(scope => undef, scp => ['read', 'write', 'x']);

    holds_steady 'scope string set, every scope covered', sub {
        my $claims = $jwt->($scope, $ctx, 'op', ['read', 'write']);
    };
    holds_steady 'scope string set, a scope missing', sub {
        my $claims = $jwt->($scope, $ctx, 'op', ['nope']);
    };
    holds_steady 'scp array set, every scope covered', sub {
        my $claims = $jwt->($scp, $ctx, 'op', ['read']);
    };
    holds_steady 'scp array set, a scope missing', sub {
        my $claims = $jwt->($scp, $ctx, 'op', ['admin']);
    };
}

done_testing;

package FakeCtx;
sub new { bless { stash => {} }, shift }
sub stash { $_[0]{stash} }
