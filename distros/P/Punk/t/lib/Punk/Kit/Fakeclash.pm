package Punk::Kit::Fakeclash;

# t/1311: a kit whose option is one `new` already declares. Whichever of the
# two Getopt bound would decide what the command does, so it is refused rather
# than ordered.

use strict;
use warnings;
use parent 'Punk::Generate';

sub options { return ( { spec => 'force', doc => 'clashes on purpose' } ) }

1;
