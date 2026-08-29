package Typesense::Client::Error;
$Typesense::Client::Error::VERSION = '0.001';
use v5.38;
use warnings;
use experimental 'signatures';

use overload '""' => sub { $_[0]->message_full }, fallback => 1;

## Exception object for Typesense::Client.
##
## Thrown in strict mode (the default). In fail_open mode the client builds it
## all the same and leaves it in ->last_error, but returns undef.
##
##   if (my $err = $@) {
##       die $err unless ref $err && $err->isa('Typesense::Client::Error');
##       warn $err->code;      # 404, or 0 if there was no HTTP response
##       warn $err->endpoint;  # POST /collections/products/documents/import
##   }

sub new ($class, %args) {
    return bless {
        message  => $args{message}  // 'error',
        code     => $args{code}     // 0,
        endpoint => $args{endpoint} // '',
        body     => $args{body},
    }, $class;
}

sub message  { $_[0]{message} }
sub code     { $_[0]{code} }
sub endpoint { $_[0]{endpoint} }
sub body     { $_[0]{body} }

## code 0 = no HTTP response ever arrived (DNS, connection, timeout).
sub is_connection_error ($self) { return $self->{code} == 0 }
sub is_not_found        ($self) { return $self->{code} == 404 }

sub message_full ($self) {
    my $where = $self->{endpoint} ? " [$self->{endpoint}]" : '';
    my $code  = $self->{code} ? " (HTTP $self->{code})" : ' (no response)';
    return "Typesense: $self->{message}$code$where";
}

sub throw ($class, %args) { die $class->new(%args) }

1;

__END__

=head1 NAME

Typesense::Client::Error - Exception object thrown by Typesense::Client

=head1 SYNOPSIS

    use Typesense::Client;

    my $ts = Typesense::Client->new(url => '...', api_key => '...');

    my $res = eval { $ts->collections->get('products') };
    if (my $err = $@) {
        die $err unless ref $err && $err->isa('Typesense::Client::Error');
        say $err->code;                  # 404
        say $err->message;               # Not Found
        say $err->endpoint;              # GET /collections/products
        say "$err";                      # stringifies to the full message
        warn 'server unreachable' if $err->is_connection_error;
    }

=head1 DESCRIPTION

Every failure raised by L<Typesense::Client> in its default (strict) mode is an
object of this class. In C<fail_open> mode the same object is built and stored
in C<< $client->last_error >>, and the method returns C<undef> instead of dying.

The object stringifies to L</message_full>, so C<warn $@> and C<die $@> do the
right thing without any unpacking.

=head1 METHODS

=head2 message

The error text reported by Typesense, or a transport-level description when the
request never reached the server.

=head2 code

The HTTP status code. B<Zero> means no HTTP response was received at all: DNS
failure, connection refused, or timeout. See L</is_connection_error>.

=head2 endpoint

The method and path that failed, e.g. C<GET /collections/products>. Useful in
logs where several calls are in flight.

=head2 body

The decoded JSON body of the error response, when the server sent one, as a
hash reference. C<undef> otherwise.

=head2 is_connection_error

True when the request never reached the server (C<code> is 0). This is the case
worth retrying or failing open on; a 4xx usually is not.

=head2 is_not_found

True for HTTP 404.

=head2 message_full

The full message, as produced by stringification.

=head2 throw

    Typesense::Client::Error->throw(message => '...', code => 404);

Constructs and dies. Used internally by the client.

=head1 SEE ALSO

L<Typesense::Client>

=head1 AUTHOR

SeHarrys

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2026 by SeHarrys.

This is free software; you can redistribute it and/or modify it under the terms
of the Artistic License 2.0.

=cut
