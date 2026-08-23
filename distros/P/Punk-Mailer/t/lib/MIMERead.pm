package MIMERead;

use strict;
use warnings;
use MIME::Base64 ();
use MIME::QuotedPrint ();

# A strict reader for what the builder wrote - test-only, and deliberately
# unforgiving: a real mail client tolerates a preamble, a bare LF, a
# missing closing delimiter. This refuses all of them, so a message that
# passes here is one that any reader accepts.
#
#   my $m = MIMERead::parse($bytes);
#   $m->{headers}{subject}        # unfolded, lowercase names
#   $m->{order}                   # header names in the order written
#   $m->{type}, $m->{params}      # Content-Type and its parameters
#   $m->{body}                    # decoded, for a non-multipart part
#   $m->{parts}                   # [ parsed parts ], for a multipart one
#   $m->{encoding}                # the Content-Transfer-Encoding used
#   $m->{raw_body}                # the body before decoding

sub parse {
    my ($bytes) = @_;
    my $idx = index($bytes, "\r\n\r\n");
    die "no header/body separator\n" if $idx < 0;
    my $head = substr($bytes, 0, $idx + 2);
    my $body = substr($bytes, $idx + 4);
    die "a bare LF in the headers\n" if $head =~ /(?<!\r)\n/;

    my (%h, @order);
    my $cur;
    for my $line (split /\r\n/, $head, -1) {
        next if $line eq '';
        if ($line =~ /^[ \t]/) {
            die "continuation with no header\n" unless defined $cur;
            $h{$cur} .= $line;      # fold kept the space, so just append
            next;
        }
        my ($name, $val) = $line =~ /^([!-9;-~]+):[ \t]?(.*)\z/
            or die "malformed header line: $line\n";
        $cur = lc $name;
        die "duplicate header $name\n" if exists $h{$cur} && $cur !~ /^received$/;
        $h{$cur} = $val;
        push @order, $name;
    }
    for my $line (split /\r\n/, $head) {
        die "header line over 998 characters\n" if length $line > 998;
    }

    my $ct = $h{'content-type'} // die "no Content-Type\n";
    my ($type, $rest) = $ct =~ m{^\s*([\w.+-]+/[\w.+-]+)\s*(.*)\z}s
        or die "malformed Content-Type: $ct\n";
    my %params;
    while ($rest =~ /;\s*([\w*-]+)=(?:"((?:[^"\\]|\\.)*)"|([^;\s]+))/g) {
        my ($k, $v) = ($1, defined $2 ? $2 : $3);
        $v =~ s/\\(.)/$1/g if defined $2;
        $params{lc $k} = $v;
    }

    my $out = {
        headers => \%h, order => \@order, type => lc $type, params => \%params,
        raw_body => $body,
    };

    if ($type =~ m{^multipart/}i) {
        my $b = $params{boundary} // die "multipart with no boundary\n";
        die "multipart with a Content-Transfer-Encoding other than 7bit\n"
            if defined $h{'content-transfer-encoding'}
            && lc $h{'content-transfer-encoding'} ne '7bit';
        my $open = "--$b\r\n";
        die "preamble before the first boundary\n"
            unless substr($body, 0, length $open) eq $open;
        my $close = "\r\n--$b--\r\n";
        die "no closing delimiter\n"
            unless substr($body, -length $close) eq $close;
        my $inner = substr($body, length $open, length($body) - length($open) - length($close));
        my @raw = split /\r\n--\Q$b\E\r\n/, $inner, -1;
        $out->{parts} = [ map { parse($_) } @raw ];
        return $out;
    }

    my $enc = lc($h{'content-transfer-encoding'} // '7bit');
    $out->{encoding} = $enc;
    if ($enc eq 'base64') {
        for my $line (split /\r\n/, $body) {
            die "base64 line over 76 characters\n" if length $line > 76;
            die "base64 line with a character outside the alphabet: $line\n"
                if $line =~ m{[^A-Za-z0-9+/=]};
        }
        $out->{body} = MIME::Base64::decode_base64($body);
    }
    elsif ($enc eq 'quoted-printable') {
        for my $line (split /\r\n/, $body, -1) {
            die "quoted-printable line over 76 characters\n" if length $line > 76;
            die "trailing whitespace on a quoted-printable line\n" if $line =~ /[ \t]\z/;
        }
        my $decoded = MIME::QuotedPrint::decode_qp($body);
        $decoded =~ s/(?<!\r)\n/\r\n/g;     # decode_qp turns CRLF into \n; put it back
        $out->{body} = $decoded;
    }
    elsif ($enc eq '7bit') {
        die "8-bit byte in a 7bit body\n" if $body =~ /[\x80-\xff]/;
        die "NUL in a 7bit body\n" if $body =~ /\0/;
        die "bare LF in a 7bit body\n" if $body =~ /(?<!\r)\n/;
        for my $line (split /\r\n/, $body) {
            die "7bit line over 998 characters\n" if length $line > 998;
        }
        $out->{body} = $body;
    }
    else {
        die "unexpected Content-Transfer-Encoding $enc\n";
    }
    return $out;
}

1;
