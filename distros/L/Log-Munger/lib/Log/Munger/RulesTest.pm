package Log::Munger::RulesTest;

use 5.006;
use strict;
use warnings;
use Template;
use Log::Munger::RuleFileParser;
use Log::Munger::LogProcessor ();
use B                         ();

=head1 NAME

Log::Munger::RulesTest - Runs a rule file's own tests and lints it for the usual mistakes.

=head1 VERSION

Version 0.0.1

=cut

our $VERSION = '0.0.1';

=head1 SYNOPSIS

    use Log::Munger::RulesTest;

    my $results = Log::Munger::RulesTest->test( 'file' => 'postfix' );

    if ( defined( $results->{'fatal'} ) ) {
        print 'File could not be loaded... ' . $results->{'fatal'} . "\n";
    } else {
        print 'Errors:'   . "\n" . join( "\n", @{ $results->{'errors'} } )   . "\n\n";
        print 'Warnings:' . "\n" . join( "\n", @{ $results->{'warnings'} } ) . "\n\n";
    }

A rule file carries its own tests. Each primitive under C<vars> has positive and
negative cases under C<vars_tests>, each rule has a C<tests> block naming strings
that should and should not match, and each C<decompose> entry has its own
C<tests>. This module is what runs all of that, along with a lint pass over every
resolved var.

A rule's test case may also name the program the line arrived under, which is
what puts the rule's C<gate> under test alongside its patterns:

    tests:
      positive:
        # the gate has to let dnsmasq-dhcp through before the patterns are tried
        - string: 'DHCPACK(eth0) 192.0.2.50 aa:bb:cc:dd:ee:ff myhost'
          program: 'dnsmasq-dhcp'
          result:
            dnsmasq_dhcp_type: 'DHCPACK'
            dnsmasq_dhcp_iface: 'eth0'
            dnsmasq_dhcp_ip: '192.0.2.50'
            dnsmasq_dhcp_mac: 'aa:bb:cc:dd:ee:ff'
            dnsmasq_dhcp_hostname: 'myhost'
      negative:
        # a plain string is a line no pattern may match, whatever the program
        - 'this is not a dnsmasq line at all'
        # naming a program instead says the gate must not let this daemon in,
        # even though the line itself is one the patterns handle
        - string: 'DHCPACK(eth0) 192.0.2.50 aa:bb:cc:dd:ee:ff myhost'
          program: 'dhcpd'

Naming a program is worth the line it costs. A wrong pattern loses one message
type; a wrong gate loses the daemon, and every pattern test still passes while it
does. Gates are checked against a record holding nothing but C<PROGRAM>, which is
what every gate any rule file has needed keys on.

A case may also carry a C<numeric> list, naming the fields the file's C<convert>
has to have turned into numbers:

    - string: 'Maximum number of concurrent DNS queries reached (max: 150)'
      program: 'dnsmasq'
      numeric:
        - dnsmasq_max_queries
      result:
        # captures are compared as the strings they are, before any conversion
        dnsmasq_max_queries: '150'

C<result> and C<numeric> are asking different questions of the same case, which
is why both can name the same field. C<result> compares the raw capture, which is
the string C<'150'>. C<numeric> runs decompose and convert over a copy of those
captures and asks what C<'150'> became -- so a field a decompose produced can be
listed too, which is the case worth covering most: a kv blob split into fields,
one of which a convert then coerces.

What C<numeric> checks is how perl is holding the value, not what it looks like.
Asking C<looks_like_number> would pass on the captured string whether the convert
ran or not, which is the one thing the case was written to find out.

An C<enriched> map says what the whole field set looks like at the same point,
which is what puts a C<decompose> under test as the rule really uses it:

    - string: 'neti : TTY=pts/0 ; PWD=/home/neti ; USER=root ; COMMAND=/bin/ls -la'
      program: 'sudo'
      result:
        # the raw captures: one blob, not yet split
        sudo_user: 'neti'
        sudo_kv: 'TTY=pts/0 ; PWD=/home/neti ; USER=root ; COMMAND=/bin/ls -la'
      enriched:
        # and what a consumer receives
        sudo_user: 'neti'
        sudo_TTY: 'pts/0'
        sudo_PWD: '/home/neti'
        sudo_USER: 'root'
        sudo_COMMAND: '/bin/ls -la'

A decompose entry's own C<tests> feed it a hand-written input, which says the
entry works but not that anything is wired to it: rename the capture it reads and
those tests still pass while the rule quietly stops splitting. C<enriched> is
compared exactly in both directions, so the missing fields are caught.

Nothing here needs live log data or a running system, so it is cheap enough to
wire into CI. That is what C<log_munger test_all> does, and it exits non-zero if
any file reports an error. C<log_munger test_rule_file -f E<lt>fileE<gt>> does the
same thing for one file and dumps the whole result as YAML.

=head1 METHODS

=head2 test

Runs a rule file's tests and lints it, gathering everything that went wrong rather
than stopping at the first problem.

Give it either C<file> or C<hash>, not both and not neither. Beyond that, it
reports rather than dies: a rule file bad enough that it will not even load comes
back as a C<fatal>, not an exception.

The checks are:

=over 4

=item * Every C<vars_tests> entry. The var is spliced into the entry's
C<test_template>, then each positive case has to match with C<TEST> capturing the
expected result, and no negative case may match with C<TEST> captured. A negative
that matches without capturing C<TEST> is a warning, not an error.

=item * Every resolved var, linted for leftover grok C<%{...}>, named captures
Perl will not accept, embedded newlines, and anything that will not compile.

=item * Every rule, compiled exactly as L<Log::Munger::LogProcessor> compiles it,
then run against its C<tests>. Positive strings have to match with the expected
captures and negative strings have to match nothing. A pattern that looks like a
var reference but names no existing var is flagged, since the engine would
silently treat it as an inline regexp.

=item * Every rule's C<gate>, for the test cases that name a C<program>. A
positive case naming one requires the gate to accept it before the patterns are
tried; a negative case naming one passes if the gate refuses it or no pattern
matches. A gated rule no case names a program for is a warning.

=item * Every rule's C<convert>, for the test cases carrying a C<numeric> list.
The case's captures are run through decompose and convert on a copy, and each
field named has to come out held as a number rather than as the string the
pattern captured. A rule that converts a field to a number and lists none is a
warning.

=item * Every rule's C<decompose>, for the test cases carrying an C<enriched> map.
The case's captures are run through decompose and convert on a copy, and the
whole field set is compared exactly. A rule whose decompose fires for one of its
own tests and says nothing about the result is a warning.

=item * Every C<decompose> entry, rule level and file level, applied on its own to
its C<tests> input and checked against the expected output.

=item * A file level C<convert> map, for types that are not recognised.

=back

Anything that would produce wrong output is an error. Anything merely worth
knowing, such as a var or rule with no tests at all, is a warning.

    - file :: The file to load and test. Either a bare name resolved through the
        search path, such as "postfix", or a path.
        Default :: undef

    - hash :: An already loaded rules hash ref to test instead of a file.
        Default :: undef

Returns a hash ref:

    - fatal :: The reason the file could not be loaded, or undef if it loaded.
        When this is set the other two are empty, since nothing could be tested.

    - errors :: Array ref of strings, each naming a problem that would produce
        wrong output. Empty if there were none.

    - warnings :: Array ref of strings, each naming something worth knowing that
        is not itself a failure. Empty if there were none.

Every message is prefixed with where the problem is, written as a path into the
rule file, so C<.rules.3.tests.positive.0> is the first positive test of the
fourth rule.

Dies only if neither C<file> nor C<hash> was given, if both were, or if either is
of the wrong type.

    my $results = Log::Munger::RulesTest->test( 'file' => 'postfix' );
    my $results = Log::Munger::RulesTest->test( 'hash' => $rules_hash );

=cut

sub test {
	my ( $blank, %opts ) = @_;

	if ( !defined( $opts{'hash'} ) && !defined( $opts{'file'} ) ) {
		die('$opts{hash} and $opts{file} are both undef and one needs to be defined');
	} elsif ( defined( $opts{'hash'} ) && defined( $opts{'file'} ) ) {
		die('$opts{hash} and $opts{file} are both defined and only one should be');
	} elsif ( defined( $opts{'hash'} ) && ref( $opts{'hash'} ) ne 'HASH' ) {
		die( '$opts{hash} has a ref of "' . ref( $opts{'hash'} ) . '" and not "HASH"' );
	} elsif ( defined( $opts{'file'} ) && ref( $opts{'file'} ) ne '' ) {
		die( '$opts{file} has a ref of "' . ref( $opts{'file'} ) . '" and not ""' );
	}

	if ( defined( $opts{'file'} ) ) {
		eval {
			my $parser = Log::Munger::RuleFileParser->new;
			$opts{'hash'} = $parser->load( 'file' => $opts{'file'} );
		};
		if ($@) {
			return {
				'fatal'    => '"' . $opts{'file'} . '" could not be loaded... ' . $@,
				'errors'   => [],
				'warnings' => [],
			};
		}
	} ## end if ( defined( $opts{'file'} ) )

	my $rules = $opts{'hash'};

	my @errors;
	my @warnings;

	my $vars_testable = 0;
	if ( defined( $rules->{'vars'} ) ) {
		if ( ref( $rules->{'vars'} ) eq 'HASH' ) {
			$vars_testable = 1;
		} else {
			push( @errors, '.vars has a ref of "' . ref( $rules->{'vars'} ) . '" and not "HASH"' );
		}
	} else {
		push( @warnings, '.vars is undef' );
	}

	my $has_var_tests = 0;
	if ( defined( $rules->{'vars_tests'} ) ) {
		if ( ref( $rules->{'vars_tests'} ) eq 'HASH' ) {
			$has_var_tests = 1;
		} else {
			push( @errors, '.vars_tests has a ref of "' . ref( $rules->{'vars_tests'} ) . '" and not "HASH"' );
		}
	} elsif ( defined( $rules->{'vars'} ) ) {
		push( @warnings, '.vars_tests is undef even though .vars exists, meaning there are no tests for it' );
	}

	##
	## process everything under .vars_tests
	##
	if ( $has_var_tests && $vars_testable ) {
		# tracked so that, once the tests are done, any var that never showed up
		# here can be reported as untested
		my %tested_vars;
		my $tt = Template->new();
		foreach my $var ( keys( %{ $rules->{'vars_tests'} } ) ) {
			$tested_vars{$var} = 1;
			_test_var( $var, $rules, $tt, \@errors, \@warnings );
		}

		#
		# since we are done with var tests, look for any vars we've not done any tests for
		#
		foreach my $var ( keys( %{ $rules->{'vars'} } ) ) {
			if ( !$tested_vars{$var} ) {
				push( @warnings, '.vars.' . $var . ' lacks any tests' );
			}
		}
	} ## end if ( $has_var_tests && $vars_testable )

	##
	## lint every resolved var value for problems that break matching
	##
	if ($vars_testable) {
		foreach my $var ( sort keys( %{ $rules->{'vars'} } ) ) {
			my $value = $rules->{'vars'}{$var};
			next if ( ref($value) ne '' );    # ref problems already reported above
			push( @errors, _lint_regexp_string( '.vars.' . $var, $value ) );
		}
	}

	##
	## process everything under .rules
	##
	if ( defined( $rules->{'rules'} ) ) {
		if ( ref( $rules->{'rules'} ) ne 'ARRAY' ) {
			push( @errors, '.rules has a ref of "' . ref( $rules->{'rules'} ) . '" and not "ARRAY"' );
		} else {
			my $vars = ( ref( $rules->{'vars'} ) eq 'HASH' ) ? $rules->{'vars'} : {};

			my $rule_int = 0;
			foreach my $rule ( @{ $rules->{'rules'} } ) {
				my $where = '.rules.' . $rule_int;
				if ( ref($rule) ne 'HASH' ) {
					push( @errors, $where . ' has a ref of "' . ref($rule) . '" and not "HASH"' );
					$rule_int++;
					next;
				}

				# a pattern that references a name absent from vars is silently
				# treated as an inline regexp by the engine; an all-caps name is
				# almost certainly a typo'd var reference, so flag it loudly
				if ( ref( $rule->{'patterns'} ) eq 'ARRAY' ) {
					my $pattern_int = 0;
					foreach my $pattern ( @{ $rule->{'patterns'} } ) {
						if (   ( ref($pattern) eq '' )
							&& ( $pattern =~ /^[A-Z][A-Z0-9_]*\z/ )
							&& ( !exists( $vars->{$pattern} ) ) )
						{
							push( @errors,
									  $where
									. '.patterns.'
									. $pattern_int
									. ' looks like a var reference ("'
									. $pattern
									. '") but no such var exists' );
						} ## end if ( ( ref($pattern) eq '' ) && ( $pattern...))
						$pattern_int++;
					} ## end foreach my $pattern ( @{ $rule->{'patterns'} } )
				} ## end if ( ref( $rule->{'patterns'} ) eq 'ARRAY')

				# compile the rule exactly as the engine does; a failure here is
				# what surfaces un-degrokked grok and illegal capture names
				my $compiled;
				# compiled with the file-level defaults the engine passes, so a
				# rule that declares no convert or decompose of its own is
				# tested holding the ones it actually runs with
				eval {
					$compiled = Log::Munger::LogProcessor->_compile_rule(
						'rule'              => $rule,
						'vars'              => $vars,
						'default_geoip'     => $rules->{'geoip'},
						'default_decompose' => $rules->{'decompose'},
						'default_convert'   => $rules->{'convert'},
					);
				};
				if ($@) {
					push( @errors, $where . ' failed to compile... ' . $@ );
					$rule_int++;
					next;
				}

				#
				# run the rule's embedded tests
				#
				if ( !defined( $rule->{'tests'} ) ) {
					push( @warnings, $where . ' lacks any tests' );
				} elsif ( ref( $rule->{'tests'} ) ne 'HASH' ) {
					push( @errors, $where . '.tests has a ref of "' . ref( $rule->{'tests'} ) . '" and not "HASH"' );
				} else {
					my $gated     = 0;
					my $converted = 0;
					my $enriched  = 0;
					_test_rule_positive( $where, $rule, $compiled, \@errors, \$gated, \$converted, \$enriched );
					_test_rule_negative( $where, $rule, $compiled, \@errors, \$gated );

					# a gate nothing ever names is a gate nothing has checked,
					# and a wrong one costs the whole daemon rather than one
					# message type
					if ( !$gated && @{ $compiled->{'gate'} } ) {
						push( @warnings, $where . ' is gated but no test names a program' );
					}

					# a convert nothing ever lists is a convert nothing has
					# checked. It is the quietest thing in a rule file to get
					# wrong: the field is captured, the value is right, and it
					# arrives as a string where a consumer expected a number
					my @unchecked = _unchecked_converts( $rule, $compiled );
					if (@unchecked) {
						push( @warnings,
								  $where
								. ' converts to a number but no test lists as numeric: '
								. join( ', ', @unchecked ) );
					}

					# a decompose entry's own tests say it works, not that the rule is
					# wired to it. Rename a capture and the entry's tests still pass
					# while the rule quietly stops splitting anything
					my @unwired = _unchecked_decomposes( $rule, $compiled );
					if (@unwired) {
						push( @warnings,
								  $where
								. ' decomposes into fields no test says it produces: '
								. join( ', ', @unwired ) );
					}
				} ## end else [ if ( !defined( $rule->{'tests'} ) ) ]

				# a rule may carry its own decompose entries
				if ( defined( $rule->{'decompose'} ) ) {
					_test_decompose( $rule->{'decompose'}, $vars, \@errors, \@warnings, $where . '.decompose' );
				}

				$rule_int++;
			} ## end foreach my $rule ( @{ $rules->{'rules'} } )
		} ## end else [ if ( ref( $rules->{'rules'} ) ne 'ARRAY' )]
	} ## end if ( defined( $rules->{'rules'} ) )

	##
	## a file-level decompose is shared by every rule, so test it once here
	##
	if ( defined( $rules->{'decompose'} ) ) {
		my $vars = ( ref( $rules->{'vars'} ) eq 'HASH' ) ? $rules->{'vars'} : {};
		_test_decompose( $rules->{'decompose'}, $vars, \@errors, \@warnings, '.decompose' );
	}

	##
	## validate a file-level convert map (bad types are a load-time error)
	##
	if ( defined( $rules->{'convert'} ) ) {
		eval { Log::Munger::LogProcessor->_compile_convert( $rules->{'convert'} ); };
		if ($@) {
			push( @errors, '.convert is invalid... ' . $@ );
		}
	}

	my $results = {
		'fatal'    => undef,
		'errors'   => \@errors,
		'warnings' => \@warnings,
	};

	return $results;
} ## end sub test

# Runs one var's vars_tests entry: validates the shapes involved, splices the
# var into its test_template, and hands the resulting regexp to
# _test_var_positive and _test_var_negative.
#
# Args:
#
#     - $var :: The name of the var under test, such as "SSH_FAILED". Both the
#         var itself and its vars_tests entry are read out of $rules.
#
#     - $rules :: The loaded rules hash ref, read for .vars.$var and
#         .vars_tests.$var.
#
#     - $tt :: The Template object used to process the test_template.
#
#     - $errors :: Array ref to push error strings onto. Appended to in place.
#
#     - $warnings :: Array ref to push warning strings onto. Appended to in
#         place.
#
# Returns nothing. Everything it finds goes onto $errors or $warnings.
#
#     _test_var( 'SSH_FAILED', $rules, $tt, \@errors, \@warnings );
sub _test_var {
	my ( $var, $rules, $tt, $errors, $warnings ) = @_;

	my $var_tests = $rules->{'vars_tests'}{$var};
	my $value     = $rules->{'vars'}{$var};

	if ( !defined($value) ) {
		push( @{$errors}, '.vars.' . $var . ' has tests for it but it is undefined' );
		return;
	}
	if ( ref($var_tests) ne 'HASH' ) {
		push( @{$errors}, '.vars_tests.' . $var . ' has a ref of "' . ref($var_tests) . '" and not "HASH"' );
		return;
	}
	if ( ref($value) ne '' ) {
		push( @{$errors}, '.vars.' . $var . ' has a ref of "' . ref($value) . '" and not ""' );
		return;
	}

	my $test_template = $var_tests->{'test_template'};
	if ( !defined($test_template) ) {
		push( @{$errors}, '.vars_tests.' . $var . '.test_template is undef' );
		return;
	}
	if ( ref($test_template) ne '' ) {
		push(
			@{$errors},
			'.vars_tests.' . $var . '.test_template has a ref of "' . ref($test_template) . '" and not ""'
		);
		return;
	}

	#
	# splice the var into its test_template. everything below needs the
	# resulting regexp, so a template that will not process ends the testing of
	# this var here.
	#
	my $test_regex;
	eval { $tt->process( \$test_template, { 'TEST_VAR' => $value }, \$test_regex ) || die( $tt->error() ); };
	if ($@) {
		push( @{$errors}, '.vars_tests.' . $var . '.test_template could not be templated...' . $@ );
		return;
	}

	_test_var_positive( $var, $var_tests->{'positive'}, $test_regex, $errors );
	_test_var_negative( $var, $var_tests->{'negative'}, $test_regex, $errors, $warnings );

	return;
} ## end sub _test_var

# Runs one var's positive vars_tests cases. Each case is { string, result },
# and the string has to match the templated test regexp with TEST capturing the
# expected result.
#
# Having no positive tests is an error rather than a warning. A var with only
# negative tests has never been shown to match anything, which is the same as
# not being tested at all.
#
# Args:
#
#     - $var :: The name of the var under test, used to prefix messages.
#
#     - $positive :: The positive list out of the var's vars_tests entry. An
#         array ref of { string, result } hash refs.
#
#     - $test_regex :: The regexp string the test_template produced.
#
#     - $errors :: Array ref to push error strings onto. Appended to in place.
#
# Returns nothing. Everything it finds goes onto $errors.
#
#     _test_var_positive( $var, $var_tests->{'positive'}, $test_regex, \@errors );
sub _test_var_positive {
	my ( $var, $positive, $test_regex, $errors ) = @_;

	my $pwhere = '.vars_tests.' . $var . '.positive';
	if ( !defined($positive) ) {
		push( @{$errors}, $pwhere . ' is undef' );
		return;
	} elsif ( ref($positive) ne 'ARRAY' ) {
		push( @{$errors}, $pwhere . ' has a ref of "' . ref($positive) . '" and not "ARRAY"' );
		return;
	} elsif ( !defined( $positive->[0] ) ) {
		push( @{$errors}, $pwhere . ' is empty and has no tests' );
		return;
	}

	my $test_int = 0;
	foreach my $test ( @{$positive} ) {
		# an undef entry ends the list, matching the while loop this replaced
		last if ( !defined($test) );

		my $twhere = $pwhere . '.' . $test_int;
		if ( ref($test) ne 'HASH' ) {
			push( @{$errors}, $twhere . ' has a ref of "' . ref($test) . '" and not "HASH"' );
		} elsif ( !defined( $test->{'string'} ) ) {
			push( @{$errors}, $twhere . '.string is undef' );
		} elsif ( ref( $test->{'string'} ) ne '' ) {
			push( @{$errors}, $twhere . '.string has a ref of "' . ref( $test->{'string'} ) . '" and not ""' );
		} elsif ( !defined( $test->{'result'} ) ) {
			push( @{$errors}, $twhere . '.result is undef' );
		} elsif ( ref( $test->{'result'} ) ne '' ) {
			push( @{$errors}, $twhere . '.result has a ref of "' . ref( $test->{'result'} ) . '" and not ""' );
		} else {
			my $detail
				= '... test_regex="'
				. $test_regex
				. '" string="'
				. $test->{'string'}
				. '" expected result="'
				. $test->{'result'} . '"';
			if ( $test->{'string'} =~ /$test_regex/ ) {
				my %found_items = %+;
				if ( !defined( $found_items{'TEST'} ) ) {
					push( @{$errors}, $twhere . ' matched but "TEST" was not captured' . $detail );
				} elsif ( $found_items{'TEST'} ne $test->{'result'} ) {
					push(
						@{$errors},
						$twhere
							. ' matched but "TEST" captured the wrong result, "'
							. $found_items{'TEST'} . '"'
							. $detail
					);
				}
			} else {
				push( @{$errors}, $twhere . ' did not match but was expected to' . $detail );
			}
		} ## end else [ if ( ref($test) ne 'HASH' ) ]

		$test_int++;
	} ## end foreach my $test ( @{$positive} )

	return;
} ## end sub _test_var_positive

# Runs one var's negative vars_tests cases. Each case is a plain string that
# has to match nothing, or at least not capture TEST: a negative that matches
# without capturing TEST is a warning rather than an error.
#
# Args:
#
#     - $var :: The name of the var under test, used to prefix messages.
#
#     - $negative :: The negative list out of the var's vars_tests entry. An
#         array ref of plain strings.
#
#     - $test_regex :: The regexp string the test_template produced.
#
#     - $errors :: Array ref to push error strings onto. Appended to in place.
#
#     - $warnings :: Array ref to push warning strings onto. Appended to in
#         place.
#
# Returns nothing. Everything it finds goes onto $errors or $warnings.
#
#     _test_var_negative( $var, $var_tests->{'negative'}, $test_regex, \@errors, \@warnings );
sub _test_var_negative {
	my ( $var, $negative, $test_regex, $errors, $warnings ) = @_;

	my $nwhere = '.vars_tests.' . $var . '.negative';
	if ( !defined($negative) ) {
		push( @{$errors}, $nwhere . ' is undef' );
		return;
	} elsif ( ref($negative) ne 'ARRAY' ) {
		push( @{$errors}, $nwhere . ' has a ref of "' . ref($negative) . '" and not "ARRAY"' );
		return;
	}

	my $test_int = 0;
	foreach my $test ( @{$negative} ) {
		# an undef entry ends the list, matching the while loop this replaced
		last if ( !defined($test) );

		my $twhere = $nwhere . '.' . $test_int;
		if ( ref($test) ne '' ) {
			push( @{$errors}, $twhere . ' has a ref of "' . ref($test) . '" and not ""' );
		} elsif ( $test =~ /$test_regex/ ) {
			my %found_items = %+;
			my $detail      = '... test_regex="' . $test_regex . '" string="' . $test . '"';
			if ( !defined( $found_items{'TEST'} ) ) {
				push( @{$warnings}, $twhere . ' matched but TEST was not found... possible error' . $detail );
			} else {
				push(
					@{$errors},
					$twhere . ' matched with TEST having a value of "' . $found_items{'TEST'} . '"' . $detail
				);
			}
		} ## end elsif ( $test =~ /$test_regex/ )

		$test_int++;
	} ## end foreach my $test ( @{$negative} )

	return;
} ## end sub _test_var_negative

# Lints one fully resolved regexp string for the four things that go wrong often
# enough to be worth checking for by name.
#
# Leftover grok "%{...}" means a pattern was copied in from logstash and never run
# through Log::Munger::Degrok. An illegal named capture means a grok capture name
# came across as-is when Perl will not take it; grok is happy with "src-ip" and
# Perl only accepts [A-Za-z_]\w*. An embedded newline usually means a YAML "|"
# block scalar leaked its terminator into the middle of a pattern, which leaves it
# unable to match a single line log while looking perfectly fine in the file. And
# a string that will not compile at all is caught here rather than at match time.
#
# The capture name scan skips (?<= and (?<! since those are lookbehind assertions
# rather than named captures.
#
# Args:
#
#     - $where :: Where this string lives in the rule file, written as a path,
#         such as ".vars.SSH_FAILED". Prefixed onto every message so the caller
#         knows what to go look at.
#
#     - $value :: The resolved regexp string to lint. This wants to be the value
#         after templating, not the vars_templated source, since the whole point
#         is to check what the engine will actually compile.
#
# Returns a list of error strings, each already prefixed with $where. An empty
# list means the string is clean. Nothing is ever pushed to warnings from here;
# everything it looks for would produce wrong output.
#
#     my @errors = _lint_regexp_string( '.vars.SSH_FAILED', $rules->{'vars'}{'SSH_FAILED'} );
#     # ( '.vars.SSH_FAILED has an illegal named-capture "src-ip" (must match [A-Za-z_]\w*)' )
sub _lint_regexp_string {
	my ( $where, $value ) = @_;

	my @errors;

	if ( $value =~ /%\{[^}]*\}/ ) {
		push( @errors, $where . ' contains un-degrokked grok "%{...}"' );
	}

	# validate every (?<name> ... capture name; Perl allows [A-Za-z_]\w* only.
	# the (?![=!]) guard skips lookbehind assertions (?<= and (?<!
	while ( $value =~ /\(\?<(?![=!])([^>]*)>/g ) {
		my $name = $1;
		if ( $name !~ /^[A-Za-z_]\w*\z/ ) {
			push( @errors, $where . ' has an illegal named-capture "' . $name . '" (must match [A-Za-z_]\\w*)' );
		}
	}

	if ( $value =~ /\n/ ) {
		push( @errors, $where . ' contains an embedded newline and cannot match a single-line log' );
	}

	my $compiled;
	eval {
		# this is a deliberate trial compile of possibly-bad input; keep any
		# regexp warnings out of the caller's stderr
		local $SIG{'__WARN__'} = sub { };
		$compiled = qr/$value/;
	};
	if ($@) {
		push( @errors, $where . ' does not compile as a regexp... ' . $@ );
	}

	return @errors;
} ## end sub _lint_regexp_string

# Matches a string against a compiled rule's patterns, the way the engine does:
# tried in order, first match wins.
#
# Args:
#
#     - $compiled :: The rule after Log::Munger::LogProcessor->_compile_rule,
#         read for its qr// patterns list.
#
#     - $string :: The string to match, such as a test case's string.
#
# Returns a hash ref of the winning pattern's named captures, which may be an
# empty hash ref for a pattern with no named captures, or undef when no pattern
# matched.
#
#     my $captures = _first_match( $compiled, $test->{'string'} );
sub _first_match {
	my ( $compiled, $string ) = @_;

	foreach my $pattern ( @{ $compiled->{'patterns'} } ) {
		if ( $string =~ $pattern ) {
			my %captures = %+;
			return \%captures;
		}
	}

	return undef;
} ## end sub _first_match

# Runs a rule's positive tests. Each case names a string that has to match one of
# the rule's patterns, along with the captures that match is expected to produce.
#
# The patterns are tried in order and the first to match wins, exactly as the
# engine does it, so a test also pins down which pattern is supposed to be
# handling a given line.
#
# A case may also name a program, and then the rule's gate has to accept it
# before the patterns are tried. This is what covers the gate itself. A gate is
# not a detail of the pattern below it -- it is the reason the rule is consulted
# at all, and getting it wrong means a daemon's whole log goes unmatched while
# every pattern test still passes. Naming a program on at least one case is what
# turns "these patterns work" into "this rule fires for this daemon".
#
# What is compared against a case's result is the raw named captures and nothing
# else, which is why a positive test's expected result lists a port as the string
# '54321' even though a convert: turns it into a number at runtime. A case that
# also carries numeric or enriched gets a second look via _test_numeric /
# _test_enriched, which run decompose and convert over a copy of the captures.
# Geoip never runs here; it is a runtime concern.
#
# Args:
#
#     - $where :: Where this rule lives, written as a path, such as ".rules.3".
#         The per-test messages extend it, giving ".rules.3.tests.positive.0".
#
#     - $rule :: The raw rule hash ref, straight out of the rule file. Only its
#         tests.positive is read here. Each entry is
#         { string, result => {}, program => optional }.
#
#     - $compiled :: The same rule after Log::Munger::LogProcessor->_compile_rule,
#         which is where the qr// patterns and the compiled gates come from.
#
#     - $errors :: Array ref to push error strings onto. Appended to in place.
#
#     - $gated :: Scalar ref, set to 1 if any case named a program. The caller
#         uses it to warn about a gated rule whose tests never exercise the gate.
#
#     - $converted :: Scalar ref, set to 1 if any case carried a numeric list.
#         The caller uses it the same way for a rule whose converts go untested.
#
#     - $enriched :: Scalar ref, set to 1 if any case carried an enriched map.
#         The caller uses it the same way for a rule whose decompose goes
#         untested.
#
# Returns nothing. Everything it finds goes onto $errors, which is left untouched
# if all the positive tests pass.
#
#     _test_rule_positive( '.rules.0', $rule, $compiled, \@errors, \$gated, \$converted, \$enriched );
sub _test_rule_positive {
	my ( $where, $rule, $compiled, $errors, $gated, $converted, $enriched ) = @_;

	my $positive = $rule->{'tests'}{'positive'};
	if ( !defined($positive) ) {
		push( @{$errors}, $where . '.tests.positive is undef' );
		return;
	} elsif ( ref($positive) ne 'ARRAY' ) {
		push( @{$errors}, $where . '.tests.positive has a ref of "' . ref($positive) . '" and not "ARRAY"' );
		return;
	}

	my $test_int = 0;
	foreach my $test ( @{$positive} ) {
		my $twhere = $where . '.tests.positive.' . $test_int;
		if ( ref($test) ne 'HASH' ) {
			push( @{$errors}, $twhere . ' has a ref of "' . ref($test) . '" and not "HASH"' );
			$test_int++;
			next;
		}
		if ( !defined( $test->{'string'} ) || ref( $test->{'string'} ) ne '' ) {
			push( @{$errors}, $twhere . '.string is undef or not a string' );
			$test_int++;
			next;
		}
		my $expected = defined( $test->{'result'} ) ? $test->{'result'} : {};
		if ( ref($expected) ne 'HASH' ) {
			push( @{$errors}, $twhere . '.result has a ref of "' . ref($expected) . '" and not "HASH"' );
			$test_int++;
			next;
		}

		# a named program has to get past the rule's gate before the patterns
		# are worth trying
		if ( defined( $test->{'program'} ) ) {
			if ( ref( $test->{'program'} ) ne '' ) {
				push( @{$errors}, $twhere . '.program has a ref of "' . ref( $test->{'program'} ) . '" and not ""' );
				$test_int++;
				next;
			}
			${$gated} = 1;
			my $refusal = _gate_refusal( $compiled, $test->{'program'} );
			if ( defined($refusal) ) {
				push( @{$errors}, $twhere . ' ' . $refusal );
				$test_int++;
				next;
			}
		} ## end if ( defined( $test->{'program'} ) )

		my $got = _first_match( $compiled, $test->{'string'} );

		if ( !defined($got) ) {
			push( @{$errors}, $twhere . ' did not match any pattern... string="' . $test->{'string'} . '"' );
		} else {
			my $diff = _capture_diff( $expected, $got );
			if ( defined($diff) ) {
				push(
					@{$errors},
					$twhere . ' captures differ from expected: ' . $diff . ' string="' . $test->{'string'} . '"'
				);
			}
			if ( defined( $test->{'numeric'} ) ) {
				${$converted} = 1;
				_test_numeric( $twhere, $test->{'numeric'}, $compiled, $got, $errors );
			}
			if ( defined( $test->{'enriched'} ) ) {
				${$enriched} = 1;
				_test_enriched( $twhere, $test->{'enriched'}, $compiled, $got, $errors );
			}
		} ## end else [ if ( !defined($got) ) ]

		$test_int++;
	} ## end foreach my $test ( @{$positive} )

	return;
} ## end sub _test_rule_positive

# Runs a rule's negative tests. Each case is a string that has to match none of
# the rule's patterns.
#
# This is what keeps a loose pattern honest. A pattern written as "a word, a
# space, then anything" will happily match most of a log file, and its positive
# tests will not notice. A good negative case is one that is genuinely outside
# what the pattern was written for, not merely unrelated in subject matter.
#
# A case may instead be written as { string, program }, and then it passes if
# either the gate refuses the program or no pattern matches. That is the shape
# of a gate written too wide: the line is one this rule handles perfectly well,
# and the whole point is that it arrived under a program this rule has no
# business claiming.
#
# Args:
#
#     - $where :: Where this rule lives, written as a path, such as ".rules.3".
#         The per-test messages extend it, giving ".rules.3.tests.negative.0".
#
#     - $rule :: The raw rule hash ref, straight out of the rule file. Only its
#         tests.negative is read here. Each entry is either a plain string or a
#         { string, program } hash ref.
#
#     - $compiled :: The same rule after Log::Munger::LogProcessor->_compile_rule,
#         which is where the qr// patterns and the compiled gates come from.
#
#     - $errors :: Array ref to push error strings onto. Appended to in place.
#
#     - $gated :: Scalar ref, set to 1 if any case named a program. Shared with
#         _test_rule_positive, since either kind of case exercises the gate.
#
# Returns nothing. Everything it finds goes onto $errors, which is left untouched
# if all the negative tests pass.
#
#     _test_rule_negative( '.rules.0', $rule, $compiled, \@errors, \$gated );
sub _test_rule_negative {
	my ( $where, $rule, $compiled, $errors, $gated ) = @_;

	my $negative = $rule->{'tests'}{'negative'};
	if ( !defined($negative) ) {
		push( @{$errors}, $where . '.tests.negative is undef' );
		return;
	} elsif ( ref($negative) ne 'ARRAY' ) {
		push( @{$errors}, $where . '.tests.negative has a ref of "' . ref($negative) . '" and not "ARRAY"' );
		return;
	}

	my $test_int = 0;
	foreach my $test ( @{$negative} ) {
		my $twhere = $where . '.tests.negative.' . $test_int;

		my $string  = $test;
		my $program = undef;
		if ( ref($test) eq 'HASH' ) {
			$string  = $test->{'string'};
			$program = $test->{'program'};
			if ( !defined($string) || ref($string) ne '' ) {
				push( @{$errors}, $twhere . '.string is undef or not a string' );
				$test_int++;
				next;
			}
			if ( !defined($program) || ref($program) ne '' ) {
				push( @{$errors}, $twhere . '.program is undef or not a string' );
				$test_int++;
				next;
			}
			${$gated} = 1;
		} elsif ( ref($test) ne '' ) {
			push( @{$errors}, $twhere . ' has a ref of "' . ref($test) . '" and not "" or "HASH"' );
			$test_int++;
			next;
		}

		# a refused program is the whole answer; the patterns are never reached
		if ( defined($program) && defined( _gate_refusal( $compiled, $program ) ) ) {
			$test_int++;
			next;
		}

		foreach my $pattern ( @{ $compiled->{'patterns'} } ) {
			if ( $string =~ $pattern ) {
				push(
					@{$errors},
					$twhere
						. ' matched a pattern but should not have'
						. ( defined($program) ? ' (gate accepted "' . $program . '")' : '' )
						. '... string="'
						. $string . '"'
				);
				last;
			} ## end if ( $string =~ $pattern )
		} ## end foreach my $pattern ( @{ $compiled->{'patterns'...}})
		$test_int++;
	} ## end foreach my $test ( @{$negative} )

	return;
} ## end sub _test_rule_negative

# Reports whether perl is holding a scalar as a number rather than as the string
# a capture produced.
#
# This is what a "numeric" test case is asking, and asking it any other way does
# not work. Scalar::Util::looks_like_number answers "could this be read as a
# number", which is true of the captured string before any conversion happens, so
# a check built on it passes whether the convert ran or not.
#
# A capture is POK and nothing else. Once _convert has put an int() or a numeric
# addition through it the scalar carries IOK or NOK as well, and that is the only
# difference between "44444" fresh out of a pattern and 44444 after a convert:
# the two compare equal both as strings and as numbers.
#
# The value is read through a reference and never used in numeric context here,
# since doing so would set the very flag being looked for.
#
# Args:
#
#     - $value :: The scalar to inspect, normally a field out of a captures hash
#         that decompose and convert have been run over. undef is allowed and
#         reported as not converted.
#
# Returns 1 when the scalar carries a numeric slot, otherwise 0.
#
#     _holds_a_number( 44444 )   # 1
#     _holds_a_number( '44444' ) # 0
sub _holds_a_number {
	my ($value) = @_;

	if ( !defined($value) ) {
		return 0;
	}

	my $sv = B::svref_2object( \$value );

	return ( $sv->FLAGS & ( B::SVf_IOK() | B::SVf_NOK() ) ) ? 1 : 0;
} ## end sub _holds_a_number

# Runs a copy of a case's captures through decompose and then convert, the way
# the engine does, and hands back what a consumer would receive.
#
# Copied rather than modified, because .result compares the raw capture set and
# that does not change. Everything a case says about the stage after -- what a
# blob was split into, what a string was coerced to -- is asked of this copy.
#
# geoip is not run. It needs a database, and it adds a key rather than changing
# one, so it is a runtime concern rather than a property of the rule file.
#
# Args:
#
#     - $compiled :: The rule after Log::Munger::LogProcessor->_compile_rule,
#         read for its decompose list and convert map.
#
#     - $captures :: Hash ref of the raw named captures the winning pattern
#         produced. Left untouched.
#
# Returns a hash ref of the fields as they would reach a consumer.
#
#     my $fields = _enrich( $compiled, \%got );
sub _enrich {
	my ( $compiled, $captures ) = @_;

	my %fields = %{$captures};
	if ( @{ $compiled->{'decompose'} } ) {
		Log::Munger::LogProcessor->_decompose( $compiled, \%fields );
	}
	if ( keys( %{ $compiled->{'convert'} } ) ) {
		Log::Munger::LogProcessor->_convert( $compiled, \%fields );
	}

	return \%fields;
} ## end sub _enrich

# Runs a positive case's enriched expectation: the field set a consumer receives
# once decompose and convert have run.
#
# This is what puts a decompose under test as the rule really uses it. An entry's
# own tests feed it a hand-written input in isolation, which says the entry works
# but not that it is wired to anything -- nothing there notices when a pattern's
# capture is renamed out from under it, or when the field one entry produces
# stops being the field the next one consumes.
#
# Compared exactly in both directions, as .result is, so a field that quietly
# stops being produced is caught and so is one that turns up unasked for.
#
# Args:
#
#     - $twhere :: Where this case lives, written as a path, such as
#         ".rules.3.tests.positive.0". Used to prefix any error.
#
#     - $expected :: The case's enriched map, as written in the rule file.
#
#     - $compiled :: The rule after Log::Munger::LogProcessor->_compile_rule.
#
#     - $captures :: Hash ref of the raw named captures. Copied, not modified.
#
#     - $errors :: Array ref to push error strings onto. Appended to in place.
#
# Returns nothing. Everything it finds goes onto $errors.
#
#     _test_enriched( '.rules.0.tests.positive.1', $expected, $compiled, \%got, \@errors );
sub _test_enriched {
	my ( $twhere, $expected, $compiled, $captures, $errors ) = @_;

	if ( ref($expected) ne 'HASH' ) {
		push( @{$errors}, $twhere . '.enriched has a ref of "' . ref($expected) . '" and not "HASH"' );
		return;
	}

	my $diff = _capture_diff( $expected, _enrich( $compiled, $captures ) );
	if ( defined($diff) ) {
		push( @{$errors}, $twhere . '.enriched differs from what decompose and convert produced: ' . $diff );
	}

	return;
} ## end sub _test_enriched

# Runs a positive test case's captures through decompose and convert, the way the
# engine does (via _enrich), and checks the fields the case listed as numeric.
#
# The captures are copied first. What .result compares is the raw capture set and
# that does not change -- which is why a positive test's expected result still
# lists a port as the string '54321'. This runs on a copy of the same captures so
# a case can say what that string is supposed to become.
#
# Decompose runs first, as it does at runtime, so a field a decompose produced can
# be listed too. That covers the case worth covering most: a kv blob split into
# fields, one of which a convert then coerces.
#
# Args:
#
#     - $twhere :: Where this case lives, written as a path, such as
#         ".rules.3.tests.positive.0". Used to prefix any error.
#
#     - $numeric :: The case's numeric list, as written in the rule file. An array
#         ref of capture names, such as [ 'dnsmasq_max_queries' ].
#
#     - $compiled :: The rule after Log::Munger::LogProcessor->_compile_rule,
#         read for its decompose list and convert map.
#
#     - $captures :: Hash ref of the raw named captures the winning pattern
#         produced. Copied rather than modified.
#
#     - $errors :: Array ref to push error strings onto. Appended to in place.
#
# Returns nothing. Everything it finds goes onto $errors.
#
#     _test_numeric( '.rules.0.tests.positive.1', ['ssh_src_port'], $compiled, \%got, \@errors );
sub _test_numeric {
	my ( $twhere, $numeric, $compiled, $captures, $errors ) = @_;

	if ( ref($numeric) ne 'ARRAY' ) {
		push( @{$errors}, $twhere . '.numeric has a ref of "' . ref($numeric) . '" and not "ARRAY"' );
		return;
	}

	my %converted = %{ _enrich( $compiled, $captures ) };

	foreach my $field ( @{$numeric} ) {
		if ( ref($field) ne '' ) {
			push( @{$errors}, $twhere . '.numeric entry has a ref of "' . ref($field) . '" and not ""' );
			next;
		}
		if ( !exists( $converted{$field} ) ) {
			push(
				@{$errors},
				$twhere
					. '.numeric names "'
					. $field
					. '", which nothing produced; neither the pattern nor a decompose sets it'
			);
			next;
		} ## end if ( !exists( $converted{$field} ) )
		if ( !_holds_a_number( $converted{$field} ) ) {
			push(
				@{$errors},
				$twhere
					. '.numeric names "'
					. $field
					. '", which came out as the string "'
					. ( defined( $converted{$field} ) ? $converted{$field} : '' )
					. '"; no convert turned it into a number'
			);
		} ## end if ( !_holds_a_number( $converted{$field} ...))
	} ## end foreach my $field ( @{$numeric} )

	return;
} ## end sub _test_numeric

# Lists the numeric conversions a rule's own tests do not check.
#
# Asking this per field rather than per rule matters: a rule that lists one
# converted field satisfies a per-rule check while its other converts go
# unwatched, which is exactly how http_access_logs kept a status code and a byte
# count as strings while its port conversion was tested.
#
# Only fields the rule's own positive tests really produce are considered, and
# only int and float entries -- lc, uc and mac turn a string into another string,
# and a rule that inherits the file level map often produces none of the fields in
# it. Warning about either would be noise, and noise in a lint teaches people to
# skip the output.
#
# Args:
#
#     - $rule :: The raw rule hash ref, read for its positive tests: their
#         strings, and the numeric lists they already carry.
#
#     - $compiled :: The rule after Log::Munger::LogProcessor->_compile_rule.
#
# Returns a sorted list of field names, empty when everything convertible is
# already listed.
#
#     my @unchecked = _unchecked_converts( $rule, $compiled );
sub _unchecked_converts {
	my ( $rule, $compiled ) = @_;

	my %numeric_type = map { $_ => 1 }
		grep { $compiled->{'convert'}{$_} eq 'int' || $compiled->{'convert'}{$_} eq 'float' }
		keys( %{ $compiled->{'convert'} } );
	if ( !keys(%numeric_type) ) {
		return ();
	}

	my %listed;
	my %produced;
	foreach my $test ( @{ $rule->{'tests'}{'positive'} || [] } ) {
		next if ( ref($test) ne 'HASH' || !defined( $test->{'string'} ) );
		$listed{$_} = 1 for @{ $test->{'numeric'} || [] };

		my $captures = _first_match( $compiled, $test->{'string'} );
		next if ( !defined($captures) || !keys( %{$captures} ) );

		if ( @{ $compiled->{'decompose'} } ) {
			Log::Munger::LogProcessor->_decompose( $compiled, $captures );
		}
		foreach my $field ( keys( %{$captures} ) ) {
			$produced{$field} = 1 if ( $numeric_type{$field} );
		}
	} ## end foreach my $test ( @{ $rule->{'tests'}{'positive'...}})

	return sort grep { !$listed{$_} } keys(%produced);
} ## end sub _unchecked_converts

# Lists the fields a rule's decompose produces that no enriched map names.
#
# Per field for the same reason as the converts above: one enriched case covers
# the entries that fired for that line, and a rule whose other tests reach a
# different entry would otherwise look covered.
#
# A file level decompose is shared by every rule in the file and most of them
# capture none of the fields it names, so a rule whose decompose never fires for
# any of its own tests is not asked about.
#
# Args:
#
#     - $rule :: The raw rule hash ref, read for its positive tests and the
#         enriched maps they already carry.
#
#     - $compiled :: The rule after Log::Munger::LogProcessor->_compile_rule.
#
# Returns a sorted list of field names, empty when nothing is missing.
#
#     my @unwired = _unchecked_decomposes( $rule, $compiled );
sub _unchecked_decomposes {
	my ( $rule, $compiled ) = @_;

	if ( !@{ $compiled->{'decompose'} } ) {
		return ();
	}

	my %named;
	my %produced;
	foreach my $test ( @{ $rule->{'tests'}{'positive'} || [] } ) {
		next if ( ref($test) ne 'HASH' || !defined( $test->{'string'} ) );
		$named{$_} = 1 for keys( %{ $test->{'enriched'} || {} } );

		my $captures = _first_match( $compiled, $test->{'string'} );
		next if ( !defined($captures) || !keys( %{$captures} ) );

		my %split = %{$captures};
		Log::Munger::LogProcessor->_decompose( $compiled, \%split );
		foreach my $field ( keys(%split) ) {
			$produced{$field} = 1 if ( !exists( $captures->{$field} ) );
		}
	} ## end foreach my $test ( @{ $rule->{'tests'}{'positive'...}})

	return sort grep { !$named{$_} } keys(%produced);
} ## end sub _unchecked_decomposes

# Runs a compiled rule's gates against a program name. Each gate is evaluated
# by Log::Munger::LogProcessor->_gate_passes, so this is the engine's own gate
# check rather than a parallel copy of it.
#
# The engine gates on a whole record, but every gate any rule file has ever
# needed keys on PROGRAM, so a test names a program rather than building a
# record. A gate gets a synthetic { PROGRAM => $program } to look at; one keyed
# on some other field finds nothing there and refuses, which is the right answer
# for a test that has not said what that field holds.
#
# Args:
#
#     - $compiled :: The rule after Log::Munger::LogProcessor->_compile_rule.
#         Only its gate list is read, each entry being
#         { field, literals => {}, regexps => [] }.
#
#     - $program :: The program name to gate, as a plain string, such as
#         "dnsmasq-dhcp" or "/usr/sbin/cron".
#
# Returns undef when every gate passes, otherwise a string naming the gate that
# refused and what it wanted, ready to be dropped into an error message.
#
#     my $why = _gate_refusal( $compiled, 'cron' );
#     # 'gate 0 on PROGRAM does not accept "cron"'
sub _gate_refusal {
	my ( $compiled, $program ) = @_;

	my $item = { 'PROGRAM' => $program };

	my $gate_int = 0;
	foreach my $gate ( @{ $compiled->{'gate'} } ) {
		if ( !Log::Munger::LogProcessor->_gate_passes( $gate, $item->{ $gate->{'field'} } ) ) {
			return 'gate ' . $gate_int . ' on ' . $gate->{'field'} . ' does not accept "' . $program . '"';
		}
		$gate_int++;
	}

	return undef;
} ## end sub _gate_refusal

# Compares two flat capture hashes and describes the first way they differ.
#
# Both directions are checked, so a capture that was expected and never appeared
# is caught, and so is one that appeared without being asked for. That second case
# matters more than it looks: an unexpected capture usually means a pattern picked
# up a group nobody meant to add, and without checking for it a test would pass
# while the rule quietly emitted a field consumers were not written for.
#
# Comparison is string comparison, which is what the rule files want. Everything
# coming out of a regexp capture is a string, and the expected results in YAML are
# written to match.
#
# Args:
#
#     - $expected :: Hash ref of the captures the test says there should be, as
#         written in the rule file. Values are compared as strings.
#
#     - $got :: Hash ref of the captures that actually came out, a copy of %+.
#
# Returns undef if the two agree, otherwise a string describing the first
# difference found, ready to be dropped into an error message. Only the first is
# reported, since a single wrong pattern usually throws off several keys at once
# and listing them all says no more than listing one.
#
#     my $diff = _capture_diff( { ssh_user => 'alice' }, { ssh_user => 'bob' } );
#     # 'key "ssh_user" expected "alice" but got "bob"'
sub _capture_diff {
	my ( $expected, $got ) = @_;

	foreach my $key ( sort keys( %{$expected} ) ) {
		if ( !exists( $got->{$key} ) ) {
			return 'expected key "' . $key . '" not captured';
		}
		if ( $expected->{$key} ne $got->{$key} ) {
			return 'key "' . $key . '" expected "' . $expected->{$key} . '" but got "' . $got->{$key} . '"';
		}
	}
	foreach my $key ( sort keys( %{$got} ) ) {
		if ( !exists( $expected->{$key} ) ) {
			return 'unexpected key "' . $key . '" captured as "' . $got->{$key} . '"';
		}
	}

	return undef;
} ## end sub _capture_diff

# Tests a decompose list, either a rule's own or the file level default.
#
# Every entry is compiled on its own first, which is what surfaces an unknown
# type, leftover grok in a pattern entry, or a pattern that will not compile.
#
# An entry that carries tests is then exercised one entry at a time. The captures
# hash is built as nothing but { field => input }, the single entry is applied to
# it, and what comes out has to equal the expected result. Testing entries in
# isolation like this means a list of several does not have to be reasoned about
# as a whole, and it keeps a change to one entry from breaking the tests of the
# others.
#
# The expected result has to account for the entry's remove: setting. With remove
# set the source field is gone by the time the comparison happens, so listing it
# would fail; without it the source field is still there and leaving it out would
# fail as an unexpected capture.
#
# Args:
#
#     - $list :: The decompose list, as written in the rule file. An array ref of
#         { field, type, ... } hash refs.
#
#     - $vars :: The resolved vars hash ref, which a "type: pattern" entry
#         resolves its pattern name against. An empty hash ref is fine for a list
#         that only uses kv or json entries.
#
#     - $errors :: Array ref to push error strings onto. Appended to in place.
#
#     - $warnings :: Array ref to push warning strings onto. Appended to in
#         place. An entry with no tests at all lands here rather than in errors.
#
#     - $where :: Where this list lives, written as a path, such as ".decompose"
#         for the file level one or ".rules.3.decompose" for a rule's own. The
#         per-entry and per-test messages extend it.
#
# Returns nothing. Everything it finds goes onto $errors or $warnings.
#
#     _test_decompose( $rules->{'decompose'}, $vars, \@errors, \@warnings, '.decompose' );
sub _test_decompose {
	my ( $list, $vars, $errors, $warnings, $where ) = @_;

	if ( ref($list) ne 'ARRAY' ) {
		push( @{$errors}, $where . ' has a ref of "' . ref($list) . '" and not "ARRAY"' );
		return;
	}

	my $int = 0;
	foreach my $entry ( @{$list} ) {
		my $ewhere = $where . '.' . $int;

		# compile just this entry (surfaces bad type / grok / regexp)
		my $compiled;
		eval { $compiled = Log::Munger::LogProcessor->_compile_decompose( [$entry], $vars ); };
		if ($@) {
			push( @{$errors}, $ewhere . ' failed to compile... ' . $@ );
			$int++;
			next;
		}

		if ( !defined( $entry->{'tests'} ) ) {
			push( @{$warnings}, $ewhere . ' lacks any tests' );
			$int++;
			next;
		} elsif ( ref( $entry->{'tests'} ) ne 'ARRAY' ) {
			push( @{$errors}, $ewhere . '.tests has a ref of "' . ref( $entry->{'tests'} ) . '" and not "ARRAY"' );
			$int++;
			next;
		}

		my $rule     = { 'decompose' => $compiled };
		my $test_int = 0;
		foreach my $test ( @{ $entry->{'tests'} } ) {
			my $twhere = $ewhere . '.tests.' . $test_int;
			if ( ref($test) ne 'HASH' ) {
				push( @{$errors}, $twhere . ' has a ref of "' . ref($test) . '" and not "HASH"' );
				$test_int++;
				next;
			}
			if ( !defined( $test->{'input'} ) || ref( $test->{'input'} ) ne '' ) {
				push( @{$errors}, $twhere . '.input is undef or not a string' );
				$test_int++;
				next;
			}
			my $expected = defined( $test->{'result'} ) ? $test->{'result'} : {};
			if ( ref($expected) ne 'HASH' ) {
				push( @{$errors}, $twhere . '.result has a ref of "' . ref($expected) . '" and not "HASH"' );
				$test_int++;
				next;
			}

			my %captures = ( $entry->{'field'} => $test->{'input'} );
			Log::Munger::LogProcessor->_decompose( $rule, \%captures );

			my $diff = _capture_diff( $expected, \%captures );
			if ( defined($diff) ) {
				push(
					@{$errors},
					$twhere . ' decompose output differs: ' . $diff . ' input="' . $test->{'input'} . '"'
				);
			}

			$test_int++;
		} ## end foreach my $test ( @{ $entry->{'tests'} } )

		$int++;
	} ## end foreach my $entry ( @{$list} )

	return;
} ## end sub _test_decompose

1;    # End of Log::Munger::RulesTest
