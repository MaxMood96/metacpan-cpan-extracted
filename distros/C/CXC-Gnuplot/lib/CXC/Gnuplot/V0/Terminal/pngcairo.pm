package CXC::Gnuplot::V0::Terminal::pngcairo;

use v5.38;
use Feature::Compat::Class;
use experimental 'builtin';

our $VERSION = 'v0.29.3';

class CXC::Gnuplot::V0::Terminal::pngcairo : isa(CXC::Gnuplot::V0::Terminal::cairo);

use CXC::Gnuplot::V0::Types -lexical, qw( PositiveNum  );
use CXC::Gnuplot::V0::Util -lexical => 'clone_object', 'pvalidate', 'to_hash_r';

use builtin 'is_bool';

#<<< no tidy
field $transparent  :param  :reader  = undef;
field $crop         :param  :reader  = undef;
field $pointscale   :param  :reader  = undef;
#>>>



















sub terminal { 'pngcairo' }

use constant _DEFAULT_EXT => '.png';

ADJUST {

    defined $transparent
      and !is_bool( $transparent )
      and croak( q{invalid value for "transparent" parameter: must be bool} );

    defined $crop
      and !is_bool( $crop )
      and croak( q{invalid value for "crop" parameter: must be bool} );

    pvalidate( pointscale => PositiveNum, \$pointscale );
}





method to_hash {

    to_hash_r( {
        $self->SUPER::to_hash->%*,
        ( defined $transparent ? ( transparent => $transparent ) : () ),
        ( defined $crop        ? ( crop        => $crop )        : () ),
        ( defined $pointscale  ? ( pointscale  => $pointscale )  : () ),
    } );

}





method opts {

    return (
        $self->SUPER::opts,
        ( defined $transparent ? $transparent ? 'transparent' : 'notransparent' : () ),
        ( defined $crop        ? $crop        ? 'crop'        : 'nocrop'        : () ),
        ( defined $pointscale  ? [ pointscale => $pointscale ] : () ),
    );

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

=for :stopwords Diab Jerius Smithsonian Astrophysical Observatory pointscale

=head1 NAME

CXC::Gnuplot::V0::Terminal::pngcairo

=head1 VERSION

version v0.29.3

=head1 OBJECT ATTRIBUTES

=head2 transparent

=head2 crop

=head2 pointscale

=head1 CLASS METHODS

=head2 new

=head1 METHODS

=head2 to_hash

=head2 opts

=head1 SUBROUTINES

=head2 terminal

=head1 INTERNALS

=for Pod::Coverage META
DOES

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
