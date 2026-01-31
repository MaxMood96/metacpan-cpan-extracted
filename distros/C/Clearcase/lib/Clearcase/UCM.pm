
=pod

=head1 NAME UCM.pm

Object oriented interface to UCM Streams

=head1 VERSION

=over

=item Author

Andrew DeFaria <Andrew@DeFaria.com>

=item Revision

$Revision: 1.2 $

=item Created

Fri May 14 18:16:16 PDT 2010

=item Modified

$Date: 2011/11/16 19:46:13 $

=back

=head1 SYNOPSIS

Provides access to information about Clearcase Elements.

  my $stream= new Clearcase::UCM::Stream ($name, $pvob);

=head1 DESCRIPTION

This module implements a UCM Stream object

=head1 ROUTINES

The following routines are exported:

=cut

package Clearcase::UCM;

use strict;
use warnings;

use Clearcase;
use Clearcase::Vob;
use Clearcase::Vobs;

sub new ($) {
  my ($class, $stream) = @_;

=pod

=head2 new

Construct a new Clearcase Stream object.

Parameters:

=for html <blockquote>

=over

=item stream name

Name of stream

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item Clearcase Stream object

=back

=for html </blockquote>

=cut

  return bless {}, $class;    # bless
}    # new

sub pvobs () {
  my ($self) = @_;

=pod

=head2 pvob

Returns the pvob of the stream

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item stream's pvob

=back

=for html </blockquote>

=cut

  my @pvobs;

  my $VOBs = Clearcase::Vobs->new;

  foreach my $vobtag ($VOBs->vobs) {
    my $VOB  = Clearcase::Vob->new ("$Clearcase::VOBTAG_PREFIX$vobtag");
    my $attr = $VOB->vob_registry_attributes;

    if ($attr and $attr =~ /ucmvob/) {
      push @pvobs, $vobtag;
    }    # if
  }    # foreach

  return @pvobs;
}    # pvobs

1;

=head1 DEPENDENCIES

=head2 Modules

=over

=item L<Clearcase|Clearcase>

=back

=head1 INCOMPATABILITIES

None

=head1 BUGS AND LIMITATIONS

There are no known bugs in this module.

Please report problems to Andrew DeFaria <Andrew@DeFaria.com>.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2020 by Andrew@DeFaria.com

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.38.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
