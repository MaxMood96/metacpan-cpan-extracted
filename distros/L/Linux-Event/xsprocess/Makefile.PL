use strict;
use warnings;
use Config;
use ExtUtils::CBuilder;
use ExtUtils::MakeMaker;

my $builder = ExtUtils::CBuilder->new(quiet => 1);
my ($object, $executable);
my $has_spawn_chdir = eval {
    $object = $builder->compile(source => 'check_spawn_chdir.c');
    $executable = $builder->link_executable(objects => $object);
    1;
};
my $spawn_chdir_error = $@;
unlink grep { defined && -e } $object, $executable;
die "Linux::Event::Process requires a libc with "
    . "posix_spawn_file_actions_addchdir_np.\n$spawn_chdir_error"
    if !$has_spawn_chdir;
my $spawn_chdir_define = ' -DLEP_HAVE_POSIX_SPAWN_CHDIR=1';

WriteMakefile(
    NAME             => 'Linux::Event::Process',
    VERSION_FROM     => '../lib/Linux/Event/Process.pm',
    ABSTRACT         => 'pidfd child processes for Linux::Event',
    AUTHOR           => 'Joshua S. Day <hax@cpan.org>',
    LICENSE          => 'perl_5',
    MIN_PERL_VERSION => '5.036000',
    PM               => {},
    XS               => { 'Process.xs' => 'Process.c' },
    OBJECT           => 'Process$(OBJ_EXT)',
    CCFLAGS          => "$Config{ccflags} -pthread$spawn_chdir_define",
    LIBS             => ['-lpthread'],
    clean            => { FILES => 'Process.c' },
);
