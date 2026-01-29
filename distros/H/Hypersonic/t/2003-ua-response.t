use strict;
use warnings;
use Test::More;

use_ok('Hypersonic::UA::Response');

subtest 'XS functions registered' => sub {
    my $funcs = Hypersonic::UA::Response->get_xs_functions();
    ok(exists $funcs->{'Hypersonic::UA::Response::new'}, 'new');
    ok(exists $funcs->{'Hypersonic::UA::Response::from_raw'}, 'from_raw');
    ok(exists $funcs->{'Hypersonic::UA::Response::status'}, 'status');
    ok(exists $funcs->{'Hypersonic::UA::Response::status_text'}, 'status_text');
    ok(exists $funcs->{'Hypersonic::UA::Response::body'}, 'body');
    ok(exists $funcs->{'Hypersonic::UA::Response::headers'}, 'headers');
    ok(exists $funcs->{'Hypersonic::UA::Response::header'}, 'header');
    ok(exists $funcs->{'Hypersonic::UA::Response::content_type'}, 'content_type');
    ok(exists $funcs->{'Hypersonic::UA::Response::content_length'}, 'content_length');
    ok(exists $funcs->{'Hypersonic::UA::Response::is_success'}, 'is_success');
    ok(exists $funcs->{'Hypersonic::UA::Response::is_redirect'}, 'is_redirect');
    ok(exists $funcs->{'Hypersonic::UA::Response::is_error'}, 'is_error');
    ok(exists $funcs->{'Hypersonic::UA::Response::is_client_error'}, 'is_client_error');
    ok(exists $funcs->{'Hypersonic::UA::Response::is_server_error'}, 'is_server_error');
    ok(exists $funcs->{'Hypersonic::UA::Response::is_json'}, 'is_json');
    ok(exists $funcs->{'Hypersonic::UA::Response::json'}, 'json');
    ok(exists $funcs->{'Hypersonic::UA::Response::location'}, 'location');
};

done_testing();
