#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 38;

use Crypt::URandom ();
use Text::Password::Pronounceable;

# The tests below stand in for the system CSPRNG by localizing
# Crypt::URandom::urandom, which is where the module draws its bytes.
no warnings 'redefine';

my $class = 'Text::Password::Pronounceable';

# Run $code with the generator drawing from a fixed queue of bytes rather than
# real entropy, which makes its output deterministic.
sub with_bytes {
    my ($bytes, $code) = @_;
    my @queue = @$bytes;
    local *Crypt::URandom::urandom = sub {
        my ($n) = @_;
        die "stub exhausted: wanted $n byte(s), have " . scalar(@queue) . "\n"
            unless @queue >= $n;
        return pack 'C*', splice @queue, 0, $n;
    };
    return $code->();
}

# _random_int consumes one four byte draw at a time; spell queues out in those
# terms rather than in loose bytes.
sub draws { return map { unpack 'C*', pack 'N', $_ } @_ }

# Run $code with the entropy source failing the way Crypt::URandom fails.
sub with_no_entropy {
    my ($code) = @_;
    local *Crypt::URandom::urandom = sub { die "entropy unavailable\n" };
    return $code->();
}

# _random_int reaches every value in its range.
for my $want (0 .. 10) {
    is( with_bytes( [ draws($want) ], sub { $class->_random_int(11) } ),
        $want, "_random_int(11) can return $want" );
}

# A draw from the discarded block is redrawn rather than folded in with a
# modulo, which would bias the low end of the range.  4294967292 is the first
# value of that block for a limit of 11, and it is congruent to 0, so folding
# it in would show up here as a 0 instead of the 5 that follows it.
is( with_bytes( [ draws( 4294967292, 5 ) ], sub { $class->_random_int(11) } ),
    5, 'a draw from the discarded block is rejected and redrawn' );

# No draw can push a result outside the requested range: not the edges of the
# draw space, nor either side of the boundary where draws start being discarded.
{
    my $ceiling = int( 2 ** 32 / 11 ) * 11;   # 4294967292
    my @escaped;
    for my $value ( 0, 1, 10, 11, 12, 255, 256, 65535, 65536,
        $ceiling - 1, $ceiling, $ceiling + 1, 4294967295,
        map { int( 2 ** 32 / 7 ) * $_ } 1 .. 6 )
    {
        my $got = with_bytes( [ draws( $value, 0 ) ],
            sub { $class->_random_int(11) } );
        push @escaped, "$value => " . ( defined $got ? $got : 'undef' )
            if !defined $got || $got < 0 || $got > 10;
    }
    is_deeply( \@escaped, [], 'no draw escapes [0,11)' );
}

# A limit wider than the draw space would leave nothing acceptable and spin for
# ever, so it is refused rather than drawn for.  Reachable only from an absurd
# max length; the frequency tables cannot get near it.
{
    my ( $got, $ok );
    with_bytes( [], sub {
        $ok = eval { $got = $class->_random_int( 2 ** 32 + 1 ); 1 };
    } );
    ok( $ok, 'a limit wider than the draw space does not die' );
    ok( !defined $got, 'and yields no integer, rather than hanging' );
}

# An absurd length range is refused, and says so: the message must not blame the
# entropy source, which is working fine.
{
    my @warnings;
    my $got = eval {
        local $SIG{__WARN__} = sub { push @warnings, $_[0] };
        with_bytes( [], sub { $class->generate( 1, 2 ** 33 ) } );
    };

    is( $got, q[], 'an unreachable length range yields no password' );
    like( $warnings[0] || q[], qr/wider than a \d+ byte draw/,
        '...and the warning names the real problem' );
    unlike( $warnings[0] || q[], qr/secure source of randomness/,
        '...and does not blame the entropy source' );
}

# Degenerate limits consume no entropy at all.
is( with_bytes( [], sub { $class->_random_int(1) } ), 0, '_random_int(1) is always 0' );
is( with_bytes( [], sub { $class->_random_int(0) } ), 0, '_random_int(0) is always 0' );

# A failing entropy source warns and yields no password.  It must not become an
# exception (generate has never thrown) and must not quietly fall back on core
# rand(), which would hand back a weak password that looks like a good one.
{
    my @warnings;
    my $got = eval {
        local $SIG{__WARN__} = sub { push @warnings, $_[0] };
        with_no_entropy( sub { $class->generate( 6, 10 ) } );
    };

    ok( defined $got, 'generate returns rather than dying when entropy fails' );
    is( $got, q[], '...and the password is empty, not a weak fallback' );
    is( scalar @warnings, 1, '...and exactly one warning is issued' );
    like( $warnings[0], qr/no secure source of randomness/,
        '...and the warning says what went wrong' );
    like( $warnings[0], qr/entropy unavailable/,
        '...and includes the underlying error' );
}

# A failure must not be shrugged off just because the next draw works.  Were
# the length draw left unchecked, a transient failure would quietly yield a
# minimum-length password whose length was never actually drawn.
{
    my @warnings;
    my $real  = \&Crypt::URandom::urandom;
    my $calls = 0;
    my $got   = eval {
        local $SIG{__WARN__} = sub { push @warnings, $_[0] };
        local *Crypt::URandom::urandom
            = sub { $calls++ ? $real->( $_[0] ) : die "transient failure\n" };
        $class->generate( 6, 10 );
    };

    is( $got, q[], 'a failed length draw is reported, not shrugged off' );
    is( scalar @warnings, 1, '...and warns exactly once' );
}

# Entropy can also run out part way through, after the length has been drawn.
# The letter draws must fail the same way: an unchecked draw would leave the
# frequency walk starting from letter 0 and quietly return a row of "a"s.
{
    my @warnings;
    my $got = eval {
        local $SIG{__WARN__} = sub { push @warnings, $_[0] };
        # One draw is enough for the length; nothing is left for letters.
        with_bytes( [ draws(4) ], sub { $class->generate( 6, 10 ) } );
    };

    is( $got, q[], 'a failure after the length draw yields no password' );
    is( scalar @warnings, 1, '...and warns exactly once' );
}

# Fewer bytes than we asked for must not quietly weaken a draw.  This cannot
# happen with Crypt::URandom as it stands since it loops until the buffer is full
# or croaks, but the draw is built by shifting bytes together, so a short read
# would silently produce a smaller number rather than an obvious failure.
{
    my @warnings;
    my $got = eval {
        local $SIG{__WARN__} = sub { push @warnings, $_[0] };
        local *Crypt::URandom::urandom = sub { return q[] };
        $class->generate( 6, 10 );
    };

    is( $got, q[], 'a short read yields no password' );
    like( $warnings[0] || q[], qr/asked for \d+ byte\(s\) but received \d+/,
        '...and the warning reports the shortfall' );
}

# Identical entropy produces identical passwords.
{
    my @bytes = map { $_ % 256 } 1 .. 512;
    my $first  = with_bytes( [@bytes], sub { $class->generate(8) } );
    my $second = with_bytes( [@bytes], sub { $class->generate(8) } );
    is( $first, $second, 'the same entropy yields the same password' );
    like( $first, qr/\A[a-z]{8}\z/, 'password is 8 lowercase letters' );
}

# The documented maximum length is reachable.
{
    my $len = with_bytes(
        [ draws(4), map { $_ % 256 } 1 .. 512 ],
        sub { length $class->generate( 6, 10 ) },
    );
    is( $len, 10, 'generate(6,10) can return a 10-character password' );
}

# ...and it really shows up in unstubbed output.
{
    my %seen;
    $seen{ length $class->generate( 6, 10 ) }++ for 1 .. 500;
    is_deeply( [ sort { $a <=> $b } keys %seen ], [ 6, 7, 8, 9, 10 ],
        'generated lengths cover 6..10 inclusive' );
}

# A max below min carps, but has never been fatal, and it drew downwards from
# min rather than pinning the length.  That is degenerate but observable, so it
# is unchanged: 0.30's int( rand( 5 - 10 ) ) also spread lengths over 6..10.
{
    my %seen;
    {
        local $SIG{__WARN__} = sub { };  # _check_lengths carps every time
        $seen{ length $class->generate( 10, 5 ) }++ for 1 .. 500;
    }
    is_deeply( [ sort { $a <=> $b } keys %seen ], [ 6, 7, 8, 9, 10 ],
        'a max below min still draws downwards from min, as it always did' );
}

# Drawing entropy must not disturb the caller's $@, which 0.30 never touched.
{
    eval { die "unrelated\n" };
    $class->generate( 6, 10 );
    is( $@, "unrelated\n", 'a successful generate leaves $@ alone' );
}

# An unrelated exception is an error, not an entropy failure.  It must not be
# relabelled, and must not be demoted to a warning.
{
    my $err = do {
        local *Text::Password::Pronounceable::_generate_nextchar
            = sub { die "boom\n" };
        eval { $class->generate( 6, 10 ); 1 } ? '' : $@;
    };
    is( $err, "boom\n", 'an unrelated exception propagates unchanged' );
}
