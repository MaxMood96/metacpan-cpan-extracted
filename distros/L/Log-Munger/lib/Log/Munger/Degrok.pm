package Log::Munger::Degrok;

use 5.006;
use strict;
use warnings;
use Scalar::Util                qw(looks_like_number);
use File::Slurp                 qw(read_file);
use Hash::Merge                 ();
use YAML::XS                    qw(Dump);
use Log::Munger::RuleFileParser ();

=head1 NAME

Log::Munger::Degrok - Rewrites grok templating into the form Log::Munger uses.

=head1 VERSION

Version 0.0.1

=cut

our $VERSION = '0.0.1';

=head1 SYNOPSIS

    use Log::Munger::Degrok;

    print Log::Munger::Degrok->string( 'string' => 'client=%{IP:client_ip}' ) . "\n";
    # client=(?<client_ip>[% IP %])

    print Log::Munger::Degrok->file( 'file' => '/path/to/patterns.grok' );

    print Log::Munger::Degrok->grok2rules( 'file' => '/path/to/patterns.grok', 'includes' => ['base'] );

Grok references a named pattern as C<%{TEMPLATE}> and captures one as
C<%{TEMPLATE:VAR}>. Log::Munger uses L<Template> for the first and Perl's own
named capture syntax for the second, so those become C<[% TEMPLATE %]> and
C<< (?<VAR>[% TEMPLATE %]) >>. This module does that rewrite.

Only the delimiters change. The primitive names in F<base.yaml> deliberately track
grok's, so a pattern that referenced C<%{IP}> before goes on referencing the same
thing afterwards, and most patterns work straight after conversion. What the
rewrite cannot fix is a capture name Perl will not accept, since grok is happy
with names like C<src-ip> and Perl is not. Those come across unchanged and are
caught later, either at load time or by L<Log::Munger::RulesTest>.

=head1 METHODS

=head2 string

Rewrites the grok templating in a string and returns the result.

Every C<%{...}> reference is rewritten, however many there are, and anything that
is not one is left exactly as it was.

    - string :: The string to convert. Required.
        Default :: undef

Returns the rewritten string. Dies only if C<string> is undef.

    my $results;
    my $some_string = 'client=%{IP:client_ip} user=%{USERNAME:user}';
    eval { $results = Log::Munger::Degrok->string( 'string' => $some_string ); };
    if ($@) {
        die( 'Failed to process the string "' . $some_string . '"... ' . $@ );
    }
    print $results . "\n";
    # client=(?<client_ip>[% IP %]) user=(?<user>[% USERNAME %])

=cut

sub string {
	my ( $blank, %opts ) = @_;

	if ( !defined( $opts{'string'} ) ) {
		die('$opts{string} is undef');
	}
	my $string = $opts{'string'};

	# one pass: %{NAME} becomes [% NAME %] and %{NAME:capture} becomes
	# (?<capture>[% NAME %]). s///g resumes after each replacement, so the
	# replacement text itself is never re-matched
	$string =~ s/\%\{([A-Za-z0-9_]+)(?:\:([A-Za-z0-9_]+))?\}/
		defined($2) ? "(?<$2>[% $1 %])" : "[% $1 %]"/ge;

	return $string;
} ## end sub string

=head2 file

L</string> applied to a whole file, a line at a time.

The file's structure is untouched. Only the C<%{...}> references change, so a grok
patterns file comes back as the same file with Log::Munger templating in it. To
turn one into an actual rule file, use L</grok2rules> instead.

    - file :: The file to convert. Required.
        Default :: undef

Returns the whole rewritten file as a single string, line endings and all. Dies if
C<file> is undef or the file cannot be read.

    my $results;
    my $file = '/tmp/patterns.grok';
    eval { $results = Log::Munger::Degrok->file( 'file' => $file ); };
    if ($@) {
        die( 'Failed to process "' . $file . '"... ' . $@ );
    }
    print $results;

=cut

sub file {
	my ( $blank, %opts ) = @_;

	if ( !defined( $opts{'file'} ) ) {
		die('$opts{file} is undef');
	}

	my @lines;
	eval { @lines = read_file( $opts{'file'} ); };
	if ($@) {
		die( 'Failed to read "' . $opts{'file'} . '"... ' . $@ );
	}

	my @processed_lines;
	foreach my $line (@lines) {
		$line = Log::Munger::Degrok->string( 'string' => $line );
		push( @processed_lines, $line );
	}

	return join( '', @processed_lines );
} ## end sub file

=head2 grok2rules

Turns a grok patterns file into the skeleton of a Log::Munger rule file.

A grok patterns file is a list of C<NAME regexp> lines. Each one becomes a var:
plain lines go under C<vars>, and lines that reference other patterns go under
C<vars_templated> once they have been through L</string>. Comments and blank lines
are dropped.

Naming what you already have as C<includes> is worth doing. Most grok patterns
files start with their own copies of C<IP>, C<WORD>, C<HOSTNAME> and the rest, and
without the includes those all come across and shadow the ones in F<base.yaml>.
With them, the duplicates are recognised and handled per C<overwrite> instead.

What comes back is a skeleton, not a finished rule file. There is no C<rules>
section, no gates, no tests and no enrichment, because none of that exists in a
grok patterns file to convert. Writing those is the part still left to do.

    - file :: The grok patterns file to convert. Required.
        Default :: undef

    - includes :: Rule files to treat as includes. Their vars are loaded so
        names already provided by one can be recognised, and they are written
        into the skeleton's own includes list. The taken value is an array ref.
        Default :: []

    - overwrite :: What to do about a name an include already defines.
        Accepted values are:
            - yes :: Take the grok file's version.
            - no_silent :: Keep the include's version, saying nothing.
            - no_warn :: Keep the include's version and warn about it.
            - no_die :: Die on the first one.
        Default :: no_warn

Returns the skeleton as a YAML string, ready to write to a file. Dies if C<file>
is undef or unreadable, if C<overwrite> is not one of the four values above, if an
include cannot be loaded, or if a line in the patterns file has a name but no
regexp after it.

    my $results;
    my $file = '/tmp/patterns.grok';
    eval { $results = Log::Munger::Degrok->grok2rules( 'file' => $file, 'includes' => ['base'] ); };
    if ($@) {
        die( 'Failed to process "' . $file . '"... ' . $@ );
    }
    print $results;

=cut

sub grok2rules {
	my ( $blank, %opts ) = @_;

	if ( !defined( $opts{'file'} ) ) {
		die('$opts{file} is undef');
	}

	my $overwrite_types = {
		'yes'       => 1,
		'no_die'    => 1,
		'no_warn'   => 1,
		'no_silent' => 1,
	};

	if ( !defined( $opts{'overwrite'} ) ) {
		$opts{'overwrite'} = 'no_warn';
	} elsif ( ref( $opts{'overwrite'} ) ne '' ) {
		die( '$opts{overwrite} is specified but has a ref of "' . ref( $opts{'overwrite'} ) . '" instead of ""' );
	} elsif ( !$overwrite_types->{ $opts{'overwrite'} } ) {
		die(      '$opts{overwrite} has a value of "'
				. $opts{'overwrite'}
				. '"... expected values: '
				. join( ', ', sort( keys( %{$overwrite_types} ) ) ) );
	}

	# the rules file being generated
	my $rules = {};

	my $includes = { 'vars' => {}, 'vars_templated' => {} };
	if ( defined( $opts{'includes'} )
		&& ( ref( $opts{'includes'} ) ne 'ARRAY' ) )
	{
		die( '$opts{includes} is specified but has a ref of "' . ref( $opts{'includes'} ) . '" instead of "ARRAY"' );
	}
	if ( defined( $opts{'includes'} ) && defined( $opts{'includes'}[0] ) ) {
		$rules->{'includes'} = [];

		# LEFT_PRECEDENT so an earlier include wins over a later one, the
		# same way RuleFileParser merges. Only existence is checked below,
		# so this is consistency rather than behavior
		my $merger = Hash::Merge->new('LEFT_PRECEDENT');
		my $parser = Log::Munger::RuleFileParser->new;

		# use a while loop instead of foreach for basically simplifying display of errors
		my $include_int = 0;
		while ( defined( $opts{'includes'}[$include_int] ) ) {
			my $include = $opts{'includes'}[$include_int];
			if ( ref($include) ne '' ) {
				die( '$opts{includes}[' . $include_int . '] has a ref of "' . ref($include) . '" and not ""' );
			}

			push( @{ $rules->{'includes'} }, $include );

			my $include_rules;
			eval { $include_rules = $parser->load( 'file' => $include ); };
			if ($@) {
				die( '$opts{includes}[' . $include_int . '], "' . $include . '", could not be loaded... ' . $@ );
			}

			$includes = $merger->merge( $includes, $include_rules );

			$include_int++;
		} ## end while ( defined( $opts{'includes'}[$include_int...]))
	} ## end if ( defined( $opts{'includes'} ) && defined...)

	my @lines;
	eval { @lines = read_file( $opts{'file'} ); };
	if ($@) {
		die( 'Failed to read "' . $opts{'file'} . '"... ' . $@ );
	}
	# chomp before anything else so the regexp half of a line never carries its
	# newline into the emitted YAML
	chomp(@lines);
	# drop comments and blank lines. A name with no regexp after it is kept so
	# it hits the die below rather than vanishing silently
	@lines = grep( !/^#/ && !/^\s*$/, @lines );

	foreach my $line (@lines) {
		my ( $var, $regexp ) = split( /[\ \t]+/, $line, 2 );
		# If we don't have $regexp, there is almost certainly something wrong with that line
		# It is not useful and likely should be removed.
		if ( !defined($regexp) ) {
			die(      'The line "'
					. $line
					. '" could not be split into a name and a regexp on whitespace, meaning there is likely something wrong with this line as there is no regexp for the variable'
			);
		}

		# a name an include already defines is handled per the overwrite policy:
		# yes takes the grok file's version, the no_* policies keep the
		# include's
		my $process_line = 1;
		if ( $opts{'overwrite'} ne 'yes' ) {
			my $already;
			if ( defined( $includes->{'vars'}{$var} ) ) {
				$already = '.vars.' . $var;
			} elsif ( defined( $includes->{'vars_templated'}{$var} ) ) {
				$already = '.vars_templated.' . $var;
			}
			if ( defined($already) ) {
				if ( $opts{'overwrite'} eq 'no_die' ) {
					die( '"' . $already . '" is already defined in one of the includes' );
				} elsif ( $opts{'overwrite'} eq 'no_warn' ) {
					warn( '"' . $already . '" is already defined in one of the includes... skipping...' );
				}
				$process_line = 0;
			}
		} ## end if ( $opts{'overwrite'} ne 'yes' )

		if ($process_line) {
			# a line referencing another pattern becomes a templated var
			if ( $regexp =~ /\%\{[A-Za-z0-9_]+(?:\:[A-Za-z0-9_]+)?\}/ ) {
				$rules->{'vars_templated'}{$var} = Log::Munger::Degrok->string( 'string' => $regexp );
			} else {
				$rules->{'vars'}{$var} = $regexp;
			}
		}

	} ## end foreach my $line (@lines)

	return Dump($rules);
} ## end sub grok2rules
