#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Require;

use v5.14.4;
use warnings;

our $VERSION = '1.16.1'; # VERSION

use Carp;
require Rex::Logger;

# some code borrowed from: UNIVERSAL::require (neilb)

BEGIN { require UNIVERSAL; }

my $module_name_rx = qr/[A-Z_a-z][0-9A-Z_a-z]*(?:::[0-9A-Z_a-z]+)*/;

sub UNIVERSAL::require {
  my ( $module, %option ) = @_;

  $option{level} ||= 0;

  my ( $caller_package, $caller_file, $caller_line ) = caller( $option{level} );

  my $file = $module . ".pm";
  $file =~ s/::/\//g;

  # check if module is already loaded.
  return eval { 1 } if $INC{$file};

  my $ret = eval "CORE::require(\$file)";

  if ( !$ret ) {
    confess $@;
  }

  return $ret;
}

sub UNIVERSAL::use {
  my ( $module, @imports ) = @_;

  $module->require( level => 1 );

  my ( $caller_package, $caller_file, $caller_line ) = caller(0);

  eval "package $caller_package;\n\$module->import(\@imports);\n1;";

  if ($@) {
    confess $@;
  }

  return 1;
}

sub UNIVERSAL::is_loadable {
  my ($module) = @_;
  eval {
    $module->require;
    1;
  };

  if ($@) { return 0; }
  return 1;
}

1;
