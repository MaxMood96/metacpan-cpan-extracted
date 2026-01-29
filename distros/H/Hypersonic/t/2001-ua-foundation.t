use strict;
use warnings;
use Test::More;

use_ok('Hypersonic::UA');
use_ok('Hypersonic::UA::Socket');

subtest 'UA XS functions' => sub {
    my $funcs = Hypersonic::UA->get_xs_functions();
    ok(exists $funcs->{'Hypersonic::UA::parse_url'}, 'parse_url registered');
    ok(exists $funcs->{'Hypersonic::UA::build_request'}, 'build_request registered');
};

subtest 'Socket XS functions' => sub {
    my $funcs = Hypersonic::UA::Socket->get_xs_functions();
    ok(exists $funcs->{'Hypersonic::UA::Socket::connect_to_host'}, 'connect_to_host registered');
    ok(exists $funcs->{'Hypersonic::UA::Socket::connect_nonblocking'}, 'connect_nonblocking registered');
    ok(exists $funcs->{'Hypersonic::UA::Socket::check_connect'}, 'check_connect registered');
    ok(exists $funcs->{'Hypersonic::UA::Socket::send'}, 'send registered');
    ok(exists $funcs->{'Hypersonic::UA::Socket::send_nonblocking'}, 'send_nonblocking registered');
    ok(exists $funcs->{'Hypersonic::UA::Socket::recv'}, 'recv registered');
    ok(exists $funcs->{'Hypersonic::UA::Socket::recv_nonblocking'}, 'recv_nonblocking registered');
    ok(exists $funcs->{'Hypersonic::UA::Socket::recv_chunk'}, 'recv_chunk registered');
    ok(exists $funcs->{'Hypersonic::UA::Socket::wait_readable'}, 'wait_readable registered');
    ok(exists $funcs->{'Hypersonic::UA::Socket::close'}, 'close registered');
};

done_testing();
