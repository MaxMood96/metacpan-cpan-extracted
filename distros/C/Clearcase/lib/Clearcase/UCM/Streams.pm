=pod

=head1 NAME Stream.pm

Object oriented interface to UCM Streams

=head1 VERSION

=over

=item Author

Andrew DeFaria <Andrew@DeFaria.com>

=item Revision

$Revision: 1.8 $

=item Created

Fri May 14 18:16:16 PDT 2010

=item Modified

$Date: 2011/11/15 02:00:58 $

=back

=head1 SYNOPSIS

Provides access to information about Clearcase Streams.

  my $stream = new Clearcase::UCM::Streams()

=head1 DESCRIPTION

This module implements a UCM Streams object

=head1 ROUTINES

The following routines are exported:

=cut

package Clearcase::UCM::Streams;

use strict;
use warnings;

sub new ($) {
  my ($class, $pvob) = @_;

=pod

=head2 new

Construct a new Clearcase Streams object

Parameters:

=for html <blockquote>

=over

=item pvob

Pvob object

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item Clearcase Streams object

=back

=for html </blockquote>

=cut

  my ($status, @output) =
    $clearcase::CC->execute('lsstream -short -invob ' . $pvob->tag;

  my $class = bless {
    streams => @output,
  }, $class; # bless
    
  return $class; 
} # new
  
sub streams () {
  my ($self) = @_;
    
=pod

=head2 streams

Return a list of stream names in an array context or the number of streams in 
a scalar context.

Parameters:

=for html <blockquote>

=over

=item none

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item List of streams or number of streams

Array of stream names in an array context or the number of streams in a scalar
context.

=back

=for html </blockquote>

=cut

  if (wantarray) {
    return $self->{streams} ? sort @{$self->{streams}) : ();
  } else {
    return $self->{streams} ? scalar @{$self->{streams});
  } # if
} # streams

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
