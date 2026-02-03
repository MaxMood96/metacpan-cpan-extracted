package SPVM::Mojo::UserAgent;

1;

=encoding utf-8

=head1 Name

SPVM::Mojo::UserAgent - Context-aware HTTP and WebSocket user agent

=head1 Description

Mojo::UserAgent class in L<SPVM> is a full featured HTTP and WebSocket user agent.
Every I/O operation is context-aware and can be canceled via L<Go::Context|SPVM::Go::Context>.

Since this class is designed to be goroutine-safe, you can perform multiple HTTP requests in parallel by creating goroutines. This is efficient for fetching data from multiple APIs simultaneously.

=head1 Usage

  use Mojo::UserAgent;
  use Go::Context;
  use Go;

  # Note: This version is not compatible with previous versions.
  # The first argument of I/O methods (get, post, put, patch, delete, head, options, start) 
  # now requires a Go::Context object.

  my $ua  = Mojo::UserAgent->new;
  my $ctx = Go::Context->background;

  # --- Single request example ---
  my $res = $ua->get($ctx, "docs.mojolicious.org")->result;
  say $res->body if $res->is_success;
  
  # --- Parallel access example ---
  # Fetch multiple URLs in parallel using goroutines.
  # Note: SPVM does not support closures, so variables must be passed as arguments.
  my $urls = ["https://google.com", "https://github.com", "https://metacpan.org"];
  for my $url (@$urls) {
    Go->go([$ctx : Go::Context, $ua : Mojo::UserAgent, $url : string], method : void () {
      my $tx = $ua->get($ctx, $url);
      if (my $res = $tx->result) {
        say "URL: $url, Code: " . $res->code;
      }
    });
  }
  
  # Wait for all goroutines to finish
  Go->gosched;

  # --- Request with timeout example ---
  {
    my $timeout_ctx_derived = Go::Context->with_timeout($ctx, 0.5);
    my $timeout_ctx = $timeout_ctx_derived->ctx;
    my $tx = $ua->get($timeout_ctx, "https://example.com");
  }

=head1 Class Methods

=head2 new

C<static method new : Mojo::UserAgent ();>

Create a new L<Mojo::UserAgent|SPVM::Mojo::UserAgent> object, and return it.

=head1 Instance Methods

=head2 build_tx

C<method build_tx : Mojo::Transaction::HTTP ($method : string, $url : string|L<Mojo::URL|SPVM::Mojo::URL>, $args : object...);>

Generate L<Mojo::Transaction::HTTP|SPVM::Mojo::Transaction::HTTP> object with L<Mojo::UserAgent::Transactor#tx|SPVM::Mojo::UserAgent::Transactor/"tx">.

Examples:

  my $tx = $ua->build_tx(GET => "example.com");
  my $tx = $ua->build_tx(PUT => "http://example.com" => {Accept => "*/*"} => "Content!");
  my $tx = $ua->build_tx(PUT => "http://example.com" => {Accept => "*/*"} => [(object)form => {a => "b"}]);
  my $tx = $ua->build_tx(PUT => "http://example.com" => {Accept => "*/*"} => [(object)json => {a => "b"}]);

  # Request with custom cookie
  my $tx = $ua->build_tx(GET => "https://example.com/account");
  $tx->req->cookies({name => "user", value => "sri"});
  $tx = $ua->start($ctx, $tx);

  # Deactivate gzip compression
  my $tx = $ua->build_tx(GET => "example.com");
  $tx->req->headers->remove("Accept-Encoding");
  $tx = $ua->start($ctx, $tx);

  # Interrupt response by raising an error
  my $tx = $ua->build_tx(GET => "http://example.com");
  $tx->res->on(progress => method ($res : Mojo::Message::Response) {
    unless (my $server = $res->headers->server) {
      return;
    }
    
    if (Re->m($server, "IIS")) {
      die "Oh noes, it is IIS!";
    }
  });
  $tx = $ua->start($ctx, $tx);

=head2 build_websocket_tx

Not yet implemented.

=head2 delete

C<method delete : Mojo::Transaction::HTTP ($ctx : L<Go::Context|SPVM::Go::Context>, $url : string|L<Mojo::URL|SPVM::Mojo::URL>, $args : object...);>

Perform blocking C<DELETE> request and return resulting L<Mojo::Transaction::HTTP|SPVM::Mojo::Transaction::HTTP> object, takes the same arguments as
L<Mojo::UserAgent::Transactor/"tx"> (except for the C<DELETE> method, which is implied).

Examples:

  my $tx = $ua->delete($ctx, "example.com");
  my $tx = $ua->delete($ctx, "http://example.com" => {Accept => "*/*"} => "Content!");
  my $tx = $ua->delete($ctx, "http://example.com" => {Accept => "*/*"} => [(object)form => {a => "b"}]);
  my $tx = $ua->delete($ctx, "http://example.com" => {Accept => "*/*"} => [(object)json => {a => "b"}]);

=head2 get

C<method get : Mojo::Transaction::HTTP ($ctx : L<Go::Context|SPVM::Go::Context>, $url : string|L<Mojo::URL|SPVM::Mojo::URL>, $args : object...);>

Perform blocking C<GET> request and return resulting L<Mojo::Transaction::HTTP|SPVM::Mojo::Transaction::HTTP> object, takes the same arguments as
L<Mojo::UserAgent::Transactor/"tx"> (except for the C<GET> method, which is implied).

Examples:

  my $tx = $ua->get($ctx, "example.com");
  my $tx = $ua->get($ctx, "http://example.com" => {Accept => "*/*"} => "Content!");
  my $tx = $ua->get($ctx, "http://example.com" => {Accept => "*/*"} => [(object)form => {a => "b"}]);
  my $tx = $ua->get($ctx, "http://example.com" => {Accept => "*/*"} => [(object)json => {a => "b"}]);

=head2 head

C<method head : Mojo::Transaction::HTTP ($ctx : L<Go::Context|SPVM::Go::Context>, $url : string|L<Mojo::URL|SPVM::Mojo::URL>, $args : object...);>

Perform blocking C<HEAD> request and return resulting L<Mojo::Transaction::HTTP|SPVM::Mojo::Transaction::HTTP> object, takes the same arguments as
L<Mojo::UserAgent::Transactor/"tx"> (except for the C<HEAD> method, which is implied).

Examples:

  my $tx = $ua->head($ctx, "example.com");
  my $tx = $ua->head($ctx, "http://example.com" => {Accept => "*/*"} => "Content!");
  my $tx = $ua->head($ctx, "http://example.com" => {Accept => "*/*"} => [(object)form => {a => "b"}]);
  my $tx = $ua->head($ctx, "http://example.com" => {Accept => "*/*"} => [(object)json => {a => "b"}]);

=head2 options

C<method options : Mojo::Transaction::HTTP ($ctx : L<Go::Context|SPVM::Go::Context>, $url : string|L<Mojo::URL|SPVM::Mojo::URL>, $args : object...);>

Perform blocking C<OPTIONS> request and return resulting L<Mojo::Transaction::HTTP|SPVM::Mojo::Transaction::HTTP> object, takes the same arguments as
L<Mojo::UserAgent::Transactor/"tx"> (except for the C<OPTIONS> method, which is implied).

Examples:

  my $tx = $ua->options($ctx, "example.com");
  my $tx = $ua->options($ctx, "http://example.com" => {Accept => "*/*"} => "Content!");
  my $tx = $ua->options($ctx, "http://example.com" => {Accept => "*/*"} => [(object)form => {a => "b"}]);
  my $tx = $ua->options($ctx, "http://example.com" => {Accept => "*/*"} => [(object)json => {a => "b"}]);

=head2 patch

C<method patch : Mojo::Transaction::HTTP ($ctx : L<Go::Context|SPVM::Go::Context>, $url : string|L<L<Mojo::URL|SPVM::Mojo::URL>|SPVM::Mojo::URL>, $args : object...);>

Perform blocking C<PATCH> request and return resulting L<Mojo::Transaction::HTTP|SPVM::Mojo::Transaction::HTTP> object, takes the same arguments as
L<Mojo::UserAgent::Transactor/"tx"> (except for the C<PATCH> method, which is implied).

Examples:

  my $tx = $ua->patch($ctx, "example.com");
  my $tx = $ua->patch($ctx, "http://example.com" => {Accept => "*/*"} => "Content!");
  my $tx = $ua->patch($ctx, "http://example.com" => {Accept => "*/*"} => [(object)form => {a => "b"}]);
  my $tx = $ua->patch($ctx, "http://example.com" => {Accept => "*/*"} => [(object)json => {a => "b"}]);

=head2 post

C<method post : Mojo::Transaction::HTTP ($ctx : L<Go::Context|SPVM::Go::Context>, $url : string|L<Mojo::URL|SPVM::Mojo::URL>, $args : object...);>

Perform blocking C<POST> request and return resulting L<Mojo::Transaction::HTTP|SPVM::Mojo::Transaction::HTTP> object, takes the same arguments as
L<Mojo::UserAgent::Transactor/"tx"> (except for the C<POST> method, which is implied).

Examples:

  my $tx = $ua->post($ctx, "example.com");
  my $tx = $ua->post($ctx, "http://example.com" => {Accept => "*/*"} => "Content!");
  my $tx = $ua->post($ctx, "http://example.com" => {Accept => "*/*"} => [(object)form => {a => "b"}]);
  my $tx = $ua->post($ctx, "http://example.com" => {Accept => "*/*"} => [(object)json => {a => "b"}]);

=head2 put

C<method put : Mojo::Transaction::HTTP ($ctx : L<Go::Context|SPVM::Go::Context>, $url : string|L<Mojo::URL|SPVM::Mojo::URL>, $args : object...);>

Perform blocking C<PUT> request and return resulting L<Mojo::Transaction::HTTP|SPVM::Mojo::Transaction::HTTP> object, takes the same arguments as
L<Mojo::UserAgent::Transactor/"tx"> (except for the C<PUT> method, which is implied).

Examples:

  my $tx = $ua->put($ctx, "example.com");
  my $tx = $ua->put($ctx, "http://example.com" => {Accept => "*/*"} => "Content!");
  my $tx = $ua->put($ctx, "http://example.com" => {Accept => "*/*"} => [(object)form => {a => "b"}]);
  my $tx = $ua->put($ctx, "http://example.com" => {Accept => "*/*"} => [(object)json => {a => "b"}]);

=head2 start

C<method start : Mojo::Transaction::HTTP ($ctx : L<Go::Context|SPVM::Go::Context>, $tx : Mojo::Transaction::HTTP);>

Perform blocking request for a custom L<Mojo::Transaction::HTTP|SPVM::Mojo::Transaction::HTTP> object, which can be prepared manually or with
L</"build_tx">.

Examples:

  my $tx = $ua->start($ctx, Mojo::Transaction::HTTP->new);

=head2 websocket

Not yet implemented.

=head1 See Also

=over 2

=item * L<SPVM::Mojolicious>

=back

=head1 Copyright & License

Copyright (c) 2025 Yuki Kimoto

MIT License

