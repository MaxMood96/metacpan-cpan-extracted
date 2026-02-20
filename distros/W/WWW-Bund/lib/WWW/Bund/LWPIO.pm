package WWW::Bund::LWPIO;
our $VERSION = '0.002';
# ABSTRACT: Synchronous HTTP backend using LWP::UserAgent

use Moo;
use LWP::UserAgent;
use HTTP::Request;
use WWW::Bund::HTTPResponse;
use namespace::clean;


with 'WWW::Bund::Role::IO';

has timeout => (is => 'ro', default => 30);


has ua => (
    is      => 'lazy',
    builder => sub {
        my $self = shift;
        LWP::UserAgent->new(
            agent   => 'WWW-Bund/' . ($WWW::Bund::VERSION // 'dev'),
            timeout => $self->timeout,
        );
    },
);


sub call {
    my ($self, $req) = @_;

    my $http_req = HTTP::Request->new($req->method => $req->url);

    my $headers = $req->headers;
    for my $header (keys %$headers) {
        $http_req->header($header => $headers->{$header});
    }

    $http_req->content($req->content) if $req->has_content;

    my $response = $self->ua->request($http_req);

    return WWW::Bund::HTTPResponse->new(
        status       => $response->code,
        content      => $response->decoded_content // '',
        content_type => $response->header('Content-Type') // '',
    );
}


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WWW::Bund::LWPIO - Synchronous HTTP backend using LWP::UserAgent

=head1 VERSION

version 0.002

=head1 SYNOPSIS

    use WWW::Bund::LWPIO;

    my $io = WWW::Bund::LWPIO->new(timeout => 30);
    my $response = $io->call($request);

=head1 DESCRIPTION

Default HTTP backend for L<WWW::Bund>. Uses L<LWP::UserAgent> for synchronous
HTTP requests. Implements L<WWW::Bund::Role::IO>.

=head2 timeout

HTTP request timeout in seconds. Defaults to C<30>.

=head2 ua

L<LWP::UserAgent> instance for making HTTP requests.

=head2 call

    my $response = $io->call($request);

Execute HTTP request. Takes L<WWW::Bund::HTTPRequest>, returns
L<WWW::Bund::HTTPResponse> with decoded content.

=head1 SUPPORT

=head2 Issues

Please report bugs and feature requests on GitHub at
L<https://github.com/Getty/p5-www-bund/issues>.

=head1 CONTRIBUTING

Contributions are welcome! Please fork the repository and submit a pull request.

=head1 AUTHOR

Torsten Raudssus <torsten@raudssus.de>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2026 by Torsten Raudssus.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
