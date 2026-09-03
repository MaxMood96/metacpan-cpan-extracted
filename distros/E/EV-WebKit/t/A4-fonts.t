use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib';
use TWK;
use EV;
use EV::WebKit;

# The installed font set is a platform tell of its own, and fontconfig is the
# layer that decides it. The catch is the sandbox: the web process cannot open
# a config nobody bound into it, and when it cannot, fontconfig falls back to
# the system one and NOTHING changes -- silently, with no error anywhere. So
# what is asserted here is that the restriction actually reached the engine,
# measured through text metrics rather than trusted.
my @DIRS = grep { -d } qw(
    /usr/share/fonts/truetype/msttcorefonts
    /usr/share/fonts/truetype/liberation
);
plan skip_all => 'needs a known font directory (msttcorefonts or liberation)' unless @DIRS;

my $JS = <<'JS';
var c = document.createElement('canvas').getContext('2d');
var S = 'mmmmmmmmmmlliWWQ@ABCxyz0123';
function w(f) { c.font = '72px ' + f; return c.measureText(S).width }
var base = w('monospace'), present = [];
A.probe.forEach(function (f) { if (Math.abs(w('"' + f + '", monospace') - base) > 0.5) present.push(f) });
return { sans: w('sans-serif'), serif: w('serif'), mono: base, present: present };
JS
my @PROBE = ('DejaVu Sans', 'Noto Sans', 'Cantarell', 'Arial', 'Times New Roman', 'Comic Sans MS');

sub measure {
    my (%opt) = @_;
    my $b = EV::WebKit->new(window => [400,300], ephemeral => 1, timeout => 20, %opt);
    $b->mock_scheme('ft', sub { ('<html><body>f</body></html>', 'text/html') });
    my $nav_err;
    $b->go('ft://h/x', sub { $nav_err = $_[1]; EV::break });
    TWK::run_with_timeout(25);
    my ($r, $err);
    $b->script_async($JS, { probe => \@PROBE }, sub { ($r, $err) = @_; EV::break }) unless $nav_err;
    TWK::run_with_timeout(20) unless $nav_err;
    $b->quit;
    return ($nav_err, $err, $r);
}

my ($ne, $je, $before) = measure();
is($ne, undef, 'baseline page loaded') or BAIL_OUT('cannot load a page at all');
is($je, undef, 'baseline measured') or BAIL_OUT('cannot measure text');
my %had = map { $_ => 1 } @{ $before->{present} };

# A font the host has and the restricted set does not. Without one the whole
# comparison would be vacuous, so skip rather than assert nothing. Not
# skip_all: assertions have already run, and planning after them is an error.
my ($linux_only) = grep { $had{$_} } 'DejaVu Sans', 'Noto Sans', 'Cantarell';

SKIP: {
    skip 'host has none of the Linux-only probe fonts to hide', 3 unless $linux_only;
    my ($ne2, $je2, $after) = measure(fonts => \@DIRS);
    is($ne2, undef, 'fonts => \@dirs: page loaded');
    is($je2, undef, 'fonts => \@dirs: measured');
    my %now = map { $_ => 1 } @{ $after->{present} // [] };
    ok(!$now{$linux_only}, "fonts => \\\@dirs hides '$linux_only', which the host does have")
        or diag "still present: @{ $after->{present} // [] }";
}

SKIP: {
    my ($mst) = grep { m{msttcorefonts} } @DIRS;
    skip 'generic mapping needs msttcorefonts', 4 unless $mst;
    skip 'nothing to hide', 4 unless $linux_only;
    my ($ne3, $je3, $after) = measure(fonts => {
        dirs       => [$mst],
        sans_serif => 'Arial',
        serif      => 'Times New Roman',
        monospace  => 'Courier New',
    });
    is($ne3, undef, 'fonts => \%spec: page loaded');
    is($je3, undef, 'fonts => \%spec: measured');
    my %now = map { $_ => 1 } @{ $after->{present} // [] };
    ok(!$now{$linux_only}, "fonts => \\%spec hides '$linux_only'");
    # The point of the generic mapping: without it all three collapse onto one
    # face and measure the same.
    my %w = map { $_ => sprintf '%.2f', $after->{$_} } qw(sans serif mono);
    ok($w{sans} ne $w{serif} && $w{serif} ne $w{mono} && $w{sans} ne $w{mono},
       'sans-serif, serif and monospace resolve to three different faces')
        or diag "sans=$w{sans} serif=$w{serif} mono=$w{mono}";
}

# Bad input is rejected before anything is built.
for my $case (
    [ 'empty list'        => [] ],
    [ 'missing directory' => ['/nonexistent/evwk/fonts'] ],
    [ 'unknown key'       => { dirs => \@DIRS, nope => 1 } ],
    [ 'dirs not a list'   => { dirs => 'x' } ],
    [ 'markup in family'  => { dirs => \@DIRS, serif => '<x>' } ],
    [ 'missing file'      => '/nonexistent/evwk/fonts.conf' ],
) {
    my ($name, $val) = @$case;
    my $b = eval { EV::WebKit->new(window => [200,150], ephemeral => 1, fonts => $val) };
    ok(!$b && $@, "fonts => $name croaks") or do { $b->quit if $b };
}

done_testing;
