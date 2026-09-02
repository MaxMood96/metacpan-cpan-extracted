package CmpCryptX::PK::ECC;
use Moo;
with qw( Crypt::JWS::OpenSSL::Role::Encoder );
use Crypt::PK::ECC 0.069;
use Digest::SHA ();
use version;
use namespace::clean;

my $ECC_ALGO_MAP = {
    'ES256' => [ 'SHA256', \&Digest::SHA::sha256 ],
    'ES384' => [ 'SHA384', \&Digest::SHA::sha384 ],
    'ES512' => [ 'SHA512', \&Digest::SHA::sha512 ],
};

has '_is_dt_version' => ( is => 'lazy');

sub can_do_deterministic { shift->_is_dt_version; }

sub can_do_non_deterministic { 1; }

sub sign {
    my ($self, $request) = @_;
    my $algo = $request->{algorithm};
    my $key  = $request->{key};
    
    my( $algotext, $hash_method ) = @{ $ECC_ALGO_MAP->{$algo} };
    
    my $ecc_key  = Crypt::PK::ECC->new(\$key);
    
    if ( $request->{non_deterministic} ) {
        return $ecc_key->sign_message_rfc7518($request->{message}, $algotext);
    } else {
        my $digest = $hash_method->($request->{message});        
        return $ecc_key->sign_hash_rfc7518($digest, $algotext, $algotext);
    }
}

sub verify {
    my ($self, $request) = @_;
    my $algo = $request->{algorithm};
    my $key  = $request->{key};
    
    my( $algotext, $hash_method ) = @{ $ECC_ALGO_MAP->{$algo} };
    
    my $ecc_key = Crypt::PK::ECC->new(\$key);
    
    return $ecc_key->verify_message_rfc7518($request->{signature}, $request->{message}, $algotext);
}

sub _build__is_dt_version {
    my $self = shift;
    my $checkver = $self->numify_version( $Crypt::PK::ECC::VERSION );
    return ( $checkver >= 0.088 ) ? 1 : 0;
}

1;

__END__