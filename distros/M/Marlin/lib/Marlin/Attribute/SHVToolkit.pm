use 5.008008;
use strict;
use warnings;

package Marlin::Attribute::SHVToolkit;

BEGIN {
	our $AUTHORITY = 'cpan:TOBYINK';
	our $VERSION   = '0.023001';
	
	require Sub::HandlesVia::Toolkit::SubAccessorSmall;
	our @ISA = 'Sub::HandlesVia::Toolkit::SubAccessorSmall';
};

sub code_generator_for_attribute {
	my ( $self, $target, $attr ) = @_;
	my $realattr = $self->_attr;
	
	my $codegen = $self->SUPER::code_generator_for_attribute( $target, $attr );
	$codegen->{xs_info} = $realattr->shvxs_info;
	$codegen->{target}  = $realattr->{package};
	return $codegen;
}

1;
