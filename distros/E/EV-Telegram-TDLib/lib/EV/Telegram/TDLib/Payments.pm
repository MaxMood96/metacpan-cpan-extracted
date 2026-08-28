package EV::Telegram::TDLib::Payments;

use strict;
use warnings;
use Carp qw(croak);
use MIME::Base64 ();

our $VERSION = '0.03';

sub CLONE_SKIP { 1 }

sub _json_bool { EV::Telegram::TDLib::_json_bool($_[0]) }
sub _need { EV::Telegram::TDLib::_need(@_) }

our %UPDATES = (
    updateNewPreCheckoutQuery => \&_update_pre_checkout,
    updateNewShippingQuery    => \&_update_shipping,
);

# The invoice payload is the seller's own order id, handed back at checkout.
# It is TL bytes in inputMessageInvoice and in updateNewPreCheckoutQuery, but a
# plain string in updateNewShippingQuery -- encoding all three alike corrupts
# the shipping one, so each is handled on its own terms.
sub _update_pre_checkout {
    my ($self, $obj) = @_;
    my $cb = $self->{on_pre_checkout_query} or return;
    $cb->({
        id              => $obj->{id},
        sender_user_id  => $obj->{sender_user_id},
        currency        => $obj->{currency},
        total_amount    => $obj->{total_amount},
        payload         => MIME::Base64::decode_base64($obj->{invoice_payload} // ''),
        shipping_option_id => $obj->{shipping_option_id},
        order_info      => $obj->{order_info},
    });
}

sub _update_shipping {
    my ($self, $obj) = @_;
    my $cb = $self->{on_shipping_query} or return;
    $cb->({
        id                => $obj->{id},
        sender_user_id    => $obj->{sender_user_id},
        payload           => $obj->{invoice_payload},
        shipping_address  => $obj->{shipping_address},
    });
}

sub on_pre_checkout_query {
    my ($self, $cb) = @_;
    $self->{on_pre_checkout_query} = $cb if $cb;
    return $self->{on_pre_checkout_query};
}

sub on_shipping_query {
    my ($self, $cb) = @_;
    $self->{on_shipping_query} = $cb if $cb;
    return $self->{on_shipping_query};
}

sub _price_parts {
    my ($prices) = @_;
    croak 'prices must be an arrayref' unless ref $prices eq 'ARRAY';
    croak 'an invoice needs at least one price' unless @$prices;
    return [ map {
        my ($label, $amount) = ref $_ eq 'ARRAY'  ? @$_
                             : ref $_ eq 'HASH'   ? @{$_}{qw(label amount)}
                             : croak 'each price must be an arrayref or hashref';
        croak 'each price needs a label and an amount'
            unless defined $label && defined $amount;
        { '@type' => 'labeledPricePart', label => "$label", amount => 0 + $amount };
    } @$prices ];
}

# Amounts are in the currency's smallest unit -- cents, not euros -- except for
# XTR, where one unit is one Star. Selling digital goods for Stars needs no
# payment provider at all, so provider_token stays empty.
sub _invoice_content {
    my ($spec) = @_;
    croak 'send_invoice needs a hashref describing the invoice'
        unless ref $spec eq 'HASH';
    _need('title, description, payload, currency, prices',
          @{$spec}{qw(title description payload currency prices)});
    return {
        '@type'      => 'inputMessageInvoice',
        invoice      => {
            '@type'                => 'invoice',
            currency               => "$spec->{currency}",
            price_parts            => _price_parts($spec->{prices}),
            max_tip_amount         => 0 + ($spec->{max_tip} // 0),
            suggested_tip_amounts  => [ map { 0 + $_ } @{ $spec->{tips} || [] } ],
            is_test                => _json_bool($spec->{test}),
            need_name              => _json_bool($spec->{need_name}),
            need_phone_number      => _json_bool($spec->{need_phone}),
            need_email_address     => _json_bool($spec->{need_email}),
            need_shipping_address  => _json_bool($spec->{need_shipping}),
            send_phone_number_to_provider => _json_bool($spec->{send_phone_to_provider}),
            send_email_address_to_provider => _json_bool($spec->{send_email_to_provider}),
            is_flexible            => _json_bool($spec->{flexible}),
        },
        title           => "$spec->{title}",
        description     => "$spec->{description}",
        photo_url       => $spec->{photo_url} // '',
        photo_size      => 0 + ($spec->{photo_size}   // 0),
        photo_width     => 0 + ($spec->{photo_width}  // 0),
        photo_height    => 0 + ($spec->{photo_height} // 0),
        payload         => MIME::Base64::encode_base64($spec->{payload}, ''),
        provider_token  => $spec->{provider_token} // '',
        provider_data   => $spec->{provider_data}  // '',
        start_parameter => $spec->{start_parameter} // '',
    };
}

sub send_invoice {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($chat_id, $spec, @rest) = @args;
    my %opt = @rest;
    _need('chat_id, invoice', $chat_id, $spec);
    $self->_send_content($chat_id, _invoice_content($spec), \%opt, $cb);
    return;
}

sub invoice_link {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($spec, @rest) = @args;
    my %opt = @rest;
    _need('invoice', $spec);
    $self->send({
        '@type'                  => 'createInvoiceLink',
        business_connection_id   => $opt{business_connection_id} // '',
        invoice                  => _invoice_content($spec),
    }, $cb);
    return;
}

# An empty error approves. Telegram gives a bot seconds to answer, and an
# unanswered query fails the payment, so answer from the handler.
sub answer_pre_checkout_query {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($id, @rest) = @args;
    my %opt = @rest;
    _need('pre_checkout_query_id', $id);
    $self->send({ '@type' => 'answerPreCheckoutQuery',
                  pre_checkout_query_id => "$id",
                  error_message => $opt{error} // '' }, $cb);
    return;
}

sub answer_shipping_query {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($id, @rest) = @args;
    my %opt = @rest;
    _need('shipping_query_id', $id);
    my @options;
    for my $o (@{ $opt{options} || [] }) {
        croak 'each shipping option must be a hashref' unless ref $o eq 'HASH';
        _need('shipping option id, title, prices', @{$o}{qw(id title prices)});
        push @options, { '@type' => 'shippingOption', id => "$o->{id}",
                         title => "$o->{title}",
                         price_parts => _price_parts($o->{prices}) };
    }
    $self->send({ '@type' => 'answerShippingQuery',
                  shipping_query_id => "$id",
                  shipping_options  => \@options,
                  error_message     => $opt{error} // '' }, $cb);
    return;
}

sub refund_star_payment {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my ($user_id, $charge_id, @rest) = @args;
    _need('user_id, telegram_payment_charge_id', $user_id, $charge_id);
    $self->send({ '@type' => 'refundStarPayment', user_id => 0 + $user_id,
                  telegram_payment_charge_id => "$charge_id" }, $cb);
    return;
}

my %DIRECTION = (
    incoming => 'transactionDirectionIncoming',
    outgoing => 'transactionDirectionOutgoing',
);

sub star_transactions {
    my ($self, @args) = @_;
    my $cb = ref $args[-1] eq 'CODE' ? pop @args : sub {};
    my (@rest) = @args;
    my %opt = @rest;
    my %req = (
        '@type'    => 'getStarTransactions',
        owner_id   => { '@type' => 'messageSenderUser',
                        user_id => 0 + ($opt{owner} // $self->my_id // 0) },
        subscription_id => $opt{subscription_id} // '',
        offset     => $opt{offset} // '',
        limit      => 0 + ($opt{limit} // 50),
    );
    if (defined $opt{direction}) {
        my $t = $DIRECTION{ $opt{direction} }
            or croak "unknown direction '$opt{direction}'";
        $req{direction} = { '@type' => $t };
    }
    $self->send(\%req, $cb);
    return;
}

1;
