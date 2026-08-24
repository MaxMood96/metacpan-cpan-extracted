package Log::Munger::LogProcessor;

use 5.006;
use strict;
use warnings;
use Scalar::Util                qw(looks_like_number);
use JSON                        ();
use Log::Munger::RuleFileParser ();
use Log::Munger::RulesUsable    ();

# the "json" decompose type decodes with JSON::decode_json (utf8-on, and backed
# by JSON::XS when installed via the JSON front end) so it handles a raw-bytes
# MESSAGE without a separate decode step.

=head1 NAME

Log::Munger::LogProcessor - Compiles rule files and matches log records against them.

=head1 VERSION

Version 0.0.1

=cut

our $VERSION = '0.0.1';

=head1 SYNOPSIS

    use Log::Munger::LogProcessor;

    my $processor = Log::Munger::LogProcessor->new( 'rules' => [ 'base', 'postfix' ] );

    my $fields = $processor->process_item( 'item' => $decoded_log_hashref );
    if ( defined($fields) ) {
        # $fields is a hashref of the named captures from the first matching rule
    }

Each named rule file is loaded and its C<rules:> section compiled into an ordered,
merged dispatch list. A rule file with no C<rules:> section (a pure primitive
library such as C<base>) is accepted and skipped for dispatch.

A rule dispatches when B<all> of its gates pass B<and> one of its patterns matches
the target field. A gate passes when its field matches any of the gate's values,
patterns are first-match-wins, and rules are tried in load order (files in the
order given, rules in file order).

=head1 METHODS

=head2 new

Loads and compiles the named rule files.

    - rules :: Rule files to load. The taken value is an array ref.
        Default :: undef (required)

    - geoip :: Path to a MaxMind .mmdb database. When given, rules may flag
        captured fields (via a rule-level or file-level C<geoip:> list) whose
        values are looked up and stored under C<< $result->{geoip}{$field} >>.
        Requires IP::Geolocation::MMDB (a soft dependency, only loaded when this
        option is used).
        Default :: undef (geoip disabled)

=cut

sub new {
	my ( $blank, %opts ) = @_;

	if ( !defined( $opts{'rules'} ) ) {
		die('$opts{rules} is undef');
	} elsif ( ref( $opts{'rules'} ) ne 'ARRAY' ) {
		die( '$opts{rules} has a ref of "' . ref( $opts{'rules'} ) . '" and not "ARRAY"' );
	} elsif ( !defined( $opts{'rules'}[0] ) ) {
		die('$opts{rules}[0] is undef... no rules have been specified to use');
	}

	my $self = {
		'rules'        => [],       # compiled rules, ordered and merged across files
		'rule_files'   => [],       # names of the files loaded, in order
		'geoip_reader' => undef,    # IP::Geolocation::MMDB, if geoip is enabled
	};
	bless $self;

	# geoip is an opt-in feature with a soft dependency: only when a database
	# path is given do we require IP::Geolocation::MMDB and open the database
	if ( defined( $opts{'geoip'} ) ) {
		if ( ref( $opts{'geoip'} ) ne '' ) {
			die( '$opts{geoip} has a ref of "' . ref( $opts{'geoip'} ) . '" and not "" (a database path)' );
		}
		my $have_reader = eval { require IP::Geolocation::MMDB; 1; };
		if ( !$have_reader ) {
			die( 'geoip was requested but IP::Geolocation::MMDB is not installed... ' . $@ );
		}
		eval { $self->{'geoip_reader'} = IP::Geolocation::MMDB->new( 'file' => $opts{'geoip'} ); };
		if ($@) {
			die( 'Failed to open the geoip database "' . $opts{'geoip'} . '"... ' . $@ );
		}
	} ## end if ( defined( $opts{'geoip'} ) )

	my $parser = Log::Munger::RuleFileParser->new;

	my $rules_int = 0;
	while ( defined( $opts{'rules'}[$rules_int] ) ) {
		my $name = $opts{'rules'}[$rules_int];

		# RuleFileParser->load resolves the name (or path) itself via
		# WhichRuleFile, so hand it over untouched; resolving here too would
		# repeat the same work and turn error messages into resolved paths
		# rather than the name the caller actually passed
		my $rules;
		eval { $rules = $parser->load( 'file' => $name ); };
		if ($@) {
			die( 'Failed to load $opts{rules}[' . $rules_int . '], "' . $name . '"... ' . $@ );
		}

		# a file used purely as a primitive library (e.g. base) has no rules:
		# section; it is legal to list it, it just contributes no dispatch rules
		if ( !defined( $rules->{'rules'} ) ) {
			push( @{ $self->{'rule_files'} }, $name );
			$rules_int++;
			next;
		}

		eval { Log::Munger::RulesUsable->usable( 'rules' => $rules ); };
		if ($@) {
			die( '.rules in "' . $name . '" is not usable... ' . $@ );
		}

		my $vars = $rules->{'vars'};
		if ( ref($vars) ne 'HASH' ) {
			$vars = {};
		}

		# file-level geoip / decompose / convert defaults for every rule in the
		# file that does not carry its own
		my $file_geoip     = $rules->{'geoip'};
		my $file_decompose = $rules->{'decompose'};
		my $file_convert   = $rules->{'convert'};

		my $rule_int = 0;
		foreach my $rule ( @{ $rules->{'rules'} } ) {
			my $compiled;
			eval {
				$compiled = $self->_compile_rule(
					'rule'              => $rule,
					'vars'              => $vars,
					'default_geoip'     => $file_geoip,
					'default_decompose' => $file_decompose,
					'default_convert'   => $file_convert,
				);
			};
			if ($@) {
				die( 'Failed to compile .rules[' . $rule_int . '] in "' . $name . '"... ' . $@ );
			}
			push( @{ $self->{'rules'} }, $compiled );
			$rule_int++;
		} ## end foreach my $rule ( @{ $rules->{'rules'} } )

		push( @{ $self->{'rule_files'} }, $name );
		$rules_int++;
	} ## end while ( defined( $opts{'rules'}[$rules_int] ))

	return $self;
} ## end sub new

=head2 process_item

Runs an item through the compiled rules and returns the named captures of the
first matching rule.

The item may be given directly with C<item>, or assembled from the individual
syslog fields with C<message> (plus the optional C<program> / C<priority> /
C<facility>). This lets a caller that already has the fields split out (a syslog
reader, C<baphomet>, etc.) hand them over without building the record hash
itself.

    - item :: The decoded log record (a hash ref), or a bare string. A bare
        string is treated as a raw log line and matched as the C<MESSAGE> field,
        so callers feeding whole log lines (e.g. apache/nginx access logs) need
        not wrap them. If given, C<item> takes precedence and the C<message> /
        C<program> / C<priority> / C<facility> args below are ignored.
        Default :: undef

    - message :: The raw log message; assembled into C<< { MESSAGE => ... } >>.
        Default :: undef

    - program :: Adds a C<PROGRAM> field (the usual gate for daemon rule files).
        Default :: undef

    - priority :: Adds a C<PRIORITY> field.
        Default :: undef

    - facility :: Adds a C<FACILITY> field.
        Default :: undef

    my $fields = $processor->process_item( 'item' => $decoded_hashref );
    my $fields = $processor->process_item( 'message' => $line, 'program' => 'sshd' );

Returns a hash ref of the winning pattern's named captures on a match (which may
be an empty hash ref if the pattern had no named captures), or C<undef> if no rule
matched. This method never dies: an exception during matching is caught and comes
back as C<undef>. That bounds failures, not runtime -- a pattern prone to
catastrophic backtracking can still burn CPU on a hostile line, so keep patterns
anchored and tested.

=cut

sub process_item {
	my ( $self, %opts ) = @_;

	my $match = $self->_run( $self->_item_from_opts(%opts) );
	return $match->{'matched'} ? $match->{'fields'} : undef;
}

=head2 explain_item

Like L</process_item> but returns match metadata instead of just the fields,
for tooling that needs to know I<which> rule fired. Accepts the same arguments as
L</process_item> (C<item>, or C<message> plus optional C<program> / C<priority> /
C<facility>). Returns a hash ref:

    { matched => 0 }                                         # nothing matched
    { matched => 1, rule => <name>, pattern => <index>,
      field => <target field>, fields => { ...captures... } } # a rule fired

Never dies.

=cut

sub explain_item {
	my ( $self, %opts ) = @_;

	return $self->_run( $self->_item_from_opts(%opts) );
}

# Resolves the item to run from the caller's arguments. An explicit item (hash
# ref or bare string) is returned as-is for backward compatibility. Otherwise,
# when message is given, a record hash is assembled from it plus any of the
# optional program / priority / facility fields, mapped to the syslog-ng-style
# upper-case keys PROGRAM / PRIORITY / FACILITY that rule gates match on.
#
# Takes the same %opts as process_item and explain_item.
#
# Returns the item to hand to _run: the item as given, an assembled hash ref,
# or undef when neither item nor message was given (which _run treats as a
# non-match).
#
#     my $item = $self->_item_from_opts(%opts);
sub _item_from_opts {
	my ( $self, %opts ) = @_;

	# an explicit item wins, preserving the original hashref/bare-string behavior
	return $opts{'item'} if ( exists( $opts{'item'} ) );

	# nothing to assemble
	return undef if ( !defined( $opts{'message'} ) );

	my $item = { 'MESSAGE' => $opts{'message'} };
	$item->{'PROGRAM'}  = $opts{'program'}  if ( defined( $opts{'program'} ) );
	$item->{'PRIORITY'} = $opts{'priority'} if ( defined( $opts{'priority'} ) );
	$item->{'FACILITY'} = $opts{'facility'} if ( defined( $opts{'facility'} ) );

	return $item;
} ## end sub _item_from_opts

# The shared matcher for process_item and explain_item. Coerces a bare-string
# item to { MESSAGE => $string }, walks the rules, and on the first
# gate-passing pattern match runs decompose -> geoip -> convert.
#
# Args:
#
#     - $item :: The record to match. A hash ref, a bare string, or undef.
#
# Returns the match-metadata hash explain_item documents: { matched => 0 } on
# no match, else { matched => 1, rule, pattern, field, fields }. Never dies.
#
#     my $match = $self->_run($item);
sub _run {
	my ( $self, $item ) = @_;

	# a bare string is treated as a raw log line and matched as MESSAGE, so
	# callers feeding whole log lines (apache/nginx access logs, etc.) do not
	# have to wrap them in a hash themselves
	if ( defined($item) && ref($item) eq '' ) {
		$item = { 'MESSAGE' => $item };
	}
	if ( !defined($item) || ref($item) ne 'HASH' ) {
		return { 'matched' => 0 };
	}

	my $result = { 'matched' => 0 };
	eval {
	RULE: foreach my $rule ( @{ $self->{'rules'} } ) {

			# gates: every gate must pass (ANDed)
			foreach my $gate ( @{ $rule->{'gate'} } ) {
				if ( !$self->_gate_passes( $gate, $item->{ $gate->{'field'} } ) ) {
					next RULE;
				}
			}

			# target field to munge
			my $target = $item->{ $rule->{'field'} };
			if ( !defined($target) || ref($target) ne '' ) {
				next RULE;
			}

			# patterns: first match wins
			my $pattern_int = 0;
			foreach my $pattern ( @{ $rule->{'patterns'} } ) {
				if ( $target =~ $pattern ) {
					# copy %+ immediately, before any later match can clobber it
					my %captures = %+;
					# decompose first (it can produce fields geoip then looks up)
					if ( @{ $rule->{'decompose'} } ) {
						$self->_decompose( $rule, \%captures );
					}
					if ( $self->{'geoip_reader'} && @{ $rule->{'geoip'} } ) {
						$self->_geoip_enrich( $rule, \%captures );
					}
					# coerce numeric fields last, after geoip has seen the
					# string addresses
					if ( keys( %{ $rule->{'convert'} } ) ) {
						$self->_convert( $rule, \%captures );
					}
					$result = {
						'matched' => 1,
						'rule'    => $rule->{'name'},
						'pattern' => $pattern_int,
						'field'   => $rule->{'field'},
						'fields'  => \%captures,
					};
					last RULE;
				} ## end if ( $target =~ $pattern )
				$pattern_int++;
			} ## end foreach my $pattern ( @{ $rule->{'patterns'} } )
		} ## end RULE: foreach my $rule ( @{ $self->{'rules'} } )
	};
	if ($@) {
		return { 'matched' => 0 };
	}

	return $result;
} ## end sub _run

# Checks a single compiled gate against the value of its field.
#
# A gate passes when the value is a defined plain scalar and either sits in the
# gate's literals set or matches one of its //regexp// values. An absent,
# undef, or non-scalar value fails the gate. This is the one place gate
# semantics live; Log::Munger::RulesTest calls it too, so a test's gate check
# is the engine's rather than a parallel copy.
#
# Args:
#
#     - $gate :: A compiled gate entry, as _compile_rule builds them:
#         { field, literals => {}, regexps => [ qr//, ... ] }.
#
#     - $value :: The value of the gate's field out of the record being
#         matched. May be undef.
#
# Returns 1 when the gate passes, otherwise 0.
#
#     if ( !$self->_gate_passes( $gate, $item->{ $gate->{'field'} } ) ) {
#         next RULE;
#     }
sub _gate_passes {
	my ( $self, $gate, $value ) = @_;

	if ( !defined($value) || ref($value) ne '' ) {
		return 0;
	}
	if ( $gate->{'literals'}{$value} ) {
		return 1;
	}
	foreach my $re ( @{ $gate->{'regexps'} } ) {
		if ( $value =~ $re ) {
			return 1;
		}
	}

	return 0;
} ## end sub _gate_passes

# For each of the rule's flagged geoip fields that was captured, looks the
# value up in the geoip database and stores the record under
# $captures->{geoip}{$field}.
#
# Args:
#
#     - $rule :: The compiled rule, read for its geoip field list.
#
#     - $captures :: Hash ref of the captured fields. Modified in place.
#
# Returns nothing. A field that is undef, empty, not an address, or absent from
# the database is simply skipped; a lookup never dies.
#
#     $self->_geoip_enrich( $rule, \%captures );
sub _geoip_enrich {
	my ( $self, $rule, $captures ) = @_;

	my %geo;
	foreach my $field ( @{ $rule->{'geoip'} } ) {
		my $address = $captures->{$field};
		next if ( !defined($address) || $address eq '' );

		my $record;
		# record_for_address dies on a non-address; keep that local so a bad
		# value never costs the rest of the enrichment
		eval { $record = $self->{'geoip_reader'}->record_for_address($address); };
		next if ( $@ || !defined($record) );

		$geo{$field} = $record;
	} ## end foreach my $field ( @{ $rule->{'geoip'} } )

	# never clobber a capture that happens to be named geoip; no enrichment
	# step overwrites an existing capture
	if ( %geo && !exists( $captures->{'geoip'} ) ) {
		$captures->{'geoip'} = \%geo;
	}

	return;
} ## end sub _geoip_enrich

# Compiles a decompose: list (an array of {field, type, ...} entries) into
# runtime structures. Three types are supported:
#
#     - kv      :: split a "k=v k=v" blob into fields. Options: field_split
#                  (default " "), value_split (default "="), prefix (default ""),
#                  trim (chars stripped from each end of a value), remove. With
#                  quoted => true it is quote-aware instead: a value may be
#                  "double" or 'single' quoted (quotes stripped, the separator
#                  allowed inside them), and pairs are found by scanning for
#                  key=value shapes rather than by splitting on field_split.
#     - pattern :: re-match the field against a named var (or inline regexp),
#                  anchored, and merge its named captures. Options: pattern,
#                  remove.
#     - json    :: JSON-decode the field (for logs that embed a JSON document in
#                  a sub-field, e.g. MongoDB). By default the decoded structure
#                  is flattened into keys of prefix + path joined by separator
#                  (default "_"); MongoDB extended-JSON wrappers ({"$date":...},
#                  {"$oid":...}, {"$numberLong":...}) collapse to their scalar,
#                  booleans normalize to 1/0, and JSON null is skipped. Arrays
#                  are keyed by index. Options: prefix (default ""), separator
#                  (default "_"), remove, and nested => true (store the decoded
#                  structure whole under a single key -- the prefix minus a
#                  trailing separator, or with no prefix the source field itself,
#                  replacing the raw string -- instead of flattening). A field
#                  whose value is not valid JSON, or is JSON for a bare scalar,
#                  is left untouched.
#
# Every entry may set remove: true to drop the source field afterwards. An
# entry may also carry a tests: [ { input, result }, ... ] list, which
# Log::Munger::RulesTest runs in isolation; the tests key is ignored here.
#
# Args:
#
#     - $decompose :: The decompose list as written in the rule file. An array
#         ref of { field, type, ... } hash refs.
#
#     - $vars :: The compiled vars hash ref a "type: pattern" entry resolves
#         its pattern name against.
#
# Returns an array ref of compiled entries. Dies on a malformed entry, an
# unknown type, un-degrokked grok, or a pattern that will not compile.
#
#     my $compiled = $self->_compile_decompose( $rules->{'decompose'}, $vars );
sub _compile_decompose {
	my ( $self, $decompose, $vars ) = @_;

	if ( ref($decompose) ne 'ARRAY' ) {
		die( '.decompose has a ref of "' . ref($decompose) . '" and not "ARRAY"' );
	}

	my @compiled;
	my $int = 0;
	foreach my $d ( @{$decompose} ) {
		if ( ref($d) ne 'HASH' ) {
			die( '.decompose[' . $int . '] has a ref of "' . ref($d) . '" and not "HASH"' );
		}
		if ( !defined( $d->{'field'} ) || ref( $d->{'field'} ) ne '' ) {
			die( '.decompose[' . $int . '].field is undef or not a string' );
		}
		my $type = defined( $d->{'type'} ) ? $d->{'type'} : 'kv';
		my $c    = {
			'field'  => $d->{'field'},
			'type'   => $type,
			'remove' => ( $d->{'remove'} ? 1 : 0 ),
		};

		if ( $type eq 'kv' ) {
			$c->{'prefix'}      = defined( $d->{'prefix'} ) ? $d->{'prefix'} : '';
			$c->{'trim'}        = $d->{'trim'};                                      # may be undef
			$c->{'field_split'} = defined( $d->{'field_split'} ) ? $d->{'field_split'} : ' ';
			$c->{'value_split'} = defined( $d->{'value_split'} ) ? $d->{'value_split'} : '=';
			$c->{'quoted'}      = ( $d->{'quoted'} ? 1 : 0 );
			if ( $c->{'field_split'} eq '' ) { die( '.decompose[' . $int . '].field_split is empty' ); }
			if ( $c->{'value_split'} eq '' ) { die( '.decompose[' . $int . '].value_split is empty' ); }
		} elsif ( $type eq 'pattern' ) {
			my $pname = $d->{'pattern'};
			if ( !defined($pname) || ref($pname) ne '' ) {
				die( '.decompose[' . $int . '].pattern is undef or not a string' );
			}
			my $rx_string = exists( $vars->{$pname} ) ? $vars->{$pname} : $pname;
			if ( $rx_string =~ /%\{[^}]*\}/ ) {
				die( '.decompose[' . $int . '].pattern ("' . $pname . '") contains un-degrokked grok "%{...}"' );
			}
			my $rx;
			eval { $rx = qr/\A(?:$rx_string)\z/; };
			if ($@) {
				die( '.decompose[' . $int . '].pattern ("' . $pname . '") does not compile... ' . $@ );
			}
			$c->{'regexp'} = $rx;
		} elsif ( $type eq 'json' ) {
			# JSON-decode the field and either flatten the structure into
			# prefixed keys (default) or store the decoded structure whole
			# (nested => true).
			$c->{'prefix'}    = defined( $d->{'prefix'} )    ? $d->{'prefix'}    : '';
			$c->{'separator'} = defined( $d->{'separator'} ) ? $d->{'separator'} : '_';
			$c->{'nested'}    = ( $d->{'nested'} ? 1 : 0 );
			if ( ref( $c->{'prefix'} ) ne '' ) {
				die( '.decompose[' . $int . '].prefix is not a string' );
			}
			if ( ref( $c->{'separator'} ) ne '' || $c->{'separator'} eq '' ) {
				die( '.decompose[' . $int . '].separator is undef, empty, or not a string' );
			}
		} else {
			die( '.decompose[' . $int . '].type "' . $type . '" is unknown (expected "kv", "pattern", or "json")' );
		}

		push( @compiled, $c );
		$int++;
	} ## end foreach my $d ( @{$decompose} )

	return \@compiled;
} ## end sub _compile_decompose

# Applies a rule's compiled decompose entries to the captures hash, in order,
# so a later entry can break down a field produced by an earlier one.
#
# Args:
#
#     - $rule :: The compiled rule, read for its decompose list.
#
#     - $captures :: Hash ref of the captured fields. Modified in place. New
#         fields never clobber an existing capture; the one overwrite is a
#         nested json decompose with no prefix, which replaces its own source
#         field with the decoded structure.
#
# Returns nothing. Never dies.
#
#     $self->_decompose( $rule, \%captures );
sub _decompose {
	my ( $self, $rule, $captures ) = @_;

	foreach my $d ( @{ $rule->{'decompose'} } ) {
		my $value = $captures->{ $d->{'field'} };
		next if ( !defined($value) || ref($value) ne '' );

		if ( $d->{'type'} eq 'kv' ) {
			if ( $d->{'quoted'} ) {
				# quote-aware: a value may be "double" or 'single' quoted (quotes
				# stripped, the field separator allowed inside), else a bareword.
				# pairs are found by scanning for key=value shapes (value_split
				# joining key and value) rather than by splitting on field_split.
				my $vs = quotemeta( $d->{'value_split'} );
				while ( $value =~ /([\w.\-]+)$vs(?:"([^"]*)"|'([^']*)'|(\S*))/g ) {
					my $key = $1;
					my $val = defined($2) ? $2 : ( defined($3) ? $3 : $4 );
					$self->_store_kv_pair( $d, $captures, $key, $val );
				}
			} else {
				my $fs = quotemeta( $d->{'field_split'} );
				foreach my $token ( split( /$fs/, $value, -1 ) ) {
					next if ( $token eq '' );
					my $idx = index( $token, $d->{'value_split'} );
					next if ( $idx < 1 );    # need at least a one-char key before the split
					my $key = substr( $token, 0, $idx );
					my $val = substr( $token, $idx + length( $d->{'value_split'} ) );
					$self->_store_kv_pair( $d, $captures, $key, $val );
				}
			} ## end else [ if ( $d->{'quoted'} ) ]
		} elsif ( $d->{'type'} eq 'pattern' ) {
			if ( $value =~ $d->{'regexp'} ) {
				my %sub = %+;
				foreach my $key ( keys(%sub) ) {
					next if ( exists( $captures->{$key} ) );
					$captures->{$key} = $sub{$key};
				}
			}
		} elsif ( $d->{'type'} eq 'json' ) {
			my $decoded;
			eval { $decoded = JSON::decode_json($value); };
			# a value that is not valid JSON (or decodes to a bare scalar) is left
			# untouched -- skip this entry entirely so the raw field survives
			next if ( $@ || !defined($decoded) || ref($decoded) eq '' );
			if ( $d->{'nested'} ) {
				my $key = $d->{'prefix'};
				if ( $key ne '' ) {
					$key =~ s/\Q$d->{'separator'}\E\z//;    # trim a trailing separator
				} else {
					$key = $d->{'field'};
				}
				if ( $key eq $d->{'field'} ) {
					# landing on the source field itself replaces the raw JSON
					# string; remove: would delete what was just stored, so skip it
					$captures->{$key} = $decoded;
					next;
				}
				$captures->{$key} = $decoded if ( !exists( $captures->{$key} ) );
			} else {
				$self->_json_flatten( $decoded, '', $d->{'separator'}, $d->{'prefix'}, $captures );
			}
		} ## end elsif ( $d->{'type'} eq 'json' )

		if ( $d->{'remove'} ) {
			delete $captures->{ $d->{'field'} };
		}
	} ## end foreach my $d ( @{ $rule->{'decompose'} } )

	return;
} ## end sub _decompose

# Stores one key/value pair a kv decompose produced: trims the entry's trim
# characters off each end of the value, prepends the entry's prefix to the key,
# and stores the pair -- unless the key already exists, since no decompose ever
# clobbers a real capture.
#
# Args:
#
#     - $d :: The compiled kv decompose entry, read for its trim and prefix.
#
#     - $captures :: Hash ref of the captured fields. Modified in place.
#
#     - $key :: The key as parsed out of the blob, before the prefix.
#
#     - $value :: The value as parsed out of the blob, before the trim.
#
# Returns nothing.
#
#     $self->_store_kv_pair( $d, $captures, $key, $val );
sub _store_kv_pair {
	my ( $self, $d, $captures, $key, $value ) = @_;

	if ( defined( $d->{'trim'} ) && length( $d->{'trim'} ) ) {
		my $tc = $d->{'trim'};
		$value =~ s/\A[\Q$tc\E]+//;
		$value =~ s/[\Q$tc\E]+\z//;
	}

	$key = $d->{'prefix'} . $key;
	if ( !exists( $captures->{$key} ) ) {    # do not clobber a real capture
		$captures->{$key} = $value;
	}

	return;
} ## end sub _store_kv_pair

# Recursively flattens a decoded-JSON structure into the captures hash. Each
# leaf becomes prefix + path, where path is the sequence of object keys and
# array indices joined by the separator. MongoDB extended-JSON wrappers (a hash
# with a single $-prefixed key such as $date / $oid / $numberLong) collapse
# transparently to their inner value; booleans normalize to 1/0; JSON null is
# skipped.
#
# Args:
#
#     - $data :: The decoded structure (or, on recursion, a piece of it).
#
#     - $path :: The path down to $data so far, "" at the top.
#
#     - $sep :: The separator joining path segments.
#
#     - $prefix :: Prepended to every produced key.
#
#     - $captures :: Hash ref the produced fields land in. Modified in place;
#         an already-present capture is never clobbered.
#
# Returns nothing. Never dies.
#
#     $self->_json_flatten( $decoded, '', '_', 'mongo_', \%captures );
sub _json_flatten {
	my ( $self, $data, $path, $sep, $prefix, $captures ) = @_;

	if ( ref($data) eq 'HASH' ) {
		# collapse a MongoDB extended-JSON wrapper: { "$date" => ... } etc.
		my @keys = keys( %{$data} );
		if ( scalar(@keys) == 1 && $keys[0] =~ /\A\$/ ) {
			return $self->_json_flatten( $data->{ $keys[0] }, $path, $sep, $prefix, $captures );
		}
		foreach my $key ( keys( %{$data} ) ) {
			my $child = ( $path eq '' ) ? $key : $path . $sep . $key;
			$self->_json_flatten( $data->{$key}, $child, $sep, $prefix, $captures );
		}
		return;
	} ## end if ( ref($data) eq 'HASH' )
	if ( ref($data) eq 'ARRAY' ) {
		my $index = 0;
		foreach my $element ( @{$data} ) {
			my $child = ( $path eq '' ) ? $index : $path . $sep . $index;
			$self->_json_flatten( $element, $child, $sep, $prefix, $captures );
			$index++;
		}
		return;
	}

	# leaf
	return if ( !defined($data) );    # skip JSON null
	if ( JSON::is_bool($data) ) {     # backend-agnostic (JSON::XS or JSON::PP boolean)
		$data = $data ? 1 : 0;
	} elsif ( ref($data) ) {
		$data = "$data";              # any other blessed leaf: stringify defensively
	}
	return if ( $path eq '' );        # a top-level bare scalar has no key to store under

	my $key = $prefix . $path;
	return if ( exists( $captures->{$key} ) );    # do not clobber an existing capture
	$captures->{$key} = $data;

	return;
} ## end sub _json_flatten

# Validates a convert: map (field => type) and returns a normalized copy.
#
# lc/uc exist so a rule file can normalize a captured token whose case varies
# between the log sources that produce it; mac normalizes the several spellings
# a MAC address arrives in (see _normalize_mac). The full rationale lives in
# docs/rule-files.md.
#
# Args:
#
#     - $convert :: The convert map as written in the rule file. A hash ref of
#         field => type, where type is one of int, float, lc, uc, or mac.
#         Aliases: integer for int; num/number for float; lower/lowercase and
#         upper/uppercase for the case folds; macaddr/mac_address for mac.
#
# Returns a hash ref of field => canonical type. Dies on an unknown type.
#
#     my $normalized = $self->_compile_convert( $rules->{'convert'} );
sub _compile_convert {
	my ( $self, $convert ) = @_;

	if ( ref($convert) ne 'HASH' ) {
		die( '.convert has a ref of "' . ref($convert) . '" and not "HASH"' );
	}

	my %normalized;
	foreach my $field ( keys( %{$convert} ) ) {
		my $type = $convert->{$field};
		if ( !defined($type) || ref($type) ne '' ) {
			die( '.convert.' . $field . ' type is undef or not a string' );
		}
		if ( $type =~ /\A(?:int|integer)\z/i ) {
			$normalized{$field} = 'int';
		} elsif ( $type =~ /\A(?:float|num|number)\z/i ) {
			$normalized{$field} = 'float';
		} elsif ( $type =~ /\A(?:lc|lower|lowercase)\z/i ) {
			$normalized{$field} = 'lc';
		} elsif ( $type =~ /\A(?:uc|upper|uppercase)\z/i ) {
			$normalized{$field} = 'uc';
		} elsif ( $type =~ /\A(?:mac|macaddr|mac_address)\z/i ) {
			$normalized{$field} = 'mac';
		} else {
			die( '.convert.' . $field . ' type "' . $type . '" is unknown (expected int, float, lc, uc, or mac)' );
		}
	} ## end foreach my $field ( keys( %{$convert} ) )

	return \%normalized;
} ## end sub _compile_convert

# Coerces the rule's convert fields in the captures hash: int/float to numbers
# so they serialize as JSON numbers rather than strings, lc/uc to a case-folded
# string, mac to lowercase colon-separated hex.
#
# Args:
#
#     - $rule :: The compiled rule, read for its convert map.
#
#     - $captures :: Hash ref of the captured fields. Modified in place. A
#         field that is not present is left untouched, as is a numeric
#         conversion of something that does not look like a number and a mac
#         conversion of something that is not twelve hex digits.
#
# Returns nothing. Never dies.
#
#     $self->_convert( $rule, \%captures );
sub _convert {
	my ( $self, $rule, $captures ) = @_;

	foreach my $field ( keys( %{ $rule->{'convert'} } ) ) {
		next if ( !exists( $captures->{$field} ) );
		my $value = $captures->{$field};
		next if ( !defined($value) || ref($value) ne '' );

		my $type = $rule->{'convert'}{$field};

		# the case folds apply to any string, so they sit ahead of the
		# looks-like-a-number guard the numeric conversions need
		if ( $type eq 'lc' ) {
			$captures->{$field} = lc($value);
			next;
		} elsif ( $type eq 'uc' ) {
			$captures->{$field} = uc($value);
			next;
		} elsif ( $type eq 'mac' ) {
			$captures->{$field} = $self->_normalize_mac($value);
			next;
		}

		next if ( !looks_like_number($value) );

		if ( $type eq 'int' ) {
			$captures->{$field} = int( $value + 0 );
		} else {
			$captures->{$field} = $value + 0;
		}
	} ## end foreach my $field ( keys( %{ $rule->{'convert'}...}))

	return;
} ## end sub _convert

# Rewrites a MAC address into the one spelling everything else in the
# distribution uses: twelve lowercase hex digits in six colon-separated pairs.
#
# Args:
#
#     - $value :: The captured string to rewrite. Any of the spellings a log
#         line might carry are understood -- colon-separated
#         ("C4:D8:D5:3B:8C:4B"), hyphen-separated as Windows writes it
#         ("C4-D8-D5-3B-8C-4B"), dotted quads as Cisco writes them
#         ("c4d8.d53b.8c4b"), space-separated bytes as the kernel's link layer
#         header dump writes them ("c4 d8 d5 3b 8c 4b"), and bare
#         ("c4d8d53b8c4b").
#
# Returns the normalized address as a string. If the value does not reduce to
# exactly twelve hex digits once the separators are removed it is returned
# unchanged, so a field that turns out not to hold a MAC after all is passed
# through rather than mangled -- this runs against whatever the pattern
# captured, and a pattern can be looser than its author intended.
#
#     # all five of these return 'c4:d8:d5:3b:8c:4b'
#     $processor->_normalize_mac('C4:D8:D5:3B:8C:4B');
#     $processor->_normalize_mac('C4-D8-D5-3B-8C-4B');
#     $processor->_normalize_mac('c4d8.d53b.8c4b');
#     $processor->_normalize_mac('c4 d8 d5 3b 8c 4b');
#     $processor->_normalize_mac('c4d8d53b8c4b');
#
#     # not twelve hex digits, so returned as-is
#     $processor->_normalize_mac('unknown');
sub _normalize_mac {
	my ( $self, $value ) = @_;

	my $digits = $value;
	$digits =~ s/[:.\-\s]//g;

	return $value if ( $digits !~ /\A[0-9A-Fa-f]{12}\z/ );

	return join( ':', lc($digits) =~ /([0-9a-f]{2})/g );
} ## end sub _normalize_mac

# Compiles a single rules: entry into the runtime structure:
#
#     {
#         name      => ...,          # optional, diagnostics only
#         field     => 'MESSAGE',    # target field, defaults to MESSAGE
#         gate      => [ { field => ..., literals => {...}, regexps => [ qr//, ... ] }, ... ],
#         patterns  => [ qr//, ... ],
#         geoip     => [ 'field_name', ... ],
#         decompose => [ ... ],      # see _compile_decompose
#         convert   => { field_name => 'int'|'float'|'lc'|'uc'|'mac', ... },
#     }
#
# A rule may set anchored: true, in which case each pattern is wrapped as
# \A(?:...)\z so it must match the whole target field (the equivalent of a
# logstash "^...$" grok) rather than any substring.
#
# geoip:, decompose:, and convert: may each be given per-rule or once at the
# top of the file as a default for every rule. A rule-level one replaces the
# file-level default rather than merging with it. They run in the order
# decompose -> geoip -> convert, so geoip can look up a field a decompose step
# produced, and convert only coerces once geoip has seen the string addresses.
#
# Args:
#
#     - rule :: The raw rule hash ref.
#
#     - vars :: The compiled vars hash ref (pattern names resolve against this).
#
#     - default_geoip :: The file-level geoip list, used when the rule has none.
#
#     - default_decompose :: The file-level decompose list, used when the rule
#         has none.
#
#     - default_convert :: The file-level convert map, used when the rule has
#         none.
#
# Returns the compiled rule hash ref. Dies on a malformed rule, an un-degrokked
# %{...} remnant, or a pattern that will not compile (which is where an illegal
# named capture such as a "-" in the name is caught, at load time rather than
# at match time).
#
#     my $compiled = $self->_compile_rule( 'rule' => $rule, 'vars' => $vars );
sub _compile_rule {
	my ( $self, %opts ) = @_;

	my $rule = $opts{'rule'};
	my $vars = $opts{'vars'};
	if ( ref($rule) ne 'HASH' ) {
		die( 'rule has a ref of "' . ref($rule) . '" and not "HASH"' );
	}
	if ( ref($vars) ne 'HASH' ) {
		$vars = {};
	}

	my $compiled = {
		'name'      => $rule->{'name'},
		'field'     => ( defined( $rule->{'field'} ) ? $rule->{'field'} : 'MESSAGE' ),
		'gate'      => [],
		'patterns'  => [],
		'geoip'     => [],
		'decompose' => [],
		'convert'   => {},
	};
	if ( ref( $compiled->{'field'} ) ne '' ) {
		die( '.field has a ref of "' . ref( $compiled->{'field'} ) . '" and not ""' );
	}

	# numeric coercion of captured fields (rule-level, else the file default)
	my $convert = defined( $rule->{'convert'} ) ? $rule->{'convert'} : $opts{'default_convert'};
	if ( defined($convert) ) {
		$compiled->{'convert'} = $self->_compile_convert($convert);
	}

	# captured fields to enrich with geoip (rule-level, else the file default)
	my $geoip = defined( $rule->{'geoip'} ) ? $rule->{'geoip'} : $opts{'default_geoip'};
	if ( defined($geoip) ) {
		if ( ref($geoip) ne 'ARRAY' ) {
			die( '.geoip has a ref of "' . ref($geoip) . '" and not "ARRAY"' );
		}
		foreach my $field ( @{$geoip} ) {
			if ( ref($field) ne '' ) {
				die( '.geoip entry has a ref of "' . ref($field) . '" and not ""' );
			}
			push( @{ $compiled->{'geoip'} }, $field );
		}
	} ## end if ( defined($geoip) )

	# captured fields to break down further (rule-level, else the file default)
	my $decompose = defined( $rule->{'decompose'} ) ? $rule->{'decompose'} : $opts{'default_decompose'};
	if ( defined($decompose) ) {
		$compiled->{'decompose'} = $self->_compile_decompose( $decompose, $vars );
	}

	# when anchored, each pattern must match the whole target field (like a
	# logstash "^...$" grok), not just a substring
	my $anchored = ( defined( $rule->{'anchored'} ) && $rule->{'anchored'} ) ? 1 : 0;

	# gates
	if ( defined( $rule->{'gate'} ) ) {
		if ( ref( $rule->{'gate'} ) ne 'ARRAY' ) {
			die( '.gate has a ref of "' . ref( $rule->{'gate'} ) . '" and not "ARRAY"' );
		}
		my $gate_int = 0;
		foreach my $gate ( @{ $rule->{'gate'} } ) {
			if ( ref($gate) ne 'HASH' ) {
				die( '.gate[' . $gate_int . '] has a ref of "' . ref($gate) . '" and not "HASH"' );
			}
			if ( !defined( $gate->{'field'} ) || ref( $gate->{'field'} ) ne '' ) {
				die( '.gate[' . $gate_int . '].field is undef or not a string' );
			}
			if ( !defined( $gate->{'values'} ) || ref( $gate->{'values'} ) ne 'ARRAY' ) {
				die( '.gate[' . $gate_int . '].values is undef or not an "ARRAY"' );
			}

			my $compiled_gate = {
				'field'    => $gate->{'field'},
				'literals' => {},
				'regexps'  => [],
			};
			my $value_int = 0;
			foreach my $value ( @{ $gate->{'values'} } ) {
				if ( ref($value) ne '' ) {
					die(      '.gate['
							. $gate_int
							. '].values['
							. $value_int
							. '] has a ref of "'
							. ref($value)
							. '" and not ""' );
				}
				# //regexp// is the gate-value regexp marker; the outer slashes
				# are stripped strictly so an interior // (e.g. http://) survives
				if ( $value =~ /^\/\/(.*)\/\/\z/s ) {
					my $re = $1;
					my $compiled_re;
					eval { $compiled_re = qr/$re/; };
					if ($@) {
						die(      '.gate['
								. $gate_int
								. '].values['
								. $value_int
								. '] //regexp// "'
								. $value
								. '" does not compile... '
								. $@ );
					} ## end if ($@)
					push( @{ $compiled_gate->{'regexps'} }, $compiled_re );
				} else {
					$compiled_gate->{'literals'}{$value} = 1;
				}
				$value_int++;
			} ## end foreach my $value ( @{ $gate->{'values'} } )

			push( @{ $compiled->{'gate'} }, $compiled_gate );
			$gate_int++;
		} ## end foreach my $gate ( @{ $rule->{'gate'} } )
	} ## end if ( defined( $rule->{'gate'} ) )

	# patterns
	if ( !defined( $rule->{'patterns'} ) ) {
		die('.patterns is undef; a rule needs at least one pattern');
	} elsif ( ref( $rule->{'patterns'} ) ne 'ARRAY' ) {
		die( '.patterns has a ref of "' . ref( $rule->{'patterns'} ) . '" and not "ARRAY"' );
	} elsif ( !defined( $rule->{'patterns'}[0] ) ) {
		die('.patterns[0] is undef; a rule needs at least one pattern');
	}
	my $pattern_int = 0;
	foreach my $pattern ( @{ $rule->{'patterns'} } ) {
		if ( ref($pattern) ne '' ) {
			die( '.patterns[' . $pattern_int . '] has a ref of "' . ref($pattern) . '" and not ""' );
		}
		# a bare name that resolves to a compiled var uses that var's regexp
		# string; anything else is treated as an inline regexp
		my $regexp_string = ( exists( $vars->{$pattern} ) ) ? $vars->{$pattern} : $pattern;

		if ( $regexp_string =~ /%\{[^}]*\}/ ) {
			die( '.patterns[' . $pattern_int . '] ("' . $pattern . '") contains un-degrokked grok "%{...}"' );
		}

		if ($anchored) {
			$regexp_string = '\A(?:' . $regexp_string . ')\z';
		}

		my $compiled_re;
		eval { $compiled_re = qr/$regexp_string/; };
		if ($@) {
			die( '.patterns[' . $pattern_int . '] ("' . $pattern . '") does not compile as a regexp... ' . $@ );
		}
		push( @{ $compiled->{'patterns'} }, $compiled_re );
		$pattern_int++;
	} ## end foreach my $pattern ( @{ $rule->{'patterns'} } )

	return $compiled;
} ## end sub _compile_rule

=head1 AUTHOR

Zane C. Bowers-Hadley, C<< <vvelox at vvelox.net> >>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by Zane C. Bowers-Hadley.

This is free software, licensed under:

  The GNU Lesser General Public License, Version 3, June 2007

=cut

1;    # End of Log::Munger::LogProcessor
