package CmpCryptPerl::Perl::RSA;
use Moo;
use Crypt::Perl 0.38;
use Crypt::Perl::RSA::Parse;
use namespace::clean;

my $RSA_ALGO_MAP = {
    RS256  => [ 'sign_RS256', 'verify_RS256' ],
    RS384  => [ 'sign_RS384', 'verify_RS384' ],
    RS512  => [ 'sign_RS512', 'verify_RS512' ],
};

has 'can_use_pkcs1_padding'     =>  ( is => 'ro', default => 1 );

has 'can_use_pkcs1_pss_padding' =>  ( is => 'ro', default => 0 );

sub sign {
    my ($self, $request) = @_;
    my $algorithm = $request->{algorithm};
    my $rsa = Crypt::Perl::RSA::Parse::private($request->{key});
    my $method = $RSA_ALGO_MAP->{$algorithm}->[0];
    return $rsa->$method($request->{message});
}

sub verify {
    my ($self, $request) = @_;
    my $algorithm = $request->{algorithm};
    my $rsa = Crypt::Perl::RSA::Parse::public($request->{key});
    my $method = $RSA_ALGO_MAP->{$algorithm}->[1];
    return $rsa->$method($request->{message}, $request->{signature});
}

1;

__END__
