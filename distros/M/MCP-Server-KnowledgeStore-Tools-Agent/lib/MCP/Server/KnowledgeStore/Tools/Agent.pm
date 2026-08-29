package MCP::Server::KnowledgeStore::Tools::Agent;
use v5.38;
use Mojo::Base -strict, -signatures;

our $VERSION = '0.001';

# ABSTRACT: The agent MCP tools, as an MCP::Server::KnowledgeStore::Tools plugin

use Mojo::JSON qw(false);
use MCP::Server::KnowledgeStore::Tools::Support
  qw(name_pattern author author_property);

my $NAME_PATTERN = name_pattern;

sub _project_property () {
  return {
    project => {
      type        => 'string',
      description => 'Only agents tagged as tailored for this project',
    },
  };
}

sub register ($class, $server, $store, %opts) {
  $server->tool(
    name        => 'list_agents',
    description =>
      'List agent definitions held in the store - global, one per name '
      . '(there is one "analyse", not a per-project copy). project filters '
      . 'to agents tailored for that project; omit it to list every agent.',
    input_schema => {
      type                 => 'object',
      properties           => _project_property(),
      additionalProperties => false,
    },
    code => sub ($tool, $args) {
      return $tool->structured_result(
        { agents => $store->list_agents($args->{project}) });
    },
  );

  $server->tool(
    name        => 'get_agent',
    description =>
      'Fetch the full content of one agent definition (.claude/agents/*.md), '
      . 'verbatim - frontmatter and all, unparsed',
    input_schema => {
      type       => 'object',
      properties => { name => { type => 'string', pattern => $NAME_PATTERN } },
      required   => ['name'],
      additionalProperties => false,
    },
    code => sub ($tool, $args) {
      my $agent = $store->get_agent($args->{name});
      return $tool->text_result("No agent named '$args->{name}'", 1)
        unless $agent;
      return $agent->{body};
    },
  );

  $server->tool(
    name        => 'save_agent',
    description =>
      'Save an agent definition verbatim, overwriting whatever was there for '
      . 'that name - no revision history, no frontmatter parsing. Agents are '
      . 'global; use tag_agent to say which projects it fits.',
    input_schema => {
      type       => 'object',
      properties => {
        name    => { type => 'string', pattern => $NAME_PATTERN },
        content => { type => 'string' },
        author_property()->%*,
      },
      required             => [qw(name content)],
      additionalProperties => false,
    },
    code => sub ($tool, $args) {
      my $agent = $store->save_agent($args->{name}, $args->{content},
        author => author($tool, $args));
      return $tool->structured_result(
        { name => $agent->{name}, updated_at => "$agent->{updated_at}" });
    },
  );

  $server->tool(
    name        => 'tag_agent',
    description =>
      'Tag an agent as tailored for a project (additive - does not remove '
      . 'other tags)',
    input_schema => {
      type       => 'object',
      properties => {
        name    => { type => 'string', pattern => $NAME_PATTERN },
        project => { type => 'string' },
      },
      required             => [qw(name project)],
      additionalProperties => false,
    },
    code => sub ($tool, $args) {
      eval { $store->tag_agent($args->{name}, $args->{project}) };
      return $tool->text_result("No agent named '$args->{name}'", 1) if $@;
      return $tool->structured_result(
        { name => $args->{name}, project => $args->{project} });
    },
  );

  $server->tool(
    name         => 'untag_agent',
    description  => "Remove an agent's tag for a project",
    input_schema => {
      type       => 'object',
      properties => {
        name    => { type => 'string', pattern => $NAME_PATTERN },
        project => { type => 'string' },
      },
      required             => [qw(name project)],
      additionalProperties => false,
    },
    code => sub ($tool, $args) {
      $store->untag_agent($args->{name}, $args->{project});
      return $tool->structured_result(
        { name => $args->{name}, project => $args->{project} });
    },
  );

  return;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

MCP::Server::KnowledgeStore::Tools::Agent - The agent MCP tools, as an MCP::Server::KnowledgeStore::Tools plugin

=head1 VERSION

version 0.001

=head1 SYNOPSIS

  use MCP::Server::KnowledgeStore::Tools::Agent;

  MCP::Server::KnowledgeStore::Tools::Agent->register($mcp_server, $store);

=head1 DESCRIPTION

A L<MCP::Server::KnowledgeStore::Tools> plugin registering C<list_agents>,
C<get_agent>, C<save_agent>, C<tag_agent> and C<untag_agent> against a
L<MCP::Server::KnowledgeStore::Store>. Agent definitions are stored as opaque
blobs, global by name (not scoped to one project the way a spec is) -
see L<MCP::Server::KnowledgeStore::Store/agents>. Which projects an agent suits
is the same many-to-many tag idea as memory/skill, not a copy per
project.

=head1 METHODS

=head2 register

  MCP::Server::KnowledgeStore::Tools::Agent->register($server, $store);

Adds this plugin's tools to C<$server> (an L<MCP::Server>), backed by
C<$store>. Called by L<MCP::Server::KnowledgeStore::Tools/build> for every
installed plugin - not normally called directly.

=head1 AUTHOR

Wesley Schwengle <waterkip@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2026 by Wesley Schwengle.

This is free software, licensed under:

  The (three-clause) BSD License

=cut
