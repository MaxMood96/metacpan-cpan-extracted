package Log::Munger::App::Command::list_fields;

use strict;
use warnings;
use Log::Munger::App -command;
use Log::Munger::RuleFileParser ();

sub opt_spec {
	return ( [ 'f=s', 'Rule file to inspect.' ], );
}

sub abstract { "List the fields a rule file can produce (a schema hint)" }

sub description {
	"Reads a rule file and lists what it can emit without running anything against it: the
named-capture fields of its patterns, the fields its pattern decomposes produce, the prefixes
its kv decomposes produce keys under, and the fields it geoips.

The kv prefixes are listed separately because those keys are whatever the log line happened to
contain and are not knowable until something is matched.
";
}

sub validate { return 1 }

# Collects the named capture names out of a resolved regexp string.
#
# This is how the field list is worked out without running anything: a pattern's
# (?<name>...) groups are the fields it emits, so reading them straight off the
# resolved regexp gives the schema. It only finds what is written down, which is
# why kv decompose keys are reported separately as a prefix rather than as
# individual fields. Those are whatever the log line happened to contain and are
# not knowable until something is matched.
#
# The name pattern is [A-Za-z_]\w*, which is what Perl accepts for a capture name.
# That also means (?<= and (?<! are skipped, since neither can look like a name.
#
# Args:
#
#     - $string :: The resolved regexp string to read, after templating rather
#         than the vars_templated source.
#
#     - $set :: Hash ref used as a set. Every name found is added as a key with a
#         value of 1. Modified in place, so it accumulates across calls, which is
#         how the fields of every pattern in a file end up in one collection.
#
# Returns nothing. The names come back through $set.
#
#     my %fields;
#     _captures( $rules->{'vars'}{'SSH_FAILED'}, \%fields );
#     # $fields{ssh_user} = 1, $fields{ssh_src_ip} = 1, ...
sub _captures {
	my ( $string, $set ) = @_;
	while ( $string =~ /\(\?<([A-Za-z_]\w*)>/g ) {
		$set->{$1} = 1;
	}
	return;
}

sub execute {
	my ( $self, $opts, $args ) = @_;

	if ( !defined( $opts->{'f'} ) ) {
		die('No rule file specified via -f');
	}

	my $rules = Log::Munger::RuleFileParser->new->load( 'file' => $opts->{'f'} );
	my $vars  = ( ref( $rules->{'vars'} ) eq 'HASH' ) ? $rules->{'vars'} : {};

	my %fields;    # static capture names
	my %kv;        # prefix => source field (dynamic)
	my %geoip;     # field => 1

	my @rulelist = ( ref( $rules->{'rules'} ) eq 'ARRAY' ) ? @{ $rules->{'rules'} } : ();
	foreach my $rule (@rulelist) {
		next if ( ref($rule) ne 'HASH' );

		# pattern captures
		foreach my $pattern ( @{ $rule->{'patterns'} } ) {
			next if ( ref($pattern) ne '' );
			my $string = exists( $vars->{$pattern} ) ? $vars->{$pattern} : $pattern;
			_captures( $string, \%fields );
		}

		# decompose (rule-level, else file-level default)
		my $decompose = defined( $rule->{'decompose'} ) ? $rule->{'decompose'} : $rules->{'decompose'};
		if ( ref($decompose) eq 'ARRAY' ) {
			foreach my $d ( @{$decompose} ) {
				next if ( ref($d) ne 'HASH' );
				my $type = defined( $d->{'type'} ) ? $d->{'type'} : 'kv';
				if ( $type eq 'kv' ) {
					my $prefix = defined( $d->{'prefix'} ) ? $d->{'prefix'} : '';
					$kv{$prefix} = $d->{'field'};
				} elsif ( $type eq 'pattern' ) {
					my $string = exists( $vars->{ $d->{'pattern'} } ) ? $vars->{ $d->{'pattern'} } : $d->{'pattern'};
					_captures( $string, \%fields ) if ( defined($string) );
				}
			} ## end foreach my $d ( @{$decompose} )
		} ## end if ( ref($decompose) eq 'ARRAY' )

		# geoip (rule-level, else file-level default)
		my $g = defined( $rule->{'geoip'} ) ? $rule->{'geoip'} : $rules->{'geoip'};
		if ( ref($g) eq 'ARRAY' ) {
			$geoip{$_} = 1 for ( @{$g} );
		}
	} ## end foreach my $rule (@rulelist)

	print "fields:\n";
	print "  $_\n" for ( sort keys %fields );

	if (%kv) {
		print "\nkv-decompose (dynamic keys):\n";
		foreach my $prefix ( sort keys %kv ) {
			print "  ${prefix}* (from " . $kv{$prefix} . ")\n";
		}
	}

	if (%geoip) {
		print "\ngeoip:\n";
		print "  .geoip.$_\n" for ( sort keys %geoip );
	}

	return;
} ## end sub execute

1;
