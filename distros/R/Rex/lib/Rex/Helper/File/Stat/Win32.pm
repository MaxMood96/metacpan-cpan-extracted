#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Helper::File::Stat::Win32;

use v5.14.4;
use warnings;

our $VERSION = '1.16.1'; # VERSION

use Fcntl;

use Rex::Interface::Exec;

sub S_ISDIR {
  shift;
  Fcntl::S_ISDIR(@_);
}

sub S_ISREG {
  shift;
  Fcntl::S_ISREG(@_);
}

sub S_ISLNK {
  shift;
  if ( Rex::is_ssh() ) {
    my $exec = Rex::Interface::Exec->create;
    $exec->exec("perl -le 'use Fcntl; exit Fcntl::S_ISLNK($_[0])'");
    return $?;
  }
  else {
    Rex::Logger::info( "S_ISLNK not supported on your platform.", "warn" );
    return 0;
  }
}

sub S_ISBLK {
  shift;
  Fcntl::S_ISBLK(@_);
}

sub S_ISCHR {
  shift;
  Fcntl::S_ISCHR(@_);
}

sub S_ISFIFO {
  shift;
  Fcntl::S_ISFIFO(@_);
}

sub S_ISSOCK {
  shift;

  if ( Rex::is_ssh() ) {
    my $exec = Rex::Interface::Exec->create;
    $exec->exec("perl -le 'use Fcntl; exit Fcntl::S_ISSOCK($_[0])'");
    return $?;
  }
  else {
    Rex::Logger::info( "S_ISSOCK not supported on your platform.", "warn" );
    return 0;
  }
}

sub S_IMODE {
  shift;
  Fcntl::S_IMODE(@_);
}

1;
