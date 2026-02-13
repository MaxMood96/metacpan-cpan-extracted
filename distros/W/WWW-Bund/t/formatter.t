use strict;
use warnings;
use Test::More;
use FindBin;
use File::Spec;
use File::Temp qw(tempdir tempfile);

use WWW::Bund::CLI::Formatter;

my $templates_dir = File::Spec->catdir($FindBin::Bin, '..', 'share', 'templates');
my $strings_dir   = File::Spec->catdir($FindBin::Bin, '..', 'share', 'strings');

# Helper to create formatter
sub make_fmt {
    my (%opts) = @_;
    WWW::Bund::CLI::Formatter->new(
        templates_dir => $opts{templates_dir} // $templates_dir,
        strings_dir   => $opts{strings_dir}   // $strings_dir,
        lang          => $opts{lang}          // 'de',
        %opts,
    );
}

# --- _extract tests ---
{
    my $fmt = make_fmt();

    # Simple key
    my $data = { roads => [qw(A1 A2 A3)] };
    is_deeply($fmt->_extract($data, 'roads'), [qw(A1 A2 A3)], '_extract simple key');

    # Dotted path
    $data = { data => { items => [1, 2, 3] } };
    is_deeply($fmt->_extract($data, 'data.items'), [1, 2, 3], '_extract dotted path');

    # Missing path returns undef
    is($fmt->_extract($data, 'nonexistent'), undef, '_extract missing key');
    is($fmt->_extract($data, 'data.nonexistent'), undef, '_extract missing nested key');
}

# --- _resolve_field tests ---
{
    my $fmt = make_fmt();

    my $item = { name => 'Test', water => { shortname => 'Rhein' }, km => 42 };

    is($fmt->_resolve_field($item, 'name'), 'Test', '_resolve_field simple');
    is($fmt->_resolve_field($item, 'water.shortname'), 'Rhein', '_resolve_field dotted');
    is($fmt->_resolve_field($item, 'km'), 42, '_resolve_field numeric');
    is($fmt->_resolve_field($item, 'nonexistent'), undef, '_resolve_field missing');
    is($fmt->_resolve_field($item, 'water.nonexistent'), undef, '_resolve_field nested missing');
}

# --- _render_table tests ---
{
    my $fmt = make_fmt();

    my $data = [
        { name => 'Alpha', value => 10 },
        { name => 'Beta',  value => 20 },
    ];

    my $template = {
        type    => 'table',
        columns => [
            { field => 'name',  header => 'NAME',  width => 20 },
            { field => 'value', header => 'VALUE', width => 10 },
        ],
    };

    my $out = $fmt->_render_table($data, $template);
    like($out, qr/NAME\s+VALUE/, 'table has headers');
    like($out, qr/---/, 'table has separator');
    like($out, qr/Alpha\s+10/, 'table has first row');
    like($out, qr/Beta\s+20/, 'table has second row');

    # Empty array (German)
    like($fmt->_render_table([], $template), qr/\(leer\)/, 'table empty array (de)');
}

# --- _render_table with dotted fields ---
{
    my $fmt = make_fmt();

    my $data = [
        { shortname => 'BONN', water => { shortname => 'Rhein' } },
        { shortname => 'KOELN', water => { shortname => 'Rhein' } },
    ];

    my $template = {
        type    => 'table',
        columns => [
            { field => 'shortname',       header => 'STATION', width => 15 },
            { field => 'water.shortname', header => 'WATER',   width => 15 },
        ],
    };

    my $out = $fmt->_render_table($data, $template);
    like($out, qr/STATION\s+WATER/, 'dotted table has headers');
    like($out, qr/BONN\s+Rhein/, 'dotted table resolves nested field');
}

# --- _render_list tests ---
{
    my $fmt = make_fmt();

    # Simple list of scalars
    my $data = [qw(A1 A2 A3)];
    my $template = { type => 'list' };
    my $out = $fmt->_render_list($data, $template);
    like($out, qr/A1\nA2\nA3\n/, 'list renders scalars');

    # List with field extraction
    $data = [{ name => 'Rhein' }, { name => 'Elbe' }];
    $template = { type => 'list', field => 'name' };
    $out = $fmt->_render_list($data, $template);
    like($out, qr/Rhein\nElbe\n/, 'list extracts field');

    # Empty list (German)
    like($fmt->_render_list([], $template), qr/\(leer\)/, 'list empty (de)');
}

# --- _render_list with columns ---
{
    my $fmt = make_fmt();

    my $data = [qw(A1 A2 A3 A4 A5 A6 A7)];
    my $template = { type => 'list', columns => 3 };
    my $out = $fmt->_render_list($data, $template);
    my @lines = split /\n/, $out;
    is(scalar @lines, 3, 'columns: 3 items per row, 7 items = 3 rows');
    like($lines[0], qr/A1\s+A2\s+A3/, 'first row has 3 items');
    like($lines[1], qr/A4\s+A5\s+A6/, 'second row has 3 items');
    like($lines[2], qr/A7/, 'third row has remainder');

    # columns with field extraction
    $data = [map {{ name => "X$_" }} 1..5];
    $template = { type => 'list', field => 'name', columns => 3 };
    $out = $fmt->_render_list($data, $template);
    @lines = split /\n/, $out;
    is(scalar @lines, 2, 'columns with field: 5 items / 3 cols = 2 rows');
    like($lines[0], qr/X1\s+X2\s+X3/, 'field columns first row');

    # columns: 1 behaves like normal list
    $data = [qw(A B C)];
    $template = { type => 'list', columns => 1 };
    $out = $fmt->_render_list($data, $template);
    is($out, "A\nB\nC\n", 'columns: 1 is same as no columns');
}

# --- _word_wrap ---
{
    # Basic word wrap
    my @lines = WWW::Bund::CLI::Formatter::_word_wrap("Hello World", 20);
    is(scalar @lines, 1, 'short text: no wrap needed');
    is($lines[0], 'Hello World', 'short text: unchanged');

    @lines = WWW::Bund::CLI::Formatter::_word_wrap("AS Köln-Lövenich (aus Richtung Lövenich)", 20);
    ok(scalar @lines > 1, 'long text wraps to multiple lines');
    ok(length($lines[0]) <= 20, 'first line within width');

    # Hard break when no space
    @lines = WWW::Bund::CLI::Formatter::_word_wrap("Superlangeeswortohnespace", 10);
    ok(scalar @lines > 1, 'hard break on long word');
    is(length($lines[0]), 10, 'hard break at exact width');
}

# --- _render_table with wrap ---
{
    my $fmt = make_fmt();

    my $data = [
        { title => 'Short', subtitle => 'Also short' },
        { title => 'A1 Foo-Bar', subtitle => 'This is a very long subtitle that should wrap to the next line properly' },
    ];
    my $template = {
        type    => 'table',
        columns => [
            { field => 'title',    header => 'TITLE',    width => 15 },
            { field => 'subtitle', header => 'SUBTITLE', width => 25, wrap => 1 },
        ],
    };

    my $out = $fmt->_render_table($data, $template);
    # The long subtitle should produce extra lines
    my @lines = split /\n/, $out;
    ok(scalar @lines > 4, 'wrap: long subtitle produces extra lines');
    # First data line should have both title and start of subtitle
    like($lines[2], qr/Short\s+Also short/, 'wrap: short row unchanged');
    # The wrapped row should have the title on first line
    like($lines[3], qr/A1 Foo-Bar/, 'wrap: long row has title');
    # Continuation line should have empty title column (padded spaces + wrapped text)
    like($lines[4], qr/^\s+\S/, 'wrap: continuation line has empty first column then text');

    # Without wrap, text is truncated
    my $template_no_wrap = {
        type    => 'table',
        columns => [
            { field => 'title',    header => 'TITLE',    width => 15 },
            { field => 'subtitle', header => 'SUBTITLE', width => 25 },
        ],
    };
    my $out_no_wrap = $fmt->_render_table($data, $template_no_wrap);
    my @lines_no_wrap = split /\n/, $out_no_wrap;
    is(scalar @lines_no_wrap, 4, 'no wrap: exactly header + separator + 2 data rows');
}

# --- _render_table with full_grid ---
{
    my $fmt = make_fmt();
    my $data = [
        { name => 'Alice', age => '30' },
        { name => 'Bob',   age => '25' },
    ];
    my $template = {
        type      => 'table',
        full_grid => 1,
        columns   => [
            { field => 'name', header => 'NAME', width => 10 },
            { field => 'age',  header => 'AGE',  width => 5 },
        ],
    };
    my $out = $fmt->_render_table($data, $template);
    like($out, qr/^\+[-+]+\+$/m, 'full_grid: has horizontal rule with +');
    like($out, qr/\| NAME\s+\| AGE\s+\|/, 'full_grid: header row has pipes');
    like($out, qr/\| Alice\s+\| 30\s+\|/, 'full_grid: data row has pipes');
    like($out, qr/\| Bob\s+\| 25\s+\|/, 'full_grid: second data row has pipes');

    # Count rules: top + after header + after each row = 1 + 1 + 2 = 4
    my @rules = $out =~ /(\+[-+]+\+)/g;
    is(scalar @rules, 4, 'full_grid: 4 horizontal rules (top, header, 2 rows)');
}

# --- full_grid + wrap ---
{
    my $fmt = make_fmt();
    my $data = [
        { title => 'Short', desc => 'A very long description that wraps around' },
    ];
    my $template = {
        type      => 'table',
        full_grid => 1,
        columns   => [
            { field => 'title', header => 'TITLE', width => 10 },
            { field => 'desc',  header => 'DESC',  width => 20, wrap => 1 },
        ],
    };
    my $out = $fmt->_render_table($data, $template);
    # Wrapped lines should also have pipes
    my @pipe_lines = grep { /^\|/ } split /\n/, $out;
    ok(scalar @pipe_lines >= 3, 'full_grid+wrap: wrapped lines also have pipes');
    # Rule comes after the wrapped block, not after each wrapped line
    my @all_lines = split /\n/, $out;
    like($all_lines[-1], qr/^\+[-+]+\+$/, 'full_grid+wrap: ends with rule');
}

# --- _render_record tests ---
{
    my $fmt = make_fmt();

    my $data = { shortname => 'BONN', longname => 'Bonn', km => 654.8 };
    my $template = {
        type   => 'record',
        fields => [
            { field => 'shortname', label => 'Station' },
            { field => 'longname',  label => 'Name' },
            { field => 'km',        label => 'Kilometer' },
        ],
    };

    my $out = $fmt->_render_record($data, $template);
    like($out, qr/Station\s+BONN/, 'record shows station');
    like($out, qr/Name\s+Bonn/, 'record shows name');
    like($out, qr/Kilometer\s+654\.8/, 'record shows km');
}

# --- format_output with json mode ---
{
    my $fmt = make_fmt();
    my $data = { foo => 'bar' };
    my $out = $fmt->format_output($data, 'anything', 'json');
    like($out, qr/"foo"\s*:\s*"bar"/, 'json mode outputs JSON');
}

# --- format_output with yaml mode ---
{
    my $fmt = make_fmt();
    my $data = { foo => 'bar' };
    my $out = $fmt->format_output($data, 'anything', 'yaml');
    like($out, qr/foo: bar/, 'yaml mode outputs YAML');
}

# --- format_output YAML fallback (no template) ---
{
    my $fmt = make_fmt();
    my $data = { some => 'data' };
    my $out = $fmt->format_output($data, 'nonexistent_endpoint', 'template');
    like($out, qr/some: data/, 'template mode falls back to YAML when no template');
}

# --- format_output with existing template (German) ---
{
    my $fmt = make_fmt(lang => 'de');
    my $data = { roads => [qw(A1 A2 A3)] };
    my $out = $fmt->format_output($data, 'autobahn_roads', 'template');
    like($out, qr/A1/, 'de template uses autobahn_roads template');
    like($out, qr/A2/, 'de template lists A2');
    like($out, qr/A3/, 'de template lists A3');
}

# --- format_output with existing template (English) ---
{
    my $fmt = make_fmt(lang => 'en');
    my $data = { roads => [qw(A1 A2 A3)] };
    my $out = $fmt->format_output($data, 'autobahn_roads', 'template');
    like($out, qr/A1/, 'en template uses autobahn_roads template');
}

# --- German roadworks template has German headers ---
{
    my $fmt = make_fmt(lang => 'de');
    my $data = {
        roadworks => [
            { title => 'Baustelle A1', subtitle => 'Koeln-Bonn', isBlocked => 'false' },
        ],
    };
    my $out = $fmt->format_output($data, 'autobahn_roadworks', 'template');
    like($out, qr/TITEL\s+UNTERTITEL\s+GESPERRT/, 'de roadworks has German headers');
    like($out, qr/Baustelle A1/, 'de roadworks shows title');
}

# --- English roadworks template has English headers ---
{
    my $fmt = make_fmt(lang => 'en');
    my $data = {
        roadworks => [
            { title => 'Construction A1', subtitle => 'Cologne-Bonn', isBlocked => 'false' },
        ],
    };
    my $out = $fmt->format_output($data, 'autobahn_roadworks', 'template');
    like($out, qr/TITLE\s+SUBTITLE\s+BLOCKED/, 'en roadworks has English headers');
}

# --- German pegel station has German labels ---
{
    my $fmt = make_fmt(lang => 'de');
    my $data = { shortname => 'BONN', longname => 'Bonn', water => { shortname => 'Rhein' },
                 km => 654.8, latitude => 50.7, longitude => 7.1, agency => 'WSA' };
    my $out = $fmt->format_output($data, 'pegel_online_station', 'template');
    like($out, qr/Gewaesser/, 'de pegel station has Gewaesser label');
    like($out, qr/Behoerde/, 'de pegel station has Behoerde label');
}

# --- English pegel station has English labels ---
{
    my $fmt = make_fmt(lang => 'en');
    my $data = { shortname => 'BONN', longname => 'Bonn', water => { shortname => 'Rhein' },
                 km => 654.8, latitude => 50.7, longitude => 7.1, agency => 'WSA' };
    my $out = $fmt->format_output($data, 'pegel_online_station', 'template');
    like($out, qr/Water/, 'en pegel station has Water label');
    like($out, qr/Agency/, 'en pegel station has Agency label');
}

# --- template_override ---
{
    my ($fh, $tmpfile) = tempfile(SUFFIX => '.yml', UNLINK => 1);
    print $fh "type: list\nfield: id\n";
    close $fh;

    my $fmt = make_fmt();
    $fmt->template_override($tmpfile);

    my $data = [{ id => 'X1' }, { id => 'X2' }];
    my $out = $fmt->format_output($data, 'whatever', 'template');
    like($out, qr/X1\nX2/, 'template override loads custom template');
}

# --- undef data (German) ---
{
    my $fmt = make_fmt(lang => 'de');
    my $out = $fmt->format_output(undef, 'test', 'template');
    like($out, qr/keine Daten/, 'de undef data returns (keine Daten)');
}

# --- undef data (English) ---
{
    my $fmt = make_fmt(lang => 'en');
    my $out = $fmt->format_output(undef, 'test', 'template');
    like($out, qr/no data/, 'en undef data returns (no data)');
}

done_testing;
