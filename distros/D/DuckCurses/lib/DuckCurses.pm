package DuckCurses;

use 5.032000;
use strict;
use warnings;

require Exporter;
use AutoLoader qw(AUTOLOAD);

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use DuckCurses ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.1.4';


# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!
=head1 NAME
  
DuckCurses - Duck Tales game using curses library

=head1 SYNOPSIS

  use DuckCurses;

  init DuckCursesMain.pm to play it.

=head1 DESCRIPTION

Dagobert Duck jumping around on his (pogo)stick killing baddies :-)

=head2 EXPORT

=head1 SEE ALSO

=head1 AUTHOR

Kobold Wizard Johan, E<lt>koboldwiz@yahoo.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2021 by Kobold Wizard Johan

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.32.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
