#!/usr/bin/env perl

use strict;
use warnings;
use lib '../lib';
use Image::APNG;

sub main
{
print "APNG Generator Example\n" ;
print "=" x 50 . "\n\n" ;

my $frames = 
	[
		['frame1.png', 100],
		['frame2.png', 150],
		['frame3.png', 100],
		['frame4.png', 200]
	] ;

my $options = 
	{
	loop_count           => 0,
	normalize_resolution => 1,
	background_color     => [255, 255, 255, 0],
	optimize_palette     => 0,
	disposal_method      => 1,
	blend_operation      => 1
	} ;

print "Generating APNG from frames...\n" ;
my $result = Image::APNG::generate($frames, $options) ;

if ($result->{status} == 0)
	{
	print "Success! APNG generated.\n" ;
	print "Data size: " . length($result->{data}) . " bytes\n" ;
	
	if (@{$result->{errors}})
		{
		print "\nWarnings encountered:\n" ;
		print "  - $_\n" for @{$result->{errors}} ;
		}
	
	my $output_file = 'output.png' ;
	open my $fh, '>', $output_file or die "Cannot write to $output_file: $!" ;
	binmode $fh ;
	print $fh $result->{data} ;
	close $fh ;
	
	print "\nAPNG saved to: $output_file\n" ;
	}
else
	{
	print "Failed to generate APNG!\n\n" ;
	print "Errors:\n" ;
	print "  - $_\n" for @{$result->{errors}} ;
	}
}

main() ;
