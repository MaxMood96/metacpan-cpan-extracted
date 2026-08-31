package PPKTest;

use 5.010;
use strict;
use warnings;
use Exporter 'import';
use FindBin ();
use MIME::Base64 ();

our @EXPORT_OK = qw(fixture_dir fixture b64u_decode b64u_encode hex_to_bytes
                    have_openssl openssl_accepts_pem auth_data cose_bytes);

sub fixture_dir { "$FindBin::Bin/fixtures" }

# One key=value fixture file as a hashref.
sub fixture {
    my ($name) = @_;
    my $path = fixture_dir() . "/$name";
    open my $fh, '<', $path or die "PPKTest: cannot read $path: $!";
    my %f;
    while (my $line = <$fh>) {
        chomp $line;
        next unless $line =~ /\A(\w+)=(.*)\z/;
        $f{$1} = $2;
    }
    close $fh;
    return \%f;
}

sub b64u_decode {
    my ($s) = @_;
    $s =~ tr{-_}{+/};
    $s .= '=' x ((4 - length($s) % 4) % 4);
    return MIME::Base64::decode_base64($s);
}

sub b64u_encode {
    my ($b) = @_;
    my $s = MIME::Base64::encode_base64($b, '');
    $s =~ tr{+/}{-_};
    $s =~ s/=+\z//;
    return $s;
}

sub hex_to_bytes { my ($h) = @_; $h =~ s/\s+//g; return pack 'H*', $h }

# authenticatorData is a fixed binary layout, not CBOR - so it is read
# here by hand, which also keeps these helpers independent of the
# decoder they are used to test.
#
#   32  rpIdHash
#    1  flags   (bit 0 UP, bit 2 UV, bit 6 AT)
#    4  signCount, big-endian
#   then, when AT is set:
#   16  AAGUID
#    2  credentialIdLength
#    n  credentialId
#       the COSE public key, and any extensions behind it
sub auth_data {
    my ($bytes) = @_;
    return undef if length $bytes < 37;
    my %d = (
        rpIdHash  => substr($bytes, 0, 32),
        flags     => ord substr($bytes, 32, 1),
        signCount => unpack('N', substr($bytes, 33, 4)),
    );
    $d{up} = ($d{flags} & 0x01) ? 1 : 0;
    $d{uv} = ($d{flags} & 0x04) ? 1 : 0;
    $d{at} = ($d{flags} & 0x40) ? 1 : 0;
    if ($d{at} && length $bytes >= 55) {
        $d{aaguid}    = substr($bytes, 37, 16);
        my $len       = unpack 'n', substr($bytes, 53, 2);
        $d{credentialId} = substr($bytes, 55, $len);
        $d{cose}      = substr($bytes, 55 + $len);
    }
    return \%d;
}

# The COSE key bytes out of a decoded attestation object.
sub cose_bytes {
    my ($decoded) = @_;
    return undef unless ref $decoded eq 'HASH' && defined $decoded->{authData};
    my $ad = auth_data($decoded->{authData}) or return undef;
    return $ad->{cose};
}

sub have_openssl {
    my $v = `openssl version 2>/dev/null`;
    return $v && $v =~ /openssl/i ? 1 : 0;
}

# openssl as the oracle: does it accept this PEM as a public key, and
# what does it say the key is? Returns (ok, text).
sub openssl_accepts_pem {
    my ($pem) = @_;
    my $tmp = "ppk-key-$$-" . int(rand 1e6) . ".pem";
    open my $fh, '>', $tmp or die $!;
    print {$fh} $pem;
    close $fh;
    my $out = `openssl pkey -pubin -in $tmp -noout -text 2>&1`;
    unlink $tmp;
    return (($? == 0 ? 1 : 0), $out);
}

1;
