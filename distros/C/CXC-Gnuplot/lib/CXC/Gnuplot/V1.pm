package CXC::Gnuplot::V1;

# ABSTRACT: Map Gnuplot concepts and subsystems onto Perl

use v5.38;
our $VERSION = 'v0.29.3';

use Feature::Compat::Class;

class CXC::Gnuplot::V0;

use experimental 'builtin';
use builtin::compat 'is_bool', 'true';

use CXC::Gnuplot::V1::Util -lexical => 'clone_object', 'pvalidate', 'flatten_array';

my sub croak {
    require Carp;
    goto \&Carp::croak;
}

#<<< no tidy
field $xaxis     :param  :reader  = undef;
field $x2axis    :param  :reader  = undef;
field $yaxis     :param  :reader  = undef;
field $y2axis    :param  :reader  = undef;
field $key       :param  :reader  = undef;
field $terminal  :param  :reader  = undef;
field $title     :param  :reader  = undef;
field $margin    :param  :reader  = undef;
field $timestamp :param  :reader  = undef;
#>>>






























ADJUST {

    pvalidate( xaxis  => Axis => \$xaxis );
    pvalidate( yaxis  => Axis => \$yaxis );
    pvalidate( x2axis => Axis => \$x2axis );
    pvalidate( y2axis => Axis => \$y2axis );

    $key = { on => $key } if is_bool( $key );
    pvalidate( key       => Key       => \$key );
    pvalidate( terminal  => Terminal  => \$terminal );
    pvalidate( title     => Title     => \$title );
    pvalidate( margin    => Margin    => \$margin );
    pvalidate( timestamp => Timestamp => \$timestamp );
}






method to_hash {

    return {
        ( defined $key       ? ( key       => $key )       : () ),
        ( defined $margin    ? ( margin    => $margin )    : () ),
        ( defined $terminal  ? ( terminal  => $terminal )  : () ),
        ( defined $title     ? ( title     => $title )     : () ),
        ( defined $x2axis    ? ( x2axis    => $x2axis )    : () ),
        ( defined $xaxis     ? ( xaxis     => $xaxis )     : () ),
        ( defined $y2axis    ? ( y2axis    => $y2axis )    : () ),
        ( defined $yaxis     ? ( yaxis     => $yaxis )     : () ),
        ( defined $timestamp ? ( timestamp => $timestamp ) : () ),
    };

}






method clone ( %args ) {
    clone_object( $self, \%args );
}





method set ( %opts ) {

    my @args;

    push @args, $terminal->set
      if defined $terminal;

    push @args, $xaxis->set( 'x', %opts )
      if defined $xaxis;

    push @args, $yaxis->set( 'y', %opts )
      if defined $yaxis;

    push @args, $x2axis->set( 'x2', %opts )
      if defined $x2axis;

    push @args, $y2axis->set( 'y2', %opts )
      if defined $y2axis;

    push @args, $title->set( %opts )
      if defined $title;

    push @args, $key->set( %opts )
      if defined $key;

    push @args, $margin->set( %opts )
      if defined $margin;

    push @args, $timestamp->set( %opts )
      if defined $timestamp;

    return @args;
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

=for :stopwords Diab Jerius Smithsonian Astrophysical Observatory xaxis yaxis

=head1 NAME

CXC::Gnuplot::V1 - Map Gnuplot concepts and subsystems onto Perl

=head1 VERSION

version v0.29.3

=head1 SYNOPSIS

=head1 OBJECT ATTRIBUTES

=head2 xaxis

=head2 yaxis

=head2 x2axis

=head2 y2axis

=head2 key

=head2 terminal

=head2 title

=head2 margin

=head2 timestamp

=head1 CLASS METHODS

=head2 new

=head1 METHODS

=head2 to_hash

=head2 clone

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
