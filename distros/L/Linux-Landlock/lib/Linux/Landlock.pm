package Linux::Landlock;

=head1 NAME

Linux::Landlock - A higher level interface to the Linux Landlock API

=head1 DESCRIPTION

Landlock is a sandboxing feature specific to Linux that allows a process to
restrict its own access to the file system.
Once set, restrictions cannot be undone and they are inherited by all future
child processes.

Since the restrictions are set at runtime, from within the process itself,
you can take into account dynamic information from your configuration.
For example, a server that is supposed to serve files from a specific directory
can restrict itself to that directory and its subdirectories to mitigate any bugs
allowing directory traversal attacks. This is much less intrusive than chroot
and does not require root privileges.

This module provides an object-oriented interface to the Linux Landlock API.
It uses the lower-level interface provided by L<Linux::Landlock::Direct>.

See L<https://docs.kernel.org/userspace-api/landlock.html> for more information
about Landlock.

=head1 METHODS

=head1 SYNOPSIS

      use Linux::Landlock;

      my $ruleset = Linux::Landlock->new(); # this can die
      $ruleset->add_path_rule('/etc/fstab', qw(read_file));
      $ruleset->add_net_rule(22222, qw(bind_tcp));
      $ruleset->apply();

      print -r '/etc/fstab' ? "allowed\n" : "not allowed\n"; # allowed ...
      IO::File->new('/etc/fstab', 'r') and print "succeeded: $!\n"; # ... and opening works
      print -r '/etc/passwd' ? "allowed\n" : "not allowed\n"; # allowed ...
      IO::File->new('/etc/passwd', 'r') or print "failed\n"; # ... but opening fails because of Landlock

      system('/usr/bin/cat /etc/fstab') and print "failed: $!\n"; # this fails, because we cannot execute cat

      IO::Socket::INET->new(LocalPort => 33333, Proto => 'tcp') or print "failed: $!\n"; # failed
      IO::Socket::INET->new(LocalPort => 22222, Proto => 'tcp') and print "succeeded\n"; # succeeded

=over 1

=item new([handled_fs_actions => \@fs_actions, handled_net_actions => \@net_actions, die_on_unsupported => 1|0])

Create a new L<Linux::Landlock> instance.

C<handled_fs_actions> and C<handled_net_actions> restrict the set of actions that can be used in rules and that
will be prevented if not allowed by any rule. By default, all actions supported by the kernel and known to this
module are covered. This should usually not be changed.

If C<die_on_unsupported> is set to a true value, the module will die if an unsupported access right is requested.
Otherwise, access rights will be set on a best-effort basis, as intended by the upstream Landlock API design. This
option should usually not be used.

=item apply()

Apply the ruleset to the current process and all future children. Dies on error.

=item get_abi_version()

Int, returns the ABI version of the Landlock kernel module. Can be called as a static method.
A version < 1 means that Landlock is not available.

=item add_path_beneath_rule($path, @allowed)

Add a rule to the ruleset that allows the specified access to the given path.
C<$path> can be a file or a directory. C<@allowed> is a list of access rights to allow.

Possible access rights are:

    execute
    write_file
    read_file
    read_dir
    remove_dir
    remove_file
    make_char
    make_dir
    make_reg
    make_sock
    make_fifo
    make_block
    make_sym
    refer
    truncate
    ioctl_dev

See  L<https://docs.kernel.org/userspace-api/landlock.html> for all possible access rights.

This method dies on error. Errors are: non-existing or non-accessible paths and empty rules.
If C<die_on_unsupported> is used, it will also die if the rules are not supported by the
current kernel.

B<Beware>: While the API accepts a path or user space file descriptor, the rule is actually
checked against the corresponding, kernel internal file system object. This means that you
will lose access if a path or directory you allowed access to is renamed or replaced.

=item add_net_port_rule($port, @allowed)

Add a rule to the ruleset that allows the specified access to the given port.
C<$port> is allowed port, C<@allowed> is a list of allowed operations.

Possible operations are:

    bind_tcp
    connect_tcp

=item allow_perl_inc_access()

A convenience method that adds rules to allow reading files and directories in
all directories in C<@INC>.
This will not allow access to ".", even if it is in C<@INC>.

=back

=head1 LIMITATIONS

This module requires a Linux system supporting the Landlock functionality. As of
2024, this is the case for almost all distributions, however, the version of the
available Landlock ABI varies.

Notably, the C<TRUNCATE> access right is only supported by the kernel since ABI
version 3 (kernel version 6.2 or newer, unless backported).

Network functionality is only available since ABI version 4.

Also keep in mind, that some Perl, or even libc, functions might implicitly rely
on file system access that could have been restricted by Landlock.

=head1 AUTHOR

Marc Ballarin, <ballarin.marc@gmx.de>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2024 by Marc Ballarin

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

use strict;
use warnings;
use POSIX                   ();
use List::Util              qw(reduce);
use Linux::Landlock::Direct qw(
  %LANDLOCK_ACCESS_FS
  %LANDLOCK_ACCESS_NET
  ll_add_path_beneath_rule
  ll_add_net_port_rule
  ll_restrict_self
  ll_get_abi_version
  ll_create_fs_ruleset
  ll_create_net_ruleset
  set_no_new_privs
);
our $VERSION = '0.8';

sub new {
    my ($class, %args) = @_;
    die "Landlock is not available\n" if ll_get_abi_version() < 1;
    my $self = bless {}, $class;
    $self->{die_on_unsupported}  = $args{die_on_unsupported};
    $self->{handled_fs_actions}  = ref $args{handled_fs_actions} eq 'ARRAY'  ? $args{handled_fs_actions}  : [];
    $self->{handled_net_actions} = ref $args{handled_net_actions} eq 'ARRAY' ? $args{handled_net_actions} : [];
    return $self;
}

sub apply {
    my ($self) = @_;
    set_no_new_privs() or die "Failed to set no_new_privs: $!\n";
    if (defined $self->{_fs_fd}) {
        ll_restrict_self($self->{_fs_fd}) or die "Failed to restrict self: $!\n";
    }
    if (defined $self->{_net_fd}) {
        ll_restrict_self($self->{_net_fd}) or die "Failed to restrict self: $!\n";
    }
    return 1;
}

sub get_abi_version {
    return ll_get_abi_version();
}

sub add_path_beneath_rule {
    my ($self, $path, @allowed) = @_;

    unless (defined $self->{_fs_fd}) {
        $self->{_fs_fd} = ll_create_fs_ruleset(map { $LANDLOCK_ACCESS_FS{ uc $_ } } @{ $self->{handled_fs_actions} })
          or die "Failed to create ruleset: $!\n";
    }
    my $is_dir = -d $path;
    if (my $fd = $is_dir ? POSIX::opendir($path) : POSIX::open($path)) {
        my $allowed = reduce { $a | $b } map { $LANDLOCK_ACCESS_FS{ uc $_ } } @allowed;
        my $result  = ll_add_path_beneath_rule($self->{_fs_fd}, $allowed, $fd);
        if ($is_dir) {
            POSIX::closedir($fd);
        } else {
            POSIX::close($fd);
        }
        die "Failed to add rule: $!\n" unless $result;
        if ($result != $allowed && $self->{die_on_unsupported}) {
            die "Unsupported access rights: $allowed vs. $result\n";
        }
        return $result;
    } else {
        die "Failed to open $path: $!\n";
    }
}

sub add_net_port_rule {
    my ($self, $port, @allowed) = @_;
    unless (defined $self->{_net_fd}) {
        $self->{_net_fd} = ll_create_net_ruleset(map { $LANDLOCK_ACCESS_FS{ uc $_ } } @{ $self->{handled_net_actions} })
          or die "Failed to create ruleset: $!\n";
    }
    my $allowed = reduce { $a | $b } map { $LANDLOCK_ACCESS_NET{ uc $_ } } @allowed;
    my $result  = ll_add_net_port_rule($self->{_net_fd}, $allowed, $port) or die "Failed to add rule: $!\n";
    if ($result != $allowed && $self->{die_on_unsupported}) {
        die "Unsupported access rights: $allowed vs. $result\n";
    }
    return $result;
}

sub allow_perl_inc_access {
    my ($self) = @_;

    for (@INC) {
        next unless -d $_;
        next if $_ eq '.';
        $self->add_path_beneath_rule($_, qw(read_file read_dir));
    }
    return 1;
}

sub allow_std_dev_access {
    my ($self) = @_;

    for (qw(null zero random urandom)) {
        $self->add_path_beneath_rule("/dev/$_", qw(read_file write_file));
    }
    return 1;
}

sub DESTROY {
    my ($self) = @_;
    POSIX::close($self->{_fs_fd})  if defined $self->{_fs_fd};
    POSIX::close($self->{_net_fd}) if defined $self->{_net_fd};
    return;
}

1;
