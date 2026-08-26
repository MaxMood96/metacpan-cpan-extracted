package Crypt::Image::Axis;

use strict;
use warnings;
use version;

our $VERSION   = qv('v1.0.1');
our $AUTHORITY = 'cpan:MANWAR';

=head1 NAME

Crypt::Image::Axis - Coordinates of the image used in the Crypt::Image.

=head1 VERSION

Version v1.0.1

=cut

use Types::Standard qw(Int);
use Moo;
use namespace::autoclean;

has 'x' => (is => 'ro', isa => Int, required => 1);
has 'y' => (is => 'ro', isa => Int, required => 1);
has 'z' => (is => 'ro', isa => Int);

=head1 DESCRIPTION

Used internally by Crypt::Image::Util module.

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

    perldoc Crypt::Image::Axis

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

1; # End of Crypt::Image::Axis
