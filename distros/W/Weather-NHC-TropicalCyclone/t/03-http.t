use strict;
use warnings;
use lib 't/lib';
use Test::More;
use MockHTTP;
use Weather::NHC::TropicalCyclone::HTTP ();

sub dies_like (&$;$) {
    my ( $code, $re, $name ) = @_;
    my $ok = eval { $code->(); 1 };
    my $err = $@;
    ok !$ok && $err =~ $re, $name;
}

my $mock = MockHTTP->new(
    routes => {
        'mock://ok'     => { success => 1, status => 200, content => 'ok' },
        'mock://status' => { status => 204, content => q{} },
        'mock://fail'   => { success => 0, status => 503, content => q{} },
    },
    mirror => {
        'mock://mirror-ok'   => { success => 1, status => 200, content => 'file' },
        'mock://mirror-fail' => { success => 0, status => 500 },
    },
);

{
    local %ENV = %ENV;
    delete @ENV{qw/http_proxy HTTP_PROXY https_proxy HTTPS_PROXY all_proxy ALL_PROXY/};
    my $default_http = Weather::NHC::TropicalCyclone::HTTP->new;
    isa_ok $default_http->client, 'HTTP::Tiny', 'default HTTP::Tiny client';
}

my $http = Weather::NHC::TropicalCyclone::HTTP->new( client => $mock );
is $http->client, $mock, 'client accessor';
is $http->get('mock://ok')->{content}, 'ok', 'successful get';
is $http->get('mock://status')->{status}, 204, '2xx status works without success key';

dies_like { $http->get('mock://fail') } qr/503/, 'get failure includes status';
dies_like { $http->get('mock://missing') } qr/404/, 'missing mock route fails';

my $file = 't-http-mirror.tmp';
unlink $file;
ok $http->mirror('mock://mirror-ok', $file)->{success}, 'successful mirror';
ok -e $file, 'mirror wrote file';
unlink $file;
dies_like { $http->mirror('mock://mirror-fail', $file) } qr/500/, 'mirror failure includes status';

my $undef = bless {}, 'UndefHTTP';
{
    no strict 'refs';
    *{'UndefHTTP::get'} = sub { return undef };
}
my $bad = Weather::NHC::TropicalCyclone::HTTP->new( client => $undef );
dies_like { $bad->get('mock://undef') } qr/Unknown/, 'undef response handled';

done_testing;
