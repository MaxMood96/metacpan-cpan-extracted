package CXC::Gnuplot::V1::TerminalBase;

use v5.38;
use Object::Pad 0.821;

our $VERSION = 'v0.29.3';

class CXC::Gnuplot::V1::TerminalBase : isa(CXC::Gnuplot::V1::Base)
  does( CXC::Gnuplot::V1::Role::Clone );

use experimental 'builtin', 'declared_refs';
use builtin::compat 'load_module', 'true';

use CXC::Gnuplot::V1::Types -lexical => 'signature_for', 'SetFormats';
use CXC::Gnuplot::V1::Util -lexical => 'render_opts',    'render_set';

my sub croak {
    require Carp;
    goto \&Carp::croak;
}

## no critic(Subroutines::ProtectPrivateSubs)
#<<< no tidy
field $size  :param  :reader //= q{};
field $ext   :param  :reader  = __CLASS__->_DEFAULT_EXT;
#>>>







# virtual class
ADJUST {
    if ( __CLASS__ eq __PACKAGE__ ) {
        require Carp;
        Carp::croak( "can't instantiate @{[__CLASS__]}" );
    }
}





















sub _DEFAULT_EXT ( $class ) {

    state %ext = (
        cairolatex => '.tex',
        canvas     => '.js',
        context    => '.tex',
        dxf        => '.dxf',
        emf        => '.emf',
        epscairo   => '.eps',
        epslatex   => '.tex',
        fig        => '.fig',
        gif        => '.gif',
        jpeg       => '.jpg',
        pbm        => '.pbm',
        pcl5       => '.pcl',
        pdfcairo   => '.pdf',
        pict2e     => '.tex',
        pngcairo   => '.png',
        postscript => '.ps',
        pslatex    => '.tex',
        pstricks   => '.tex',
        svg        => '.svg',
        texdraw    => '.tex',
        tikz       => '.tex',
        webp       => '.webp',
    );

    my ( $term ) = $class =~ /([^:]+)$/;
    return $ext{$term} // q{};
}








method to_hash {
    return {
        ( defined $size ? ( size => $size ) : () ),    #
        ( defined $ext  ? ( ext  => $ext )  : () ),
    };
}






method opts {
    return $self->terminal, ( length( $size ) ? [ size => $size ] : () );
}





signature_for set => (
    method => 1,
    named  => [
        as => SetFormats,
        { default => 'string' },
    ],
);

method set ( $opt ) {
    return render_set( [ render_opts( [ set => 'terminal' ], $self ) ], $opt->as );
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

CXC::Gnuplot::V1::TerminalBase

=head1 VERSION

version v0.29.3

=head1 OBJECT ATTRIBUTES

=head2 size

=head2 ext

=head1 CONSTRUCTORS

=head2 new

  $object = $class->new( @args )

Construct an object from the supplied arguments.

Arguments may be supplied as a name/value list or as a single plain hash reference.

=head1 METHODS

=head2 to_hash

Returns a hashref whose contents can be passed to the constructor to
generate a duplicate of the object.

=head2 opts

=head2 set

=head1 INTERNALS

=for Pod::Coverage META
DOES
BUILDARGS
clone

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
