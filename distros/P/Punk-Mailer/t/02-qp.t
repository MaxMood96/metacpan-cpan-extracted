use strict;
use warnings;
use Test::More;
use MIME::QuotedPrint ();
BEGIN { do './t/sibling.pl' }
use Punk::Mailer;

# quoted-printable: the RFC 2045 rules one at a time, then round trips.

is(Punk::Mailer::_qp("hello\r\n"), "hello\r\n", 'ASCII passes through');
is(Punk::Mailer::_qp("a=b"), "a=3Db", '= is encoded');
is(Punk::Mailer::_qp("end \r\n"), "end=20\r\n", 'a space before CRLF is encoded');
is(Punk::Mailer::_qp("end\t"), "end=09", 'a tab at the end of input is encoded');
is(Punk::Mailer::_qp("a b\r\n"), "a b\r\n", 'a space inside a line is literal');
is(Punk::Mailer::_qp("caf\xc3\xa9"), "caf=C3=A9", '8-bit bytes are encoded');
is(Punk::Mailer::_qp("\0"), "=00", 'NUL is encoded');
is(Punk::Mailer::_qp("one\r\ntwo\r\n"), "one\r\ntwo\r\n", 'CRLF is a line break');

{
    my $line = 'x' x 100;
    my $enc  = Punk::Mailer::_qp("$line\r\n");
    my @lines = split /\r\n/, $enc;
    my @long = grep { length $_ > 76 } @lines;
    is(scalar @long, 0, 'a long line is soft-broken to 76');
    like($lines[0], qr/=\z/, 'the broken line ends with a soft break');
    is(decoded($enc), "$line\r\n", 'and decodes to the original');
}

# MIME::QuotedPrint::decode_qp turns CRLF into the platform newline; put
# it back so the comparison is against the bytes the encoder was given
sub decoded {
    my $out = MIME::QuotedPrint::decode_qp($_[0]);
    $out =~ s/(?<!\r)\n/\r\n/g;
    return $out;
}

{
    # a soft break must not land after a space that then ends the line
    my $line = ('ab ' x 30);
    my $enc  = Punk::Mailer::_qp("$line\r\n");
    my @bad = grep { /[ \t]\z/ } split /\r\n/, $enc;
    is(scalar @bad, 0, 'no line ends with whitespace after a soft break');
    is(decoded($enc), "$line\r\n", 'spaces round-trip');
}

srand 7;
for my $n (0, 1, 10, 77, 300, 2000) {
    my $in = '';
    for (1 .. $n) {
        my $r = rand;
        $in .= $r < 0.05 ? "\r\n" : $r < 0.15 ? chr(128 + int rand 128)
             : $r < 0.20 ? ' ' : chr(33 + int rand 94);
    }
    my $enc = Punk::Mailer::_qp($in);
    my @long = grep { length $_ > 76 } split /\r\n/, $enc;
    is(scalar @long, 0, "$n bytes of mixed input: no line over 76");
    is(decoded($enc), $in, "$n bytes: round-trips");
}

done_testing;
