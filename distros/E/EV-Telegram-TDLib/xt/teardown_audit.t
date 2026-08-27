use strict;
use warnings;
use Test::More;
use Config;

plan skip_all => 'author test: set AUTHOR_TESTING=1' unless $ENV{AUTHOR_TESTING};

# A client still materialised when the process exits is a real crash window,
# not a tidy leak: TDLib skips client teardown once exit has begun and detaches
# its scheduler thread rather than joining it. This runs every t/ file with a
# hook that reports any such client, so the invariant is enforced mechanically
# instead of relying on each test to be careful.

my @tests = sort glob 't/*.t';
plan tests => scalar @tests;

for my $t (@tests) {
    my $out = `"$Config{perlpath}" -Iblib/lib -Iblib/arch -Ixt/lib -MTeardownAudit $t 2>&1`;
    my ($live) = $out =~ /TEARDOWN-AUDIT-LIVE: (.+)/;
    ok !$live, "$t leaves no client materialised at exit"
        or diag "still live: $live";
}

done_testing;
