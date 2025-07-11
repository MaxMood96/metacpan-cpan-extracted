#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Inventory::DMIDecode::Memory;

use v5.14.4;
use warnings;

our $VERSION = '1.16.1'; # VERSION

use Rex::Inventory::DMIDecode::Section;
use base qw(Rex::Inventory::DMIDecode::Section);

__PACKAGE__->section("Memory Device");

__PACKAGE__->has(
  [
    'Part Number', 'Serial Number', 'Type',         'Speed',
    'Size',        'Manufacturer',  'Bank Locator', 'Form Factor',
    'Locator',
  ],
  1
); # is_array 1

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $that->SUPER::new(@_);

  bless( $self, $proto );

  return $self;
}

sub get {

  my ( $self, $key, $is_array ) = @_;
  if ( $key eq "Type" ) {
    my $ret = $self->_search_for( $key, $is_array );
    if ( $ret eq "<OUT OF SPEC>" ) {
      return "";
    }

    return $ret;
  }

  return $self->SUPER::get( $key, $is_array );

}

1;
