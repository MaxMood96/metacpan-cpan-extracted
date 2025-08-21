package Telegram::Bot::Object::InlineKeyboardMarkup;
$Telegram::Bot::Object::InlineKeyboardMarkup::VERSION = '0.028';
# ABSTRACT: The base class for Telegram 'InlineKeyboardMarkup' type objects


use Mojo::Base 'Telegram::Bot::Object::Base';
use Telegram::Bot::Object::InlineKeyboardButton;

has 'inline_keyboard';

sub fields {
  return { 'Telegram::Bot::Object::InlineKeyboardButton' => [qw/inline_keyboard/],
         };
}

sub array_of_arrays {
  qw/inline_keyboard/;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Telegram::Bot::Object::InlineKeyboardMarkup - The base class for Telegram 'InlineKeyboardMarkup' type objects

=head1 VERSION

version 0.028

=head1 DESCRIPTION

See L<https://core.telegram.org/bots/api#inlinekeyboardmarkup> for details of the
attributes available for L<Telegram::Bot::Object::InlineKeyboardMarkup> objects.

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
