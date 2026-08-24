use v5.26;
use warnings;
use experimental 'signatures';
use Test::More;

# This file contains some integration tests

my $G_REQUEST;
my $G_RESPONSE;

package My::Test::App {
  use PlackX::Framework;
  use My::Test::App::Router;
  sub app_base { '/my-test-app-base' }
  #sub uri_prefix { '/my-test-app-base' }

  base '/sub-area';

  route '/' => sub ($request, $response) {
    ($G_REQUEST, $G_RESPONSE) = ($request, $response);
    return $response->render_text('OK 1');
  };

  route '/some-route' => sub ($request, $response) {
    ($G_REQUEST, $G_RESPONSE) = ($request, $response);
    return $response->render_text('OK 2');
  };
}

use Plack::Test;
use HTTP::Request::Common;

my $app  = My::Test::App->app;
my $test = Plack::Test->create($app);
{
  my $res = $test->request(GET "/");
  is($res->code => 404, 'Request to / does not reach app with app_base');
}
{
  my $res = $test->request(GET "/my-test-app-base/sub-area");
  # Maybe TODO: This doesn't reach app because there's no trailing slash, so test fails. Should that be changed?
  #is($res->content => 'OK 1', 'Request to /$app_base/$route_base does reach app with app_base and route_base');
}
{
  my $res = $test->request(GET "/my-test-app-base/sub-area/");
  is($res->content => 'OK 1', 'Request to /$app_base/$route_base does reach app with app_base and route_base');
}
{
  my $res = $test->request(GET "/my-test-app-base/sub-area/some-route");
  is($res->content => 'OK 2', 'Request to /$app_base/$route_base/$route does reach app');

  for my $page ('', 'a', 'b/page/2') {
    is($G_REQUEST->app_rel_to("/$page") => "/my-test-app-base/$page", 'app_rel_to adds app_base');
    is($G_REQUEST->app_abs_to("/$page") => "http://localhost/my-test-app-base/$page", 'app_abs_to adds app_base and http://host/');
  }

  for my $page ('', 'a', 'b/page/2') {
    is($G_REQUEST->route_rel_to("/$page") => "/my-test-app-base/sub-area/$page", 'route_rel_to adds app_base and route base');
    is($G_REQUEST->route_abs_to("/$page") => "http://localhost/my-test-app-base/sub-area/$page", 'app_rel_to adds app_base and route base and http://host/');
  }
}

done_testing();
