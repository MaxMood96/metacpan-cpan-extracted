package CmpCryptX::PK::RSA;
use Moo;
use Crypt::PK::RSA 0.069;
use namespace::clean;

my $RSA_ALGO_MAP = {
    'RS256'  => [ 'SHA256', 'v1.5' ],
    'RS384'  => [ 'SHA384', 'v1.5' ],
    'RS512'  => [ 'SHA512', 'v1.5' ],
    'PS256'  => [ 'SHA256', 'pss', 32 ],
    'PS384'  => [ 'SHA384', 'pss', 48 ],
    'PS512'  => [ 'SHA512', 'pss', 64 ],
};

has 'can_use_pkcs1_padding'     =>  ( is => 'ro', default => 1 );
has 'can_use_pkcs1_pss_padding' =>  ( is => 'ro', default => 1 );

sub sign {
    my ($self, $request) = @_;
    my $algo = $request->{algorithm};
    my $key  = $request->{key};
    my $rsa = Crypt::PK::RSA->new(\$key);
    return $rsa->sign_message($request->{message}, @{ $RSA_ALGO_MAP->{$algo} });
}

sub verify {
    my ($self, $request) = @_;
    my $algo = $request->{algorithm};
    my $key  = $request->{key};
    my $rsa = Crypt::PK::RSA->new(\$key);
    return $rsa->verify_message($request->{signature}, $request->{message}, @{ $RSA_ALGO_MAP->{$algo} });
}

1;

__END__