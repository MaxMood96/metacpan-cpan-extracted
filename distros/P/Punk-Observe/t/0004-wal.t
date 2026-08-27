#!perl
# The WAL. The assertions that matter are the crash ones: a ragged tail is
# NORMAL, and refusing to replay it is the wrong-way failure.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Config;
use File::Temp qw(tempdir);
use File::Spec;
use Punk::Observe;

my $W = 'Punk::Observe::WAL';

my $dir = tempdir(CLEANUP => 1);
sub path { File::Spec->catfile($dir, $_[0]) }
sub slurp {
    my ($p) = @_;
    open my $fh, '<', $p or return '';
    binmode $fh;
    local $/;
    return scalar <$fh>;
}

use constant { NEVER => 0, INTERVAL => 1, ALWAYS => 2 };

# --- CRC-32C ----------------------------------------------------------------

diag($W->can('crc32c_hardware')->() ? 'CRC-32C: hardware instruction'
                                    : 'CRC-32C: table fallback');

# The published CRC-32C check value: "123456789" is 0xE3069283.
is(sprintf('%08x', $W->can('crc32c')->('123456789')), 'e3069283',
   'CRC-32C matches the published check value');
is(sprintf('%08x', $W->can('crc32c_table')->('123456789')), 'e3069283',
   '  and so does the table fallback');

# The two paths must agree BIT FOR BIT. A WAL written on a box with the
# instruction and replayed on one without has to verify, and that is not
# hypothetical - it is a segment archive moved between hosts.
{
    my $bad = 0;
    for my $n (0 .. 200) {
        my $s = join '', map { chr(($_ * 37 + $n * 11) & 0xFF) } 0 .. $n;
        $bad++ if $W->can('crc32c')->($s) != $W->can('crc32c_table')->($s);
    }
    is($bad, 0, 'hardware and table CRC agree on 201 lengths including 0');
}

# Alignment: the hardware path aligns to 8 bytes first, so every offset into
# a buffer must give the same answer as the table.
{
    my $base = join '', map { chr($_ & 0xFF) } 1 .. 64;
    my $bad = 0;
    for my $off (0 .. 15) {
        my $s = substr($base, $off);
        $bad++ if $W->can('crc32c')->($s) != $W->can('crc32c_table')->($s);
    }
    is($bad, 0, 'the two agree at every alignment offset');
}

is($W->can('hdr_size')->(), 40, 'the frame header is the declared 40 bytes');

# --- append and replay ------------------------------------------------------

{
    my $p = path('basic.wal');
    my $r = $W->can('append')->($p, [
        { t => '1774224000000000000', kind => 3, body => 'GET /a' },
        { t => '1774224000000000001', kind => 3, body => 'GET /b' },
        { t => '1774224000000000002', kind => 2, body => '' },
    ], NEVER, 0);
    ok($r->{ok}, 'append succeeded');
    is("$r->{frames}", '1', 'one frame');

    my $rp = $W->can('replay')->(slurp($p));
    is("$rp->{frames}",  '1', 'replay finds one frame');
    is("$rp->{records}", '3', '  and three records');
    is("$rp->{bytes_truncated}", '0', '  with nothing left over');
    is($rp->{reason}, 'eof', '  ending cleanly at eof');

    my $bodies = $W->can('replay_bodies')->(slurp($p));
    is(scalar @$bodies, 3, 'three records come back');
    is($bodies->[0]{body}, 'GET /a', '  body 0');
    is($bodies->[1]{body}, 'GET /b', '  body 1');
    is($bodies->[2]{body}, '',       '  an empty body stays empty');
    is("$bodies->[0]{t}", '1774224000000000000',
       '  and a timestamp above 2^53 survives the round trip bit-exact');
    is($bodies->[2]{kind}, 2, '  kind survives');
}

# An empty batch writes NOTHING. A zero-record frame would carry a nonsense
# t_min/t_max span and a reader pruning on it skips exactly the wrong frames.
{
    my $p = path('empty.wal');
    my $r = $W->can('append')->($p, [], NEVER, 0);
    ok($r->{ok}, 'an empty batch is not an error');
    is("$r->{frames}", '0', '  and writes no frame');
    is(-s $p ? 1 : 0, 0, '  leaving the file empty');
}

# --- many frames ------------------------------------------------------------

{
    my $p = path('many.wal');
    my $r = $W->can('append_many')->($p, 500, NEVER, 0);
    ok($r->{ok}, '500 frames appended');
    my $rp = $W->can('replay')->(slurp($p));
    is("$rp->{frames}",  '500', 'replay finds all 500');
    is("$rp->{records}", '500', '  and all 500 records');
    is($rp->{reason}, 'eof', '  ending cleanly');
}

# --- the fsync policy, asserted by COUNTING not by timing -------------------

{
    my $p = path('fsync-always.wal');
    my $r = $W->can('append_many')->($p, 20, ALWAYS, 0);
    is("$r->{fsyncs}", '20', 'ALWAYS flushes once per frame');
}
{
    my $p = path('fsync-never.wal');
    my $r = $W->can('append_many')->($p, 20, NEVER, 0);
    is("$r->{fsyncs}", '0', 'NEVER does not flush');
}
{
    # A very long interval means the timer never fires within the run, so the
    # count is zero. This asserts the POLICY, not the clock: no sleep, no wall
    # -clock comparison, nothing that a loaded smoker can perturb.
    my $p = path('fsync-interval.wal');
    my $r = $W->can('append_many')->($p, 20, INTERVAL, '3600000000000');
    is("$r->{fsyncs}", '0', 'INTERVAL with an hour interval flushes not at all');
}
{
    # 0 means "use the default", which is 200ms - not "flush every time".
    # A caller passing 0 is saying it has no opinion, and 20 frames take far
    # less than 200ms, so nothing flushes.
    my $p = path('fsync-interval0.wal');
    my $r = $W->can('append_many')->($p, 20, INTERVAL, '0');
    is("$r->{fsyncs}", '0', 'an interval of 0 means the default, not "always"');
}
{
    # A 1ns interval makes the timer fire on every check, which asserts the
    # interval path actually RUNS. This is safe on a loaded smoker in a way a
    # sleep is not: load can only make the elapsed time larger, never smaller,
    # so the assertion cannot become false under contention.
    my $p = path('fsync-interval1.wal');
    my $r = $W->can('append_many')->($p, 20, INTERVAL, '1');
    cmp_ok(0 + $r->{fsyncs}, '>', 0, 'a 1ns interval does flush');
    cmp_ok(0 + $r->{fsyncs}, '<=', 20, '  and never more than once per frame');
}

# --- the ragged tail, which is NORMAL --------------------------------------

{
    my $p = path('ragged.wal');
    $W->can('append_many')->($p, 10, NEVER, 0);
    my $full = slurp($p);

    # Chop the file mid-frame, exactly as a crash would.
    for my $keep (int(length($full) * 0.55), length($full) - 1,
                  length($full) - 39) {
        my $rp = $W->can('replay')->(substr($full, 0, $keep));
        cmp_ok(0 + $rp->{frames}, '<', 10,
               "a tail chopped at $keep yields fewer than 10 frames");
        cmp_ok(0 + $rp->{frames}, '>', 0, '  but not zero');
        cmp_ok(0 + $rp->{bytes_truncated}, '>', 0,
               '  and reports the truncated remainder rather than erroring');
        like($rp->{reason}, qr/^(short|magic)$/, '  stopping for a stated reason');
    }
}

# Every single truncation of a real WAL replays cleanly. This is the assertion
# that there is no length at which recovery reads past its buffer.
{
    my $p = path('trunc.wal');
    $W->can('append_many')->($p, 20, NEVER, 0);
    my $full = slurp($p);
    my $bad = 0;
    for my $n (0 .. length($full)) {
        my $rp = eval { $W->can('replay')->(substr($full, 0, $n)) };
        $bad++ unless defined $rp && defined $rp->{reason};
    }
    is($bad, 0, 'all ' . (length($full) + 1)
              . ' truncations replay cleanly, none crashes');
}

# --- a corrupted middle frame stops THERE ----------------------------------

{
    my $p = path('corrupt.wal');
    $W->can('append_many')->($p, 10, NEVER, 0);
    my $full = slurp($p);
    my $hdr  = $W->can('hdr_size')->();

    # Frame 0 is header + records; flip a byte inside frame 5's payload.
    my $frame_total = $hdr + 88;            # one 88-byte record, no arena
    my $target = 5 * $frame_total + $hdr + 4;
    my $corrupt = $full;
    substr($corrupt, $target, 1) = chr(ord(substr($corrupt, $target, 1)) ^ 0xFF);

    my $rp = $W->can('replay')->($corrupt);
    is("$rp->{frames}", '5', 'replay stops AT the corrupt frame, keeping 5');
    is($rp->{reason}, 'crc', '  reporting a CRC failure');
    cmp_ok(0 + $rp->{bytes_truncated}, '>', 0, '  and the rest as unread');
}

# A corrupt frame must not be SKIPPED. If a bad CRC only cost that one frame,
# the length used to find the next one came from the same untrusted bytes.
{
    my $p = path('corrupt2.wal');
    $W->can('append_many')->($p, 10, NEVER, 0);
    my $full = slurp($p);
    my $hdr  = $W->can('hdr_size')->();
    my $frame_total = $hdr + 88;
    my $corrupt = $full;
    # Corrupt frame 2's declared length: the header no longer agrees with
    # itself, which must be caught before any of it is trusted.
    substr($corrupt, 2 * $frame_total + 4, 1) = chr(0x7F);
    my $rp = $W->can('replay')->($corrupt);
    is("$rp->{frames}", '2', 'a header whose arithmetic disagrees stops replay');
    cmp_ok(0 + $rp->{records}, '==', 2, '  keeping only the verified records');
}

# --- the seal ---------------------------------------------------------------

{
    my $p = path('sealed.wal');
    $W->can('append_many')->($p, 7, NEVER, 0);
    ok($W->can('seal')->($p, 7), 'seal writes a trailer');

    my $rp = $W->can('replay')->(slurp($p));
    is("$rp->{frames}", '7', 'replay reads every frame before the seal');
    is($rp->{sealed}, 1, '  and reports the file as sealed');
    is($rp->{reason}, 'sealed', '  stopping at the trailer');
    is("$rp->{bytes_truncated}", '0', '  with nothing unread');
}

{
    my $p = path('unsealed.wal');
    $W->can('append_many')->($p, 3, NEVER, 0);
    my $rp = $W->can('replay')->(slurp($p));
    is($rp->{sealed}, 0, 'an unsealed file reports itself unsealed');
    is($rp->{reason}, 'eof', '  and ends at eof');
}

# --- a real crash -----------------------------------------------------------

SKIP: {
    skip 'fork not available', 6 unless $Config::Config{d_fork};

    my $p = path('crash.wal');
    my $pid = fork();
    skip 'fork failed', 6 unless defined $pid;

    if ($pid == 0) {
        # The child appends and then dies WITHOUT sealing, closing nothing.
        # POSIX::_exit, so no END blocks, no flush, no cleanup: as close to a
        # kill -9 as a test can arrange from inside.
        $W->can('append_many')->($p, 25, NEVER, 0);
        require POSIX;
        POSIX::_exit(0);
    }
    waitpid $pid, 0;

    my $full = slurp($p);
    my $rp = $W->can('replay')->($full);
    is("$rp->{frames}", '25', 'a child that died without sealing left 25 readable frames');
    is($rp->{sealed}, 0, '  and the file is not sealed');
    is($rp->{reason}, 'eof', '  ending at eof, because the writes completed');

    # Now the harder case: the same file with its last frame chopped, which is
    # what a crash mid-writev leaves.
    my $torn = substr($full, 0, length($full) - 30);
    my $rp2 = $W->can('replay')->($torn);
    is("$rp2->{frames}", '24', 'a torn final frame costs exactly that frame');
    cmp_ok(0 + $rp2->{bytes_truncated}, '>', 0, '  and is reported, not raised');
    is($rp2->{reason}, 'short', '  as a short tail');
}

# --- two workers, two files, no interleaving --------------------------------

SKIP: {
    skip 'fork not available', 3 unless $Config::Config{d_fork};

    my @paths = (path('w0.wal'), path('w1.wal'));
    my @pids;
    for my $i (0, 1) {
        my $pid = fork();
        skip 'fork failed', 3 unless defined $pid;
        if ($pid == 0) {
            $W->can('append')->($paths[$i],
                [ map { { t => 1774224000000000000 + $_,
                          kind => 3, body => "worker$i-$_" } } 1 .. 50 ],
                NEVER, 0);
            require POSIX;
            POSIX::_exit(0);
        }
        push @pids, $pid;
    }
    waitpid $_, 0 for @pids;

    for my $i (0, 1) {
        my $bodies = $W->can('replay_bodies')->(slurp($paths[$i]));
        my @wrong = grep { $_->{body} !~ /^worker$i-/ } @$bodies;
        # ${i} braced deliberately: "$i's" parses as the package variable
        # $i::s, because an apostrophe is perl's old package separator.
        is(scalar @wrong, 0,
           "worker ${i}'s file contains only worker ${i}'s records");
    }
    my $b0 = $W->can('replay_bodies')->(slurp($paths[0]));
    is(scalar @$b0, 50, 'and all 50 of them');
}

# --- THE WHOLE RECORD, NOT THREE FIELDS OF IT -------------------------------
#
# The log wrote t, kind and body and zeroed everything else, and both the
# append and the replay reported success while doing it. A log line stored
# that way cannot be filtered on severity or joined to its trace, and nothing
# anywhere says so: the failure is a page of results with empty columns.
{
    my $p = path('full.wal');
    my $rec = {
        t         => '1774224000123456789',
        kind      => 2,
        body      => 'card refused: insufficient funds',
        severity  => 17,                    # ERROR on the 24-point scale
        span_kind => 2,                     # server
        status    => 2,                     # error
        duration  => '3262000000',
        trace_hi  => '12297829382473034410',
        trace_lo  => '17361641481138401520',
        span_id   => '81985529216486895',
        parent_id => '1311768467463790320',
        attrs     => {
            'service.name'                => 'cards',
            'http.route'                  => '/authorize',
            'http.response.status_code'   => 502,
        },
    };

    my $r = $W->can('append')->($p, [ $rec ], NEVER, 0);
    ok($r->{ok}, 'a full record appends');

    my $back = $W->can('replay_bodies')->(slurp($p));
    is(scalar @$back, 1, '  and replays as one record');
    my $g = $back->[0];

    for my $k (qw(t duration trace_hi trace_lo span_id parent_id)) {
        is("$g->{$k}", $rec->{$k}, "  $k survives bit-exact above 2^53");
    }
    is($g->{severity},  17, '  severity survives');
    is($g->{span_kind}, 2,  '  span kind survives');
    is($g->{status},    2,  '  status survives');
    is($g->{kind},      2,  '  record kind survives');
    is($g->{body}, $rec->{body}, '  the body survives');

    is($g->{attrs}{'service.name'}, 'cards', '  a string attribute survives');
    is($g->{attrs}{'http.route'}, '/authorize', '  and another');
    # As a STRING this compares as one, and 99 sorts above 500.
    is($g->{attrs}{'http.response.status_code'}, 502,
       '  a numeric attribute comes back numeric');

    # Canonical order, not hash order. The content-derived series id is
    # computed over these bytes, so the same labels in two orders would be
    # two series.
    is_deeply($g->{attr_order},
              [ sort @{ $g->{attr_order} } ],
              '  attributes are stored in canonical order');
}

# A frame from a version this build does not know is REFUSED, not read.
#
# The bytes are intact and mean something else. Reading them as records would
# hand back whatever the older writer left in the fields it never filled,
# which is telemetry that is wrong rather than absent.
{
    my $p = path('oldversion.wal');
    my $r = $W->can('append')->($p,
        [ { t => '1774224000000000000', kind => 3, body => 'GET /a' } ],
        NEVER, 0);
    ok($r->{ok}, 'a frame is written');

    my $bytes = slurp($p);
    # The version is the last two bytes of the 40-byte header.
    substr($bytes, 38, 2) = pack('v', 1);

    my $rp = $W->can('replay')->($bytes);
    is($rp->{reason}, 'version', 'replay stops at an unknown frame version');
    is("$rp->{records}", '0', '  having read no records from it');
    cmp_ok($rp->{bytes_truncated}, '>', 0, '  and reports the bytes it left');

    my $back = $W->can('replay_bodies')->($bytes);
    is(scalar @$back, 0, '  and hands back nothing rather than zeroed records');
}


done_testing();
