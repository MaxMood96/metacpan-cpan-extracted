#!perl
use 5.006;
use strict;
use warnings;
use Test::More;

my $mmdb = 't/mmdb/GeoLite2-Country-Test.mmdb';

plan skip_all => 'IP::Geolocation::MMDB is not installed'
	unless eval { require IP::Geolocation::MMDB; 1; };
plan skip_all => "test database $mmdb not found"
	unless -f $mmdb;

use_ok('Log::Munger') || print "Bail out!\n";

# geoip enrichment on a flagged field (http_clientip) using a known test IP
my $m = Log::Munger->new( 'rules' => ['http_access_logs'], 'geoip' => $mmdb );
my $line = '81.2.69.142 - - [15/Jul/2026:12:00:00 +0000] "GET / HTTP/1.1" 200 12 "-" "curl/8"';
my $r    = $m->process_item( 'item' => $line );

ok( defined($r), 'access line matched' );
is( $r->{'http_clientip'}, '81.2.69.142', 'client ip captured' );
ok( exists( $r->{'geoip'} ), 'geoip key present in result' );
is( ref( $r->{'geoip'} ), 'HASH', 'geoip is a hash keyed by field name' );
is( $r->{'geoip'}{'http_clientip'}{'country'}{'iso_code'},
	'GB', 'geoip goes under .geoip.$field and resolves the country' );

# a private / absent address yields no geoip entry (and never dies)
my $priv = $m->process_item(
	'item' => '10.0.0.1 - - [15/Jul/2026:12:00:00 +0000] "GET / HTTP/1.1" 200 12 "-" "curl/8"' );
ok( defined($priv), 'private-ip line still matched' );
ok( !exists( $priv->{'geoip'} ), 'private/absent ip => no geoip entry' );

# without a geoip database, no geoip enrichment happens at all
my $nodb = Log::Munger->new( 'rules' => ['http_access_logs'] );
my $r2   = $nodb->process_item( 'item' => $line );
ok( defined($r2) && !exists( $r2->{'geoip'} ), 'no geoip database => no geoip key' );

# the error-log file's flagged nginx client_ip is enriched too
my $me = Log::Munger->new( 'rules' => ['http_error_logs'], 'geoip' => $mmdb );
my $re = $me->process_item( 'item' =>
		'2026/07/15 09:01:02 [error] 42#0: *5 boom, client: 81.2.69.142, server: x, request: "GET / HTTP/1.1", host: "x"'
);
is( $re->{'geoip'}{'http_error_client_ip'}{'country'}{'iso_code'},
	'GB', 'nginx error client_ip enriched under .geoip' );

# postfix file-level geoip default flags postfix_client_ip
my $mp = Log::Munger->new( 'rules' => [ 'base', 'postfix' ], 'geoip' => $mmdb );
my $rp = $mp->process_item( 'item' => { PROGRAM => 'postfix/smtpd', MESSAGE => 'connect from mail.example.com[81.2.69.142]' } );
is( $rp->{'geoip'}{'postfix_client_ip'}{'country'}{'iso_code'},
	'GB', 'postfix file-level geoip default enriches postfix_client_ip' );

#
# the rest of the shipped files that flag an address, including the ones where
# the field geoip reads was produced by a decompose rather than by a pattern
#
my %flagged = (
	'sshd'      => [ 'ssh_src_ip',    { PROGRAM => 'sshd',    MESSAGE => 'Failed password for root from 81.2.69.142 port 22 ssh2' } ],
	'netfilter' => [ 'nf_SRC',        { PROGRAM => 'kernel',  MESSAGE => '[UFW BLOCK] IN=eth0 OUT= SRC=81.2.69.142 DST=192.0.2.1 PROTO=TCP SPT=1 DPT=22' } ],
	'dovecot'   => [ 'dovecot_rip',   { PROGRAM => 'dovecot', MESSAGE => 'imap-login: Login: user=<x>, method=PLAIN, rip=81.2.69.142, lip=192.0.2.1, session=<s>' } ],
	'named'     => [ 'dns_client_ip', { PROGRAM => 'named',   MESSAGE => 'client 81.2.69.142#5 (x): query: x IN A + (192.0.2.1)' } ],
	'pam'       => [ 'pam_rhost',     { PROGRAM => 'sshd',    MESSAGE => 'pam_unix(sshd:auth): authentication failure; logname= uid=0 euid=0 tty=ssh ruser= rhost=81.2.69.142 user=root' } ],
	# json-flatten attr.remote, then split ip:port, then look the address up
	'mongodb'   => [ 'mongo_attr_remote_ip', { PROGRAM => 'mongod', MESSAGE => '{"s":"I","c":"NETWORK","id":22943,"ctx":"listener","msg":"Connection accepted","attr":{"remote":"81.2.69.142:52111","connectionId":7}}' } ],
);

foreach my $rule_file ( sort keys(%flagged) ) {
	my ( $field, $item ) = @{ $flagged{$rule_file} };
	my $got = Log::Munger->new( 'rules' => [$rule_file], 'geoip' => $mmdb )->process_item( 'item' => $item );
	is( $got->{'geoip'}{$field}{'country'}{'iso_code'}, 'GB', "$rule_file: geoip on $field" );
}

# squid is fed raw, having no syslog identity of its own
my $squid = Log::Munger->new( 'rules' => ['squid'], 'geoip' => $mmdb )->process_item(
	'item' => '1.0 1 81.2.69.142 TCP_MISS/200 1 GET http://x/ - DIRECT/1.2.3.4 text/html' );
is( $squid->{'geoip'}{'squid_client_ip'}{'country'}{'iso_code'}, 'GB', 'squid: geoip on squid_client_ip' );

done_testing();
