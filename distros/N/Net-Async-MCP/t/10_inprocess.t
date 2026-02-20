use strict;
use warnings;
use Test2::V0;

use IO::Async::Loop;
use Net::Async::MCP;
use MCP::Server;

# Create test MCP server with tools
my $server = MCP::Server->new(name => 'TestServer');

$server->tool(
  name         => 'echo',
  description  => 'Echo the input text',
  input_schema => {
    type       => 'object',
    properties => { message => { type => 'string' } },
    required   => ['message'],
  },
  code => sub { return "Echo: $_[1]->{message}" },
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
  code => sub { return $_[1]->{a} + $_[1]->{b} },
);

# Create MCP client with InProcess transport
my $loop = IO::Async::Loop->new;
my $mcp = Net::Async::MCP->new(server => $server);
$loop->add($mcp);

# Test initialize
{
  my $result = $mcp->initialize->get;
  is($result->{serverInfo}{name}, 'TestServer', 'server name from initialize');
  ok($result->{capabilities}, 'capabilities returned');
  is($mcp->server_info->{name}, 'TestServer', 'server_info accessor');
}

# Test ping
{
  my $ok = $mcp->ping->get;
  ok($ok, 'ping succeeds');
}

# Test list_tools
{
  my $tools = $mcp->list_tools->get;
  is(scalar @$tools, 2, 'two tools listed');

  my %by_name = map { $_->{name} => $_ } @$tools;
  ok($by_name{echo}, 'echo tool exists');
  ok($by_name{add}, 'add tool exists');
  is($by_name{echo}{description}, 'Echo the input text', 'echo description');
}

# Test call_tool - echo
{
  my $result = $mcp->call_tool('echo', { message => 'hello world' })->get;
  ok(!$result->{isError}, 'echo not an error');
  is($result->{content}[0]{type}, 'text', 'content type is text');
  is($result->{content}[0]{text}, 'Echo: hello world', 'echo result correct');
}

# Test call_tool - add
{
  my $result = $mcp->call_tool('add', { a => 3, b => 4 })->get;
  ok(!$result->{isError}, 'add not an error');
  is($result->{content}[0]{text}, '7', 'add result correct');
}

# Test call_tool - nonexistent tool
{
  my $f = $mcp->call_tool('nonexistent', {});
  ok($f->failure, 'calling nonexistent tool fails');
  like($f->failure, qr/not found/i, 'error mentions not found');
}

# Test list_prompts (empty)
{
  my $prompts = $mcp->list_prompts->get;
  is(scalar @$prompts, 0, 'no prompts');
}

# Test list_resources (empty)
{
  my $resources = $mcp->list_resources->get;
  is(scalar @$resources, 0, 'no resources');
}

done_testing;
