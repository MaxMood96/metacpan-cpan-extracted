package MooX::Cmd::ChainedOptions::Base;

# ABSTRACT: anchor role for chained option roles

use Moo::Role;
use Scalar::Util qw[ blessed ];

use namespace::clean;

our $VERSION = '0.04';

has _parent => (
    is       => 'lazy',
    init_arg => undef,
    builder  => sub {

        my $class = blessed $_[0];

        # Find the element in command chain array which directly
        # precedes the element containing the current class.

        # There is a single array used for the command chain, and it
        # is populated by MooX::Cmd as it processes the command line.
        # This builder may be called for a class after MooX::Cmd has
        # added entries for the class' subcommands, so we can't simply
        # assume that the last element in the array is for this class.

        my $last;
        for ( reverse @{ $_[0]->command_chain } ) {
            next unless $last;
            return $_ if blessed $last eq $class;
        }
        continue { $last = $_ }

        require Carp;
        Carp::croak( "unable to determine parent in chain hierarchy\n" );
    },
);

1;

#
# This file is part of MooX-Cmd-ChainedOptions
#
# This software is Copyright (c) 2017 by Smithsonian Astrophysical Observatory.
#
# This is free software, licensed under:
#
#   The GNU General Public License, Version 3, June 2007
#

=pod

=head1 NAME

MooX::Cmd::ChainedOptions::Base - anchor role for chained option roles

=head1 VERSION

version 0.04

=head1 DESCRIPTION

This role provides the basis for the per-command roles generated by
L<MooX::Cmd::ChanedOptions::Role>.  It provides the C<_parent>
attribute which handles options further up the command chain.

=head1 BUGS AND LIMITATIONS

You can make new bug reports, and view existing ones, through the
web interface at L<https://rt.cpan.org/Public/Dist/Display.html?Name=MooX-Cmd-ChainedOptions>.

=head1 SEE ALSO

Please see those modules/websites for more information related to this module.

=over 4

=item *

L<MooX::Cmd::ChainedOptions|MooX::Cmd::ChainedOptions>

=back

=head1 AUTHOR

Diab Jerius <djerius@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2017 by Smithsonian Astrophysical Observatory.

This is free software, licensed under:

  The GNU General Public License, Version 3, June 2007

=cut

__END__

#pod =head1 DESCRIPTION
#pod
#pod This role provides the basis for the per-command roles generated by
#pod L<MooX::Cmd::ChanedOptions::Role>.  It provides the C<_parent>
#pod attribute which handles options further up the command chain.
