use v5.40;
use blib;
use Test2::V0 '!subtest', -no_srand => 1;
use Test2::Util::Importer 'Test2::Tools::Subtest' => ( subtest_streamed => { -as => 'subtest' } );
use Path::Tiny qw[path];
use File::Temp qw[tempdir];
use Cwd;
use Alien::Xmake::Project;
#
my $old = getcwd;
my $dir = path( tempdir( CLEANUP => 1 ) );
#
subtest 'Perl DSL emits a build file' => sub {
    my $p = Alien::Xmake::Project->new( file => "$dir/xmake.lua" );
    ok $p->set_project('dsl')->set_version('0.1.0') eq $p,     'top level chains return the project';
    ok $p->set_xmakever('2.9.1') eq $p,                        'xmakever chains';
    ok $p->add_requires( 'zlib' => { system => true } ) eq $p, 'project add_requires chains';
    ok $p->add_rules( 'mode.release', 'mode.debug' ) eq $p,    'project rules chain';
    my $t = $p->target('cli');
    isa_ok $t, ['Alien::Xmake::Project::Target'], 'target returns a Target builder';
    ok $t->set_kind('binary')->add_files('src/main.cpp') eq $t,                     'target methods chain';
    ok $t->set_languages('c++20')->set_warnings('all') eq $t,                       'target model methods chain';
    ok $t->add_packages('zlib')->add_values( 'wasm.preloadfiles' => 'a.js' ) eq $t, 'target deps/values chain';
    ok $t->configvar_check_links( 'HAS_PTHREAD', [ 'pthread', 'm' ] ) eq $t,        'configvar_check_links chains';
    ok $t->configvar_check_ctypes( 'HAS_WCHAR', 'wchar_t' ) eq $t,                  'configvar_check_ctypes chains';
    ok $t->check_cincludes( 'HAS_STRING_H', 'string.h' ) eq $t,                     'check_cincludes chains';
    ok $t->when( 'is_plat("windows")', sub { $t->add_links('user32') } ) eq $t,     'scoped condition block chains';
    my $o = $p->option('opt')->set_default('1')->add_links('z');
    isa_ok $o, ['Alien::Xmake::Project::Option'], 'option returns an Option builder';
    my $o2 = $p->option( 'inline_opt', { default => !0, values => [ 'a', 'b' ], showmenu => !0 } );
    isa_ok $o2, ['Alien::Xmake::Project::Option'], 'inline option returns an Option builder';
    my $r = $p->rule('rr')->set_extensions('.xyz');
    isa_ok $r, ['Alien::Xmake::Project::Rule'], 'rule returns a Rule builder';
    my $x = $p->xpack('xp')->set_version('1.0');
    isa_ok $x, ['Alien::Xmake::Project::Xpack'], 'xpack returns an Xpack builder';
    my $comp = $x->component('runtime')->set_default('true')->on_installcmd('function (component) end');
    isa_ok $comp, ['Alien::Xmake::Project::XpackComponent'], 'xpack component returns a builder';
    my $tc = $p->toolchain('gcc')->set_kind('cross');
    isa_ok $tc, ['Alien::Xmake::Project::Toolchain'], 'toolchain returns a Toolchain builder';
    my $pk = $p->package('mypkg')->set_homepage('https://example.com')->on_install( 'windows', 'function (package) end' );
    isa_ok $pk, ['Alien::Xmake::Project::Package'], 'package returns a Package builder';
    my $n = $p->namespace( 'nn', 'add_rules("mode.release")' );
    isa_ok $n, ['Alien::Xmake::Project::Namespace'], 'namespace returns a Namespace builder';
    $p->save;
    ok -f "$dir/xmake.lua", 'save wrote the build file';
    my $lua = path("$dir/xmake.lua")->slurp_utf8;
    like $lua, qr/set_project\("dsl"\)/,                                       'project line emitted';
    like $lua, qr/set_xmakever\("2\.9\.1"\)/,                                  'xmakever emitted';
    like $lua, qr/add_requires\("zlib", \{\["system"\]=true\}\)/,              'project require with opts emitted';
    like $lua, qr/add_rules\("mode\.release", "mode\.debug"\)/,                'project rules emitted';
    like $lua, qr/target\("cli"\)/,                                            'target emitted';
    like $lua, qr/set_kind\("binary"\)/,                                       'kind emitted';
    like $lua, qr/add_files\("src\/main\.cpp"\)/,                              'files emitted';
    like $lua, qr/set_languages\("c\+\+20"\)/,                                 'languages emitted';
    like $lua, qr/set_warnings\("all"\)/,                                      'warnings emitted';
    like $lua, qr/add_packages\("zlib"\)/,                                     'packages emitted';
    like $lua, qr/add_values\("wasm\.preloadfiles", "a\.js"\)/,                'values emitted';
    like $lua, qr/configvar_check_links\("HAS_PTHREAD", \{"pthread", "m"\}\)/, 'configvar check links emitted';
    like $lua, qr/configvar_check_ctypes\("HAS_WCHAR", "wchar_t"\)/,           'configvar check ctypes emitted';
    like $lua, qr/check_cincludes\("HAS_STRING_H", "string\.h"\)/,             'check cincludes emitted';
    like $lua, qr/includes\("\@builtin\/check"\)/,                             'check module included';
    my $check_count = () = $lua =~ /includes\("\@builtin\/check"\)/g;
    is $check_count, 1, 'check module included exactly once';
    like $lua, qr/if is_plat\("windows"\) then\s+add_links\("user32"\)\s+end/, 'scoped condition wraps the guarded statement';
    like $lua, qr/option\("opt"\)/,                                            'option wrapper emitted';
    like $lua, qr/add_links\("z"\)/,                                           'option body emitted';
    like $lua, qr/option\("inline_opt", \{\["default"\]=true, \["showmenu"\]=true, \["values"\]=\{"a", "b"\}\}\)/,
        'inline option emits the table form';
    like $lua, qr/rule\("rr"\)/,                             'rule wrapper emitted';
    like $lua, qr/set_extensions\("\.xyz"\)/,                'rule body emitted';
    like $lua, qr/includes\("\@builtin\/xpack"\)/,           'xpack plugin included once';
    like $lua, qr/xpack\("xp"\)/,                            'xpack wrapper emitted';
    like $lua, qr/xpack_component\("runtime"\)/,             'xpack component wrapper emitted';
    like $lua, qr/set_default\("true"\)/,                    'xpack component body emitted';
    like $lua, qr/xpack_component_end\(\)/,                  'xpack component closed';
    like $lua, qr/xpack_end\(\)/,                            'xpack closed';
    like $lua, qr/toolchain\("gcc"\)/,                       'toolchain wrapper emitted';
    like $lua, qr/set_kind\("cross"\)/,                      'toolchain body emitted';
    like $lua, qr/package\("mypkg"\)/,                       'package wrapper emitted';
    like $lua, qr/set_homepage\("https:\/\/example\.com"\)/, 'package body emitted';
    like $lua, qr/namespace\("nn"\)/,                        'namespace wrapper emitted';
    my $xpack_count = () = $lua =~ /includes\("\@builtin\/xpack"\)/g;
    is $xpack_count, 1, 'xpack include emitted exactly once';
};
#
subtest 'Best practices statements render' => sub {
    my $p = Alien::Xmake::Project->new( file => "$dir/t8.lua" );
    $p->set_project('t8');    # root scope
    ok $p->add_defines('GLOBAL_DEF') eq $p, 'root add_defines chains';
    ok $p->set_arch('x64') eq $p,           'root set_arch chains';
    ok $p->set_languages('c11') eq $p,      'root set_languages chains';
    ok $p->set_toolchains('gcc') eq $p,     'root set_toolchains chains';
    my $t = $p->target('lib');
    ok $t->set_kind('static')->add_files('*.c') eq $t,                                              'policy target built';
    ok $t->set_policy( 'build.merge_archive', !0 ) eq $t,                                           'set_policy chains';
    ok $t->set_policy( 'build.ccache', !0 ) eq $t,                                                  'set_policy(ccache) chains';
    ok $t->add_rules( 'c++.unity_build', { batchsize => 16, uniqueid => 'UNITY' } ) eq $t,          'unity_build rule chains';
    ok $t->set_configvar( 'PACKAGE_VERSION', '1.2.3', { quote => true } ) eq $t,                    'set_configvar chains';
    ok $t->add_configfiles( 'config.h.in', { variables => { PACKAGE_VERSION => '1.2.3' } } ) eq $t, 'add_configfiles chains';
    $p->save;
    my $lua = path("$dir/t8.lua")->slurp_utf8;
    like $lua, qr/add_defines\("GLOBAL_DEF"\)/,                                                         'root add_defines emitted';
    like $lua, qr/set_arch\("x64"\)/,                                                                   'root set_arch emitted';
    like $lua, qr/set_languages\("c11"\)/,                                                              'root set_languages emitted';
    like $lua, qr/set_toolchains\("gcc"\)/,                                                             'root set_toolchains emitted';
    like $lua, qr/set_policy\("build\.merge_archive", true\)/,                                          'policy rendered bare true';
    like $lua, qr/set_policy\("build\.ccache", true\)/,                                                 'ccache policy rendered';
    like $lua, qr/add_rules\("c\+\+\.unity_build", \{\["batchsize"\]="16", \["uniqueid"\]="UNITY"\}\)/, 'unity rule + opts rendered';
    like $lua, qr/set_configvar\("PACKAGE_VERSION", "1\.2\.3", \{\["quote"\]=true\}\)/,                 'configvar rendered';
    like $lua, qr/add_configfiles\("config\.h\.in",/,                                                   'configfiles emitted';
    like $lua, qr/\["PACKAGE_VERSION"\]="1\.2\.3"/,                                                     'configfiles variable rendered';
};
#
subtest 'DSL project configures and builds' => sub {
    mkdir "$dir/src" or die $!;
    path("$dir/src/main.cpp")->spew_utf8("int main(){ return 0; }\n");
    my $p = Alien::Xmake::Project->new( file => "$dir/xmake.lua" );
    $p->add_requires('zlib');
    $p->target('cli')->set_kind('binary')->add_files('src/main.cpp')->add_packages('zlib');
    $p->save;
    chdir $dir or die $!;
    my $x = $p->xmake;
    ok ref($x) eq 'Alien::Xmake',          'xmake returns an Alien::Xmake handle';
    ok $x->configure( mode => 'release' ), 'configure reads the DSL-generated file';
    my $targets = $x->show( 'targets', format => 'json' );
    is $targets, ['cli'], 'targets reflect the DSL project';
    ok $x->build, 'build succeeds from the DSL project';
    my $ti = $x->target_info('cli');
    is $ti->{kind}, 'binary', 'target_info reflects the DSL target';
    ok $x->clean, 'clean from the DSL project';
    chdir $old or die "chdir $old: $!";
};
#
subtest 'xpack packs install archives' => sub {
    my $todo = todo 'xpack fails on Windows without proper archivers and this is not that important...';
    mkdir "$dir/src" unless -d "$dir/src";
    path("$dir/src/packmain.cpp")->spew_utf8("int main(){ return 0; }\n");
    my $p = Alien::Xmake::Project->new( file => "$dir/pack.lua" );
    my $t = $p->target('app');
    $t->set_kind('binary')->add_files('src/packmain.cpp');
    my $xp = $p->xpack('my_pack');
    $xp->set_formats( 'zip', 'targz' );
    $xp->set_title('Pack Demo');
    $xp->set_author('Alien::Xmake');
    $xp->add_targets('app');
    $p->save;
    my $lua = path("$dir/pack.lua")->slurp_utf8;
    like $lua, qr/includes\("\@builtin\/xpack"\)/, 'xpack include emitted';
    like $lua, qr/xpack\("my_pack"\)/,             'xpack wrapper emitted';
    like $lua, qr/set_formats\("zip", "targz"\)/,  'formats emitted';
    like $lua, qr/add_targets\("app"\)/,           'bundle target emitted';
    chdir $dir or die $!;
    my $x = $p->xmake;
    ok $x->configure( mode => 'release' ),           'configure (xpack project)';
    ok $x->build('app'),                             'build before pack';
    ok $x->pack( 'my_pack', jobs => 2 ),             'xmake pack runs';
    ok -e "$dir/build/xpack/my_pack/my_pack.zip",    'zip archive produced';
    ok -e "$dir/build/xpack/my_pack/my_pack.tar.gz", 'tar.gz archive produced';
    chdir $old or die "chdir $old: $!";
};
#
subtest 'table renderer round-trips through lua_json' => sub {
    my $x = Alien::Xmake::Project->new( file => "$dir/x.lua" )->xmake;    # reuses the project dir

    # Note: an empty array [] is deliberately not round-tripped because an empty Lua table {}
    # is ambiguous between {} and [], and json.encode normalizes it to an empty object, so the
    # renderer's [] comes back as {}.
    my @cases = (
        [ 'scalar string',      'hello' ],
        [ 'array of strings',   [ 'pthread', 'm', 'dl' ] ],
        [ 'empty table',        {} ],
        [ 'flat table',         { shared => 'yes', cxx  => '1' } ],
        [ 'nested hash + list', { name   => 'z',   libs => [ 'z', 'm' ], configs => { shared => '1' } } ],
        [ 'array of hashes',    [ { a => '1' }, { b => 'two' } ] ]
    );
    for my $c (@cases) {
        my ( $label, $input ) = @$c;
        my $lua    = Alien::Xmake::Project::Util::_lua_value($input);
        my $parsed = $x->lua_json( "return $lua", return => 1 );
        is $parsed, $input, "table renderer round-trips: $label";
    }

    # v5.36 boolean dualvars render as bare true/false; json round-trips them to
    # JSON::PP::Boolean objects (truthy for true, falsy for false).
    my $lua_bool = Alien::Xmake::Project::Util::_lua_value( { shared => !0, debug => !1 } );
    like $lua_bool, qr/\["shared"\]\s*=\s*true/, 'boolean true emitted bare true';
    like $lua_bool, qr/\["debug"\]\s*=\s*false/, 'boolean false emitted bare false';
    my $parsed_bool = $x->lua_json( "return $lua_bool", return => 1 );
    ok $parsed_bool->{shared} ? 1 : 0,     'boolean true round-trips truthy';
    ok !( $parsed_bool->{debug} ? 1 : 0 ), 'boolean false round-trips falsy';

    # A plain integer scalar is intentionally rendered as a quoted string.
    my $lua_int = Alien::Xmake::Project::Util::_lua_value( { count => 5 } );
    like $lua_int, qr/\["count"\]\s*=\s*"5"/, 'plain integer scalar is quoted';
};
#
subtest 'DSL project convenience execution methods' => sub {
    my $conv_dir = path( tempdir( CLEANUP => 1 ) );
    mkdir "$conv_dir/src" or die $!;
    path("$conv_dir/src/main.cpp")->spew_utf8("int main(){ return 0; }\n");
    my $p = Alien::Xmake::Project->new( file => "$conv_dir/xmake.lua" );
    $p->target('conv_cli')->set_kind('binary')->add_files('src/main.cpp');
    chdir $conv_dir or die $!;
    ok $p->configure( mode => 'release' ), 'direct configure auto-saves and succeeds';
    ok -f "$conv_dir/xmake.lua",           'xmake.lua auto-saved';
    ok $p->build,                          'direct build succeeds';
    my $ti = $p->target_info('conv_cli');
    is $ti->{kind}, 'binary', 'direct target_info returns info';
    ok $p->project('compile_commands'),      'direct project(compile_commands) succeeds';
    ok -f "$conv_dir/compile_commands.json", 'compile_commands.json generated';
    ok $p->clean,                            'direct clean succeeds';
    chdir $old or die "chdir $old: $!";
};
#
done_testing;
