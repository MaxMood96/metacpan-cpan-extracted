package Linux::Event::Kernel;
use v5.36;
use strict;
use warnings;

our $VERSION = '0.111';

1;

__END__

=head1 NAME

Linux::Event::Kernel - kernel event and state namespace

=head1 DESCRIPTION

C<Linux::Event::Kernel> is a namespace category for Linux::Event abstractions
over Linux kernel notification and state facilities. Applications choose a
concrete leaf such as L<Linux::Event::Kernel::Timer>,
L<Linux::Event::Kernel::Signal>, L<Linux::Event::Kernel::Event>, or
L<Linux::Event::Kernel::Process>.

=cut
