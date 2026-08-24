package Log::Munger::RulesTemplateOrder;

use 5.006;
use strict;
use warnings;
use Algorithm::Dependency::Ordered;
use Algorithm::Dependency::Source::HoA;

# Log::Munger::RuleFileParser is loaded at runtime (via require, inside
# _load_no_templating below) rather than with a compile-time use:
# RuleFileParser already uses this module, so a use here would form a circular
# dependency.

=head1 NAME

Log::Munger::RulesTemplateOrder - Works out the order a rule file's templated vars must be resolved in.

=head1 VERSION

Version 0.0.1

=cut

our $VERSION = '0.0.1';

=head1 SYNOPSIS

    use Log::Munger::RulesTemplateOrder;

    my $order = Log::Munger::RulesTemplateOrder->order_for_rules_file( 'file' => 'base' );
    foreach my $var ( @{$order} ) {
        print $var . "\n";
    }

A rule file's C<vars_templated> entries reference each other. C<TIMESTAMP_ISO8601>
is built out of C<YEAR>, C<MONTHNUM>, C<TIME> and friends, and C<TIME> is in turn
built out of C<HOUR>, C<MINUTE> and C<SECOND>. Resolving them in hash order would
leave a C<[% TIME %]> sitting unsubstituted in the middle of a timestamp pattern,
so L<Log::Munger::RuleFileParser> asks this module for a working order first.

The dependencies are read straight off the C<[% VAR %]> references in each
templated var and handed to L<Algorithm::Dependency::Ordered>, which returns a
schedule where nothing comes before something it needs.

C<log_munger rule_file_template_order -f E<lt>fileE<gt>> prints that schedule, and
adding C<-d> prints the dependency map it was derived from.

=head1 METHODS

=head2 order_for_rules_hash

Returns the order the templated vars of an already loaded rules hash have to be
resolved in.

The hash wants to be one from L<Log::Munger::RuleFileParser/load_no_templating>.
Once C<load> has run, the templating is already done and the C<[% VAR %]>
references this reads have been substituted away.

Plain C<vars> are treated as already resolved: a templated var may reference any
of them, but they do not appear in the returned schedule. A name defined under
both C<vars> and C<vars_templated> resolves as the plain var, which is what lets
a file shadow an include's templated var with a plain one.

    - rules :: The rules hash ref to process.
        Default :: undef

Returns an array ref of the C<vars_templated> names, in the order they should be
resolved. A file with neither C<vars> nor C<vars_templated> gets an empty array
ref. Dies on anything L</depends_for_rules_hash> dies on, if a templated var
references a name that is not defined anywhere, or if the references are
circular.

    my $order = Log::Munger::RulesTemplateOrder->order_for_rules_hash( 'rules' => $rules_hash );

=cut

sub order_for_rules_hash {
	my ( $blank, %opts ) = @_;

	if ( !defined( $opts{'rules'} ) ) {
		die('$opts{rules} is undef');
	} elsif ( ref( $opts{'rules'} ) ne 'HASH' ) {
		die( '$opts{rules} has a ref of "' . ref( $opts{'rules'} ) . '" and not HASH' );
	}
	my $rules = $opts{'rules'};

	my $depends_info   = Log::Munger::RulesTemplateOrder->depends_for_rules_hash( 'rules' => $rules );
	my @templated_vars = sort( keys( %{$depends_info} ) );

	my @vars;
	if ( defined( $rules->{'vars'} ) ) {
		@vars = keys( %{ $rules->{'vars'} } );
	}

	# nothing to order (a rules-only file with no vars/vars_templated); return
	# an empty schedule rather than letting Algorithm::Dependency die on it
	if ( !@vars && !@templated_vars ) {
		return [];
	}

	# every plain var becomes a dependency-less, already-selected entry so a
	# templated var may reference it. A name defined under both vars and
	# vars_templated is taken as the plain var, which is what lets a file
	# shadow an include's templated var with a plain one
	foreach my $var (@vars) {
		$depends_info->{$var} = [];
	}

	# a reference to a name defined nowhere would otherwise be dropped from the
	# schedule silently, along with everything that references it
	foreach my $var (@templated_vars) {
		foreach my $reference ( @{ $depends_info->{$var} } ) {
			if ( !exists( $depends_info->{$reference} ) ) {
				die(      '.vars_templated.'
						. $var
						. ' references "'
						. $reference
						. '", which is not defined under .vars or .vars_templated' );
			}
		}
	} ## end foreach my $var (@templated_vars)

	my $deps_source = Algorithm::Dependency::Source::HoA->new($depends_info);
	my $dep         = Algorithm::Dependency::Ordered->new(
		source   => $deps_source,
		selected => \@vars,
	) or die 'Failed to set up dependency algorithm';

	my $schedule = $dep->schedule_all();

	# a circular reference is unschedulable and Algorithm::Dependency omits it
	# quietly rather than erroring, so catch it here by name
	my %shadowed      = map { $_ => 1 } @vars;
	my %scheduled     = defined($schedule) ? ( map { $_ => 1 } @{$schedule} ) : ();
	my @unschedulable = grep { !$scheduled{$_} && !$shadowed{$_} } @templated_vars;
	if ( !defined($schedule) || @unschedulable ) {
		die( 'Could not work out a resolution order for .vars_templated... circular [% %] references between: '
				. join( ', ', @unschedulable ) );
	}

	return $schedule;
} ## end sub order_for_rules_hash

=head2 depends_for_rules_hash

Returns the raw dependency map behind L</order_for_rules_hash>, for when you want
to see what references what rather than just the resulting order.

Each templated var is scanned for C<[% VAR %]> references and gets an entry
listing the names it mentions. A var that references nothing gets an empty list.
Nothing is checked for existence here, so a reference to a var that was never
defined shows up in the map the same as any other; L</order_for_rules_hash> is
what dies on it.

    - rules :: The rules hash ref to process.
        Default :: undef

Returns a hash ref of C<< { var_name => [ names it references ] } >>, or an empty
hash ref if the file has no C<vars_templated>. Dies if C<rules> is undef, is not a
hash ref, holds a C<vars> / C<vars_templated> that is not a hash ref, or holds a
C<vars_templated> entry whose value is not a plain string.

    my $depends = Log::Munger::RulesTemplateOrder->depends_for_rules_hash( 'rules' => $rules_hash );
    # $depends->{TIME} = [ 'HOUR', 'MINUTE', 'SECOND' ]

=cut

sub depends_for_rules_hash {
	my ( $blank, %opts ) = @_;

	if ( !defined( $opts{'rules'} ) ) {
		die('$opts{rules} is undef');
	} elsif ( ref( $opts{'rules'} ) ne 'HASH' ) {
		die( '$opts{rules} has a ref of "' . ref( $opts{'rules'} ) . '" and not HASH' );
	}
	my $rules = $opts{'rules'};

	if ( defined( $rules->{'vars'} ) && ( ref( $rules->{'vars'} ) ne 'HASH' ) ) {
		die( '$opts{rules}{vars} has a ref of "' . ref( $rules->{'vars'} ) . '" and not HASH' );
	} elsif ( defined( $rules->{'vars_templated'} ) && ( ref( $rules->{'vars_templated'} ) ne 'HASH' ) ) {
		die( '$opts{rules}{vars_templated} has a ref of "' . ref( $rules->{'vars_templated'} ) . '" and not HASH' );
	}

	my @templated_vars;
	if ( !defined( $rules->{'vars_templated'} ) ) {
		return {};
	} else {
		# check this here so we die earlier instead of later after doing more processing
		@templated_vars = keys( %{ $rules->{'vars_templated'} } );
		foreach my $var (@templated_vars) {
			if ( ref( $rules->{'vars_templated'}{$var} ) ne '' ) {
				die(      '$opts{rules}{vars_templated}{'
						. $var
						. '} has a ref of "'
						. ref( $rules->{'vars_templated'}{$var} )
						. '" and not ""' );
			}
		}
	} ## end else [ if ( !defined( $rules->{'vars_templated'} ...))]

	my $template_depends = {};
	foreach my $var (@templated_vars) {
		# each reference is recorded once, in first-appearance order, which
		# both dedupes the list and keeps the -d dump of this map stable
		my @has_vars;
		my %seen;
		my $string = $rules->{'vars_templated'}{$var};
		while ( $string =~ /\[\% +([A-Za-z0-9_]+) +\%\]/g ) {
			push( @has_vars, $1 ) if ( !$seen{$1}++ );
		}
		$template_depends->{$var} = \@has_vars;
	} ## end foreach my $var (@templated_vars)

	return $template_depends;
} ## end sub depends_for_rules_hash

=head2 order_for_rules_file

L</order_for_rules_hash> for a rule file on disk. The file is loaded with
L<Log::Munger::RuleFileParser/load_no_templating>, which is the state the ordering
has to be worked out in, and the resulting hash is handed straight over.

    - file :: The file to load. Either a bare name resolved through the search
        path, such as "base", or a path. Required.
        Default :: undef

Returns an array ref of var names in the order they should be resolved. Dies if
the file cannot be found or loaded.

    my $order = Log::Munger::RulesTemplateOrder->order_for_rules_file( 'file' => 'base' );

=cut

sub order_for_rules_file {
	my ( $blank, %opts ) = @_;

	return Log::Munger::RulesTemplateOrder->order_for_rules_hash( 'rules' => _load_no_templating( $opts{'file'} ) );
}

=head2 depends_for_rules_file

L</depends_for_rules_hash> for a rule file on disk, loaded the same way
L</order_for_rules_file> loads it.

    - file :: The file to load. Either a bare name resolved through the search
        path, such as "base", or a path. Required.
        Default :: undef

Returns a hash ref of C<< { var_name => [ names it references ] } >>. Dies if the
file cannot be found or loaded.

    my $depends = Log::Munger::RulesTemplateOrder->depends_for_rules_file( 'file' => 'base' );

=cut

sub depends_for_rules_file {
	my ( $blank, %opts ) = @_;

	return Log::Munger::RulesTemplateOrder->depends_for_rules_hash( 'rules' => _load_no_templating( $opts{'file'} ) );
}

# Loads a rule file via Log::Munger::RuleFileParser->load_no_templating, which
# is the state the ordering has to be worked out in: once load has run, the
# [% VAR %] references this module reads have been substituted away.
#
# RuleFileParser is required at runtime rather than used at compile time since
# it uses this module itself; see the note at the top of the file.
#
# Args:
#
#     - $file :: The file to load. Either a bare name resolved through the
#         search path, such as "base", or a path.
#
# Returns the rules hash ref, with vars_templated left untouched. Dies when
# $file is undef or not a plain string, or when the file cannot be found or
# loaded.
#
#     my $rules = _load_no_templating( $opts{'file'} );
sub _load_no_templating {
	my ($file) = @_;

	if ( !defined($file) ) {
		die('$opts{file} is undef');
	} elsif ( ref($file) ne '' ) {
		die( '$opts{file} ref is "' . ref($file) . '" and not ""' );
	}

	my $rules;
	eval {
		require Log::Munger::RuleFileParser;
		my $parser = Log::Munger::RuleFileParser->new;
		$rules = $parser->load_no_templating( 'file' => $file );
	};
	if ($@) {
		die( 'Failed to call load_no_templating for "' . $file . '"... ' . $@ );
	}

	return $rules;
} ## end sub _load_no_templating
