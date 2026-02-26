use v5.40;

use Container::Builder;

my $builder = Container::Builder->new(debian_pkg_hostname => 'debian.inf.tu-dresden.de', os_version => 'trixie', cache_folder => 'artifacts_trixie', enable_packages_cache => 1, packages_file => 'Packages_trixie');
$builder->create_directory('/', 0755, 0, 0);
$builder->create_directory('bin/', 0755, 0, 0);
$builder->create_directory('tmp/', 01777, 0, 0);
$builder->create_directory('root/', 0700, 0, 0);
$builder->create_directory('home/', 0755, 0, 0);
$builder->create_directory('home/larry/', 0700, 1337, 1337);
$builder->create_directory('etc/', 0755, 0, 0);
$builder->create_directory('app/', 0755, 1337, 1337);
# Extra
$builder->add_deb_package('base-files');
$builder->add_deb_package('netbase');
$builder->add_deb_package('tzdata');
$builder->add_deb_package('media-types');
my $nsswitch = <<'NSS';
# /etc/nsswitch.conf
#
# Example configuration of GNU Name Service Switch functionality.
# If you have the `glibc-doc-reference' and `info' packages installed, try:
# `info libc "Name Service Switch"' for information about this file.

passwd:         compat
group:          compat
shadow:         compat
gshadow:        files

hosts:          files dns
networks:       files

protocols:      db files
services:       db files
ethers:         db files
rpc:            db files

netgroup:       nis
NSS
$builder->add_file_from_string($nsswitch, '/etc/nsswitch.conf', 0644, 0, 0);
# C dependencies (to run a compiled executable)
$builder->add_deb_package('libc-bin');
$builder->add_deb_package('libc6');
$builder->add_deb_package('gcc-14-base');
$builder->add_deb_package('libgcc-s1');
$builder->add_deb_package('libgomp1');
$builder->add_deb_package('libstdc++6');
# Perl base
$builder->add_deb_package('libcrypt1');
$builder->add_deb_package('perl-base');
$builder->add_group('root', 0);
$builder->add_group('tty', 5);
$builder->add_group('staff', 50);
$builder->add_group('larry', 1337);
$builder->add_group('nobody', 65000);
$builder->add_user('root', 0, 0, '/sbin/nologin', '/root');
$builder->add_user('nobody', 65000, 65000, '/sbin/nologin', '/nohome');
$builder->add_user('larry', 1337, 1337, '/sbin/nologin', '/home/larry');
$builder->runas_user('larry');
$builder->set_env('PATH', '/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin');
$builder->set_work_dir('/home/larry/');
$builder->set_entry('/usr/bin/perl', 'testproggie.pl');
my $testproggie = <<'PROG';
use v5.40; # Trixie comes with 5.40
say "Hallo vriendjes en vriendinnetjes!";
PROG
$builder->add_file_from_string($testproggie, '/home/larry/testproggie.pl', 0644, 1337, 1337); # our program
$builder->build('04-hello-world.tar');
say "Now run: podman load -i 04-hello-world.tar";
say "Then run: podman run " . substr($builder->get_digest(), 0, 12);
