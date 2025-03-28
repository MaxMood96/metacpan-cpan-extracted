use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::NoTabs 0.15

use Test::More 0.88;
use Test::NoTabs;

my @files = (
    'lib/Net/Async/Redis.pm',
    'lib/Net/Async/Redis.pod',
    'lib/Net/Async/Redis/Cluster.pm',
    'lib/Net/Async/Redis/Cluster.pod',
    'lib/Net/Async/Redis/Cluster/Multi.pm',
    'lib/Net/Async/Redis/Cluster/Node.pm',
    'lib/Net/Async/Redis/Cluster/Node.pod',
    'lib/Net/Async/Redis/Cluster/Replica.pm',
    'lib/Net/Async/Redis/Cluster/Replica.pod',
    'lib/Net/Async/Redis/Commands.pm',
    'lib/Net/Async/Redis/Commands.pod',
    'lib/Net/Async/Redis/Multi.pm',
    'lib/Net/Async/Redis/Protocol.pm',
    'lib/Net/Async/Redis/Server.pm',
    'lib/Net/Async/Redis/Server.pod',
    'lib/Net/Async/Redis/Server/Connection.pm',
    'lib/Net/Async/Redis/Server/Connection.pod',
    'lib/Net/Async/Redis/Server/Database.pm',
    'lib/Net/Async/Redis/Subscription.pm',
    'lib/Net/Async/Redis/Subscription/Message.pm',
    't/00-check-deps.t',
    't/00-compile.t',
    't/00-report-prereqs.dd',
    't/00-report-prereqs.t',
    't/basic.t',
    't/client_side_caching.t',
    't/cluster.t',
    't/hash_slot.t',
    't/interleave.t',
    't/keyspec.t',
    't/multi.t',
    't/pipeline.t',
    't/protocol.t',
    't/protocol_compatibility_test.t',
    't/psubscribe.t',
    't/pubsub.t',
    't/watch_keyspace.t',
    'xt/author/distmeta.t',
    'xt/author/eol.t',
    'xt/author/minimum-version.t',
    'xt/author/mojibake.t',
    'xt/author/no-tabs.t',
    'xt/author/pod-syntax.t',
    'xt/author/portability.t',
    'xt/author/test-version.t',
    'xt/release/common_spelling.t',
    'xt/release/cpan-changes.t'
);

notabs_ok($_) foreach @files;
done_testing;
