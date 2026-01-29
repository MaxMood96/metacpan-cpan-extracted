use strict;
use warnings;
use Test::More;

use_ok('Hypersonic::UA::Stream');

subtest 'Constants' => sub {
    is(Hypersonic::UA::Stream->STATE_INIT, 0, 'STATE_INIT');
    is(Hypersonic::UA::Stream->STATE_HEADERS, 1, 'STATE_HEADERS');
    is(Hypersonic::UA::Stream->STATE_BODY, 2, 'STATE_BODY');
    is(Hypersonic::UA::Stream->STATE_FINISHED, 3, 'STATE_FINISHED');
    is(Hypersonic::UA::Stream->STATE_ERROR, 4, 'STATE_ERROR');
};

subtest 'XS functions registered' => sub {
    my $funcs = Hypersonic::UA::Stream->get_xs_functions();
    ok(exists $funcs->{'Hypersonic::UA::Stream::new'}, 'new');
    ok(exists $funcs->{'Hypersonic::UA::Stream::fd'}, 'fd');
    ok(exists $funcs->{'Hypersonic::UA::Stream::state'}, 'state');
    ok(exists $funcs->{'Hypersonic::UA::Stream::status'}, 'status');
    ok(exists $funcs->{'Hypersonic::UA::Stream::headers'}, 'headers');
    ok(exists $funcs->{'Hypersonic::UA::Stream::is_complete'}, 'is_complete');
    ok(exists $funcs->{'Hypersonic::UA::Stream::is_error'}, 'is_error');
    ok(exists $funcs->{'Hypersonic::UA::Stream::read_chunk'}, 'read_chunk');
    ok(exists $funcs->{'Hypersonic::UA::Stream::abort'}, 'abort');
};

done_testing();
