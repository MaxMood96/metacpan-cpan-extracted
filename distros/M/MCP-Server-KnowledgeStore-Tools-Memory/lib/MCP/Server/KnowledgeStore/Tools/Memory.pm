package MCP::Server::KnowledgeStore::Tools::Memory;
use v5.38;
use Mojo::Base -strict, -signatures;

our $VERSION = '0.001';

# ABSTRACT: The memory MCP tools, as an MCP::Server::KnowledgeStore::Tools plugin

use MCP::Server::KnowledgeStore::Tools::Revisioned;

sub register ($class, $server, $store, %opts) {
  return MCP::Server::KnowledgeStore::Tools::Revisioned->register(
    $server, $store,
    kind        => 'memory',
    plural      => 'memories',
    type        => 1,
    search      => 1,
    allow_purge => $opts{allow_purge},
  );
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

MCP::Server::KnowledgeStore::Tools::Memory - The memory MCP tools, as an MCP::Server::KnowledgeStore::Tools plugin

=head1 VERSION

version 0.001

=head1 SYNOPSIS

  use MCP::Server::KnowledgeStore::Tools::Memory;

  MCP::Server::KnowledgeStore::Tools::Memory->register($mcp_server, $store);

=head1 DESCRIPTION

A L<MCP::Server::KnowledgeStore::Tools> plugin registering C<list_memories>,
C<search_memories>, C<get_memory>, C<save_memory>,
C<list_memory_revisions>, C<mark_memory_useful>, C<tag_memory> and
C<untag_memory>, along with the archive, restore, purge, and archived-list
tools, against a L<MCP::Server::KnowledgeStore::Store>. The tool set itself is
generic; see L<MCP::Server::KnowledgeStore::Tools::Revisioned>. This plugin
configures it for searchable memories with a C<type> field.

=head1 METHODS

=head2 register

  MCP::Server::KnowledgeStore::Tools::Memory->register($server, $store);

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
