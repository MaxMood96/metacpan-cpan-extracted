use strict;
use warnings;
use Test::More;

BEGIN {
    plan skip_all => 'author test: set AUTHOR_TESTING=1' unless $ENV{AUTHOR_TESTING};
}

eval { require JSON::PP; 1 } or plan skip_all => 'JSON::PP not available';
plan skip_all => 'run perl Makefile.PL first' unless -r 'MYMETA.json';

# PAUSE treats a present `provides` as authoritative and does not scan the
# tarball, so a package missing from it is simply not indexed for that release
# -- and the namespace is not registered to the author either. It is fixable
# only before upload, which is exactly why it needs a test rather than a
# reviewer noticing.
open my $h, '<', 'MYMETA.json' or die "MYMETA.json: $!";
my $meta = JSON::PP->new->decode(do { local $/; <$h> });
close $h;

my $provides = $meta->{provides} || {};
ok scalar keys %$provides, 'META declares a provides map';

my @shipped = ('EV::Telegram::TDLib');
for my $f (glob 'lib/EV/Telegram/TDLib/*.pm') {
    (my $pkg = $f) =~ s{\Alib/}{};
    $pkg =~ s{/}{::}g;
    $pkg =~ s{\.pm\z}{};
    push @shipped, $pkg;
}

my @missing = grep { !$provides->{$_} } @shipped;
is "@missing", '', 'every shipped module is listed in provides'
    or diag "not indexed, and the namespace goes unregistered: @missing";

my %ship = map { $_ => 1 } @shipped;
my @extra = grep { !$ship{$_} } sort keys %$provides;
is "@extra", '', 'provides lists nothing that is not shipped'
    or diag "declared but absent: @extra";

# a provides entry pointing at the wrong file indexes nothing useful
my @badfile = grep { my $f = $provides->{$_}{file}; !$f || !-r $f } sort keys %$provides;
is "@badfile", '', 'every provides entry points at a readable file'
    or diag "bad file: @badfile";

done_testing;
