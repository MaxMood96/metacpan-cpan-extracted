#!perl
use v5.26;
use warnings;
use Test::More;

{
  # Require
  require_ok('PlackX::Framework::Response');

  # Create
  {
    my $response = PlackX::Framework::Response->new;
    ok($response, 'Create response object');
    isa_ok($response, 'PlackX::Framework::Response');

    # Response properties
    ok(!$response->isa('Plack::Request' ));
    ok( $response->isa('Plack::Response'));

    # Stop and continue
    ok($response->last eq $response,  'last()');
    ok($response->stop eq $response,  'stop()');
    ok(not($response->next), 'next()');

    # Defaults
    $response->set_defaults;
    ok(
      ($response->charset eq 'utf8' and $response->content_type eq 'text/html' and $response->status == 200),
      'set_defaults: Default charset is utf8, status 200, content-type text/html'
    );
  }

  # Cleanup callbacks
  {
    my $response = PlackX::Framework::Response->new;
    $response->add_cleanup_callback(sub { 111; });
    $response->add_cleanup_callback(sub { 222; });
    ok(
      ref $response->cleanup_callbacks eq 'ARRAY',
      'add_cleanup_callback() / cleanup_callbacks()'
    );
    is(
      scalar($response->cleanup_callbacks->@*) => 2,
      'cleanup_callbacks has the right number of callbacks'
    );
    is(
      $response->cleanup_callbacks->[0]->() => 111,
      'execute cleanup_callback 1'
    );
    is(
      $response->cleanup_callbacks->[1]->() => 222,
       'execute cleanup_callback 2'
    );
  }

  # Charset then Content type
  {
    my $response = PlackX::Framework::Response->new;
    is_deeply(
      [$response->content_type] => [''],
      'Empty content_type upon new()'
    );

    $response->charset('abc');
    is(
      $response->charset => 'abc',
      'Charset set successfully (before content_type)'
    );

    $response->content_type('text/test');
    is_deeply(
      [$response->headers->content_type] => ['text/test', 'charset=abc'],
      'Set charset then content-type'
    );

    # Set charset with content_type overrides earlier charset() call
    $response->content_type('text/test2; charset=def');
    is_deeply(
      [$response->headers->content_type] => ['text/test2', 'charset=def'],
      'Content_type is correct after setting content-type then charset'
    );
  }

  # Content-type then charset
  {
    my $response = PlackX::Framework::Response->new;
    $response->content_type('text/test3; charset=hij');
    $response->charset('klm');
    is(
      $response->charset => 'klm',
      'Charset set successfully (after content-type)'
    );
    is_deeply(
      [$response->headers->content_type] => ['text/test3', 'charset=klm'],
      'Content_type is correct after setting content-type then charset'
    );
  }

  # Print
  {
    my $response = PlackX::Framework::Response->new;
    $response->print('Line 1');
    $response->print('Line 2');
    my $body = join '', $response->body->@*;
    is($body => 'Line 1Line 2', 'object method print() adds lines to body');
  }

  # Redirect/Finalize
  {
    my $response = PlackX::Framework::Response->new;
    my $return = $response->redirect('http://example.example/');
    is(
      $return => $response,
      'redirect() returns same object'
    );
    is_deeply(
      $response->finalize => [303, ['Location','http://example.example/'],[]],
      'redirect() and finalize() sets location header and status code 303'
    );

    $response->redirect('http://example.example2/', 399);
    is(
      $response->status => 399,
      'redirect override status code'
    );
  }

  # Flash
  {
    # We have to subclass to override flash_cookie_name()
    eval q{
      package PXF_Test_Response {
        use parent 'PlackX::Framework::Response';
        sub app_namespace     { die }
        sub flash_cookie_name { 'flash-123456789-test' }
      }
      1;
    } or die 'Could not create sublcass of PXFR: ' .$@;

    my $response = PXF_Test_Response->new(200);
    $response->flash("A plain string!");
    is(
      $response->finalize->[1][0] => 'Set-Cookie',
      'Flash cookie is set'
    );

    my ($cookie_value) = split /; /, $response->finalize->[1][1];
    is(
      $cookie_value => 'flash-123456789-test=A%20plain%20string%21',
      'Flash cookie value is correct (plain string)'
    );

    # This should get converted to JSON-url-base64
    my $hashref = { title => "Hello\r\n", message => 'World!!!?', array => [0..9] };
    $response->flash($hashref);
    ($cookie_value) = split /; /, $response->finalize->[1][1];
    ok(
      $cookie_value =~
      m/^flash-123456789-test=flash-123456789-test-ju64-([a-zA-Z0-9_-]+)$/,
      'Flash cookie hashref is converted to JSON ub64'
    );

    my $coded = $1;
    is_deeply(
      PXF::Util::decode_ju64($coded) => $hashref,
      'JSON cookie decoded back to hashref correctly'
    );
  }

  # render_file / filehandle
  # test: render_file(filename), (type, filename), render_fh(filename), render_fh(type, filename)
  {
    my $response = PlackX::Framework::Response->new;
    $response->content_type('nobody/nothing');
    $response->render_file('./t/tsupport/image.png');

    is(
      $response->content_type => 'image/png',
      'render_file(filename): Content-Type is set correctly'
    );

    my $body = $response->body;
    ok(
      (ref $body and ("$body" =~ m/GLOB/ or $body->can('getline'))),
      'render_file sets body to a file handle or object with a getline() method'
    );

    # Read the body
    {
      my $body_data;
      if ($body->can('getline')) {
        local $/;
        $/ = \16384;
        $body_data = $body->getline;
      } else {
        local $/;
        $/ = \16384;
        $body_data = <$body>;
      }
      open my $fh, '<:raw', './t/tsupport/image.png'
        or die "Cannot open file, $!";
      local $/;
      my $real_content = <$fh>;
      close $fh;
      is(
        $body_data => $real_content,
        "File is read correctly: strings match"
      );
      is(
        length $body_data => -s './t/tsupport/image.png',
        'Files is read correctly: bytes read is equal to file size'
      );
    }

    ####################
    # render_* methods #
    ####################

    $response->render_file('manual/no-type', './t/tsupport/image.png');
    is(
      $response->content_type => 'manual/no-type',
      'render_file(type, filename) overrides content-type'
    );

    $response = PlackX::Framework::Response->new;
    $response->content_type('test/test');
    $response->render_fh(undef, $body);
    is(
      $response->content_type => 'test/test',
      'render_fh($filehandle) preserves manual content-type'
    );

    $response = PlackX::Framework::Response->new;
    $response->content_type('manual/manual');
    $response->render_file('./t/tsupport/nothing.empty');
    is(
      $response->content_type => 'manual/manual',
      'render_file($filename) preserves content-type when it cannot be auto-detected'
    );
  }

  # render_json
  require JSON::MaybeXS;
  {
    my $data = { number => 1, array => [1,2,3], hash => { fruit => 'banana' }};
    my $response = PlackX::Framework::Response->new;
    $response->render_json($data);
    is(
      $response->content_type => 'application/json',
      'render_json sets content_type'
    );
    my $body = $response->body;
    $body = $body->[0] if ref $body;

    JSON::MaybeXS->new->decode($body);
    is_deeply(
      JSON::MaybeXS->new->decode($body) => $data,
      'render_json encode/decode ok'
    );
  }

  # render_text
  {
    my $response = PlackX::Framework::Response->new;
    $response->render_text('Hello World!');
    is(
      $response->content_type => 'text/plain',
       'render_text sets content_type'
    );
    is(
      (ref $response->body ? $response->body->[0] : $response->body) => 'Hello World!',
       'render_text sets body'
    );
  }

  # render_html
  {
    my $response = PlackX::Framework::Response->new;
    $response->render_html('<p>Hello World!</p>');
    is(
      $response->content_type => 'text/html',
       'render_html sets content_type'
    );
    is(
      (ref $response->body ? $response->body->[0] : $response->body) => '<p>Hello World!</p>',
       'render_html sets body'
    );
  }

  # render_stream
  {
    my $response = PlackX::Framework::Response->new;
    my $sub      = sub { 'render_stream_test' };
    my $return = $response->render_stream($sub);
    is(
      $return => $response,
      'render_stream returns response object'
    );
    is(
      $response->stream->() => 'render_stream_test',
      'render_stream sets stream() property'
    );
  }

  # render_template
  {
    my $response = PlackX::Framework::Response->new;
    $response->{template} = bless {}, 'pxf_mock_template';
    my $return = $response->render_template;
    is(
      $return => $response,
      'render_template returns response object'
    );
  }
}
done_testing();

package pxf_mock_template { sub render { } }
