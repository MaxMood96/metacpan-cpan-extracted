package Zonemaster::LDNS::RR::NSEC3PARAM;

use strict;
use warnings;

use parent 'Zonemaster::LDNS::RR';

1;

=head1 NAME

Zonemaster::LDNS::RR::NSEC3PARAM - Type NSEC3PARAM record

=head1 DESCRIPTION

A subclass of L<Zonemaster::LDNS::RR>, so it has all the methods of that class available in addition to the ones documented here.

=head1 METHODS

=over

=item algorithm()

Returns the algorithm number.

=item flags()

Returns the flags field.

=item iterations()

Returns the iteration count.

=item salt()

Returns the contents of the salt field as a binary string, if non-empty; otherwise, returns an empty string.

=item hash_name($name)

Computes and returns a hash, in canonical form, of the given name using the parameters (algorithm, iterations, salt) of the resource record.

=back
