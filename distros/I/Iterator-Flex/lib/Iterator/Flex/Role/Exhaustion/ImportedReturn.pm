package Iterator::Flex::Role::Exhaustion::ImportedReturn;

# ABSTRACT: Imported iterator returns a sentinel

use strict;
use warnings;

our $VERSION = '0.29';

use Iterator::Flex::Utils qw( :default REG_GENERAL REG_GP_INPUT_EXHAUSTION );

use Role::Tiny;
use experimental 'signatures';

use namespace::clean;









sub imported_sentinel ( $self ) {
    return $REGISTRY{ refaddr $self }[REG_GENERAL][REG_GP_INPUT_EXHAUSTION][1];
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

Iterator::Flex::Role::Exhaustion::ImportedReturn - Imported iterator returns a sentinel

=head1 VERSION

version 0.29

=head1 METHODS

=head2 imported_sentinel

  $sentinel = $iterator->sentinel

returns the sentinel which the iterator will return to signal exhaustion

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
