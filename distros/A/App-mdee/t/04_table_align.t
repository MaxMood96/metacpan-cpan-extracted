use strict;
use warnings;
use Test::More;
use open qw(:std :encoding(utf-8));

use lib '.';
use t::Util;

# Unit tests for parse_separator
use_ok('App::Greple::md');

sub parse_separator { App::Greple::md::parse_separator(@_) }

# Right-aligned column
{
    my $block = "| A | B |\n|---|---:|\n| a | b |\n";
    my @opts = parse_separator(\$block);
    is_deeply(\@opts, ['--table-right=3'],
              "right-aligned column");
    unlike($block, qr/:/, "colons stripped from separator");
}

# Center-aligned column
{
    my $block = "| A | B |\n|---|:---:|\n| a | b |\n";
    my @opts = parse_separator(\$block);
    is_deeply(\@opts, ['--table-center=3'],
              "center-aligned column");
}

# Left-aligned (explicit) — no option generated
{
    my $block = "| A | B |\n|:---|:---|\n| a | b |\n";
    my @opts = parse_separator(\$block);
    is_deeply(\@opts, [],
              "left-aligned generates no options");
}

# Mixed alignment
{
    my $block = "| L | C | R | D |\n|:---|:---:|---:|---|\n| a | b | c | d |\n";
    my @opts = parse_separator(\$block);
    is_deeply(\@opts, ['--table-right=4', '--table-center=3'],
              "mixed alignment: right and center");
}

# No separator line
{
    my $block = "| A | B |\n| a | b |\n| c | d |\n";
    my @opts = parse_separator(\$block);
    is_deeply(\@opts, [],
              "no separator line returns empty");
}

# Multiple right-aligned columns
{
    my $block = "| A | B | C |\n|---:|---:|---:|\n| a | b | c |\n";
    my @opts = parse_separator(\$block);
    is_deeply(\@opts, ['--table-right=2,3,4'],
              "multiple right-aligned columns");
}

# Default (no colon) generates no options
{
    my $block = "| A | B | C |\n|---|---|---|\n| a | b | c |\n";
    my @opts = parse_separator(\$block);
    is_deeply(\@opts, [],
              "default alignment generates no options");
}

# Integration test: aligned table via greple
my $test_md = 't/test.md';

SKIP: {
    skip "$test_md not found", 3 unless -f $test_md;

    my $strip = sub { local $_ = shift; s/\e\[[0-9;]*[mK]//g; $_ };
    my $out = run("'-Mmd::config(colorize=0,table=1,rule=1)' $test_md")->stdout;
    my @lines = map { $strip->($_) } split /\n/, $out;

    # Find aligned table by looking for "Left" header
    my ($header_idx) = grep { $lines[$_] =~ /Left.*Center.*Right.*Default/ } 0..$#lines;
    ok(defined $header_idx, "aligned table found in output");

    SKIP: {
        skip "aligned table not found", 2 unless defined $header_idx;

        # Data rows: index +2 (header, separator, first data)
        my $row1 = $lines[$header_idx + 2];

        my $V = "\x{2502}";  # │

        # Right column: values should be right-aligned (leading spaces)
        like($row1, qr/${V}\s+c\s*${V}/, "right-aligned column has leading spaces");

        # Center column: values should have spaces on both sides
        like($row1, qr/${V}\s+b\s+${V}/, "center-aligned column has balanced spaces");
    }
}

done_testing;
