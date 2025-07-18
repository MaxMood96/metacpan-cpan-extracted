  use strict;
  use warnings;
  package Alien::Bit;
$Alien::Bit::VERSION = '0.02';
use parent qw( Alien::Base );

=head1 NAME

Alien::Bit - Find or install the Bit library

=head1 VERSION

version 0.02

=head1 SYNOPSIS

Installs the Bit library, used to manipulate bitsets and their packed containers

=head1 DESCRIPTION

This distribution provides the librry Bit so that it can be used by 
other Perl distributions that are on CPAN.  It will download Bit from Github
and will build the (static and dynamic) versions of the library for use by other
Perl modules.


=head1 SEE ALSO

=over 4

=item L<Bit|https://github.com/chrisarg/Bit>

Bit is a high-performance, uncompressed bitset implementation in C, optimized 
for modern architectures. The library provides an efficient way to create, 
manipulate, and query bitsets with a focus on performance and memory alignment. 
The API and the interface is largely based on David Hanson's Bit_T library 
discussed in Chapter 13 of "C Interfaces and Implementations", 
Addison-Wesley ISBN 0-201-49841-3 extended to incorporate additional operations 
(such as counts on unions/differences/intersections of sets), 
fast population counts using the libpocnt library and GPU operations for packed 
containers of (collections) of Bit(sets).

=item L<libpopcnt|https://github.com/kimwalisch/libpopcnt>

libpopcnt.h is a header-only C/C++ library for counting the number of 1 bits 
(bit population count) in an array as quickly as possible using specialized 
CPU instructions i.e. POPCNT, AVX2, AVX512, NEON, SVE. libpopcnt.h has been 
tested successfully using the GCC, Clang and MSVC compilers.


=item L<Alien>

Documentation on the Alien concept itself.

=item L<Alien::Base>

The base class for this Alien.

=item L<Alien::Build::Manual::AlienUser>

Detailed manual for users of Alien classes.

=back

=head1 AUTHOR

Christos Argyropoulos <chrisarg@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2025 by Christos Argyropoulos.

This is distributed under the BSD-2 license

=cut

1;
