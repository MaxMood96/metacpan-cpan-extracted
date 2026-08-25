package CXC::Gnuplot::V1::Role::Clone;

use v5.38;
use experimental 'builtin', 'declared_refs';
use Object::Pad 0.821;

our $VERSION = 'v0.29.3';

role CXC::Gnuplot::V1::Role::Clone;

method to_hash;

use builtin 'is_bool', 'true', 'blessed';
use Hash::Merge;

use Lexical::Import qw( Ref::Util is_plain_arrayref );

## no critic ( AmbiguousNames )

my $merger = do {
    my $obj = Hash::Merge->new;
    $obj->add_behavior_spec( {
            'SCALAR' => {
                'SCALAR' => sub { $_[1] },
                'ARRAY'  => sub { $_[1] },
                'HASH'   => sub { $_[1] },
            },
            'ARRAY' => {
                'SCALAR' => sub { $_[1] },
                'ARRAY'  => sub { $_[1] },
                'HASH'   => sub { $_[1] },
            },
            'HASH' => {
                'SCALAR' => sub { $_[1] },
                'ARRAY'  => sub { $_[1] },
                'HASH'   => sub ( $left, $right ) {
                    my \%left  = $left;
                    my \%right = $right;

                    # delete the specified entries from $left
                    if ( defined( my $delete = delete $right{-delete} ) ) {
                        # delete everything
                        if ( is_bool( $delete ) ) {
                            %left = () if $delete;
                        }
                        else {
                            # delete specific keys
                            delete @left{ is_plain_arrayref( $delete ) ? $delete->@* : $delete };
                        }
                    }

                    if ( defined( my $overwrite = delete $right{-overwrite} ) ) {

                        # overwrite keys in $left with keys in $right
                        # removing them from %right so they can't be merged
                        my @keys
                          = is_bool( $overwrite )           ? ( $overwrite ? keys %right : () )
                          : is_plain_arrayref( $overwrite ) ? $overwrite->@*
                          :                                   ( $overwrite );
                        @left{@keys} = delete @right{@keys};
                    }


                    return \%left unless keys %right;

                    # merge what's left
                    # _merge_hashes is part of the public API
                    ## no critic ( Subroutines::ProtectPrivateSubs )
                    Hash::Merge::_merge_hashes( \%left, \%right );
                },
            },
        },
        __PACKAGE__,
    );
    # this is on by default, but let's make it explicit
    $obj->set_clone_behavior( true );
    $obj;
};





method clone ( %new ) {
    my $class = blessed( $self );
    my \%old  = $self->to_hash;
    my \%attr = $merger->merge( \%old, \%new );
    return $class->new( %attr );
}


1;

#
# This file is part of CXC-Gnuplot
#
# This software is Copyright (c) 2024 by Smithsonian Astrophysical Observatory.
#
# This is free software, licensed under:
#
#   The GNU General Public License, Version 3, June 2007
#

__END__

=pod

=for :stopwords Diab Jerius Smithsonian Astrophysical Observatory

=head1 NAME

CXC::Gnuplot::V1::Role::Clone

=head1 VERSION

version v0.29.3

=head1 METHODS

=head2 clone

=head1 INTERNALS

=for Pod::Coverage DOES
META
new

=head1 SUPPORT

=head2 Bugs

Please report any bugs or feature requests to bug-cxc-gnuplot@rt.cpan.org  or through the web interface at: L<https://rt.cpan.org/Public/Dist/Display.html?Name=CXC-Gnuplot>

=head2 Source

Source is available at

  https://codeberg.org/CXC-Optics/p5-CXC-Gnuplot

and may be cloned from

  https://codeberg.org/CXC-Optics/p5-CXC-Gnuplot.git

=head1 SEE ALSO

Please see those modules/websites for more information related to this module.

=over 4

=item *

L<CXC::Gnuplot|CXC::Gnuplot>

=back

=head1 AUTHOR

Diab Jerius <djerius@cfa.harvard.edu>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2024 by Smithsonian Astrophysical Observatory.

This is free software, licensed under:

  The GNU General Public License, Version 3, June 2007

=cut
