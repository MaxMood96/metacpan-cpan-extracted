package RDF::Cowl::Lib::Gen::Class::DataCompl;
# ABSTRACT: Private class for RDF::Cowl::DataCompl
$RDF::Cowl::Lib::Gen::Class::DataCompl::VERSION = '1.0.0';
## DO NOT EDIT
## Generated via maint/tt/Class.pm.tt

package # hide from PAUSE
  RDF::Cowl::DataCompl;

use strict;
use warnings;
use feature qw(state);
use Devel::StrictMode qw( STRICT );
use RDF::Cowl::Lib qw(arg);
use RDF::Cowl::Lib::Types qw(:all);
use Types::Common qw(Maybe BoolLike PositiveOrZeroInt Str StrMatch InstanceOf);
use Type::Params -sigs;

my $ffi = RDF::Cowl::Lib->ffi;


# cowl_data_compl
$ffi->attach( [
 "COWL_WRAP_cowl_data_compl"
 => "new" ] =>
	[
		arg "CowlAnyDataRange" => "operand",
	],
	=> "CowlDataCompl"
	=> sub {
		my $RETVAL;
		my $xs    = shift;
		my $class = shift;


		state $signature = signature(
			strictness => STRICT,
			pos => [
				CowlAnyDataRange, { name => "operand", },
			],
		);

		$RETVAL = $xs->( &$signature );

		die "RDF::Cowl::DataCompl::new: error: returned NULL" unless defined $RETVAL;
		$RDF::Cowl::Object::_INSIDE_OUT{$$RETVAL}{retained} = 1;
		return $RETVAL;
	}
);


# cowl_data_compl_get_operand
$ffi->attach( [
 "COWL_WRAP_cowl_data_compl_get_operand"
 => "get_operand" ] =>
	[
		arg "CowlDataCompl" => "range",
	],
	=> "CowlDataRange"
	=> sub {
		my $RETVAL;
		my $xs    = shift;


		state $signature = signature(
			strictness => STRICT,
			pos => [
				CowlDataCompl, { name => "range", },
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

RDF::Cowl::Lib::Gen::Class::DataCompl - Private class for RDF::Cowl::DataCompl

=head1 VERSION

version 1.0.0

=head1 AUTHOR

Zakariyya Mughal <zmughal@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2024 by Auto-Parallel Technologies, Inc..

This is free software, licensed under Eclipse Public License - v 2.0.

=cut
