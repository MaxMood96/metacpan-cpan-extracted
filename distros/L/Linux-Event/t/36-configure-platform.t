use v5.36;
use strict;
use warnings;

use Cwd qw(abs_path);
use File::Spec;
use File::Temp qw(tempdir);
use FindBin qw($Bin);
use IPC::Open3 qw(open3);
use Symbol qw(gensym);
use Test::More;

my $makefile_pl = abs_path(File::Spec->catfile($Bin, '..', 'Makefile.PL'));
my $temporary = tempdir(CLEANUP => 1);
my $program = <<'PERL';
use strict;
use warnings;
Internals::SvREADONLY($^O, 0);
local $^O = 'freebsd';
chdir $ARGV[1] or die "chdir $ARGV[1]: $!";
my $result = do $ARGV[0];
die $@ if $@;
die "do $ARGV[0]: $!" if !defined $result;
PERL

my $stderr = gensym;
my $pid = open3(undef, my $stdout, $stderr,
    $^X, '-e', $program, $makefile_pl, $temporary);
local $/;
my $output = (<$stdout> // '') . (<$stderr> // '');
waitpid($pid, 0);

is($?, 0, 'unsupported platform exits successfully during configuration');
like($output, qr/^OS unsupported: Linux::Event supports Linux only$/m,
    'configuration emits the conventional unsupported-OS message');
ok(!-e File::Spec->catfile($temporary, 'Makefile'),
    'unsupported configuration does not create a Makefile');

done_testing;
