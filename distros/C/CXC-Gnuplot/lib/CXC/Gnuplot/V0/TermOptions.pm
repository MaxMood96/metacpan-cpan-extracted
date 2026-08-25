package CXC::Gnuplot::V0::TermOptions;

use v5.38;
use Feature::Compat::Class;
use experimental 'builtin', 'declared_refs';

our $VERSION = 'v0.29.3';

class CXC::Gnuplot::V0::TermOptions;

use CXC::Gnuplot::V0::Util
  -lexical => 'assert_coerce_object',
  'clone_object', 'pvalidate', 'render_opts', 'render_set';
use CXC::Gnuplot::V0::Types -lexical, qw( PositiveNum SetFormats signature_for );
use builtin::compat 'blessed', 'is_bool', 'true';

my sub croak {
    require Carp;
    goto \&Carp::croak;
}

#<<< no tidy
field $enhanced    :param  :reader = undef;
field $font        :param  :reader = undef;
field $fontscale   :param  :reader = undef;
field $linewidth   :param  :reader = undef;
field $dashlength  :param  :reader = undef;
field $pointscale  :param  :reader = undef;
#>>>






















ADJUST {
    defined $enhanced
      and !is_bool( $enhanced )
      and croak( q{invalid value for "enhanced" parameter: must be bool} );

    pvalidate( font       => Font => \$font );
    pvalidate( fontscale  => PositiveNum, \$fontscale );
    pvalidate( linewidth  => PositiveNum, \$linewidth );
    pvalidate( dashlength => PositiveNum, \$dashlength );
    pvalidate( pointscale => PositiveNum, \$pointscale );
}






method to_hash {
    return {
        ( defined $enhanced   ? ( enhanced   => $enhanced )   : () ),
        ( defined $font       ? ( font       => $font )       : () ),
        ( defined $fontscale  ? ( fontscale  => $fontscale )  : () ),
        ( defined $linewidth  ? ( linewidth  => $linewidth )  : () ),
        ( defined $dashlength ? ( dashlength => $dashlength ) : () ),
        ( defined $pointscale ? ( pointscale => $pointscale ) : () ),
    };
}





method clone ( %args ) {
    return clone_object( $self, \%args );
}






sub assert_coerce ( $class, $args ) {
    assert_coerce_object( $class, $args );
}

my sub set_attr ( $label, $value, $set_opts = {} ) {
    my \%set_opts = $set_opts;
    return () unless defined $value;
    return blessed( $value )
      ? $value->set( %set_opts )
      : [ set => termoption => $label => $value ];
}





signature_for set => (
    method => 1,
    named  => [
        as => SetFormats,
        { default => 'string' },
    ],
);

method set ( $opt ) {
    ## no critic(NamingConventions::ProhibitAmbiguousNames)

    my %format = ( as => $opt->as );

    ## no critic (NamingConventions::ProhibitAmbiguousNames)
    my @set;

    defined $enhanced
      and push @set, [ set => termoption => $enhanced ? 'enhanced' : 'noenhanced' ];

    push @set,
      set_attr( fontscale  => $fontscale,  \%format ),
      set_attr( linewidth  => $linewidth,  \%format ),
      set_attr( dashlength => $dashlength, \%format ),
      set_attr( pointscale => $pointscale, \%format ),
      ;

    push @set, render_opts( [qw( set termoption font )], $font );

    return render_set( \@set, $opt->as );
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

=for :stopwords Diab Jerius Smithsonian Astrophysical Observatory dashlength fontscale
linewidth pointscale

=head1 NAME

CXC::Gnuplot::V0::TermOptions

=head1 VERSION

version v0.29.3

=head1 OBJECT ATTRIBUTES

=head2 enhanced

=head2 font

=head2 fontscale

=head2 linewidth

=head2 dashlength

=head2 pointscale

=head1 CLASS METHODS

=head2 new

=head2 assert_coerce

=head1 METHODS

=head2 to_hash

=head2 clone

=head2 set

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
