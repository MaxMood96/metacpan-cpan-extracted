package Telegram::Bot::Object::SuccessfulPayment;
$Telegram::Bot::Object::SuccessfulPayment::VERSION = '0.028';
# ABSTRACT: The base class for Telegram 'SuccessfulPayment' type objects


use Mojo::Base 'Telegram::Bot::Object::Base';
# use Telegram::Bot::Object::OrderInfo;

has 'currency';
has 'total_amount';
has 'invoice_payload';
has 'shipping_option_id';
# has 'order_info'; #OrderInfo XXX
has 'telegram_payment_charge_id';
has 'provider_payment_charge_id';

sub fields {
  return { scalar => [qw/currency total_amount invoice_payload shipping_option_id
                         telegram_payment_charge_id provider_payment_charge_id/],
       # 'Telegram::Bot::Object::OrderInfo' => [qw/order_info/],

         };
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Telegram::Bot::Object::SuccessfulPayment - The base class for Telegram 'SuccessfulPayment' type objects

=head1 VERSION

version 0.028

=head1 DESCRIPTION

See L<https://core.telegram.org/bots/api#successfulpayment> for details of the
attributes available for L<Telegram::Bot::Object::SuccessfulPayment> objects.

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
