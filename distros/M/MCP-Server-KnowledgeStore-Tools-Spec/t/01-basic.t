use strict;
use warnings;
use Test::More 0.96;
use MCP::Server;

use_ok("MCP::Server::KnowledgeStore::Tools::Spec");

my $server = MCP::Server->new(name => 'test');
MCP::Server::KnowledgeStore::Tools::Spec->register($server, bless({}, 'TestStore'));
my ($save_spec) = grep { $_->{name} eq 'save_spec' } $server->{tools}->@*;
ok $save_spec->{input_schema}{additionalProperties},
  'save_spec accepts and ignores additional arguments';

done_testing;
