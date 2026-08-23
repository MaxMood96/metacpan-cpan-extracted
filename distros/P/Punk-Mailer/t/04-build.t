use strict;
use warnings;
use utf8;
use Test::More;
use File::Temp ();
use lib 't/lib';
use MIMERead;
BEGIN { do './t/sibling.pl' }
use Punk::Mailer;

# the builder: the three structures, parsed back by a reader that refuses
# anything a lenient mail client would forgive; the encoding choice; the
# generated headers; attachments from a path, from bytes, from an object.

my %base = (from => 'Example <ops@example.com>', to => 'Alice <a@example.com>',
            subject => 'Hello', date => 1787000000);

sub parses {
    my ($bytes, $name) = @_;
    my $m = eval { MIMERead::parse($bytes) };
    ok($m, "$name: parses strictly") or diag $@;
    return $m;
}

# ---- text only ----------------------------------------------------------------
{
    my $bytes = Punk::Mailer->build({ %base, text => "Just text.\n" });
    my $m = parses($bytes, 'text only');
    is($m->{type}, 'text/plain', 'Content-Type text/plain');
    is($m->{params}{charset}, 'utf-8', 'charset utf-8');
    is($m->{encoding}, '7bit', 'ASCII text is 7bit');
    is($m->{body}, "Just text.\r\n", 'the body, with CRLF');
    is($m->{headers}{from}, 'Example <ops@example.com>', 'From');
    is($m->{headers}{to}, 'Alice <a@example.com>', 'To');
    is($m->{headers}{subject}, 'Hello', 'Subject');
    is($m->{headers}{date}, 'Mon, 17 Aug 2026 20:53:20 +0000', 'Date from the spec');
    like($m->{headers}{'message-id'}, qr/^<1787000000\.\d+\.[A-Za-z0-9_-]{24}\@example\.com>\z/,
        'Message-ID: epoch.pid.token at the From domain');
    is($m->{headers}{'mime-version'}, '1.0', 'MIME-Version');
    is_deeply([ @{ $m->{order} }[0 .. 3] ], [ qw(From To Subject Date) ],
        'address headers first, in the conventional order');
}

# ---- text + html ------------------------------------------------------------------
{
    my $bytes = Punk::Mailer->build({ %base, text => "plain\n", html => "<p>rich</p>\n" });
    my $m = parses($bytes, 'alternative');
    is($m->{type}, 'multipart/alternative', 'multipart/alternative');
    is(scalar @{ $m->{parts} }, 2, 'two parts');
    is($m->{parts}[0]{type}, 'text/plain', 'text first');
    is($m->{parts}[1]{type}, 'text/html', 'then html');
    is($m->{parts}[1]{body}, "<p>rich</p>\r\n", 'the html body');
    like($m->{params}{boundary}, qr/^=_pm_[A-Za-z0-9_-]{24}\z/, 'the boundary shape');
}

# ---- attachments ----------------------------------------------------------------
{
    my $dir = File::Temp->newdir;
    my $pdf = "$dir/inv.pdf";
    my $blob = join '', map { chr($_ % 256) } 0 .. 9999;
    open my $fh, '>', $pdf or die $!; binmode $fh; print $fh $blob; close $fh;

    {
        package FakeUpload;
        sub new { my ($c, %a) = @_; bless {%a}, $c }
        sub path { $_[0]{path} }
        sub filename { $_[0]{filename} }
        sub type { $_[0]{type} }
    }

    my $bytes = Punk::Mailer->build({
        %base, text => "see attached\n", html => "<p>see attached</p>\n",
        attachments => [
            { path => $pdf, filename => 'invoice.pdf', type => 'application/pdf' },
            { content => "a,b\n1,2\n", filename => 'data "q".csv', type => 'text/csv' },
            FakeUpload->new(path => $pdf, filename => 'rapport été.pdf',
                            type => 'application/pdf'),
            { content => 'x', filename => 'untyped' },
        ],
    });
    my $m = parses($bytes, 'mixed');
    is($m->{type}, 'multipart/mixed', 'multipart/mixed');
    is(scalar @{ $m->{parts} }, 5, 'the alternative plus four attachments');
    is($m->{parts}[0]{type}, 'multipart/alternative', 'the first part is the alternative');
    is(scalar @{ $m->{parts}[0]{parts} }, 2, '  with its two parts');
    isnt($m->{parts}[0]{params}{boundary}, $m->{params}{boundary},
        'the inner boundary differs from the outer');

    my $a = $m->{parts}[1];
    is($a->{type}, 'application/pdf', 'path attachment: type');
    is($a->{params}{name}, 'invoice.pdf', '  name');
    is($a->{encoding}, 'base64', '  base64');
    is($a->{body}, $blob, '  the file bytes, streamed from disk');
    like($a->{headers}{'content-disposition'}, qr/^attachment;\s*filename="invoice\.pdf"/,
        '  Content-Disposition attachment');

    my $c = $m->{parts}[2];
    is($c->{body}, "a,b\n1,2\n", 'content attachment: bytes as given');
    is($c->{params}{name}, 'data "q".csv', '  a quote in the filename is escaped and survives');

    my $u = $m->{parts}[3];
    is($u->{body}, $blob, 'object attachment: read through ->path');
    like($u->{headers}{'content-disposition'}, qr/filename\*=UTF-8''rapport%20%C3%A9t%C3%A9\.pdf/,
        '  a non-ASCII filename is RFC 2231 encoded');
    like($u->{headers}{'content-disposition'}, qr/filename="rapport _t_\.pdf"/,
        '  with an ASCII stand-in beside it');

    is($m->{parts}[4]{type}, 'application/octet-stream', 'no type means octet-stream');
}

# ---- the encoding choice --------------------------------------------------------
{
    my %e = (
        'ASCII'            => [ "plain ascii\n",                '7bit'             ],
        'mostly ASCII'     => [ "caf\x{e9} au lait, s'il vous pla\x{ee}t\n", 'quoted-printable' ],
        'CJK'              => [ ("日本語のテキスト" x 20) . "\n", 'base64'           ],
        'a 1000-column line' => [ ('x' x 1000) . "\n",          'quoted-printable' ],
        'a NUL'            => [ "a\0b\n",                       'base64'           ],
    );
    for my $name (sort keys %e) {
        my ($text, $want) = @{ $e{$name} };
        my $m = parses(Punk::Mailer->build({ %base, text => $text }), $name);
        is($m->{encoding}, $want, "$name -> $want");
        my $expect = $text;
        utf8::encode($expect);      # perl semantics: a latin-1 string upgrades too
        $expect =~ s/(?<!\r)\n/\r\n/g unless $want eq 'base64';
        is($m->{body}, $expect, "  and decodes to the text");
    }
}

# ---- a body that contains the boundary --------------------------------------------
# The guarantee rests on the boundary's alphabet: it starts with "=_", and
# quoted-printable turns every "=" into "=3D", so the one encoding a 7bit
# body is switched to cannot leave the boundary intact. A forced boundary
# has to be shaped like a real one for the test to mean anything.
{
    my $b = '=_pm_FIXEDFORTHISTEST';
    my $text = "innocent\r\n--$b\r\nnot a part\r\n";
    my $bytes = Punk::Mailer->build({ %base, text => $text, html => "<p>x</p>",
                                      _boundary => $b });
    my $m = parses($bytes, 'boundary in the body');
    is($m->{parts}[0]{encoding}, 'quoted-printable',
        '7bit text containing the boundary is encoded instead');
    is($m->{parts}[0]{body}, $text, '  and decodes whole');
    is(scalar @{ $m->{parts} }, 2, '  and the structure has two parts, not three');
}

# ---- custom headers -----------------------------------------------------------------
{
    my $m = parses(Punk::Mailer->build({ %base, text => 't',
        headers => { 'X-Zed' => 'last', 'List-Unsubscribe' => '<mailto:u@example.com>',
                     'X-Accent' => 'café' } }), 'custom headers');
    is($m->{headers}{'list-unsubscribe'}, '<mailto:u@example.com>', 'a custom header');
    is($m->{headers}{'x-accent'}, '=?UTF-8?B?Y2Fmw6k=?=', 'a non-ASCII value is encoded');
    my @custom = grep { /^(X-|List-)/ } @{ $m->{order} };
    is_deeply(\@custom, [ 'List-Unsubscribe', 'X-Accent', 'X-Zed' ], 'in sorted order');
}

# ---- the spec is strict -------------------------------------------------------------
{
    ok(!eval { Punk::Mailer->build({ %base, text => 't', subjet => 'typo' }); 1 },
        'an unknown key croaks');
    like($@, qr/unknown message key 'subjet'/, '  naming it');
    ok(!eval { Punk::Mailer->build({ from => 'a@b.c', subject => 's', text => 't' }); 1 },
        'no recipient croaks');
    ok(!eval { Punk::Mailer->build({ %base, text => 't', from => [ 'a@b.c', 'd@e.f' ] }); 1 },
        'two from addresses croak');
    ok(!eval { Punk::Mailer->build({ %base }); 1 }, 'no body croaks');
    ok(!eval { Punk::Mailer->build({ %base, text => 't',
        attachments => [ { content => 'x', filename => 'f', cid => 'a' } ] }); 1 },
        'cid is reserved');
    like($@, qr/reserved/, '  and says so');
    ok(!eval { Punk::Mailer->build({ %base, text => 't',
        attachments => [ { path => '/no/such/file', filename => 'f' } ] }); 1 },
        'an unreadable path croaks');
    like($@, qr{cannot open attachment '/no/such/file'}, '  naming the path');
    ok(!eval { Punk::Mailer->build({ %base, text => 't', message_id => 'bare' }); 1 },
        'a message_id without <...@...> croaks');
    my $m = parses(Punk::Mailer->build({ %base, text => 't',
        message_id => '<abc@mine.example>', message_id_domain => 'ignored' }), 'own id');
    is($m->{headers}{'message-id'}, '<abc@mine.example>', 'a supplied Message-ID is used');
    $m = parses(Punk::Mailer->build({ %base, text => 't', message_id_domain => 'mine.example' }),
        'own domain');
    like($m->{headers}{'message-id'}, qr/\@mine\.example>\z/, 'message_id_domain wins');
}

# ---- build_to streams the same bytes ---------------------------------------------
{
    my $spec = { %base, text => "stream\n", html => "<p>stream</p>" };
    my $whole = Punk::Mailer->build({ %$spec, _boundary => 'B' });
    my ($joined, $chunks) = ('', 0);
    Punk::Mailer->build_to({ %$spec, _boundary => 'B' }, sub { $joined .= $_[0]; $chunks++ });
    (my $w = $whole) =~ s/^Message-ID:.*\r\n//m;
    (my $j = $joined) =~ s/^Message-ID:.*\r\n//m;
    is($j, $w, 'build_to produces the same bytes');
    cmp_ok($chunks, '>', 1, 'in more than one chunk');
}

done_testing;
