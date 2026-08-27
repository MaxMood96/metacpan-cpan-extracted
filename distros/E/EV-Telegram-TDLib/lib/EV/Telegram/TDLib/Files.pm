package EV::Telegram::TDLib::Files;

use strict;
use warnings;

our $VERSION = '0.02';

sub CLONE_SKIP { 1 }

our %UPDATES = (
    updateFile => \&_update_file,
);

sub _downloads { $_[0]{cache}{downloads} ||= {} }

sub _uploads { $_[0]{cache}{uploads} ||= {} }

sub _json_bool { EV::Telegram::TDLib::_json_bool($_[0]) }
sub _need { EV::Telegram::TDLib::_need(@_) }

sub _update_file {
    my ($self, $obj) = @_;
    my $file = $obj->{file} or return;
    # an id-less file would key both registries under the empty string and
    # collide with a later lookup
    return unless defined $file->{id};
    # TDLib re-sends updateFile for reasons unrelated to our download, so
    # only registered ids are followed and a completed one is dropped at once
    if (my $dl = $self->_downloads->{ $file->{id} }) {
        # guarded: this is user code running before our own bookkeeping, and
        # a die here would strand a completed download unresolved forever
        if (my $cb = $dl->{on_progress}) { $self->_guarded($cb, $file) }
        my $local = $file->{local};
        if ($local && $local->{is_downloading_completed}) {
            delete $self->_downloads->{ $file->{id} };
            $dl->{cb}->($file, undef);
        }
        elsif ($local && $local->{is_downloading_active}) {
            $dl->{started} = 1;
        }
        # started, then neither active nor completed: a permanent failure,
        # signalled only via updateFile; an inactive update before the
        # start is just the file's current state, not a failure
        elsif ($local && $dl->{started}) {
            delete $self->_downloads->{ $file->{id} };
            $dl->{cb}->(undef, { '@type' => 'error', code => -1,
                                 message => 'download failed' });
        }
    }
    if (my $cb = $self->_uploads->{ $file->{id} }) {
        $cb->($file);
        delete $self->_uploads->{ $file->{id} }
            if $file->{remote} && $file->{remote}{is_uploading_completed};
    }
}

sub download {
    my ($self, $file_id, @rest) = @_;
    my $cb = ref $rest[-1] eq 'CODE' ? pop @rest : sub {};
    my %opt = @rest;
    my $id = 0 + $file_id;
    # one registration per file id: overwriting would silently drop the
    # first caller's callback, so the second call fails instead --
    # synchronously, like a parse_mode error, since nothing is sent
    if ($self->_downloads->{$id}) {
        $cb->(undef, { '@type' => 'error', code => -1,
                       message => "download of file $id already in progress" });
        return;
    }
    my $reg = { cb => $cb, on_progress => $opt{on_progress} };
    $self->_downloads->{$id} = $reg;
    $self->send({
        '@type' => 'downloadFile',
        file_id => 0 + $file_id,
        priority => 0 + ($opt{priority} // 1),
        offset => 0,
        limit => 0,
        synchronous => _json_bool(0),
    }, sub {
        my ($res, $err) = @_;
        # bind to our own registration: a cancel followed by a fresh
        # download reuses the id, and this reply must not be handed to the
        # replacement, which would fail it and swallow its own reply
        my $dl = $self->_downloads->{ 0 + $file_id };
        return unless $dl && $dl == $reg;
        if ($err) {
            delete $self->_downloads->{ 0 + $file_id };
            $dl->{cb}->(undef, $err);
            return;
        }
        # an asynchronous request resolves at download start, so from
        # here an inactive-and-not-completed update is a terminal failure
        $dl->{started} = 1;
        # an already-downloaded file resolves the request at once and no
        # updateFile follows: nothing about the file changed
        if ($res->{local} && $res->{local}{is_downloading_completed}) {
            delete $self->_downloads->{ 0 + $file_id };
            $dl->{cb}->($res, undef);
        }
    });
    return;
}

sub cancel_download {
    my ($self, $file_id) = @_;
    $self->send({
        '@type' => 'cancelDownloadFile',
        file_id => 0 + $file_id,
        only_if_pending => _json_bool(0),
    });
    my $dl = delete $self->_downloads->{ 0 + $file_id } or return;
    $dl->{cb}->(undef, { '@type' => 'error', code => -1,
                         message => 'download canceled' });
    return;
}

sub upload {
    my ($self, $path, %opt) = @_;
    return { '@type' => 'inputFileLocal', path => "$path" };
}

sub on_upload {
    my ($self, $file_id, $cb) = @_;
    if ($cb) { $self->_uploads->{ 0 + $file_id } = $cb }
    else     { delete $self->_uploads->{ 0 + $file_id } }
    return;
}

1;
