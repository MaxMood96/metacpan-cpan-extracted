package CmpCryptPerl::Perl::ECC;
use Moo;
use Crypt::Perl 0.38;
use Crypt::Perl::ECDSA::Parse;
use Try::Tiny;
use namespace::clean;

my $ECC_ALGO_MAP = {
    ES256 => 66,
    ES384 => 96,
    ES512 => 132,
};

sub can_do_deterministic { 1; }
sub can_do_non_deterministic { 0; }

sub sign {
    my ($self, $request) = @_;
    my $algorithm = $request->{algorithm};
    my $ecc = Crypt::Perl::ECDSA::Parse::private($request->{key});
    my $jwaalg = $ecc->get_jwa_alg();
    die qq(key is type $jwaalg but your requested algorithm is $algorithm) unless ( $algorithm eq $jwaalg );
    $ecc->sign_jwa($request->{message});
}

sub verify {
    my ($self, $request) = @_;
    my $algorithm = $request->{algorithm};
    my $ecc = Crypt::Perl::ECDSA::Parse::public($request->{key});
    my $jwaalg = $ecc->get_jwa_alg();
    die qq(key is type $jwaalg but your requested algorithm is $algorithm) unless ( $algorithm eq $jwaalg );
    $ecc->verify_jwa($request->{message}, $request->{signature});
}

1;

__END__
