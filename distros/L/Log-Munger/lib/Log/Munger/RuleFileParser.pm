package Log::Munger::RuleFileParser;

use 5.006;
use strict;
use warnings;
use YAML::XS qw(Load);

# a rule file is data; never bless objects out of YAML tags. Old YAML::XS
# versions default LoadBlessed on, which is an object-injection risk when
# loading a third-party rule file
$YAML::XS::LoadBlessed = 0;
use Log::Munger::WhichRuleFile ();
use File::Slurp                qw(read_file);
use Template;
use Hash::Merge ();
use Log::Munger::RulesTemplateOrder;

=head1 NAME

Log::Munger::RuleFileParser - Reads a Log::Munger rule file into a rules hash.

=head1 VERSION

Version 0.0.1

=cut

our $VERSION = '0.0.1';

=head1 SYNOPSIS

    use Log::Munger::RuleFileParser;

    my $parser = Log::Munger::RuleFileParser->new;
    my $rules  = $parser->load( 'file' => 'sshd' );

    print $rules->{'vars'}{'SSH_FAILED'} . "\n";

Loading a rule file is four steps. The name is resolved to a path via
L<Log::Munger::WhichRuleFile>, the YAML is read in, anything under C<includes> is
merged in with the file itself winning on a conflict (and an earlier include
winning over a later one), and finally everything under C<vars_templated> is run
through L<Template> and folded into C<vars>.

That last step is why order matters: a templated var may reference another
templated var, so L<Log::Munger::RulesTemplateOrder> sorts them by dependency
first and each one is resolved only once everything it references already is.

Trailing newlines are stripped from every var at every step. A YAML C<|> block
scalar keeps its terminating newline, and one of those landing in the middle of a
composed pattern would quietly stop it matching single line logs.

=head1 METHODS

=head2 new

Creates a parser. Takes no arguments.

    my $parser = Log::Munger::RuleFileParser->new;

=cut

sub new {
	my ( $blank, %opts ) = @_;

	my $self = {};
	bless $self;

	return $self;
}

=head2 load

Loads a rule file, merging its includes and resolving its templated vars.

Every resolved C<vars_templated> entry is written back into C<< $rules->{vars} >>,
so by the time this returns there is one flat namespace of named regexps and
C<vars_templated> is only of interest for seeing how a var was written.

    - file :: The file to load. Either a bare name resolved through the search
        path, such as "sshd", or a path. Required.
        Default :: undef

Returns the rules hash ref. Dies if the file cannot be found, is not valid YAML,
does not parse to a hash, names an include that cannot be found, references a var
that is not defined anywhere, or holds a var that will not template.

    my $rules = $parser->load( 'file' => 'sshd' );

=cut

sub load {
	my ( $self, %opts ) = @_;

	if ( !defined( $opts{'file'} ) ) {
		die('$opts{file} is undef');
	} elsif ( ref( $opts{'file'} ) ne '' ) {
		die( '$opts{file} ref is "' . ref( $opts{'file'} ) . '" and not ""' );
	}

	my $rules;
	eval { $rules = $self->load_no_templating( 'file' => $opts{'file'} ); };
	if ($@) {
		die( 'Failed to call load_no_templating for "' . $opts{'file'} . '"... ' . $@ );
	}

	my $template_order = Log::Munger::RulesTemplateOrder->order_for_rules_hash( 'rules' => $rules );

	my $tt = Template->new;

	my $template_hash = 'vars_templated';
	if ( defined( $rules->{$template_hash} ) ) {
		if ( ref( $rules->{$template_hash} ) ne 'HASH' ) {
			die(      '$rules->{'
					. $template_hash
					. '} exists and is of ref "'
					. ref( $rules->{$template_hash} )
					. '" and not HASH' );
		}

		foreach my $item ( @{$template_order} ) {
			# strip trailing newlines off the template source so a block-scalar
			# terminator does not survive into the composed pattern
			$rules->{$template_hash}{$item} = _normalized_var_value( $rules->{$template_hash}{$item},
				'$rules->{' . $template_hash . '}{' . $item . '}' );

			my $results;
			$tt->process( \$rules->{$template_hash}{$item}, $rules->{'vars'}, \$results )
				|| die( 'Failed to process $rules->{' . $template_hash . '}{' . $item . '} ... ' . $tt->error() );
			# strip before writing back to the stash: dependency ordering means
			# this value may be interpolated into a later var, and an embedded
			# newline mid-pattern would keep it from matching single-line logs
			$results =~ s/[\r\n]+\z//;
			$rules->{'vars'}{$item} = $results;
		} ## end foreach my $item ( @{$template_order} )
	} ## end if ( defined( $rules->{$template_hash} ) )

	return $rules;
} ## end sub load

=head2 load_no_templating

Same as L</load>, but stops short of resolving C<vars_templated>. The includes are
still merged and the plain C<vars> are still normalized, so what comes back is the
rule file as written rather than as compiled.

This is what the template ordering tooling uses. Working out which var depends on
which means reading the C<[% VAR %]> references before they are substituted away.

    - file :: The file to load. Either a bare name resolved through the search
        path, such as "sshd", or a path. Required.
        Default :: undef

Returns the rules hash ref, with C<vars_templated> left untouched. Dies under the
same conditions as L</load>, minus the templating.

    my $rules = $parser->load_no_templating( 'file' => 'sshd' );

=cut

sub load_no_templating {
	my ( $self, %opts ) = @_;

	if ( !defined( $opts{'file'} ) ) {
		die('$opts{file} is undef');
	} elsif ( ref( $opts{'file'} ) ne '' ) {
		die( '$opts{file} ref is "' . ref( $opts{'file'} ) . '" and not ""' );
	}

	my $file_location = Log::Munger::WhichRuleFile->rule_file_location( 'file' => $opts{'file'} );

	if ( !defined($file_location) ) {
		die(      '"'
				. $opts{'file'}
				. '" could not be found by Log::Munger::WhichRuleFile->rule_file_location(file =>"'
				. $opts{'file'}
				. '")' );
	}

	my $rules;
	eval { $rules = _read_yaml_hash($file_location); };
	if ($@) {
		die( 'Failed to read in and parse "' . $file_location . '"... ' . $@ );
	}

	if ( defined( $rules->{'includes'} ) ) {
		if ( ref( $rules->{'includes'} ) ne 'ARRAY' ) {
			die(      '.includes in "'
					. $file_location
					. '" is of ref "'
					. ref( $rules->{'includes'} )
					. '" and not "ARRAY"' );
		}
		if ( defined( $rules->{'includes'}[0] ) ) {
			# LEFT_PRECEDENT with the file on the left: the file wins a conflict
			# with an include, and an earlier include wins over a later one.
			# Arrays merge by appending the include's entries, which is also what
			# lets the loop below pick up an include's own includes as they are
			# merged in
			my $merger = Hash::Merge->new('LEFT_PRECEDENT');
			my %included;
			my $include_int = 0;
			while ( defined( $rules->{'includes'}[$include_int] ) ) {
				if ( ref( $rules->{'includes'}[$include_int] ) ne '' ) {
					die(      '.includes.'
							. $include_int
							. ' is a ref of "'
							. ref( $rules->{'includes'}[$include_int] )
							. '" and not ""' );
				}

				if ( !$included{ $rules->{'includes'}[$include_int] } ) {
					$included{ $rules->{'includes'}[$include_int] } = 1;

					my $include_location = Log::Munger::WhichRuleFile->rule_file_location(
						'file' => $rules->{'includes'}[$include_int] );
					if ( !defined($include_location) ) {
						die(      '.includes.'
								. $include_int . ', "'
								. $rules->{'includes'}[$include_int]
								. '", could not be found by Log::Munger::WhichRuleFile->rule_file_location' );
					}
					my $rule_include;
					eval { $rule_include = _read_yaml_hash($include_location); };
					if ($@) {
						die(      '.includes.'
								. $include_int . ', "'
								. $rules->{'includes'}[$include_int]
								. '", could not be loaded... '
								. $@ );
					}

					$rules = $merger->merge( $rules, $rule_include );
				} ## end if ( !$included{ $rules->{'includes'}[$include_int...]})

				$include_int++;
			} ## end while ( defined( $rules->{'includes'}[$include_int...]))

		} ## end if ( defined( $rules->{'includes'}[0] ) )
	} ## end if ( defined( $rules->{'includes'} ) )

	if ( defined( $rules->{'vars'} ) ) {
		if ( ref( $rules->{'vars'} ) ne 'HASH' ) {
			die( '$rules->{vars} exists and is of ref "' . ref( $rules->{'vars'} ) . '" and not HASH' );
		}

		foreach my $item ( keys( %{ $rules->{'vars'} } ) ) {
			# every plain var feeds the Template Toolkit stash; strip trailing
			# newlines (YAML "|" block-scalar terminators) so they cannot leak
			# into the middle of a composed pattern during templating
			$rules->{'vars'}{$item} = _normalized_var_value( $rules->{'vars'}{$item}, '$rules->{vars}{' . $item . '}' );
		}
	} ## end if ( defined( $rules->{'vars'} ) )

	return $rules;
} ## end sub load_no_templating

# Reads a YAML file and returns the hash ref it parses to.
#
# Args:
#
#     - $path :: The path of the file to read.
#
# Returns the parsed hash ref. Dies when the file cannot be read, is not valid
# YAML, or parses to something other than a hash, such as a list or nothing at
# all.
#
#     my $rules = _read_yaml_hash($file_location);
sub _read_yaml_hash {
	my ($path) = @_;

	my $raw    = read_file($path);
	my $parsed = Load($raw);
	if ( !defined($parsed) ) {
		die( 'Load(read_file("' . $path . '")) returned undef' );
	}
	if ( ref($parsed) ne 'HASH' ) {
		die( 'Load(read_file("' . $path . '")) returned a ref of "' . ref($parsed) . '" and not "HASH"' );
	}

	return $parsed;
} ## end sub _read_yaml_hash

# Normalizes one var value as it came out of the YAML. A value written as an
# array of strings is joined into a single string, and trailing newlines are
# stripped, since a YAML "|" block scalar keeps its terminating newline and one
# of those landing in the middle of a composed pattern would quietly stop it
# matching single-line logs.
#
# Args:
#
#     - $value :: The value as YAML::XS returned it. A plain string or an
#         array ref of strings.
#
#     - $where :: Where the value lives, such as '$rules->{vars}{FOO}'. Used in
#         the die message.
#
# Returns the normalized string. Dies when the value is neither a plain string
# nor an array ref.
#
#     $rules->{'vars'}{$item} = _normalized_var_value( $rules->{'vars'}{$item}, '$rules->{vars}{' . $item . '}' );
sub _normalized_var_value {
	my ( $value, $where ) = @_;

	if ( ( ref($value) ne 'ARRAY' ) && ( ref($value) ne '' ) ) {
		die( $where . ' is of ref "' . ref($value) . '" and not "ARRAY" or ""' );
	}
	if ( ref($value) eq 'ARRAY' ) {
		$value = join( '', @{$value} );
	}
	$value =~ s/[\r\n]+\z//;

	return $value;
} ## end sub _normalized_var_value

1;    # End of Log::Munger::RuleFileParser
