#!perl
# Phase 0's promises, asserted from Perl so that they are checked on every
# perl in the matrix rather than only on the one that built the .so.
use 5.010;
use strict;
use warnings;
use Config;
use Test::More;

use Punk::Observe;

my %build = Punk::Observe::build_info();
diag("build: " . join(', ', map { "$_=$build{$_}" } sort keys %build));
diag("uvsize=$Config{uvsize} ivsize=$Config{ivsize}");

# --- the record's layout ----------------------------------------------------

is(Punk::Observe::rec_size(), Punk::Observe::rec_declared_size(),
   'sizeof(po_rec) is what the header declares');

my %off = Punk::Observe::rec_offsets();

# The 8-byte members come first and are contiguous. A compiler that inserted
# padding between them would still give a plausible sizeof, so the offsets are
# checked individually and the failure names the member.
my @eight = qw(t_unix_nano series trace_id_hi trace_id_lo
               span_id parent_span_id dur_nano value);
for my $i (0 .. $#eight) {
    is($off{ $eight[$i] }, $i * 8, "$eight[$i] at offset " . ($i * 8));
}

my @four = qw(body_off body_len attr_off attr_len);
for my $i (0 .. $#four) {
    is($off{ $four[$i] }, 64 + $i * 4, "$four[$i] at offset " . (64 + $i * 4));
}

is($off{severity}, 80, 'severity at 80');
is($off{flags},    82, 'flags at 82');
is($off{kind},     84, 'kind at 84');
is($off{aux},      85, 'aux at 85');

# No interior padding: every member accounted for, and the tail is the one
# explicit pad the header documents.
is(Punk::Observe::rec_size() % 8, 0, 'the record is 8-byte aligned');

# --- 64-bit timestamps ------------------------------------------------------

# The values that matter: a real 2026 nanosecond timestamp, the 32-bit wall,
# the NV wall, and the top of the range.
my @ts = (
    '0',
    '1',
    '4294967295',            # 2^32 - 1
    '4294967296',            # 2^32
    '1774224000000000000',   # a plausible 2026 instant, ~1.77e18
    '9007199254740993',      # 2^53 + 1: the first integer an NV cannot hold
    '18446744073709551614',  # UINT64_MAX - 1
    '18446744073709551615',  # UINT64_MAX
);

for my $t (@ts) {
    my $got = Punk::Observe::u64_roundtrip($t);
    is("$got", $t, "timestamp $t survives the record field bit-exact");
}

# The decimal formatter itself, on every platform. On a 64-bit UV perl the
# string branch is never taken, so without this it would first run on the
# 32-bit smokers - the machines least able to report why it broke.
for my $t (@ts) {
    is(Punk::Observe::u64_to_string($t), $t,
       "the decimal formatter renders $t exactly");
}

# The string path is not merely available, it is TAKEN where it has to be.
# A branch that is never exercised is a branch that is wrong.
if ($Config{uvsize} < 8) {
    ok(Punk::Observe::u64_is_string('1774224000000000000'),
       'a 2026 timestamp comes back as a string on this 32-bit UV perl');
}
else {
    ok(!Punk::Observe::u64_is_string('1774224000000000000'),
       'a 2026 timestamp fits a UV here, so it comes back as one');
    # And the value that cannot fit even a 64-bit UV's signed twin still works.
    is("" . Punk::Observe::u64_roundtrip('18446744073709551615'),
       '18446744073709551615', 'UINT64_MAX round-trips on a 64-bit UV perl');
}

# Rejections, so that a bad value is an error rather than a silent zero.
for my $bad ('-1', 'abc', '', '1.5', '99999999999999999999999') {
    my $ok = eval { Punk::Observe::u64_roundtrip($bad); 1 };
    ok(!$ok, "refused: '" . $bad . "'");
}

# --- the clock seam ---------------------------------------------------------

Punk::Observe::clock_freeze('1774224000000000000');
is("" . Punk::Observe::now_ns(), '1774224000000000000', 'the clock froze');

Punk::Observe::clock_step('1000000000');
is("" . Punk::Observe::now_ns(), '1774224001000000000',
   'the clock steps, so no later phase has to sleep to test a timer');

Punk::Observe::clock_real();
ok(Punk::Observe::now_ns() > 0, 'the real clock is restored');

ok($build{clock_gettime}, 'clock_gettime probed and linked here')
    or diag('no clock_gettime: durations fall back to the wall clock');

# Blocks are two hours, epoch-aligned, so a block id is a pure function of a
# timestamp and two workers can never disagree about which block a record is in.
my $two_h = '7200000000000';
is("" . Punk::Observe::block_start('0'), '0', 'epoch is a block start');
is("" . Punk::Observe::block_start($two_h), $two_h, 'a boundary is its own start');
is("" . Punk::Observe::block_start('7199999999999'), '0', 'one ns before rolls back');
is("" . Punk::Observe::block_start('7200000000001'), $two_h, 'one ns after rolls up');

# A clock that stepped backwards gives end < start. In a uint64_t that
# subtraction is about 1.8e19, not a small negative number.
is("" . Punk::Observe::duration('100', '250'), '150', 'a normal duration');
is("" . Punk::Observe::duration('250', '100'), '0',
   'end before start clamps to zero rather than wrapping to 1.8e19');

# --- the tenant boundary ----------------------------------------------------

ok(Punk::Observe::tenant_ok($_), "accepted tenant: $_")
    for ('a', 'acme', 'acme-corp', 'acme_corp', 'A1', '0', 'x' x 64);

my @bad = (
    '..'            => 'parent traversal',
    '.'             => 'current directory',
    '.hidden'       => 'a leading dot',
    'a/b'           => 'a separator',
    'a\\b'          => 'a backslash, which browsers fold to a separator',
    '../etc'        => 'a traversal with a prefix',
    'a..b'          => 'a dot at all',
    '%2e%2e'        => 'percent-encoded traversal',
    'a b'           => 'a space',
    "a\0b"          => 'an embedded NUL',
    "a\nb"          => 'a newline',
    ''              => 'the empty string',
    'x' x 65        => '65 characters',
    'caf' . chr(0xe9) => 'a non-ASCII byte',
);
while (my ($id, $why) = splice @bad, 0, 2) {
    ok(!Punk::Observe::tenant_ok($id), "refused ($why)");
}

# The refusal happens before a path exists.
is(Punk::Observe::store_root('/var/lib/oo', '../other'), undef,
   'a refused tenant yields no root at all');
is(Punk::Observe::store_root('/var/lib/oo', 'a/b'), undef,
   'a separator yields no root at all');

# Single-tenant: the root IS the data directory, with no tenant component.
is(Punk::Observe::store_root('/var/lib/oo', undef), '/var/lib/oo',
   'single-tenant root is the data directory');

# Multi-tenant: one directory level, and the assertion is on the STRING, so it
# holds whether or not either directory exists.
is(Punk::Observe::store_root('/var/lib/oo', 'acme'), '/var/lib/oo/acme',
   'multi-tenant root is a directory under the data directory');

my $a = Punk::Observe::store_join('/var/lib/oo', 'alpha', 'traces/000/w0.seg');
my $b = Punk::Observe::store_join('/var/lib/oo', 'beta',  'traces/000/w0.seg');
is($a, '/var/lib/oo/alpha/traces/000/w0.seg', 'a path under alpha');
is($b, '/var/lib/oo/beta/traces/000/w0.seg',  'a path under beta');
isnt($a, $b, 'the two tenants get different paths');
unlike($a, qr{/beta/},  'no path built for alpha mentions beta');
unlike($b, qr{/alpha/}, 'no path built for beta mentions alpha');

# --- the arena --------------------------------------------------------------

# Records hold offsets into the arena, never pointers into the request body.
for my $s ('', 'a', 'x' x 10_000, "with\0a\0nul", "caf\xc3\xa9") {
    is(Punk::Observe::arena_roundtrip($s), $s,
       'arena round-trip, ' . length($s) . ' bytes');
}

done_testing();
