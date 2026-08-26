#!/usr/bin/env perl

use 5.006;
use strict;
use warnings;
use Test::More tests => 3;
use File::Temp qw(tempfile);
use Crypt::Image;

eval {
    require GD;
};
if ($@) {
    plan skip_all => 'GD is required for testing Crypt::Image';
}

# Create a temporary key image dynamically to satisfy FilePath validation
my ($fh_key, $key_file) = tempfile(SUFFIX => '.png', UNLINK => 1);
my $gd = GD::Image->new(100, 100);
my $white = $gd->colorAllocate(255, 255, 255);
$gd->rectangle(0, 0, 99, 99, $white);
print $fh_key $gd->png;
close $fh_key;

my (undef, $enc_file) = tempfile(SUFFIX => '.png', UNLINK => 1);

my $crypter = Crypt::Image->new(file => $key_file, type => 'png');

eval { $crypter->encrypt() };
like($@, qr/ERROR: Encryption text is missing./);

eval { $crypter->encrypt('Hello World') };
like($@, qr/ERROR: Decrypted file name is missing./);

# Key image is 100x100, so maximum text length is (100*100)-2 = 9998
my $too_long_text = 'A' x 9999;
eval { $crypter->encrypt($too_long_text, $enc_file) };
like($@, qr/ERROR: Encryption text is too long./);
