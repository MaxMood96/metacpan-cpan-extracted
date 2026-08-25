package My::Test;

use Test2::V0;
use Test::File::ShareDir -share => { -dist => { 'CXC-Gnuplot' => 'share' } };

use experimental;
use Data::Dump;

use Import::Into;

sub import {
    my $caller = caller;
    Test2::V0->import::into( $caller );
    experimental->import::into( $caller, 'builtin', 'declared_refs', 'signatures', 'for_list' );
    builtin->import::into( $caller, 'true', 'false' );
    Data::Dump->import::into( $caller, 'pp', 'dd' );
}
1;
