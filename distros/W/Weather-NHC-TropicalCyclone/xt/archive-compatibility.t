use strict;
use warnings;
use Test::More;
use File::Find qw/find/;
use File::Spec ();
use Weather::NHC::TropicalCyclone ();

my $root = $ENV{STORM_ARCHIVE};
plan skip_all => 'set STORM_ARCHIVE to a local StormSurgeLive/storm-archive checkout'
  if !defined $root || !-d $root;

my @json;
find(
    sub {
        return if !-f $_;
        push @json, $File::Find::name if /CurrentStorms\.json$/;
    },
    $root,
);

plan skip_all => "no CurrentStorms.json files found beneath $root" if !@json;

my $nhc = Weather::NHC::TropicalCyclone->new;
my @failed;
my %unknown;
for my $file ( sort @json ) {
    my $ok = eval { $nhc->load_file($file); 1 };
    push @failed, "$file: $@" if !$ok;
    $unknown{$_}++ for @{ $nhc->validation_warnings } if $ok;
}

ok !@failed, 'all archived CurrentStorms.json snapshots parse and validate'
  or diag join "\n", @failed;
diag sprintf 'checked %d archived CurrentStorms.json files', scalar @json;
diag "observed validation warning: $_ ($unknown{$_} snapshots)" for sort keys %unknown;

done_testing;
