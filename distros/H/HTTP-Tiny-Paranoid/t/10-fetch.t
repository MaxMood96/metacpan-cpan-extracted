#!perl

use warnings;
use strict;

use Test::More;
use Test::Fake::HTTPD;

use HTTP::Tiny::Paranoid;

{
  # loopback is in Net::DNS::Paranoid's default blocked ranges, so this
  # never even reaches the network.
  my $res = HTTP::Tiny::Paranoid->new(timeout => 5)->get('http://127.0.0.1/');
  ok !$res->{success}, 'fetch to loopback address is blocked by default';
  is $res->{status}, 599, '...with internal exception status';
  like $res->{content}, qr/bad host/, '...and expected reason';
}

{
  HTTP::Tiny::Paranoid->whitelisted_hosts(['127.0.0.1']);

  my $httpd = run_http_server {
    return HTTP::Response->new(200, 'OK', undef, "hello\n");
  };

  my $res = HTTP::Tiny::Paranoid->new(timeout => 5)->get($httpd->endpoint);
  ok $res->{success}, 'fetch to whitelisted loopback address succeeds';
  is $res->{content}, "hello\n", '...and returns the expected body';
}

done_testing;
