#!perl
use 5.006;
use strict;
use warnings;
use Test::More;
use File::ShareDir ();
use FindBin        ();

BEGIN {
	use_ok('Log::Munger') || print "Bail out!\n";
}

# test the working tree's rule files rather than whatever copy happens to be
# installed; without this a stale installed share dir shadows the tree
$ENV{'LOG_MUNGER_RULES_DIR'} = $FindBin::Bin . '/../share' if ( -d $FindBin::Bin . '/../share' );

#
# What only exists when more than one rule file is loaded.
#
# A rule file's tests only ever see that file, and they now cover everything
# visible from there: the patterns, the whole capture set each one produces, the
# programs the gate admits and refuses, what a decompose produces and what a
# convert coerces. All of it runs for every shipped file in t/all_rules_clean.t,
# so none of it is repeated here.
#
# What is left is the property that only exists in the union, and it is the one
# no rule file can describe on its own. Several files end in a catch-all so an
# unrecognised line keeps its text rather than being dropped, and a few are
# gateless because their source is a file rather than syslog -- pf writes binary
# pcap that only becomes text once tcpdump has rendered it, and squid's access log
# are tailed off disk. Each of those is reasonable alone,
# and each is a way to quietly swallow someone else's traffic once everything is
# loaded together.
#
# So everything below asserts "the right file claimed this line", never what the
# line captured.
#

#
# the whole set at once: every daemon's line still goes to the file that owns it
#
my $share = $ENV{'LOG_MUNGER_RULES_DIR'};
if ( !defined($share) || !-d $share ) {
	$share = File::ShareDir::dist_dir('Log-Munger');
}
my @all = map { m{([^/]+)\.yaml\z} } sort glob("$share/*.yaml");
cmp_ok( scalar(@all), '>=', 40, 'found the full set of shipped rule files' );

my $everything = Log::Munger->new( 'rules' => \@all );

my @ownership = (
	[ 'sshd goes to sshd', { PROGRAM => 'sshd', MESSAGE => 'Failed password for root from 203.0.113.7 port 44444 ssh2' }, 'ssh_user' ],
	[ 'postfix goes to postfix', { PROGRAM => 'postfix/smtpd', MESSAGE => 'connect from unknown[192.0.2.5]' }, 'postfix_client_ip' ],
	[ 'netfilter goes to netfilter', { PROGRAM => 'kernel', MESSAGE => '[UFW BLOCK] IN=eth0 OUT= SRC=203.0.113.7 DST=192.0.2.1 PROTO=TCP SPT=44444 DPT=22' }, 'nf_SRC' ],
	[ 'samba goes to samba', { PROGRAM => 'smbd', MESSAGE => '  check_ntlm_password:  Authentication for user [admin] -> [admin] FAILED with error NT_STATUS_NO_SUCH_USER' }, 'samba_status' ],
	[ 'slapd goes to slapd', { PROGRAM => 'slapd', MESSAGE => 'conn=1000 op=0 RESULT tag=97 err=49 text=' }, 'slapd_err' ],
	[ 'polkit goes to polkit', { PROGRAM => 'polkitd', MESSAGE => 'Loading rules from directory /etc/polkit-1/rules.d' }, 'polkit_message' ],
	[ 'rspamd goes to rspamd', { PROGRAM => 'rspamd', MESSAGE => 'rspamd 3.7.5 is loading configuration' }, 'rspamd_message' ],
	[ 'clamav goes to clamav', { PROGRAM => 'clamd', MESSAGE => 'SelfCheck: Database status OK.' }, 'clamav_message' ],
	# tier-two daemons, several of which also end in a catch-all
	[ 'docker goes to docker', { PROGRAM => 'dockerd', MESSAGE => 'failed to start daemon: no such file' }, 'docker_message' ],
	[ 'sendmail goes to sendmail', { PROGRAM => 'sm-mta', MESSAGE => 'starting daemon (8.17.1): SMTP+queueing@00:30:00' }, 'sendmail_message' ],
	[ 'freeradius goes to freeradius', { PROGRAM => 'radiusd', MESSAGE => 'Ready to process requests' }, 'radius_message' ],
	[ 'strongswan goes to strongswan', { PROGRAM => 'charon', MESSAGE => 'charon stopped after 200 ms' }, 'ipsec_message' ],
	[ 'wpa_supplicant goes to wpa_supplicant', { PROGRAM => 'wpa_supplicant', MESSAGE => 'Successfully initialized wpa_supplicant' }, 'wpa_message' ],
	[ 'networkd goes to networkd', { PROGRAM => 'systemd-networkd', MESSAGE => 'Enumeration completed' }, 'networkd_message' ],
	[ 'resolved goes to resolved', { PROGRAM => 'systemd-resolved', MESSAGE => 'Positive Trust Anchors:' }, 'resolved_message' ],
	[ 'timesyncd goes to timesyncd', { PROGRAM => 'systemd-timesyncd', MESSAGE => 'Network configuration changed, trying to establish connection.' }, 'timesyncd_message' ],
	[ 'zed goes to zed', { PROGRAM => 'zed', MESSAGE => 'ZFS Event Daemon 2.1.11-1 (PID 1234)' }, 'zed_message' ],
	[ 'cups goes to cups', { PROGRAM => 'cupsd', MESSAGE => 'Scheduler shutting down normally.' }, 'cups_message' ],
	[ 'php-fpm goes to php_fpm', { PROGRAM => 'php-fpm8.2', MESSAGE => 'ready to handle connections' }, 'php_message' ],
	[ 'rsyslogd goes to syslog_daemon', { PROGRAM => 'rsyslogd', MESSAGE => 'rsyslogd\'s groupid changed to 106' }, 'syslogd_message' ],
	[ 'xinetd goes to xinetd', { PROGRAM => 'xinetd', MESSAGE => 'xinetd Version 2.3.15 started' }, 'xinetd_message' ],
	[ 'snmpd goes to snmpd', { PROGRAM => 'snmpd', MESSAGE => 'NET-SNMP version 5.9.3' }, 'snmpd_message' ],
	[ 'mountd goes to nfs', { PROGRAM => 'rpc.mountd', MESSAGE => 'Version 1.3.4 starting' }, 'nfs_message' ],
	[ 'atd goes to atd', { PROGRAM => 'atd', MESSAGE => 'File a000050192abc is in the future' }, 'atd_message' ],
	[ 'nslcd goes to nslcd', { PROGRAM => 'nslcd', MESSAGE => 'accepting connections' }, 'nslcd_message' ],
	[ 'pkg goes to pkg', { PROGRAM => 'pkg', MESSAGE => 'nginx upgraded: 1.28.0_2,3 -> 1.28.0_3,3' }, 'pkg_version_from' ],
	# the OpenWRT set, each of which ends in a catch-all
	[ 'dropbear goes to dropbear', { PROGRAM => 'dropbear', MESSAGE => 'Not backgrounding' }, 'dropbear_message' ],
	[ 'odhcpd goes to odhcpd', { PROGRAM => 'odhcpd', MESSAGE => 'Raising SIGUSR1 due to reload' }, 'odhcpd_message' ],
	[ 'netifd goes to netifd', { PROGRAM => 'netifd', MESSAGE => "Network device 'phy0-ap1' link is up" }, 'netifd_link_state' ],
	[ 'lldpd goes to lldpd', { PROGRAM => 'lldpd', MESSAGE => 'unable to get system name' }, 'lldpd_message' ],
	[ 'lldpcli goes to lldpd', { PROGRAM => 'lldpcli', MESSAGE => 'protocol LLDP enabled' }, 'lldpd_protocol' ],
	[ 'a luci login under uhttpd goes to luci', { PROGRAM => 'uhttpd', MESSAGE => '[info] luci: accepted login on / for root from 192.0.2.5' }, 'luci_user' ],
	# sympa's daemons answer to some very generic program names, so each is
	# checked separately rather than trusting one to stand for the rest
	[ 'sympa bulk goes to sympa', { PROGRAM => 'bulk', MESSAGE => 'notice main:: Bulk 6.2.76 Started' }, 'sympa_daemon' ],
	[ 'sympa archived goes to sympa', { PROGRAM => 'archived', MESSAGE => 'notice main:: Archived 6.2.76 Started' }, 'sympa_daemon' ],
	[ 'sympa bounced goes to sympa', { PROGRAM => 'bounced', MESSAGE => 'notice main::sigterm() Signal TERM received, still processing current task' }, 'sympa_function' ],
	[ 'sympa CLI goes to sympa', { PROGRAM => 'sympa/health_check', MESSAGE => 'notice Sympa::DatabaseManager::probe_db() Table one_time_ticket_table created in database sympa' }, 'sympa_function' ],
	# Tor answers to two program names for the same daemon: "Tor" for its own
	# syslog output and "tor" for the stdout systemd captures, which still has
	# Tor's timestamp and level on the front
	[ 'Tor goes to tor', { PROGRAM => 'Tor', MESSAGE => 'We now have enough directory information to build circuits.' }, 'tor_message' ],
	[ 'tor stdout goes to tor', { PROGRAM => 'tor', MESSAGE => 'Jul 28 14:41:30.650 [notice] Opening Socks listener on 127.0.0.1:9050' }, 'tor_listener_addr' ],
	[ 'dbus-daemon goes to dbus', { PROGRAM => 'dbus-daemon', MESSAGE => '[system] Reloaded configuration' }, 'dbus_bus' ],
	# libvirt's modular daemons share one rule, so a second one is checked
	[ 'virtqemud goes to libvirt', { PROGRAM => 'virtqemud', MESSAGE => 'libvirt version: 11.1.0' }, 'libvirt_version' ],
	[ 'libvirtd goes to libvirt', { PROGRAM => 'libvirtd', MESSAGE => "Cannot get interface flags on 'virbr0': No such device" }, 'libvirt_error' ],
	# fwupd's clients log under their own names and write the bare message
	# with none of the daemon's time-and-domain prefix on it
	[ 'fwupd goes to fwupd', { PROGRAM => 'fwupd', MESSAGE => '11:21:52.150 FuEngine             something new' }, 'fwupd_domain' ],
	[ 'fwupdmgr goes to fwupd', { PROGRAM => 'fwupdmgr', MESSAGE => 'Updating lvfs' }, 'fwupd_remote' ],
	[ 'avahi-daemon goes to avahi', { PROGRAM => 'avahi-daemon', MESSAGE => 'Server startup complete. Host name is host.local.' }, 'avahi_message' ],
	# the Ereshkigal suite. Kur and Galla gate on a prefix rather than an exact
	# name, which is the sort of gate that can reach too far, so all four are
	# checked with everything loaded
	[ 'kur-sshd goes to kur', { PROGRAM => 'kur-sshd', MESSAGE => 'banned 192.0.2.7 expires=1785727347' }, 'kur_ip' ],
	[ 'galla-suricata goes to galla', { PROGRAM => 'galla-suricata', MESSAGE => 'banished 192.0.2.7 to Kur ban_time=300' }, 'galla_ip' ],
	[ 'baphomet goes to baphomet', { PROGRAM => 'baphomet', MESSAGE => 'galla "sshd" died, restarting in 1 seconds' }, 'bph_galla' ],
	[ 'ereshkigal goes to ereshkigal', { PROGRAM => 'ereshkigal', MESSAGE => 'added kur "dns"' }, 'eresh_kur' ],
	# the capture-and-submit chain, all three of which end in a catch-all
	[ 'daemonlogger goes to daemonlogger', { PROGRAM => 'daemonlogger', MESSAGE => 'Rolling over logfile...' }, 'dlog_action' ],
	[ 'virani goes to virani', { PROGRAM => 'virani', MESSAGE => 'Remote IP: 192.0.2.5' }, 'virani_remote_ip' ],
	[ 'suricata_extract_submit goes to suricata_extract_submit', { PROGRAM => 'suricata_extract_submit', MESSAGE => 'None found at this time' }, 'ses_state' ],
	# nergal and mojo_cape_submit share a message vocabulary and a rule
	[ 'mojo_cape_submit goes to mojo_cape_submit', { PROGRAM => 'mojo_cape_submit', MESSAGE => '0 : Source Host: sensor.example.net' }, 'cape_submit_source_host' ],
	[ 'nergal goes to mojo_cape_submit', { PROGRAM => 'nergal', MESSAGE => '0 : Submitting "sample.msi" submitted as 116' }, 'cape_submit_task_id' ],
	# the four raw, gateless formats, which are the ones with nothing but
	# their own shape keeping them apart
	[ 'an apache line goes to http_access_logs', '127.0.0.1 - frank [10/Oct/2000:13:55:36 -0700] "GET /a.gif HTTP/1.0" 200 2326 "-" "Mozilla/5.0"', 'http_clientip' ],
	[ 'a squid line goes to squid', '1626345600.123 234 192.0.2.5 TCP_MISS/200 1234 GET http://e.com/ - DIRECT/1.2.3.4 text/html', 'squid_client_ip' ],
	[ 'a pf line goes to pf', 'rule 12/0(match): block in on em0: 192.0.2.5.49152 > 192.0.2.1.22: Flags [S], length 0', 'pf_src_ip' ],
#	[ 'an eve.json line goes to suricata', '{"timestamp":"2026-07-15T10:00:00+0000","event_type":"alert","src_ip":"203.0.113.7","src_port":44444,"dest_ip":"192.0.2.1","dest_port":22}', 'suricata_event_type' ],
	# the daemons whose only whole-set check this used to be: each answers to a
	# name of its own, so what is asserted is that nothing else takes the line
	# first
	[ 'haproxy goes to haproxy', { PROGRAM => 'haproxy', MESSAGE => '192.0.2.5:49152 [15/Jul/2026:10:00:00.123] http-in be/srv 0/0/1/2/3 200 1234 - - ---- 1/1/0/0/0 0/0 "GET / HTTP/1.1"' }, 'haproxy_accept_date' ],
	[ 'NetworkManager goes to networkmanager', { PROGRAM => 'NetworkManager', MESSAGE => '<warn>  [1626345600.1234] device (wlan0): state change: config -> failed (reason \'no-secrets\', sys-iface-state: \'managed\')' }, 'nm_level' ],
	[ 'opendkim goes to opendkim', { PROGRAM => 'opendkim', MESSAGE => '1rABCD: s=default d=example.com SSL' }, 'opendkim_detail' ],
	[ 'opendmarc goes to opendmarc', { PROGRAM => 'opendmarc', MESSAGE => '1rABCD: example.com fail; dkim=fail (bad signature) spf=pass' }, 'opendmarc_detail' ],
	[ 'openvpn-server goes to openvpn', { PROGRAM => 'openvpn-server', MESSAGE => 'neti/192.0.2.5:49152 [neti] Peer Connection Initiated with [AF_INET]192.0.2.5:49152' }, 'openvpn_af' ],
	[ 'postgres goes to postgresql', { PROGRAM => 'postgres', MESSAGE => 'FATAL:  password authentication failed for user "neti"' }, 'pgsql_user' ],
	[ 'proftpd goes to proftpd', { PROGRAM => 'proftpd', MESSAGE => '192.0.2.1 (scanner[203.0.113.7]) - USER admin (Login failed): Incorrect password.' }, 'proftpd_client_host' ],
	[ 'smartd goes to smartd', { PROGRAM => 'smartd', MESSAGE => 'Device: /dev/sda [SAT], SMART Prefailure Attribute: 5 Reallocated_Sector_Ct changed from 100 to 99' }, 'smartd_attribute_id' ],
	[ 'spamd goes to spamd', { PROGRAM => 'spamd', MESSAGE => 'spamd: result: Y 12 - BAYES_99,HTML_MESSAGE scantime=1.2,size=1234,user=neti,uid=1000,required_score=5.0,rhost=localhost,raddr=127.0.0.1' }, 'spamd_score_int' ],
	[ 'vsftpd goes to vsftpd', { PROGRAM => 'vsftpd', MESSAGE => '[pid 1234] [neti] FAIL LOGIN: Client "192.0.2.5"' }, 'vsftpd_action' ],
	[ 'mariadbd goes to mysql', { PROGRAM => 'mariadbd', MESSAGE => q{Access denied for user 'root'@'192.0.2.5' (using password: YES)} }, 'mysql_user' ],
	# ...and a mongodb JSON line must still reach mongodb rather than being
	# taken by suricata's gateless JSON rule
	[ 'mongodb JSON goes to mongodb', { PROGRAM => 'mongod', MESSAGE => '{"t":{"$date":"2026-07-27T02:49:30.131+00:00"},"s":"I","c":"NETWORK","id":22943,"ctx":"listener","msg":"Connection accepted"}' }, 'mongo_msg' ],
);

foreach my $case (@ownership) {
	my ( $label, $item, $want ) = @{$case};
	my $fields = $everything->process_item( 'item' => $item );
	ok( defined($fields) && exists( $fields->{$want} ), $label )
		or diag( defined($fields) ? 'got instead: ' . join( ', ', sort keys %{$fields} ) : 'no match at all' );
}

#
# and the pairs worth naming, where two files are loaded and one could plausibly
# reach into the other
#

# the squid access rule is gateless, so it is considered for every record. Its
# patterns require the "%Ss:%Sh" tail precisely so an apache line loaded
# alongside it is not stolen out from under http_access_logs.
my $squid_and_http = Log::Munger->new( 'rules' => [ 'squid', 'http_access_logs' ] );
my $apache = $squid_and_http->process_item(
	'item' => '127.0.0.1 - frank [10/Oct/2000:13:55:36 -0700] "GET /a.gif HTTP/1.0" 200 2326 "-" "Mozilla/5.0"' );
is( $apache->{'http_clientip'}, '127.0.0.1', 'apache line goes to http_access_logs even with squid loaded first' );
ok( !exists( $apache->{'squid_client_ip'} ), 'squid does not claim an apache line' );

# kernel and netfilter both answer to PROGRAM=kernel, so a firewall line has to
# get past everything kernel.yaml offers before it reaches netfilter
my $kernel_and_netfilter = Log::Munger->new( 'rules' => [ 'kernel', 'netfilter' ] );
my $ufw = $kernel_and_netfilter->process_item(
	'message' => '[ 4391.338436] [UFW BLOCK] IN=eth0 OUT= SRC=203.0.113.7 DST=192.0.2.1 PROTO=TCP SPT=44444 DPT=22',
	'program' => 'kernel'
);
ok( exists( $ufw->{'nf_SRC'} ), 'a firewall line reaches netfilter with kernel loaded first' );

# the syslog daemon's repeat suppression arrives under the repeating program's
# identity rather than the daemon's. Eleven send failures become one line that
# no dnsmasq pattern matches, so the rule is gateless and sits behind the gated
# syslog_daemon rule.
my $repeated = Log::Munger->new( 'rules' => [ 'dnsmasq', 'syslog_daemon' ] )->process_item(
	'message' => 'message repeated 11 times: [ failed to send packet: Operation not permitted]',
	'program' => 'dnsmasq'
);
ok( exists( $repeated->{'syslogd_repeated_message'} ),
	'a dnsmasq line reaches syslog_daemon\'s gateless repeat rule' );

done_testing();
