use v5.36;
use strict;
use warnings;
use Test::More;

use Linux::Event::Error;

my $error = Linux::Event::Error->new(
    type => 'framing',
    operation => 'frame',
    message => 'bad frame',
);
is("$error", 'frame: bad frame', 'Stream::Error string overload accepts Perl overload call convention');
ok(!defined $error->pending_bytes, 'non-limit errors have no pending byte detail');
ok(!defined $error->limit, 'non-limit errors have no hard-limit detail');

done_testing;
