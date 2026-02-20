#!/usr/bin/env perl
use Mojo::Base -strict, -signatures;
use MCP::Server;

my $server = MCP::Server->new(name => 'TestServer');

$server->tool(
  name         => 'echo',
  description  => 'Echo the input text',
  input_schema => {
    type       => 'object',
    properties => { message => { type => 'string' } },
    required   => ['message'],
  },
  code => sub ($tool, $args) {
    return "Echo: $args->{message}";
  },
);

$server->tool(
  name         => 'add',
  description  => 'Add two numbers',
  input_schema => {
    type       => 'object',
    properties => {
      a => { type => 'number' },
      b => { type => 'number' },
    },
    required => ['a', 'b'],
  },
  code => sub ($tool, $args) {
    return $args->{a} + $args->{b};
  },
);

$server->to_stdio;
