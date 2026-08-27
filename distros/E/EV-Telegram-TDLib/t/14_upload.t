use strict;
use warnings;
use Test::More;
use EV;
use EV::Telegram::TDLib;

my @sent;
{
    no warnings 'redefine';
    *EV::Telegram::TDLib::_send = sub { push @sent, $_[1]; };
}

sub extra_of {
    my ($json) = @_;
    my ($extra) = $json =~ /"\@extra":"(\d+)"/;
    return $extra;
}

my $td = EV::Telegram::TDLib->new(
    api_id   => 1,
    api_hash => 'x',
    auto_auth => 0,
    database_directory => 't/tmp-upload',
);

my (@progress, @updates);
$td->on_update(sub { push @updates, $_[0] });
$td->on_upload(55, sub { push @progress, $_[0] });

$td->_inject_raw(q({"@type":"updateFile","file":{"@type":"file","id":55,"size":2000,"local":{"@type":"localFile","path":"/tmp/big.bin","is_downloading_completed":true},"remote":{"@type":"remoteFile","is_uploading_active":true,"is_uploading_completed":false,"uploaded_size":500}}}));
is(scalar @progress, 1, 'upload progress fires for a registered id');
is($progress[0]{remote}{uploaded_size}, 500, 'the remote uploaded_size is delivered');

$td->_inject_raw(q({"@type":"updateFile","file":{"@type":"file","id":66,"size":2000,"remote":{"@type":"remoteFile","is_uploading_active":true,"is_uploading_completed":false,"uploaded_size":500}}}));
is(scalar @progress, 1, 'an unregistered id fires no upload watcher');
is($updates[-1]{'@type'}, 'updateFile', 'the update still reaches on_update');

$td->_inject_raw(q({"@type":"updateFile","file":{"@type":"file","id":55,"size":2000,"local":{"@type":"localFile","path":"/tmp/big.bin","is_downloading_completed":true},"remote":{"@type":"remoteFile","is_uploading_active":false,"is_uploading_completed":true,"uploaded_size":2000}}}));
is(scalar @progress, 2, 'the completing update is delivered');
ok($progress[1]{remote}{is_uploading_completed}, 'remote completion flag is delivered');

$td->_inject_raw(q({"@type":"updateFile","file":{"@type":"file","id":55,"size":2000,"remote":{"@type":"remoteFile","is_uploading_active":false,"is_uploading_completed":true,"uploaded_size":2000}}}));
is(scalar @progress, 2, 'the watcher is dropped after completion');

# --- explicit unwatch
my @gone;
$td->on_upload(56, sub { push @gone, $_[0] });
$td->on_upload(56, undef);
$td->_inject_raw(q({"@type":"updateFile","file":{"@type":"file","id":56,"size":1,"remote":{"@type":"remoteFile","is_uploading_active":true,"is_uploading_completed":false,"uploaded_size":0}}}));
is(scalar @gone, 0, 'on_upload with an undef callback removes the watcher');

# --- download and upload registries coexist on the same client
my (@dl_progress, @dl_done);
$td->download(57, on_progress => sub { push @dl_progress, $_[0] }, sub { push @dl_done, [@_] });
my $extra_dl = extra_of($sent[-1]);
$td->_inject_raw(qq({"\@type":"file","id":57,"\@extra":"$extra_dl"}));
my @up57;
$td->on_upload(57, sub { push @up57, $_[0] });
$td->_inject_raw(q({"@type":"updateFile","file":{"@type":"file","id":57,"size":10,"local":{"@type":"localFile","downloaded_size":5,"is_downloading_completed":false},"remote":{"@type":"remoteFile","is_uploading_active":true,"is_uploading_completed":false,"uploaded_size":3}}}));
is(scalar @dl_progress, 1, 'the download progress fired for the same id');
is(scalar @up57, 1, 'the upload watcher fired for the same id');

# --- close drops watchers silently
my @late;
$td->on_upload(58, sub { push @late, $_[0] });
$td->close;
$td->_inject_raw(q({"@type":"updateAuthorizationState","authorization_state":{"@type":"authorizationStateClosed"}}));
ok(!exists $td->{cache}{uploads}, 'close drops upload watchers');
is(scalar @late, 0, 'no watcher fires during close');

done_testing;
