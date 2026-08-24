#!perl
use v5.26;
use warnings;
use experimental 'signatures';
use Test::More;

package MyExample::Request {
  use parent 'PlackX::Framework::Request';
  sub app_namespace { 'MyExample' }
}

package MyExample2::Request {
  use parent 'PlackX::Framework::Request';
  sub app_namespace { 'MyExample2' }
}

# Basics
{
  # Require
  require_ok('PlackX::Framework::Request');

  # Create object
  my $request = MyExample::Request->new(sample_env());
  ok($request, 'Request object created');

  # Request properties
  ok( $request->isa('PlackX::Framework::Request'),  'Object isa PXF::Request'        );
  ok(!$request->isa('PlackX::Framework::Response'), 'Object is not a PXF::Response'  );
  ok( $request->isa('Plack::Request' ),             'Object also isa Plack::Request' );
  ok(!$request->isa('Plack::Response'),             'Object is not a Plack::Response');

  # Namespace
  ok($request->app_namespace eq 'MyExample',        'Namespace is set');

  # Stash
  my $stash = { boo => 'who' };
  $request->stash($stash);
  ok($request->stash->{boo} eq 'who');
  ok($request->stash_param('boo') eq 'who');
  ok(!$request->param('boo')); # should not merge
  ok(!$request->route_param('boo'));
  ok(!$request->cgi_param('boo'));

  # Route Params
  $request->route_parameters({ user_id => '8', page => 'paper' });
  ok($request->route_param('user_id') eq '8');
  ok($request->route_param('page') eq 'paper');

  # Params
  # Ensure cgi_param() can return list, param() can't
  ok(my $food = $request->param('food') eq 'pizza');
  ok(my $drink = $request->param('drink') =~ m/^(beer|pepsi|wine|water)$/);
  my @drinks = $request->cgi_param('drink');
  ok(@drinks == 4);
  my @sdrinks = $request->param('drink');
  ok(@sdrinks == 1);
}

# Flash
{
  require PlackX::Framework;
  my $name = PlackX::Framework::flash_cookie_name('MyExample');

  my $env  = sample_env();
  $env->{HTTP_COOKIE} = "$name=A%20Plain%20String";
  my $request  = MyExample::Request ->new($env);
  my $request2 = MyExample2::Request->new($env);

  ok(
    (substr($request->flash_cookie_name, 0, 5) eq 'flash'),
    'Flash cookie names starts with flash'
  );
  ok(
    (8 < length $request->flash_cookie_name && length $request->flash_cookie_name < 64),
    'Flash cookie name makes sense'
  );
  isnt(
    $request->flash_cookie_name => $request2->flash_cookie_name,
    'Different flash cookie names for different class names'
  );

  # Plain flash cookie
  is(   $request->flash  => 'A Plain String', 'Flash is set and url-decoded correctly');
  isnt( $request2->flash => 'A Plain String', 'Two different flashes are different');

  # JSON encoded
  my $hash = { key => 'value', key2 => 'value2', arr => [1..9] };
  my $val  = PXF::Util::encode_ju64($hash);
  $env->{HTTP_COOKIE} = "$name=$name-ju64-$val";
  $request = MyExample::Request->new($env);
  is_deeply($request->flash => $hash, 'Flash is correct (JSON-encoded hashref)');
}

# Routes/reroutes
{
  my $request = MyExample::Request->new(sample_env());

  ok($request->destination eq $request->path_info, 'destination is set to original');
  $request->reroute('/route-1');
  ok($request->destination eq '/route-1', 'reroute resets destination');
  is($request->max_reroutes => 16, 'max_reroutes is 16');

  { no warnings 'once';
    *MyExample::Request::max_reroutes = sub { 10 };
  }
  is($request->max_reroutes => 10, 'max_reroutes is adjustable to 10');

  # Raises error if excessive reroutes
  ok( eval { $request->reroute("/route-$_"); 1 }, 'reroute ok')
  for 2..10;
  ok(!eval { $request->reroute("/route-$_"); 1 }, 'excessive reroutes not ok')
  for 11..12;

  ok(
    ('/route-10' eq $request->env->{PATH_INFO} and '/route-10' eq $request->env->{REQUEST_URI}),
     'reroute alters psgi environment'
  );
}

# is_ methods
{
  my $env = sample_env();
  my $req;

  $req = MyExample::Request->new($env);
  ok(
    ($req->is_get and !$req->is_post and !$req->is_put and !$req->is_delete),
    'GET request is_get'
  );

  $env->{REQUEST_METHOD} = 'POST';
  $req = MyExample::Request->new($env);
  ok(
    (!$req->is_get and $req->is_post and !$req->is_put and !$req->is_delete),
    'POST request is_post'
  );

  $env->{REQUEST_METHOD} = 'PUT';
  $req = MyExample::Request->new($env);
  ok(
    (!$req->is_get and !$req->is_post and $req->is_put and !$req->is_delete),
    'PUT request is_put'
  );

  $env->{REQUEST_METHOD} = 'DELETE';
  $req = MyExample::Request->new($env);
  ok(
    (!$req->is_get and !$req->is_post and !$req->is_put and $req->is_delete),
    'DELETE request is_delete'
  );
}

# Small utils
{
  is(
    PlackX::Framework::Request::with_leadslash('hello') => '/hello',
    'with_leadslash adds slash when necessary'
  );

  is(
    PlackX::Framework::Request::with_leadslash('/hello') => '/hello',
    'with_leadslash unchanged if already has slash'
  );

  is(
    PlackX::Framework::Request::no_trailslash('hello/') => 'hello',
     'no_trailslash removestrailing slash'
  );

  is(
    PlackX::Framework::Request::no_trailslash('hello') => 'hello',
     'no_trailslash unchanged if no trailing slash'
  );

  my $request;
  $request = MyExample::Request->new(sample_env());
  is(
    $request->abs_to('/some/page'), 'http://example.com/foo/some/page',
    'abs_to() method'
  );
  is(
    $request->rel_to('/some/page'), '/foo/some/page',
     'rel_to() method'
  );

  $request = MyExample::Request->new(sample_env2());
  is(
    $request->abs_to('/some/page'), 'http://www.example.com/some/page',
     'abs_to() method (env 2)'
  );
  is(
    $request->rel_to('/some/page'), '/some/page',
     'rel_to() method (env 2)'
  );
}


done_testing();

####################################################

sub sample_env {
 return {
    REQUEST_METHOD    => 'GET',
    SERVER_PROTOCOL   => 'HTTP/1.1',
    SERVER_PORT       => 80,
    SERVER_NAME       => 'example.com',
    SCRIPT_NAME       => '/foo',
    REMOTE_ADDR       => '127.0.0.1',
    PATH_INFO         => '/foo',
    REQUEST_URI       => '/foo',
    HTTP_COOKIE       => 'NOT_IMPLEMENTED=NOT_IMPLEMENTED',
    QUERY_STRING      => 'food=pizza&drink=beer&drink=pepsi&drink=wine&drink=water',
    'psgi.version'    => [ 1, 0 ],
    'psgi.input'      => undef,
    'psgi.errors'     => undef,
    'psgi.url_scheme' => 'http',
  };
}

sub sample_env2 {
  return {
    'psgi.multithread' => !!0,
    'psgi.version' => [ 1, 1 ],
    'SERVER_PROTOCOL' => 'HTTP/1.1',
    'psgi.multiprocess' => !!0,
    #'psgi.input' => \*{'HTTP::Message::PSGI::$input'},
    'SCRIPT_NAME' => '',
    'REMOTE_ADDR' => '127.0.0.1',
    'HTTP_HOST' => 'www.example.com',
    'psgi.url_scheme' => 'http',
    'REQUEST_URI' => '/hello/there',
    'PATH_INFO' => '/hello/there',
    'REMOTE_HOST' => 'localhost',
    'psgi.run_once' => !!1,
    #'psgi.errors' => *::STDERR,
    'REMOTE_PORT' => 9735,
    'CONTENT_LENGTH' => 0,
    'psgi.nonblocking' => !!0,
    'SERVER_NAME' => 'www.example.com',
    'QUERY_STRING' => '',
    'psgi.streaming' => !!1,
    'SERVER_PORT' => 80,
    'REQUEST_METHOD' => 'GET'
  };
}
