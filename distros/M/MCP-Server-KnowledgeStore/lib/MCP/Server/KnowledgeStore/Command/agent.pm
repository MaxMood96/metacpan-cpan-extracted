package MCP::Server::KnowledgeStore::Command::agent;
use v5.38;
use Mojo::Base 'Mojolicious::Command', -signatures;

our $VERSION = '0.001';

# ABSTRACT: Sync agent definitions between the store and .claude/agents

use Getopt::Long qw(GetOptionsFromArray);
use Mojo::File   qw(curfile);

has description => 'Sync agent definitions with .claude/agents';
has usage       => <<~'USAGE';
  Usage: APPLICATION agent list [--project NAME]
         APPLICATION agent pull <name> [--dir PATH]
         APPLICATION agent pull --project NAME [--dir PATH]
         APPLICATION agent push <name> [--dir PATH] [--project NAME] [--author NAME]

    ./bin/mcp-ks agent pull react-native-programming
    ./bin/mcp-ks agent pull --project abto
    ./bin/mcp-ks agent push react-native-programming --project abto

  Claude Code resolves subagent_type from .claude/agents/*.md before any
  tool call can run, so pulling an agent from the store is what actually
  makes it usable in a session - reading it over MCP alone does not.
  --dir defaults to ./.claude/agents (relative to the current directory).
  USAGE

sub run ($self, $action = undef, @args) {
  my $method = {
    list => \&_list,
    pull => \&_pull,
    push => \&_push,
  }->{ $action // '' };
  die $self->usage unless $method;

  unless (eval { $method->($self, @args); 1 }) {
    my $err = $@ // 'unknown error';
    $err =~ s/ at \S+ line \d+\.?\s*\z//;
    say STDERR $err;
    exit 1;
  }
  return;
}

sub _dir_for (@args) {
  my $dir = '.claude/agents';
  GetOptionsFromArray(\@args, 'dir=s' => \$dir);
  return (Mojo::File->new($dir), @args);
}

sub _list ($self, @args) {
  my $project;
  GetOptionsFromArray(\@args, 'project=s' => \$project);
  my $store  = $self->app->store;
  my $agents = $store->list_agents($project);
  return say 'No agents in the store.' unless @$agents;
  printf "%-30s %-20s %s\n", 'NAME', 'AUTHOR', 'PROJECTS';
  for my $agent (@$agents) {
    printf "%-30s %-20s %s\n", $agent->{name}, $agent->{author} // '',
      join(', ', @{ $agent->{projects} // [] });
  }
  return;
}

sub _pull ($self, @args) {
  my $project;
  GetOptionsFromArray(\@args, 'project=s' => \$project);
  my ($dir, $name) = _dir_for(@args);
  die $self->usage unless defined $project || defined $name;

  my $store = $self->app->store;
  my @names
    = defined $project
    ? map { $_->{name} } @{ $store->list_agents($project) }
    : ($name);
  die "No agents tagged for project '$project'.\n"
    if defined $project && !@names;

  $dir->make_path unless -d $dir;
  for my $agent_name (@names) {
    my $agent = $store->get_agent($agent_name);
    die "No agent named '$agent_name'.\n" unless $agent;
    my $file = $dir->child("$agent_name.md");
    $file->spurt($agent->{body});
    say "Pulled $agent_name -> $file";
  }
  return;
}

sub _push ($self, @args) {
  my ($project, $author);
  GetOptionsFromArray(
    \@args,
    'project=s' => \$project,
    'author=s'  => \$author
  );
  my ($dir, $name) = _dir_for(@args);
  die $self->usage unless defined $name;

  my $file = $dir->child("$name.md");
  die "No such file: $file\n" unless -e $file;

  my $store = $self->app->store;
  $store->save_agent($name, $file->slurp, author => $author);
  say "Pushed $file -> $name";

  if (defined $project) {
    $store->tag_agent($name, $project);
    say "Tagged $name for project '$project'";
  }
  return;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

MCP::Server::KnowledgeStore::Command::agent - Sync agent definitions between the store and .claude/agents

=head1 VERSION

version 0.001

=head1 SYNOPSIS

  ./bin/mcp-ks agent list
  ./bin/mcp-ks agent list --project abto
  ./bin/mcp-ks agent pull react-native-programming
  ./bin/mcp-ks agent pull --project abto
  ./bin/mcp-ks agent push react-native-programming --project abto

=head1 DESCRIPTION

Agent definitions (C<.claude/agents/*.md>) are stored verbatim in
L<MCP::Server::KnowledgeStore::Store>'s C<agents> table, but reading one back over MCP
does not make it usable: Claude Code resolves C<subagent_type> from
local files before any tool call can run. This command is the missing
step - pull writes the stored body to a local file, push reads a local
file into the store.

=head1 METHODS

=head2 run

  $command->run(@ARGV);

Dispatches to C<list>, C<pull> or C<push>.

=head1 AUTHOR

Wesley Schwengle <waterkip@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2026 by Wesley Schwengle.

This is free software, licensed under:

  The (three-clause) BSD License

=cut
