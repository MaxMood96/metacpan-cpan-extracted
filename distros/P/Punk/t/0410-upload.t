#!perl
use 5.010;
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/lib";
use Test::More;
use File::Temp ();
use Punk::Test;

# multipart/form-data: field parts become params, file parts become
# Punk::Upload objects. Posted through Punk::Test's own multipart
# encoder, so the two halves of the conversation test each other; only
# the malformed body at the end is hand-rolled, because the client will
# not build one.

{
    package UApp;
    use Punk;
    post '/up' => sub {
        my ($c) = @_;
        my $up = $c->req->upload('file');
        return $c->text('no file', 400) unless $up;
        $c->json({
            desc     => $c->param('desc'),
            filename => $up->filename,
            name     => $up->name,
            type     => $up->type,
            size     => $up->size,
            content  => $up->content,
            two      => scalar @{ $c->req->uploads->{multi} || [] },
        });
    };
    package main;
}

# frozen once: the malformed post at the end drives the same coderef raw
my $app = UApp->to_app;
my $t   = Punk::Test->new($app);

$t->post_ok('/up',
        form   => { desc => 'a caption' },
        upload => {
            file  => [ \'the bytes', 'hi.txt', 'text/plain' ],
            multi => [ [ \'A', 'a' ], [ \'B', 'b' ] ],
        })
  ->status_is(200)
  ->json_is('/desc',     'a caption',  'a text field becomes a param')
  ->json_is('/filename', 'hi.txt',     'the upload filename')
  ->json_is('/name',     'file',       'the form field name')
  ->json_is('/type',     'text/plain', 'the content type')
  ->json_is('/size',     9,            'the byte size')
  ->json_is('/content',  'the bytes',  'the content')
  ->json_is('/two',      2,            'a field uploaded twice yields an arrayref');

# save() writes the bytes
{
    package SaveApp;
    use Punk;
    post '/save' => sub {
        my ($c) = @_;
        my $up = $c->req->upload('file');
        $up->save($c->param('to'));
        $c->text('saved');
    };
    package main;
    my $s = Punk::Test->new('SaveApp');
    my $tmp = File::Temp->new(SUFFIX => '.dat'); my $path = "$tmp";
    $s->post_ok('/save',
            form   => { to => $path },
            upload => { file => [ \'SAVED-BYTES', 'f' ] })
      ->status_is(200);
    open my $rd, '<', $path; local $/; my $got = <$rd>;
    is($got, 'SAVED-BYTES', 'save($path) writes the uploaded bytes');
}

# a malformed body is empty, not a crash - hand-rolled, the client will
# not produce one
{
    my $body = "garbage without a boundary";
    open my $in, '<', \$body or die;
    my $r = eval { $app->({
        REQUEST_METHOD => 'POST', PATH_INFO => '/up',
        CONTENT_TYPE   => 'multipart/form-data; boundary=PunkBoundary123',
        CONTENT_LENGTH => length $body,
        'psgi.input'   => $in,
    }) };
    ok(!$@, 'a malformed multipart body does not crash');
    is($r->[0], 400, 'and there simply is no upload');
}

done_testing;
