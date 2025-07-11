#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Helper::File::Stat::Unix;

use v5.14.4;
use warnings;

our $VERSION = '1.16.1'; # VERSION

use Fcntl;

use Rex::Helper::Run;

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
  Fcntl::S_ISLNK(@_);
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
  Fcntl::S_ISSOCK(@_);
}

sub S_IMODE {
  shift;
  Fcntl::S_IMODE(@_);
}

1;
