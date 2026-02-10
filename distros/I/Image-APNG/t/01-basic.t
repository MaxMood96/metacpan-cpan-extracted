#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Temp qw(tempfile tempdir);
use Image::APNG;

plan skip_all => 'Image::Magick required for testing' unless eval { require Image::Magick; 1 } ;

plan tests => 8;

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
my $frame2 = create_test_png("$tempdir/frame2.png", 100, 100, 'blue') ;
my $frame3 = create_test_png("$tempdir/frame3.png", 100, 100, 'green') ;

my $frames = 
	[
		[$frame1, 100],
		[$frame2, 150],
		[$frame3, 100]
	] ;

my $result = Image::APNG::generate($frames) ;

ok(defined $result, 'generate() returns a result') ;
ok(ref $result eq 'HASH', 'Result is a hash reference') ;
ok(exists $result->{status}, 'Result has status key') ;
ok(exists $result->{errors}, 'Result has errors key') ;
ok(exists $result->{data}, 'Result has data key') ;

is($result->{status}, 0, 'Generation succeeds') ;
ok(defined $result->{data}, 'Data is defined') ;
ok(length($result->{data}) > 0, 'Data has content') ;
