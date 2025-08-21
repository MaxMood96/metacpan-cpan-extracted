package Telegram::Bot::Object::Invoice;
$Telegram::Bot::Object::Invoice::VERSION = '0.028';
# ABSTRACT: The base class for Telegram 'Invoice' type objects


use Mojo::Base 'Telegram::Bot::Object::Base';

has 'title';
has 'description';
has 'start_parameter';
has 'currency';
has 'total_amount';

sub fields {
  return { scalar => [qw/title description start_parameter currency total_amount/],
         };
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Telegram::Bot::Object::Invoice - The base class for Telegram 'Invoice' type objects

=head1 VERSION

version 0.028

=head1 DESCRIPTION

See L<https://core.telegram.org/bots/api#invoice> for details of the
attributes available for L<Telegram::Bot::Object::Invoice> objects.

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
