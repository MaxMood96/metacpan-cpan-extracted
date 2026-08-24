#!perl
use 5.006;
use strict;
use warnings;
use Test::More;

BEGIN {
	use_ok('Log::Munger') || print "Bail out!\n";
}

#
# The two web-server rule files, from the outside.
#
# Both are gateless: they carry no PROGRAM gate because these lines arrive off a
# log file rather than syslog, so the only thing keeping an access line and an
# error line apart is the shape of the line itself. That is a property of the
# engine's first-match-wins ordering rather than of any one pattern, so it is
# asserted here rather than in the files' own tests.
#
# That both files test clean is asserted in t/all_rules_clean.t.
#

#
# access logs
#
my $access = Log::Munger->new( 'rules' => ['http_access_logs'] );
isa_ok( $access, 'Log::Munger' );

# a raw combined line fed straight in as a string (no wrapping hash)
my $combined
	= '127.0.0.1 - frank [10/Oct/2000:13:55:36 -0700] "GET /apache_pb.gif HTTP/1.0" 200 2326 '
	. '"http://www.example.com/start.html" "Mozilla/4.08 [en] (Win98; I ;Nav)"';
is_deeply(
	$access->process_item( 'item' => $combined ),
	{   http_clientip    => '127.0.0.1',
		http_ident       => '-',
		http_auth        => 'frank',
		http_timestamp   => '10/Oct/2000:13:55:36 -0700',
		http_verb        => 'GET',
		http_request     => '/apache_pb.gif',
		http_httpversion => '1.0',
		http_response    => '200',
		http_bytes       => '2326',
		http_referrer    => 'http://www.example.com/start.html',
		http_agent       => 'Mozilla/4.08 [en] (Win98; I ;Nav)',
	},
	'raw combined access line enriches (string item)'
);

# a plain Common Log Format line via a MESSAGE hash (syslog-style delivery)
is_deeply(
	$access->process_item(
		'item' => { MESSAGE => '192.168.1.1 - - [12/Jul/2026:08:15:50 +0000] "GET / HTTP/1.1" 304 -' } ),
	{   http_clientip    => '192.168.1.1',
		http_ident       => '-',
		http_auth        => '-',
		http_timestamp   => '12/Jul/2026:08:15:50 +0000',
		http_verb        => 'GET',
		http_request     => '/',
		http_httpversion => '1.1',
		http_response    => '304',
	},
	'common log format via MESSAGE hash ("-" bytes omitted)'
);

# non-access text does not match
is( $access->process_item( 'item' => 'just some noise' ), undef, 'non-access line => undef' );

#
# error logs
#
my $error = Log::Munger->new( 'rules' => ['http_error_logs'] );
isa_ok( $error, 'Log::Munger' );

# apache 2.4 error line fed straight in as a raw string
is_deeply(
	$error->process_item(
		'item' => '[Wed Oct 11 14:32:52.123456 2000] [core:error] [pid 12345:tid 140234] '
			. '[client 192.168.1.1:1234] AH00128: File does not exist: /var/www/html/favicon.ico'
	),
	{   http_error_timestamp   => 'Wed Oct 11 14:32:52.123456 2000',
		http_error_module      => 'core',
		http_error_loglevel    => 'error',
		http_error_pid         => '12345',
		http_error_tid         => '140234',
		http_error_client_ip   => '192.168.1.1',
		http_error_client_port => '1234',
		http_error_code        => 'AH00128',
		http_error_message     => 'File does not exist: /var/www/html/favicon.ico',
	},
	'apache 2.4 error line enriches (raw string)'
);

# nginx error with the structured tail, via a MESSAGE hash
is_deeply(
	$error->process_item(
		'item' => {
			MESSAGE => '2000/10/11 14:32:52 [error] 12345#0: *67 open() "/x" failed (2: No such file or directory)'
				. ', client: 192.168.1.1, server: example.com, request: "GET /favicon.ico HTTP/1.1", host: "example.com"'
		}
	),
	{   http_error_timestamp    => '2000/10/11 14:32:52',
		http_error_loglevel     => 'error',
		http_error_pid          => '12345',
		http_error_tid          => '0',
		http_error_connectionid => '67',
		http_error_message      => 'open() "/x" failed (2: No such file or directory)',
		http_error_client_ip    => '192.168.1.1',
		http_error_server       => 'example.com',
		http_error_request      => 'GET /favicon.ico HTTP/1.1',
		http_error_host         => 'example.com',
	},
	'nginx error line enriches with structured tail'
);

#
# the two must not reach into each other. Both are gateless, so with only one
# of them loaded a line belonging to the other has to come back as a miss.
#
is( $error->process_item( 'item' => '127.0.0.1 - - [12/Jul/2026:08:15:50 +0000] "GET / HTTP/1.1" 200 12' ),
	undef, 'access line => undef under error rules' );
is( $access->process_item(
		'item' => '[Wed Oct 11 14:32:52.123456 2000] [core:error] [pid 12345:tid 140234] '
			. '[client 192.168.1.1:1234] AH00128: File does not exist: /favicon.ico'
	),
	undef,
	'error line => undef under access rules'
);

done_testing();
