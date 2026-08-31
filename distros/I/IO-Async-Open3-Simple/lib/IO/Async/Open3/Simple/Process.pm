use warnings;
use 5.042;

package IO::Async::Open3::Simple::Process 0.01 {

    # ABSTRACT: Process run using IO::Async::Open3::Simple


    sub new ( $class, $pid, $stdin ) {
        bless { pid => $pid, stdin => $stdin, user => '' }, $class;
    }


    sub pid ($self) { $self->{pid} }


    if ( $^O eq 'MSWin32' ) {
        require Carp;
        *print = sub (@) { Carp::croak("IO::Async::Open3::Simple::Process#print is unsupported on this platform") };
        *say   = sub (@) { Carp::croak("IO::Async::Open3::Simple::Process#say is unsupported on this platform") };
    } else {
        *print = sub ( $self, @data ) {
            my $stdin = $self->{stdin};
            print $stdin @data;
        };
        *say = sub ( $self, @data ) {
            my $stdin = $self->{stdin};
            print $stdin @data, "\n";
        };
    }


    sub close ($self) {
        CORE::close( $self->{stdin} );
    }


    sub user ( $self, $data = undef ) {
        $self->{user} = $data if defined $data;
        $self->{user};
    }

}

__END__

=pod

=encoding UTF-8

=head1 NAME

IO::Async::Open3::Simple::Process - Process run using IO::Async::Open3::Simple

=head1 VERSION

version 0.01

=head1 DESCRIPTION

This class represents a process being handled by L<IO::Async::Open3::Simple>.

=head1 ATTRIBUTES

=head2 pid

 my $pid = $proc->pid;

Return the Process ID of the child process.

=head1 METHODS

=head2 print

 $proc->print(@data);

Write to the subprocess' stdin.

Do NOT use this method if you have passed stdin via the C<$stdin> argument
on the L<IO::Async::Open3::Simple#run> method.

Currently on (non cygwin) Windows (Strawberry, ActiveState) this method is not
supported, so if you need to send (standard) input to the subprocess, you must pass
it into the L<IO::Async::Open3::Simple#run> method.

=head2 say

 $proc->say(@data);

Write to the subprocess' stdin, adding a new line at the end.

Do NOT use this method if you have passed stdin via the C<$stdin> argument
on the L<IO::Async::Open3::Simple#run> method.

Currently on (non cygwin) Windows (Strawberry, ActiveState) this method is not
supported, so if you need to send (standard) input to the subprocess, you must pass
it into the L<IO::Async::Open3::Simple#run> method.

=head2 close

 $proc->close

Close the subprocess' stdin.

=head2 user

 $proc->user($user_data);
 my $user_data = $proc->user;

Get or set user defined data tied to the process object.  Any
Perl data structure may be used.  Useful for persisting data
between callbacks, for example:

 IO::Async::Open3::Simple->new(
   on_start => sub ($proc, $program, @args) {
     $proc->user({ prefix => '> ' });
   },
   on_stdout => sub ($proc, $line) {
     my $prefix = $proc->user->{prefix};
     say "$prefix$line";
   },
 );

=head1 SEE ALSO

=over 4

=item L<IO::Async::Open3::Simple>

=back

=head1 AUTHOR

Graham Ollis <plicease@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2026 by Graham Ollis.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
