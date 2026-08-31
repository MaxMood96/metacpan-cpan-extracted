#!perl
use 5.010;
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/lib";
use Test::More;
use File::Temp ();
use Punk::Test;

# The client's `upload` option, round-tripped against the streaming
# server-side parser: both value forms, the spill path, repeated fields,
# filename edge cases, csrf composition, and the croaks. The client and
# the app share this process, so handlers compare uploaded bytes against
# the originals directly rather than shipping them back through JSON.

our %SENT;      # what the test posted, for exact comparison in handlers

{
    package UpApp;
    use Punk;
    session secret => 'upload-test-key';

    post '/up' => sub {
        my ($c) = @_;
        my $up = $c->req->upload('file')
            or return $c->text('no file', 400);
        $c->json({
            desc     => $c->param('desc'),
            filename => $up->filename,
            name     => $up->name,
            type     => $up->type,
            size     => $up->size,
            spilled  => defined $up->path ? 1 : 0,
            exact    => (defined $main::SENT{file}
                         && $up->content eq $main::SENT{file}) ? 1 : 0,
            fn_exact => (defined $main::SENT{fname}
                         && $up->filename eq $main::SENT{fname}) ? 1 : 0,
            boundary => scalar(($c->req->header('content-type') // '')
                              =~ /boundary=(\S+)/ ? $1 : ''),
            multi    => [ map { $_->filename }
                          @{ $c->req->uploads->{multi} || [] } ],
        });
    };
}

my $t = Punk::Test->new('UpApp');

# ---- a small part, in memory, from a content ref -----------------------------

$SENT{file} = 'the bytes';
$t->post_ok('/up',
        form   => { desc => 'a caption' },
        upload => { file => [ \'the bytes', 'hi.txt', 'text/plain' ] })
  ->status_is(200)
  ->json_is('/desc',     'a caption', 'a form pair became an ordinary part')
  ->json_is('/filename', 'hi.txt')
  ->json_is('/name',     'file')
  ->json_is('/type',     'text/plain')
  ->json_is('/size',     9)
  ->json_is('/spilled',  0, 'a small part stayed in memory')
  ->json_is('/exact',    1, 'the bytes arrived intact');

# ---- defaults: filename from the path's basename, type octet-stream ----------

my $tmp = File::Temp->new;
print {$tmp} 'from a file';
close $tmp;
my ($base) = "$tmp" =~ m{([^/\\]+)\z};

$SENT{file} = 'from a file';
$t->post_ok('/up', upload => { file => [ "$tmp" ] })
  ->status_is(200)
  ->json_is('/filename', $base, 'the filename defaulted to the basename')
  ->json_is('/type', 'application/octet-stream', 'and the type to octet-stream')
  ->json_is('/exact', 1);

$SENT{file} = 'x';
$t->post_ok('/up', upload => { file => [ \'x' ] })
  ->json_is('/filename', 'file', 'a content ref defaults its filename to the field');

# ---- the spill path ----------------------------------------------------------

# Past PQ_MP_SPILL (64 KiB), built to be hostile to a chunked encoder and
# parser: CRLFs, leading dashes, and boundary-shaped runs throughout.
my $big = ("--PunkTest\r\n-abc" . ("x" x 61)) x 2600;   # ~200KB
$SENT{file} = $big;
$t->post_ok('/up',
        form   => { desc => 'big' },
        upload => { file => [ \$big, 'big.bin', 'application/x-thing' ] })
  ->status_is(200)
  ->json_is('/size',    length $big)
  ->json_is('/spilled', 1, 'a part past the threshold spilled to disk')
  ->json_is('/exact',   1, 'and every byte arrived')
  ->json_is('/desc',    'big', 'with the field beside it intact');

# the same part from a real file, so the streamed-read arm is the one tested
{
    my $bf = File::Temp->new;
    binmode $bf;
    print {$bf} $big;
    close $bf;
    $t->post_ok('/up', upload => { file => [ "$bf", 'big.bin' ] })
      ->json_is('/spilled', 1)
      ->json_is('/exact',   1, 'a file source streams through intact');
}

# ---- repeated fields ---------------------------------------------------------

$SENT{file} = 'f';
$t->post_ok('/up', upload => {
        file  => [ \'f' ],
        multi => [ [ \'A', 'a.txt' ], [ \'B', 'b.txt' ] ],
    })
  ->json_is('/multi', [ 'a.txt', 'b.txt' ],
        'an arrayref of arrayrefs repeats the field');

# ---- filename edge cases -----------------------------------------------------

$SENT{file} = 'q';
$t->post_ok('/up', upload => { file => [ \'q', 'fo"o.txt' ] })
  ->json_is('/filename', 'fo%22o.txt',
        'a quote is percent-encoded, RFC 7578');

# A flagged filename, as a test with `use utf8` would write it. The parser
# stores what arrived, so the exact expectation is the UTF-8 bytes - and it
# is compared in-process, not through the JSON seam, whose bytes-vs-flag
# behaviour is not what this test is about.
my $uni = "na\x{ef}ve.png";
utf8::upgrade($uni);
my $uni_bytes = $uni;
utf8::encode($uni_bytes);
$SENT{fname} = $uni_bytes;
$t->post_ok('/up', upload => { file => [ \'q', $uni ] })
  ->json_is('/fn_exact', 1, 'a UTF-8 filename travels as raw UTF-8');
delete $SENT{fname};

# ---- csrf => 1 composes ------------------------------------------------------

{
    package CsrfUpApp;
    use Punk;
    session secret => 'upload-csrf-key';
    csrf;
    get  '/'   => sub { $_[0]->text($_[0]->csrf_token) };
    post '/up' => sub {
        my ($c) = @_;
        my $up = $c->req->upload('file');
        $c->text($up ? 'got ' . $up->size : 'none');
    };
}
my $c = Punk::Test->new('CsrfUpApp');
$c->get_ok('/');
$SENT{file} = 'guarded';
$c->post_ok('/up', upload => { file => [ \'guarded', 'g.txt' ] }, csrf => 1)
  ->status_is(200, 'csrf => 1 composes with upload')
  ->content_is('got 7');
$c->post_ok('/up', upload => { file => [ \'guarded', 'g.txt' ] })
  ->status_is(403, 'and without it the guard still refuses');

# ---- the boundary is verified, not hoped -------------------------------------

{
    # First roll deliberately collides with the content; the encoder must
    # notice and re-roll rather than send a body the parser would cut short.
    my @rolls = ('COLLIDINGBOUNDARY', 'PunkTestReRolled0001');
    no warnings 'redefine';
    local *Punk::Test::_mp_boundary = sub { shift @rolls };
    my $bytes = 'leading COLLIDINGBOUNDARY trailing';
    $SENT{file} = $bytes;
    $t->post_ok('/up', upload => { file => [ \$bytes, 'c.bin' ] })
      ->status_is(200)
      ->json_is('/exact',    1, 'a colliding boundary was re-rolled')
      ->json_is('/boundary', 'PunkTestReRolled0001', 'to the next roll');
}

# ---- the croaks --------------------------------------------------------------

for my $bad ([ json => {} ], [ body => 'x' ], [ type => 'text/plain' ]) {
    my $err = '';
    eval { $t->post_ok('/up', upload => { f => [ \'x' ] }, @$bad) }
        or $err = $@;
    like($err, qr/upload and $bad->[0] do not combine/,
        "upload + $bad->[0] croaks");
}
{
    my $err = '';
    eval { $t->post_ok('/up', upload => { f => 'not-an-arrayref' }) }
        or $err = $@;
    like($err, qr/takes an arrayref/, 'a non-arrayref field croaks');
}
{
    my $err = '';
    eval { $t->post_ok('/up', upload => { f => [ 't/no-such-file.bin' ] }) }
        or $err = $@;
    like($err, qr/no file at 't\/no-such-file\.bin'/,
        'a missing path croaks before the request starts');
}

done_testing;
