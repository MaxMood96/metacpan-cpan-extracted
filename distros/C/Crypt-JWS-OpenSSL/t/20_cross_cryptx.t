use Test::More;
use Test::Deep;
use JSON::MaybeXS 1.002002 ();
use lib 't/lib';

BEGIN {
    eval {
        require Crypt::PK::RSA;
        Crypt::PK::RSA->VERSION(0.069);
        require Crypt::PK::ECC;
        Crypt::PK::ECC->VERSION(0.069);
    };
    
    if( $@ ) {
        plan skip_all => qq(required version of CryptX not installed for comparision);
        done_testing;
    };
       
    use_ok('Crypt::JWS::OpenSSL');
    use_ok('CmpCryptX');
}


## using canonical JSON ordering for tests. DON'T do this in production
our $H1NAME = 'OpenSSL';
our $H1 = Crypt::JWS::OpenSSL->new( 'JSON' => JSON::MaybeXS->new->canonical->utf8(1) );
$H1->throw_errors(1);

our $H2NAME = 'CryptX';
our $H2 = CmpCryptX->new( 'JSON' => JSON::MaybeXS->new->canonical->utf8(1) );
$H2->throw_errors(1);

do 'token_cross.pl' or die( $@ || $! );

done_testing;

1;
