package Log::Munger::App::Command::dump_rule_file;

use strict;
use warnings;
use Log::Munger::App -command;
use Log::Munger::RuleFileParser;
use YAML::XS qw(Dump);

sub opt_spec {
	return (
		[ 'f=s',     'Rule file to read.' ],
		[ 'var|v=s', 'Dump only the resolved value of this one var (a compiled regexp), not the whole file.' ],
	);
}

sub abstract { "Dump a rule file as loaded, with includes merged and vars resolved" }

sub description {
	"Loads a rule file the way the engine does, merging its includes and resolving its templated
vars, then dumps the result as YAML.

With --var it prints only that one var's resolved value, which is how to see the regexp a
primitive actually compiles to.
";
}

sub validate { return 1 }

sub execute {
	my ( $self, $opts, $args ) = @_;

	if ( !defined( $opts->{'f'} ) ) {
		die('No rules file specified via -f');
	}

	my $parser = Log::Munger::RuleFileParser->new;
	my $rules  = $parser->load( 'file' => $opts->{'f'} );

	if ( defined( $opts->{'var'} ) ) {
		if ( ref( $rules->{'vars'} ) ne 'HASH' || !exists( $rules->{'vars'}{ $opts->{'var'} } ) ) {
			die( 'no such var "' . $opts->{'var'} . '" in "' . $opts->{'f'} . '"' );
		}
		print $rules->{'vars'}{ $opts->{'var'} } . "\n";
		return;
	}

	print Dump($rules);

	return;
} ## end sub execute

1;
