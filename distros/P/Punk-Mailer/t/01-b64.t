use strict;
use warnings;
use Test::More;
use MIME::Base64 ();
BEGIN { do './t/sibling.pl' }
use Punk::Mailer;

# the streaming base64 encoder: RFC 4648 vectors, 76-column CRLF lines,
# and the property that matters for attachments - the chunking of the
# input never changes the output.

my %vec = (
    ''       => '',
    'f'      => 'Zg==',
    'fo'     => 'Zm8=',
    'foo'    => 'Zm9v',
    'foob'   => 'Zm9vYg==',
    'fooba'  => 'Zm9vYmE=',
    'foobar' => 'Zm9vYmFy',
);
for my $in (sort keys %vec) {
    is(Punk::Mailer::_b64_plain($in), $vec{$in}, "plain: '$in'");
}

srand 42;
sub bytes { my $n = shift; join '', map { chr int rand 256 } 1 .. $n }

for my $n (0, 1, 2, 3, 56, 57, 58, 75, 76, 114, 115, 200, 1000) {
    my $in  = bytes($n);
    my $enc = Punk::Mailer::_b64($in);
    if ($n == 0) {
        is($enc, '', 'nothing in, nothing out');
        next;
    }
    like($enc, qr/\r\n\z/, "$n bytes: the output ends with CRLF");
    my @lines = split /\r\n/, $enc;
    my @long = grep { length $_ > 76 } @lines;
    is(scalar @long, 0, "$n bytes: no line over 76");
    if (@lines > 1) {
        my @short = grep { length $_ != 76 } @lines[0 .. $#lines - 1];
        is(scalar @short, 0, "$n bytes: every line but the last is exactly 76");
    }
    is(MIME::Base64::decode_base64($enc), $in, "$n bytes: decodes to the input");
    is(length $enc, Punk::Mailer::_b64_wrapped_len($n),
        "$n bytes: _b64_wrapped_len predicted the length");
}

{
    my $in  = bytes(1000);
    my $whole = Punk::Mailer::_b64($in);
    for my $chunk (1, 2, 3, 4, 5, 7, 56, 57, 58, 333, 999) {
        is(Punk::Mailer::_b64_chunked($in, $chunk), $whole,
            "feeding $chunk bytes at a time gives the same output");
    }
}

# two tokens are never alike, and are base64url
{
    my ($a, $b) = (Punk::Mailer::_token(), Punk::Mailer::_token());
    like($a, qr/^[A-Za-z0-9_-]{24}\z/, 'a token is 24 base64url characters');
    isnt($a, $b, 'and two differ');
}

done_testing;
