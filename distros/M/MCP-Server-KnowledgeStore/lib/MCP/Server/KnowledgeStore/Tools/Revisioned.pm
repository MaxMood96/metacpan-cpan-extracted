package MCP::Server::KnowledgeStore::Tools::Revisioned;
use v5.38;
use Mojo::Base -strict, -signatures;

our $VERSION = '0.001';

# ABSTRACT: Generic tool set for a revisioned, taggable, project-scoped resource

use Carp                                        qw(croak);
use Mojo::JSON                                  qw(true false);
use MCP::Server::KnowledgeStore::Tools::Support qw(
  name_pattern summary author revision_property author_property
  project_property
);

my $NAME_PATTERN = name_pattern;

# Memory and skill were two ~150-line files that differed only in
# whether they have `type` and `search`, and in their name. This is
# that shared shape, factored out - a resource registers by calling
# this once with its own kind and a backend, instead of writing out
# list/get/save/revisions/useful/tag/untag by hand.
sub register ($class, $server, $backend, %config) {
  my $kind        = $config{kind} or croak 'kind is required';
  my $plural      = $config{plural} // "${kind}s";
  my $has_type    = $config{type}   // 0;
  my $has_search  = $config{search} // 0;
  my $allow_purge = exists $config{allow_purge} ? $config{allow_purge} : 1;

  $server->tool(
    name         => "list_${plural}",
    description  => "List $kind entries, optionally filtered by project",
    input_schema => {
      type                 => 'object',
      properties           => project_property(),
      additionalProperties => false,
    },
    code => sub ($tool, $args) {
      my $entries = $backend->list($kind, $args->{project});
      return $tool->structured_result(
        { $plural => [map { summary($_) } @$entries] });
    },
  );

  if ($has_search) {
    $server->tool(
      name        => "search_${plural}",
      description =>
        "Search across $kind frontmatter and bodies. Postgres tsvector "
        . "picks the candidates, TF-IDF corpus vectors rank them.",
      input_schema => {
        type       => 'object',
        properties => {
          query => { type => 'string', description => 'Text to search for' },
          limit => {
            type        => 'integer',
            minimum     => 1,
            maximum     => 100,
            default     => 10,
            description => 'Maximum number of results (default: 10)'
          },
          project_property()->%*,
        },
        required             => ['query'],
        additionalProperties => false,
      },
      code => sub ($tool, $args) {
        my $hits = $backend->search($kind, $args->{query}, $args->{project},
          $args->{limit} // 10);
        return $tool->structured_result(
          {
            $plural => [
              map {
                {
                  summary($_)->%*,
                    matches => $_->{matches},
                    rank    => $_->{rank},
                    ts_rank => $_->{ts_rank}
                }
              } @$hits
            ]
          }
        );
      },
    );
  }


  $server->tool(
    name        => "get_${kind}",
    description =>
      "Fetch the full content of one $kind, at its current or an older revision",
    input_schema => {
      type       => 'object',
      properties => {
        name => { type => 'string', pattern => $NAME_PATTERN },
        revision_property()->%*,
      },
      required             => ['name'],
      additionalProperties => false,
    },
    code => sub ($tool, $args) {
      my $entry = $backend->get($kind, $args->{name}, $args->{revision});
      return $tool->text_result(
        "No $kind named '$args->{name}'"
          . (
          defined $args->{revision} ? " at revision $args->{revision}" : ''
          ),
        1
      ) unless $entry;
      return $entry->{content};
    },
  );

  my %save_properties = (
    name    => { type => 'string', pattern => $NAME_PATTERN },
    content => $has_type
    ? {
      type        => 'string',
      description =>
        'Markdown body. Frontmatter it carries is read into metadata.',
      }
    : { type => 'string' },
    description => { type => 'string' },
    project_property()->%*,
    author_property()->%*,
  );
  $save_properties{type}
    = { type => 'string', enum => [qw(user feedback project reference)] }
    if $has_type;
  my @save_fields
    = $has_type ? qw(type description project) : qw(description project);

  $server->tool(
    name        => "save_${kind}",
    description =>
      "Save a $kind as a new revision in the shared store. project, if "
      . 'given, adds a project tag - it does not replace existing tags; '
      . "use untag_${kind} to remove one.",
    input_schema => {
      type                 => 'object',
      properties           => \%save_properties,
      required             => [qw(name content), ($has_type ? 'type' : ())],
      additionalProperties => false,
    },
    code => sub ($tool, $args) {
      my $entry = $backend->save(
        $kind, $args->{name}, $args->{content},
        author => author($tool, $args),
        map { defined $args->{$_} ? ($_ => $args->{$_}) : () } @save_fields
      );
      return $tool->structured_result(
        { name => $entry->{name}, revision => $entry->{revision} });
    },
  );

  $server->tool(
    name         => "list_${kind}_revisions",
    description  => "List every saved revision of one $kind, newest first",
    input_schema => {
      type       => 'object',
      properties => { name => { type => 'string', pattern => $NAME_PATTERN } },
      required   => ['name'],
      additionalProperties => false,
    },
    code => sub ($tool, $args) {
      my $history = $backend->history($kind, $args->{name});
      return $tool->text_result("No $kind named '$args->{name}'", 1)
        unless @$history;
      my @revisions;
      for my $row (@$history) {
        push @revisions,
          {
          revision    => $row->{revision},
          description => $row->{description},
          created_at  => "$row->{created_at}",
          is_head     => $row->{is_head} ? true : false,
          map { defined $row->{$_} ? ($_ => $row->{$_}) : () }
            qw(author type project),
          };
      }
      return $tool->structured_result({ revisions => \@revisions });
    },
  );

  $server->tool(
    name        => "mark_${kind}_useful",
    description =>
      "Record that a $kind was useful, incrementing its useful_count",
    input_schema => {
      type       => 'object',
      properties => { name => { type => 'string', pattern => $NAME_PATTERN } },
      required   => ['name'],
      additionalProperties => false,
    },
    code => sub ($tool, $args) {
      my $count = eval { $backend->mark_useful($kind, $args->{name}) };
      return $tool->text_result("No $kind named '$args->{name}'", 1)
        unless defined $count;
      return $tool->structured_result(
        { name => $args->{name}, useful_count => $count });
    },
  );

  $server->tool(
    name        => "tag_${kind}",
    description => "Tag a $kind as relevant to a project (additive - "
      . 'does not remove other tags)',
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
      eval { $backend->tag($kind, $args->{name}, $args->{project}) };
      return $tool->text_result("No $kind named '$args->{name}'", 1) if $@;
      return $tool->structured_result(
        { name => $args->{name}, project => $args->{project} });
    },
  );

  $server->tool(
    name         => "untag_${kind}",
    description  => "Remove a project tag from a $kind",
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
      $backend->untag($kind, $args->{name}, $args->{project});
      return $tool->structured_result(
        { name => $args->{name}, project => $args->{project} });
    },
  );

  # Archive (soft delete) an entry
  $server->tool(
    name        => "archive_${kind}",
    description =>
      "Archive (soft delete) a $kind. Hides it from normal operations "
      . 'but keeps all data and revision history for possible restoration.',
    input_schema => {
      type       => 'object',
      properties => {
        name              => { type => 'string', pattern => $NAME_PATTERN },
        expected_revision => {
          type        => 'integer',
          minimum     => 1,
          description =>
            'Optional: verify this revision before archiving to prevent stale operations',
        },
        author => {
          type        => 'string',
          description => 'Who to record as performing the archive'
        },
        reason =>
          { type => 'string', description => 'Optional reason for archiving' },
      },
      required             => [qw(name)],
      additionalProperties => false,
    },
    code => sub ($tool, $args) {
      my $author = author($tool, $args);
      my $entry  = eval {
        $backend->archive(
          $kind, $args->{name},
          author            => $author,
          expected_revision => $args->{expected_revision},
          reason            => $args->{reason},
        );
      };
      return $tool->text_result(
        "No $kind named '$args->{name}' or already archived", 1)
        if $@ && $@ =~ /no \Q$kind\E named/;
      return $tool->text_result($@,                                1) if $@;
      return $tool->text_result("Already archived: $args->{name}", 1)
        unless $entry;
      return $tool->structured_result(
        {
          name        => $entry->{name},
          revision    => $entry->{revision},
          archived_at => "$entry->{archived_at}",
        }
      );
    },
  );

  # Restore an archived entry
  $server->tool(
    name        => "restore_${kind}",
    description =>
      "Restore a previously archived $kind, making it visible again",
    input_schema => {
      type       => 'object',
      properties => {
        name   => { type => 'string', pattern => $NAME_PATTERN },
        author => {
          type        => 'string',
          description => 'Who to record as performing the restore'
        },
        reason =>
          { type => 'string', description => 'Optional reason for restoring' },
      },
      required             => [qw(name)],
      additionalProperties => false,
    },
    code => sub ($tool, $args) {
      my $author = author($tool, $args);
      my $entry  = eval {
        $backend->restore(
          $kind, $args->{name},
          author => $author,
          reason => $args->{reason}
        );
      };
      return $tool->text_result($@, 1) if $@;
      return $tool->text_result("No archived $kind named '$args->{name}'", 1)
        unless $entry;
      return $tool->structured_result(
        {
          name     => $entry->{name},
          revision => $entry->{revision},
        }
      );
    },
  );

  # Permanently purge an entry (destructive, cannot be undone)
  $server->tool(
    name        => "purge_${kind}",
    description => "Permanently delete a $kind and ALL its revision history. "
      . (
      $allow_purge
      ? 'This is destructive and cannot be undone.'
      : 'DISABLED on this server'
      ),
    input_schema => {
      type       => 'object',
      properties => {
        name              => { type => 'string', pattern => $NAME_PATTERN },
        expected_revision => {
          type        => 'integer',
          minimum     => 1,
          description =>
            'Optional: verify this revision before purging to prevent stale operations',
        },
        author => {
          type        => 'string',
          description => 'Who to record as performing the purge'
        },
        reason => {
          type        => 'string',
          description => 'Optional reason for permanent deletion'
        },
      },
      required             => [qw(name)],
      additionalProperties => false,
    },
    code => sub ($tool, $args) {
      return $tool->text_result("purge_${kind} is disabled on this server", 1)
        unless $allow_purge;

      my $author = author($tool, $args);
      my $result = eval {
        $backend->purge(
          $kind, $args->{name},
          author            => $author,
          expected_revision => $args->{expected_revision},
          reason            => $args->{reason},
        );
      };
      return $tool->text_result($@, 1) if $@;
      return $tool->structured_result($result);
    },
  );

  # List archived entries
  $server->tool(
    name        => "list_archived_${plural}",
    description =>
      "List archived $kind entries, optionally filtered by project",
    input_schema => {
      type                 => 'object',
      properties           => project_property(),
      additionalProperties => false,
    },
    code => sub ($tool, $args) {
      my $entries = $backend->list_archived($kind, $args->{project});
      return $tool->structured_result(
        { $plural => [map { summary($_) } @$entries] });
    },
  );

  # Add MCP Resource Templates
  # These provide addressable reads via URIs as an alternative to get_* tools
  if ($server->can('add_template')) {
    my $uri_prefix = "${kind}://${plural}";

    $server->add_template(
      uri_template => "$uri_prefix/{name}",
      name         => "${kind}_read",
      description  => "Read the current revision of a $kind by name",
      mime_type    => 'text/markdown',
      code         => sub ($template, $params, $context) {
        my $name  = $params->{name};
        my $entry = $backend->get($kind, $name);
        return undef unless $entry;
        return $entry->{content};
      },
    );

    $server->add_template(
      uri_template => "$uri_prefix/{name}/revisions/{revision}",
      name         => "${kind}_read_revision",
      description  =>
        "Read a specific revision of a $kind by name and revision number",
      mime_type => 'text/markdown',
      code      => sub ($template, $params, $context) {
        my $name     = $params->{name};
        my $revision = $params->{revision};
        my $entry    = $backend->get($kind, $name, $revision);
        return undef unless $entry;
        return $entry->{content};
      },
    );
  }

  return;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

MCP::Server::KnowledgeStore::Tools::Revisioned - Generic tool set for a revisioned, taggable, project-scoped resource

=head1 VERSION

version 0.001

=head1 SYNOPSIS

  package MCP::Server::KnowledgeStore::Tools::Memory;
  use MCP::Server::KnowledgeStore::Tools::Revisioned;

  sub register ($class, $server, $store) {
    MCP::Server::KnowledgeStore::Tools::Revisioned->register(
      $server, $store, kind => 'memory', type => 1, search => 1);
  }

=head1 DESCRIPTION

Memory and skill are, at the tool level, the same shape: list, get,
save, list revisions, mark useful, tag, untag - differing only in
whether they carry C<type> and support C<search>. This module is that
shape, factored out once instead of duplicated per resource.

=head1 THE BACKEND INTERFACE

C<register> takes a I<backend> - anything implementing this handful of
methods, taking C<$kind> as their first argument, matching
L<MCP::Server::KnowledgeStore::Store>'s own shape:

  $backend->list($kind, $project)                    # arrayref of entries
  $backend->search($kind, $query, $project)           # only if search => 1
  $backend->get($kind, $name, $revision)               # one entry, or undef
  $backend->save($kind, $name, $content, %opts)        # returns the new entry
  $backend->tag($kind, $name, $project)                # dies if $name unknown
  $backend->untag($kind, $name, $project)
  $backend->history($kind, $name)                      # arrayref, newest first
  $backend->mark_useful($kind, $name)                  # returns the new count

Additional methods for lifecycle management (added alongside this module):

  $backend->archive($kind, $name, %opts)              # soft delete, returns entry
  $backend->restore($kind, $name, %opts)              # undo archive, returns entry
  $backend->purge($kind, $name, %opts)                # permanent delete, returns status
  $backend->list_archived($kind, $project)             # arrayref of archived entries
  $backend->audit_log($kind, $name, $action, $limit)  # arrayref of audit entries

Options for archive/restore/purge: author (required), expected_revision (optional),
reason (optional).

C<MCP::Server::KnowledgeStore::Store> already implements all of it, since this is
exactly the API it exposed before this module existed. Passing a
different object is how a resource can bring its own storage instead of
Store's C<entries>/C<revisions> tables, as long as it answers to the
same shape.

=head1 METHODS

=head2 register

  MCP::Server::KnowledgeStore::Tools::Revisioned->register(
    $server, $backend, kind => 'memory', plural => 'memories',
    type => 1, search => 1,
  );

C<kind> is required. C<plural> defaults to C<"${kind}s">. C<type>
(default false) adds the C<type> property/requirement C<save_*> memory
needs and skill doesn't. C<search> (default false) additionally
registers C<search_$plural>.

=head1 AUTHOR

Wesley Schwengle <waterkip@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2026 by Wesley Schwengle.

This is free software, licensed under:

  The (three-clause) BSD License

=cut
