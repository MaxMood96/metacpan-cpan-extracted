package RDF::Cowl::DataOneOf;
# ABSTRACT: Represents DataOneOf in the OWL 2 specification
$RDF::Cowl::DataOneOf::VERSION = '1.0.0';
# CowlDataOneOf
use strict;
use warnings;
use parent 'RDF::Cowl::DataRange';
use RDF::Cowl::Lib qw(arg);

my $ffi = RDF::Cowl::Lib->ffi;

require RDF::Cowl::Lib::Gen::Class::DataOneOf unless $RDF::Cowl::no_gen;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

RDF::Cowl::DataOneOf - Represents DataOneOf in the OWL 2 specification

=head1 VERSION

version 1.0.0

=head1 GENERATED DOCUMENTATION

See more documentation at:

L<RDF::Cowl::Lib::Gen::Class::DataOneOf>

=head1 AUTHOR

Zakariyya Mughal <zmughal@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2024 by Auto-Parallel Technologies, Inc..

This is free software, licensed under Eclipse Public License - v 2.0.

=cut
