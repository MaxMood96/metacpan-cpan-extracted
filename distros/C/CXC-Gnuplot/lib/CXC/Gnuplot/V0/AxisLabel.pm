package CXC::Gnuplot::V0::AxisLabel;

use v5.38;
use experimental 'builtin';
use Feature::Compat::Class;

our $VERSION = 'v0.29.3';

class CXC::Gnuplot::V0::AxisLabel;

use builtin 'is_bool', 'false';

no namespace::clean;

use Ref::Util 'is_ref', 'is_plain_arrayref';

use namespace::clean;

use CXC::Gnuplot::V0::Types -lexical, 'is_Num', 'is_NonEmptyStr';
use CXC::Gnuplot::V0::Util -lexical, 'maybe_quote', 'assert_coerce_object', 'clone_object',
  'pvalidate', 'to_hash_r', 'render_opts';

my sub croak {
    require Carp;
    goto \&Carp::croak;
}


#<<< notidy
field $text       :param  :reader  = undef;
field $offset     :param  :reader  = undef;
field $font       :param  :reader  = undef;
field $textcolor  :param  :reader  = undef;
field $enhanced   :param  :reader  = undef;
field $rotate     :param  :reader  = undef;
#>>>





















ADJUST {

    pvalidate( offset => CoordOffset3D => \$offset );
    pvalidate( font   => Font          => \$font );

    pvalidate( textcolor => ColorSpec => \$textcolor );

    defined $enhanced
      and $enhanced = !!$enhanced;

    defined $rotate
      and $rotate ne 'norotate'
      and $rotate ne 'parallel'
      and !( is_bool( $rotate ) && !$rotate )
      and !is_Num( $rotate )
      and
      croak( '"rotate" must be a float or one of "parallel", "norotate", or the false boolean value' );

}





method to_hash {
    to_hash_r( {
        ( defined $text      ? ( text      => $text )      : () ),
        ( defined $offset    ? ( offset    => $offset )    : () ),
        ( defined $font      ? ( font      => $font )      : () ),
        ( defined $textcolor ? ( textcolor => $textcolor ) : () ),
        ( defined $enhanced  ? ( enhanced  => $enhanced )  : () ),
        ( defined $rotate    ? ( rotate    => $rotate )    : () ),
    } );
}





sub assert_coerce( $class, $args ) {
    assert_coerce_object( $class, $args );
}





method clone ( %args ) {
    return clone_object( $self, \%args );
}






sub coerce_attrs ( $class, @attrs ) {
    return @attrs == 1 && !is_ref( $attrs[0] )
      ? { text => $attrs[0] }
      : undef;
}





method opts {
    my @opts;

    defined $text
      and push @opts, maybe_quote( $text );

    push @opts, render_opts( offset => $offset );
    push @opts, render_opts( font   => $font );

    push @opts, render_opts( textcolor => $textcolor );

    defined $enhanced
      and push @opts, ( $enhanced ? 'enhanced' : 'noenhanced' );

    defined $rotate
      and push @opts,
      is_Num( $rotate )       ? [ 'rotate by' => $rotate ]
      : $rotate eq 'parallel' ? [ rotate => 'parallel' ]
      :                         'norotate';

    return @opts;
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

=for :stopwords Diab Jerius Smithsonian Astrophysical Observatory textcolor

=head1 NAME

CXC::Gnuplot::V0::AxisLabel

=head1 VERSION

version v0.29.3

=head1 OBJECT ATTRIBUTES

=head2 text

=head2 offset

=head2 font

=head2 textcolor

=head2 enhanced

=head2 rotate

=head1 CLASS METHODS

=head2 new

=head2 assert_coerce

=head2 coerce_attrs

=head1 METHODS

=head2 to_hash

=head2 clone

=head2 opts

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
