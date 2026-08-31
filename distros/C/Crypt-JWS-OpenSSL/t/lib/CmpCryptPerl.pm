package CmpCryptPerl;
use Moo;
use CmpCryptPerl::Perl::ECC;
use CmpCryptPerl::Perl::RSA;

extends 'Crypt::JWS::OpenSSL';

sub _build_rsa_handler {
    return CmpCryptPerl::Perl::RSA->new;
}

sub _build_ecc_handler {
    return CmpCryptPerl::Perl::ECC->new;
}

1;