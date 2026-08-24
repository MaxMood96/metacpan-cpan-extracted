package Log::Munger;

use 5.006;
use strict;
use warnings;
use Log::Munger::LogProcessor ();

=head1 NAME

Log::Munger - Extracts structured fields from log records using YAML rule files.

=head1 VERSION

Version 0.0.1

=cut

our $VERSION = '0.0.1';

=head1 SYNOPSIS

    use Log::Munger;

    my $munger = Log::Munger->new( 'rules' => [ 'sshd', 'postfix' ] );

    # a decoded record, such as what journald or syslog-ng JSON output gives you
    my $fields = $munger->process_item(
        'item' => {
            'PROGRAM' => 'sshd',
            'MESSAGE' => 'Failed password for root from 203.0.113.7 port 44444 ssh2',
        }
    );
    # $fields = { ssh_method => 'password', ssh_user => 'root', ssh_src_ip => '203.0.113.7', ... }

    # a bare string is matched as the MESSAGE field, so whole log lines work as-is
    my $access = $munger->process_item( 'item' => $raw_apache_line );

Each rule file is a YAML document holding a library of named regexps and an ordered
list of rules built from them. A record is walked against those rules in load order,
and the first one whose gates pass and whose pattern matches returns its named
captures. Captured fields can then be broken down further, looked up in a GeoIP
database, and coerced to numbers.

This is the same idea as grok for Logstash, minus the Logstash. See
L<Log::Munger::LogProcessor> for the matching engine and the C<log_munger> command
for the CLI.

=head1 METHODS

=head2 new

Creates a new munger. Rule files may be supplied up front, added later via
L</load>, or both.

Each name is resolved through L<Log::Munger::WhichRuleFile>, so it may be a bare
name such as C<sshd> or a path. A rule file that fails to load or compile is
fatal, which means a broken file is caught here rather than silently producing no
matches later on.

    my $munger = Log::Munger->new( 'rules' => [ 'base', 'postfix' ] );
    my $munger = Log::Munger->new( 'rules' => ['postfix'], 'geoip' => '/path/to/GeoLite2-City.mmdb' );

    - rules :: Rule files to load. The taken value is an array ref.
        Default :: undef

    - geoip :: Path to a MaxMind .mmdb database. When set, rules that flag
        captured fields with a C<geoip:> list have those looked up, with the
        result stored under C<< $result->{geoip}{$field} >>. Needs
        L<IP::Geolocation::MMDB>, which is only loaded when this is used.
        Default :: undef (geoip disabled)

=cut

sub new {
	my ( $blank, %opts ) = @_;

	my $self = {
		'rule_files' => [],
		'processor'  => undef,
		'geoip'      => $opts{'geoip'},
	};
	bless $self;

	if ( defined( $opts{'rules'} ) ) {
		if ( ref( $opts{'rules'} ) ne 'ARRAY' ) {
			die( '$opts{rules} has a ref of "' . ref( $opts{'rules'} ) . '" and not "ARRAY"' );
		}
		push( @{ $self->{'rule_files'} }, @{ $opts{'rules'} } );
		$self->_build_processor;
	}

	return $self;
} ## end sub new

=head2 load

Loads an additional rule file and rebuilds the processor. Rules from files loaded
later are tried after rules from files loaded earlier, so load order is match
priority.

Returns 1. Dies if the file cannot be found, loaded, or compiled.

    - file :: The file to load. Required.
        Default :: undef

    $munger->load( 'file' => 'sshd' );

=cut

sub load {
	my ( $self, %opts ) = @_;

	if ( !defined( $opts{'file'} ) ) {
		die('$opts{file} is undef');
	} elsif ( ref( $opts{'file'} ) ne '' ) {
		die( '$opts{file} ref is "' . ref( $opts{'file'} ) . '" and not ""' );
	}

	push( @{ $self->{'rule_files'} }, $opts{'file'} );
	$self->_build_processor;

	return 1;
} ## end sub load

=head2 process_item

Runs a decoded log record through the loaded rules and returns the named
captures of the first matching rule, or undef if nothing matched (or no rules
have been loaded).

    - item :: The decoded log record (a hash ref), or a bare string. A bare
        string is treated as a raw log line and matched as the C<MESSAGE> field.
        If given, C<item> takes precedence over the field args below.
        Default :: undef

    - message :: The raw log message, assembled into C<< { MESSAGE => ... } >>.
        Default :: undef

    - program :: Optional C<PROGRAM> field (the usual daemon-rule gate).
        Default :: undef

    - priority :: Optional C<PRIORITY> field.
        Default :: undef

    - facility :: Optional C<FACILITY> field.
        Default :: undef

    my $fields = $munger->process_item( 'item' => $json );
    my $fields = $munger->process_item( 'item' => $raw_access_log_line );

    # from a syslog reader that already has the fields split out (e.g. baphomet):
    my $fields = $munger->process_item(
        'message'  => $message,
        'program'  => $program,
        'priority' => $priority,
        'facility' => $facility,
    );

Returns a hash ref of the winning rule's named captures, or undef if nothing
matched. Never dies: an exception during matching comes back as undef rather
than taking down the stream. That bounds failures, not runtime -- a pattern
prone to catastrophic backtracking can still burn CPU on a hostile line.

=cut

sub process_item {
	my ( $self, %opts ) = @_;

	if ( !defined( $self->{'processor'} ) ) {
		return undef;
	}

	return $self->{'processor'}->process_item(%opts);
}

=head2 explain_item

Like L</process_item>, but reports which rule and pattern fired alongside the
fields. Handy when a rule file is not matching what you expected it to. Takes the
same args and never dies. See L<Log::Munger::LogProcessor/explain_item>.

    my $why = $munger->explain_item( 'item' => $json );

    # { matched => 0 }
    # { matched => 1, rule => 'sshd', pattern => 1, field => 'MESSAGE', fields => { ... } }

=cut

sub explain_item {
	my ( $self, %opts ) = @_;

	if ( !defined( $self->{'processor'} ) ) {
		return { 'matched' => 0 };
	}

	return $self->{'processor'}->explain_item(%opts);
}

# Rebuilds the LogProcessor from the rule file names collected so far, passing
# along the geoip database path if one was given to new.
#
# Log::Munger::LogProcessor has no way to append a rule file to an existing
# instance, so every call to new or load throws the old processor away and
# compiles the whole set again. That keeps the rules in load order and keeps the
# compile errors happening at load time.
#
# Takes no args beyond $self.
#
# Returns the new Log::Munger::LogProcessor object, which is also stashed in
# $self->{processor}. Dies if any of the rule files fails to load or compile.
#
#     $self->_build_processor;
sub _build_processor {
	my ($self) = @_;

	my %args = ( 'rules' => $self->{'rule_files'} );
	$args{'geoip'} = $self->{'geoip'} if ( defined( $self->{'geoip'} ) );

	$self->{'processor'} = Log::Munger::LogProcessor->new(%args);

	return $self->{'processor'};
} ## end sub _build_processor

=head1 AUTHOR

Zane C. Bowers-Hadley, C<< <vvelox at vvelox.net> >>

=head1 SEE ALSO

=over 4

=item * L<Log::Munger::LogProcessor> - the matching engine.

=item * L<Log::Munger::RulesTest> - the test harness behind C<log_munger test_all>.

=item * L<Log::Munger::Degrok> - converting existing grok patterns.

=item * The C<docs/> directory in the distribution, which covers the rule file
format, the primitive library, and writing your own rules.

=back

=head1 BUGS

Report bugs and feature requests through GitHub at
L<https://github.com/LilithSec/Log-Munger>, or to C<bug-log-munger at rt.cpan.org>.

=head1 SUPPORT

    perldoc Log::Munger

You can also find this distribution at:

=over 4

=item * GitHub

L<https://github.com/LilithSec/Log-Munger>

=item * MetaCPAN

L<https://metacpan.org/release/Log-Munger>

=item * RT, CPAN's request tracker

L<https://rt.cpan.org/NoAuth/Bugs.html?Dist=Log-Munger>

=back

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by Zane C. Bowers-Hadley.

This is free software, licensed under:

  The GNU Lesser General Public License, Version 3, June 2007


=cut

1;    # End of Log::Munger
