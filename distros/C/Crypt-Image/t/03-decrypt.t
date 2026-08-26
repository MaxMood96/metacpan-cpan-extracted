#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Temp qw(tempfile);
use Crypt::Image;

eval {
    require GD;
};
if ($@) {
    plan skip_all => 'GD is required for testing Crypt::Image';
} else {
    plan tests => 3;
}

# 1. Create a key image on disk to pass file validation
my ($fh_key, $key_file) = tempfile(SUFFIX => '.png', UNLINK => 1);
my $gd = GD::Image->new(100, 100);
my $white = $gd->colorAllocate(255, 255, 255);
$gd->rectangle(0, 0, 99, 99, $white);
print $fh_key $gd->png;
close $fh_key;

# Prepare temporary path for the encrypted output image
my (undef, $enc_file) = tempfile(SUFFIX => '.png', UNLINK => 1);

# 2. Instantiate Crypt::Image with the key image
my $crypter = Crypt::Image->new(file => $key_file);
isa_ok($crypter, 'Crypt::Image');

# 3. Perform dynamic round-trip encryption & decryption
my $original_text = 'Hello World';

eval { $crypter->encrypt($original_text, $enc_file) };
if ($@) {
    diag("Encryption failed: $@");
}
ok(-f $enc_file && -s $enc_file, 'Encrypted image created successfully');

my $decrypted_text = eval { $crypter->decrypt($enc_file) };
if ($@) {
    diag("Decryption failed: $@");
}

is($decrypted_text, $original_text, 'Decrypted text matches original input');
