package Iterator::Flex::Role::Exhaustion::PassthroughThrow;

# ABSTRACT: signal exhaustion by transitioning to exhausted state and throwing exception

use strict;
use warnings;

our $VERSION = '0.29';

use Role::Tiny;
use experimental 'signatures';
use namespace::clean;






















sub signal_exhaustion ( $self, @exception ) {
    $self->set_exhausted;

    die( @exception ) if @exception;
    require Iterator::Flex::Failure;
    Iterator::Flex::Failure::Exhausted->throw;
}


1;

#
# This file is part of Iterator-Flex
#
# This software is Copyright (c) 2018 by Smithsonian Astrophysical Observatory.
#
# This is free software, licensed under:
#
#   The GNU General Public License, Version 3, June 2007
#

__END__

=pod

=for :stopwords Diab Jerius Smithsonian Astrophysical Observatory

=head1 NAME

Iterator::Flex::Role::Exhaustion::PassthroughThrow - signal exhaustion by transitioning to exhausted state and throwing exception

=head1 VERSION

version 0.29

=head1 METHODS

=head2 signal_exhaustion

   $iterator->signal_exhaustion( @exception );

Signal that the iterator is exhausted.

=over

=item 1

Transition to the L<exhausted state|Iterator::Flex::Manual::Overview/Exhausted Stae>
via the L<Iterator::Flex::Base/set_exhausted> method.

=item 2

die with C<@exception> if provided, else throw L<Iterator::Flex::Failure/Exhausted>.

=back

=head1 INTERNALS

=head1 SUPPORT

=head2 Bugs

Please report any bugs or feature requests to bug-iterator-flex@rt.cpan.org  or through the web interface at: L<https://rt.cpan.org/Public/Dist/Display.html?Name=Iterator-Flex>

=head2 Source

Source is available at

  https://gitlab.com/djerius/iterator-flex

and may be cloned from

  https://gitlab.com/djerius/iterator-flex.git

=head1 SEE ALSO

Please see those modules/websites for more information related to this module.

=over 4

=item *

L<Iterator::Flex|Iterator::Flex>

=back

=head1 AUTHOR

Diab Jerius <djerius@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2018 by Smithsonian Astrophysical Observatory.

This is free software, licensed under:

  The GNU General Public License, Version 3, June 2007

=cut
