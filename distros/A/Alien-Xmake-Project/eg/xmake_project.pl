use v5.40;
use blib;
use Alien::Xmake::Project;
use Cwd qw[getcwd];
use Path::Tiny;

# This is a full walkthrough of Alien::Xmake::Project. Instead of hand-writing xmake.lua (Lua),
# describe the project with chained Perl method calls, save() the generated build file, and drive
# every stage (configure, build, clean) through the returned Alien::Xmake handle. The demo is
# self-contained (no external packages), so it builds offline with whatever compiler is present.
my $dir  = Path::Tiny->tempdir;
my $orig = getcwd;
chdir $dir or die "chdir $dir: $!";

# src/main.cpp for the demo
path('src')->mkpath;
path('src/main.cpp')->spew_utf8(<<~'CPP');
    #include <cstdio>
    #include <string>
    int main() {
        std::puts("hello from Alien::Xmake::Project");
        return 0;
    }
    CPP
my $p = Alien::Xmake::Project->new(
    file => 'xmake.lua',    # where save() writes the build file
    yes  => 1               # auto-confirm prompts (never hang on a TTY)
);

# project identity at the global scope
$p->set_project('demo')->set_version('0.1.0')->set_xmakever('3.1.1');
$p->add_rules( 'mode.debug', 'mode.release' );

# Targets:
# target() returns a builder; every set_*/add_* call returns it too, so the
# whole description is one long chain. add_requires() would pull from xrepo
# (needs network) - omitted here to keep the demo building offline.
$p->target('demo')
    ->set_kind('binary')
    ->set_languages('c++20')
    ->set_warnings('all')
    ->set_optimize('fastest')
    ->add_files('src/main.cpp')
    ->add_defines('DEMO_VERSION="0.1.0"')

    # when() scopes a group of statements behind a compile-time predicate
    # (is_plat / is_os / is_arch / is_mode / ... or any Lua expression).
    ->when( 'is_plat("windows")', sub ($t) { $t->add_defines('WIN32_LEAN_AND_MEAN') } );

# write the build file and show what we generated
$p->save;
say 'Wrote xmake.lua';
say path('xmake.lua')->slurp_utf8;

# Drive it via Alien::Xmake handle
say 'Configuring (release)...';
die 'configure failed' unless $p->configure( mode => 'release' );
say 'Building...';
die 'build failed' unless $p->build;
say 'Running...';
$p->xmake->run;
say 'Querying available platforms...';
say "  - $_" for $p->show('platforms');
say 'Cleaning...';
$p->clean;
chdir $orig or die "chdir $orig: $!";    # Go home just in case
