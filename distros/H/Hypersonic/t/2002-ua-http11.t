use strict;
use warnings;
use Test::More;

use_ok('Hypersonic::UA::Protocol::HTTP1');

subtest 'XS functions registered' => sub {
    my $funcs = Hypersonic::UA::Protocol::HTTP1->get_xs_functions();
    ok(exists $funcs->{'Hypersonic::UA::Protocol::HTTP1::build_request'}, 'build_request');
    ok(exists $funcs->{'Hypersonic::UA::Protocol::HTTP1::parse_response'}, 'parse_response');
    ok(exists $funcs->{'Hypersonic::UA::Protocol::HTTP1::parse_status_line'}, 'parse_status_line');
    ok(exists $funcs->{'Hypersonic::UA::Protocol::HTTP1::parse_headers'}, 'parse_headers');
    ok(exists $funcs->{'Hypersonic::UA::Protocol::HTTP1::find_body_start'}, 'find_body_start');
    ok(exists $funcs->{'Hypersonic::UA::Protocol::HTTP1::get_content_length'}, 'get_content_length');
    ok(exists $funcs->{'Hypersonic::UA::Protocol::HTTP1::decode_chunked'}, 'decode_chunked');
};

done_testing();
