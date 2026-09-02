use v5.40;
use Test2::V0 '!subtest', -no_srand => 1;
use Test2::Util::Importer 'Test2::Tools::Subtest' => ( subtest_streamed => { -as => 'subtest' } );
use lib 'lib', '../lib', 'blib/lib', '../blib/lib';
use Cwd;
use File::Temp qw[tempdir];
use Alien::Xmake;
#
ok $Alien::Xmake::VERSION, 'Alien::Xmake::VERSION';
#
my $xmake = Alien::Xmake->new;
ok $xmake->version,         'version is set';
ok defined $xmake->buildid, 'buildid is defined-ish';
ok my $exe = $xmake->exe,   'exe works';
`$exe g --theme=plain` if $ENV{AUTOMATED_TESTING};

# Query mode
my @platforms = $xmake->show('platforms');
ok scalar @platforms > 0, 'show -l platforms returns a list';
my $lua_scripts = $xmake->lua( undef, list => 1 );
ok length( $lua_scripts // '' ), 'lua --list returns scripts';
my $macros = $xmake->macro( undef, list => 1 );
ok defined $macros, 'macro list returns output';
my $checks = $xmake->check( undef, list => 1 );
ok defined $checks, 'check list returns output';
subtest 'scaffold a project and drive it' => sub {
    my $old = getcwd;
    my $dir = tempdir( CLEANUP => 1 );
    chdir $dir or die "chdir $dir: $!";
    local $@;
    ok $xmake->create( 't_demo', template => 'console' ), 'create scaffolds a project';
    ok -f 't_demo/xmake.lua',                             'xmake.lua was generated';
    chdir 't_demo' or die 'chdir t_demo: $!';
    ok $xmake->configure( mode => 'debug', jobs => 2 ), 'configure succeeds';
    my $targets = $xmake->show( 'targets', format => 'json' );
    is ref $targets, 'ARRAY', 'show -l targets --format=json is an array';
    ok scalar @{$targets}, 'at least one target';
    ok $xmake->clean,      'clean succeeds';
    chdir $old or die "chdir $old: $!";
};
#
done_testing;
