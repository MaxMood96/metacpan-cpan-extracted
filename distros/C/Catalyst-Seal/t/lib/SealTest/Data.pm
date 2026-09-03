package SealTest::Data;

use strict;
use warnings;

use Moose;
with 'Catalyst::ClassData';

# A class data value of every shape the sealed accessor has to return
# unchanged. The interesting ones are the falsy and absent values: the stock
# accessor distinguishes "defined in my own slot" from "walk the ISA", and a
# constant that gets that wrong is wrong quietly.

__PACKAGE__->mk_classdata('cd_string', 'a string');
__PACKAGE__->mk_classdata('cd_zero', 0);
__PACKAGE__->mk_classdata('cd_empty', '');
__PACKAGE__->mk_classdata('cd_undef');
__PACKAGE__->mk_classdata('cd_hash', { a => 1 });
__PACKAGE__->mk_classdata('cd_array', [1, 2, 3]);
__PACKAGE__->mk_classdata('cd_code', sub { 'called' });
__PACKAGE__->mk_classdata('cd_object', bless({}, 'SealTest::Data::Thing'));
__PACKAGE__->mk_classdata('cd_inherited', 'from the parent');
__PACKAGE__->mk_classdata('cd_writable', 'before');

sub attributes {
    return qw(cd_string cd_zero cd_empty cd_undef cd_hash cd_array
              cd_code cd_object cd_inherited cd_writable);
}

__PACKAGE__->meta->make_immutable;

1;
