package Weather::NHC::TropicalCyclone::HTTP;

use strict;
use warnings;
use HTTP::Tiny ();

sub new {
    my ( $class, %args ) = @_;
    my $client = $args{client} || HTTP::Tiny->new;
    return bless { client => $client }, $class;
}

sub client { return $_[0]->{client} }

sub get {
    my ( $self, $url ) = @_;
    my $response = $self->client->get($url);
    _assert_success( $response, "Fetching of $url failed" );
    return $response;
}

sub mirror {
    my ( $self, $url, $file ) = @_;
    my $response = $self->client->mirror( $url, $file );
    _assert_success( $response, "Download of $url failed" );
    return $response;
}

sub _assert_success {
    my ( $response, $message ) = @_;
    my $ok = $response && ( $response->{success} || ( defined $response->{status} && $response->{status} >= 200 && $response->{status} < 300 ) );
    return 1 if $ok;
    my $status = $response && defined $response->{status} ? $response->{status} : q{Unknown};
    die "$message. HTTP status: $status\n";
}

1;

__END__

=head1 NAME

Weather::NHC::TropicalCyclone::HTTP - small, injectable HTTP boundary for Weather::NHC::TropicalCyclone

=head1 DESCRIPTION

This internal class centralizes C<HTTP::Tiny> access so the public NHC client and
storm objects do not create HTTP clients throughout the code.  Supplying a mock
client to L<Weather::NHC::TropicalCyclone/new> therefore makes network behavior
fully deterministic in tests.

=head1 METHODS

=head2 new

    my $http = Weather::NHC::TropicalCyclone::HTTP->new(
        client => $http_tiny_compatible_object,
    );

The client must provide C<get> and C<mirror> methods with C<HTTP::Tiny>-compatible
response hashes.

=head2 get

Performs an HTTP GET and returns the successful C<HTTP::Tiny>-style response hash.

=head2 mirror

Downloads a URL to a local file and returns the successful response hash.

Both methods perform a request and throw an exception for unsuccessful responses.

=cut
