use Test::More;
use Crypt::OpenSSL::Guess qw/openssl_version/;
use Crypt::OpenSSL::Verify;

diag(openssl_version);
use_ok('Crypt::OpenSSL::Verify');

my $v = Crypt::OpenSSL::Verify->new();
isa_ok($v, 'Crypt::OpenSSL::Verify', "Crypt::OpenSSL::Verify::new()");

eval {
    $v = Crypt::OpenSSL::Verify->new('t/cacert.pem', '');
};
like($@, qr/Invalid type/, "Second parameter not a hash - Invalid type");

$v = Crypt::OpenSSL::Verify->new('t/cacert.pem', {});
isa_ok($v, 'Crypt::OpenSSL::Verify', "Crypt::OpenSSL::Verify::new('t/cacert.pem', {})");

$v = Crypt::OpenSSL::Verify->new(undef);
isa_ok($v, 'Crypt::OpenSSL::Verify', "Crypt::OpenSSL::Verify::new(undef)");

$v = Crypt::OpenSSL::Verify->new(undef, {});
isa_ok($v, 'Crypt::OpenSSL::Verify', "Crypt::OpenSSL::Verify::new(undef, {})");

done_testing;
