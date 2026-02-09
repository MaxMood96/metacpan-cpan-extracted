#!/usr/bin/perl
use v5.10;
use strict;
use warnings;

use Path::Tiny;
use Perl::Version::Bumper qw( version_use );

die "At least one feature name is required!"
  unless @ARGV;

# find all test files
my @test_types = qw( bump );
my %test_file;
$test_file{$_} = {
    map $_->basename('.data') =~ /\A[1-9][0-9]{2}_([a-z_]+)\z/g
    ? ( $1 => $_ )
    : (),
    path( t => $_ )->children
  }
  for @test_types;

my $feature_data = Perl::Version::Bumper->feature_data;
my %template = (
    bump => sub {
        my ($feature) = @_;
	my $info = $feature_data->{$feature};
        my $test = '';

        # use feature
        $test .= << "TEST";
########## feature $feature
use feature '$feature';
TEST
        if ( $info->{enabled} ) {
            my $version = version_use( $info->{enabled} );
            $test .= $info->{enabled} == 5.010
              ? << "TEST"
---
use VERSION;
TEST
              : << "TEST";
---
use VERSION;
use feature '$feature';
--- $version
use VERSION;
TEST
        }
	else {
            $test .= << "TEST";
---
use VERSION;
use feature '$feature';
TEST
	}

        if ( $info->{disabled} ) {
            my $version = version_use( $info->{disabled} );
            $test .= << "TEST";
--- $version
use VERSION;
use feature '$feature';
TEST
        }

	# no feature
        $test .= << "TEST";
########## no feature $feature
no feature '$feature';
---
use VERSION;
no feature '$feature';
TEST
        if ( $info->{disabled} ) {
            my $version = version_use( $info->{disabled} );
            $test .= << "TEST";
--- $version
use VERSION;
TEST
        }

        if ( $info->{compat} ) {
            for my $compat ( sort keys %{ $info->{compat} } ) {
                if ( $info->{compat}{$compat} >= 0 ) {    # import
                    $test .= << "TEST";
########## feature $feature replaces $compat
use $compat;
TEST
                    if ( $info->{enabled} ) {
                        my $version = version_use( $info->{known} );
                        $test .= $info->{enabled} == 5.010
                          ? << "TEST"
---
use VERSION;
TEST
                          : << "TEST";
---
use VERSION;
use $compat;
--- $version
use VERSION;
TEST
                    }
                }
		# cases:
		# - known < enabled => can replace
		#
                if ( $info->{compat}{$compat} <= 0 ) {    # unimport
                    $test .= << "TEST";
########## no feature $feature replaces no $compat
no $compat;
TEST
                    if ( $info->{disabled} ) {
                        $test .= << "TEST";
########## no feature $feature replaces no $compat
no $compat;
TEST
                        my $version = version_use( $info->{disabled} );
                        $test .= << "TEST";
---
use VERSION;
no $compat;
--- $version
use VERSION;
TEST
                    }
                }
            }
        }

	return $test;
    },
);

for my $feature (@ARGV) {
    warn "Unknown feature '$feature'\n" and next
      unless exists $feature_data->{$feature};
    for my $test_type (@test_types) {
        if ( exists $test_file{$test_type}{$feature} ) {
            warn "A $test_type test file for '$feature' already exists: "
              . $test_file{$test_type}{$feature} . "\n";
            next;
        }
        else {
            # pick the largest number available
            my $max = 100;
            $_ > $max and $max = $_
              for map $_->basename =~ /\A([0-9]+)_/ ? "$1" : (),
              values %{ $test_file{$test_type} };
            $max++;

            # create the file
	    my $file = path( t => $test_type => "${max}_$feature.data" );
	    say "Creating $file\n";
            $file->spew( $template{$test_type}->($feature) );
	    $test_file{$test_type}{$feature} = $file;
        }
    }
}

