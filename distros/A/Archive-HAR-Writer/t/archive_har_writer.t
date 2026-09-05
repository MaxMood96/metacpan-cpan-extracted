use Test2::V0 -no_srand => 1;
use v5.42;
use Archive::HAR::Writer;
use HTTP::Request;
use HTTP::Response;
use Mojo::Transaction::HTTP;
use JSON::MaybeXS ();
use Path::Tiny    qw( tempfile );

subtest 'basic object' => sub {
    my $har = Archive::HAR::Writer->new;
    isa_ok $har, 'Archive::HAR::Writer';
    is $har->api, 1, 'api defaults to 1';
};

subtest 'HTTP::Request / HTTP::Response transaction' => sub {
    my $req = HTTP::Request->new( GET => 'http://example.com/foo?bar=baz' );
    $req->protocol('HTTP/1.1');
    $req->header( 'User-Agent' => 'test-agent' );
    $req->header( 'Cookie'     => 'sid=abc123; theme=dark' );

    my $res = HTTP::Response->new( 200, 'OK' );
    $res->protocol('HTTP/1.1');
    $res->header( 'Content-Type' => 'application/json' );
    $res->header( 'Set-Cookie'   => 'sid=abc123; Path=/; HttpOnly' );
    $res->content('{"ok":true}');

    my $har = Archive::HAR::Writer->new;
    is $har->add_http_transaction( [ $req, $res ] ), $har, 'returns self';

    my $data  = _write_and_decode($har);
    my $entry = $data->{log}{entries}[0];

    is $entry->{request}{method},      'GET';
    is $entry->{request}{url},         'http://example.com/foo?bar=baz';
    is $entry->{request}{httpVersion}, 'HTTP/1.1';
    is $entry->{request}{queryString}, [ { name => 'bar', value => 'baz' } ];
    is $entry->{request}{cookies},     [ { name => 'sid', value => 'abc123' }, { name => 'theme', value => 'dark' }, ];

    is $entry->{response}{status},            200;
    is $entry->{response}{statusText},        'OK';
    is $entry->{response}{content}{mimeType}, 'application/json';
    is $entry->{response}{content}{text},     '{"ok":true}';
    is $entry->{response}{cookies},
      [
        {
            name     => 'sid',
            value    => 'abc123',
            path     => '/',
            httpOnly => T(),
        },
      ];
};

subtest 'Mojo::Transaction::HTTP transaction' => sub {
    my $tx = Mojo::Transaction::HTTP->new;
    $tx->req->method('POST');
    $tx->req->url->parse('http://example.com/submit');
    $tx->req->headers->content_type('application/x-www-form-urlencoded');
    $tx->req->body('a=1&b=2');
    $tx->res->code(302);
    $tx->res->message('Found');
    $tx->res->headers->location('http://example.com/done');

    my $har = Archive::HAR::Writer->new;
    $har->add_http_transaction($tx);

    my $data  = _write_and_decode($har);
    my $entry = $data->{log}{entries}[0];

    is $entry->{request}{method}, 'POST';
    is $entry->{request}{postData},
      {
        mimeType => 'application/x-www-form-urlencoded',
        text     => 'a=1&b=2',
      };
    is $entry->{response}{status},      302;
    is $entry->{response}{redirectURL}, 'http://example.com/done';
};

subtest 'binary response content is base64 encoded' => sub {
    my $req = HTTP::Request->new( GET => 'http://example.com/img' );
    my $res = HTTP::Response->new( 200, 'OK' );
    $res->header( 'Content-Type' => 'image/png' );
    $res->content("\x89PNG\r\n");

    my $har = Archive::HAR::Writer->new;
    $har->add_http_transaction( [ $req, $res ] );

    my $data    = _write_and_decode($har);
    my $content = $data->{log}{entries}[0]{response}{content};

    is $content->{encoding}, 'base64';
    is $content->{text}, "iVBORw0K", 'body is base64 encoded';
};

subtest 'multiple transactions accumulate' => sub {
    my $req = HTTP::Request->new( GET => 'http://example.com/' );
    my $res = HTTP::Response->new( 200, 'OK' );

    my $har = Archive::HAR::Writer->new;
    $har->add_http_transaction( [ $req, $res ] );
    $har->add_http_transaction( [ $req, $res ] );

    my $data = _write_and_decode($har);
    is scalar( $data->{log}{entries}->@* ), 2, 'two entries recorded';
    is $data->{log}{version},               '1.2';
    is $data->{log}{creator}{name},         'Archive::HAR::Writer';
};

subtest 'unsupported transaction types are rejected' => sub {
    my $har = Archive::HAR::Writer->new;

    like dies { $har->add_http_transaction('nope') }, qr/unsupported transaction type/, 'string rejected';

    like dies { $har->add_http_transaction( [ 'not a request', 'not a response' ] ) },
      qr/request must be an HTTP::Request/, 'bad request rejected';

    my $req = HTTP::Request->new( GET => 'http://example.com/' );
    like dies { $har->add_http_transaction( [ $req, 'not a response' ] ) },
      qr/response must be an HTTP::Response/, 'bad response rejected';
};

subtest 'write_file writes to disk' => sub {
    my $req = HTTP::Request->new( GET => 'http://example.com/' );
    my $res = HTTP::Response->new( 200, 'OK' );

    my $har = Archive::HAR::Writer->new;
    $har->add_http_transaction( [ $req, $res ] );

    my $file = tempfile();
    $har->write_file($file);

    my $data = JSON::MaybeXS::decode_json( $file->slurp_raw );
    is scalar( $data->{log}{entries}->@* ), 1;
};

sub _write_and_decode ($har) {
    my $out = '';
    $har->write( \$out );
    return JSON::MaybeXS::decode_json($out);
}

done_testing;
