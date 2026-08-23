use strict;
use warnings;
use utf8;
use Test::More;
use File::Temp ();
use MIME::Base64 ();
use JSON::PP ();
use lib 't/lib';
use FakeResend;
BEGIN { do './t/sibling.pl' }
use Punk::Mailer;

# the Resend transport against a fake: the JSON it sends, the headers it
# authenticates with, and how each answer becomes a Result.

my $srv = eval { FakeResend->new } or plan skip_all => "cannot start the fake: $@";

sub mailer {
    my ($path, %extra) = @_;
    return Punk::Mailer->new(transport => 'resend', from => 'Ops <ops@example.com>',
                             resend => { api_key => 're_test_key', url => $srv->url($path), %extra });
}

my %msg = (to => [ 'Alice <a@example.com>', 'b@example.com' ], cc => 'Zoë <z@example.com>',
           bcc => 'hidden@example.com', reply_to => 'help@example.com',
           subject => 'Résumé', text => "plain ünïcode\n", html => "<p>rich</p>",
           headers => { 'X-Entity-Ref-ID' => 'abc' });

# ---- the request -------------------------------------------------------------
{
    my $m = mailer('/ok');
    is($m->transport->url, $srv->url('/ok'), 'url points at the fake');
    is($m->transport->timeout, 10, 'the default timeout');
    my $r = $m->send({ %msg, attachments => [
        { content => "a,b\n", filename => 'data.csv', type => 'text/csv' },
    ] });
    is($r->status, 'accepted', '200 is accepted') or diag $r->message;
    is($r->code, 200, '  with the HTTP status');
    is($r->id, '49a3999c-0ce1-4ea6-ab68-afcd6dc2e794', '  and the id Resend returned');
    is($r->transport, 'resend', '  from resend');

    my ($req) = $srv->requests;
    like($req->{line}, qr{^POST /ok HTTP/1\.1}, 'a POST');
    is($req->{headers}{authorization}, 'Bearer re_test_key', 'Bearer auth');
    is($req->{headers}{'content-type'}, 'application/json', 'JSON content type');
    my $j = JSON::PP->new->utf8->decode($req->{body});
    is($j->{from}, 'Ops <ops@example.com>', 'from');
    is_deeply($j->{to}, [ 'Alice <a@example.com>', 'b@example.com' ], 'to, display forms kept');
    is_deeply($j->{cc}, [ 'Zoë <z@example.com>' ], 'cc as raw UTF-8, not an encoded-word');
    is_deeply($j->{bcc}, [ 'hidden@example.com' ], 'bcc goes to the API, which handles it');
    is_deeply($j->{reply_to}, [ 'help@example.com' ], 'reply_to');
    is($j->{subject}, 'Résumé', 'subject as characters');
    is($j->{text}, "plain ünïcode\n", 'text');
    is($j->{html}, '<p>rich</p>', 'html');
    is_deeply($j->{headers}, { 'X-Entity-Ref-ID' => 'abc' }, 'custom headers');
    is(scalar @{ $j->{attachments} }, 1, 'one attachment');
    is($j->{attachments}[0]{filename}, 'data.csv', '  filename');
    is($j->{attachments}[0]{content_type}, 'text/csv', '  content_type');
    is(MIME::Base64::decode_base64($j->{attachments}[0]{content}), "a,b\n", '  base64 content');
    unlike($j->{attachments}[0]{content}, qr/\r|\n/, '  in one unwrapped string');
}

# ---- a path attachment, and the cap -----------------------------------------------
{
    my $dir = File::Temp->newdir;
    my $blob = join '', map { chr int rand 256 } 1 .. 5000;
    open my $fh, '>', "$dir/f.bin" or die $!; binmode $fh; print $fh $blob; close $fh;

    my $r = mailer('/ok')->send({ %msg, attachments => [ { path => "$dir/f.bin", filename => 'f.bin' } ] });
    ok($r->accepted, 'a path attachment is read and sent');
    my @reqs = $srv->requests;
    my $j = JSON::PP->new->utf8->decode($reqs[-1]{body});
    is(MIME::Base64::decode_base64($j->{attachments}[0]{content}), $blob, '  as its bytes');

    my $before = scalar @reqs;
    $r = mailer('/ok', max_attachment => 1000)->send({ %msg,
        attachments => [ { path => "$dir/f.bin", filename => 'f.bin' } ] });
    is($r->status, 'rejected', 'over max_attachment is rejected locally');
    like($r->message, qr/5000 bytes, over the resend transport's max_attachment of 1000/, '  saying so');
    is(scalar $srv->requests, $before, '  and nothing was sent');

    $r = mailer('/ok', max_attachment => 3)->send({ %msg,
        attachments => [ { content => 'xxxx', filename => 'x' } ] });
    is($r->status, 'rejected', 'the cap applies to content attachments too');
}

# ---- the answers ----------------------------------------------------------------
{
    my $r = mailer('/rate')->send(\%msg);
    is($r->status, 'deferred', '429 is deferred');
    is($r->code, 429, '  code');
    like($r->message, qr/resend answered 429: Too many requests/, '  with the message field');
    ok($r->retryable, '  retryable');

    $r = mailer('/bad')->send(\%msg);
    is($r->status, 'rejected', '422 is rejected');
    like($r->message, qr/Invalid `to` field/, '  with the message field');
    ok(!$r->retryable, '  not retryable');

    $r = mailer('/down')->send(\%msg);
    is($r->status, 'deferred', '500 is deferred');
    is($r->message, 'resend answered 500: boom é "quoted"', '  with \u and \" unescaped');

    $r = mailer('/nowhere')->send(\%msg);
    is($r->status, 'rejected', 'an unexpected 4xx is rejected');

    $r = mailer('/drop')->send(\%msg);
    is($r->status, 'failed', 'a closed connection is failed');
    like($r->message, qr/resend unreachable/, '  unreachable');
    is($r->id, undef, '  no id');
    ok($r->retryable, '  retryable');
}

# ---- nobody listening ---------------------------------------------------------------
{
    my $port = $srv->port;
    $srv->stop;
    my $r = Punk::Mailer->new(transport => 'resend', from => 'o@example.com',
        resend => { api_key => 'k', url => "http://127.0.0.1:$port/ok", timeout => 2 })->send(\%msg);
    is($r->status, 'failed', 'a refused connection is failed');
}

done_testing;
