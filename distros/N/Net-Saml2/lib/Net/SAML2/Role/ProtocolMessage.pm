package Net::SAML2::Role::ProtocolMessage;

use Moose::Role;

# ABSTRACT: Common behaviour for Protocol messages

use namespace::autoclean;

use DateTime;
use MooseX::Types::URI qw/ Uri /;
use Net::SAML2::Util qw(generate_id);


has id => (
    isa     => 'Str',
    is      => 'ro',
    builder => "_build_id"
);

has issue_instant => (
    isa     => 'Str',
    is      => 'ro',
    builder => '_build_issue_instant',
);

has issuer => (
    isa      => Uri,
    is       => 'rw',
    required => 1,
    coerce   => 1,
);

has issuer_namequalifier => (
    isa       => 'Str',
    is        => 'rw',
    predicate => 'has_issuer_namequalifier',
);

has issuer_format => (
    isa => 'Str',
    is  => 'rw',
    predicate => 'has_issuer_format',
);

has destination => (
    isa       => Uri,
    is        => 'rw',
    coerce    => 1,
    predicate => 'has_destination',
);

sub _build_issue_instant {
    return DateTime->now(time_zone => 'UTC')->strftime('%FT%TZ');
}

sub _build_id {
    return generate_id();
}


sub status_uri {
    my ($self, $status) = @_;

    my $statuses = {
        success   => 'urn:oasis:names:tc:SAML:2.0:status:Success',
        requester => 'urn:oasis:names:tc:SAML:2.0:status:Requester',
        responder => 'urn:oasis:names:tc:SAML:2.0:status:Responder',
        partial   => 'urn:oasis:names:tc:SAML:2.0:status:PartialLogout',
    };

    if (exists $statuses->{$status}) {
        return $statuses->{$status};
    }

    return;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Net::SAML2::Role::ProtocolMessage - Common behaviour for Protocol messages

=head1 VERSION

version 0.40

=head1 DESCRIPTION

Provides default ID and timestamp arguments for Protocol classes.

Provides a status-URI lookup method for the statuses used by this
implementation.

=head1 CONSTRUCTOR ARGUMENTS

=over

=item B<issuer>

URI of issuer

=item B<issuer_namequalifier>

NameQualifier attribute for Issuer

=item B<issuer_format>

Format attribute for Issuer

=item B<destination>

URI of Destination

=back

=head1 METHODS

=head2 status_uri( $status )

Provides a mapping from short names for statuses to the full status URIs.

Legal short names for B<$status> are:

=over

=item C<success>

=item C<requester>

=item C<responder>

=back

=head1 AUTHOR

Chris Andrews  <chrisa@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2021 by Chris Andrews and Others, see the git log.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
