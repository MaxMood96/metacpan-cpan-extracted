package Log::Munger::App::Command::explain;

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

sub abstract { "Show which rule/pattern a log item matched and the fields it produced" }

sub description {
	"Like munge, but reports the match itself rather than only its output: whether anything
matched, the name of the rule that fired, which of its patterns did it as a zero-based index,
the field that was matched against, and then the extracted fields as a YAML document.

This is what to reach for when a rule file is not doing what you expected, since it tells you
whether the wrong rule won or the right one matched on the wrong pattern.
";
}

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

	my %margs = ( 'rules' => $opts->{'rules'} );
	$margs{'geoip'} = $opts->{'geoip'} if ( defined( $opts->{'geoip'} ) );
	my $munger = Log::Munger->new(%margs);

	my $why = $munger->explain_item( 'item' => $item );

	if ( !$why->{'matched'} ) {
		print "matched: no\n";
		return;
	}

	print 'matched: yes' . "\n";
	print 'rule: ' . ( defined( $why->{'rule'} ) ? $why->{'rule'} : '(unnamed)' ) . "\n";
	print 'pattern: ' . $why->{'pattern'} . "\n";
	print 'field: ' . $why->{'field'} . "\n";
	print "fields:\n";
	print Dump( $why->{'fields'} );

	return;
} ## end sub execute

1;
