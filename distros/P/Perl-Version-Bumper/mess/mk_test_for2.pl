#!/usr/bin/perl
use v5.10;
use strict;
use warnings;

use Path::Tiny;
use Perl::Version::Bumper qw( version_use );

use Getopt::Long;

GetOptions( \my %option, 'save', 'force', 'debug' )
  or pod2usage(2);

die "At least one feature name is required!"
  unless @ARGV;

# find all test files
my %test_file = (
    map $_->basename('.data') =~ /\A[1-9][0-9]{2}_([a-z_]+)\z/g
    ? ( $1 => $_ )
    : (),
    path( t => 'bump' )->children
);

# load the list of features
my $feature_data = Perl::Version::Bumper->feature_data;

# setup some variables
my @vars = qw( feature known enabled disabled compat );
my ($vars) = map qr{$_}, join '|', reverse sort @vars;
our %vars;

# get all section templates
(undef, my @SECTIONS) = split /^(##########.*?$)/ms, do { local $/; <DATA> };

# process all requested features
for my $feature (@ARGV) {
    warn "Unknown feature '$feature'\n" and next
      unless exists $feature_data->{$feature};

    # pick the largest number available
    my $max = 100;
    $_ > $max and $max = $_
      for map $_->basename =~ /\A([0-9]+)_/ ? "$1" : (),
      values %test_file;
    $max++;

    # process each section
    my @sections = @SECTIONS;
    my $data = '';
    while ( my ( $title, $template ) = splice @sections, 0, 2 ) {

        # a list of ( condition, data chunk ) to be composed into the data file
	# the first condition is always true
        my @cond_tmpl = ( 1 => split /^(?:\?\?\?) +(.*)\n/m, $template );

        # populate variables
        @vars{@vars} = map $_ // 'undef', @{ $feature_data->{$feature} }{@vars};
        $vars{feature} = $feature;

        # special case of compat
        if ( $title =~ /\{compat\}/ ) {
            for my $compat ( sort keys %{ $feature_data->{$feature}{compat} } )
            {
                next
                  if $title =~ /use \{compat\}/
                  && $feature_data->{$feature}{compat}{$compat} < 0;
                next
                  if $title =~ /no \{compat\}/
                  && $feature_data->{$feature}{compat}{$compat} > 0;
                local $vars{compat} = $compat;
                ( my $temp = $title ) =~ s/\{($vars)\}/$vars{$1}/ge;
                $data .= $temp;

                # generate the data content
                for my $i ( 0 .. @cond_tmpl / 2 - 1 ) {
                    my ( $cond, $tmpl ) = @cond_tmpl[ 2 * $i, 2 * $i + 1 ];
                    $cond =~ s/\{($vars)\}/$vars{$1}/ge;
                    $data .= "# cond = $cond\n" if $option{debug};
                    $data .= "# $compat = $cond\n" if $option{debug};
                    if ( eval $cond ) {
                        ( my $chunk = $tmpl ) =~ s/\{($vars)\}/$vars{$1}/ge;
                        $data .= $chunk;
                    }
                }
            }
        }
        else {
            $title =~ s/\{($vars)\}/$vars{$1}/ge;
	    $data .= $title;

            # generate the data content
            for my $i ( 0 .. @cond_tmpl / 2 - 1 ) {
                my ( $cond, $tmpl ) = @cond_tmpl[ 2 * $i, 2 * $i + 1 ];
                $data .= "# cond = $cond\n" if $option{debug};
                $cond =~ s/\{($vars)\}/$vars{$1}/ge;
                $data .= "# cond = $cond\n" if $option{debug};
                if ( eval $cond ) {
                    ( my $chunk = $tmpl ) =~ s/\{($vars)\}/$vars{$1}/g;
                    $data .= $chunk;
                }
            }
        }
    }

    # reformat version
    $data =~ s/^--- (.*)/'--- ' . version_use($1)/gem;

    if ( $option{save} ) {
        if ( exists $test_file{$feature} ) {
            warn "A bump test file for '$feature' already exists: "
              . $test_file{$feature} . "\n";
            path( $test_file{$feature} )->spew($data)
              if $option{force};
        }
        else { path( t => bump => "${max}_$feature.data" )->spew($data); }
    }
    else { print $data; }
}

=pod
tests:

bump: assume the feature is known if used

use feature
- up until the feature is enabled
- after it's disabled

no feature
- after it's enabled

compat:
- for each compat
- if >= 0 use
- if <= 0 no

=cut

__DATA__
########## use feature '{feature}'
use feature '{feature}';
no warnings 'experimental::{feature}';
??? not defined {enabled}
---
use VERSION;
use feature '{feature}';
no warnings 'experimental::{feature}';
??? defined {enabled} && {enabled} == 5.010
---
use VERSION;
??? defined {enabled} && {enabled} > 5.010
---
use VERSION;
use feature '{feature}';
no warnings 'experimental::{feature}';
--- {enabled}
use VERSION;
??? defined {disabled} && {disabled} == 5.010
---
use VERSION;
??? defined {disabled}
--- {disabled}
use VERSION;
use feature '{feature}';
no warnings 'experimental::{feature}';
########## no feature '{feature}'
??? not defined {enabled}
use VERSION;
??? 1
no feature '{feature}';
??? defined {enabled} && {enabled} == 5.010
---
use VERSION;
no feature '{feature}';
??? defined {enabled} && {enabled} > 5.010
---
use VERSION;
--- {enabled}
use VERSION;
no feature '{feature}';
??? defined {disabled}
--- {disabled}
use VERSION;
########## use experimental '{feature}'
use experimental '{feature}';
??? not defined {enabled}
---
use VERSION;
use experimental '{feature}';
??? defined {enabled} && {enabled} == 5.010
---
use VERSION;
??? defined {enabled} && {enabled} > 5.010
---
use VERSION;
use experimental '{feature}';
--- {enabled}
use VERSION;
??? defined {disabled}
--- {disabled}
use VERSION;
use feature '{feature}';
########## no experimental '{feature}'
no experimental '{feature}';
??? not defined {enabled}
use VERSION;
??? defined {enabled} && {enabled} == 5.010
---
use VERSION;
no experimental '{feature}';
??? defined {enabled} && {enabled} > 5.010
---
use VERSION;
--- {enabled}
use VERSION;
no experimental '{feature}';
??? defined {disabled}
--- {disabled}
use VERSION;
########## use {compat}
use {compat};
??? {known} == 5.010 && defined {enabled} && {enabled} == 5.010
---
use VERSION;
??? {known} == 5.010 && defined {enabled} && {enabled} > 5.010
use VERSION;
use feature '{feature}';
no warnings 'experimental::{feature}';
--- {enabled}
use VERSION;
??? {known} > 5.010 && defined {enabled} && {known} < {enabled}
---
use VERSION;
use {compat};
--- {known}
use VERSION;
use feature '{feature}';
no warnings 'experimental::{feature}';
--- {enabled}
use VERSION;
??? defined {disabled}
---
use VERSION;
########## no {compat}
no {compat};
??? {known} == 5.010
---
use VERSION;
no feature '{feature}';
??? {known} > 5.010
---
use VERSION;
no {compat};
--- {known}
use VERSION;
no feature '{feature}';
??? defined {disabled}
--- {disabled}
use VERSION;
