#!perl
use 5.006;
use strict;
use warnings;
use Test::More;
use Scalar::Util qw(looks_like_number);

BEGIN {
	use_ok('Log::Munger')               || print "Bail out!\n";
	use_ok('Log::Munger::LogProcessor') || print "Bail out!\n";
}

# ---- the quote-aware kv mechanism in isolation (both quote styles, spaces) ----
my $c = Log::Munger::LogProcessor->_compile_decompose(
	[ { field => 'blob', type => 'kv', quoted => 1, prefix => 'k_', remove => 1 } ], {} );
my %caps = (
	blob => q{a="two words" b='single spaced' c=bare:word d="" e=} . q{'x'} . q{ f=203.0.113.7} );
Log::Munger::LogProcessor->_decompose( { decompose => $c }, \%caps );
is( $caps{'k_a'}, 'two words',     'quoted kv: double quotes keep the space' );
is( $caps{'k_b'}, 'single spaced', 'quoted kv: single quotes keep the space' );
is( $caps{'k_c'}, 'bare:word',     'quoted kv: bareword' );
is( $caps{'k_d'}, '',              'quoted kv: empty quoted value' );
is( $caps{'k_e'}, 'x',             'quoted kv: single-quoted short value' );
is( $caps{'k_f'}, '203.0.113.7',   'quoted kv: bareword ip' );
ok( !exists( $caps{'blob'} ), 'quoted kv: source removed' );

# ---- the shipped auditd file, from the outside ----
#
# That auditd.yaml tests clean is asserted in t/all_rules_clean.t along with
# every other shipped file. Everything below goes through the engine, which is
# what the in-YAML tests cannot do: auditd's records are almost entirely kv
# blobs, so what matters here is the decompose output and the coercions.
#
my $m = Log::Munger->new( 'rules' => ['auditd'] );

# SYSCALL: outer quoted kv (incl. key="watch exec" with a space) + convert
my $s = $m->process_item(
	'item' => 'type=SYSCALL msg=audit(1626345600.123:456): arch=c000003e syscall=59 exit=0 '
		. 'pid=5678 uid=0 ses=3 comm="ls" exe="/usr/bin/ls" key="watch exec"' );
is( $s->{'audit_type'}, 'SYSCALL',     'auditd: type' );
is( $s->{'audit_comm'}, 'ls',          'auditd: comm from quoted kv' );
is( $s->{'audit_key'},  'watch exec',  'auditd: quoted value with a space kept intact' );
ok( looks_like_number( $s->{'audit_pid'} ),   'auditd: pid is numeric' );
ok( looks_like_number( $s->{'audit_serial'} ), 'auditd: serial is numeric' );
ok( looks_like_number( $s->{'audit_epoch'} ),  'auditd: epoch is numeric (float)' );
ok( !exists( $s->{'audit_fields'} ), 'auditd: outer blob removed' );

# USER_AUTH: nested single-quoted msg with double-quoted values inside
my $u = $m->process_item(
	'item' => q{type=USER_AUTH msg=audit(1626345600.123:457): pid=1234 uid=0 ses=3 }
		. q{msg='op=PAM:authentication acct="root" exe="/usr/sbin/sshd" hostname=h addr=203.0.113.7 terminal=ssh res=failed'} );
is( $u->{'audit_type'},        'USER_AUTH',          'auditd: user_auth type' );
is( $u->{'audit_msg_op'},      'PAM:authentication', 'auditd: nested op' );
is( $u->{'audit_msg_acct'},    'root',               'auditd: nested acct (double-quoted inside single-quoted)' );
is( $u->{'audit_msg_addr'},    '203.0.113.7',        'auditd: nested addr' );
is( $u->{'audit_msg_res'},     'failed',             'auditd: nested res' );
ok( !exists( $u->{'audit_msg'} ),    'auditd: nested blob removed' );
ok( !exists( $u->{'audit_fields'} ), 'auditd: outer blob removed on user record' );

# ---- audit_id: the lossless correlation key ----
# audit_epoch is converted to a float, which cannot round-trip ".100"/".000",
# so the raw "<epoch>:<serial>" pair is captured separately. Without it there is
# no way to tie an AVC record to the SYSCALL/PATH records of the same event.
my $id = $m->process_item(
	'item' => 'type=SYSCALL msg=audit(1700000000.100:456): arch=c000003e pid=1 uid=0' );
is( $id->{'audit_id'},    '1700000000.100:456', 'auditd: audit_id keeps the raw epoch:serial' );
is( $id->{'audit_epoch'}, 1700000000.1,         'auditd: audit_epoch is still the float' );

# ---- AppArmor: the other in-tree LSM writing to audit.log ----
# it does not use SELinux' "avc:  denied  { perms } for" prose, it writes a k=v
# blob whose first key is apparmor=
my $aa = $m->process_item(
	'item' => 'type=AVC msg=audit(1700000012.000:468): apparmor="DENIED" operation="open" '
		. 'profile="/usr/bin/foo" name="/etc/shadow" pid=1234 comm="foo" '
		. 'requested_mask="r" denied_mask="r" fsuid=0 ouid=0' );
is( $aa->{'audit_type'},      'AVC',          'auditd: apparmor type' );
is( $aa->{'audit_apparmor'},  'DENIED',       'auditd: apparmor native verdict' );
is( $aa->{'mac_result'},      'denied',       'auditd: apparmor verdict normalized into mac_result' );
is( $aa->{'audit_operation'}, 'open',         'auditd: apparmor operation from the outer kv' );
is( $aa->{'audit_profile'},   '/usr/bin/foo', 'auditd: apparmor profile' );
is( $aa->{'audit_name'},      '/etc/shadow',  'auditd: apparmor name' );
ok( looks_like_number( $aa->{'audit_fsuid'} ), 'auditd: apparmor fsuid is numeric' );
ok( !exists( $aa->{'audit_fields'} ), 'auditd: apparmor outer blob removed' );

# the same normalized field carries the SELinux verdict, lowercased from the
# same source text -- one field to test regardless of which LSM is in use
my $selinux = $m->process_item(
	'item' => 'type=AVC msg=audit(1700000008.000:464): avc:  denied  { read } for  '
		. 'pid=4444 comm="httpd" scontext=system_u:system_r:httpd_t:s0 '
		. 'tcontext=system_u:object_r:shadow_t:s0 tclass=file' );
is( $selinux->{'mac_result'},       'denied', 'auditd: selinux verdict in the same mac_result' );
is( $selinux->{'audit_avc_action'}, 'denied', 'auditd: audit_avc_action kept for compat' );

# AppArmor records that carry no operation= at all (profile load failures), which
# is the shape the kernel-side pattern used to drop
my $status = $m->process_item(
	'item' => 'type=APPARMOR_STATUS msg=audit(1700000013.000:469): apparmor="STATUS" '
		. 'info="failed to unpack profile" error=-71 profile="unconfined" pid=123 comm="apparmor_parser"' );
is( $status->{'audit_apparmor'}, 'STATUS',                   'auditd: apparmor STATUS record' );
is( $status->{'audit_info'},     'failed to unpack profile', 'auditd: quoted info with spaces' );
is( $status->{'audit_error'},    -71,                        'auditd: negative error converted' );

# AppArmor dbus mediation arrives from dbus-daemon as USER_AVC, so the AppArmor
# blob is inside the nested msg='...' rather than the outer one
my $dbus = $m->process_item(
	'item' => q{type=USER_AVC msg=audit(1700000014.000:470): pid=1 uid=0 ses=3 }
		. q{msg='apparmor="DENIED" operation="dbus_method_call" bus="system" member="StartUnit" }
		. q{pid=2222 label="snap.foo.bar" peer_pid=1 peer_label="unconfined" exe="/usr/bin/dbus-daemon" sauid=0'} );
is( $dbus->{'audit_type'},           'USER_AVC',         'auditd: dbus apparmor type' );
is( $dbus->{'mac_result'},           'denied',           'auditd: dbus apparmor verdict normalized' );
is( $dbus->{'audit_msg_apparmor'},   'DENIED',           'auditd: dbus apparmor native verdict' );
is( $dbus->{'audit_msg_operation'},  'dbus_method_call', 'auditd: dbus operation from nested blob' );
is( $dbus->{'audit_msg_peer_label'}, 'unconfined',       'auditd: dbus peer label' );
is( $dbus->{'audit_uid'},            0,                  'auditd: dbus outer uid' );
ok( looks_like_number( $dbus->{'audit_msg_pid'} ), 'auditd: nested pid is numeric too' );

# non-auditd line
is( $m->process_item( 'item' => 'not an audit record' ), undef, 'auditd: non-record => undef' );

# geoip on the nested addr
SKIP: {
	my $mmdb = 't/mmdb/GeoLite2-Country-Test.mmdb';
	skip 'IP::Geolocation::MMDB not installed', 1 unless eval { require IP::Geolocation::MMDB; 1; };
	skip "test db $mmdb not found",             1 unless -f $mmdb;
	my $g = Log::Munger->new( 'rules' => ['auditd'], 'geoip' => $mmdb )->process_item(
		'item' => q{type=USER_AUTH msg=audit(1:2): pid=1 msg='op=login acct="root" addr=81.2.69.142 res=success'} );
	is( $g->{'geoip'}{'audit_msg_addr'}{'country'}{'iso_code'}, 'GB', 'auditd: geoip on nested addr' );
}

done_testing();
