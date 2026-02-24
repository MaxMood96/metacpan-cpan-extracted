use strict;
use warnings;

use Test2::Require::Module 'DBI';
use Test2::Require::Module 'DBD::SQLite';

use Test2::Tools::QuickDB;
skipall_unless_can_db(driver => 'SQLite');

{
    no warnings 'once';
    $main::PROTOCOL = 'SQLite';
}

do './t/generic_test.pl' or die $@;
