#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Constants;

use v5.14.4;
use warnings;

our $VERSION = '1.16.1'; # VERSION

require Rex::Exporter;
use base qw(Rex::Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(present absent latest running started stopped);

sub present { return "present"; }
sub absent  { return "absent"; }
sub latest  { return "latest"; }
sub running { return "running"; }
sub started { return "started"; }
sub stopped { return "stopped"; }

1;
