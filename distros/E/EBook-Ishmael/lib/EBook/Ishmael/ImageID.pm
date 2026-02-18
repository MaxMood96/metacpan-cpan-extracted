package EBook::Ishmael::ImageID;
use 5.016;
our $VERSION = '2.00';
use strict;
use warnings;

use Exporter 'import';
our @EXPORT = qw(image_id image_size is_image_path);

use List::Util qw(max);

use XML::LibXML;

my $IMGRX = sprintf "(%s)", join '|', qw(
    png jpg jpeg tif tiff gif bmp webp svg jxl avif
);

# This function may not support many image formats as it was designed for
# getting image sizes for CHM files to determine the cover image. CHMs
# primarily use GIFs.
# TODO: Add tif support
# TODO: Add webp support (probably never)
my %SIZE = (
    # size stored as two BE ushorts in the SOF0 marker, at offset 5.
    'jpg' => sub {

        my $ref = shift;

        my $len = length $$ref;

        my $p = 2;

        my $sof = join ' ', 0xff, 0xc0;

        while ($p < $len) {

            my $id = join ' ', unpack "CC", substr $$ref, $p, 2;
            $p += 2;
            my $mlen = unpack "n", substr $$ref, $p, 2;

            unless ($id eq $sof) {
                $p += $mlen;
                next;
            }

            my ($y, $x) = unpack "nn", substr $$ref, $p + 3, 4;

            return [ $x, $y ];

        }

        return undef;

    },
    # size stored as two BE ulongs at offset 16
    'png' => sub {

        my $ref = shift;

        return undef unless length $$ref > 24;

        my ($x, $y) = unpack "N N", substr $$ref, 16, 8;

        return [ $x, $y ];

    },
    # size stored as two LE ushorts at offset 6
    'gif' => sub {

        my $ref = shift;

        return undef unless length $$ref > 10;

        my ($x, $y) = unpack "v v", substr $$ref, 6, 4;

        return [ $x, $y ];

    },
    # size storage depends on header. For an OS header, two LE ushorts at
    # offset 18. For Windows, two LE signed longs at offset 18.
    'bmp' => sub {

        my $ref = shift;

        return undef unless length $$ref > 24;

        my $dbisize = unpack "V", substr $$ref, 14, 4;

        my ($x, $y);

        # OS
        if ($dbisize == 16) {
            ($x, $y) = unpack "v v", substr $$ref, 18, 4;
        # Win
        } else {
            ($x, $y) = unpack "(ll)<", substr $$ref, 18, 8;
            return undef if $x < 0 or $y < 0;
        }

        return [ $x, $y ];

    },
    # Get width and height attributes of root node.
    'svg' => sub {

        my $ref = shift;

        my $dom = eval { XML::LibXML->load_xml(string => $ref) }
            or return undef;

        my $svg = $dom->documentElement;

        my $x = $svg->getAttribute('width') or return undef;
        my $y = $svg->getAttribute('height') or return undef;

        return [ $x, $y ];

    },
);

sub image_id {

    my $ref = shift;

    if ($$ref =~ /^\xff\xd8\xff/) {
        return 'jpg';
    } elsif ($$ref =~ /^\x89\x50\x4e\x47\x0d\x0a\x1a\x0a/) {
        return 'png';
    } elsif ($$ref =~ /^GIF8[79]a/) {
        return 'gif';
    } elsif ($$ref =~ /^\x52\x49\x46\x46....\x57\x45\x42\x50\x56\x50\x38/) {
        return 'webp';
    } elsif ($$ref =~ /^BM/) {
        return 'bmp';
    } elsif ($$ref =~ /^(\x49\x49\x2a\x00|\x4d\x4d\x00\x2a)/) {
        return 'tif';
    } elsif ($$ref =~ /\A....ftypavif/s) {
        return 'avif';
    } elsif ($$ref =~ /^(\xff\x0a|\x00{3}\x0c\x4a\x58\x4c\x20\x0d\x0a\x87\x0a)/) {
        return 'jxl';
    } elsif (substr($$ref, 0, 1024) =~ /<\s*svg[^<>]*>/) {
        return 'svg';
    } else {
        return undef;
    }

}

sub image_size {

    my $ref = shift;
    my $fmt = shift // image_id($ref);

    unless (defined $fmt) {
        die "Could not determine image data format\n";
    }

    unless (exists $SIZE{ $fmt }) {
        return undef;
    }

    return $SIZE{ $fmt }->($ref);

}

sub is_image_path {

    my $path = shift;

    return $path =~ /\.$IMGRX$/;

}

1;

=head1 NAME

EBook::Ishmael::ImageID - Identify image data format

=head1 SYNOPSIS

  use EBook::Ishmael::ImageID;

  my $format = image_id($dataref);

=head1 DESCRIPTION

B<EBook::Ishmael::ImageID> is a module that provides the C<image_id()>
subroutine, which identifies the image format of a given buffer. This is
developer documentation, for L<ishmael> user documentation you should consult
its manual.

Currently, the following formats are supported:

=over 4

=item jpg

=item png

=item gif

=item webp

=item bmp

=item tif

=item svg

=item avif

=item jxl

=back

=head1 SUBROUTINES

=over 4

=item $f = image_id($dataref)

Returns a string of the image format of the given image buffer. C<$dataref>
must be a scalar ref. Returns C<undef> if the image's format could not be
identified.

=item [$x, $y] = image_size($dataref, [$fmt])

Returns an C<$x>/C<$y> pair representing the image data's size. C<$fmt> is an
optional argument specifying the format to use for the image data. If not
specified, C<image_size> will identify the format itself. If the image size
could not be determined, returns C<undef>.

This subroutine does not support the following formats (yet):

=over 4

=item webp

=item tif

=item avif

=item jxl

=back

=item $bool = is_image_path($path)

Returns true if C<$path> looks like an image path name.

=back

=head1 AUTHOR

Written by Samuel Young, E<lt>samyoung12788@gmail.comE<gt>.

This project's source can be found on its
L<Codeberg Page|https://codeberg.org/1-1sam/ishmael>. Comments and pull
requests are welcome!

=head1 COPYRIGHT

Copyright (C) 2025-2026 Samuel Young

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

=cut
