package Business::Payr::PaymentSession;

=head1 NAME

Business::Payr::PaymentSession - class representing a Payr payment session
returned by the C</thirdparty/user-login/> endpoint.

=head1 SYNOPSIS

    my $Session = $Payr->create_payment_session( '[email protected]' );

    # Embed the payment interface in your page
    print $Session->iframe_html;

    # Or build the URL yourself
    my $url = $Session->url;

=head1 DESCRIPTION

A C<Business::Payr::PaymentSession> object is returned by
L<Business::Payr/create_payment_session>. It encapsulates the temporary
session URL (valid for 15 minutes) that is used to embed the Payr payment
iframe into your platform.

=cut

use strict;
use warnings;
use feature qw/ signatures /;

use Moose;
no warnings qw/ experimental::signatures /;

use namespace::autoclean;

use Carp qw/ confess /;

=head1 ATTRIBUTES

=over

=item url (Str, required)

The full iframe URL returned by the C</thirdparty/user-login/> endpoint,
including the session token and session ID as query parameters. This URL
is valid for B<15 minutes>.

Example:

    https://sandbox.mypayr.co.uk/third-party?token=abc123&session_id=def456

=back

=cut

has 'url' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

=head1 METHODS

=head2 iframe_html

Returns an HTML C<< <iframe> >> snippet ready to embed in your page. The
iframe loads the Payr payment interface at the session URL.

    my $html = $Session->iframe_html;

    # Override default width / height
    my $html = $Session->iframe_html( width => '80%', height => 800 );

Optional keyword arguments:

=over

=item width

The C<width> attribute of the iframe. Defaults to C<'100%'>.

=item height

The C<height> attribute of the iframe in pixels. Defaults to C<700>.

=back

Returns a plain string of HTML.

=cut

sub iframe_html ( $self, %args ) {

    my $url    = $self->url;
    my $width  = $args{width}  // '100%';
    my $height = $args{height} // 700;

    confess "iframe_html requires a url attribute on the PaymentSession object"
        unless length $url;

    return sprintf(
        '<iframe src="%s" width="%s" height="%s" frameborder="0" allow="payment"></iframe>',
        $url,
        $width,
        $height,
    );
}

=head1 SEE ALSO

L<Business::Payr>

=head1 AUTHORS

Lee Johnson - C<leejo@cpan.org>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. If you would like to contribute documentation,
features, bug fixes, or anything else then please raise an issue / pull request:

    https://github.com/payprop/business-payr

=cut

__PACKAGE__->meta->make_immutable;

1;

# vim: ts=4:sw=4:et
