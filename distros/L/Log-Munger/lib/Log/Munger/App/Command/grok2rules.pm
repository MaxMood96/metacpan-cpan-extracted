package Log::Munger::App::Command::grok2rules;

use strict;
use warnings;
use Log::Munger::App -command;
use Log::Munger::Degrok ();

sub opt_spec {
	return (
		[ 'f=s',           'Grok patterns file to convert.' ],
		[ 'includes|i=s@', 'Rule file to treat as an include when resolving/overwriting (repeatable).' ],
		[
			'overwrite|o=s',
			'Overwrite policy for names already in an include: yes|no_silent|no_warn|no_die.',
			{ default => 'no_warn' }
		],
	);
} ## end sub opt_spec

sub abstract { "Convert a grok patterns file into a Log::Munger rules YAML skeleton" }

sub description {
	"Turns a grok patterns file, a list of 'NAME regexp' lines, into the skeleton of a rule file.
Plain lines become vars, lines referencing other patterns become vars_templated once they have
been degrokked, and the result is printed to stdout as YAML.

Naming what you already have with -i is worth doing. Most grok patterns files carry their own
copies of IP, WORD, HOSTNAME and the rest, and without the includes those all come across and
shadow the ones in base.

What comes back is a skeleton. There is no rules section, no gates and no tests, because none
of that exists in a grok patterns file to convert.
";
} ## end sub description

sub validate { return 1 }

sub execute {
	my ( $self, $opts, $args ) = @_;

	if ( !defined( $opts->{'f'} ) ) {
		die('No grok file specified via -f');
	}

	my %pass = ( 'file' => $opts->{'f'}, 'overwrite' => $opts->{'overwrite'} );
	$pass{'includes'} = $opts->{'includes'} if ( defined( $opts->{'includes'} ) );

	my $yaml;
	eval { $yaml = Log::Munger::Degrok->grok2rules(%pass); };
	if ($@) {
		die( 'Failed to convert "' . $opts->{'f'} . '"... ' . $@ );
	}

	print $yaml;

	return;
} ## end sub execute

1;
