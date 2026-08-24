#!perl
use v5.26;
use warnings;
use experimental 'signatures';
use Test::More;
use Test::TCP;
use HTTP::Server::PSGI;
use Plack::LWPish;
use HTTP::Request;
use PXF::Util ();

use constant BODY_LINES => 5;
our $SLEEP_TIME  = 0.25;
our $TCP_TEST_OK = 0;

do_tests();
done_testing();

#######################################################################

sub do_tests {
  my @content = map { "Content-Line-$_:" . int(rand(10_000)) . "\n" } 1..BODY_LINES;

  ok(
    eval {
      package My::Test::App {
        use PlackX::Framework;
        use My::Test::App::Router;

        route '/streaming-test' => sub ($request, $response) {
          die "Server does not support streaming"
            if !$request->env->{'psgi.streaming'} and !$request->env->{'test.streaming.off'};

          # Copy content so we don't alter original array
          my @content = @content;

          # Print some lines without streaming to make sure everything is
          # sent in the correct order
          $response->print(shift @content);
          $response->print(shift @content);

          # Check to make sure there is still some content left to stream
          die 'Need at least two more lines for proper streaming test'
            unless @content >= 2;

          # Stream remaining content
          return $response->render_stream(sub {
            do { $response->print($_); PXF::Util::minisleep $SLEEP_TIME } for @content;
          });
        };
      }
      1;
    },
    'Make a streaming app'
  );

  ok(
    (My::Test::App->app and ref My::Test::App->app eq 'CODE'),
    'Test app is an app'
  );

  ##############################################################
  # If this very simple app fails we won't proceed with the test
  eval {
    test_tcp(
      listen => 1,
      server => sub ($socket, @slurp) {
        my $server = HTTP::Server::PSGI->new(listen_sock => $socket);
        $server->run(sub { [200, [], ['OK']] }); #My::Test::App->app);
      },
      client => sub ($port, @slurp) {
        my $res = Plack::LWPish->new->request(
          HTTP::Request->new(GET => "http://127.0.0.1:$port/simple-test")
        );
        $TCP_TEST_OK = ($res->content eq 'OK');
      },
    );
    1;
  } or warn $@;
  ##############################################################

  SKIP: {
    $TCP_TEST_OK or skip 'Unable simple TCP test, will not test streaming body response';

    # With Streaming ON
    {
      my @client_data;

      test_tcp(
        listen => 1,
        server => sub ($socket, @slurp) {
          my $server = HTTP::Server::PSGI->new(listen_sock => $socket);
          $server->run(My::Test::App->app);
        },
        client => sub ($port, @slurp) {
          @client_data = run_client(host => '127.0.0.1', port => $port, path => '/streaming-test');
        },
      );

      my $body_text = join '', map { $_->{line} =~ m/^Content-Line/ ? $_->{line} : () } @client_data;
      is($body_text => join('', @content), 'Streaming ON: Streamed body content is as expected');

      my $elapsed = $client_data[-1]{'time'} - $client_data[-2]{'time'};
      ok(
        ($SLEEP_TIME*0.75 < $elapsed && $elapsed < $SLEEP_TIME*1.25),
        "Streaming ON: Last two lines received ${SLEEP_TIME}s +/- 25% apart (actual: ${elapsed}s)"
      );
    }

    # With Streaming OFF
    {
      my @client_data;

      test_tcp(
        listen => 1,
        server => sub ($socket, @slurp) {
          my $server = HTTP::Server::PSGI->new(listen_sock => $socket);
          $server->run(sub ($env) {
            $env->{'psgi.streaming'}     = !!0;
            $env->{'test.streaming.off'} = !!1;
            My::Test::App->app->($env);
          });
        },
        client => sub ($port, @slurp) {
          @client_data = run_client(host => '127.0.0.1', port => $port, path => '/streaming-test');
        },
      );

      my $body_text = join '', map { $_->{line} =~ m/^Content-Line/ ? $_->{line} : () } @client_data;
      is($body_text => join('', @content), 'Streaming OFF: Streamed body content is as expected');

      my $elapsed = $client_data[-1]{'time'} - $client_data[-2]{'time'};
      ok(
        ($elapsed < 0.01),
         "Streaming OFF: Minimal (< 0.01s) delay between body lines (actual: ${elapsed}s)"
      );
    }
  };
}

sub run_client (%options) {
  require IO::Socket::INET;
  require Time::HiRes;

  my $socket = IO::Socket::INET->new(
    PeerAddr => $options{host},
    PeerPort => $options{port},
    Proto    => 'tcp',
  ) or die "Could not connect to server - $!";

  # Send HTTP request manually
  print $socket "GET $options{path} HTTP/1.0\r\n";
  print $socket "Connection: close\r\n";
  print $socket "\r\n";

  # Read and save the response and time of each line
  my @received_data = ();
  push @received_data, { line => $_, time => Time::HiRes::time() } while <$socket>;

  # Close the connection
  close($socket);

  return @received_data;
}
