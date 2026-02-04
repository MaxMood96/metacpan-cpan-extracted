package SPVM::HTTP::Tiny::Response;

1;

=head1 Name

SPVM::HTTP::Tiny::Response - HTTP Response Object

=head1 Description

The L<HTTP::Tiny::Response|SPVM::HTTP::Tiny::Response> class in L<SPVM> represents an HTTP response received by L<HTTP::Tiny|SPVM::HTTP::Tiny>.

This class provides an interface compatible with Perl's C<HTTP::Tiny> response hash, while also allowing access to the underlying L<Mojo::Message::Response|SPVM::Mojo::Message::Response> object.

=head1 Usage

  my $res = $http->get($ctx, "http://example.com/");

  # Check if the request was successful (status 2xx)
  if ($res->success) {
    # Get status code and reason phrase
    my $status = $res->status;   # 200
    my $reason = $res->reason;   # "OK"

    # Get response headers as a Hash
    my $headers = $res->headers;
    my $type = (string)$headers->get("content-type");

    # Get response body
    my $content = $res->content;
    
    # Access underlying Mojo object for advanced features
    my $mojo_res = $res->res;
    my $version = $mojo_res->version;
  }

=head1 Fields

=head2 tx

C<has tx : ro L<Mojo::Transaction::HTTP|SPVM::Mojo::Transaction::HTTP>;>

The underlying L<Mojo::Transaction::HTTP|SPVM::Mojo::Transaction::HTTP> object. This field stores the entire HTTP transaction, including the request and response.

=head2 res

C<has res : virtual ro L<Mojo::Message::Response|SPVM::Mojo::Message::Response>;>

The underlying L<Mojo::Message::Response|SPVM::Mojo::Message::Response> object. This is a virtual field that retrieves the response object directly from the L</"tx"> field.

You can use this field to access low-level response data not provided by the C<HTTP::Tiny::Response> wrapper.

=head1 Instance Methods

=head2 protocol

C<method protocol : string ();>

Returns the HTTP protocol string, such as C<HTTP/1.1>.

=head2 status

C<method status : int ();>

Returns the HTTP status code (e.g., C<200>, C<404>).

=head2 success

C<method success : int ();>

Returns C<1> if the L</"status"> is a C<2xx> code, C<0> otherwise.

=head2 reason

C<method reason : string ();>

Returns the HTTP status message (e.g., C<OK>, C<Not Found>).

=head2 headers

C<method headers : L<Hash|SPVM::Hash> ();>

Returns the response headers as a L<Hash|SPVM::Hash> object.
The keys are normalized to lower-case. Values are typically strings, but can be string arrays if a header has multiple values.

=head2 content

C<method content : string ();>

Returns the response body as a C<string>.

=head1 Copyright & License

Copyright (c) 2026 Yuki Kimoto

MIT License
