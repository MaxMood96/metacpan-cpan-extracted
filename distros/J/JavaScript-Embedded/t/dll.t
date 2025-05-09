use lib './lib';
use strict;
use warnings;
use JavaScript::Embedded;
use JavaScript::Embedded::C::libPath;
use Data::Dumper;
use Test::More;

if (!$ENV{DUK_DEV}) {
    plan skip_all => 'DEV test';
}

my $js  = JavaScript::Embedded->new();
my $duk = $js->duk;

my $path    = JavaScript::Embedded::C::libPath::getPath('../C');
my $duktape = JavaScript::Embedded::C::libPath::getPath('lib/duktape.c');

my $build = "gcc -Wall -I$path $duktape ./t/dll.c -shared -fPIC -o dll.shared";
system($build) && plan skip_all => "Can't compile shared library using gcc compiler";

my $dll = $duk->duktape_dlOpen("./dll.shared");
my $fn  = $duk->to_perl(-1);

my $ret = $fn->{add_number}->( 5, 5 );

is( $ret, 10 );

ok $duk->duktape_dlClose($dll);
unlink 'dll.shared' or fail $!;

done_testing();
