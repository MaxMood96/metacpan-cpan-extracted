package CmpCryptX;
use Moo;
use CmpCryptX::PK::ECC;
use CmpCryptX::PK::RSA;
extends 'Crypt::JWS::OpenSSL';

sub _build_rsa_handler {
    return CmpCryptX::PK::RSA->new;
}

sub _build_ecc_handler {
    return CmpCryptX::PK::ECC->new;
}

1;