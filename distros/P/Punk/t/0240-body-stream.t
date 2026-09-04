#!perl
use 5.010;
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/lib";
use Test::More;
use File::Temp ();
use Punk::Test;

# The request body a chunk at a time: ->body_each and ->body_to.
#
# ->body copies the whole request into one scalar, which doubles bytes the
# server is already holding for as long as the handler runs. Multipart has
# streamed off psgi.input since uploads landed; this is the same window for a
# body that is not multipart, and the rule that keeps it honest: a body is
# read once, and reading it twice is an error somebody sees rather than an
# empty string somebody ships.

our (@CHUNKS, $COUNT, $ERR, $DIR, $PATH);
$DIR  = File::Temp->newdir();
$PATH = "$DIR/spooled.bin";

my $BIG = join '', map { sprintf "%06d-abcdefghij\n", $_ } 1 .. 20_000;

{
    package BSApp;
    use Punk;

    post '/each' => sub {
        my ($c) = @_;
        @main::CHUNKS = ();
        $main::COUNT = $c->req->body_each(sub {
            my ($chunk, $req) = @_;
            push @main::CHUNKS, $chunk;
        });
        $c->text('read');
    };

    post '/each-small' => sub {
        my ($c) = @_;
        @main::CHUNKS = ();
        $main::COUNT = $c->req->body_each(
            sub { push @main::CHUNKS, $_[0] }, chunk => 4096);
        $c->text('read');
    };

    # what the callback is given, second argument included
    post '/each-args' => sub {
        my ($c) = @_;
        @main::CHUNKS = ();
        $c->req->body_each(sub {
            my ($chunk, $req) = @_;
            push @main::CHUNKS, ref($req) . ':' . $req->method;
        });
        $c->text('read');
    };

    post '/to-path' => sub {
        my ($c) = @_;
        $main::COUNT = $c->req->body_to($main::PATH);
        $c->text('spooled');
    };

    post '/to-handle' => sub {
        my ($c) = @_;
        open my $fh, '>', "$main::PATH.h" or die $!;
        binmode $fh;
        $main::COUNT = $c->req->body_to($fh, chunk => 8192);
        close $fh;
        $c->text('spooled');
    };

    # read once: whichever way it was read first
    post '/stream-then-body' => sub {
        my ($c) = @_;
        $c->req->body_each(sub { });
        $main::ERR = '';
        eval { $c->req->body; 1 } or $main::ERR = $@;
        $c->text('done');
    };

    post '/stream-then-json' => sub {
        my ($c) = @_;
        $c->req->body_each(sub { });
        $main::ERR = '';
        eval { $c->req->json; 1 } or $main::ERR = $@;
        $c->text('done');
    };

    post '/stream-twice' => sub {
        my ($c) = @_;
        $c->req->body_each(sub { });
        $main::ERR = '';
        eval { $c->req->body_each(sub { }); 1 } or $main::ERR = $@;
        $c->text('done');
    };

    # the other order: already read whole, then streamed
    post '/body-then-stream' => sub {
        my ($c) = @_;
        my $whole = $c->req->body;
        @main::CHUNKS = ();
        $main::COUNT = $c->req->body_each(
            sub { push @main::CHUNKS, $_[0] }, chunk => 1024);
        $c->text(length($whole) == $main::COUNT ? 'same' : 'different');
    };

    post '/capped' => sub {
        my ($c) = @_;
        $main::ERR = '';
        eval { $c->req->body_each(sub { }, chunk => 1024, max => 4096); 1 }
            or $main::ERR = $@;
        $c->text('done');
    };

    post '/no-length' => sub {
        my ($c) = @_;
        @main::CHUNKS = ();
        $main::ERR = '';
        eval {
            $main::COUNT = $c->req->body_each(sub { push @main::CHUNKS, $_[0] });
            1;
        } or $main::ERR = $@;
        $c->text('done');
    };

    post '/empty' => sub {
        my ($c) = @_;
        @main::CHUNKS = ();
        $main::COUNT = $c->req->body_each(sub { push @main::CHUNKS, $_[0] });
        $c->text('done');
    };

    post '/bad' => sub {
        my ($c) = @_;
        my @errs;
        for my $try (
            sub { $c->req->body_each('not code') },
            sub { $c->req->body_each(sub { }, nope => 1) },
            sub { $c->req->body_each(sub { }, 'odd') },
            sub { $c->req->body_each(sub { }, chunk => 0) },
            sub { $c->req->body_to(undef) },
        ) {
            eval { $try->(); push @errs, 'no croak' } or push @errs, $@;
        }
        $c->text(join '~~', @errs);
    };
}

my $t = Punk::Test->new('BSApp');

# ---- the whole body, in one window -------------------------------------------
{
    $t->post_ok('/each', body => $BIG, type => 'application/octet-stream')
      ->status_is(200);
    is($COUNT, length $BIG, 'body_each returns the byte count');
    is(join('', @CHUNKS), $BIG, 'and the chunks are the body, in order');
    cmp_ok(scalar @CHUNKS, '>', 1,
        'a body larger than one window arrives in several');
}

# ---- a window of its own -----------------------------------------------------
{
    $t->post_ok('/each-small', body => $BIG,
                type => 'application/octet-stream')->status_is(200);
    is(join('', @CHUNKS), $BIG, 'a smaller chunk size still reassembles');
    is(scalar(grep { length($_) > 4096 } @CHUNKS), 0,
        'and no chunk is larger than the window asked for');
    cmp_ok(scalar @CHUNKS, '>=', int(length($BIG) / 4096),
        'which means many more of them');
}

# ---- the callback's arguments ------------------------------------------------
{
    $t->post_ok('/each-args', body => 'small', type => 'text/plain')
      ->status_is(200);
    is($CHUNKS[0], 'Punk::Request:POST',
        'the callback gets the request as its second argument');
}

# ---- straight to a file ------------------------------------------------------
{
    $t->post_ok('/to-path', body => $BIG, type => 'application/octet-stream')
      ->status_is(200);
    is($COUNT, length $BIG, 'body_to returns the byte count');
    open my $fh, '<', $PATH or die $!;
    binmode $fh;
    my $got = do { local $/; <$fh> };
    close $fh;
    is($got, $BIG, 'and the file holds the body exactly');
}

{
    $t->post_ok('/to-handle', body => $BIG,
                type => 'application/octet-stream')->status_is(200);
    open my $fh, '<', "$PATH.h" or die $!;
    binmode $fh;
    my $got = do { local $/; <$fh> };
    close $fh;
    is($got, $BIG, 'body_to writes to an open handle too');
}

# ---- read once ---------------------------------------------------------------
{
    $t->post_ok('/stream-then-body', body => 'xyz', type => 'text/plain');
    like($ERR, qr/streamed and is gone/,
        '->body after a stream says the body has gone, not nothing');

    $t->post_ok('/stream-then-json', json => { a => 1 });
    like($ERR, qr/streamed and is gone/, 'and so does ->json');

    $t->post_ok('/stream-twice', body => 'xyz', type => 'text/plain');
    like($ERR, qr/streamed and is gone/, 'and a second stream');
}

# ---- the other order is not a trap -------------------------------------------
{
    $t->post_ok('/body-then-stream', body => $BIG,
                type => 'application/octet-stream')
      ->content_is('same',
        'a body already read whole is replayed from the copy');
    is(join('', @CHUNKS), $BIG, 'in chunks, like any other');
}

# ---- a ceiling ---------------------------------------------------------------
{
    $t->post_ok('/capped', body => $BIG, type => 'application/octet-stream');
    like($ERR, qr/passed 4096 bytes/, 'max stops a body that runs away');
}

# ---- no CONTENT_LENGTH -------------------------------------------------------
#
# What that means is HTTP's answer, not a guess: with no transfer coding
# either there is no body, and looking for one would turn an ordinary bodyless
# POST into an error. Chunked is the case with a body of unknown length.
{
    $t->post_ok('/no-length', body => 'ignored', type => 'text/plain',
                env => { CONTENT_LENGTH => undef });
    is($ERR, '', 'no length and no transfer coding is not an error');
    is($COUNT, 0, 'it is a request with no body, and reads nothing');

    $t->post_ok('/no-length', body => 'no length here', type => 'text/plain',
                env => { CONTENT_LENGTH => undef,
                         HTTP_TRANSFER_ENCODING => 'chunked' });
    like($ERR, qr/psgix\.input\.buffered/,
        'a chunked body on a server that will not promise a buffer is refused');

    $t->post_ok('/no-length', body => 'no length here', type => 'text/plain',
                env => { CONTENT_LENGTH => undef,
                         HTTP_TRANSFER_ENCODING => 'chunked',
                         'psgix.input.buffered' => 1 });
    is($ERR, '', 'a server that buffers its input may be read to EOF');
    is(join('', @CHUNKS), 'no length here', 'and the whole body arrives');
}

# ---- nothing to read ---------------------------------------------------------
{
    $t->post_ok('/empty');
    is($COUNT, 0, 'an empty body reads zero bytes');
    is(scalar @CHUNKS, 0, 'and the callback is never called');
}

# ---- the croaks --------------------------------------------------------------
{
    $t->post_ok('/bad', body => 'x', type => 'text/plain');
    my @errs = split /~~/, $t->body;
    like($errs[0], qr/code reference/,    'body_each wants a coderef');
    like($errs[1], qr/unknown body_each option 'nope'/, 'and known options');
    like($errs[2], qr/key => value/,      'in pairs');
    like($errs[3], qr/chunk is a positive/, 'with a real chunk size');
    like($errs[4], qr/path or an open handle/, 'body_to wants somewhere to go');
}

done_testing;
