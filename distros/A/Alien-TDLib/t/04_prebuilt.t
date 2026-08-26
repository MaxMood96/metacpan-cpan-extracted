use strict;
use warnings;
use Test::More;

plan skip_all => 'run from the dist root' unless -f 'alienfile';

require './inc/Alien/TDLib/Prebuilt.pm';

is Alien::TDLib::Prebuilt::platform('linux', 'x64', 0),   'linux-x64-glibc',   'linux x64 glibc';
is Alien::TDLib::Prebuilt::platform('linux', 'x64', 1),   'linux-x64-musl',    'linux x64 musl';
is Alien::TDLib::Prebuilt::platform('linux', 'arm64', 0), 'linux-arm64-glibc', 'linux arm64 glibc';
is Alien::TDLib::Prebuilt::platform('linux', 'arm64', 1), 'linux-arm64-musl',  'linux arm64 musl';
is Alien::TDLib::Prebuilt::platform('darwin', 'x64'),     'darwin-x64',        'darwin x64';
is Alien::TDLib::Prebuilt::platform('darwin', 'arm64'),   'darwin-arm64',      'darwin arm64';
is Alien::TDLib::Prebuilt::platform('MSWin32', 'x64'),    'win32-x64',         'win32 x64';
ok !defined(Alien::TDLib::Prebuilt::platform('MSWin32', 'arm64')), 'no win32-arm64 package';
ok !defined(Alien::TDLib::Prebuilt::platform('freebsd', 'x64')),   'no freebsd package';
ok !defined(Alien::TDLib::Prebuilt::platform('openbsd', 'x64')),   'no openbsd package';
ok !defined(Alien::TDLib::Prebuilt::platform('netbsd', 'x64')),    'no netbsd package';
{
    my $arch = Alien::TDLib::Prebuilt::machine_arch();
    is Alien::TDLib::Prebuilt::platform('linux', undef, 0),
        (defined $arch ? "linux-$arch-glibc" : undef),
        'undef arch falls back to uname';
}

is Alien::TDLib::Prebuilt::machine_arch('x86_64'), 'x64',   'x86_64 is x64';
is Alien::TDLib::Prebuilt::machine_arch('amd64'),  'x64',   'amd64 is x64';
is Alien::TDLib::Prebuilt::machine_arch('aarch64'), 'arm64', 'aarch64 is arm64';
is Alien::TDLib::Prebuilt::machine_arch('arm64'),  'arm64', 'arm64 is arm64';
ok !defined(Alien::TDLib::Prebuilt::machine_arch('riscv64')), 'riscv64 unmapped';

SKIP: {
    skip 'musl detection is a linux affair', 3 unless $^O eq 'linux';
    my $m = Alien::TDLib::Prebuilt::detect_musl();
    ok $m == 0 || $m == 1, 'detect_musl returns a boolean';
    my $ldd = `ldd --version 2>&1` // '';
    is $m, 1, 'ldd says musl'  if $ldd =~ /musl/i;
    is $m, 0, 'ldd says glibc' if $ldd =~ /glibc|gnu libc/i;
    my $pldd = `ldd "$^X" 2>&1` // '';
    is $m, ($pldd =~ /musl/i ? 1 : 0), 'agrees with the libc perl links against'
        if $pldd =~ /musl|ld-linux/;
}

is Alien::TDLib::Prebuilt::tarball_url('linux-x64-glibc'),
    'https://registry.npmjs.org/@prebuilt-tdlib/linux-x64-glibc/-/linux-x64-glibc-0.1008066.0.tgz',
    'tarball url shape';
is Alien::TDLib::Prebuilt::metadata_url('darwin-arm64'),
    'https://registry.npmjs.org/@prebuilt-tdlib%2Fdarwin-arm64',
    'metadata url shape';

is Alien::TDLib::Prebuilt::shared_lib_name('linux-x64-musl'), 'libtdjson.so',    'linux lib name';
is Alien::TDLib::Prebuilt::shared_lib_name('darwin-arm64'),   'libtdjson.dylib', 'darwin lib name';
is Alien::TDLib::Prebuilt::shared_lib_name('win32-x64'),      'tdjson.dll',      'win32 lib name';

{
    require File::Temp;
    my $dir = File::Temp::tempdir(CLEANUP => 1);
    my $file = "$dir/blob";
    open my $fh, '>', $file or die $!;
    print $fh "abc";
    close $fh;

    my $integrity = Alien::TDLib::Prebuilt::npm_integrity($file);
    like $integrity, qr/^sha512-[A-Za-z0-9+\/]+={0,2}$/, 'integrity string shape';
    is length(substr($integrity, 7)) % 4, 0, 'base64 payload is padded';
    ok Alien::TDLib::Prebuilt::integrity_matches($file, $integrity), 'matches itself';
    ok Alien::TDLib::Prebuilt::integrity_matches($file, "sha512-AAAA $integrity"), 'any token may match';
    ok !Alien::TDLib::Prebuilt::integrity_matches($file, 'sha512-AAAA'), 'mismatch detected';
    ok !Alien::TDLib::Prebuilt::integrity_matches($file, undef), 'undef integrity never matches';
}

{
    require File::Temp;
    my $dir = File::Temp::tempdir(CLEANUP => 1);

    my $write = sub {
        my ($sub, $json) = @_;
        my $d = defined $sub ? "$dir/$sub" : $dir;
        mkdir "$dir/$sub" if defined $sub;
        open my $fh, '>', "$d/package.json" or die $!;
        print $fh $json;
        close $fh;
        return $d;
    };

    my $good = $write->(undef, sprintf
        '{"name":"x","tdlib":{"commit":"%s","version":"%s"}}',
        $Alien::TDLib::Prebuilt::TDLIB_COMMIT, $Alien::TDLib::Prebuilt::TDLIB_VERSION);
    is Alien::TDLib::Prebuilt::check_pin($good)->{version}, $Alien::TDLib::Prebuilt::TDLIB_VERSION, 'pin accepted';

    my $nested = $write->('package', sprintf
        '{"name":"x","tdlib":{"commit":"%s","version":"%s"}}',
        $Alien::TDLib::Prebuilt::TDLIB_COMMIT, $Alien::TDLib::Prebuilt::TDLIB_VERSION);
    ok Alien::TDLib::Prebuilt::check_pin($nested), 'npm layout package/package.json accepted';

    my $bad_commit = $write->(undef,
        '{"name":"x","tdlib":{"commit":"deadbeef","version":"1.8.66"}}');
    ok !eval { Alien::TDLib::Prebuilt::check_pin($bad_commit); 1 }, 'wrong commit refused';
    like $@, qr/does not match the resolved/, 'refusal names the resolved release';

    my $bad_version = $write->(undef,
        sprintf '{"name":"x","tdlib":{"commit":"%s","version":"1.8.65"}}',
        $Alien::TDLib::Prebuilt::TDLIB_COMMIT);
    ok !eval { Alien::TDLib::Prebuilt::check_pin($bad_version); 1 }, 'wrong version refused';

    my $no_tdlib = $write->(undef, '{"name":"x"}');
    ok !eval { Alien::TDLib::Prebuilt::check_pin($no_tdlib); 1 }, 'missing tdlib field refused';
}

done_testing;
