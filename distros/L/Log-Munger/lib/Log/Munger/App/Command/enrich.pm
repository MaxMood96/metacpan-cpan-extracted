package Log::Munger::App::Command::enrich;

use strict;
use warnings;
use Log::Munger::App -command;
use Log::Munger;
use JSON;

sub opt_spec {
	return (
		[ 'rules|r=s@',     'Rule file to load (may be given more than once).' ],
		[ 'raw',            'Each input line is a raw log line (matched as MESSAGE) instead of NDJSON.' ],
		[ 'geoip|g=s',      'Path to a MaxMind .mmdb database for geoip enrichment.' ],
		[ 'into|i=s',       'Key to nest the enrichment under. Default: enriched.', { default => 'enriched' } ],
		[ 'flat',           'Merge the extracted fields into the record instead of nesting them.' ],
		[ 'drop-unmatched', 'Do not emit records that did not match any rule.' ],
	);
} ## end sub opt_spec

sub abstract { "Stream log lines from stdin and emit enriched NDJSON on stdout" }

sub description {
	"Reads one record per line from stdin, NDJSON or raw log lines with --raw, runs each through
the rules, and emits NDJSON. The extracted fields are nested under a key, 'enriched' unless
--into says otherwise, or merged into the record itself with --flat.

Records that matched nothing pass through unchanged unless --drop-unmatched is given. A line
that will not decode as JSON is warned about and passed through, so nothing is ever dropped
silently.
";
} ## end sub description

sub validate { return 1 }

sub execute {
	my ( $self, $opts, $args ) = @_;

	if ( !defined( $opts->{'rules'} ) || !defined( $opts->{'rules'}[0] ) ) {
		die('No rule files specified via -r');
	}

	my %margs = ( 'rules' => $opts->{'rules'} );
	$margs{'geoip'} = $opts->{'geoip'} if ( defined( $opts->{'geoip'} ) );
	my $munger = Log::Munger->new(%margs);

	my $json = JSON->new->utf8->canonical;
	my $into = $opts->{'into'};

	while ( defined( my $line = <STDIN> ) ) {
		chomp($line);
		next if ( $line eq '' );

		# build the base record + the item handed to the munger
		my ( $record, $item );
		if ( $opts->{'raw'} ) {
			$record = { 'MESSAGE' => $line };
			$item   = $line;
		} else {
			eval { $record = $json->decode($line); };
			if ( $@ || ref($record) ne 'HASH' ) {
				# not decodable JSON: never drop data -- pass the line through.
				# The warned copy has control characters stripped so a hostile
				# line cannot drive escape sequences into a watching terminal
				my $shown = $line;
				$shown =~ s/[\x00-\x1f\x7f]/./g;
				warn("skipping undecodable line: $shown\n");
				print "$line\n";
				next;
			} ## end if ( $@ || ref($record) ne 'HASH' )
			$item = $record;
		} ## end else [ if ( $opts->{'raw'} ) ]

		my $fields = $munger->process_item( 'item' => $item );

		if ( !defined($fields) ) {
			next if ( $opts->{'drop_unmatched'} );
			print $json->encode($record) . "\n";
			next;
		}

		if ( $opts->{'flat'} ) {
			foreach my $key ( keys( %{$fields} ) ) {
				$record->{$key} = $fields->{$key} unless ( exists( $record->{$key} ) );
			}
		} else {
			$record->{$into} = $fields;
		}

		print $json->encode($record) . "\n";
	} ## end while ( defined( my $line = <STDIN> ) )

	return;
} ## end sub execute

1;
