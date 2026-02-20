use strict;
use warnings;
use Test2::V0;

use IO::Async::Loop;
use Net::Async::MCP;
use File::Basename qw( dirname );

my $server_script = dirname(__FILE__) . '/bin/test_mcp_server.pl';

# Create MCP client with Stdio transport
my $loop = IO::Async::Loop->new;
my $mcp = Net::Async::MCP->new(
  command => [ $^X, $server_script ],
);
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
}

# Test call_tool - echo
{
  my $result = $mcp->call_tool('echo', { message => 'via stdio' })->get;
  ok(!$result->{isError}, 'echo not an error');
  is($result->{content}[0]{text}, 'Echo: via stdio', 'echo result correct');
}

# Test call_tool - add
{
  my $result = $mcp->call_tool('add', { a => 10, b => 20 })->get;
  ok(!$result->{isError}, 'add not an error');
  is($result->{content}[0]{text}, '30', 'add result correct');
}

# Test multiple rapid requests
{
  my @futures;
  for my $i (1..5) {
    push @futures, $mcp->call_tool('echo', { message => "msg$i" });
  }
  for my $i (1..5) {
    my $result = $futures[$i-1]->get;
    is($result->{content}[0]{text}, "Echo: msg$i", "rapid request $i correct");
  }
}

# Test shutdown
{
  my $ok = $mcp->shutdown->get;
  ok($ok, 'shutdown succeeds');
}

done_testing;
