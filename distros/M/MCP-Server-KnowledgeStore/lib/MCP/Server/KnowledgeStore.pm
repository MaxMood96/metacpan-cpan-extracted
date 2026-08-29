package MCP::Server::KnowledgeStore;
use v5.38;
use Mojo::Base 'Mojolicious', -signatures;

our $VERSION = '0.001';

# ABSTRACT: MCP server for shared memories, skills, specs, and agents

use Mojo::Util qw(secure_compare);
use MCP::Server::KnowledgeStore::Store;
use MCP::Server::KnowledgeStore::Tools;

has store => sub ($self) {
  my $dsn = $ENV{MCP_KS_PG} // $self->config->{pg}
    or die "MCP_KS_PG is not set: nothing to serve\n";
  return MCP::Server::KnowledgeStore::Store->new(pg => $dsn);
};

# Exposed so a test (or anything else embedding this app) can register
# an extra tool after startup - MCP::Server looks tools up by name per
# request, not from a snapshot taken when to_action() was called, so
# this stays live.
has mcp_server => sub ($self) {

  # Check if purge is disabled via environment variable
  my $allow_purge = !exists $ENV{MCP_KS_NO_PURGE} || !$ENV{MCP_KS_NO_PURGE};
  return MCP::Server::KnowledgeStore::Tools->build($self->store,
    allow_purge => $allow_purge,)->log($self->log);
};

sub startup ($self) {
  $self->plugin('Config' => { file => 'mcp-ks.conf' })
    if -f $self->home->child('mcp-ks.conf');

  push @{ $self->commands->namespaces },
    'MCP::Server::KnowledgeStore::Command';

  # A bootstrap credential, for reaching a fresh deployment before any
  # token has been minted. Unlike a real token it cannot be revoked from
  # the database, so drop it once `token add` has been run.
  my $bootstrap = $ENV{MCP_KS_TOKEN} // $self->config->{token};

  # Migrations run at startup, so a fresh database and an upgraded image
  # both end up at the current schema without a separate deploy step.
  $self->store->migrate unless $ENV{MCP_KS_NO_MIGRATE};

  my $server = $self->mcp_server;
  my $routes = $self->routes;

  # Agents authenticate with a bearer token and get the MCP tools. They
  # have no accounts and no sessions: this is the only way in, and it is
  # deliberately not shared with anything a human would log into. The
  # transport answers a false return with a 401 challenge of its own.
  my $action = $server->to_action(
    {
      auth => sub ($c) {
        my $header = $c->req->headers->authorization // '';
        my ($sent) = $header =~ /\ABearer[ ]+(\S+)\z/;
        return undef unless defined $sent;

        # The token's name becomes the principal, so every revision it
        # writes is attributed to the agent that presented it.
        if (my $token = $self->store->verify_token($sent)) {
          $c->stash('mcp.ks.principal' => $token->{name});
          return { principal => $token->{name} };
        }

        return undef unless defined $bootstrap && length $bootstrap;

        # Constant-time, so a wrong token leaks nothing through timing.
        return undef unless secure_compare($sent, $bootstrap);
        $c->stash('mcp.ks.principal' => 'bootstrap');
        return { principal => 'bootstrap' };
      },
    }
  );
  $routes->any('/mcp')->to(
    cb => sub ($c) {
      my $result = $action->($c);
      if (($c->res->code // 0) >= 400) {
        my $request = eval { $c->req->json } // {};
        my $reply   = eval { $c->res->json } // {};
        $server->log_transport_rejection($c->stash('mcp.ks.principal'),
          $request, $reply);
      }
      return $result;
    }
  )->name('mcp');

  # Unauthenticated on purpose: this is what traefik and the container
  # runtime poll, and it says nothing about the contents of the store. It
  # does touch the database, since a server that cannot reach Postgres is
  # not healthy however well it answers HTTP.
  $routes->get('/health')->to(
    cb => sub ($c) {
      my $ok = eval { $self->store->db->query('SELECT 1'); 1 };
      $c->app->log->error("Health check failed: $@") unless $ok;
      return $c->render(
        status => $ok ? 200 : 503,
        json   =>
          { status => $ok ? 'ok' : 'error', database => $ok ? 'up' : 'down' },
      );
    }
  )->name('health');

  return;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

MCP::Server::KnowledgeStore - MCP server for shared memories, skills, specs, and agents

=head1 VERSION

version 0.001

=head1 SYNOPSIS

  MCP_KS_PG=postgresql://mcp_ks@db/mcp_ks \
  MCP_KS_TOKEN=secret \
    ./bin/mcp-ks daemon -l 'http://*:3000'

  # then, from any MCP client
  https://mcp-memory.internal.lan/mcp

=head1 DESCRIPTION

A L<Mojolicious> application exposing one shared memory/skills store over
MCP, so every agent on the network reads and writes the same data instead
of keeping its own copy. See F<SPEC.md> for the problem it solves.

Entries live in Postgres and are append-only: each save adds a revision
rather than replacing one, so the history F<SPEC.md> expected from git
survives the move into the database.

Callers are agents, authenticated by a named token (see
L<MCP::Server::KnowledgeStore::Command::token>) and nothing more - no accounts, no
sessions. A token's name is recorded as the author of everything it
writes.

This is a bare L<Mojolicious> application - no UI, no templates. An
admin interface over the same store, if one gets built, is a separate
project talking to this one over MCP like any other agent, not
something bolted onto this app's base class.

=head1 CONFIGURATION

Environment variables win over F<mcp-ks.conf>.

=over

=item MCP_KS_PG / C<pg>

Postgres connection string for the shared store. Required.

=item MCP_KS_TOKEN / C<token>

A bootstrap bearer token, accepted in addition to the tokens in the
database. It exists to reach a fresh deployment before any token has been
minted; it cannot be revoked without a redeploy, so drop it once
C<token add> has been run. When unset, only database tokens are accepted.

=item MCP_KS_NO_MIGRATE

Set to skip running migrations at startup, for when the schema is managed
out of band.

=item MCP_KS_NO_PURGE

Set to a true value (e.g., C<1>) to disable the C<purge_*> tools across all
resource types. When disabled, calls to any purge tool will return an error.
This allows deployments to prevent permanent deletion while still allowing
archive/restore operations. Archive provides soft deletion that preserves
all data and history for audit purposes.

=item MOJO_LOG_LEVEL

Sets the Mojolicious log threshold. Supported values are C<trace>, C<debug>,
C<info>, C<warn>, C<error>, and C<fatal>. The default is C<trace> in
development mode and C<info> in other modes.

Successful tool calls are logged at C<info>. Arguments and replies are logged
at C<debug>, and raw request and reply envelopes at C<trace>. Unknown tools
and requests rejected by the HTTP transport are C<warn>, while tool failures
and exceptions are C<error>. C<fatal> remains available for unrecoverable
server conditions.

=back

=head1 ATTRIBUTES

=head2 store

The L<MCP::Server::KnowledgeStore::Store> the tools operate on, built from the
configuration above.

=head2 mcp_server

The assembled L<MCP::Server> - see L<MCP::Server::KnowledgeStore::Tools>. Exposed
so a tool can be registered on it after startup, which is how the test
suite verifies token attribution without depending on any resource
plugin.

=head1 METHODS

=head2 startup

Migrates the database, mounts the MCP endpoint at C</mcp> behind
bearer-token authentication, and a C</health> check that verifies the
database is reachable.

=head1 SEE ALSO

L<MCP::Server::KnowledgeStore::Store>, L<MCP::Server::KnowledgeStore::Tools>, L<MCP::Server>.

=head1 AUTHOR

Wesley Schwengle <waterkip@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2026 by Wesley Schwengle.

This is free software, licensed under:

  The (three-clause) BSD License

=cut
