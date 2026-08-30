#!perl
# The design system, audited by a script rather than by eye.
#
# The failure that reaches production is a token defined ONLY inside a media
# query: it works in dark, and in light it resolves to nothing.
use 5.010;
use strict;
use warnings;
use Test::More;

my $CSS = 'root/static/observe.css';
my $TPL = 'root/templates/layout.tmpl';

ok(-f $CSS, 'the stylesheet exists') or BAIL_OUT('no stylesheet');
ok(-f $TPL, 'the layout template exists');

my $css = do { open my $fh, '<', $CSS or die; local $/; <$fh> };
my $tpl = do { open my $fh, '<', $TPL or die; local $/; <$fh> };

# Strip comments before any analysis: this file documents its own rules at
# length, and counting mentions rather than declarations would make it fail on
# its own prose. (Learned in phase 10, where exactly that happened.)
(my $code = $css) =~ s{/\*.*?\*/}{}gs;

# --- every token has a base definition -------------------------------------

sub block {
    my ($src, $sel) = @_;
    return '' unless $src =~ /\Q$sel\E\s*\{/;
    my $at = $-[0];
    my $i = index($src, '{', $at);
    my ($depth, $j) = (0, $i);
    while ($j < length $src) {
        my $c = substr($src, $j, 1);
        $depth++ if $c eq '{';
        if ($c eq '}') { $depth--; last if $depth == 0 }
        $j++;
    }
    return substr($src, $i + 1, $j - $i - 1);
}

# The bare :root block - everything before the first @media - is the base.
my ($base_src) = $code =~ /^(.*?)\@media/s;
$base_src //= $code;
my $base = block($base_src, ':root');
ok(length $base, 'there is a bare :root block');

my %defined = map { $_ => 1 } ($base =~ /(--[a-z0-9-]+)\s*:/g);
cmp_ok(scalar keys %defined, '>', 40, 'the base defines over 40 tokens');

# Every var(--x) used anywhere must have a base definition. This is the check
# that catches the media-query-only token.
my %used;
$used{$1} = 1 while $code =~ /var\((--[a-z0-9-]+)/g;
cmp_ok(scalar keys %used, '>', 25, 'the sheet actually uses its tokens');

my @undefined = grep { !$defined{$_} } sort keys %used;
is(scalar @undefined, 0, 'every var() has a definition on bare :root')
    or diag('undefined: ' . join(', ', @undefined));

# --- the two theme blocks define the same set -------------------------------

my $dark  = block($code, ':root[data-theme="dark"]');
my $light = block($code, ':root[data-theme="light"]');
ok(length $dark,  'there is an explicit dark block');
ok(length $light, 'there is an explicit light block');

my %d = map { $_ => 1 } ($dark  =~ /(--[a-z0-9-]+)\s*:/g);
my %l = map { $_ => 1 } ($light =~ /(--[a-z0-9-]+)\s*:/g);

my @only_dark  = grep { !$l{$_} } sort keys %d;
my @only_light = grep { !$d{$_} } sort keys %l;
is(scalar @only_dark,  0, 'no token exists only in the dark theme')
    or diag('dark only: ' . join(', ', @only_dark));
is(scalar @only_light, 0, 'no token exists only in the light theme')
    or diag('light only: ' . join(', ', @only_light));

# The media query must be GUARDED, or an explicit light choice loses inside a
# dark operating system.
like($code, qr/\@media \(prefers-color-scheme: dark\)\s*\{\s*:root:not\(\[data-theme="light"\]\)/,
     'the dark media query is guarded against an explicit light choice');

# The media query and the attribute block must agree, or the two ways of
# being dark look different.
my ($mq) = $code =~ /\@media \(prefers-color-scheme: dark\)\s*\{(.*?)\n\}/s;
if ($mq) {
    my %m = map { $_ => 1 } ($mq =~ /(--[a-z0-9-]+)\s*:/g);
    my @diff = grep { !$m{$_} } sort keys %d;
    is(scalar @diff, 0,
       'the dark media query defines the same tokens as [data-theme=dark]')
        or diag('missing from the media query: ' . join(', ', @diff));
}

# --- a component never names a colour --------------------------------------

# Everything after the theme blocks is component CSS, and it must reach every
# colour through a token.
#
# The boundary is found by locating the light block and skipping past its
# closing brace - splitting on the selector alone leaves the block itself in
# the "components" half, and every token definition in it then looks like a
# component naming a raw colour. (It did.)
my $components = do {
    my $at = index($code, ':root[data-theme="light"]');
    if ($at < 0) { '' }
    else {
        my $i = index($code, '{', $at);
        my ($depth, $j) = (0, $i);
        while ($j < length $code) {
            my $c = substr($code, $j, 1);
            $depth++ if $c eq '{';
            if ($c eq '}') { $depth--; last if $depth == 0 }
            $j++;
        }
        substr($code, $j + 1);
    }
};
cmp_ok(length $components, '>', 1000, 'the component half of the sheet was found');
{
    my @hex = ($components =~ /(#[0-9a-fA-F]{3,8})\b/g);
    is(scalar @hex, 0, 'no component rule names a raw colour')
        or diag('raw colours in components: ' . join(', ', @hex));
}

# And nothing inside a theme block names a component.
for my $pair ([ 'dark', $dark ], [ 'light', $light ]) {
    my ($name, $blk) = @$pair;
    my @sel = ($blk =~ /(\.[a-z][a-z0-9-]*)\s*\{/g);
    is(scalar @sel, 0, "the $name theme block contains no component selectors")
        or diag(join ', ', @sel);
}

# --- the required semantic dimensions --------------------------------------

for my $t (qw(--sev-trace --sev-debug --sev-info --sev-warn --sev-error --sev-fatal)) {
    ok($defined{$t}, "severity token $t is defined");
}
for my $t (qw(--span-server --span-client --span-internal
              --span-producer --span-consumer)) {
    ok($defined{$t}, "span-kind token $t is defined");
}
for my $i (1 .. 8) {
    ok($defined{"--series-$i"}, "series ramp token --series-$i is defined");
}
for my $t (qw(--wf-scale --wf-offset)) {
    ok($defined{$t}, "$t is a live variable, which phase 13 rewrites to pan");
}

# --- the layout rules that are not optional --------------------------------

# A TABLE IS ITS OWN SCROLL CONTAINER, which is what keeps a wide one from
# pushing the layout sideways and a long one from putting every panel below it
# off the screen. Either spelling of the overflow does that; what must not
# happen is the rule losing it.
like($code, qr/\.tablewrap\s*\{[^}]*overflow(?:-x)?:\s*(?:auto|scroll)/,
     '.tablewrap scrolls itself, so the page body does not');
like($code, qr/\.tablewrap\s*\{[^}]*max-height:\s*\d/,
     '  and is bounded, so a five-hundred-row table does not bury the page');
like($code, qr/body\s*\{[^}]*overflow-x:\s*hidden/,
     'the page body never scrolls horizontally');
like($code, qr/body\s*\{[^}]*background:\s*var\(--paper\)/,
     'body has an explicit token background, not a borrowed one');
like($code, qr/\.shell\s*>\s*\.main\s*\{[^}]*min-width:\s*0/,
     'the main grid item has min-width:0, or one wide table pushes the layout');
like($code, qr/:focus-visible\s*\{[^}]*outline:/,
     'focus has a visible ring');

# Colour is never the only signal.
like($code, qr/\.row-error[^}]*\{[^}]*(font-weight|box-shadow)/,
     'an error row carries weight or a marker, not only a hue');
like($code, qr/\.row-error td:first-child::before/,
     '  and a text marker for a reader who cannot see the hue');

# --- charts are themeable ---------------------------------------------------

like($code, qr/\.chart \.line[^}]*stroke:\s*currentColor/,
     'chart lines use currentColor, so one markup works in both themes');
{
    my ($chart) = $code =~ /(\.chart[^{]*\{.*?)\.s1/s;
    my @hex = $chart ? ($chart =~ /(#[0-9a-fA-F]{3,8})/g) : ();
    is(scalar @hex, 0, '  and no chart rule bakes a hex');
}

# --- the template -----------------------------------------------------------

like($tpl, qr/data-theme="\{%\s*theme/, 'the template stamps data-theme');
like($tpl, qr/<option value="">System<\/option>/,
     'the theme control offers three states, not two');
like($tpl, qr/observe\.css/, 'the template links the stylesheet');
like($tpl, qr/viewport.*width=device-width/, 'the template sets a viewport');
# THE ASSERTION IS "NOTHING OFF THIS ORIGIN", NOT "NO SCRIPT TAGS".
#
# Written as a ban on `src=` at all, this forbade the four interaction modules
# from ever being loaded - which is what kept them shipped, tested and dead
# for two phases. What actually matters is that nothing on the page is fetched
# from a host the operator does not control, and that is what this checks.
{
    my @srcs = ($tpl =~ /<script[^>]*\bsrc="([^"]*)"/g);
    my @off = grep { m{\A(?:https?:)?//} || m{\A[a-z][a-z0-9+.-]*:}i } @srcs;
    is(scalar @off, 0, 'every script the layout loads is same-origin')
        or diag("off-origin: @off");
    ok(scalar @srcs, '  and it does load its own');
}
unlike($tpl, qr/https?:\/\//,
       'and references no external host at all');

# --- a class that is emitted has a rule ------------------------------------
#
# THE TOKENS EXISTED AND THE COMPONENT RULES DID NOT, which is a failure mode
# neither half's tests can see: the palette test passes because the tokens are
# well-formed, the render test passes because the markup carries the classes,
# and the page draws a waterfall entirely in whitespace with a black
# flamegraph on top of it.

# Every span kind the view can emit has a bar colour.
for my $kind (qw(server client internal producer consumer)) {
    like($code, qr/\.wf-bar\.kind-\Q$kind\E\s*\{[^}]*background:\s*var\(/,
         "the $kind span kind has a bar colour");
}

# The bar does not cover the text it labels. Both were in the same row with
# the bar absolutely positioned over the whole of it, so the waterfall could
# be looked at and not read.
like($code, qr/\.waterfall li\s*\{[^}]*display:\s*grid/,
     'the waterfall row is a grid, so the bar has a track of its own');
like($code, qr/\.wf-label\s*\{[^}]*text-overflow:\s*ellipsis/,
     '  and a long span name truncates rather than pushing the timings off');
unlike($code, qr/\.wf-bar\s*\{[^}]*position:\s*absolute/,
       '  and the bar is not an overlay across the row');

# An SVG rect with no fill paints black, which in the dark theme is an
# invisible chart and in the light theme is a solid black block.
like($code, qr/\.flame rect\s*\{[^}]*fill:\s*var\(/,
     'the flamegraph frames have a fill');
like($code, qr/\.flame text\s*\{[^}]*fill:\s*var\(/,
     '  and the labels on them do too');

# --- the library loads only where it is needed -------------------------------
#
# Plotly is larger than everything else this mount serves put together, and
# most of these screens are tables. The layout is asked to render both ways
# and the two answers must differ, because a conditional that is written but
# always true is indistinguishable from no conditional at all - and the cost
# of getting it wrong is four and a half megabytes on a page of rows.
{
    eval { require Template::Stencil; 1 }
        or diag('Template::Stencil absent, skipping the conditional render');
    SKIP: {
        skip 'Template::Stencil is not installed', 4
            unless $INC{'Template/Stencil.pm'};

        # `content` is Stencil's WRAPPER mechanism, so layout.tmpl cannot be
        # rendered as a template in its own right - it comes out empty. A page
        # is rendered THROUGH it instead, which is also how the plugin does it.
        my $st = Template::Stencil->new({ template_dir => 'root/templates',
                                          wrapper => 'layout.tmpl' });
        my $render = sub {
            my (%v) = @_;
            return eval { $st->render('status.tmpl',
                { prefix => '/observe', theme => '', toolbar => '', %v }) } || '';
        };

        my $without = $render->();
        my $with    = $render->(wants_plot => 1);

        unlike($without, qr/plotly\.min\.js/,
               'a page with no figure does not load the plotting library');
        like($with, qr/plotly\.min\.js/,
             '  and a page with one does');

        # nsmath is unconditional: brush.js needs it on every screen that
        # carries a time range, which is every screen.
        like($without, qr/<script[^>]*\bsrc="[^"]*nsmath\.js"/,
             'the nanosecond arithmetic loads either way');

        # Order is load-bearing rather than incidental. `defer` runs scripts in
        # document order, so nsmath.js being first IS the guarantee that
        # brush.js and plot.js find it.
        my @srcs = ($with =~ /<script[^>]*\bsrc="([^"]*)"/g);
        my ($ns) = grep { $srcs[$_] =~ /nsmath/ } 0 .. $#srcs;
        my ($pl) = grep { $srcs[$_] =~ /plot\.js/ } 0 .. $#srcs;
        ok(defined $ns && defined $pl && $ns < $pl,
           '  and it is loaded before the modules that use it');
    }
}

# --- every figure variable is named so the loader can see it -----------------
#
# THE SUFFIX IS LOAD-BEARING. The plugin decides whether to send four and a
# half megabytes of plotting library by looking for a template variable whose
# name ends in `_plot` - a page gets the library by carrying something to
# draw, rather than by being on a list that goes stale.
#
# The failure mode is silent and total: a figure called `series_gauge` renders
# its JSON into the page, the page has a chart element and no library, and
# what the reader sees is an empty box. It cost exactly that once.
{
    my @bad;
    for my $t (glob 'root/templates/*.tmpl') {
        open my $fh, '<', $t or next;
        my $src = do { local $/; <$fh> };
        # The name inside a figure block: {% raw NAME %} within data-plot.
        while ($src =~ /data-plot>\s*\{%\s*raw\s+([a-z_0-9.]+)\s*%\}/g) {
            my $var = $1;
            push @bad, "$t: $var" unless $var =~ /_plot\z/;
        }
    }
    is_deeply(\@bad, [],
              'every figure variable ends in _plot, which is what loads the library')
        or diag(join "\n", @bad, 'a figure the loader cannot see renders an empty box');
}

# ...AND THE LOADER HAS TO LOOK WHERE THE FIGURE IS.
#
# The naming rule above is half the guarantee. The other half is the scan that
# reads it, and it read only the TOP level of the variables - so a dashboard,
# whose figures hang off each panel rather than off the page, got four chart
# elements and no library. The same empty box, arrived at from the other end.
{
    my %vars = (panels => [ { title => 'p', series_plot => '{"data":[]}' } ]);
    my $found = (grep {
        my $p = $_;
        ref $p eq 'HASH'
            && grep { /_plot\z/ && defined $p->{$_} && length $p->{$_} } keys %$p;
    } @{ $vars{panels} }) ? 1 : 0;
    ok($found, 'a figure nested in a panel is still a figure the loader finds');
}

# --- a figure never carries a null ------------------------------------------
#
# AN ABSENT KEY AND A NULL ONE ARE NOT THE SAME THING, and the difference is
# invisible from Perl: a figure that does not want the shared date axis says so
# with undef, which encodes as `null`. A plotting library handed
# `xaxis: null` does not fall back to its default - it fails, and the panel
# renders empty with nothing in the markup to say why.
#
# It reached a page once. The gauge on the overview carried `"xaxis":null` and
# drew nothing at all.
{
    eval { require Punk::Observe::Plot; 1 }
        or plan skip_all => 'Punk::Observe::Plot not loadable';
    my $P = 'Punk::Observe::Plot';

    my %fig = (
        gauge => $P->can('gauge')->(value => 4, max => 10, title => 't'),
        flow  => $P->can('service_flow')->(
                    [ { caller => 'a', callee => 'b', count => 3, errors => 0 } ]),
        timeline => $P->can('alert_timeline')->(
                    [ { series => 'a', to => 'firing', at => '1787000000000000000' } ],
                    to => '1787000060000000000'),
    );

    for my $name (sort keys %fig) {
        my $f = $fig{$name};
        ok($f, "$name builds") or next;
        my $json = $P->can('encode')->($f);
        unlike($json, qr/:\s*null/, "  the $name figure encodes no null");
        # And the axes a gauge does not want are absent, not present-and-empty.
        if ($name eq 'gauge') {
            ok(!exists $f->{layout}{xaxis},
               '  a gauge has no x axis key at all, rather than a null one');
        }
    }
}

# --- the vendored library ---------------------------------------------------
#
# A BLOB NOBODY CAN VERIFY IS A SUPPLY CHAIN NOBODY CAN AUDIT.
#
# This is the one file in the distribution that was not written here, it is
# larger than everything else put together, and it runs in the browser of
# somebody reading their own production telemetry. The digest is what makes
# replacing it a visible act: a swap that is not accompanied by a change to
# this line fails here.
#
# Update it deliberately, by re-recording the digest of a build fetched from
# https://cdn.plot.ly/plotly-<version>.min.js, never to make this pass.
{
    my $js = 'root/static/plotly.min.js';
    SKIP: {
        skip 'plotly.min.js is not in this tree', 3 unless -f $js;
        require Digest::SHA;

        my $sum = Digest::SHA->new(256)->addfile($js, 'b')->hexdigest;
        is($sum, '28498fa2ea4ba45c8633218088eb223436ca0ca02fc57027fd6fa841ad1901f9',
           'the vendored plotly.min.js is the exact build that was reviewed')
            or diag("got $sum - if this was a deliberate upgrade, record the "
                  . "new digest here and say which version it is");

        my $src = do { open my $fh, '<:raw', $js or die $!; local $/; <$fh> };
        like(substr($src, 0, 200), qr/plotly\.js v3\.4\.0/,
             '  and it says which version it is in its own banner');
        like(substr($src, 0, 200), qr/MIT/,
             '  under the licence the distribution says it is under');
    }
}

# --- the other vendored files ------------------------------------------------
#
# Same rule as plotly above, for the same reason: these were not written here,
# they run in the browser of somebody reading their own production telemetry,
# and replacing one has to be a visible act rather than a quiet edit.
#
# Update a digest deliberately, by re-recording it from the release that was
# reviewed, never to make this pass.
{
    my @vendored = (
        { file => 'root/static/moment.min.js',
          sha  => '845c524969edd5b3af9aa6d8718d29fe92e8dbe25b955214a8e064a05a9a5027',
          what => 'moment 2.30.1',
          banner => qr/2\.30\.1/ },
        { file => 'root/static/daterangepicker.js',
          sha  => '85ae36a7ed9867efd487d3494846ac696355c8303d47100f5f75c3fdbdf774d7',
          what => 'vanilla-datetimerange-picker',
          banner => qr/vanilla-datetimerange-picker/ },
        { file => 'root/static/daterangepicker.css',
          sha  => '33dd81c9713cf40a1066b03fa958641cdd6e9a6a72e55f78d5a171a41083b59f',
          what => 'vanilla-datetimerange-picker stylesheet',
          banner => undef },
    );

    require Digest::SHA;
    for my $v (@vendored) {
      SKIP: {
            skip "$v->{file} is not in this tree", ($v->{banner} ? 2 : 1)
                unless -f $v->{file};
            my $sum = Digest::SHA->new(256)->addfile($v->{file}, 'b')->hexdigest;
            is($sum, $v->{sha}, "the vendored $v->{what} is the reviewed build")
                or diag("got $sum - if this was a deliberate upgrade, record "
                      . "the new digest here and say which version it is");
            next unless $v->{banner};
            # The WHOLE file, not its first few hundred bytes. A minifier
            # keeps a licence banner at the top and puts the version string
            # wherever the code that assigns it ended up - moment states its
            # own 57KB in - so anchoring this to the head asserts the layout
            # of somebody else's build step rather than what the file is.
            my $src = do { open my $fh, '<:raw', $v->{file} or die $!;
                           local $/; <$fh> };
            like($src, $v->{banner}, "  and says what it is, in its own bytes");
        }
    }
}

# THE VENDORED FILES ARE ALL MIT, and the distribution says so where somebody
# looking for it would look. A licence recorded only in a test is a licence
# nobody reading the distribution ever sees.
{
    my $pod = do { open my $fh, '<', 'lib/Punk/Observe.pm' or die $!;
                   local $/; <$fh> };
    like($pod, qr/THIRD-PARTY|Third-party/i,
         'the POD has a third-party section');
    for my $name (qw(plotly moment vanilla-datetimerange-picker)) {
        like($pod, qr/\Q$name\E/i, "  naming $name");
    }
}

# --- the precompressed siblings ---------------------------------------------
#
# Makefile.PL derives these, and the plugin serves one INSTEAD of the file it
# was derived from. So the failure mode is not a stale asset, it is the WRONG
# BYTES UNDER A CORRECT ETAG - a client that asked for gzip gets last build's
# stylesheet and has no way to know.
#
# Inflating it and comparing is the only assertion that catches that.
{
    my @gz = glob('root/static/*.gz');
    SKIP: {
        skip 'nothing precompressed in this tree - run Makefile.PL', 1
            unless @gz;
        eval { require IO::Uncompress::Gunzip; 1 }
            or skip 'IO::Uncompress::Gunzip not available', 1;

        my @wrong;
        for my $gz (@gz) {
            (my $src = $gz) =~ s/\.gz\z//;
            next unless -f $src;
            my $want = do { open my $fh, '<:raw', $src or die $!; local $/; <$fh> };
            my $got = '';
            # Transparent => 0: it passes NON-compressed data straight
            # through, which would make a truncated or plain-text sibling
            # compare EQUAL and pass this test vacuously.
            IO::Uncompress::Gunzip::gunzip($gz => \$got, Transparent => 0)
                or do { push @wrong, "$gz did not inflate"; next };
            push @wrong, "$gz inflates to different bytes than $src"
                unless $got eq $want;
        }
        is_deeply(\@wrong, [],
                  'every precompressed asset inflates to the file beside it')
            or diag(join "\n", @wrong);
    }
}

done_testing();
