use strict;
use warnings;
use Test::More;
use open qw(:std :encoding(utf-8));

# Test that module loads
use_ok('App::Greple::md');

# Check greple is available
my $greple = `which greple 2>/dev/null`;
chomp $greple;
plan skip_all => "greple not found" unless $greple;

my $test_md = 't/test.md';
plan skip_all => "$test_md not found" unless -f $test_md;

my $cmd = "$^X -Ilib $greple";

# Basic output test
my $out = `$cmd -Mmd $test_md 2>/dev/null`;
ok(length($out) > 0, "greple -Mmd produces output");

# Output should contain ANSI escape sequences
like($out, qr/\e\[/, "output contains ANSI color sequences");

# Dark mode should also work
my $dark = `$cmd '-Mmd::config(mode=dark)' $test_md 2>/dev/null`;
ok(length($dark) > 0, "dark mode produces output");
like($dark, qr/\e\[/, "dark mode contains ANSI sequences");

# --cm override should work
my $override = `$cmd -Mmd --cm h1=RD -- $test_md 2>/dev/null`;
ok(length($override) > 0, "--cm override produces output");

# OSC 8 test: output should contain OSC 8 sequences for links
like($out, qr/\e\]8;;/, "output contains OSC 8 hyperlink sequences");

# ;sub{...} text transformation (hashed theme)
my $hashed = `$cmd -Mmd --cm 'h3=RD;sub{s/(?<!#)\$/ ###/r}' -- $test_md 2>/dev/null`;
my $strip = sub { local $_ = shift; s/\e\[[0-9;]*[mK]//g; $_ };
my ($h3_line) = map { $strip->($_) } grep { /Heading 3/ } split /\n/, $hashed;
like($h3_line, qr/### Heading 3 ###/, "sub{} appends closing hashes to h3");
my ($h4_line) = map { $strip->($_) } grep { /Heading 4/ } split /\n/, $hashed;
unlike($h4_line, qr/####$/, "sub{} on h3 does not affect h4");

# Empty ;sub{} suffix should not break colorization
my $no_sub = `$cmd -Mmd --cm 'h3=RD' -- $test_md 2>/dev/null`;
my ($h3_plain) = map { $strip->($_) } grep { /Heading 3/ } split /\n/, $no_sub;
unlike($h3_plain, qr/### Heading 3 ###/, "no sub{} means no closing hashes");

done_testing;
