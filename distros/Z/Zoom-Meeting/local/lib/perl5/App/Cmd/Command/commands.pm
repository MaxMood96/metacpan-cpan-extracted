use strict;
use warnings;

package App::Cmd::Command::commands 0.335;

use App::Cmd::Command;
BEGIN { our @ISA = 'App::Cmd::Command' };

# ABSTRACT: list the application's commands

#pod =head1 DESCRIPTION
#pod
#pod This command will list all of the application commands available and their
#pod abstracts.
#pod
#pod =method execute
#pod
#pod This is the command's primary method and raison d'etre.  It prints the
#pod application's usage text (if any) followed by a sorted listing of the
#pod application's commands and their abstracts.
#pod
#pod The commands are printed in sorted groups (created by C<sort_commands>); each
#pod group is set off by blank lines.
#pod
#pod =cut

sub execute {
  my ($self, $opt, $args) = @_;

  my $target = $opt->stderr ? *STDERR : *STDOUT;
 
  my @cmd_groups = $self->app->command_groups;
  my @primary_commands = map { @$_ if ref $_ } @cmd_groups;

  if (!@cmd_groups) {
    @primary_commands =
      grep { $_ ne 'version' or $self->app->{show_version} }
      map { ($_->command_names)[0] }
      $self->app->command_plugins;

    @cmd_groups = $self->sort_commands(@primary_commands);
  }

  my $fmt_width = 0;
  for (@primary_commands) { $fmt_width = length if length > $fmt_width }
  $fmt_width += 2; # pretty

  foreach my $cmd_set (@cmd_groups) {
    if (!ref $cmd_set) {
      print { $target } "$cmd_set:\n";
      next;
    }
    for my $command (@$cmd_set) {
      my $abstract = $self->app->plugin_for($command)->abstract;
      printf { $target } "%${fmt_width}s: %s\n", $command, $abstract;
    }
    print { $target } "\n";
  }
}

#pod =method C<sort_commands>
#pod
#pod   my @sorted = $cmd->sort_commands(@unsorted);
#pod
#pod This method orders the list of commands into groups which it returns as a list of
#pod arrayrefs, and optional group header strings.
#pod
#pod By default, the first group is for the "help" and "commands" commands, and all
#pod other commands are in the second group.
#pod
#pod This method can be overridden by implementing the C<commands_groups> method in
#pod your application base clase.
#pod
#pod =cut

sub sort_commands {
  my ($self, @commands) = @_;

  my $float = qr/^(?:help|commands)$/;

  my @head = sort grep { $_ =~ $float } @commands;
  my @tail = sort grep { $_ !~ $float } @commands;

  return (\@head, \@tail);
}

sub opt_spec {
  return (
    [ 'stderr' => 'hidden' ],
  );
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

App::Cmd::Command::commands - list the application's commands

=head1 VERSION

version 0.335

=head1 DESCRIPTION

This command will list all of the application commands available and their
abstracts.

=head1 PERL VERSION

This library should run on perls released even a long time ago.  It should work
on any version of perl released in the last five years.

Although it may work on older versions of perl, no guarantee is made that the
minimum required version will not be increased.  The version may be increased
for any reason, and there is no promise that patches will be accepted to lower
the minimum required perl.

=head1 METHODS

=head2 execute

This is the command's primary method and raison d'etre.  It prints the
application's usage text (if any) followed by a sorted listing of the
application's commands and their abstracts.

The commands are printed in sorted groups (created by C<sort_commands>); each
group is set off by blank lines.

=head2 C<sort_commands>

  my @sorted = $cmd->sort_commands(@unsorted);

This method orders the list of commands into groups which it returns as a list of
arrayrefs, and optional group header strings.

By default, the first group is for the "help" and "commands" commands, and all
other commands are in the second group.

This method can be overridden by implementing the C<commands_groups> method in
your application base clase.

=head1 AUTHOR

Ricardo Signes <cpan@semiotic.systems>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2022 by Ricardo Signes.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
