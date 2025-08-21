package Telegram::Bot::Object::Video;
$Telegram::Bot::Object::Video::VERSION = '0.028';
# ABSTRACT: The base class for Telegram 'Video' object.


use Mojo::Base 'Telegram::Bot::Object::Base';
use Telegram::Bot::Object::PhotoSize;

has 'file_id';
has 'width';
has 'height';
has 'duration';
has 'thumb'; #PhotoSize
has 'mime_type';
has 'file_size';

sub fields {
  return { scalar                             => [qw/file_id width height duration
                                                     mime_type file_size /],
           'Telegram::Bot::Object::PhotoSize' => [qw/thumb/]
         };
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Telegram::Bot::Object::Video - The base class for Telegram 'Video' object.

=head1 VERSION

version 0.028

=head1 DESCRIPTION

See L<https://core.telegram.org/bots/api#video> for details of the
attributes available for L<Telegram::Bot::Object::Video> objects.

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
