package Test::StoreDouble;
use v5.38;
use strict;
use warnings;

use base 'Exporter';
our @EXPORT_OK = qw(create_test_store);

use Carp        qw(croak);
use YAML::XS    qw(Load Dump);
use Mojo::Util  qw(b64_encode);
use Crypt::PRNG qw(random_bytes);
use Digest::SHA qw(sha256_hex);

# A simple in-memory implementation of MCP::Server::KnowledgeStore::Store interface
# for testing without a database

sub create_test_store {
  my %entries;
  my %revisions;
  my %entry_heads;
  my %next_rev = ();
  my $next_id  = 1;
  my %tokens;

  my $store = bless {
    entries     => \%entries,
    revisions   => \%revisions,
    entry_heads => \%entry_heads,
    next_rev    => \%next_rev,
    next_id     => \$next_id,
    tokens      => \%tokens,
    },
    'Test::StoreDouble';

  return $store;
}

# Implement the Store interface

sub list {
  my ($self, $kind, $project) = @_;
  $self->_check_kind($kind);

  my @results;
  for my $entry_id (
    sort { $self->{entries}{$a}{name} cmp $self->{entries}{$b}{name} }
    keys %{ $self->{entries} }
    )
  {
    next unless $self->{entries}{$entry_id}{kind} eq $kind;
    next if $self->{entries}{$entry_id}{archived_at};
    my $rev_id = $self->{entry_heads}{$entry_id};
    next unless $rev_id && $self->{revisions}{$rev_id};
    my $rev = $self->{revisions}{$rev_id};
    next
      if $project && !grep { lc($_) eq lc($project) }
      @{ $self->{entries}{$entry_id}{projects} // [] };
    push @results, $self->_entry($self->{entries}{$entry_id}, $rev);
  }
  return \@results;
}

sub get {
  my ($self, $kind, $name, $revision) = @_;
  $self->_check_kind($kind);
  $self->_check_name($name);

  for my $entry_id (keys %{ $self->{entries} }) {
    next
      unless $self->{entries}{$entry_id}{kind} eq $kind
      && $self->{entries}{$entry_id}{name} eq $name;

    my $rev_id;
    if ($revision) {

      # Find revision by revision number
      for my $rid (keys %{ $self->{revisions} }) {
        my $rev_entry_id = $self->{revisions}{$rid}{entry_id};
        $rev_entry_id = $$rev_entry_id if ref($rev_entry_id) eq 'SCALAR';
        if ( $rev_entry_id == $entry_id
          && $self->{revisions}{$rid}{revision} == $revision)
        {
          $rev_id = $rid;
          last;
        }
      }
    }
    else {
      $rev_id = $self->{entry_heads}{$entry_id};
    }

    next unless $rev_id && $self->{revisions}{$rev_id};
    my $rev = $self->{revisions}{$rev_id};
    return $self->_entry($self->{entries}{$entry_id},
      $rev, $rev_id == $self->{entry_heads}{$entry_id});
  }
  return undef;
}

sub save {
  my ($self, $kind, $name, $content, %opts) = @_;
  $self->_check_kind($kind);

  croak 'name is required' unless defined $name && length $name;
  $self->_check_name($name);

  # Find existing entry by name and kind
  my $entry_id;
  for my $eid (keys %{ $self->{entries} }) {
    if ( $self->{entries}{$eid}{kind} eq $kind
      && $self->{entries}{$eid}{name} eq $name)
    {
      $entry_id = $eid + 0;    # Force numeric
      last;
    }
  }
  if (!defined $entry_id) {
    $entry_id = $self->{next_id}++;
    $entry_id = $$entry_id if ref($entry_id) eq 'SCALAR';
    $entry_id += 0;    # Force numeric
  }

  if (!$self->{entries}{$entry_id}) {
    $self->{entries}{$entry_id} = {
      id           => $entry_id,
      kind         => $kind,
      name         => $name,
      created_at   => '2026-01-01 00:00:00',
      archived_at  => undef,
      head_id      => undef,
      view_count   => 0,
      useful_count => 0,
      projects     => [],
    };
  }

  my $entry = $self->{entries}{$entry_id};

  # Get previous revision's data for inheritance
  my $prev_rev_id = $entry->{head_id};
  my $prev_rev
    = $prev_rev_id && $self->{revisions}{$prev_rev_id}
    ? $self->{revisions}{$prev_rev_id}
    : undef;

  # Parse frontmatter if present
  my ($meta, $body) = $self->_split($content);
  my $description = $opts{description} // $meta->{description}
    // ($prev_rev ? $prev_rev->{description} : '') // '';
  my $type = $opts{type} // $meta->{metadata}{type}
    // ($entry->{type} // ($prev_rev ? $prev_rev->{type} : undef));
  my $author = $opts{author} // $meta->{author} // 'test-author';

  # Strip trailing and leading newlines from body
  $body =~ s/\n\z//;
  $body =~ s/\A\n//;

  croak 'type is required' if $kind eq 'memory' && !defined $type;

  # Handle projects from frontmatter
  if (exists $meta->{project}) {
    $entry->{projects} = [
      ref($meta->{project}) eq 'ARRAY'
      ? @{ $meta->{project} }
      : $meta->{project}
    ];
  }
  if ($opts{project}) {
    push @{ $entry->{projects} }, $opts{project};
  }

  # Update entry with current type for inheritance
  $entry->{type}        = $type        if defined $type;
  $entry->{description} = $description if defined $description;

  my $rev_id = $self->{next_id}++;
  $rev_id = $$rev_id if ref($rev_id) eq 'SCALAR';
  $rev_id += 0;

  $self->{next_rev}{$entry_id} = ($self->{next_rev}{$entry_id} // 0) + 1;

  $self->{revisions}{$rev_id} = {
    id          => $rev_id + 0,
    entry_id    => $entry_id + 0,
    body        => $body,
    description => $description,
    type        => $type,
    author      => $author,
    created_at  => '2026-01-01 00:00:00',
    revision    => $self->{next_rev}{$entry_id} + 0,
  };

  $entry->{head_id} = $rev_id;
  $self->{entry_heads}{$entry_id} = $rev_id;

  return $self->_entry($entry, $self->{revisions}{$rev_id}, 1);
}

sub history {
  my ($self, $kind, $name) = @_;
  $self->_check_kind($kind);

  for my $entry_id (keys %{ $self->{entries} }) {
    next
      unless $self->{entries}{$entry_id}{kind} eq $kind
      && $self->{entries}{$entry_id}{name} eq $name;
    my @results;
    for my $rev_id (
      sort {
        $self->{revisions}{$b}{revision} <=> $self->{revisions}{$a}{revision}
      } keys %{ $self->{revisions} }
      )
    {
      my $rev_entry_id = $self->{revisions}{$rev_id}{entry_id};
      $rev_entry_id = $$rev_entry_id if ref($rev_entry_id) eq 'SCALAR';
      next unless $rev_entry_id == $entry_id;
      push @results,
        {
        %{ $self->{revisions}{$rev_id} },
        is_head => ($rev_id == $self->{entry_heads}{$entry_id} ? 1 : 0),
        };
    }
    return \@results;
  }
  return [];
}

sub search {
  my ($self, $kind, $query, $project) = @_;
  $self->_check_kind($kind);
  croak 'query is required' unless defined $query && length $query;

  my @results;
  for my $entry_id (keys %{ $self->{entries} }) {
    next unless $self->{entries}{$entry_id}{kind} eq $kind;
    next if $self->{entries}{$entry_id}{archived_at};
    my $rev_id = $self->{entry_heads}{$entry_id};
    next unless $rev_id && $self->{revisions}{$rev_id};
    my $rev = $self->{revisions}{$rev_id};
    next
      unless $rev->{body} =~ /\Q$query/i
      || ($rev->{description} // '') =~ /\Q$query/i;
    my $match = $rev->{body};
    $match =~ s/\A\n//;
    push @results,
      { %{ $self->{entries}{$entry_id} }, %$rev, matches => [$match], };
  }
  return \@results;
}

# Token methods

sub create_token {
  my ($self, $name) = @_;
  croak 'token name is required' unless defined $name && length $name;

  croak "a token named '$name' already exists"
    . ' (revoked names stay reserved)'
    if exists $self->{tokens}{$name};

  my $token = 'mcp_ks_' . (b64_encode(random_bytes(32), '') =~ tr{+/=}{-_}dr);
  my $token_hash = sha256_hex($token);

  $self->{tokens}{$name} = {
    name       => $name,
    token_hash => $token_hash,
    created_at => '2026-01-01 00:00:00',
    revoked_at => undef,
  };

  return {
    name       => $name,
    created_at => '2026-01-01 00:00:00',
    token      => $token
  };
}

sub verify_token {
  my ($self, $presented) = @_;
  return undef unless defined $presented && length $presented;

  my $hash = sha256_hex($presented);
  for my $name (keys %{ $self->{tokens} }) {
    if ($self->{tokens}{$name}{token_hash} eq $hash
      && !defined $self->{tokens}{$name}{revoked_at})
    {
      $self->{tokens}{$name}{last_used_at} = '2026-01-01 00:00:01';
      return {
        name         => $name,
        created_at   => $self->{tokens}{$name}{created_at},
        last_used_at => '2026-01-01 00:00:01'
      };
    }
  }
  return undef;
}

sub list_tokens {
  my ($self) = @_;
  my @results;
  for my $name (sort keys %{ $self->{tokens} }) {
    my $t = $self->{tokens}{$name};
    push @results,
      {
      name         => $name,
      created_at   => $t->{created_at},
      last_used_at => $t->{last_used_at} // undef,
      revoked_at   => $t->{revoked_at}   // undef,
      active       => ($t->{revoked_at} ? 0 : 1),
      };
  }
  return \@results;
}

sub revoke_token {
  my ($self, $name) = @_;
  croak 'token name is required' unless defined $name && length $name;

  return undef
    unless exists $self->{tokens}{$name}
    && !defined $self->{tokens}{$name}{revoked_at};

  $self->{tokens}{$name}{revoked_at} = '2026-01-01 00:00:00';
  return { name => $name, revoked_at => '2026-01-01 00:00:00' };
}

# Private helpers (copied from Store.pm)

sub _check_kind {
  my ($self, $kind) = @_;
  croak "invalid kind '$kind': expected memory, skill or spec"
    unless defined $kind
    && ($kind eq 'memory' || $kind eq 'skill' || $kind eq 'spec');
  return $kind;
}

sub _check_name {
  my ($self, $name) = @_;
  croak 'name is required' unless defined $name && length $name;
  croak "invalid name '$name': expected alphanumeric name with optional "
    . "hyphens, underscores, or colons (e.g., my-memory-name or My::Module::Name)"
    unless $name =~ /\A[A-Za-z0-9][A-Za-z0-9_:-]*\z/a;
  return $name;
}

sub _split {
  my ($self, $text) = @_;
  $text //= '';
  return ({}, $text) unless $text =~ s/\A---\r?\n(.*?)\r?\n---[ \t]*\r?\n?//s;
  my $meta = eval { Load($1) } // {};
  $meta = {} unless ref $meta eq 'HASH';
  return ($meta, $text);
}

sub _entry {
  my ($self, $row, $rev, $is_head) = @_;
  $is_head //= 0;
  my $meta
    = { name => $row->{name}, description => $rev->{description} // '' };
  $meta->{metadata}{type} = $rev->{type} if defined $rev->{type};
  $meta->{project} = $row->{projects}[0]
    if defined $row->{projects} && @{ $row->{projects} };

  my $head = Dump($meta);
  $head = "---\n$head" unless $head =~ /\A---\r?\n/;
  $head =~ s/\n?\z/\n/;
  return {
    name           => $row->{name},
    description    => $row->{description} // '',
    type           => $rev->{type},
    project        => $row->{projects}[0] // undef,
    projects       => $row->{projects}    // [],
    kind           => $row->{kind},
    revision       => $rev->{revision},
    author         => $rev->{author},
    created_at     => $rev->{created_at},
    body           => $rev->{body},
    content        => $head . "---\n\n" . ($rev->{body} // '') . "\n",
    view_count     => $row->{view_count}   // 0,
    useful_count   => $row->{useful_count} // 0,
    last_viewed_at => $row->{last_viewed_at},
    is_head        => $is_head,
  };
}

1;
