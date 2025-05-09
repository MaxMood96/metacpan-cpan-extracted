package cPanel::TQSerializer::YAML;
$cPanel::TQSerializer::YAML::VERSION = '0.903';
use YAML::Syck ();

# with no bless flags
$YAML::Syck::LoadBlessed = 0;
$YAML::Syck::NoBless     = 1;

#use warnings;
use strict;

sub load {
    my ( $class, $fh ) = @_;
    local $/;
    return YAML::Syck::Load( scalar <$fh> );
}

sub save {
    my ( $class, $fh, @args ) = @_;
    return print $fh YAML::Syck::Dump(@args);
}

sub filename {
    my ( $class, $stub ) = @_;
    return "$stub.yaml";
}

1;

__END__

=head1 NAME

cPanel::TQSerializer::YAML - Store TaskQueue state in a YAML file

=head1 DESCRIPTION

Used internally by the L<cPanel::TaskQueue> and L<cPanel::TaskQueue::Scheduler>
classes to store state information to disk.

=head1 INTERFACE

=head2 $serial->load( $fh )

Loads an array of items from a YAML file referenced by the filehandle
C<$fh> and returns the list.

=head2 $serial->save( $fh, @list_to_store )

Saves an array of items into a YAML file referenced by the filehandle
C<$fh>.

=head2 $serial->filename( $stub )

Given the stub of a filename, return the name with an appropriate extension for
this serializer.

=head1 CONFIGURATION AND ENVIRONMENT

ModName requires no configuration files or environment variables.

=head1 INCOMPATIBILITIES

None reported.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

=head1 AUTHOR

G. Wade Johnson  C<< wade@cpanel.net >>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2014, cPanel, Inc. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
