package Linux::Event::IO;
use v5.36;
use strict;
use warnings;

our $VERSION = '0.111';

1;

__END__

=head1 NAME

Linux::Event::IO - application data I/O namespace

=head1 DESCRIPTION

C<Linux::Event::IO> is a namespace category, not a generic I/O object.
Applications choose a concrete leaf such as L<Linux::Event::IO::Pipe>,
L<Linux::Event::IO::TTY>, or a socket type below L<Linux::Event::IO::Sock>.

=cut
