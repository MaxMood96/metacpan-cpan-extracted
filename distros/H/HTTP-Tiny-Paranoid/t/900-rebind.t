#!perl

use warnings;
use strict;

use Test::More;
use Test::Fake::HTTPD;

use HTTP::Tiny::Paranoid;
use Net::DNS::Paranoid;

# Regression test for DNS rebind. We must pass the address that
# Net::DNS::Paranoid actually returned (if any) down to HTTP::Tiny, otherwise
# it will resolve the name again, which could come back with a different
# address.
#
# We simulate this by trying a request to an invalid hostname, and overriding
# Net::DNS::Paranoid's resolve function to force it to return the HTTP server
# IP for it. If HTTP::Tiny::Paranoid pass that IP down to HTTP::Tiny proper,
# then the request will work as it should. If it passed the host name, it would
# do its own resolve and fail, and so would the test.

my $httpd = run_http_server {
  return HTTP::Response->new(200, 'OK', undef, "hello\n");
};

{
  no warnings 'redefine';
  local *Net::DNS::Paranoid::resolve = sub { return ([$httpd->host], undef) };

  my $url = $httpd->endpoint;
  $url->host('rebind-test.invalid');

  my $res = HTTP::Tiny::Paranoid->new(timeout => 5)->get($url);
  ok $res->{success},
    'request to an unresolvable hostname succeeds using the approved address'
    or diag explain $res;
  is $res->{content}, "hello\n", '...and returns the expected body';
}

done_testing;
