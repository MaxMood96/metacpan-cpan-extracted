package Telegram::Bot::Object::Venue;
$Telegram::Bot::Object::Venue::VERSION = '0.028';
# ABSTRACT: The base class for Telegram 'LoginUrl' type objects


use Mojo::Base 'Telegram::Bot::Object::Base';
use Telegram::Bot::Object::Location;

has 'location'; #Location
has 'title';
has 'address';
has 'foursquare_id';
has 'foursquare_type';

sub fields {
  return { 'scalar'                           => [qw/title address
                                                     foursquare_id foursquare_type/],
            'Telegram::Bot::Object::Location' => [qw/location/] };

}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Telegram::Bot::Object::Venue - The base class for Telegram 'LoginUrl' type objects

=head1 VERSION

version 0.028

=head1 DESCRIPTION

See L<https://core.telegram.org/bots/api#venue> for details of the
attributes available for L<Telegram::Bot::Object::Venue> objects.

=head1 AUTHORS

=over 4

=item *

Justin Hawkins <justin@eatmorecode.com>

=item *

James Green <jkg@earth.li>

=item *

Julien Fiegehenn <simbabque@cpan.org>

=item *

Jess Robinson <jrobinson@cpan.org>

=item *

Albert Cester <albert.cester@web.de>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2024 by James Green.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
