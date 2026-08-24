package Log::Munger::App::Command::degrok;

use strict;
use warnings;
use Log::Munger::App -command;
use Log::Munger::Degrok;

sub opt_spec {
	return (
		[ 's=s',  'A string to convert.' ],
		[ 'f=s',  'A file to convert.' ],
		[ 'r',    'With -f, emit a rules file skeleton instead of the rewritten file.' ],
		[ 'i=s@', 'Rule file to treat as an include, for -r (repeatable).' ],
		[ 'o=s',  'Overwrite policy for names already in an include: yes|no_silent|no_warn|no_die.' ],
	);
}

sub abstract { "Rewrite grok templating into the Log::Munger form" }

sub description {
	'Grok references a named pattern as "%{TEMPLATE}" and captures one as "%{TEMPLATE:VAR}".
Log::Munger writes those as "[% TEMPLATE %]" and "(?<VAR>[% TEMPLATE %])" respectively. This
rewrites the first form into the second.

Give it either -s for a string or -f for a file, not both. Adding -r to -f produces a rules
file skeleton rather than the rewritten file, which is what the grok2rules command does.
';
}

sub validate { return 1 }

sub execute {
	my ( $self, $opts, $args ) = @_;

	if ( !defined( $opts->{'s'} ) && !defined( $opts->{'f'} ) ) {
		die('Either -s or -f need specified');
	} elsif ( defined( $opts->{'s'} ) && defined( $opts->{'f'} ) ) {
		die('-s and -f can not be used together');
	}

	if ( defined( $opts->{'s'} ) ) {
		print Log::Munger::Degrok->string( 'string' => $opts->{'s'} ) . "\n";
	} elsif ( defined( $opts->{'f'} ) ) {
		if ( !-f $opts->{'f'} ) {
			die( '"' . $opts->{'f'} . '" is not a file' );
		} elsif ( !-r $opts->{'f'} ) {
			die( '"' . $opts->{'f'} . '" is not readable' );
		}

		my $results;
		if ( $opts->{'r'} ) {
			$results = Log::Munger::Degrok->grok2rules(
				'file'      => $opts->{'f'},
				'includes'  => $opts->{'i'},
				'overwrite' => $opts->{'o'}
			) . "\n";
		} else {
			$results = Log::Munger::Degrok->file( 'file' => $opts->{'f'} ) . "\n";
		}
		print $results;
	} ## end elsif ( defined( $opts->{'f'} ) )
} ## end sub execute

1;
