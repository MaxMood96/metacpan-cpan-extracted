package Alien::TDLib::Guards;

use strict;
use warnings;

# try the bare name, then each PATHEXT suffix, as-is and lowercased
sub _exe_exts {
    my ($os, $pathext) = @_;
    return ('') unless $os eq 'MSWin32';
    my @exts = ('');
    for my $ext (defined $pathext && length $pathext ? split(/;/, $pathext) : ('.exe')) {
        for my $e ($ext, lc $ext) {
            next unless length $e;
            push @exts, $e unless grep { $_ eq $e } @exts;
        }
    }
    return @exts;
}

sub find_tool {
    my ($tool, $opt) = @_;
    $opt //= {};
    require File::Spec;
    my @dirs = @{ $opt->{dirs} // [File::Spec->path] };
    for my $dir (@dirs) {
        for my $ext (_exe_exts($opt->{os} // $^O, $opt->{pathext} // $ENV{PATHEXT})) {
            my $path = File::Spec->catfile($dir, "$tool$ext");
            return $path if -x $path && !-d _;
        }
    }
    return undef;
}

sub cpu_count {
    my $n = eval { require Sys::Info; Sys::Info->new->device('CPU')->count };
    return $n if $n;
    # /proc/cpuinfo is Linux-only; sysctl hw.ncpu covers macOS and the BSDs
    $n = cpuinfo_count('/proc/cpuinfo');
    return $n if $n;
    $n = sysctl_count();
    return $n if $n;
    return 1;
}

sub cpuinfo_count {
    my ($file) = @_;
    open my $fh, '<', $file or return undef;
    my $c = grep { /^processor\s*:/ } <$fh>;
    return $c || undef;
}

sub sysctl_count {
    my ($cmd) = @_;
    my @cmds = defined $cmd ? ($cmd) : ('sysctl -n hw.ncpu', '/usr/sbin/sysctl -n hw.ncpu');
    for my $c (@cmds) {
        my $out = `$c 2>/dev/null`;
        next if !defined $out || $?;
        return $1 if $out =~ /^\s*(\d+)\s*$/ && $1 > 0;
    }
    return undef;
}

sub ram_gb {
    my ($file) = @_;
    $file //= '/proc/meminfo';
    open my $fh, '<', $file or return 0;
    my %m;
    while (<$fh>) { $m{$1} = $2 if /^(MemAvailable|MemTotal):\s+(\d+)\s+kB/ }
    my $kb = $m{MemAvailable} // $m{MemTotal} // 0;
    return int($kb / 1024 / 1024);
}

# TDLib needs ~1GB per translation unit under GCC; this keeps it off the OOM killer
use constant GB_PER_JOB => 1.5;

sub job_count {
    my ($cpus, $gb) = @_;
    return $ENV{ALIEN_TDLIB_JOBS} if $ENV{ALIEN_TDLIB_JOBS};
    my $by_ram = $gb ? int($gb / GB_PER_JOB) : $cpus;
    my $n = $by_ram < $cpus ? $by_ram : $cpus;
    return $n < 1 ? 1 : $n;
}

sub build_jobs {
    my ($cpus, $gb) = @_;
    return $ENV{ALIEN_TDLIB_JOBS} if $ENV{ALIEN_TDLIB_JOBS};
    $cpus //= cpu_count();
    $gb   //= ram_gb();
    my $cap = $cpus - 1;
    $cap = 1 if $cap < 1;
    my $n = job_count($cpus, $gb);
    return $n < $cap ? $n : $cap;
}

1;
