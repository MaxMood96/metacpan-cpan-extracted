#!perl
# Ingest keys.
#
# TWO PROPERTIES, AND THE SECOND IS ASSERTED STRUCTURALLY.
#
#   A key is stored as a HASH. The key file lives in /etc, gets backed up and
#   ends up in a configuration-management repository; as a list of tokens it
#   is a list of credentials.
#
#   The comparison is CONSTANT TIME. That is checked by reading the source for
#   an early return, not by measuring: a timing test on a loaded smoker
#   measures the smoker, and one that passes on a quiet box and fails on a
#   busy one teaches people to ignore it.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Punk::Observe;

my $K = 'Punk::Observe::Key';
sub bearer { $K->can('bearer')->($_[0]) }
sub check  { $K->can('check')->(@_) }

my @KEYS = ( 'prod' => 'k-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
             'ci'   => 'k-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb' );

# --- the bearer header ------------------------------------------------------

{
    is(bearer('Bearer abc123'), 'abc123', 'a bearer token is extracted');
    is(bearer('bearer abc123'), 'abc123',
       '  case-insensitively, because RFC 7235 says the scheme is');
    is(bearer('BEARER abc123'), 'abc123', '  in either direction');
    is(bearer("Bearer   abc123"), 'abc123', '  with the space run collapsed');
    is(bearer("Bearer\tabc123"), 'abc123', '  and a tab accepted');
}

{
    for my $bad ('Basic abc', 'Bearer', 'Bearer ', 'abc123', '', 'Bearerabc') {
        is(bearer($bad), undef, "'$bad' yields no token");
    }
    is(bearer(undef), undef, 'and neither does a missing header');
}

# --- authentication ---------------------------------------------------------

{
    my $r = check(\@KEYS, 'Bearer k-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', undef);
    ok($r->{ok}, 'a correct key is accepted');
    is($r->{name}, 'prod', '  and names which key it was');

    $r = check(\@KEYS, 'Bearer k-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb', undef);
    ok($r->{ok}, 'the second key is accepted too');
    is($r->{name}, 'ci', '  and is told apart from the first');
}

{
    for my $bad (
        [ 'Bearer wrong'  => 'a wrong key' ],
        [ undef           => 'a missing header' ],
        [ 'Bearer '       => 'an empty token' ],
        [ 'Basic k-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' => 'the wrong scheme' ],
    ) {
        my $r = check(\@KEYS, $bad->[0], undef);
        ok(!$r->{ok}, "$bad->[1] is refused");
    }
}

# A KEY DIFFERING IN THE LAST BYTE. This is the case a prefix comparison gets
# right by accident and a truncating one gets wrong.
{
    my $r = check(\@KEYS, 'Bearer k-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab', undef);
    ok(!$r->{ok}, 'a key differing only in the last byte is refused');

    $r = check(\@KEYS, 'Bearer k-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', undef);
    ok(!$r->{ok}, '  and so is a PREFIX of a valid key');

    $r = check(\@KEYS, 'Bearer k-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', undef);
    ok(!$r->{ok}, '  and so is a valid key with a byte appended');

    $r = check(\@KEYS, 'Bearer K-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA', undef);
    ok(!$r->{ok}, '  and the token itself is case-SENSITIVE');
}

# --- revocation -------------------------------------------------------------

{
    my $r = check(\@KEYS, 'Bearer k-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', 'prod');
    ok(!$r->{ok}, 'a revoked key is refused');
    is($r->{code}, 3, '  as revoked, not as unknown');

    $r = check(\@KEYS, 'Bearer k-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb', 'prod');
    ok($r->{ok}, '  while the other key still works');
}

# --- configured open --------------------------------------------------------
#
# An endpoint with no keys configured is open, and SAYS so, rather than
# silently refusing everything or silently accepting it without a record.

{
    my $r = check([], undef, undef);
    ok($r->{ok}, 'with no keys configured the endpoint is open');
    is($r->{required}, 0, '  and reports that it is not requiring one');

    $r = check(\@KEYS, undef, undef);
    is($r->{required}, 1, 'configuring a key makes one required');
}

# --- CONSTANT TIME, ASSERTED STRUCTURALLY -----------------------------------

{
    my $eq = $K->can('ct_eq');
    ok($eq->('same', 'same'), 'the comparison says equal for equal input');
    ok(!$eq->('same', 'diff'), '  and unequal for unequal');
    ok(!$eq->('a', 'ab'), '  including a prefix');
    ok(!$eq->('', 'a'), '  and an empty string');
    ok($eq->('', ''), '  while two empties are equal');
}

{
    open my $fh, '<', 'include/punk_observe/po_key.h' or die $!;
    my $src = do { local $/; <$fh> };
    close $fh;

    # Prose explains the rule at length; only CODE is examined.
    (my $code = $src) =~ s{/\*.*?\*/}{}gs;

    # The comparison itself must contain no branch on the data and no
    # early return.
    my ($fn) = $code =~ /(static int po_ct_eq128.*?\n\})/s;
    ok($fn, 'the constant-time comparison was found') or BAIL_OUT('no compare');
    unlike($fn, qr/\breturn\b.*\breturn\b/s,
           'it has exactly one return, so it cannot exit early');
    unlike($fn, qr/\bif\b|\bwhile\b|\bfor\b|\?/,
           '  and no branch at all on the data');
    unlike($fn, qr/memcmp|strcmp|strncmp/,
           '  and calls no library comparison that would short-circuit');

    # And nothing anywhere in the file compares key material with memcmp.
    my ($chk) = $code =~ /(static int po_keyring_check.*?\n\})/s;
    ok($chk, 'the ring check was found');
    unlike($chk, qr/memcmp/, 'the ring check uses no memcmp');
    unlike($chk, qr/\bbreak\b/,
           '  and does not stop at the first match, so the POSITION of a key '
         . 'in the ring does not leak either');
}

# --- the token is never stored ---------------------------------------------

{
    open my $fh, '<', 'include/punk_observe/po_key.h' or die $!;
    my $src = do { local $/; <$fh> };
    close $fh;
    (my $code = $src) =~ s{/\*.*?\*/}{}gs;

    my ($struct) = $code =~ /(typedef struct \{.*?\} po_key;)/s;
    ok($struct, 'the key record was found');
    unlike($struct, qr/char\s+(?:token|secret|key)\s*\[/,
           'a key record holds no token field at all');
    like($struct, qr/po_u64\s+h_hi, h_lo/,
         '  only a hash of one');
}

# --- an ingest key is not the session credential ---------------------------
#
# Asserted where it is enforceable: the keyring has no notion of a session,
# a user or a scope beyond ingest, so it cannot grant one.

{
    open my $fh, '<', 'include/punk_observe/po_key.h' or die $!;
    my $src = do { local $/; <$fh> };
    close $fh;
    (my $code = $src) =~ s{/\*.*?\*/}{}gs;
    unlike($code, qr/\bsession\b|\bcookie\b|\bcsrf\b/i,
           'the keyring knows nothing about sessions or cookies');
}

# --- THE MOUNT REFUSES TO REGISTER WITHOUT A GUARD -------------------------
#
# An unguarded mount is every log line the application has ever written,
# served to anybody who finds the prefix. A loud failure at boot beats a
# silent hole nobody notices.

SKIP: {
    eval { require Punk::Plugin::Observe; 1 }
        or skip 'Punk::Plugin::Observe not loadable', 8;

    my $P = 'Punk::Plugin::Observe';

    {
        local %ENV = %ENV;
        delete $ENV{PUNK_OBSERVE_INSECURE};
        eval { $P->register(undef, {}) };
        ok($@, 'registering with NO guard croaks');
        like($@, qr/guard is required/, '  saying a guard is required');
        like($@, qr/every log line/,
             '  and saying WHY, because the reason is the argument');
        like($@, qr/PUNK_OBSERVE_INSECURE/,
             '  and naming the deliberate escape');
    }

    {
        local $ENV{PUNK_OBSERVE_INSECURE} = 1;
        my $st = eval { $P->register(undef, {}) };
        ok(!$@, 'the documented escape lets it register') or diag $@;
        ok($st, '  and returns state');
    }

    {
        my $st = eval { $P->register(undef, { guard => sub { 1 } }) };
        ok(!$@, 'a coderef guard registers') or diag $@;
        is($st->{prefix}, '/observe', '  at the default prefix');
    }

    {
        my $st = eval { $P->register(undef,
            { guard => sub { 1 }, prefix => '/telemetry/' }) };
        is($st->{prefix}, '/telemetry',
           'a trailing slash on the prefix is trimmed');
    }

    # THE TENANT IS VALIDATED AT REGISTRATION, so a typo in a config file is a
    # boot failure rather than a path built at runtime.
    {
        eval { $P->register(undef, { guard => sub { 1 }, tenant => '../etc' }) };
        ok($@, 'a bad configured tenant croaks at registration');
        like($@, qr/not usable/, '  with the reason');
    }

    {
        my $st = eval { $P->register(undef, { guard => sub { 1 } }) };
        is($st->{tenant}{fixed}, 'default',
           'the tenant defaults to a CONSTANT, which is the whole seam');
        ok(!defined $st->{tenant}{resolver},
           '  with no resolver until one is configured');
    }

    # Ingest is registered ONLY when asked for, and its scope is separate.
    {
        my $st = eval { $P->register(undef, { guard => sub { 1 } }) };
        ok(!defined $st->{ingest},
           'no ingest endpoint is registered unless one is configured');

        $st = eval { $P->register(undef,
            { guard => sub { 1 }, ingest => {} }) };
        is($st->{ingest}{prefix}, '/v1', 'the ingest prefix defaults to /v1');
        is($st->{ingest}{scope}, 'ingest',
           'and an ingest key is scoped to ingest, with no option to widen it');
    }

    # The rate limit is OFF unconfigured; cardinality HAS a default.
    {
        my $st = eval { $P->register(undef, { guard => sub { 1 } }) };
        is($st->{limits}{rate_records}, 0,
           'the rate limit is off unless configured');
        cmp_ok($st->{limits}{series}, '>', 0,
           'but cardinality HAS a default - a store without one is waiting '
         . 'for a bad deploy');
    }
}

done_testing();
