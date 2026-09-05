use Test2::V0 -no_srand => 1;
use v5.42;
use Archive::HAR::Writer;
use HTTP::Request;
use HTTP::Response;
use Mojo::Transaction::HTTP;
use JSON::MaybeXS ();
use JSON::Validator ();
use Path::Tiny      qw( path );
use Cwd             ();

my $schema_dir = path(__FILE__)->parent->child('data/har-schema')->realpath;

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
    $har->add_http_transaction( [ $req, $res ] );

    _is_valid_har($har);
};

subtest 'Mojo::Transaction::HTTP transaction with postData and redirect' => sub {
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

    _is_valid_har($har);
};

subtest 'binary response content is base64 encoded' => sub {
    my $req = HTTP::Request->new( GET => 'http://example.com/img' );
    my $res = HTTP::Response->new( 200, 'OK' );
    $res->header( 'Content-Type' => 'image/png' );
    $res->content("\x89PNG\r\n");

    my $har = Archive::HAR::Writer->new;
    $har->add_http_transaction( [ $req, $res ] );

    _is_valid_har($har);
};

subtest 'multiple transactions accumulate' => sub {
    my $req = HTTP::Request->new( GET => 'http://example.com/' );
    my $res = HTTP::Response->new( 200, 'OK' );

    my $har = Archive::HAR::Writer->new;
    $har->add_http_transaction( [ $req, $res ] );
    $har->add_http_transaction( [ $req, $res ] );

    _is_valid_har($har);
};

sub _is_valid_har ($har) {
    my $out = '';
    $har->write( \$out );
    my $data = JSON::MaybeXS::decode_json($out);

    my @errors = _validator()->validate($data);
    unless ( ok( @errors == 0, 'HAR document conforms to the HAR 1.2 schema' ) ) {
        diag "$_" for @errors;
    }
}

sub _validator {
    state $validator;
    return $validator //= do {
        my $cwd = Cwd::getcwd();
        chdir $schema_dir or die "chdir $schema_dir: $!";
        my $v = JSON::Validator->new->schema('har.json');
        chdir $cwd or die "chdir $cwd: $!";
        $v;
    };
}

done_testing;
