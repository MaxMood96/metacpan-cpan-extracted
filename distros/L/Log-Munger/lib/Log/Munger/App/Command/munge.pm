package Log::Munger::App::Command::munge;

use strict;
use warnings;
use Log::Munger::App -command;
use Log::Munger;
use JSON;
use YAML::XS qw(Dump);

sub opt_spec {
	return (
		[ 'rules|r=s@', 'Rule file to load (may be given more than once).' ],
		[ 'string|s=s', 'Item to process. If not given, one is read from stdin.' ],
		[ 'raw',        'Treat the item as a raw log line (matched as MESSAGE) instead of JSON.' ],
		[ 'geoip|g=s',  'Path to a MaxMind .mmdb database for geoip enrichment.' ],
	);
}

sub abstract { "Run one log item through the rules and dump the extracted fields" }

sub description {
	"Reads a single item from -s, or from stdin if -s is not given, runs it through the rules, and
prints the winning rule's captured fields as YAML. If nothing matched it prints '--- ~', a YAML
null.

--raw only sets MESSAGE, so a rule gating on another field, as sshd gates on PROGRAM, will not
match a raw line. Feed those a JSON record that includes the gate field. --raw is for gateless
whole-line rules such as http_access_logs.
";
} ## end sub description

sub validate { return 1 }

sub execute {
	my ( $self, $opts, $args ) = @_;

	if ( !defined( $opts->{'rules'} ) || !defined( $opts->{'rules'}[0] ) ) {
		die('No rule files specified via -r');
	}

	my $raw = $opts->{'string'};
	if ( !defined($raw) ) {
		local $/ = undef;
		$raw = <STDIN>;
	}
	if ( !defined($raw) ) {
		die('No item given via -s or on stdin');
	}

	my $item;
	if ( $opts->{'raw'} ) {
		chomp($raw);
		$item = $raw;
	} else {
		eval { $item = decode_json($raw); };
		if ($@) {
			die( 'Failed to decode the item as JSON (use --raw for a plain log line)... ' . $@ );
		}
	}

	my %args = ( 'rules' => $opts->{'rules'} );
	$args{'geoip'} = $opts->{'geoip'} if ( defined( $opts->{'geoip'} ) );
	my $munger = Log::Munger->new(%args);

	my $fields = $munger->process_item( 'item' => $item );

	if ( defined($fields) ) {
		print Dump($fields);
	} else {
		print "--- ~\n";    # YAML null -- nothing matched
	}

	return;
} ## end sub execute

1;
