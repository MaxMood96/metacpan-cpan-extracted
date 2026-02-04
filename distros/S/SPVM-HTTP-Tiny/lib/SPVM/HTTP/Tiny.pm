package SPVM::HTTP::Tiny;

our $VERSION = "0.017";

1;

=head1 Name

SPVM::HTTP::Tiny - A User-Friendly HTTP Client based on Mojo::UserAgent

=head1 Description

L<HTTP::Tiny|SPVM::HTTP::Tiny> class in L<SPVM> is a simple HTTP client.

B<This class is highly experimental. Many dramatic incompatibilities are expected.>

=head1 Usage

  use HTTP::Tiny;
  use Go::Context;
  
  my $ctx = Go::Context->background;
  my $http = HTTP::Tiny->new;
  
  # GET request
  my $response = $http->get($ctx, 'http://example.com/');
  
  unless ($response->success) {
    die "Failed to fetch!";
  }
  
  # Status and Reason
  my $status = $response->status;
  my $reason = $response->reason;
  
  # Accessing headers
  my $headers = $response->headers;
  my $content_type = $headers->header("Content-Type");
  
  # Accessing content
  my $content = $response->content;
  if (Fn->length($content) > 0) {
    print $content;
  }

=head1 Details

=head2 Wrapper of Mojo::UserAgent

This class is a wrapper of L<Mojo::UserAgent|SPVM::Mojo::UserAgent>. Unlike Perl's original C<HTTP::Tiny>, this implementation depends on the Mojo stack to support non-blocking I/O and L<Go|SPVM::Go> coroutines.

=head1 Fields

=head2 ua

C<has ua : ro L<Mojo::UserAgent|SPVM::Mojo::UserAgent>;>

The L<Mojo::UserAgent|SPVM::Mojo::UserAgent> object used for HTTP requests.

=head1 Class Methods

=head2 new

C<static method new : L<HTTP::Tiny|SPVM::HTTP::Tiny> ($options : object[] = undef);>

Creates a new L<HTTP::Tiny|SPVM::HTTP::Tiny> object.

B<Note:> Currently, C<$options> are ignored in the C<new> method. The default User-Agent string is C<SPVM/HTTP::Tiny/$VERSION> and C<max_redirects> is set to 5.

=head1 Instance Methods

=head2 get

C<method get : L<HTTP::Tiny::Response|SPVM::HTTP::Tiny::Response> ($ctx : L<Go::Context|SPVM::Go::Context>, $url : string, $options : object[] = undef);>

Sends an HTTP C<GET> request.

=head2 head

C<method head : L<HTTP::Tiny::Response|SPVM::HTTP::Tiny::Response> ($ctx : L<Go::Context|SPVM::Go::Context>, $url : string, $options : object[] = undef);>

Sends an HTTP C<HEAD> request.

=head2 put

C<method put : L<HTTP::Tiny::Response|SPVM::HTTP::Tiny::Response> ($ctx : L<Go::Context|SPVM::Go::Context>, $url : string, $options : object[] = undef);>

Sends an HTTP C<PUT> request.

=head2 post

C<method post : L<HTTP::Tiny::Response|SPVM::HTTP::Tiny::Response> ($ctx : L<Go::Context|SPVM::Go::Context>, $url : string, $options : object[] = undef);>

Sends an HTTP C<POST> request.

=head2 patch

C<method patch : L<HTTP::Tiny::Response|SPVM::HTTP::Tiny::Response> ($ctx : L<Go::Context|SPVM::Go::Context>, $url : string, $options : object[] = undef);>

Sends an HTTP C<PATCH> request.

=head2 delete

C<method delete : L<HTTP::Tiny::Response|SPVM::HTTP::Tiny::Response> ($ctx : L<Go::Context|SPVM::Go::Context>, $url : string, $options : object[] = undef);>

Sends an HTTP C<DELETE> request.

=head2 request

C<method request : L<HTTP::Tiny::Response|SPVM::HTTP::Tiny::Response> ($ctx : L<Go::Context|SPVM::Go::Context>, $method : string, $url : string, $options : object[] = undef);>

Sends an HTTP request with the specified method.

Options (as a C<Hash>):

=over 2

=item * C<headers> : object[] (Hash-like)

Custom headers for the request.

  my $res = $http->request($ctx, "GET", $url, {headers => {"X-Custom" => "Value"}});

=back

=head1 Repository

L<SPVM::HTTP::Tiny - Github|https://github.com/yuki-kimoto/SPVM-HTTP-Tiny>

=head1 Author

Yuki Kimoto C<kimoto.yuki@gmail.com>

=head1 Copyright & License

Copyright (c) 2026 Yuki Kimoto

MIT License
