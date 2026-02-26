use v5.40;

use Container::Builder;

say "Make sure you have a sample Dancer2 app. (dancer2 gen -a SampleApp)";
say "Then fatpack plackup and fatpack your app into two files.";
say "Below it shows how you could add all of the dancer2 files into the container";
say "But for brevity/clarity, it doesn't do any checks on whether those files exists";
say "(This is an example! Not a test case that needs passing!But it works on my dev machine hehe)";
say "Use it for inspiration or to better understand how this Module works.";
exit 0;

my $builder = Container::Builder->new(debian_pkg_hostname => 'debian.inf.tu-dresden.de', os_version => 'bookworm', cache_folder => 'artifacts_bookworm', enable_packages_cache => 1, packages_file => 'Packages_bookworm');
$builder->create_directory('/', 0755, 0, 0);
$builder->create_directory('bin/', 0755, 0, 0);
$builder->create_directory('tmp/', 01777, 0, 0);
$builder->create_directory('root/', 0700, 0, 0);
$builder->create_directory('home/', 0755, 0, 0);
$builder->create_directory('home/larry/', 0700, 1337, 1337);
$builder->create_directory('etc/', 0755, 0, 0);
$builder->create_directory('app/', 0755, 1337, 1337);
# C dependencies (to run a compiled executable)
$builder->add_deb_package('libc-bin');
$builder->add_deb_package('libc6');
$builder->add_deb_package('gcc-12-base');
$builder->add_deb_package('libgcc-s1');
$builder->add_deb_package('libgomp1');
$builder->add_deb_package('libstdc++6');
$builder->add_deb_package('ca-certificates');
# SSL support
$builder->add_deb_package('libssl3');
# Perl dependencies (to run a basic Perl program)
$builder->add_deb_package('libcrypt1');
$builder->add_deb_package('perl');
# My fatpack expects these to be already installed somehow
$builder->add_deb_package('libtry-tiny-perl');
$builder->add_deb_package('libdevel-stacktrace-perl');
$builder->add_deb_package('libdevel-stacktrace-ashtml-perl');
# html::parser contains xs code so no can do with fatpack
$builder->add_deb_package('libhtml-parser-perl');
# same for Clone 
$builder->add_deb_package('libclone-perl');
$builder->add_group('root', 0);
$builder->add_group('tty', 5);
$builder->add_group('staff', 50);
$builder->add_group('larry', 1337);
$builder->add_group('nobody', 65000);
$builder->add_user('root', 0, 0, '/sbin/nologin', '/root');
$builder->add_user('nobody', 65000, 65000, '/sbin/nologin', '/nohome');
$builder->add_user('larry', 1337, 1337, '/sbin/nologin', '/home/larry');
$builder->set_env('PATH', '/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin');
# Dancer2
# Fatpacked files
$builder->add_file('../SampleApp/bin/fatpacked.app.psgi', '/app/bin/fatpacked.app.psgi', 0644, 1337, 1337);
$builder->add_file('../SampleApp/fatpacked.plackup', '/bin/plackup', 0644, 1337, 1337);
# Dancer2 folders
$builder->copy('../SampleApp/views/', '/app/views', 0755, 1337, 1337);
$builder->copy('../SampleApp/public/', '/app/public', 0755, 1337, 1337);
$builder->copy('../SampleApp/environments/', '/app/environments', 0755, 1337, 1337);
# Config file
$builder->add_file('../SampleApp/config.yml', '/app/config.yml', 0644, 1337, 1337);

# TODO: Not sure why but the env is broken and it thinks /app/bin/ is the cwd
$builder->add_file('../SampleApp/config.yml', '/app/bin/config.yml', 0644, 1337, 1337);
$builder->runas_user('larry');
$builder->set_env('DANCER_ENVDIR', '/app/environments/');
$builder->set_env('DANCER_VIEWS', '/app/views/');
$builder->set_env('DANCER_PUBLIC', '/app/public/');
$builder->set_env('DANCER_CONFIG_VERBOSE', '1');
$builder->set_work_dir('/app');
$builder->set_entry('/usr/bin/perl', '/bin/plackup', '-E', 'development', '--host', '0.0.0.0', '--port', '5000', '/app/bin/fatpacked.app.psgi');
$builder->build('03-dancer2.tar');
say "Now run: podman load -i 03-dancer2.tar";
say "Then run: podman tag " . substr($builder->get_digest(), 0, 12) . " localhost/dancer2:latest";
say "And finally: podman run -p5000:5000 localhost/dancer2:latest";
