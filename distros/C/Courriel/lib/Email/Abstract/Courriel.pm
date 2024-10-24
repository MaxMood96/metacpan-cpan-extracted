package Email::Abstract::Courriel;

use strict;
use warnings;

our $VERSION = '0.49';

use Courriel;

use parent 'Email::Abstract::Plugin';

sub target {'Courriel'}

sub construct {
    my ( $class, $rfc822 ) = @_;
    Courriel->parse( text => \$rfc822 );
}

sub get_header {
    my ( $class, $obj, $header ) = @_;
    my @values = map { $_->value } $obj->headers->get($header);
    return wantarray ? @values : $values[0];
}

sub get_body {
    my ( $class, $obj ) = @_;
    return $obj->as_string;
}

sub set_header {
    my ( $class, $obj, $header, @data ) = @_;
    $obj->headers->remove($header);
    $obj->headers->add( $header => $_ ) for @data;
}

sub set_body {
    my ( $class, $obj, $body ) = @_;
    $obj->replace_body( text => $body );
}

sub as_string {
    my ( $class, $obj ) = @_;
    $obj->as_string;
}

1;

#ABSTRACT: Email::Abstract wrapper for Courriel

__END__

=pod

=encoding UTF-8

=head1 NAME

Email::Abstract::Courriel - Email::Abstract wrapper for Courriel

=head1 VERSION

version 0.49

=head1 DESCRIPTION

This module wraps the Courriel mail handling library with an abstract
interface, to be used with L<Email::Abstract>.

=head1 SEE ALSO

L<Email::Abstract>, L<Courriel>.

=head1 SUPPORT

Bugs may be submitted at L<https://github.com/houseabsolute/Courriel/issues>.

I am also usually active on IRC as 'autarch' on C<irc://irc.perl.org>.

=head1 SOURCE

The source code repository for Courriel can be found at L<https://github.com/houseabsolute/Courriel>.

=head1 AUTHOR

Dave Rolsky <autarch@urth.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2021 by Dave Rolsky.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

The full text of the license can be found in the
F<LICENSE> file included with this distribution.

=cut
