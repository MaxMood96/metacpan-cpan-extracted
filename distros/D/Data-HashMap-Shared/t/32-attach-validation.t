use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use POSIX ();
use Time::HiRes ();

use Data::HashMap::Shared::II;

# Regression (0.19): shm_validate_header reads hdr->size and hdr->tombstones at
# different instants, so on a saturated map a concurrent writer could make the
# cross-field invariant (size + tombstones <= table_cap) look violated and a
# perfectly healthy file was rejected with "corrupt header".  Attach validation
# now re-checks under the seqlock and rejects only a STABLE violation.

use constant { OFF_TABLE_CAP => 20, OFF_SIZE => 136, OFF_TOMBSTONES => 140 };

my $dir = tempdir(CLEANUP => 1);

# --- a stably invalid header must still be refused -------------------------
{
    my $p = "$dir/corrupt.hm";
    { my $m = Data::HashMap::Shared::II->new($p, 8); $m->put($_, $_) for 1 .. 10; }

    my $poke = sub { my ($off, $v) = @_;
        open my $f, '+<', $p or die $!; binmode $f;
        seek $f, $off, 0 or die $!; print $f pack('L', $v); close $f or die $!;
    };
    my $attach = sub { defined eval { Data::HashMap::Shared::II->new($p, 8) } };

    my ($size, $tomb) = do {
        open my $f, '<', $p or die $!; binmode $f;
        seek $f, OFF_SIZE, 0 or die $!; read $f, my $b, 8; unpack 'L2', $b;
    };

    ok( $attach->(), 'healthy header attaches' );

    $poke->(OFF_SIZE, 9999);
    ok( !$attach->(), 'size > table_cap is still refused' );
    $poke->(OFF_SIZE, $size);

    $poke->(OFF_SIZE, 10); $poke->(OFF_TOMBSTONES, 10);
    ok( !$attach->(), 'a STABLE size + tombstones > table_cap is still refused' );
    $poke->(OFF_SIZE, $size); $poke->(OFF_TOMBSTONES, $tomb);

    $poke->(OFF_TABLE_CAP, 7);
    ok( !$attach->(), 'non-power-of-two table_cap is still refused' );
    $poke->(OFF_TABLE_CAP, 16);

    ok( $attach->(), 'header restored: attaches again' );

    # Attach validation waits out an active writer rather than rejecting on a
    # torn counter pair, so it must NOT also wait on a file that is simply
    # corrupt: a stable violation has to be refused on the first attempt.
    # (Guards the backoff from turning every bad file into a multi-second stall.)
    $poke->(OFF_SIZE, 9999);
    my $t0 = Time::HiRes::time();
    $attach->() for 1 .. 20;
    my $elapsed = Time::HiRes::time() - $t0;
    $poke->(OFF_SIZE, $size);
    cmp_ok( $elapsed, '<', 1.0,
            sprintf('20 corrupt-header attaches refuse promptly (%.1f ms total)', $elapsed * 1000) );
}


# --- attaching to a saturated map under concurrent writes must not croak ----
{
    my $p = "$dir/race.hm";
    my $m = Data::HashMap::Shared::II->new($p, 8);   # pinned at table_cap 16
    $m->put($_, $_) for 1 .. 16;
    undef $m;

    my $churn = fork // die "fork: $!";
    unless ($churn) {
        my $c = Data::HashMap::Shared::II->new($p, 8);
        my ($i, $stop) = (0, time + 30);   # self-expire: never orphan a spinner
        while (time < $stop) { $i++; my $k = 1 + $i % 16; $c->remove($k); $c->put($k, $i) }
        POSIX::_exit(0);
    }

    my ($ok, $croaked, $first) = (0, 0, '');
    my $deadline = time + 3;
    while (time < $deadline) {
        if (eval { Data::HashMap::Shared::II->new($p, 8) }) { $ok++ }
        else { $croaked++; $first ||= $@ }
    }
    kill 9, $churn; waitpid $churn, 0;

    ok( $ok > 0, "attached $ok times while a writer churned a saturated map" );
    is( $croaked, 0, 'no spurious "corrupt header" rejection' )
        or diag "first failure: $first";
}

done_testing;
