package MCP::Server::KnowledgeStore::Store;
use v5.38;
use Object::Pad;

our $VERSION = '0.001';

# ABSTRACT: Postgres store for memories, skills, specs, agents, and projects

class MCP::Server::KnowledgeStore::Store;

use Carp        qw(croak);
use Crypt::PRNG qw(random_bytes);
use Digest::SHA qw(sha256_hex);
use Mojo::Pg;
use Mojo::Util qw(b64_encode);
use YAML::XS   qw(Load Dump);
use MCP::Server::KnowledgeStore::TermWeight;

# Either a Mojo::Pg or a connection string. Both machines reach the same
# database over the network, which is what makes it the single canonical
# store - there is no file tree and no shared mount any more.
field $pg : param : reader;

ADJUST {
  $pg = Mojo::Pg->new($pg) unless ref $pg;

  # Postgres refuses a server-side prepared statement whose result columns
  # changed shape since it was planned, with "cached plan must not change
  # result type". A migration that alters a table some statement selects
  # from is enough. Mojo::Pg runs every query through prepare_cached, so
  # the broken plan sticks to that pooled connection for the life of the
  # process: search dies while writes carry on, and only a restart clears
  # it. Client-side placeholders cost a replan per call, which is nothing
  # at this traffic, and the whole failure mode goes away.
  $pg->options->{pg_server_prepare} = 0;

  $pg->migrations->name('wdms_mcp')->from_data(__PACKAGE__, 'migrations.sql');
}

# Run pending migrations. Called explicitly rather than from ADJUST so
# constructing a store never has a side effect on the database.
method migrate { $pg->migrations->migrate; return $self }

method db { return $pg->db }

sub _check_kind ($kind) {
  croak "invalid kind '$kind': expected memory, skill or spec"
    unless defined $kind
    && ($kind eq 'memory' || $kind eq 'skill' || $kind eq 'spec');
  return $kind;
}

# Names are the caller-supplied key for every lookup, so they are held to
# the same shape the files used, both here and in a CHECK constraint.
# Now supports both slug-style (my-memory-name) and namespace-style (My::Module::Name).
sub _check_name ($name) {
  croak 'name is required' unless defined $name && length $name;
  croak "invalid name '$name': expected alphanumeric name with optional "
    . "hyphens, underscores, or colons (e.g., my-memory-name or My::Module::Name)"
    unless $name =~ /\A[A-Za-z0-9][A-Za-z0-9_:-]*\z/a;
  return $name;
}

# Frontmatter is still the wire format - it is what agents already write -
# but it is not how anything is stored. On the way in it is split into
# columns, on the way out it is rendered back, so the DB holds structured
# metadata while clients keep the format they know.
method _split ($text) {
  $text //= '';
  return ({}, $text) unless $text =~ s/\A---\r?\n(.*?)\r?\n---[ \t]*\r?\n?//s;
  my $meta = eval { Load($1) } // {};
  $meta = {} unless ref $meta eq 'HASH';
  return ($meta, $text);
}

method _render ($row) {
  my $meta
    = { name => $row->{name}, description => $row->{description} // '' };
  $meta->{metadata}{type} = $row->{type}    if defined $row->{type};
  $meta->{project}        = $row->{project} if defined $row->{project};

  my $head = Dump($meta);
  $head = "---\n$head" unless $head =~ /\A---\r?\n/;
  $head =~ s/\n?\z/\n/;
  return $head . "---\n\n" . ($row->{body} // '') . "\n";
}

method _entry ($row) {
  return {
    name        => $row->{name},
    description => $row->{description} // '',
    type        => $row->{type},

    # Spec's single required project, still on the revision (as
    # project_id, resolved to its name below). Memory and skill are
    # tagged instead - see `projects`.
    project        => $row->{project},
    projects       => $row->{projects} // [],
    kind           => $row->{kind},
    revision       => $row->{revision},
    author         => $row->{author},
    created_at     => $row->{created_at},
    body           => $row->{body},
    content        => $self->_render($row),
    view_count     => $row->{view_count}   // 0,
    useful_count   => $row->{useful_count} // 0,
    last_viewed_at => $row->{last_viewed_at},
  };
}

# One query shape for every read: an entry joined to whichever revision is
# its head. A history lookup swaps that join for a specific revision.
method _select ($where, @bind) {
  return $self->db->query(<<~"SQL", @bind)->hashes;
    SELECT e.kind, e.name, r.revision, r.body, r.description, r.type,
           pr.name AS project, r.author, r.created_at,
           e.view_count, e.useful_count, e.last_viewed_at,
           coalesce(
             (SELECT array_agg(p.name ORDER BY p.name)::text[]
                FROM entry_projects ep JOIN projects p ON p.id = ep.project_id
               WHERE ep.entry_id = e.id),
             '{}'
           ) AS projects
      FROM entries e
      JOIN revisions r ON r.id = e.head_id
      LEFT JOIN projects pr ON pr.id = r.project_id
     WHERE $where
     ORDER BY e.name
    SQL
}

# A project is a real row now (see migration 7), so this is a plain
# listing rather than a UNION of three free-text columns.
method list_projects {
  return $self->db->query('SELECT name FROM projects ORDER BY name')
    ->arrays->flatten->to_array;
}

# Full rows, for a projects admin list - list_projects itself stays
# name-only (its shape is the MCP tool's contract).
method list_projects_full {
  return $self->db->query(
    'SELECT id, name, description, created_at FROM projects ORDER BY name')
    ->hashes->to_array;
}

# Full row, for a project's own edit page - list_projects stays name-only
# (its shape is the MCP tool's contract, see list_projects' tool wrapper).
method get_project ($name) {
  croak 'name is required' unless defined $name && length $name;
  return $self->db->query(
    'SELECT id, name, description, created_at FROM projects WHERE name = ?',
    $name)->hash;
}

# Unlike _project_id (called implicitly by tag/save), this is the
# explicit "a human asked to create a project" entry point - errors if
# the name is already taken instead of silently reusing the existing
# row, and it's the only way to set a description at creation time.
method create_project ($name, %opts) {
  croak 'name is required' unless defined $name && length $name;
  croak "a project named '$name' already exists" if $self->get_project($name);
  return $self->db->query(<<~'SQL', $name, $opts{description})->hash;
    INSERT INTO projects (name, description) VALUES (?, ?)
      RETURNING id, name, description, created_at
    SQL
}

method update_project ($name, %opts) {
  croak 'name is required' unless defined $name && length $name;
  my $new_name = $opts{name} // $name;
  my $row      = eval {
    $self->db->query(<<~'SQL', $new_name, $opts{description}, $name)->hash;
      UPDATE projects SET name = ?, description = ? WHERE name = ?
        RETURNING id, name, description, created_at
      SQL
  };
  if (my $err = $@) {
    croak "a project named '$new_name' already exists"
      if "$err" =~ /duplicate key/;
    croak $err;
  }
  croak "no project named '$name'" unless $row;
  return $row;
}

# revisions.project_id (a spec's required, single project) has no ON
# DELETE action, so Postgres itself refuses to delete a project any
# spec still belongs to - caught here and re-raised as a message a form
# can show directly, rather than a raw constraint-name error. Tags
# (entry_projects/project_agents) ARE ON DELETE CASCADE by design (a
# memory/skill/agent can lose one of several tags without objection),
# so those never block a delete.
method delete_project ($name) {
  croak 'name is required' unless defined $name && length $name;
  my $deleted = eval {
    $self->db->query('DELETE FROM projects WHERE name = ? RETURNING id', $name)
      ->hash;
  };
  if (my $err = $@) {
    croak "Cannot delete project '$name': it still has specs assigned to it"
      if "$err" =~ /violates foreign key constraint/;
    croak $err;
  }
  croak "no project named '$name'" unless $deleted;
  return 1;
}

# Resolves a project name to its id, creating the row if this is the
# first time it has been used - tagging with a new name is how a
# project comes into being, the same way it worked when project was
# still a bare string. Case-insensitive, so "Abto" and "abto" are the
# same project.
method _project_id ($name) {
  croak 'project is required' unless defined $name && length $name;
  my $row
    = $self->db->query('SELECT id FROM projects WHERE name = ?', $name)->hash;
  return $row->{id} if $row;
  return $self->db->query(
    'INSERT INTO projects (name) VALUES (?) RETURNING id', $name)->hash->{id};
}

# Like _project_id, but never creates - for filtering, where a project
# name nobody has used yet should simply match nothing rather than
# spring into existence as a side effect of a read.
method _find_project_id ($name) {
  my $row
    = $self->db->query('SELECT id FROM projects WHERE name = ?', $name)->hash;
  return $row ? $row->{id} : undef;
}

# Spec keeps its single required project on the revision - a spec
# document belongs to exactly one project by definition. Memory and
# skill are tagged instead: a memory can matter to more than one
# project, so filtering joins entry_projects rather than reading a
# single column. Either way, filtering by a project nobody has tagged
# anything with matches nothing rather than erroring.
method _project_filter ($kind, $project) {
  return ('', ()) unless defined $project && length $project;
  my $project_id = $self->_find_project_id($project);
  return (' AND 1 = 0', ()) unless defined $project_id;
  return $kind eq 'spec'
    ? (' AND r.project_id = ?', $project_id)
    : (
    ' AND EXISTS (SELECT 1 FROM entry_projects ep'
      . ' WHERE ep.entry_id = e.id AND ep.project_id = ?)',
    $project_id
    );
}

method list ($kind, $project = undef) {
  _check_kind($kind);
  my ($where,  @bind)  = ('e.kind = ? AND e.archived_at IS NULL', $kind);
  my ($clause, @pbind) = $self->_project_filter($kind, $project);
  $where .= $clause;
  push @bind, @pbind;
  return [map { $self->_entry($_) } @{ $self->_select($where, @bind) }];
}

# Same shape as list(), but newest-first and capped - for a dashboard's
# "what's new" glance, where list()'s alphabetical order is useless.
# created_at is the head revision's own (see _select's join), so this
# is "most recently saved", not "most recently created" - an edit
# bumps an entry back to the top, which is the more useful reading for
# "what changed lately".
method list_recent ($kind, $limit = 10) {
  _check_kind($kind);
  my $rows = $self->db->query(<<~"SQL", $kind, $limit)->hashes;
    SELECT e.kind, e.name, r.revision, r.body, r.description, r.type,
           pr.name AS project, r.author, r.created_at,
           e.view_count, e.useful_count, e.last_viewed_at,
           coalesce(
             (SELECT array_agg(p.name ORDER BY p.name)::text[]
                FROM entry_projects ep JOIN projects p ON p.id = ep.project_id
               WHERE ep.entry_id = e.id),
             '{}'
           ) AS projects
      FROM entries e
      JOIN revisions r ON r.id = e.head_id
      LEFT JOIN projects pr ON pr.id = r.project_id
     WHERE e.kind = ? AND e.archived_at IS NULL
     ORDER BY r.created_at DESC
     LIMIT ?
    SQL
  return [map { $self->_entry($_) } @$rows];
}

# Vector-based search using hybrid approach (TF-IDF ranking with tsvector filtering).
# Maintains backward compatibility by including `matches` array.
# The one way in. Ranking is hybrid_search's (tsvector filtering, TF-IDF
# re-ranking); this adds the matching lines on top, which is the only
# thing the two ever differed by.
method search ($kind, $query, $project = undef, $limit = 10) {
  _check_kind($kind);
  croak 'query is required' unless defined $query && length $query;

  my $results = $self->hybrid_search($kind, $query, $project, $limit);

  # Add matches for backward compatibility with existing clients
  for my $r (@$results) {
    my @lines = grep { index(lc $_, lc $query) >= 0 }
      split /\n/, "$r->{name}\n$r->{description}\n$r->{body}";
    $r->{matches} = [splice @lines, 0, 5];
  }

  return $results;
}

# Hybrid search using PostgreSQL tsvector for filtering + Lingua::TermWeight
# TF-IDF for ranking. Only considers LATEST REVISIONS (head_id).
method hybrid_search (
  $kind, $query,
  $project    = undef,
  $limit      = 10,
  $use_cached = 1
  )
{
  _check_kind($kind);
  croak 'query is required' unless defined $query && length $query;

  # Step 1: Get candidates from PostgreSQL tsvector - LATEST REVISIONS ONLY
  my $where      = 'e.kind = ? AND e.archived_at IS NULL AND r.id = e.head_id';
  my @where_bind = ($kind);
  my ($clause, @pbind) = $self->_project_filter($kind, $project);
  $where .= $clause;
  push @where_bind, @pbind;

  # Match any query term for candidate recall, then let TF-IDF rank relevance.
  my $tsquery = <<~'SQL';
    websearch_to_tsquery(
      'english', regexp_replace(?, '[[:space:]]+', ' OR ', 'g')
    )
    SQL

  my $candidate_limit = $limit * 5;
  my @bind            = ($query, @where_bind, $query, $candidate_limit);

  my $sql = <<~"SQL";
    SELECT e.kind, e.name, r.id AS revision_id, r.revision,
           r.body, r.description, r.type,
           pr.name AS project, r.author, r.created_at,
           e.view_count, e.useful_count, e.last_viewed_at,
           coalesce(
             (SELECT array_agg(p.name ORDER BY p.name)::text[]
                FROM entry_projects ep JOIN projects p ON p.id = ep.project_id
               WHERE ep.entry_id = e.id),
             '{}'
           ) AS projects,
           ts_rank(r.search_vector, $tsquery) AS ts_rank,
           dt.tfidf_vector AS cached_vector
      FROM entries e
      JOIN revisions r ON r.id = e.head_id
      LEFT JOIN projects pr ON pr.id = r.project_id
      LEFT JOIN document_tfidf dt ON dt.revision_id = r.id
     WHERE $where AND r.search_vector @@ $tsquery
     ORDER BY ts_rank DESC
     LIMIT ?
    SQL

  my $candidates = $self->db->query($sql, @bind)->expand->hashes->to_array;
  return [] unless @$candidates;

  # Step 2: Get corpus-wide IDF (computed from latest revisions only)
  my $idf_data = $self->_get_corpus_idf($kind);
  my $idf      = $idf_data->{idf};

  # Step 3: Compute query vector using corpus IDF
  my $tw           = MCP::Server::KnowledgeStore::TermWeight->new;
  my $query_tf     = $tw->compute_tf($query);
  my $query_vector = {
    map { $_ => ($query_tf->{$_} // 0) * ($idf->{$_} // 0) }
      keys %$query_tf
  };

  # Step 4: Re-rank candidates using cosine similarity
  my @ranked = map {
    my $doc_vector = $_->{cached_vector}
      // $self->_compute_doc_vector($kind, $_->{revision_id}, $idf);
    +{ %$_, rank => $tw->cosine_similarity($query_vector, $doc_vector) };
  } @$candidates;

  # A PostgreSQL stem match can have no corresponding TF-IDF term. Drop
  # those zero-rank candidates when cosine similarity found useful matches,
  # but retain the PostgreSQL-ranked fallback when the whole corpus scores 0.
  my @positive = grep { $_->{rank} > 0 } @ranked;
  @ranked = @positive if @positive;
  @ranked = sort {
    $b->{rank} <=> $a->{rank}
      || ($b->{ts_rank} // 0) <=> ($a->{ts_rank} // 0)
  } @ranked;
  splice @ranked, $limit if @ranked > $limit;
  return \@ranked;
}

# Get or compute corpus-wide IDF for a kind - LATEST REVISIONS ONLY
method _get_corpus_idf ($kind) {
  my $row
    = $self->db->query(
    'SELECT idf, document_count FROM corpus_idf WHERE kind = ?', $kind)
    ->expand->hash;

  return $row if $row;

  # Compute fresh IDF from LATEST REVISIONS only
  my $tw        = MCP::Server::KnowledgeStore::TermWeight->new;
  my $documents = $self->db->query(<<~'SQL', $kind)->arrays->flatten->to_array;
    SELECT e.name || ' ' || r.body || ' ' || COALESCE(r.description, '')
      FROM entries e
      JOIN revisions r ON r.id = e.head_id
     WHERE e.kind = ? AND e.archived_at IS NULL
    SQL

  my $idf   = $tw->compute_idf($documents);
  my $count = scalar @$documents;

  my $json_idf = { json => $idf };
  $self->db->query(<<~'SQL', $kind, $json_idf, $count, $json_idf, $count);
    INSERT INTO corpus_idf (kind, idf, document_count)
    VALUES (?, ?, ?)
    ON CONFLICT (kind) DO UPDATE SET idf = ?, document_count = ?, updated_at = now()
    SQL

  return { idf => $idf, document_count => $count };
}

# Compute and cache a document's TF-IDF vector - LATEST REVISIONS ONLY
method _compute_doc_vector ($kind, $revision_id, $idf) {

  # Verify this IS the latest revision before computing
  my $row = $self->db->query(<<~'SQL', $revision_id)->hash;
    SELECT e.name, r.body, r.description, e.head_id = r.id AS is_latest
      FROM revisions r
      JOIN entries e ON e.id = r.entry_id
     WHERE r.id = ?
    SQL

  croak "Refusing to compute vector for non-latest revision $revision_id"
    unless $row && $row->{is_latest};

  my $text = join ' ', $row->{name}, ($row->{body} // ''),
    ($row->{description} // '');
  my $tw    = MCP::Server::KnowledgeStore::TermWeight->new;
  my $tf    = $tw->compute_tf($text);
  my $tfidf = { map { $_ => ($tf->{$_} // 0) * ($idf->{$_} // 0) } keys %$tf };

  # Cache it
  my $json_tfidf = { json => $tfidf };
  my $term_count = scalar keys %$tfidf;
  my @bind       = ($revision_id, $json_tfidf, $term_count, $json_tfidf);
  $self->db->query(<<~'SQL', @bind);
    INSERT INTO document_tfidf (revision_id, tfidf_vector, term_count)
    VALUES (?, ?, ?)
    ON CONFLICT (revision_id) DO UPDATE
      SET tfidf_vector = ?, updated_at = now()
    SQL

  return $tfidf;
}

# Invalidate vector cache when documents change
method _invalidate_vector_cache ($kind, $revision_id = undef) {
  if ($revision_id) {
    $self->db->query('DELETE FROM document_tfidf WHERE revision_id = ?',
      $revision_id);
  }
  else {
    $self->db->query(<<~'SQL', $kind);
      DELETE FROM document_tfidf
      WHERE revision_id IN (
        SELECT r.id
          FROM revisions r
          JOIN entries e ON e.head_id = r.id
         WHERE e.kind = ?
      )
      SQL
    $self->db->query('DELETE FROM corpus_idf WHERE kind = ?', $kind);
  }
}

# The raw row, with no view-counting side effect - what save() uses to
# hand back the entry it just wrote, since writing is not viewing.
method _fetch ($kind, $name, $revision = undef) {
  return defined $revision
    ? $self->db->query(<<~'SQL', $kind, $name, $revision)->hash
        SELECT e.kind, e.name, r.revision, r.body, r.description, r.type,
               pr.name AS project, r.author, r.created_at,
               e.view_count, e.useful_count, e.last_viewed_at,
               coalesce(
                 (SELECT array_agg(p.name ORDER BY p.name)::text[]
                    FROM entry_projects ep JOIN projects p ON p.id = ep.project_id
                   WHERE ep.entry_id = e.id),
                 '{}'
               ) AS projects
          FROM entries e
          JOIN revisions r ON r.entry_id = e.id
          LEFT JOIN projects pr ON pr.id = r.project_id
         WHERE e.kind = ? AND e.name = ? AND r.revision = ?
        SQL
    : $self->_select('e.kind = ? AND e.name = ?', $kind, $name)->first;
}

method get ($kind, $name, $revision = undef) {
  _check_kind($kind);
  _check_name($name);

  my $row = $self->_fetch($kind, $name, $revision);
  return undef unless $row;

  # Check if archived - still return the content but note it's archived
  my $is_archived
    = $self->db->query(
    'SELECT archived_at FROM entries WHERE kind = ? AND name = ?',
    $kind, $name)->hash->{archived_at};

  # A read through this method is what "viewed via the API" means; bump
  # the counter for every call, including an old-revision lookup, rather
  # than only the head - an agent reading history is still consulting it.
  # Note: archived entries can still be viewed (for audit purposes)
  my $viewed = $self->db->query(<<~'SQL', $kind, $name)->hash;
    UPDATE entries SET view_count = view_count + 1, last_viewed_at = now()
     WHERE kind = ? AND name = ?
     RETURNING view_count, last_viewed_at
    SQL
  @{$row}{qw(view_count last_viewed_at)}
    = @{$viewed}{qw(view_count last_viewed_at)};

  my $entry = $self->_entry($row);

  # Add archived status to the entry
  $entry->{archived_at} = $is_archived if $is_archived;

  return $entry;
}

# Called explicitly by a client when an entry was actually useful, as
# opposed to merely read - a separate signal from view_count, which
# counts every fetch whether or not it helped.
method mark_useful ($kind, $name) {
  _check_kind($kind);
  _check_name($name);
  my $row = $self->db->query(<<~'SQL', $kind, $name)->hash;
    UPDATE entries SET useful_count = useful_count + 1
     WHERE kind = ? AND name = ?
     RETURNING useful_count
    SQL
  croak "no $kind named '$name'" unless $row;
  return $row->{useful_count};
}

sub _check_taggable ($kind) {
  croak "project on a spec is set via save_spec, not tag/untag"
    if $kind eq 'spec';
  return _check_kind($kind);
}

# A memory or skill can matter to more than one project - see
# entry_projects in the migrations - so tagging is its own call rather
# than something a save replaces wholesale.
method tag ($kind, $name, $project) {
  _check_taggable($kind);
  _check_name($name);
  croak 'project is required' unless defined $project && length $project;
  my $entry
    = $self->db->query('SELECT id FROM entries WHERE kind = ? AND name = ?',
    $kind, $name)->hash;
  croak "no $kind named '$name'" unless $entry;
  my $project_id = $self->_project_id($project);
  $self->db->query(<<~'SQL', $entry->{id}, $project_id);
    INSERT INTO entry_projects (entry_id, project_id) VALUES (?, ?)
      ON CONFLICT DO NOTHING
    SQL
  return 1;
}

method untag ($kind, $name, $project) {
  _check_taggable($kind);
  _check_name($name);
  croak 'project is required' unless defined $project && length $project;
  my $project_id = $self->_find_project_id($project) or return 1;
  $self->db->query(<<~'SQL', $kind, $name, $project_id);
    DELETE FROM entry_projects
     WHERE entry_id = (SELECT id FROM entries WHERE kind = ? AND name = ?)
       AND project_id = ?
    SQL
  return 1;
}

# Append-only: a save never updates a revision, it adds the next one and
# moves the entry's head to it. The previous content stays readable, which
# is the audit trail git used to provide.
method save ($kind, $name, $content, %opts) {
  _check_kind($kind);
  _check_name($name);

  my ($meta, $body) = $self->_split($content);
  $body =~ s/\A\s+//;
  $body =~ s/\s+\z//;

  my $db = $self->db;
  my $tx = $db->begin;

  my $entry = $db->query(<<~'SQL', $kind, $name)->hash;
    INSERT INTO entries (kind, name) VALUES (?, ?)
      ON CONFLICT (kind, name) DO UPDATE SET name = excluded.name
      RETURNING id, head_id
    SQL

  my $head
    = $entry->{head_id}
    ? $db->query('SELECT * FROM revisions WHERE id = ?', $entry->{head_id})
    ->hash
    : {};

  # Anything the caller did not mention is inherited from the current
  # head, so a save that only changes the body keeps its metadata.
  my $description = $opts{description} // $meta->{description}
    // $head->{description} // '';
  my $type
    = $kind eq 'memory'
    ? ($opts{type} // $meta->{metadata}{type} // $head->{type})
    : undef;
  croak 'type is required for a memory'
    if $kind eq 'memory' && !(defined $type && length $type);

  # Spec keeps project on the revision, required and single - a spec
  # document belongs to exactly one project. Memory and skill no longer
  # write it here at all; a project argument to their save is a tag
  # added below, additive rather than replacing prior tags, since a
  # revision's identity has nothing to do with which projects care
  # about the entry.
  my $project_id;
  if ($kind eq 'spec') {
    my $project_name = $opts{project} // $meta->{project};
    $project_id
      = defined $project_name && length $project_name
      ? $self->_project_id($project_name)
      : $head->{project_id};
    croak 'project is required for a spec' unless defined $project_id;
  }

  # Every bind value has to sit on the heredoc's own line, or the
  # continuation lines end up inside the SQL.
  my @bind = (
    $entry->{id}, $entry->{id}, $body, $description, $type,
    $project_id,  $opts{author}
  );
  my $revision = $db->query(<<~'SQL', @bind)->hash;
    INSERT INTO revisions
      (entry_id, revision, body, description, type, project_id, author)
    VALUES (
      ?,
      (SELECT coalesce(max(revision), 0) + 1 FROM revisions WHERE entry_id = ?),
      ?, ?, ?, ?, ?
    )
    RETURNING id, revision
    SQL

  $db->query('UPDATE entries SET head_id = ? WHERE id = ?',
    $revision->{id}, $entry->{id});

  # Update search_vector for the new revision
  $db->query('SELECT update_revision_search_vector(?, ?, ?, ?)',
    $revision->{id}, $name, $description, $body);

  if ($kind ne 'spec') {
    my $tag = $opts{project} // $meta->{project};
    if (defined $tag && length $tag) {
      my $tag_id = $self->_project_id($tag);
      $db->query(<<~'SQL', $entry->{id}, $tag_id);
        INSERT INTO entry_projects (entry_id, project_id) VALUES (?, ?)
          ON CONFLICT DO NOTHING
        SQL
    }
  }

  $tx->commit;

  # Invalidate vector cache: old head (if exists) and new head
  my $new_entry = $self->_fetch($kind, $name);
  if ($entry->{head_id}) {
    $self->_invalidate_vector_cache($kind, $entry->{head_id});
  }
  $self->_invalidate_vector_cache($kind, $new_entry->{id});
  $self->db->query('DELETE FROM corpus_idf WHERE kind = ?', $kind);

  return $self->_entry($new_entry);
}

method history ($kind, $name) {
  _check_kind($kind);
  _check_name($name);
  return $self->db->query(<<~'SQL', $kind, $name)->hashes->to_array;
    SELECT r.revision, r.description, r.type, p.name AS project, r.author,
           r.created_at, (r.id = e.head_id) AS is_head
      FROM entries e
      JOIN revisions r ON r.entry_id = e.id
      LEFT JOIN projects p ON p.id = r.project_id
     WHERE e.kind = ? AND e.name = ?
     ORDER BY r.revision DESC
    SQL
}

# Soft delete: archive an entry. Hides it from normal reads but keeps all
# data and revision history. Returns the archived entry's current state.
method archive ($kind, $name, %opts) {
  _check_kind($kind);
  _check_name($name);

  my $expected_revision = $opts{expected_revision};
  my $reason = $opts{reason} // '';
  my $author = $opts{author} // croak 'author is required for archive';

  my $db = $self->db;
  my $tx = $db->begin;

  # Check the entry exists and get its current revision
  my $entry = $db->query(
    'SELECT id, head_id FROM entries WHERE kind = ? AND name = ? AND archived_at IS NULL',
    $kind, $name
  )->hash;
  croak "no $kind named '$name' (or already archived)" unless $entry;

  # If expected_revision is provided, verify it matches the current head
  if (defined $expected_revision) {
    my $current_rev = $db->query('SELECT revision FROM revisions WHERE id = ?',
      $entry->{head_id})->hash->{revision};
    croak "expected revision $expected_revision but current is $current_rev"
      unless $current_rev == $expected_revision;
  }

  # Archive the entry. Bind order must match placeholder order (SET
  # before WHERE) - author/reason were previously passed last while
  # binding positionally first, so kind/name landed in archived_by/
  # archived_reason and author/reason landed in the WHERE clause,
  # matching zero rows: this silently no-opped (0 rows updated, never
  # checked) instead of erroring, so every archive_* call looked
  # successful without ever actually archiving anything.
  my $archived = $db->query(<<~'SQL', $author, $reason, $kind, $name)->hash;
    UPDATE entries
      SET archived_at = now(), archived_by = ?, archived_reason = ?
     WHERE kind = ? AND name = ? AND archived_at IS NULL
      RETURNING id, head_id
    SQL
  croak "no $kind named '$name' (or already archived)" unless $archived;

  # Record in audit log
  my $head_revision = $db->query('SELECT revision FROM revisions WHERE id = ?',
    $entry->{head_id})->hash->{revision};
  $db->query(
    <<~'SQL', 'archive', $kind, $name, $head_revision, $author, $reason);
    INSERT INTO audit_log (action, kind, name, revision, acted_by, reason)
    VALUES (?, ?, ?, ?, ?, ?)
    SQL

  $tx->commit;

  # Return the archived entry's state before it was hidden
  my $row = $self->_fetch($kind, $name);
  return $row ? $self->_entry($row) : undef;
}

# Restore an archived entry. Makes it visible again in normal operations.
method restore ($kind, $name, %opts) {
  _check_kind($kind);
  _check_name($name);

  my $author = $opts{author} // croak 'author is required for restore';
  my $reason = $opts{reason} // '';

  my $db = $self->db;
  my $tx = $db->begin;

  # Check the entry exists and is currently archived
  my $entry = $db->query(
    'SELECT id, head_id FROM entries WHERE kind = ? AND name = ? AND archived_at IS NOT NULL',
    $kind, $name
  )->hash;
  croak "no archived $kind named '$name'" unless $entry;

  # Restore the entry
  $db->query(<<~'SQL', $kind, $name)->hash;
    UPDATE entries
      SET archived_at = NULL, archived_by = NULL, archived_reason = NULL
     WHERE kind = ? AND name = ? AND archived_at IS NOT NULL
      RETURNING id, head_id
    SQL

  # Record in audit log
  my $head_revision = $db->query('SELECT revision FROM revisions WHERE id = ?',
    $entry->{head_id})->hash->{revision};
  $db->query(
    <<~'SQL', 'restore', $kind, $name, $head_revision, $author, $reason);
    INSERT INTO audit_log (action, kind, name, revision, acted_by, reason)
    VALUES (?, ?, ?, ?, ?, ?)
    SQL

  $tx->commit;

  # Return the restored entry
  my $row = $self->_fetch($kind, $name);
  return $row ? $self->_entry($row) : undef;
}

# Permanently delete an entry and all its revision history. This is
# destructive and cannot be undone. Returns the audit log entry.
method purge ($kind, $name, %opts) {
  _check_kind($kind);
  _check_name($name);

  my $expected_revision = $opts{expected_revision};
  my $reason = $opts{reason} // '';
  my $author = $opts{author} // croak 'author is required for purge';

  my $db = $self->db;
  my $tx = $db->begin;

  # Check the entry exists (may or may not be archived)
  my $entry
    = $db->query('SELECT id, head_id FROM entries WHERE kind = ? AND name = ?',
    $kind, $name)->hash;
  croak "no $kind named '$name'" unless $entry;

  # If expected_revision is provided, verify it matches the current head
  if (defined $expected_revision) {
    my $current_rev = $db->query('SELECT revision FROM revisions WHERE id = ?',
      $entry->{head_id})->hash->{revision};
    croak "expected revision $expected_revision but current is $current_rev"
      unless $current_rev == $expected_revision;
  }

  # Get the current revision for audit log
  my $head_revision = $db->query('SELECT revision FROM revisions WHERE id = ?',
    $entry->{head_id})->hash->{revision};

  # Delete all project tags first (CASCADE will handle this, but be explicit in log)
  # Then delete the entry and all its revisions (CASCADE from entries to revisions)
  my $deleted = $db->query(<<~'SQL', $kind, $name)->hash;
    DELETE FROM entries WHERE kind = ? AND name = ?
      RETURNING id
    SQL

  # Record in audit log
  $db->query(
    <<~'SQL', 'purge', $kind, $name, $head_revision, $author, $reason);
    INSERT INTO audit_log (action, kind, name, revision, acted_by, reason)
    VALUES (?, ?, ?, ?, ?, ?)
    SQL

  $tx->commit;

  return {
    name     => $name,
    kind     => $kind,
    revision => $head_revision,
    deleted  => !!$deleted,
  };
}

# List archived entries of a given kind, optionally filtered by project.
# Same shape as list() but only returns archived entries.
method list_archived ($kind, $project = undef) {
  _check_kind($kind);
  my ($where,  @bind)  = ('e.kind = ? AND e.archived_at IS NOT NULL', $kind);
  my ($clause, @pbind) = $self->_project_filter($kind, $project);
  $where .= $clause;
  push @bind, @pbind;
  return [map { $self->_entry($_) } @{ $self->_select($where, @bind) }];
}

# Get audit log entries, optionally filtered.
method audit_log ($kind = undef, $name = undef, $action = undef, $limit = 50) {
  my ($where, @bind) = ('1 = 1', ());

  if (defined $kind && length $kind) {
    $where .= ' AND kind = ?';
    push @bind, $kind;
  }
  if (defined $name && length $name) {
    $where .= ' AND name = ?';
    push @bind, $name;
  }
  if (defined $action && length $action) {
    $where .= ' AND action = ?';
    push @bind, $action;
  }

  return $self->db->query(<<~"SQL", @bind, $limit)->hashes->to_array;
    SELECT id, action, kind, name, revision, acted_by, acted_at, reason
      FROM audit_log
     WHERE $where
     ORDER BY acted_at DESC, id DESC
     LIMIT ?
    SQL
}

# Agent credentials. Agents get a token, not an account - there is no
# agent-side user record anywhere in this schema, and a token grants the
# MCP tools and nothing else.
#
# A token is 32 random bytes, so a single SHA-256 is the right hash: it is
# not a password, there is nothing to brute-force, and a KDF would only
# slow down every request. Only the hash is stored, so a database dump
# yields nothing usable.
method create_token ($name) {
  croak 'token name is required' unless defined $name && length $name;

  # Names stay reserved after revocation, so an old credential's name can
  # never quietly come back on a new token. Checked here for a readable
  # error; the unique constraint is what actually guarantees it.
  croak "a token named '$name' already exists"
    . ' (revoked names stay reserved)'
    if $self->db->query('SELECT 1 FROM tokens WHERE name = ?', $name)->rows;

  my $token = 'mcp_ks_' . b64_encode(random_bytes(32), '') =~ tr{+/=}{-_}dr;
  my $row   = $self->db->query(<<~'SQL', $name, sha256_hex($token))->hash;
    INSERT INTO tokens (name, token_hash) VALUES (?, ?)
      RETURNING name, created_at
    SQL

  # The only time the caller ever sees it; nothing can recover it later.
  return { %$row, token => $token };
}

method verify_token ($presented) {
  return undef unless defined $presented && length $presented;
  my $row = $self->db->query(<<~'SQL', sha256_hex($presented))->hash;
    UPDATE tokens SET last_used_at = now()
     WHERE token_hash = ? AND revoked_at IS NULL
      RETURNING name, created_at, last_used_at
    SQL
  return $row;
}

method list_tokens {
  return $self->db->query(<<~'SQL')->hashes->to_array;
    SELECT name, created_at, last_used_at, revoked_at,
           (revoked_at IS NULL) AS active
      FROM tokens
     ORDER BY name
    SQL
}

# Revoking keeps the row, so a name cannot be silently reused and the
# audit trail of what once had access survives.
method revoke_token ($name) {
  croak 'token name is required' unless defined $name && length $name;
  my $row = $self->db->query(<<~'SQL', $name)->hash;
    UPDATE tokens SET revoked_at = now()
     WHERE name = ? AND revoked_at IS NULL
      RETURNING name, revoked_at
    SQL
  return $row;
}

# Agent definitions (.claude/agents/*.md) are not shoehorned into the
# entries/revisions shape: their frontmatter carries fields (tools,
# model, ...) that memory/skill/spec never needed to preserve, so this
# is a plain blob by name - the whole file, verbatim, no parsing and no
# history. A local sync step reads/writes the file; this is just where
# the current version lives centrally.
#
# Agents are global (there is one "analyse", not an abto one and a waya
# one) - which projects a given agent is tailored for is a separate,
# many-to-many fact recorded in project_agents, not a copy of the body
# per project.
method get_agent ($name) {
  _check_name($name);
  my $row = $self->db->query(<<~'SQL', $name)->hash;
    SELECT a.*,
           coalesce(
             (SELECT array_agg(p.name ORDER BY p.name)::text[]
                FROM project_agents pa JOIN projects p ON p.id = pa.project_id
               WHERE pa.agent_name = a.name),
             '{}'
           ) AS projects
      FROM agents a WHERE a.name = ?
    SQL
  return $row;
}

# Optionally filtered to agents tailored for one project - the same
# "list, optionally scoped" shape as list_memories/list_skills, just
# joined against project_agents instead of entry_projects. A project
# nobody has tagged anything with matches nothing, same as elsewhere.
method list_agents ($project = undef) {
  my ($where, @bind) = ('1 = 1', ());
  if (defined $project && length $project) {
    my $project_id = $self->_find_project_id($project);
    ($where, @bind)
      = defined $project_id
      ? (
      'EXISTS (SELECT 1 FROM project_agents pa'
        . ' WHERE pa.agent_name = a.name AND pa.project_id = ?)',
      ($project_id)
      )
      : ('1 = 0', ());
  }
  return $self->db->query(<<~"SQL", @bind)->hashes->to_array;
    SELECT a.name, a.author, a.created_at, a.updated_at,
           coalesce(
             (SELECT array_agg(p.name ORDER BY p.name)::text[]
                FROM project_agents pa JOIN projects p ON p.id = pa.project_id
               WHERE pa.agent_name = a.name),
             '{}'
           ) AS projects
      FROM agents a
     WHERE $where
     ORDER BY a.name
    SQL
}

method save_agent ($name, $content, %opts) {
  _check_name($name);
  croak 'content is required' unless defined $content && length $content;
  return $self->db->query(<<~'SQL', $name, $content, $opts{author})->hash;
    INSERT INTO agents (name, body, author) VALUES (?, ?, ?)
      ON CONFLICT (name) DO UPDATE
        SET body = excluded.body, author = excluded.author,
            updated_at = now()
      RETURNING name, author, created_at, updated_at
    SQL
}

# Unlike a memory/skill/spec (archive/restore/purge - see above), an
# agent definition has no revision history to preserve, so there's no
# soft-delete state to distinguish - this is the only deletion an agent
# has. project_agents rows CASCADE with it.
method delete_agent ($name) {
  _check_name($name);
  my $deleted
    = $self->db->query('DELETE FROM agents WHERE name = ? RETURNING id', $name)
    ->hash;
  croak "no agent named '$name'" unless $deleted;
  return 1;
}

# The tailoring fact: "this agent is a good fit for this project" - not
# ownership, since the same agent can be tailored for several projects,
# and a project can have several agents tailored for it.
method tag_agent ($name, $project) {
  _check_name($name);
  croak 'project is required' unless defined $project && length $project;
  croak "no agent named '$name'"
    unless $self->db->query('SELECT 1 FROM agents WHERE name = ?', $name)
    ->rows;
  my $project_id = $self->_project_id($project);
  $self->db->query(<<~'SQL', $name, $project_id);
    INSERT INTO project_agents (agent_name, project_id) VALUES (?, ?)
      ON CONFLICT DO NOTHING
    SQL
  return 1;
}

method untag_agent ($name, $project) {
  _check_name($name);
  croak 'project is required' unless defined $project && length $project;
  my $project_id = $self->_find_project_id($project) or return 1;
  $self->db->query(
    'DELETE FROM project_agents WHERE agent_name = ? AND project_id = ?',
    $name, $project_id);
  return 1;
}

1;

=pod

=encoding UTF-8

=head1 NAME

MCP::Server::KnowledgeStore::Store - Postgres store for memories, skills, specs, agents, and projects

=head1 VERSION

version 0.001

=head1 SYNOPSIS

  use MCP::Server::KnowledgeStore::Store;

  my $store = MCP::Server::KnowledgeStore::Store->new(
    pg => 'postgresql://mcp_ks@localhost/mcp_ks'
  );
  $store->migrate;

  my $memory = $store->save(
    memory => 'deployment-notes',
    "---\ndescription: Deployment notes\n---\n\nUse the release pipeline.\n",
    author => 'release-agent'
  );

  my $hits = $store->search(memory => 'release pipeline');

=head1 DESCRIPTION

This is the PostgreSQL persistence layer used by
L<MCP::Server::KnowledgeStore>. Memories, skills, and specs are revisioned.
Agent definitions and projects have their own records, and entries can be
associated with projects.

Constructing a store configures its migrations without running them. Call
L</migrate> explicitly when the application is responsible for schema
management.

=head1 METHODS

=head2 migrate

Runs pending C<wdms_mcp> migrations and returns the store.

=head2 db

Returns a L<Mojo::Pg::Database> connection.

=head2 save / get / list / list_recent / history

Create revisions and read revisioned memories, skills, and specs. The first
argument is the entry kind: C<memory>, C<skill>, or C<spec>.

=head2 search

  my $hits = $store->search($kind, $query, $project, $limit);

Selects candidates with PostgreSQL full-text search and ranks them with
TF-IDF corpus vectors.

=head2 tag / untag

Associate a memory or skill with a project. A spec's single project is set
when the spec is saved.

=head2 archive / restore / purge

Manage the lifecycle of revisioned entries. Archiving is reversible. Purging
permanently removes the entry and its revision history.

=head2 list_projects / get_project / create_project / update_project / delete_project

Manage project records.

=head2 list_agents / get_agent / save_agent / delete_agent / tag_agent / untag_agent

Manage agent definitions and their project associations.

=head2 create_token / list_tokens / verify_token / revoke_token

Manage the named bearer tokens accepted by the MCP application.

=head1 AUTHOR

Wesley Schwengle <waterkip@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2026 by Wesley Schwengle.

This is free software, licensed under:

  The (three-clause) BSD License

=cut

__DATA__

@@ migrations.sql

-- 1 up

CREATE TABLE entries (
  id         bigserial PRIMARY KEY,
  kind       text NOT NULL CHECK (kind IN ('memory', 'skill')),
  -- The same slug shape the store enforces in Perl, so a bad name cannot
  -- reach the table by some other route.
  name       text NOT NULL CHECK (name ~ '^[A-Za-z0-9][A-Za-z0-9_-]*$'),
  head_id    bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (kind, name)
);

-- Append-only history. One row per save; the entry's head_id names the
-- current one, so old content is never overwritten.
CREATE TABLE revisions (
  id          bigserial PRIMARY KEY,
  entry_id    bigint NOT NULL REFERENCES entries (id) ON DELETE CASCADE,
  revision    integer NOT NULL CHECK (revision > 0),
  body        text NOT NULL,
  description text NOT NULL DEFAULT '',
  type        text CHECK (type IS NULL
                OR type IN ('user', 'feedback', 'project', 'reference')),
  project     text,
  author      text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (entry_id, revision)
);

ALTER TABLE entries ADD CONSTRAINT entries_head_id_fkey
  FOREIGN KEY (head_id) REFERENCES revisions (id);

CREATE INDEX revisions_entry_id_revision_idx
  ON revisions (entry_id, revision DESC);
CREATE INDEX revisions_project_idx ON revisions (lower(project));

-- 1 down

ALTER TABLE entries DROP CONSTRAINT entries_head_id_fkey;
DROP TABLE revisions;
DROP TABLE entries;

-- 2 up

-- Credentials for the agents that call /mcp. Deliberately not a users
-- table: an agent has a token, a name to identify it by, and nothing
-- else. Only the hash is stored.
CREATE TABLE tokens (
  id           bigserial PRIMARY KEY,
  name         text NOT NULL UNIQUE,
  token_hash   text NOT NULL UNIQUE,
  created_at   timestamptz NOT NULL DEFAULT now(),
  last_used_at timestamptz,
  revoked_at   timestamptz
);

-- Every request hits this lookup, and only live tokens can ever match.
CREATE INDEX tokens_active_hash_idx
  ON tokens (token_hash) WHERE revoked_at IS NULL;

-- 2 down

DROP TABLE tokens;

-- 3 up

-- Usage signals for entries, bumped by the store rather than by an
-- agent's frontmatter, so they cannot be forged by a save.
ALTER TABLE entries ADD COLUMN view_count bigint NOT NULL DEFAULT 0;
ALTER TABLE entries ADD COLUMN useful_count bigint NOT NULL DEFAULT 0;
ALTER TABLE entries ADD COLUMN last_viewed_at timestamptz;

-- 3 down

ALTER TABLE entries DROP COLUMN view_count;
ALTER TABLE entries DROP COLUMN useful_count;
ALTER TABLE entries DROP COLUMN last_viewed_at;

-- 4 up

-- A spec is a project's write-up, kept in the same append-only shape as
-- a memory or skill so it gets revision history, view counts and a
-- project filter for free.
ALTER TABLE entries DROP CONSTRAINT entries_kind_check;
ALTER TABLE entries ADD CONSTRAINT entries_kind_check
  CHECK (kind IN ('memory', 'skill', 'spec'));

-- 4 down

ALTER TABLE entries DROP CONSTRAINT entries_kind_check;
ALTER TABLE entries ADD CONSTRAINT entries_kind_check
  CHECK (kind IN ('memory', 'skill'));

-- 5 up

-- Deliberately not entries/revisions: an agent definition's frontmatter
-- carries fields (tools, model, ...) this store has no reason to know
-- about, so the whole file is kept as one opaque blob, overwritten in
-- place rather than versioned. Agents are global - one "analyse", not
-- an abto one and a waya one - so name alone is the key.
CREATE TABLE agents (
  id         bigserial PRIMARY KEY,
  name       text NOT NULL UNIQUE
               CHECK (name ~ '^[A-Za-z0-9][A-Za-z0-9_-]*$'),
  body       text NOT NULL,
  author     text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Which projects a given agent is tailored for - a fact about fit, not
-- ownership: the same agent can suit several projects, and a project
-- can have several agents suited to it.
CREATE TABLE project_agents (
  agent_name text NOT NULL REFERENCES agents (name) ON DELETE CASCADE,
  project    text NOT NULL,
  PRIMARY KEY (agent_name, project)
);
CREATE INDEX project_agents_project_idx ON project_agents (lower(project));

-- 5 down

DROP TABLE project_agents;
DROP TABLE agents;

-- 6 up

-- Generalizes the same idea to memory and skill: a memory or skill can
-- be relevant to more than one project, so "project" moves from a
-- single column on the revision to a tag on the entry - independent of
-- revision history, the way project_agents is independent of an
-- agent's body. Spec is deliberately excluded: a spec document belongs
-- to exactly one project by definition, so revisions.project stays its
-- authoritative field.
CREATE TABLE entry_projects (
  entry_id bigint NOT NULL REFERENCES entries (id) ON DELETE CASCADE,
  project  text NOT NULL,
  PRIMARY KEY (entry_id, project)
);
CREATE INDEX entry_projects_project_idx ON entry_projects (lower(project));

-- Carry forward whatever was already tagged via the old single-column
-- field, so nothing already in use goes untagged.
INSERT INTO entry_projects (entry_id, project)
SELECT e.id, r.project
  FROM entries e
  JOIN revisions r ON r.id = e.head_id
 WHERE e.kind IN ('memory', 'skill') AND r.project IS NOT NULL;

-- 6 down

DROP TABLE entry_projects;

-- 7 up

-- Project stops being a bare string repeated in three places and
-- becomes a real row: an id other tables reference, so it has
-- somewhere to eventually carry its own metadata (a description, an
-- owner), and "abto" vs "Abto" can no longer silently become two
-- different tags going forward.
CREATE TABLE projects (
  id          bigserial PRIMARY KEY,
  name        text NOT NULL,
  description text,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX projects_name_idx ON projects (lower(name));

-- Carry forward every distinct name already in use, from all three
-- existing free-text sources. Nothing before this migration enforced
-- case-insensitive uniqueness, so a prior "Abto"/"abto" split merges
-- into whichever row the conflict target keeps - the normalization
-- this migration exists to introduce, not a bug in it.
INSERT INTO projects (name)
SELECT DISTINCT project FROM (
  SELECT project FROM entry_projects
  UNION
  SELECT project FROM project_agents
  UNION
  SELECT r.project
    FROM entries e JOIN revisions r ON r.id = e.head_id
   WHERE e.kind = 'spec' AND r.project IS NOT NULL
) AS all_projects
ON CONFLICT (lower(name)) DO NOTHING;

ALTER TABLE entry_projects ADD COLUMN project_id bigint;
UPDATE entry_projects ep SET project_id = p.id
  FROM projects p WHERE lower(p.name) = lower(ep.project);
ALTER TABLE entry_projects ALTER COLUMN project_id SET NOT NULL;
ALTER TABLE entry_projects
  ADD CONSTRAINT entry_projects_project_id_fkey
  FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE;
DROP INDEX entry_projects_project_idx;
ALTER TABLE entry_projects DROP CONSTRAINT entry_projects_pkey;
ALTER TABLE entry_projects DROP COLUMN project;
ALTER TABLE entry_projects ADD PRIMARY KEY (entry_id, project_id);

ALTER TABLE project_agents ADD COLUMN project_id bigint;
UPDATE project_agents pa SET project_id = p.id
  FROM projects p WHERE lower(p.name) = lower(pa.project);
ALTER TABLE project_agents ALTER COLUMN project_id SET NOT NULL;
ALTER TABLE project_agents
  ADD CONSTRAINT project_agents_project_id_fkey
  FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE;
DROP INDEX project_agents_project_idx;
ALTER TABLE project_agents DROP CONSTRAINT project_agents_pkey;
ALTER TABLE project_agents DROP COLUMN project;
ALTER TABLE project_agents ADD PRIMARY KEY (agent_name, project_id);

-- Spec's single project column moves the same way, nullable still -
-- required-ness stays an application rule, same as before.
ALTER TABLE revisions ADD COLUMN project_id bigint
  REFERENCES projects (id);
UPDATE revisions r SET project_id = p.id
  FROM projects p WHERE lower(p.name) = lower(r.project);
DROP INDEX revisions_project_idx;
ALTER TABLE revisions DROP COLUMN project;
CREATE INDEX revisions_project_id_idx ON revisions (project_id);

-- 7 down

ALTER TABLE revisions ADD COLUMN project text;
UPDATE revisions r SET project = p.name
  FROM projects p WHERE p.id = r.project_id;
DROP INDEX revisions_project_id_idx;
ALTER TABLE revisions DROP COLUMN project_id;
CREATE INDEX revisions_project_idx ON revisions (lower(project));

ALTER TABLE project_agents DROP CONSTRAINT project_agents_pkey;
ALTER TABLE project_agents ADD COLUMN project text;
UPDATE project_agents pa SET project = p.name
  FROM projects p WHERE p.id = pa.project_id;
ALTER TABLE project_agents ALTER COLUMN project SET NOT NULL;
ALTER TABLE project_agents DROP CONSTRAINT project_agents_project_id_fkey;
ALTER TABLE project_agents DROP COLUMN project_id;
ALTER TABLE project_agents ADD PRIMARY KEY (agent_name, project);
CREATE INDEX project_agents_project_idx ON project_agents (lower(project));

ALTER TABLE entry_projects DROP CONSTRAINT entry_projects_pkey;
ALTER TABLE entry_projects ADD COLUMN project text;
UPDATE entry_projects ep SET project = p.name
  FROM projects p WHERE p.id = ep.project_id;
ALTER TABLE entry_projects ALTER COLUMN project SET NOT NULL;
ALTER TABLE entry_projects DROP CONSTRAINT entry_projects_project_id_fkey;
ALTER TABLE entry_projects DROP COLUMN project_id;
ALTER TABLE entry_projects ADD PRIMARY KEY (entry_id, project);
CREATE INDEX entry_projects_project_idx ON entry_projects (lower(project));

DROP TABLE projects;

-- 8 up

-- Soft deletion support: archive entries instead of deleting them.
-- Archived entries are hidden from normal list/search but retain all
-- their data and revision history for possible restoration or audit.
ALTER TABLE entries ADD COLUMN archived_at timestamptz;
ALTER TABLE entries ADD COLUMN archived_by text;
ALTER TABLE entries ADD COLUMN archived_reason text;

-- Audit log for deletion/archival operations
CREATE TABLE audit_log (
  id          bigserial PRIMARY KEY,
  action      text NOT NULL CHECK (action IN ('archive', 'restore', 'purge')),
  kind        text NOT NULL CHECK (kind IN ('memory', 'skill', 'spec')),
  name        text NOT NULL,
  revision    integer,
  acted_by    text NOT NULL,
  acted_at    timestamptz NOT NULL DEFAULT now(),
  reason      text
);

CREATE INDEX audit_log_kind_name_idx ON audit_log (kind, name);
CREATE INDEX audit_log_action_idx ON audit_log (action);
CREATE INDEX audit_log_acted_at_idx ON audit_log (acted_at);

-- 8 down

ALTER TABLE entries DROP COLUMN archived_at;
ALTER TABLE entries DROP COLUMN archived_by;
ALTER TABLE entries DROP COLUMN archived_reason;
DROP TABLE audit_log;

-- 9 up

-- Allow namespace-style identifiers (e.g., My::Module::Name) in addition
-- to slug-style (my-module-name). The name pattern now permits colons
-- and double-colons commonly used in module names and URIs.
-- 
-- PostgreSQL auto-generates names for inline CHECK constraints like
-- "entries_name_check" for the entries table. We'll try to drop those
-- and add named constraints. If the old constraint doesn't exist (already
-- migrated), the DROP CONSTRAINT IF EXISTS will silently succeed.
ALTER TABLE entries DROP CONSTRAINT IF EXISTS entries_name_check;
ALTER TABLE entries ADD CONSTRAINT entries_name_check
  CHECK (name ~ '^[A-Za-z0-9][A-Za-z0-9_:-]*$');

ALTER TABLE agents DROP CONSTRAINT IF EXISTS agents_name_check;
ALTER TABLE agents ADD CONSTRAINT agents_name_check
  CHECK (name ~ '^[A-Za-z0-9][A-Za-z0-9_:-]*$');

-- 9 down

ALTER TABLE entries DROP CONSTRAINT IF EXISTS entries_name_check;
ALTER TABLE entries ADD CONSTRAINT entries_name_check
  CHECK (name ~ '^[A-Za-z0-9][A-Za-z0-9_-]*$');

ALTER TABLE agents DROP CONSTRAINT IF EXISTS agents_name_check;
ALTER TABLE agents ADD CONSTRAINT agents_name_check
  CHECK (name ~ '^[A-Za-z0-9][A-Za-z0-9_-]*$');

-- 10 up

-- Add tsvector column for PostgreSQL full-text search (for filtering)
ALTER TABLE revisions ADD COLUMN search_vector tsvector;

-- Create GIN index for fast vector search
CREATE INDEX revisions_search_vector_idx ON revisions USING GIN(search_vector);

-- Function to update search_vector for a revision given its entry name
CREATE OR REPLACE FUNCTION update_revision_search_vector(
  p_revision_id bigint,
  p_name text,
  p_description text,
  p_body text
) RETURNS void AS $func$
BEGIN
  UPDATE revisions 
    SET search_vector = 
      setweight(to_tsvector('english', COALESCE(p_name, '')), 'A') ||
      setweight(to_tsvector('english', COALESCE(p_description, '')), 'B') ||
      setweight(to_tsvector('english', COALESCE(p_body, '')), 'C')
    WHERE id = p_revision_id;
END;
$func$ LANGUAGE plpgsql;

-- Populate search_vector for existing revisions
-- We need to join with entries to get the name
DO $populate$
DECLARE
  rec record;
BEGIN
  FOR rec IN 
    SELECT r.id, e.name, r.description, r.body 
    FROM revisions r 
    JOIN entries e ON e.head_id = r.id 
    WHERE r.search_vector IS NULL
  LOOP
    PERFORM update_revision_search_vector(rec.id, rec.name, rec.description, rec.body);
  END LOOP;
END;
$populate$ LANGUAGE plpgsql;

-- Table for Lingua::TermWeight TF-IDF vectors (for ranking)
CREATE TABLE document_tfidf (
  revision_id bigint PRIMARY KEY REFERENCES revisions(id) ON DELETE CASCADE,
  tfidf_vector jsonb NOT NULL,
  term_count integer NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Table for corpus-wide IDF
CREATE TABLE corpus_idf (
  kind text PRIMARY KEY CHECK (kind IN ('memory', 'skill', 'spec')),
  idf jsonb NOT NULL,
  document_count integer NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Index for faster vector lookups
CREATE INDEX document_tfidf_revision_idx ON document_tfidf (revision_id);

-- 10 down

DROP INDEX IF EXISTS document_tfidf_revision_idx;
DROP TABLE IF EXISTS document_tfidf;
DROP TABLE IF EXISTS corpus_idf;
DROP FUNCTION IF EXISTS update_revision_search_vector(bigint, text, text, text);
DROP INDEX IF EXISTS revisions_search_vector_idx;
ALTER TABLE revisions DROP COLUMN IF EXISTS search_vector;

-- 11 up

-- This store is Postgres-only (no SQLite/MySQL abstraction to keep
-- portable), so citext's own case-insensitive comparison replaces every
-- lower(name) = lower(?) query and the lower(name) functional index
-- below, rather than doing the folding by hand at every call site.
CREATE EXTENSION IF NOT EXISTS citext;

DROP INDEX projects_name_idx;
ALTER TABLE projects ALTER COLUMN name TYPE citext;
CREATE UNIQUE INDEX projects_name_idx ON projects (name);

-- 11 down

DROP INDEX projects_name_idx;
ALTER TABLE projects ALTER COLUMN name TYPE text;
CREATE UNIQUE INDEX projects_name_idx ON projects (lower(name));
