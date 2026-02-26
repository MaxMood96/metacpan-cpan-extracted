use strict;
use Test::More;
use JSON qw(decode_json);

use Container::Builder::Config;

my $config = Container::Builder::Config->new();
my @env = ('PATH=/bin:/sbin', 'TEST=MORE');
my @entry = ('/usr/bin/perl');
my @cmd = ('--version');
my @layers = ();
my $empty_layers_config_jsonstr = $config->generate_config('larry', \@env, \@entry, \@cmd, '/', \@layers);
my $conf1 = decode_json($empty_layers_config_jsonstr);
ok($conf1->{architecture} eq 'amd64', 'architecture is amd64');
ok($conf1->{os} eq 'linux', 'os is linux');
ok($conf1->{config}->{User} eq 'larry', 'User is larry');
ok($conf1->{config}->{WorkingDir} eq '/', 'Working directory is "/"');
ok($conf1->{config}->{Entrypoint}->[0] eq '/usr/bin/perl', 'Entrypoint is /usr/bin/perl');
ok($conf1->{config}->{Cmd}->[0] eq '--version', 'Cmd is --version');
ok(@{$conf1->{config}->{Env}} == 2, 'Environment has length 2');
ok($conf1->{config}->{Env}->[0] eq 'PATH=/bin:/sbin', 'First env var is PATH');
ok($conf1->{config}->{Env}->[1] eq 'TEST=MORE', 'Second env var is TEST=MORE');
# Now the tests based on the layers
# We passed an empty array, so these will be length zero but still an array
ok(ref($conf1->{rootfs}->{diff_ids}) eq 'ARRAY', 'diff ids is an array');
ok(@{$conf1->{rootfs}->{diff_ids}} == 0, 'diff ids is an array of length 0');
ok(ref($conf1->{history}) eq 'ARRAY', 'history is an array');
ok(@{$conf1->{history}} == 0, 'history is an array of length 0');

done_testing;
