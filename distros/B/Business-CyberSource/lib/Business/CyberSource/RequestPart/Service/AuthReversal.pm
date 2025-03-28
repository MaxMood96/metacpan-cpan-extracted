package Business::CyberSource::RequestPart::Service::AuthReversal;
use strict;
use warnings;
use namespace::autoclean;

our $VERSION = '0.010008'; # VERSION

use Moose;
extends 'Business::CyberSource::RequestPart::Service';

use MooseX::Types::CyberSource qw( RequestID );

has request_id => (
	isa         => RequestID,
	remote_name => 'authRequestID',
	predicate   => 'has_request_id',
	is          => 'rw',
	required    => 1,
	traits      => ['SetOnce'],
);

__PACKAGE__->meta->make_immutable;
1;

# ABSTRACT: AuthReversal Service

__END__

=pod

=encoding UTF-8

=head1 NAME

Business::CyberSource::RequestPart::Service::AuthReversal - AuthReversal Service

=head1 VERSION

version 0.010008

=head1 ATTRIBUTES

=head2 request_id

The L<request_id|Business::CyberSource::Response/"request_id"> for the authorization that you want to reverse.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website
https://github.com/hostgator/business-cybersource/issues

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 AUTHOR

Caleb Cushing <xenoterracide@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2017 by Caleb Cushing <xenoterracide@gmail.com>.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut
