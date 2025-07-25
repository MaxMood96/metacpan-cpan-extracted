#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Exporter;

use v5.14.4;
use warnings;
use Symbol;

our $VERSION = '1.16.1'; # VERSION

use Data::Dumper;

our @EXPORT;

sub import {
  my ( $mod_to_register, %option ) = @_;
  my ( $mod_to_register_in, $file, $line ) = caller;

  if ( exists $option{register_in} && $option{register_in} ) {
    $mod_to_register_in = $option{register_in};
  }

  my $no_import = "";
  if ( exists $option{"-no"} && $option{"-no"} ) {
    $no_import = "," . join( ",", @{ $option{"-no"} } ) . ",";
  }

  my $ref_to_export       = qualify_to_ref( 'EXPORT', $mod_to_register );
  my $ref_to_export_array = *{$ref_to_export}{ARRAY};

  for my $reg_func ( @{$ref_to_export_array} ) {
    if ( $no_import =~ m/,$reg_func,/ ) {
      next;
    }

    my $ref_to_reg_func_in_source_mod =
      qualify_to_ref( $reg_func, $mod_to_register );
    my $ref_to_reg_func_in_target_mod =
      qualify_to_ref( $reg_func, $mod_to_register_in );

    *{$ref_to_reg_func_in_target_mod} = *{$ref_to_reg_func_in_source_mod};
  }
}

1;
