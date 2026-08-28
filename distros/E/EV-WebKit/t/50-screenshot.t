use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit; use File::Temp 'tempdir';

my $dir = tempdir(CLEANUP=>1);
my $png = "$dir/shot.png";
my $b = EV::WebKit->new(window=>[320,240]);
my ($ok, $bytes, $full_bytes);

$b->load_html('<body style="background:#0a0"><h1>shot</h1></body>', sub {
    $b->screenshot($png, sub {
        my ($result, $err) = @_;
        # PNG magic, not file(1): every file(1) line begins with the FILENAME,
        # so `substr(..., 0, 5) ne 'Error'` was true even for a missing file and
        # for no file(1) at all. Path mode went unchecked for actual PNG-ness.
        $ok = !$err && (-s $png) > 0;
        if ($ok) {
            open my $fh, '<:raw', $png or die "open $png: $!";
            read $fh, my $magic, 8;
            $ok = $magic eq "\x89PNG\r\n\x1a\n";
        }
        # Now test bytes mode
        $b->screenshot({bytes=>1}, sub {
            $bytes = $_[0];
            # Test full-document mode
            $b->screenshot({full=>1, bytes=>1}, sub {
                $full_bytes = $_[0];
                EV::break;
            });
        });
    });
});

TWK::run_with_timeout(10);

ok($ok, 'screenshot wrote a file');
is(substr($bytes, 0, 8), "\x89PNG\r\n\x1a\n", 'bytes are a PNG');
is(substr($full_bytes, 0, 8), "\x89PNG\r\n\x1a\n", 'full-document bytes are a PNG');
# ...and full => 1 really captures more than the viewport. PNG magic alone does
# not discriminate: mapping the option to the visible region still produces a
# valid PNG, and left this green. The page below is several viewports tall, so
# the two captures cannot be the same image.
{
    my $b2 = EV::WebKit->new(window => [200,150], timeout => 10);
    my ($vis, $full, $err);
    $b2->load_html('<html><body style="margin:0">'
                 . join('', map { "<div style=\"height:200px;background:hsl($_,90%,50%)\">$_</div>" } 0..9)
                 . '</body></html>', sub {
        $b2->screenshot({ bytes => 1 }, sub {
            ($vis, $err) = @_;
            $b2->screenshot({ bytes => 1, full => 1 }, sub { ($full, $err) = ($_[0], $_[1] // $err); EV::break });
        });
    });
    TWK::run_with_timeout(25);
    is($err, undef, 'both captures of a tall page succeed') or diag $err;
    cmp_ok(length($full // ''), '>', length($vis // ''),
           'full => 1 captures more of a page taller than the viewport');
    $b2->quit;
}

# screenshot({}, $cb): no path AND no bytes => must error clearly and
# asynchronously, not fall into `open ... undef` (uninitialized-value
# warnings, a confusing generic "open : ..." error).
my (@warnings, $noopt_err, $noopt_ret);
{
    local $SIG{__WARN__} = sub { push @warnings, $_[0] };
    $noopt_ret = $b->screenshot({}, sub { (undef, $noopt_err) = @_; EV::break });
    TWK::run_with_timeout(10);
}
is($noopt_ret, $b, 'screenshot({}) (no path, no bytes) returns $b');
is($noopt_err, 'screenshot path required (or bytes => 1)',
    'screenshot({}) (no path, no bytes) errors clearly');
my @uninit = grep { /uninitialized/ } @warnings;
is(scalar(@uninit), 0, 'screenshot({}) (no path, no bytes) emits no uninitialized-value warnings')
    or diag(explain(\@warnings));

# a write failure (disk full etc.) must be reported as an error, not silently
# swallowed while claiming success -- /dev/full's write(2) deterministically
# fails with ENOSPC regardless of how much data is written, so it forces the
# print/close path to actually fail without needing a real full filesystem.
SKIP: {
    skip '/dev/full not available/writable in this environment', 2
        unless -e '/dev/full' && -w '/dev/full';
    my $full_err;
    $b->screenshot('/dev/full', sub { (undef, $full_err) = @_; EV::break });
    TWK::run_with_timeout(10);
    ok(defined $full_err, 'screenshot write failure (/dev/full) is reported as an error')
        or diag('got a false success instead of an error');
    like($full_err // '', qr/write|full|space/i,
        'write-failure error message names the failure (not a generic/blank string)');
}

# The option sweep every sibling already had. Both failure modes were measured
# before it: `ful => 1` silently produced a VIEWPORT shot where the caller asked
# for the full document -- reported as success, and indistinguishable from a
# correct one -- and `screenshot(bytes => 1, $cb)` took 'bytes' for the PATH,
# wrote a PNG to a file literally named `bytes` in the process's cwd, warned
# "Odd number of elements" from inside the module, and reported success with
# the string 'bytes' as the result.
{
    my $b2 = EV::WebKit->new(window => [200,150], ephemeral => 1, timeout => 10);
    my $ready = 0;
    $b2->load_html('<p>x</p>', sub { $ready = 1; EV::break });
    TWK::run_with_timeout(20);
    ok($ready, 'premise: a page is loaded');

    my @w; local $SIG{__WARN__} = sub { push @w, $_[0] };

    ok(!eval { $b2->screenshot("$dir/x.png", ful => 1, sub {}); 1 },
       'screenshot croaks on a typo\'d option');
    like($@, qr/unknown option\(s\): ful/, '...naming it');

    # The write is ASYNCHRONOUS: a relative path is resolved when the snapshot
    # completes, not when screenshot() is called. So chdir'ing around the call
    # proves nothing -- with the guard reverted the PNG still lands in the cwd
    # the process started in (measured; that is how a stray `bytes` got into the
    # dist root in the first place). Check there, after a settle.
    require Cwd;
    my $cwd = Cwd::getcwd();
    ok(!eval { $b2->screenshot(bytes => 1, sub {}); 1 },
       'screenshot(bytes => 1, $cb) croaks rather than writing a file named "bytes"');
    like($@, qr/name => value pairs/, '...saying the option list is malformed');
    { my $settle = EV::timer(1.5, 0, sub { EV::break }); EV::run }
    ok(!-e "$cwd/bytes", '...and no stray file named "bytes" was created');

    ok(!eval { $b2->screenshot({ bytes => 1 }, 'extra', sub {}); 1 },
       'the options-hashref form rejects trailing arguments');
    like($@, qr/no further arguments/, '...saying so');

    # Only a HASH ref is the options form, so any OTHER unblessed ref used to
    # become the FILENAME: screenshot(['oops'], $cb) wrote a real PNG to a file
    # named ARRAY(0x...) and reported success with the arrayref as the path.
    # pdf got this guard a round earlier; its sibling two screens away did not.
    ok(!eval { $b2->screenshot(['oops'], sub {}); 1 },
       'screenshot rejects an arrayref where the path belongs');
    like($@, qr/path must be a plain string/, '...saying so');
    { my $settle = EV::timer(1.0, 0, sub { EV::break }); EV::run }
    # readdir, not glob: glob splits its pattern on whitespace, so a build
    # directory with a space in it would silently check nothing.
    opendir(my $dh, $cwd) or die "opendir $cwd: $!";
    my @junk = grep { /^ARRAY\(0x/ } readdir $dh;
    closedir $dh;
    is(scalar(@junk), 0, '...and wrote no stray ARRAY(0x...) file') or diag("left: @junk");

    # ...but a BLESSED ref is left alone, because that is how a File::Temp or
    # Path::Tiny path arrives. pdf has the same exemption and t/56 pins it
    # there; without one here the carve-out could be dropped as dead weight.
    {
        package EVWK::PathObj;
        use overload '""' => sub { ${ $_[0] } }, fallback => 1;
        sub new { my ($c, $p) = @_; bless \$p, $c }
    }
    my ($op, $oe, $od) = (undef, undef, 0);
    my $objpath = EVWK::PathObj->new("$dir/viaobj.png");
    # eval'd: a regression here croaks, and an uncaught croak takes the rest of
    # the file with it rather than failing one named assertion.
    my $accepted = eval { $b2->screenshot($objpath, sub { ($op, $oe) = @_; $od = 1; EV::break }); 1 };
    ok($accepted, 'a path object that stringifies is accepted') or diag $@;
    TWK::run_with_timeout(20) if $accepted;
    ok($od, '...and its callback fires') or diag 'no callback';
    is($oe, undef, '...without an error') or diag $oe;
    ok(-s "$dir/viaobj.png", '...and the file really landed');

    is(scalar(@w), 0, 'none of that warned from inside the module');

    # the legitimate spellings still work
    my ($p, $e, $done) = (undef, undef, 0);
    $b2->screenshot("$dir/ok.png", full => 1, sub { ($p, $e) = @_; $done = 1; EV::break });
    TWK::run_with_timeout(20);
    ok($done && !$e && -s "$dir/ok.png", 'a full-document screenshot still works') or diag $e;
    my ($bytes, $bdone) = (undef, 0);
    $b2->screenshot({ bytes => 1 }, sub { $bytes = $_[0]; $bdone = 1; EV::break });
    TWK::run_with_timeout(20);
    ok($bdone && defined $bytes && $bytes =~ /\A\x89PNG/, 'and so does the bytes form');
    $b2->quit;
}

done_testing;
