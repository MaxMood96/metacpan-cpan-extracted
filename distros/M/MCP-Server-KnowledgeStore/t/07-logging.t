use v5.38;
use Test::Most;

use MCP::Server::Context;
use MCP::Server::KnowledgeStore::ResourceTemplates;

my $server = MCP::Server::KnowledgeStore::ResourceTemplates->new;
$server->tool(
  name => 'echo',
  code => sub ($tool, $args) {
    return $tool->structured_result({ echo => $args->{value} });
  },
);

sub context () {
  return MCP::Server::Context->new(
    legacy    => '2025-03-26',
    principal => 'agent-one',
  );
}

sub call ($name, $arguments = {}) {
  return {
    jsonrpc => '2.0',
    id      => 1,
    method  => 'tools/call',
    params  => { name => $name, arguments => $arguments },
  };
}

subtest 'info identifies the caller and tool' => sub {
  my $capture = $server->log->capture('info');
  $server->handle(call(echo => { value => 'hello' }), context());

  like "$capture", qr/\[info\] \[agent-one\] called \[echo\]/,
    'concise call logged';
  unlike "$capture", qr/hello/, 'arguments omitted';
};

subtest 'info does not serialize successful replies' => sub {
  my $serialized = 0;
  no warnings 'redefine';
  local *MCP::Server::KnowledgeStore::ResourceTemplates::to_json
    = sub (@args) {
    $serialized++;
    return Mojo::JSON::to_json(@args);
    };

  my $capture = $server->log->capture('info');
  $server->_log_tool_reply('agent-one', 'echo',
    { result => { isError => 0 } });

  is $serialized, 0, 'reply was not serialized';
};

subtest 'debug includes arguments and reply' => sub {
  my $capture = $server->log->capture('debug');
  $server->handle(call(echo => { value => 'hello' }), context());

  like "$capture",
    qr/\[debug\] \[agent-one\] called \[echo\] with \[\{"value":"hello"\}\]/,
    'arguments logged';
  like "$capture", qr/\[debug\].*reply \[/,        'reply logged';
  like "$capture", qr/\\?"echo\\?":\\?"hello\\?"/, 'reply value logged';
};

subtest 'unknown tools warn without an info call record' => sub {
  my $capture = $server->log->capture('trace');
  $server->handle(call('missing'), context());

  like "$capture", qr/\[warn\] \[agent-one\] called unknown tool \[missing\]/,
    'unknown tool logged';
  unlike "$capture", qr/\[info\].*called \[missing\]/,
    'unknown tool is not logged as a normal call';
};

subtest 'tool failures are errors' => sub {
  $server->tool(
    name => 'fails',
    code => sub ($tool, $args) { return $tool->text_result('nope', 1) },
  );
  my $capture = $server->log->capture('error');
  $server->handle(call('fails'), context());

  like "$capture", qr/\[error\] \[agent-one\] call \[fails\] failed/,
    'error result logged';
};

subtest 'tool exceptions are errors' => sub {
  $server->tool(
    name => 'dies',
    code => sub ($tool, $args) { die "broken tool\n" },
  );
  my $capture = $server->log->capture('error');
  $server->handle(call('dies'), context());

  like "$capture", qr/\[error\] \[agent-one\] call \[dies\] failed/,
    'exception response logged';
};

subtest 'transport rejections are warnings' => sub {
  my $capture = $server->log->capture('trace');
  $server->log_transport_rejection(
    'agent-one',
    call('echo', { value => 'hello' }),
    {
      jsonrpc => '2.0',
      id      => 1,
      error   => { code => -32020, message => 'Missing Mcp-Name header' },
    },
  );

  like "$capture",
    qr/\[warn\] \[agent-one\] MCP call \[echo\] rejected \[Missing Mcp-Name header\]/,
    'rejection reason logged';
  like "$capture", qr/\[debug\].*with .*hello.*reply/,
    'arguments and rejection reply logged';
};

done_testing;
