use strict;
use warnings;
use utf8;
use Test::More;
use MIME::Base64 ();
BEGIN { do './t/sibling.pl' }
use Punk::Mailer;

# the header rules: addresses, encoded-words, folding, and the refusal
# that stops a form field from becoming a second header.

# ---- addresses ------------------------------------------------------------
{
    my @cases = (
        [ 'a@example.com',                    '',           'a@example.com' ],
        [ '  a@example.com  ',                '',           'a@example.com' ],
        [ 'Alice <a@example.com>',            'Alice',      'a@example.com' ],
        [ 'Alice Smith <a@example.com>',      'Alice Smith','a@example.com' ],
        [ '"Smith, Alice" <a@example.com>',   'Smith, Alice','a@example.com' ],
        [ '"Al \"Ace\" Smith" <a@example.com>', 'Al "Ace" Smith', 'a@example.com' ],
        [ 'Zoë <z@example.com>',              'Zoë',        'z@example.com' ],
        [ '<a@example.com>',                  '',           'a@example.com' ],
    );
    for my $c (@cases) {
        my ($in, $display, $addr) = @$c;
        my @got = Punk::Mailer::_address($in);
        is_deeply(\@got, [ $display, $addr ], "parse: $in");
    }
    for my $bad ('a@@example.com', 'a@', '@example.com', 'a b@example.com',
                 'a@example.com>', 'Alice <a@example.com', 'a@.example.com',
                 'a@example.com.', '', 'Alice <a@x> <b@y>', 'a<b@example.com',
                 "a\@example.com\r\nBcc: x\@evil.example") {
        # s///r is 5.14; this dist runs on 5.10.
        my $shown = $bad;
        $shown =~ s/\r\n/\\r\\n/g;
        ok(!eval { Punk::Mailer::_address($bad); 1 }, "refused: $shown");
        like($@, qr/not an address|carriage return/, '  with a reason');
    }
}

# ---- formatting ---------------------------------------------------------------
{
    is(Punk::Mailer::_address_header('To', 'a@example.com'),
        "To: a\@example.com\r\n", 'a bare address');
    is(Punk::Mailer::_address_header('To', 'Alice <a@example.com>'),
        "To: Alice <a\@example.com>\r\n", 'a plain display name');
    is(Punk::Mailer::_address_header('To', '"Smith, Alice" <a@example.com>'),
        "To: \"Smith, Alice\" <a\@example.com>\r\n", 'a name with a comma is quoted');
    is(Punk::Mailer::_address_header('To', 'Al "Ace" Smith <a@example.com>'),
        "To: \"Al \\\"Ace\\\" Smith\" <a\@example.com>\r\n",
        'a quote inside a name is escaped');
    is(Punk::Mailer::_address_header('To', 'Zoë <z@example.com>'),
        "To: =?UTF-8?B?Wm/Dqw==?= <z\@example.com>\r\n",
        'a non-ASCII name becomes an encoded-word');
    is(Punk::Mailer::_address_header('Cc', [ 'a@example.com', 'Bob <b@example.com>' ]),
        "Cc: a\@example.com, Bob <b\@example.com>\r\n", 'a list joins with a comma');
}

# ---- encoded-words ----------------------------------------------------------------
{
    is(Punk::Mailer::_encode_word('plain ascii'), 'plain ascii', 'ASCII is left alone');
    is(Punk::Mailer::_encode_word('é'), '=?UTF-8?B?w6k=?=', 'one non-ASCII character');

    my $long = 'é' x 200;          # 400 bytes of two-byte characters
    my $enc  = Punk::Mailer::_encode_word($long);
    my @words = split / /, $enc;
    my @over = grep { length $_ > 75 } @words;
    is(scalar @over, 0, 'no encoded-word is longer than 75 characters');
    my $back = '';
    for my $w (@words) {
        my ($b64) = $w =~ /^=\?UTF-8\?B\?(.*)\?=\z/ or die "not a word: $w";
        my $bytes = MIME::Base64::decode_base64($b64);
        ok(utf8::decode(my $copy = $bytes), 'each word decodes as whole UTF-8 characters');
        $back .= $bytes;
    }
    utf8::decode($back);
    is($back, $long, 'the words decode to the original');

    my $three = '日本語' x 100;    # three-byte characters
    my @w3 = split / /, Punk::Mailer::_encode_word($three);
    my $ok = 1;
    my $back3 = '';
    for my $w (@w3) {
        my ($b64) = $w =~ /^=\?UTF-8\?B\?(.*)\?=\z/;
        my $bytes = MIME::Base64::decode_base64($b64);
        my $copy = $bytes;
        $ok = 0 unless utf8::decode($copy);     # false on a split character
        $ok = 0 if length $w > 75;
        $back3 .= $bytes;
    }
    utf8::decode($back3);
    ok($ok, 'three-byte characters are never split');
    is($back3, $three, '  and the words decode to the original');
}

# ---- folding ------------------------------------------------------------------------
{
    my $value = join ' ', map { "word$_" } 1 .. 60;
    my $out = Punk::Mailer::_fold('Subject', $value);
    my @lines = split /\r\n/, $out;
    my @long = grep { length $_ > 78 } @lines;
    is(scalar @long, 0, 'every folded line is 78 or fewer');
    my @cont = grep { !/^ / } @lines[1 .. $#lines];
    is(scalar @cont, 0, 'every continuation starts with a space');
    (my $unfolded = $out) =~ s/\r\n(?=[ \t])//g;     # RFC 5322 2.2.3: drop the CRLF, keep the WSP
    is($unfolded, "Subject: $value\r\n", 'unfolding gives the original');

    my $run = 'x' x 1000;
    ok(!eval { Punk::Mailer::_fold('X-Long', $run); 1 }, 'a 1000-character run cannot be a header');
    like($@, qr/no whitespace/, '  and says why');

    my $fits = 'x' x 900;
    like(Punk::Mailer::_fold('X-Long', $fits), qr/^X-Long: x{900}\r\n\z/,
        'a 900-character run goes out whole');
}

# ---- the Date header -----------------------------------------------------------------
is(Punk::Mailer::_date(0), 'Thu, 01 Jan 1970 00:00:00 +0000', 'epoch zero');
is(Punk::Mailer::_date(1787000000), 'Mon, 17 Aug 2026 20:53:20 +0000', 'a 2026 date');

# ---- injection, through build -----------------------------------------------------
{
    my %base = (from => 'ops@example.com', to => 'a@example.com',
                subject => 'hi', text => 'body');
    my @cases = (
        [ 'to',      "a\@example.com\nBcc: x\@evil.example" ],
        [ 'from',    "ops\@example.com\r\nX: y"             ],
        [ 'subject', "hi\r\nBcc: x\@evil.example"           ],
        [ 'subject', "hi\0there"                             ],
    );
    for my $c (@cases) {
        my ($k, $v) = @$c;
        ok(!eval { Punk::Mailer->build({ %base, $k => $v }); 1 }, "injection via $k is refused");
        like($@, qr/carriage return, line feed or NUL|not an address/, '  naming the reason');
    }
    ok(!eval { Punk::Mailer->build({ %base, headers => { 'X-Foo' => "a\nb" } }); 1 },
        'injection via a custom header value is refused');
    ok(!eval { Punk::Mailer->build({ %base, headers => { "X-Foo\nX-Bar" => 'a' } }); 1 },
        'a header name with a newline is refused');
    ok(!eval { Punk::Mailer->build({ %base, headers => { 'X Foo' => 'a' } }); 1 },
        'a header name with a space is refused');
    ok(!eval { Punk::Mailer->build({ %base, headers => { 'Bcc' => 'x@evil.example' } }); 1 },
        'a reserved header cannot be supplied');
    like($@, qr/generated by the builder/, '  and says so');
    ok(!eval { Punk::Mailer->build({ %base, attachments => [ { content => 'x',
        filename => "a\r\nb", type => 'text/plain' } ] }); 1 },
        'injection via an attachment filename is refused');
}

# ---- bcc: envelope only -------------------------------------------------------------
{
    my $spec = { from => 'ops@example.com', to => 'a@example.com',
                 cc => 'c@example.com', bcc => [ 'b@example.com', 'a@example.com' ],
                 subject => 's', text => 't' };
    my $bytes = Punk::Mailer->build($spec);
    unlike($bytes, qr/^Bcc:/mi, 'no Bcc header');
    unlike($bytes, qr/(?<![\w.-])b\@example\.com/, 'the bcc address appears nowhere');
    my $env = Punk::Mailer->envelope($spec);
    is($env->{from}, 'ops@example.com', 'envelope from');
    is_deeply($env->{to}, [ 'a@example.com', 'c@example.com', 'b@example.com' ],
        'envelope recipients: to, cc, bcc, each once');
}

done_testing;
