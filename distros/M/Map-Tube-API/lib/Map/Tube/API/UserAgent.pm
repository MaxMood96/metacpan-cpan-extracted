package Map::Tube::API::UserAgent;

$Map::Tube::API::UserAgent::VERSION   = '0.09';
$Map::Tube::API::UserAgent::AUTHORITY = 'cpan:MANWAR';

=head1 NAME

Map::Tube::API::UserAgent - Low-level HTTP request handler for Map::Tube::API.

=head1 VERSION

Version 0.09

=cut

use 5.006;
use Data::Dumper;

use LWP::UserAgent;
use HTTP::Request::Common qw(GET POST);
use Map::Tube::API::Exception;

use Moo;
use namespace::autoclean;

has 'ua' => (is => 'rw', default => sub { LWP::UserAgent->new });

=head1 DESCRIPTION

It provides common useragent library for Map::Tube::API services.

=head1 METHODS

=head2 get($url)

It  expects  one parameter i.e.  URL  and returns the standard response. On error
throws exception of type L<Map::Tube::API::Exception>.

=cut

sub get {
    my ($self, $url) = @_;

    my $response = $self->ua->request(GET($url));

    unless ($response->is_success) {
        Map::Tube::API::Exception->throw(
            { code => $response->code, message => $response->content });
    }

    return $response;
}

=head2 post($url, $content)

It expects two parameters  i.e. URL and Content in the same order and returns the
standard response.On error throws exception of type L<Map::Tube::API::Exception>.

=cut

sub post {
     my ($self, $url, $content) = @_;

    my $response = $self->ua->request(POST($url, $content));

    unless ($response->is_success) {
        Map::Tube::API::Exception->throw(
            { code => $response->code, message => $response->content });
    }

    return $response;
}

=head1 AUTHOR

Mohammad Sajid Anwar, C<< <mohammad.anwar at yahoo.com> >>

=head1 REPOSITORY

L<https://github.com/manwar/Map-Tube-API>

=head1 BUGS

Please report any bugs or feature requests to C<bug-map-tube-api at rt.cpan.org>,
or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Map-Tube-API>.
I will be notified, and then you'll automatically be notified of progress on your
bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Map::Tube::API::UserAgent

You can also look for information at:

=over 4

=item * BUGS / ISSUES

L<https://github.com/manwar/Map-Tube-API/issues>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Map-Tube-API>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Map-Tube-API>

=item * Search MetaCPAN

L<https://metacpan.org/pod/Map::Tube::API>

=back

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2024 - 2025 Mohammad Sajid Anwar.

This  program  is  free software;  you can redistribute it and/or modify it under
the  terms  of the the Artistic  License (2.0). You may obtain a copy of the full
license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any  use,  modification, and distribution of the Standard or Modified Versions is
governed by this Artistic License.By using, modifying or distributing the Package,
you accept this license. Do not use, modify, or distribute the Package, if you do
not accept this license.

If your Modified Version has been derived from a Modified Version made by someone
other than you,you are nevertheless required to ensure that your Modified Version
 complies with the requirements of this license.

This  license  does  not grant you the right to use any trademark,  service mark,
tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge patent license
to make,  have made, use,  offer to sell, sell, import and otherwise transfer the
Package with respect to any patent claims licensable by the Copyright Holder that
are  necessarily  infringed  by  the  Package. If you institute patent litigation
(including  a  cross-claim  or  counterclaim) against any party alleging that the
Package constitutes direct or contributory patent infringement,then this Artistic
License to you shall terminate on the date that such litigation is filed.

Disclaimer  of  Warranty:  THE  PACKAGE  IS  PROVIDED BY THE COPYRIGHT HOLDER AND
CONTRIBUTORS  "AS IS'  AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES. THE IMPLIED
WARRANTIES    OF   MERCHANTABILITY,   FITNESS   FOR   A   PARTICULAR  PURPOSE, OR
NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY YOUR LOCAL LAW. UNLESS
REQUIRED BY LAW, NO COPYRIGHT HOLDER OR CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT,
INDIRECT, INCIDENTAL,  OR CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE
OF THE PACKAGE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut

1; # End of Map::Tube::API::UserAgent
