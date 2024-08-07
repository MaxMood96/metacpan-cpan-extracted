use v5.26;
use warnings;

use Test2::V0;

use Config::Structured;

my $def_file  = 't/conf/yml/definition.yml';
my $conf_file = 't/conf/yml/config.yml';

my $conf = Config::Structured->new(structure => $def_file, config => $conf_file);
my $db   = $conf->db;

is([$conf->get_node->{branches}->@*, $conf->get_node->{leaves}->@*],               [qw(db)], 'Check child nodes at top level');
is([sort($conf->db->get_node->{branches}->@*, $conf->db->get_node->{leaves}->@*)], [sort qw(user pass)], 'Check deep child nodes');

done_testing;
