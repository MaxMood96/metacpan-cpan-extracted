package Alien::TDLib::Prebuilt;

use strict;
use warnings;

# the tarball records the TDLib commit it was built from; check_pin refuses a drift
our $NPM_VERSION   = '0.1008066.0';
our $TDLIB_COMMIT  = '022d60202e446ad1287b9fb68e687c8a0760788b';
our $TDLIB_VERSION = '1.8.66';

sub machine_arch {
    my ($machine) = @_;
    if (!defined $machine) {
        require POSIX;
        $machine = (POSIX::uname())[4];
    }
    return 'x64'   if $machine =~ /^(x86_64|amd64)$/i;
    return 'arm64' if $machine =~ /^(aarch64|arm64)$/i;
    return undef;
}

# ask ldd first: /lib/ld-musl-*.so.1 also exists on glibc boxes with musl installed
sub detect_musl {
    my $ldd = `ldd --version 2>&1` // '';
    return 1 if $ldd =~ /musl/i;
    return 0 if $ldd =~ /glibc|gnu libc/i;
    my $pldd = `ldd "$^X" 2>&1` // '';
    return 1 if $pldd =~ /musl/i;
    return 0 if $pldd =~ /libc\.so/;
    return glob('/lib/ld-musl-*.so.1') ? 1 : 0;
}

sub platform {
    my ($os, $arch, $musl) = @_;
    $os   //= $^O;
    $arch //= machine_arch();
    return undef unless defined $arch;
    if ($os eq 'linux') {
        $musl //= detect_musl();
        return "linux-$arch-" . ($musl ? 'musl' : 'glibc');
    }
    return "darwin-$arch" if $os eq 'darwin';
    return 'win32-x64' if $os =~ /^(MSWin32|msys)$/ && $arch eq 'x64';
    return undef;
}

sub shared_lib_name {
    my ($plat) = @_;
    return 'tdjson.dll'      if $plat =~ /^win32/;
    return 'libtdjson.dylib' if $plat =~ /^darwin/;
    return 'libtdjson.so';
}

sub tarball_url {
    my ($plat, $npm) = @_;
    $npm ||= $NPM_VERSION;
    return "https://registry.npmjs.org/\@prebuilt-tdlib/$plat/-/$plat-$npm.tgz";
}

sub metadata_url {
    my ($plat) = @_;
    return "https://registry.npmjs.org/\@prebuilt-tdlib%2F$plat";
}

sub npm_integrity {
    my ($file) = @_;
    require Digest::SHA;
    my $b64 = Digest::SHA->new(512)->addfile($file)->b64digest;
    $b64 .= '=' x ((4 - length($b64) % 4) % 4);
    return "sha512-$b64";
}

sub integrity_matches {
    my ($file, $integrity) = @_;
    my $got = npm_integrity($file);
    return scalar grep { $_ eq $got } split ' ', $integrity // '';
}

# The package must be the release we resolved: npm could have re-published that
# version against a different TDLib commit between resolution and download.
sub check_pin {
    my ($dir, $want_commit, $want_version) = @_;
    $want_commit  ||= $TDLIB_COMMIT;
    $want_version ||= $TDLIB_VERSION;
    my $pkg = -f "$dir/package.json"         ? "$dir/package.json"
            : -f "$dir/package/package.json" ? "$dir/package/package.json"
            : die "no package.json under $dir\n";
    require JSON::PP;
    open my $fh, '<', $pkg or die "$pkg: $!\n";
    my $meta = eval { JSON::PP::decode_json(do { local $/; <$fh> }) };
    die "cannot parse $pkg\n" unless $meta;
    my $td = $meta->{tdlib} or die "$pkg has no tdlib provenance field\n";
    my ($commit, $version) = ($td->{commit} // '', $td->{version} // '');
    die "prebuilt TDLib commit $commit does not match the resolved $want_commit\n"
        unless $commit eq $want_commit;
    die "prebuilt TDLib version $version does not match the resolved $want_version\n"
        unless $version eq $want_version;
    return $td;
}

1;
