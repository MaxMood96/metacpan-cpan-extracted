#=======================================================================
#    ____  ____  _____              _    ____ ___   ____
#   |  _ \|  _ \|  ___|  _   _     / \  |  _ \_ _| |___ \
#   | |_) | | | | |_    (_) (_)   / _ \ | |_) | |    __) |
#   |  __/| |_| |  _|    _   _   / ___ \|  __/| |   / __/
#   |_|   |____/|_|     (_) (_) /_/   \_\_|  |___| |_____|
#
#   A Perl Module Chain to faciliate the Creation and Modification
#   of High-Quality "Portable Document Format (PDF)" Files.
#
#   Copyright 1999-2005 Alfred Reibenschuh <areibens@cpan.org>.
#
#=======================================================================
#
#   This library is free software; you can redistribute it and/or
#   modify it under the terms of the GNU Lesser General Public
#   License as published by the Free Software Foundation; either
#   version 2 of the License, or (at your option) any later version.
#
#   This library is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#   Lesser General Public License for more details.
#
#   You should have received a copy of the GNU Lesser General Public
#   License along with this library; if not, write to the
#   Free Software Foundation, Inc., 59 Temple Place - Suite 330,
#   Boston, MA 02111-1307, USA.
#
#   $Id: Hue.pm,v 2.0 2005/11/16 02:18:14 areibens Exp $
#
#=======================================================================

package PDF::API3::Compat::API2::Resource::ColorSpace::Indexed::Hue;

BEGIN {

    use strict;
    use PDF::API3::Compat::API2::Resource::ColorSpace::Indexed;
    use PDF::API3::Compat::API2::Basic::PDF::Utils;
    use PDF::API3::Compat::API2::Util;
    use POSIX;

    use vars qw(@ISA $VERSION);

    @ISA = qw( PDF::API3::Compat::API2::Resource::ColorSpace::Indexed );

    ( $VERSION ) = sprintf '%i.%03i', split(/\./,('$Revision: 2.0 $' =~ /Revision: (\S+)\s/)[0]); # $Date: 2005/11/16 02:18:14 $

}
no warnings qw[ deprecated recursion uninitialized ];

=item $cs = PDF::API3::Compat::API2::Resource::ColorSpace::Indexed::Hue->new $pdf

Returns a new colorspace object created based on various hues.

=cut

sub new {
    my ($class,$pdf)=@_;

    $class = ref $class if ref $class;
    $self=$class->SUPER::new($pdf,pdfkey());
    $pdf->new_obj($self) unless($self->is_obj($pdf));
    $self->{' apipdf'}=$pdf;
    my $csd=PDFDict();
    $pdf->new_obj($csd);
    $csd->{Filter}=PDFArray(PDFName('FlateDecode'));

    ## $csd->{WhitePoint}=PDFArray(map { PDFNum($_) } (0.95049, 1, 1.08897));
    ## $csd->{BlackPoint}=PDFArray(map { PDFNum($_) } (0, 0, 0));
    ## $csd->{Gamma}=PDFArray(map { PDFNum($_) } (2.22218, 2.22218, 2.22218));

    $csd->{' stream'}='';

    my %cc=();

    foreach my $s (4,3,2,1) {
        foreach my $v (4,3) {
            foreach my $r (0..31) {
                $csd->{' stream'}.=pack('CCC',map { $_*255 } namecolor('!'.sprintf('%02X',$r*255/31).sprintf('%02X',$s*255/4).sprintf('%02X',$v*255/4)));
            }
        }
    }

    $csd->{' stream'}.="\x00" x 768;
    $csd->{' stream'}=substr($csd->{' stream'},0,768);

    $self->add_elements(PDFName('DeviceRGB'),PDFNum(255),$csd);
    $self->{' csd'}=$csd;

    return($self);
}

=item $cs = PDF::API3::Compat::API2::Resource::ColorSpace::Indexed->new_api $api, $name

Returns a indexed color-space object. This method is different from 'new' that
it needs an PDF::API3::Compat::API2-object rather than a Text::PDF::File-object.

=cut

sub new_api {
    my ($class,$api,@opts)=@_;

    my $obj=$class->new($api->{pdf},@opts);
    $self->{' api'}=$api;

    return($obj);
}

1;

__END__

=head1 AUTHOR

alfred reibenschuh

=head1 HISTORY

    $Log: Hue.pm,v $
    Revision 2.0  2005/11/16 02:18:14  areibens
    revision workaround for SF cvs import not to screw up CPAN

    Revision 1.2  2005/11/16 01:27:50  areibens
    genesis2

    Revision 1.1  2005/11/16 01:19:27  areibens
    genesis

    Revision 1.9  2005/06/17 19:44:03  fredo
    fixed CPAN modulefile versioning (again)

    Revision 1.8  2005/06/17 18:53:34  fredo
    fixed CPAN modulefile versioning (dislikes cvs)

    Revision 1.7  2005/03/14 22:01:27  fredo
    upd 2005

    Revision 1.6  2004/12/16 00:30:54  fredo
    added no warn for recursion

    Revision 1.5  2004/06/15 09:14:52  fredo
    removed cr+lf

    Revision 1.4  2004/06/07 19:44:43  fredo
    cleaned out cr+lf for lf

    Revision 1.3  2003/12/08 13:06:01  Administrator
    corrected to proper licencing statement

    Revision 1.2  2003/11/30 17:32:48  Administrator
    merged into default

    Revision 1.1.1.1.2.2  2003/11/30 16:57:03  Administrator
    merged into default

    Revision 1.1.1.1.2.1  2003/11/30 14:31:36  Administrator
    added CVS id/log


=cut
