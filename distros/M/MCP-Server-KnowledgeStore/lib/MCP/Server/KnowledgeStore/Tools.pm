package MCP::Server::KnowledgeStore::Tools;
use v5.38;
use Mojo::Base -strict, -signatures;

our $VERSION = '0.001';

# ABSTRACT: Discovers and assembles the installed MCP::Server::KnowledgeStore::Tools::* plugins

use MCP::Server;
use Mojo::JSON qw(false);
use Module::Pluggable::Object;
use MCP::Server::KnowledgeStore::ResourceTemplates;

sub build ($class, $store, %opts) {

  # Use our extended server class for resource template support
  my $server = MCP::Server::KnowledgeStore::ResourceTemplates->new(
    name         => 'mcp-knowledge-store',
    version      => $VERSION,
    instructions => <<~'END',
      One canonical store for project memories and skills, shared by every
      agent. Prefer these tools over any local copy: this store is
      authoritative. Search or list before saving, so an existing entry
      gets updated instead of duplicated under a new name.
      END
  );

  # Server-level configuration
  my $allow_purge = exists $opts{allow_purge} ? $opts{allow_purge} : 1;

  # Cross-cutting, not owned by any one resource plugin - it aggregates
  # across whatever memory/skill/spec/agent tags exist, so it stays here
  # rather than being invented by one plugin and missed by the others.
  $server->tool(
    name        => 'list_projects',
    description =>
      'List distinct project names in use across memories, skills, specs '
      . 'and agents',
    input_schema =>
      { type => 'object', properties => {}, additionalProperties => false },
    code => sub ($tool, $args) {
      return $tool->structured_result({ projects => $store->list_projects });
    },
  );

  for my $plugin ($class->plugins) {
    $plugin->register($server, $store, allow_purge => $allow_purge);
  }

  return $server;
}

# One plugin per resource (Memory, Skill, Spec, Agent, ...), each its
# own distribution depending on this one for Store and Support. Adding
# a resource means installing a new MCP::Server::KnowledgeStore::Tools::* dist,
# not editing this file.
sub plugins ($class) {
  my $finder = Module::Pluggable::Object->new(
    search_path => 'MCP::Server::KnowledgeStore::Tools',
    require     => 1,
    except => qr/^MCP::Server::KnowledgeStore::Tools::(Support|Revisioned)\z/,
  );
  return $finder->plugins;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

MCP::Server::KnowledgeStore::Tools - Discovers and assembles the installed MCP::Server::KnowledgeStore::Tools::* plugins

=head1 VERSION

version 0.001

=head1 SYNOPSIS

  use MCP::Server::KnowledgeStore::Store;
  use MCP::Server::KnowledgeStore::Tools;

  my $store  = MCP::Server::KnowledgeStore::Store->new(pg => $dsn);
  my $server = MCP::Server::KnowledgeStore::Tools->build($store);
  $server->to_stdio;

=head1 DESCRIPTION

Assembles an L<MCP::Server> (specifically L<MCP::Server::KnowledgeStore::ResourceTemplates>,
which extends MCP::Server with resource template support) from whichever
C<MCP::Server::KnowledgeStore::Tools::*> plugin distributions happen to be installed -
C<::Memory>, C<::Skill>, C<::Spec>, C<::Agent> and so on each live in their
own repository and release independently of this one and of each other.
This module itself only registers the one cross-cutting tool, C<list_projects>,
that no single plugin owns.

Resource templates provide addressable reads via URIs as an alternative to
C<get_*> tools. For example, C<memory://memories/my-memory> or
C<memory://memories/my-memory/revisions/1>.

A plugin is any package under the C<MCP::Server::KnowledgeStore::Tools::>
namespace implementing:

  sub register ($class, $server, $store) { ... }

which adds its own tools to C<$server> via C<< $server->tool(...) >> and
resource templates via C<< $server->add_template(...) >>,
using C<$store> (a L<MCP::Server::KnowledgeStore::Store>) for persistence.
C<MCP::Server::KnowledgeStore::Tools::Support> provides the schema fragments and
helpers most plugins need, and C<MCP::Server::KnowledgeStore::Tools::Revisioned>
provides the whole tool set for a revisioned/taggable resource in one
call - both are excluded from discovery, since neither is a plugin
itself.

=head1 METHODS

=head2 build

  my $server = MCP::Server::KnowledgeStore::Tools->build($store);

Returns an L<MCP::Server> with C<list_projects> plus everything every
installed plugin registers.

=head2 plugins

  my @plugin_classes = MCP::Server::KnowledgeStore::Tools->plugins;

The installed, loaded plugin classes, discovered via
L<Module::Pluggable::Object>.

=head1 AUTHOR

Wesley Schwengle <waterkip@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2026 by Wesley Schwengle.

This is free software, licensed under:

  The (three-clause) BSD License

=cut
