package Crypt::Image;

use strict;
use warnings;
use version;

our $VERSION   = qv('v1.0.1');
our $AUTHORITY = 'cpan:MANWAR';

=head1 NAME

Crypt::Image - Steganography interface to hide text within an image.

=head1 VERSION

Version v1.0.1

=cut

use GD::Image;
use POSIX qw/floor/;
use Crypt::Image::Util;
use Crypt::PRNG qw(irand);
use Types::Standard qw(Int);
use Crypt::Image::Params qw(FileType FilePath);

use Moo;
use namespace::autoclean;

=head1 DESCRIPTION

C<Crypt::Image> offers an innovative way of steganography that enables users
to incorporate secret messages into crucial pictures. The hidden message
spreads in a distributed fashion across the picture, while random noise that
doesn't carry the message fills up the remaining non-relevant areas of the
image with cryptographically sound noise.

C<RGB> conversion helps hide the message from detection systems that search
for image patterns in different pictures created with the same key. The
encoding is done randomly across the C<R>, C<G> and C<B> channels, meaning
that the original C<RGB> values are altered by adding/subtracting the
encoded C<UTF> value. Hence, regardless of the fact that the same key image
and message may be used, the resulting picture will be different every time,
thus destroying all data pixels in sound noise.

=cut

our $INTENSITY = 30;

has 'width'  => (is => 'ro', isa => Int);
has 'height' => (is => 'ro', isa => Int);
has 'file'   => (is => 'ro', isa => FilePath, required => 1);
has 'type'   => (is => 'ro', isa => FileType, default => sub { return 'png'; });
has 'bytes'  => (is => 'rw', isa => Int);
has 'countc' => (is => 'rw', isa => Int);

=head1 CONSTRUCTOR

The constructor takes at the least the location key image,currently only supports
PNG  format.  Make  sure your key image is not TOO BIG.

    use strict; use warnings;
    use Crypt::Image;

    my $crypter = Crypt::Image->new(file => 'your_key_image.png');

=cut

sub BUILD {
    my ($self) = @_;

    $self->{key}    = GD::Image->new($self->{file});
    $self->{width}  = $self->{key}->width;
    $self->{height} = $self->{key}->height;
    $self->{bytes}  = ($self->{width} * $self->{height}) - 2;
    GD::Image->trueColor(1);
}

=head1 METHODS

=head2 encrypt($message, $encrypted_image_name)

Encrypts and embeds text into the key image using steganography, saving the
result to a new file.

    use strict; use warnings;
    use Crypt::Image;

    my $crypter = Crypt::Image->new(file => 'your_key_image.png');
    $crypter->encrypt('Hello World', 'your_new_encrypted_image.png');

=cut

sub encrypt {
    my ($self, $text, $file) = @_;

    die("ERROR: Encryption text is missing.\n")     unless defined $text;
    die("ERROR: Decrypted file name is missing.\n") unless defined $file;
    die("ERROR: Encryption text is too long.\n")    if ($self->{bytes} < length($text));

    my ($width, $height, $allowed, $count);
    $self->{copy} = Crypt::Image::Util::cloneImage($self->{key});
    $allowed = int(floor($self->{bytes}/length($text)));
    $self->_encryptAllowed($allowed, 1, 1);
    $self->{countc} = 0;
    $count = 0;

    foreach $width (0..$self->{width}-1) {
        foreach $height (0..$self->{height}-1) {
            unless (($width == 1) && ($height == 1)) {
                $count++;
                if ($count == $allowed) {
                    $self->_encrypt($width, $height, $self->_next($text));
                    $count = 0;
                }
                else {
                    $self->_encrypt($width, $height, 0);
                }
            }
        }
    }

    Crypt::Image::Util::saveImage($file, $self->{copy}, $self->{type});
}

=head2 decrypt($encrypted_image)

Extracts and decrypts hidden steganographic text from the specified image file.

    use strict; use warnings;
    use Crypt::Image;

    my $crypter = Crypt::Image->new(file => 'your_key_image.png');
    $crypter->encrypt('Hello World', 'your_new_encrypted_image.png');
    print "Text: [" . $crypter->decrypt('your_new_encrypted_image.png') . "]\n";

=cut

sub decrypt {
    my ($self, $file) = @_;

    die("ERROR: Encrypted file missing.\n")           unless defined $file;
    die("ERROR: Encrypted file [$file] not found.\n") unless (-f $file);

    my ($allowed, $count, $text, $width, $height);

    $self->{copy} = GD::Image->new($file);
    $allowed = $self->_decryptAllowed(1, 1);
    $count   = 0;
    $text    = '';

    foreach $width (0..$self->{width}-1) {
        foreach $height (0..$self->{height}-1) {
            unless (($width == 1) && ($height == 1)) {
                $count++;
                if ($count == $allowed) {
                    $text .= $self->_decrypt($width, $height);
                    $count = 0;
                }
            }
        }
    }
    return $text;
}

sub _encrypt {
    my ($self, $x, $y, $a) = @_;

    my ($r, $g, $b, $i, $axis);
    ($r,$g,$b) = Crypt::Image::Util::getPixelColorRGB($self->{key}, $x, $y);
    if ($a == 0) {
        $i = irand() % $INTENSITY;
        $b = Crypt::Image::Util::moveUp($b, $i);
        $i = irand() % $INTENSITY;
        $g = Crypt::Image::Util::moveUp($g, $i);
        $i = irand() % $INTENSITY;
        $r = Crypt::Image::Util::moveUp($r, $i);
    }
    else {
        $axis = Crypt::Image::Util::splitInThree($a);
        $b = Crypt::Image::Util::moveUp($b, $axis->x);
        $g = Crypt::Image::Util::moveUp($g, $axis->y);
        $r = Crypt::Image::Util::moveUp($r, $axis->z);
    }

    $self->{copy}->setPixel($x, $y, Crypt::Image::Util::getColor($r, $g, $b));
}

sub _decrypt {
    my ($self, $x, $y) = @_;

    my ($r, $g, $b) = Crypt::Image::Util::differenceInAxis($self->{key}, $self->{copy}, $x, $y);

    return chr($r+$g+$b);
}

sub _encryptAllowed {
    my ($self, $allowed, $x, $y) = @_;

    my ($r, $g, $b, $axis, $count);
    $count = 0;
    ($r,$g,$b) = Crypt::Image::Util::getPixelColorRGB($self->{key}, $x, $y);

    while ($allowed > 127) {
        $count++;
        $allowed -= 127;
    }

    if ($count > 0) {
        $axis = Crypt::Image::Util::splitInTwo($count);
        $r    = Crypt::Image::Util::moveDown($r, $axis->x);
        $g    = Crypt::Image::Util::moveDown($g, $axis->y);
    }

    $b = Crypt::Image::Util::moveDown($b, $allowed)
        if ($allowed <= 127);

    $self->{copy}->setPixel($x, $y, Crypt::Image::Util::getColor($r, $g, $b));
}

sub _decryptAllowed {
    my ($self, $x, $y) = @_;

    my ($r, $g, $b) = Crypt::Image::Util::differenceInAxis($self->{key}, $self->{copy}, $x, $y);
    return (($r*127)+($g*127)+$b);
}

sub _next {
    my ($self, $text) = @_;

    my $a = 0;
    if (length($text) > $self->{countc}) {
        $a = ord(substr($text, $self->{countc}, 1));
        $self->{countc}++;
    }

    return $a;
}

=head1 AUTHOR

Mohammad Sajid Anwar, C<< <mohammad.anwar at yahoo.com> >>

=head1 REPOSITORY

L<https://github.com/manwar/Crypt-Image>

=head1 BUGS

Please report any bugs / feature requests through the web interface at L<https://github.com/manwar/Crypt-Image/issues>.
I will be notified, and then you'll automatically be notified of progress on your
bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Crypt::Image

You can also look for information at:

=over 4

=item * ISSUES

L<https://github.com/manwar/Crypt-Image/issues>

=item * Search MetaCPAN

L<https://metacpan.org/dist/Crypt-Image>

=back

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2011 - 2026 Mohammad Sajid Anwar.

This program is free software; you can redistribute it and/or modify it under
the terms of the Artistic License (2.0).

=cut

1; # End of Crypt::Image
