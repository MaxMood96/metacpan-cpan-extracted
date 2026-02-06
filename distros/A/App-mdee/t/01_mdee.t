use v5.14;
use warnings;
use utf8;

use Test::More;
use File::Spec;

# Skip tests on platforms without bash or with old bash
BEGIN {
    my $bash_check = `bash --version 2>&1`;
    if ($? != 0) {
        plan skip_all => 'bash is not available on this system';
    }
    if ($bash_check =~ /version (\d+)\.(\d+)/) {
        my ($major, $minor) = ($1, $2);
        if ($major < 4 || ($major == 4 && $minor < 3)) {
            plan skip_all => "bash 4.3+ required (found $major.$minor)";
        }
    }
}

# Skip if getoptlong.sh is not available
BEGIN {
    my $check = `command -v getoptlong.sh 2>/dev/null`;
    if ($? != 0) {
        plan skip_all => 'getoptlong.sh is not available in PATH';
    }
}

my $mdee = File::Spec->rel2abs('script/mdee');
my $test_md = File::Spec->rel2abs('t/test.md');

# Check if mdee exists
ok(-x $mdee, 'mdee is executable');

# Test: help option
subtest 'help option' => sub {
    my $out = `$mdee --help 2>&1`;
    like($out, qr/dee.*Markdown/i, '--help shows description');
    like($out, qr/--mode/, '--help shows --mode option');
    like($out, qr/--theme/, '--help shows --theme option');
    like($out, qr/--filter/, '--help shows --filter option');
    like($out, qr/\[no-\]fold/, '--help shows --fold option');
    like($out, qr/\[no-\]table/, '--help shows --table option');
    like($out, qr/\[no-\]nup/, '--help shows --nup option');
};

# Test: version option
subtest 'version option' => sub {
    my $out = `$mdee --version 2>&1`;
    like($out, qr/^\d+\.\d+/, '--version shows version number');
};

# Test: dryrun option
subtest 'dryrun option' => sub {
    my $out = `$mdee --dryrun $test_md 2>&1`;
    like($out, qr/greple/, '--dryrun shows greple command');
    like($out, qr/nup/, '--dryrun shows nup command');
};

# Test: mode option
subtest 'mode option' => sub {
    my $out_light = `$mdee --mode=light -s cat $test_md 2>&1`;
    my $out_dark = `$mdee --mode=dark -s cat $test_md 2>&1`;
    isnt($out_light, $out_dark, 'light and dark modes produce different output');
};

# Test: no-nup option
subtest 'no-nup option' => sub {
    my $out = `$mdee --dryrun --no-nup $test_md 2>&1`;
    unlike($out, qr/run_nup/, '--no-nup excludes nup from pipeline');
};

# Test: no-fold option
subtest 'no-fold option' => sub {
    my $out = `$mdee --dryrun --no-fold $test_md 2>&1`;
    unlike($out, qr/run_fold/, '--no-fold excludes fold from pipeline');
};

# Test: no-table option
subtest 'no-table option' => sub {
    my $out = `$mdee --dryrun --no-table $test_md 2>&1`;
    unlike($out, qr/run_table/, '--no-table excludes table from pipeline');
};

# Test: filter option
subtest 'filter option' => sub {
    my $out = `$mdee --dryrun -f $test_md 2>&1`;
    unlike($out, qr/run_fold/, '-f disables fold');
    like($out, qr/run_table/, '-f keeps table enabled');
    unlike($out, qr/run_nup/, '-f disables nup');
};

# Test: style option
subtest 'style option' => sub {
    my $nup = `$mdee --dryrun --style=nup $test_md 2>&1`;
    like($nup, qr/run_fold/, '--style=nup includes fold');
    like($nup, qr/run_table/, '--style=nup includes table');
    like($nup, qr/run_nup/, '--style=nup includes nup');

    my $pager = `$mdee --dryrun --style=pager $test_md 2>&1`;
    like($pager, qr/run_fold/, '--style=pager includes fold');
    like($pager, qr/run_table/, '--style=pager includes table');
    unlike($pager, qr/run_nup/, '--style=pager excludes nup');
    like($pager, qr/run_pager/, '--style=pager includes pager');

    my $cat = `$mdee --dryrun --style=cat $test_md 2>&1`;
    like($cat, qr/run_fold/, '--style=cat includes fold');
    like($cat, qr/run_table/, '--style=cat includes table');
    unlike($cat, qr/run_nup/, '--style=cat excludes nup');

    my $filter = `$mdee --dryrun --style=filter $test_md 2>&1`;
    unlike($filter, qr/run_fold/, '--style=filter excludes fold');
    like($filter, qr/run_table/, '--style=filter includes table');
    unlike($filter, qr/run_nup/, '--style=filter excludes nup');

    my $raw = `$mdee --dryrun --style=raw $test_md 2>&1`;
    unlike($raw, qr/run_fold/, '--style=raw excludes fold');
    unlike($raw, qr/run_table/, '--style=raw excludes table');
    unlike($raw, qr/run_nup/, '--style=raw excludes nup');

    my $bogus = `$mdee --dryrun --style=bogus $test_md 2>&1`;
    like($bogus, qr/unknown style/, '--style=bogus produces error');
};

# Test: plain option
subtest 'plain option' => sub {
    my $out = `$mdee --dryrun -p $test_md 2>&1`;
    like($out, qr/run_fold/, '-p includes fold');
    like($out, qr/run_table/, '-p includes table');
    unlike($out, qr/run_nup/, '-p excludes nup');
    like($out, qr/run_pager/, '-p includes pager');
};

# Test: style override
subtest 'style override' => sub {
    my $out = `$mdee --dryrun -f --fold $test_md 2>&1`;
    like($out, qr/run_fold/, '-f --fold enables fold');
    unlike($out, qr/run_nup/, '-f --fold keeps nup disabled');

    my $out2 = `$mdee --dryrun -p --no-fold $test_md 2>&1`;
    unlike($out2, qr/run_fold/, '-p --no-fold disables fold');
    like($out2, qr/run_pager/, '-p --no-fold keeps pager');
};

# Test: list-themes option
subtest 'list-themes option' => sub {
    my $out = `$mdee --list-themes 2>&1`;
    like($out, qr/Available themes/i, '--list-themes shows themes');
    like($out, qr/default/, '--list-themes shows default theme');
};

# Test: theme name listing (-t ?)
subtest 'theme name listing' => sub {
    my $out = `$mdee --theme='?' 2>&1`;
    is($?, 0, '--theme=? exits successfully');
    like($out, qr/^default$/m, '--theme=? lists default theme');
};

# Test: width option
subtest 'width option' => sub {
    # Use actual execution: narrow width should produce more lines than wide
    my $narrow = `$mdee -s cat --width=30 $test_md 2>&1`;
    my $wide   = `$mdee -s cat --width=200 $test_md 2>&1`;
    my @narrow_lines = split /\n/, $narrow;
    my @wide_lines   = split /\n/, $wide;
    ok(@narrow_lines > @wide_lines, '--width=30 produces more lines than --width=200');
};

# Test: tee module with fold (actual execution)
subtest 'tee fold execution' => sub {
    # Use a narrow width to force folding of long lines
    # Line 77 in test.md has a long description that should wrap
    my $out = `$mdee --no-nup --no-table --fold --width=40 $test_md 2>&1`;
    is($?, 0, 'mdee with fold exits successfully');
    # The long line should be wrapped, resulting in more lines than original
    my @lines = split /\n/, $out;
    ok(@lines > 10, 'fold produces wrapped output');
    # Check that ANSI sequences are present (greple highlighting worked)
    like($out, qr/\e\[/, 'output contains ANSI escape sequences');
};

# Test: list marker patterns in fold
subtest 'list marker patterns' => sub {
    use File::Temp qw(tempfile);
    my $long = "x" x 80;

    # Helper: count output lines from fold
    my $fold_lines = sub {
        my ($input) = @_;
        my ($fh, $tmp) = tempfile(SUFFIX => '.md', UNLINK => 1);
        print $fh $input;
        close $fh;
        my $out = `$mdee --no-nup --no-table --fold --width=40 --mode=light $tmp 2>&1`;
        return split /\n/, $out;
    };

    # 1. (traditional) should fold
    ok($fold_lines->("1. $long\n") > 1, '1. list item is folded');

    # 1) (CommonMark paren) should fold
    ok($fold_lines->("1) $long\n") > 1, '1) list item is folded');

    # #. (Pandoc auto-number) should fold
    ok($fold_lines->("    #. $long\n") > 1, '#. list item is folded');

    # #) should fold
    ok($fold_lines->("    #) $long\n") > 1, '#) list item is folded');
};

# Test: tee module with table (actual execution)
subtest 'tee table execution' => sub {
    # Run with table formatting enabled
    my $out = `$mdee --no-nup --no-fold --table $test_md 2>&1`;
    is($?, 0, 'mdee with table exits successfully');
    # Table should be formatted with aligned columns
    # The separator line |---|---|---| should have consistent dashes
    like($out, qr/\|-+\|-+\|-+\|/, 'table separator is formatted');
    # Check that ANSI sequences are present
    like($out, qr/\e\[/, 'output contains ANSI escape sequences');
};

# Test: tee module combined (fold + table)
subtest 'tee combined execution' => sub {
    my $out = `$mdee --no-nup --fold --table --width=60 $test_md 2>&1`;
    is($?, 0, 'mdee with fold+table exits successfully');
    like($out, qr/\e\[/, 'output contains ANSI escape sequences');
    # Both table formatting and text should be present
    like($out, qr/greple.*Pattern matching/s, 'table content is present');
};

# Test: show option
subtest 'show option' => sub {
    # Count -E options in run_greple debug line (identified by --ci=G)
    sub count_patterns {
        my $out = shift;
        my ($line) = $out =~ /^(debug: greple\h.*--ci=G\h.*)/m;
        return 0 unless $line;
        return () = $line =~ /\h-E\h/g;
    }

    # all fields enabled by default (17 patterns)
    my $default = `$mdee -ddn $test_md 2>&1`;
    is(count_patterns($default), 17, 'default has 17 patterns');

    # --show italic=0 disables italic (15 patterns: 17 - 2 italic patterns)
    my $no_italic = `$mdee -ddn --show italic=0 $test_md 2>&1`;
    is(count_patterns($no_italic), 15, '--show italic=0 removes 2 patterns');

    # --show bold=0 disables bold (15 patterns: 17 - 2 bold patterns)
    my $no_bold = `$mdee -ddn --show bold=0 $test_md 2>&1`;
    is(count_patterns($no_bold), 15, '--show bold=0 removes 2 patterns');

    # --show all enables all fields (17 patterns)
    my $all = `$mdee -ddn --show all $test_md 2>&1`;
    is(count_patterns($all), 17, '--show all has 17 patterns');

    # --show h6=0 disables h6 (16 patterns: 17 - 1 h6 pattern)
    my $no_h6 = `$mdee -ddn --show h6=0 $test_md 2>&1`;
    is(count_patterns($no_h6), 16, '--show h6=0 removes 1 pattern');

    # --show all= --show bold enables only bold (2 patterns)
    my $only_bold = `$mdee -ddn '--show=all=' --show=bold $test_md 2>&1`;
    is(count_patterns($only_bold), 2, '--show all= --show bold has 2 patterns');

    # unknown field should error
    my $unknown = `$mdee --dryrun --show unknown $test_md 2>&1`;
    like($unknown, qr/unknown field/, '--show unknown produces error');
};

# Test: config file defaults
subtest 'config file defaults' => sub {
    use File::Temp qw(tempdir);
    my $tmpdir = tempdir(CLEANUP => 1);
    my $config_dir = "$tmpdir/mdee";
    mkdir $config_dir;

    # Test default[style]
    {
        open my $fh, '>', "$config_dir/config.sh" or die;
        print $fh "default[style]='pager'\n";
        close $fh;
        my $out = `XDG_CONFIG_HOME=$tmpdir $mdee --dryrun --mode=light $test_md 2>&1`;
        like($out, qr/run_pager/, 'default[style]=pager adds pager');
        unlike($out, qr/run_nup/, 'default[style]=pager removes nup');
    }

    # Test default[width]
    {
        open my $fh, '>', "$config_dir/config.sh" or die;
        print $fh "default[width]=40\n";
        close $fh;
        my $out = `XDG_CONFIG_HOME=$tmpdir $mdee -ddn --mode=light $test_md 2>&1`;
        like($out, qr/-sw40\b/, 'default[width]=40 sets fold width');
    }

    # Test default[base_color]
    {
        open my $fh, '>', "$config_dir/config.sh" or die;
        print $fh "default[base_color]='Crimson'\n";
        close $fh;
        my $out = `XDG_CONFIG_HOME=$tmpdir $mdee -d --dryrun --mode=light $test_md 2>&1`;
        like($out, qr/Crimson/, 'default[base_color]=Crimson is applied');
    }

    # Test command-line overrides config defaults
    {
        open my $fh, '>', "$config_dir/config.sh" or die;
        print $fh "default[style]='pager'\ndefault[width]=40\n";
        close $fh;
        my $out = `XDG_CONFIG_HOME=$tmpdir $mdee --dryrun --mode=light -s nup -w 120 $test_md 2>&1`;
        like($out, qr/run_nup/, '-s nup overrides default[style]=pager');
    }

    # Test custom theme defined in config.sh
    {
        open my $fh, '>', "$config_dir/config.sh" or die;
        print $fh <<'CONF';
declare -A theme_custom_light=(
    [base]='<DarkCyan>=y25'
    [comment]='${base}+r60'
    [bold]='${base}D'
    [strike]='X'
    [italic]='I'
    [link]="$link_func"
    [image]="$image_func"
    [image_link]="$image_link_func"
    [h1]='L25DE/${base}'
    [h2]='L25DE/${base}+y20'
    [h3]='L25DN/${base}+y30'
    [h4]='${base}UD'
    [h5]='${base}+y20;U'
    [h6]='${base}+y20'
    [inline_code]='L15/L23,/L23,L15/L23'
    [code_block]='L20 , L18 , /L23;E , L20'
)
CONF
        close $fh;
        my $out = `XDG_CONFIG_HOME=$tmpdir $mdee -d --dryrun --mode=light --theme=custom $test_md 2>&1`;
        like($out, qr/DarkCyan/, 'custom theme from config.sh is loaded');
    }

    # Test theme partial override in config.sh
    {
        open my $fh, '>', "$config_dir/config.sh" or die;
        print $fh "theme_default_light[base]='<Crimson>=y25'\n";
        close $fh;
        my $out = `XDG_CONFIG_HOME=$tmpdir $mdee -d --dryrun --mode=light $test_md 2>&1`;
        like($out, qr/Crimson/, 'theme partial override in config.sh works');
    }

    # Test --base-color overrides config theme override
    {
        open my $fh, '>', "$config_dir/config.sh" or die;
        print $fh "theme_default_light[base]='<Crimson>=y25'\n";
        close $fh;
        my $out = `XDG_CONFIG_HOME=$tmpdir $mdee -d --dryrun --mode=light -B Ivory $test_md 2>&1`;
        like($out, qr/Ivory/, '--base-color overrides config theme override');
        unlike($out, qr/Crimson/, '--base-color takes priority over config');
    }
};

# Test: external theme file loading
subtest 'external theme file' => sub {
    use File::Temp qw(tempdir);
    my $tmpdir = tempdir(CLEANUP => 1);
    my $theme_dir = "$tmpdir/mdee/theme";
    system("mkdir -p $theme_dir") == 0 or die "mkdir failed";

    # Create a test theme file
    open my $fh, '>', "$theme_dir/testtheme.sh" or die;
    print $fh <<'THEME';
declare -gA theme_testtheme_light=(
    [base]='<Crimson>=y25'
    [comment]='${base}+r60'
    [bold]='${base}D'
    [strike]='X'
    [italic]='I'
    [link]="$link_func"
    [image]="$image_func"
    [image_link]="$image_link_func"
    [h1]='L25DE/${base}'
    [h2]='L25DE/${base}+y20'
    [h3]='L25DN/${base}+y30'
    [h4]='${base}UD'
    [h5]='${base}+y20;U'
    [h6]='${base}+y20'
    [inline_code]='L15/L23,/L23,L15/L23'
    [code_block]='L20 , L18 , /L23;E , L20'
)
declare -gA theme_testtheme_dark=(
    [base]='<Crimson>=y80'
    [h1]='L00DE/${base}'
    [h2]='L00DE/${base}-y15'
    [h3]='L00DN/${base}-y25'
    [inline_code]='L12/L05,/L05,L12/L05'
    [code_block]='L10 , L12 , /L05;E , L10'
)
THEME
    close $fh;

    # Test loading external theme
    my $out = `XDG_CONFIG_HOME=$tmpdir $mdee -d --dryrun --mode=light --theme=testtheme $test_md 2>&1`;
    is($?, 0, 'external theme loads successfully');
    like($out, qr/Crimson/, 'external theme base color is applied');

    # Test dark mode with external theme (inherits from light)
    my $dark = `XDG_CONFIG_HOME=$tmpdir $mdee -d --dryrun --mode=dark --theme=testtheme $test_md 2>&1`;
    is($?, 0, 'external dark theme loads successfully');
    like($dark, qr/Crimson/, 'external dark theme has base color');

    # Test --list-themes shows external theme
    my $list = `XDG_CONFIG_HOME=$tmpdir $mdee --list-themes 2>&1`;
    like($list, qr/testtheme/, '--list-themes shows external theme');

    # Test --theme=FILE (file path direct loading)
    my $out_file = `XDG_CONFIG_HOME=$tmpdir $mdee -d --dryrun --mode=light --theme=$theme_dir/testtheme.sh $test_md 2>&1`;
    is($?, 0, '--theme=FILE loads successfully');
    like($out_file, qr/Crimson/, '--theme=FILE applies theme colors');

    # Test nonexistent theme produces error
    my $err = `XDG_CONFIG_HOME=$tmpdir $mdee --dryrun --mode=light --theme=nonexistent $test_md 2>&1`;
    isnt($?, 0, 'nonexistent theme fails');
    like($err, qr/theme not found/, 'nonexistent theme produces error');
};

# Test: share directory theme loading (warm theme)
subtest 'share theme warm' => sub {
    my $share = File::Spec->rel2abs('share/theme/warm.sh');
    plan skip_all => 'share/theme/warm.sh not found' unless -f $share;
    my $out = `$mdee -d --dryrun --mode=light --theme=warm $test_md 2>&1`;
    is($?, 0, 'warm theme loads successfully');
    like($out, qr/Coral/, 'warm theme uses Coral base color');
};

done_testing;
