package MCP::Server::KnowledgeStore::Command::token;
use v5.38;
use Mojo::Base 'Mojolicious::Command', -signatures;

our $VERSION = '0.001';

# ABSTRACT: Manage the agent tokens that authenticate /mcp

has description => 'Manage agent tokens';
has usage       => <<~'USAGE';
  Usage: APPLICATION token list
         APPLICATION token add <name>
         APPLICATION token revoke <name>

    ./bin/mcp-ks token add 'claude-code machine-a'

  A token is shown once, when it is created, and cannot be recovered
  afterwards - only its hash is stored. Mint a new one instead.
  USAGE

sub run ($self, $action = undef, @args) {
  my $store  = $self->app->store;
  my $method = {
    list   => \&_list,
    add    => \&_add,
    revoke => \&_revoke,
  }->{ $action // '' };
  die $self->usage unless $method;

  # A croak from the store is a message for the operator, not a stack
  # trace: strip the "at ... line N" Perl appends and exit non-zero.
  unless (eval { $method->($self, $store, @args); 1 }) {
    my $err = $@ // 'unknown error';
    $err =~ s/ at \S+ line \d+\.?\s*\z//;
    say STDERR $err;
    exit 1;
  }
  return;
}

sub _list ($self, $store, @) {
  my $tokens = $store->list_tokens;
  return say 'No tokens yet.' unless @$tokens;
  printf "%-30s %-12s %s\n", 'NAME', 'STATE', 'LAST USED';
  for my $token (@$tokens) {
    printf "%-30s %-12s %s\n", $token->{name},
      ($token->{active} ? 'active' : 'revoked'),
      $token->{last_used_at} // 'never';
  }
  return;
}

sub _add ($self, $store, $name = undef, @) {
  die $self->usage unless defined $name && length $name;
  my $token = $store->create_token($name);
  say "Token for $token->{name}:";
  say "";
  say "  $token->{token}";
  say "";
  say 'Shown once - store it now. Only its hash is kept.';
  return;
}

sub _revoke ($self, $store, $name = undef, @) {
  die $self->usage unless defined $name && length $name;
  my $revoked = $store->revoke_token($name);
  return say "No live token named '$name'." unless $revoked;
  say "Revoked $revoked->{name} at $revoked->{revoked_at}.";
  return;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

MCP::Server::KnowledgeStore::Command::token - Manage the agent tokens that authenticate /mcp

=head1 VERSION

version 0.001

=head1 SYNOPSIS

  ./bin/mcp-ks token list
  ./bin/mcp-ks token add 'claude-code machine-a'
  ./bin/mcp-ks token revoke 'claude-code machine-a'

=head1 DESCRIPTION

Mint, list and revoke the tokens agents use to authenticate against
C</mcp>. There is no web interface for this yet, so this command is how
credentials are managed.

=head1 ATTRIBUTES

=head2 description / usage

Inherited from L<Mojolicious::Command>.

=head1 METHODS

=head2 run

  $command->run(@ARGV);

Dispatches to C<list>, C<add> or C<revoke>.

=head1 AUTHOR

Wesley Schwengle <waterkip@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2026 by Wesley Schwengle.

This is free software, licensed under:

  The (three-clause) BSD License

=cut
