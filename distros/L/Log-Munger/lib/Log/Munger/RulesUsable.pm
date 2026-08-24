package Log::Munger::RulesUsable;

use 5.006;
use strict;
use warnings;

=head1 NAME

Log::Munger::RulesUsable - Checks that a rules hash is fit to run.

=head1 VERSION

Version 0.0.1

=cut

our $VERSION = '0.0.1';

=head1 SYNOPSIS

    use Log::Munger::RulesUsable;

    eval { Log::Munger::RulesUsable->usable( 'rules' => $rules_hash ); };
    if ($@) {
        die( 'unusable rules... ' . $@ );
    }

=head1 METHODS

=head2 usable

Checks that a rules hash is structurally sound enough to run against.

This says nothing about whether the rules do what they were meant to do. It only
confirms that the hash is a hash, that it has a C<rules> key, and that the key
holds an array with something in it. Anything past that, such as whether the
patterns compile or whether the tests pass, is L<Log::Munger::RulesTest>'s job.

The split exists because the two are used at different times. Something starting
up wants a cheap look at a file it is about to load, not the full test suite.

    - rules :: The rules hash ref to check. Required.
        Default :: undef

Returns 1 if the hash is usable. Otherwise dies with a message naming the specific
thing that was wrong, so the caller has something worth printing.

    Log::Munger::RulesUsable->usable( 'rules' => $rules_hash );

=cut

sub usable {
	my ( $blank, %opts ) = @_;

	if ( !defined( $opts{'rules'} ) ) {
		die('$opts{rules} is undef');
	} elsif ( ref( $opts{'rules'} ) ne 'HASH' ) {
		die( '$opts{rules} has a ref of "' . ref( $opts{'rules'} ) . '" and not "HASH"' );
	} elsif ( !defined( $opts{'rules'}{'rules'} ) ) {
		die('$opts{rules}{rules} is undef meaning the rules hash contains no rules');
	} elsif ( ref( $opts{'rules'}{'rules'} ) ne 'ARRAY' ) {
		die( '$opts{rules}{rules} has a ref of "' . ref( $opts{'rules'}{'rules'} ) . '" and not "ARRAY"' );
	} elsif ( !defined( $opts{'rules'}{'rules'}[0] ) ) {
		die('$opts{rules}{rules}[0] is undef meaning the rules hash contains no rules');
	}

	return 1;
} ## end sub usable
