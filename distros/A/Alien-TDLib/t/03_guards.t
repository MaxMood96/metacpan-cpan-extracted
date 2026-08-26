use strict;
use warnings;
use Test::More;

my $af = 'alienfile';
plan skip_all => 'run from the dist root' unless -f $af;

# The guards are exposed for testing via Alien::TDLib::Guards, loaded by the alienfile.
require './inc/Alien/TDLib/Guards.pm';

is Alien::TDLib::Guards::job_count(8, 16), 8, 'plenty of RAM: use all cores';
is Alien::TDLib::Guards::job_count(8, 3),  2, '3GB RAM caps jobs at 2';
is Alien::TDLib::Guards::job_count(8, 1),  1, 'never returns zero';
is Alien::TDLib::Guards::job_count(2, 64), 2, 'never exceeds the core count';

{
    local $ENV{ALIEN_TDLIB_JOBS} = '3';
    is Alien::TDLib::Guards::job_count(8, 16), 3, 'env override wins';
}

ok !Alien::TDLib::Guards::find_tool('definitely-not-a-real-tool-xyz'),
    'find_tool returns false for a missing tool';
ok Alien::TDLib::Guards::find_tool('perl'), 'find_tool finds perl';

is_deeply [Alien::TDLib::Guards::_exe_exts('linux', undef)], [''],
    'no extension candidates off Windows';
is_deeply [Alien::TDLib::Guards::_exe_exts('MSWin32', undef)], ['', '.exe'],
    '.exe fallback when PATHEXT is unset';
is_deeply [Alien::TDLib::Guards::_exe_exts('MSWin32', '.COM;.EXE;.BAT')],
    ['', '.COM', '.com', '.EXE', '.exe', '.BAT', '.bat'],
    'PATHEXT suffixes after the bare name, both cases';
is_deeply [Alien::TDLib::Guards::_exe_exts('MSWin32', '.EXE;.exe')], ['', '.EXE', '.exe'],
    'duplicate PATHEXT entries collapse';

{
    require File::Temp;
    my $dir = File::Temp::tempdir(CLEANUP => 1);
    open my $fh, '>', "$dir/cmake.exe" or die $!;
    close $fh;
    chmod 0755, "$dir/cmake.exe";

    ok !Alien::TDLib::Guards::find_tool('cmake', { os => 'linux', dirs => [$dir] }),
        'bare-name platforms ignore .exe files';
    is Alien::TDLib::Guards::find_tool('cmake',
        { os => 'MSWin32', dirs => [$dir], pathext => '.COM;.EXE;.BAT' }),
        "$dir/cmake.exe", 'PATHEXT entry finds cmake.exe';
    is Alien::TDLib::Guards::find_tool('cmake',
        { os => 'MSWin32', dirs => [$dir] }),
        "$dir/cmake.exe", 'unset PATHEXT falls back to .exe';
}

{
    require File::Temp;
    my $dir = File::Temp::tempdir(CLEANUP => 1);

    my $both = "$dir/meminfo-both";
    open my $fh, '>', $both or die $!;
    print $fh "MemTotal:       16777216 kB\nMemAvailable:     3145728 kB\n";
    close $fh;
    is Alien::TDLib::Guards::ram_gb($both), 3, 'ram_gb prefers MemAvailable';

    my $total_only = "$dir/meminfo-total";
    open $fh, '>', $total_only or die $!;
    print $fh "MemTotal:       16777216 kB\n";
    close $fh;
    is Alien::TDLib::Guards::ram_gb($total_only), 16, 'ram_gb falls back to MemTotal';

    is Alien::TDLib::Guards::ram_gb("$dir/not-there"), 0, 'unreadable meminfo gives 0';
}

is Alien::TDLib::Guards::build_jobs(8, 16), 7, 'leaves one core free';
is Alien::TDLib::Guards::build_jobs(8, 3),  2, 'RAM limit still applies under the cap';
is Alien::TDLib::Guards::build_jobs(2, 64), 1, 'cap never exceeds nproc-1';
is Alien::TDLib::Guards::build_jobs(1, 64), 1, 'cap floor is one job';

{
    local $ENV{ALIEN_TDLIB_JOBS} = '8';
    is Alien::TDLib::Guards::build_jobs(8, 16), 8, 'env override is not capped';
}

{
    require File::Temp;
    my $dir = File::Temp::tempdir(CLEANUP => 1);

    my $cpuinfo = "$dir/cpuinfo";
    open my $fh, '>', $cpuinfo or die $!;
    print $fh "processor\t: 0\nprocessor\t: 1\nprocessor\t: 2\nprocessor\t: 3\n";
    close $fh;
    is Alien::TDLib::Guards::cpuinfo_count($cpuinfo), 4, 'cpuinfo_count counts processors';

    open $fh, '>', "$dir/cpuinfo-empty" or die $!;
    close $fh;
    ok !defined(Alien::TDLib::Guards::cpuinfo_count("$dir/cpuinfo-empty")),
        'cpuinfo without processor lines gives undef';
    ok !defined(Alien::TDLib::Guards::cpuinfo_count("$dir/not-there")),
        'missing cpuinfo gives undef';
}

is Alien::TDLib::Guards::sysctl_count('echo 8'), 8, 'sysctl_count parses a number';
is Alien::TDLib::Guards::sysctl_count('echo "  16  "'), 16, 'surrounding space tolerated';
ok !defined(Alien::TDLib::Guards::sysctl_count('echo garbage')), 'non-numeric gives undef';
ok !defined(Alien::TDLib::Guards::sysctl_count('echo 0')), 'zero gives undef';
ok !defined(Alien::TDLib::Guards::sysctl_count('exit 1')), 'command failure gives undef';

ok Alien::TDLib::Guards::cpu_count() >= 1, 'cpu_count never returns less than 1';

done_testing;
