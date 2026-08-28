use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit; use File::Temp 'tempdir';

my $dir = tempdir(CLEANUP=>1);
my $pdf = "$dir/out.pdf";
my $b = EV::WebKit->new(window=>[400,300]);
my ($magic, $err);
$b->load_html('<h1>PDF</h1><p>'.('lorem '.'ipsum ' x 200).'</p>', sub {
    $b->pdf($pdf, sub {
        (my $p, $err) = @_;
        if (open my $fh,'<:raw',$pdf) { read $fh,$magic,5; close $fh }
        EV::break;
    });
});
TWK::run_with_timeout(15);
is($err, undef, 'no pdf error');
is($magic, '%PDF-', 'valid PDF produced');

# Finding 1 (r12): two pdf() calls overlapping in flight -- one targeting a
# directory with no write permission -- must not let WebKit's own 'finished'
# signal (fired for the WRONG/doomed op when two PrintOperations race) report
# a false success; pdf() must independently verify the file it claims to
# have written before resolving success.
SKIP: {
    skip 'cannot use permission bits to force a write failure when running as root', 4
        if $> == 0;
    my $dir2  = tempdir(CLEANUP=>1);
    my $rodir = "$dir2/readonly";
    mkdir $rodir or die $!;
    chmod 0500, $rodir or die $!;   # r-x------: cannot create a file inside

    my $b2 = EV::WebKit->new(window=>[300,200]);
    my ($bad_res, $bad_err, $good_res, $good_err, $pending);
    $pending = 2;
    $b2->load_html('<h1>hi</h1>', sub {
        $b2->pdf("$rodir/concurrent.pdf", sub { ($bad_res,  $bad_err)  = @_; EV::break unless --$pending; });
        $b2->pdf("$dir2/good2.pdf",       sub { ($good_res, $good_err) = @_; EV::break unless --$pending; });
    });
    TWK::run_with_timeout(20);
    chmod 0700, $rodir;   # let File::Temp CLEANUP unlink it
    $b2->quit;

    ok(defined $bad_err, 'overlapping pdf(): the doomed (unwritable-dir) call delivers a defined error')
        or diag("false success instead: res=" . (defined $bad_res ? "'$bad_res'" : 'undef'));
    ok(!-e "$rodir/concurrent.pdf", 'overlapping pdf(): no file was actually written for the doomed call');
    is($good_err, undef, 'overlapping pdf(): the valid concurrent call still succeeds');
    ok(-s "$dir2/good2.pdf", 'overlapping pdf(): the valid concurrent call really wrote a PDF');
}

# paper and margin are documented options and neither had any coverage: pdf()
# could have ignored both and the suite would not have noticed.
#
# paper is pinned through the PDF's own MediaBox, which is portable. margin is
# NOT: it moves content within an unchanged MediaBox, and the only handle on
# that was comparing two renders byte for byte -- which held locally but not on
# a GitHub runner, where two identical renders differ. So margin is checked for
# acceptance only, and says so rather than pretending to more.
{
    my $b = EV::WebKit->new(window => [300,200], timeout => 25);
    my %got;
    my $slurp = sub { open my $fh, '<:raw', $_[0] or die "open $_[0]: $!"; local $/; <$fh> };
    $b->load_html('<html><body><h1>paper</h1><p>text to place on the page</p></body></html>', sub {
        my @cases = ([a4 => {}], [letter => { paper => 'na_letter' }], [margined => { margin => 25 }]);
        my $next; $next = sub {
            my $c = shift @cases or return EV::break;
            my ($name, $opt) = @$c;
            my $path = "$dir/$name.pdf";
            $b->pdf($path, %$opt, sub {
                my (undef, $e) = @_;
                $got{"${name}_err"} = $e;
                $got{$name} = $e ? undef : $slurp->($path);
                $next->();
            });
        };
        $next->();
    });
    TWK::run_with_timeout(90);

    is($got{$_ . '_err'}, undef, "pdf with $_ options succeeded") or diag $got{$_ . '_err'}
        for qw(a4 letter margined);
    my $box = sub { my ($mb) = ($_[0] // '') =~ m{/MediaBox\s*\[([^\]]*)\]}; $mb // '(none)' };
    is($box->($got{a4}),     '0 0 595 842', 'the default paper is iso_a4');
    is($box->($got{letter}), '0 0 612 792', "paper => 'na_letter' changes the page size");
    # margin leaves the page size alone -- it is the content that moves
    is($box->($got{margined}), '0 0 595 842', 'margin does not change the page size');
    cmp_ok(length($got{margined} // ''), '>', 1000, 'and a margined render still produces a real PDF');
    $b->quit;
}

# Same sweep as screenshot: a typo'd `papre` silently rendered iso_a4 and
# reported success.
{
    my $b3 = EV::WebKit->new(window => [200,150], ephemeral => 1, timeout => 15);
    my $ready = 0;
    $b3->load_html('<p>x</p>', sub { $ready = 1; EV::break });
    TWK::run_with_timeout(20);
    ok($ready, 'premise: a page is loaded');

    my @w; local $SIG{__WARN__} = sub { push @w, $_[0] };
    ok(!eval { $b3->pdf("$dir/t.pdf", papre => 'iso_a6', sub {}); 1 },
       'pdf croaks on a typo\'d option');
    like($@, qr/unknown option\(s\): papre/, '...naming it');
    ok(!eval { $b3->pdf("$dir/t.pdf", 'paper', sub {}); 1 },
       'pdf croaks on an odd option list');
    like($@, qr/name => value pairs/, '...saying what is wrong');
    is(scalar(@w), 0, '...without warning from inside the module first');

    # A ref where the path belongs became the FILENAME: pdf({paper=>'iso_a4'})
    # rendered a real PDF into a file literally named HASH(0x...) in the cwd and
    # reported success with the hashref as the path. screenshot takes an options
    # hashref first, so this is the natural slip; download/save_to already
    # rejected a ref path, pdf did not.
    require Cwd; my $cwd = Cwd::getcwd();
    ok(!eval { $b3->pdf({ paper => 'iso_a4' }, sub {}); 1 },
       'pdf croaks on a hashref where the path belongs');
    like($@, qr/path must be a plain string/, '...saying so');
    { my $settle = EV::timer(1.0, 0, sub { EV::break }); EV::run }
    # readdir, not glob: glob splits its pattern on whitespace, so on a build
    # path containing a space it returns the fragments and this FAILS rather
    # than checking nothing. Same trap already fixed in t/50-screenshot.t.
    opendir(my $dh, $cwd) or die "opendir $cwd: $!";
    my @junk = grep { /^HASH\(0x/ } readdir $dh;
    closedir $dh;
    is(scalar(@junk), 0, '...and wrote no stray HASH(0x...) file') or diag("left: @junk");

    my ($p, $e, $done) = (undef, undef, 0);
    $b3->pdf("$dir/ok.pdf", paper => 'iso_a5', sub { ($p, $e) = @_; $done = 1; EV::break });
    TWK::run_with_timeout(30);
    ok($done && !$e && -s "$dir/ok.pdf", 'a legitimate pdf option list still renders') or diag $e;
    $b3->quit;
}

# The path is handed to GLib as a URI, so it has to be ENCODED as one. Built by
# hand as 'file://' . $path it was silently reinterpreted: GLib truncates at '#'
# or '?' and percent-decodes %XX. Measured -- pdf("$dir/report#1.pdf") wrote the
# PDF over "$dir/report", destroying its contents, and then reported that the
# caller's own file had not been written, saying nothing about the one that had.
{
    my $ub = EV::WebKit->new(window => [200,150], ephemeral => 1, timeout => 20);
    my $ready = 0;
    $ub->load_html('<p>x</p>', sub { $ready = 1; EV::break });
    TWK::run_with_timeout(25);
    ok($ready, 'premise: a page is loaded');

    my $bystander = "$dir/report";
    open my $bh, '>', $bystander or die $!;
    print $bh 'PRECIOUS-USER-DATA';
    close $bh;

    for my $name ('report#1.pdf', 'q?x.pdf', 'pct%20e.pdf') {
        my ($p, $e, $d) = (undef, undef, 0);
        $ub->pdf("$dir/$name", sub { ($p, $e) = @_; $d = 1; EV::break });
        TWK::run_with_timeout(40);
        ok($d, "pdf('$name') answers") or diag 'no callback';
        is($e, undef, "...without an error") or diag $e;
        ok(-s "$dir/$name", "...and wrote the file the caller actually named");
    }

    is(-s $bystander, 18, 'a neighbouring file was not overwritten');
    open my $rh, '<', $bystander or die $!;
    read $rh, my $head, 18;
    close $rh;
    is($head, 'PRECIOUS-USER-DATA', '...and still holds what it held');
    $ub->quit;
}

# paper takes PWG names. The natural slips -- 'letter', 'a4' -- are not
# recognised by GTK, which falls back to the default size with only a warning
# on stderr, so `paper => 'letter'` silently produces an A4 page. The POD names
# the format and both traps explicitly; this pins the behaviour behind it.
{
    my $pp = EV::WebKit->new(window => [200,150], ephemeral => 1, timeout => 20);
    my $ready = 0;
    $pp->load_html('<p>x</p>', sub { $ready = 1; EV::break });
    TWK::run_with_timeout(25);
    ok($ready, 'premise: a page is loaded');

    my $box = sub {
        my $p = shift;
        open my $h, '<', $p or return '?';
        local $/; my $d = <$h>;
        return $d =~ /MediaBox\s*\[\s*[\d.]+\s+[\d.]+\s+([\d.]+)\s+([\d.]+)/
             ? int($1) . 'x' . int($2) : '?';
    };
    my %got;
    for my $paper (qw(iso_a4 na_letter letter)) {
        my ($e, $d) = (undef, 0);
        $pp->pdf("$dir/p-$paper.pdf", paper => $paper, sub { $e = $_[1]; $d = 1; EV::break });
        TWK::run_with_timeout(45);
        ok($d && !$e, "pdf(paper => '$paper') answers without an error") or diag($e // 'no callback');
        $got{$paper} = $box->("$dir/p-$paper.pdf");
    }
    is($got{iso_a4},    '595x842', 'iso_a4 renders A4');
    is($got{na_letter}, '612x792', 'na_letter renders US Letter -- the PWG name works');
    is($got{letter},    $got{iso_a4},
       "...while 'letter' silently renders the DEFAULT size, which is why the POD names the format");
    $pp->quit;
}

done_testing;
