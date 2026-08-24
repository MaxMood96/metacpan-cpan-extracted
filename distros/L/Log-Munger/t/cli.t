#!perl
use 5.006;
use strict;
use warnings;
use Test::More;
use File::Temp ();
use FindBin    ();

BEGIN { use_ok('Log::Munger') || print "Bail out!\n"; }

# resolve names against the working tree's rule files, not an installed copy;
# the CLI subprocesses below inherit this through the environment
$ENV{'LOG_MUNGER_RULES_DIR'} = $FindBin::Bin . '/../share' if ( -d $FindBin::Bin . '/../share' );

# ---- explain_item (the shared matcher used by the explain command) ----
my $m   = Log::Munger->new( 'rules' => [ 'base', 'postfix' ] );
my $why = $m->explain_item( 'item' => { PROGRAM => 'postfix/qmgr', MESSAGE => 'ABCDEF123456: removed' } );
is( $why->{'matched'}, 1,              'explain_item: matched' );
is( $why->{'rule'},    'postfix_qmgr', 'explain_item: rule name' );
is( $why->{'pattern'}, 0,              'explain_item: pattern index' );
is( $why->{'fields'}{'postfix_queueid'}, 'ABCDEF123456', 'explain_item: fields' );
is( $m->explain_item( 'item' => { PROGRAM => 'cron', MESSAGE => 'x' } )->{'matched'}, 0, 'explain_item: no match' );

# process_item still works after the refactor
is_deeply(
	$m->process_item( 'item' => { PROGRAM => 'postfix/qmgr', MESSAGE => 'ABCDEF123456: removed' } ),
	{ 'postfix_queueid' => 'ABCDEF123456' },
	'process_item unchanged'
);

# ---- the CLI (skipped if the app is not built) ----
my $script = 'blib/script/log_munger';
SKIP: {
	skip 'built CLI (blib/script/log_munger) not present', 6 unless -f $script;

	my @inc = ( '-Ilib', '-Iblib/lib' );
	my $run = sub {
		my @cmd = @_;
		open( my $fh, '-|', $^X, @inc, $script, @cmd ) or return '';
		local $/ = undef;
		my $out = <$fh>;
		close($fh);
		return defined($out) ? $out : '';
	};

	like( $run->('list'), qr/^postfix$/m, 'CLI list: shows postfix' );
	like( $run->('list'), qr/^auditd$/m, 'CLI list: shows auditd' );
	like( $run->( 'list_fields', '-f', 'sshd' ), qr/ssh_src_ip/, 'CLI list_fields: ssh_src_ip' );
	like(
		$run->( 'dump_rule_file', '-f', 'postfix', '--var', 'POSTFIX_REMOVED' ),
		qr/postfix_queueid/,
		'CLI dump_rule_file --var: resolved regexp'
	);
	like(
		$run->( 'explain', '-r', 'sshd', '-s', '{"PROGRAM":"sshd","MESSAGE":"Failed password for root from 1.2.3.4 port 22 ssh2"}' ),
		qr/matched: yes.*rule: sshd/s,
		'CLI explain: matched rule'
	);
	like(
		$run->( 'munge', '-r', 'base', '-r', 'postfix', '-s', '{"PROGRAM":"postfix/qmgr","MESSAGE":"ABCDEF123456: removed"}' ),
		qr/postfix_queueid: ABCDEF123456/,
		'CLI munge: dumps fields'
	);
}

# ---- the remaining subcommands (also skipped if the app is not built) ----
SKIP: {
	skip 'built CLI (blib/script/log_munger) not present', 10 unless -f $script;

	my @inc = ( '-Ilib', '-Iblib/lib' );
	my $run = sub {
		my @cmd = @_;
		open( my $fh, '-|', $^X, @inc, $script, @cmd ) or return '';
		local $/ = undef;
		my $out = <$fh>;
		close($fh);
		return defined($out) ? $out : '';
	};
	my $status = sub {
		# run with stdout/stderr silenced; return the exit code
		my @cmd = @_;
		my $pid = fork();
		if ( !$pid ) {
			open( STDOUT, '>', '/dev/null' );
			open( STDERR, '>', '/dev/null' );
			exec( $^X, @inc, $script, @cmd );
			exit(127);
		}
		waitpid( $pid, 0 );
		return $? >> 8;
	};

	# which_rule_file
	like( $run->( 'which_rule_file', '-f', 'base' ), qr/base\.yaml/, 'CLI which_rule_file: resolves a path' );
	is( $status->( 'which_rule_file', '-f', 'no_such_rule_file_xyz' ), 1, 'CLI which_rule_file: exit 1 when not found' );

	# test_rule_file (drives RulesTest, dumps a YAML results hash)
	like( $run->( 'test_rule_file', '-f', 'postfix' ), qr/errors:/, 'CLI test_rule_file: dumps a results hash' );

	# test_all (summary line over every discoverable rule file)
	like( $run->('test_all'), qr/\d+ file\(s\), \d+ failed/, 'CLI test_all: prints a summary' );

	# rule_file_template_order (order and depends views)
	like( $run->( 'rule_file_template_order', '-f', 'base' ),       qr/\bDATE\b/,   'CLI rule_file_template_order: prints an order' );
	like( $run->( 'rule_file_template_order', '-f', 'base', '-d' ), qr/DATESTAMP/, 'CLI rule_file_template_order -d: prints depends' );

	# degrok (string form)
	like( $run->( 'degrok', '-s', '%{FOO:bar}' ), qr/\(\?<bar>\[% FOO %\]\)/, 'CLI degrok: translates a grok string' );

	# grok2rules (file form)
	my ( $gfh, $gpath ) = File::Temp::tempfile( UNLINK => 1 );
	print {$gfh} "MYSTAMP %{YEAR}-%{MONTHNUM}\n";
	close($gfh);
	like( $run->( 'grok2rules', '-f', $gpath ), qr/MYSTAMP/,      'CLI grok2rules: emits YAML with the var' );
	like( $run->( 'grok2rules', '-f', $gpath ), qr/\[% YEAR %\]/, 'CLI grok2rules: degrokked value in output' );
}

# ---- enrich streams stdin -> stdout, so it needs its own runner ----
SKIP: {
	skip 'built CLI (blib/script/log_munger) not present', 1 unless -f $script;
	require IPC::Open2;

	my @inc = ( '-Ilib', '-Iblib/lib' );
	my $out = '';
	eval {
		my $pid = IPC::Open2::open2( my $rd, my $wr, $^X, @inc, $script, 'enrich', '-r', 'base', '-r', 'postfix' );
		print {$wr} qq({"PROGRAM":"postfix/qmgr","MESSAGE":"ABCDEF123456: removed"}\n);
		close($wr);
		local $/ = undef;
		$out = <$rd>;
		close($rd);
		waitpid( $pid, 0 );
	};
	like( $out, qr/postfix_queueid.*ABCDEF123456/, 'CLI enrich: nests extracted fields into NDJSON' );
}

done_testing();
