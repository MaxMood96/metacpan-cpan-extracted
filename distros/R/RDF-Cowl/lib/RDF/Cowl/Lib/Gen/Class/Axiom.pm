package RDF::Cowl::Lib::Gen::Class::Axiom;
# ABSTRACT: Private class for RDF::Cowl::Axiom
$RDF::Cowl::Lib::Gen::Class::Axiom::VERSION = '1.0.0';
## DO NOT EDIT
## Generated via maint/tt/Class.pm.tt

package # hide from PAUSE
  RDF::Cowl::Axiom;

use strict;
use warnings;
use feature qw(state);
use Devel::StrictMode qw( STRICT );
use RDF::Cowl::Lib qw(arg);
use RDF::Cowl::Lib::Types qw(:all);
use Types::Common qw(Maybe BoolLike PositiveOrZeroInt Str StrMatch InstanceOf);
use Type::Params -sigs;

my $ffi = RDF::Cowl::Lib->ffi;


# cowl_axiom_get_type
$ffi->attach( [
 "COWL_WRAP_cowl_axiom_get_type"
 => "get_type" ] =>
	[
		arg "CowlAnyAxiom" => "axiom",
	],
	=> "CowlAxiomType"
	=> sub {
		my $RETVAL;
		my $xs    = shift;


		state $signature = signature(
			strictness => STRICT,
			pos => [
				CowlAnyAxiom, { name => "axiom", },
			],
		);

		$RETVAL = $xs->( &$signature );

		return $RETVAL;
	}
);


# cowl_axiom_get_annot
$ffi->attach( [
 "COWL_WRAP_cowl_axiom_get_annot"
 => "get_annot" ] =>
	[
		arg "CowlAnyAxiom" => "axiom",
	],
	=> "CowlVector"
	=> sub {
		my $RETVAL;
		my $xs    = shift;


		state $signature = signature(
			strictness => STRICT,
			pos => [
				CowlAnyAxiom, { name => "axiom", },
			],
		);

		$RETVAL = $xs->( &$signature );

		$RDF::Cowl::Object::_INSIDE_OUT{$$RETVAL}{retained} = 0;
		$RETVAL = $RETVAL->retain;
		return $RETVAL;
	}
);


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

RDF::Cowl::Lib::Gen::Class::Axiom - Private class for RDF::Cowl::Axiom

=head1 VERSION

version 1.0.0

=head1 AUTHOR

Zakariyya Mughal <zmughal@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2024 by Auto-Parallel Technologies, Inc..

This is free software, licensed under Eclipse Public License - v 2.0.

=cut
