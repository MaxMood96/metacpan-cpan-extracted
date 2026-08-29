package MCP::Server::KnowledgeStore::Tools::Support;
use v5.38;
use Mojo::Base -strict, -signatures;

our $VERSION = '0.001';

# ABSTRACT: Shared helpers every MCP::Server::KnowledgeStore::Tools::* plugin uses

use Exporter qw(import);

our @EXPORT_OK = qw(
  name_pattern summary author revision_property author_property
  project_property
);

use constant NAME_PATTERN => '^[A-Za-z0-9][A-Za-z0-9_:-]*$';

sub name_pattern () { return NAME_PATTERN }

# Tools return structured results rather than prose, so a client gets a
# list it can filter instead of a paragraph it has to parse. The store's
# `body` is dropped from list/search output - it is what get_* is for,
# and including it would make a listing as expensive as reading
# everything.
sub summary ($entry) {
  return {
    name         => $entry->{name},
    description  => $entry->{description},
    revision     => $entry->{revision},
    view_count   => $entry->{view_count}   // 0,
    useful_count => $entry->{useful_count} // 0,

    # `projects`: memory/skill's tags (may be several). `project`: a
    # spec's single required one - absent for memory/skill going
    # forward, since they no longer write that column.
    projects => $entry->{projects} // [],
    map { defined $entry->{$_} ? ($_ => $entry->{$_}) : () }
      qw(type project last_viewed_at),
  };
}

# A save records who claims to have made it. The token is shared, so this
# is not an authenticated identity - it is git's user.name, not a login.
sub author ($tool, $args) {
  return $args->{author} // $tool->context->principal;
}

sub revision_property () {
  return {
    revision => {
      type        => 'integer',
      minimum     => 1,
      description =>
        'Read this revision instead of the current one. Omit for current.',
    },
  };
}

sub author_property () {
  return {
    author => {
      type        => 'string',
      description => 'Who to record as having made this revision',
    },
  };
}

sub project_property () {
  return {
    project => {
      type        => 'string',
      description =>
        'Only entries tagged with this project (a spec\'s single required '
        . 'project; a memory/skill/agent may be tagged with several)',
    },
  };
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

MCP::Server::KnowledgeStore::Tools::Support - Shared helpers every MCP::Server::KnowledgeStore::Tools::* plugin uses

=head1 VERSION

version 0.001

=head1 DESCRIPTION

Small helpers common to every C<MCP::Server::KnowledgeStore::Tools::*> plugin -
the input-schema fragments, the summary shape, and how a save's author
is worked out. Pulled out here rather than duplicated per plugin, since
every plugin distribution already depends on this one for
L<MCP::Server::KnowledgeStore::Store>.

=head1 FUNCTIONS

Exported on request; none are exported by default.

=head2 name_pattern

The slug pattern every entry name is validated against.

=head2 summary($entry)

Renders an entry hash (from L<MCP::Server::KnowledgeStore::Store>) into the shape
a C<list_*>/C<search_*> tool returns - no C<body>, since that is what
C<get_*> is for.

=head2 author($tool, $args)

The author to record for a save: the caller's explicit C<author>
argument, or the authenticated principal.

=head2 revision_property / author_property / project_property

Reusable C<input_schema> property fragments.

=head1 AUTHOR

Wesley Schwengle <waterkip@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2026 by Wesley Schwengle.

This is free software, licensed under:

  The (three-clause) BSD License

=cut
