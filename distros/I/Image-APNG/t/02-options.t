#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Temp qw(tempfile tempdir);
use Image::APNG;

plan skip_all => 'Image::Magick required for testing' unless eval { require Image::Magick; 1 } ;

plan tests => 10;

my $tempdir = tempdir(CLEANUP => 1) ;

sub create_test_png
{
my ($filename, $width, $height, $color) = @_ ;

my $image = Image::Magick->new(size => "${width}x${height}") ;
$image->Read("xc:$color") ;
$image->Write(filename => $filename) ;

return $filename ;
}

my $frame1 = create_test_png("$tempdir/frame1.png", 100, 100, 'red') ;
my $frame2 = create_test_png("$tempdir/frame2.png", 150, 150, 'blue') ;
my $frame3 = create_test_png("$tempdir/frame3.png", 120, 80, 'green') ;

my $frames = 
	[
		[$frame1, 100],
		[$frame2, 150],
		[$frame3, 100]
	] ;

my $result = Image::APNG::generate
		(
		$frames, 
		{
		loop_count           => 5,
		normalize_resolution => 1,
		background_color     => [255, 255, 255, 0]
		}) ;

is($result->{status}, 0, 'Generation with options succeeds') ;

$result = Image::APNG::generate($frames, { optimize_palette => 1 }) ;

is($result->{status}, 0, 'Palette optimization succeeds') ;

$result = Image::APNG::generate($frames, { normalize_resolution => 1, target_resolution => [200, 200] }) ;

is($result->{status}, 0, 'Target resolution option works') ;

$result = Image::APNG::generate([]) ;

is($result->{status}, 1, 'Empty frames returns error') ;
ok(scalar @{$result->{errors}} > 0, 'Error message provided') ;

$result = Image::APNG::generate(undef) ;

is($result->{status}, 1, 'Undefined frames returns error') ;

$result = Image::APNG::generate($frames, { disposal_method => 2, blend_operation => 0 }) ;

is($result->{status}, 0, 'Custom disposal and blend options work') ;

my $nonexistent = 
	[
		["$tempdir/nonexistent.png", 100]
	] ;

$result = Image::APNG::generate($nonexistent) ;

is($result->{status}, 1, 'Nonexistent file returns error') ;
ok(scalar @{$result->{errors}} > 0, 'Error message for missing file') ;

my $mixed = 
	[
		[$frame1, 100],
		["$tempdir/missing.png", 100],
		[$frame2, 100]
	] ;

$result = Image::APNG::generate($mixed) ;

ok(scalar @{$result->{errors}} > 0, 'Errors reported for missing frame in sequence') ;
