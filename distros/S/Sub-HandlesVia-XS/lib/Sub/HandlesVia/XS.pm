use 5.008008;
use strict;
use warnings;

package Sub::HandlesVia::XS;

use Types::Common -is, -types;

BEGIN {
	our $AUTHORITY = 'cpan:TOBYINK';
	our $VERSION   = '0.003000';
	
	require XSLoader;
	__PACKAGE__->XSLoader::load( $VERSION );
};

sub ArraySource {
	my ( $class, $string ) = @_;
	my $method = 'ARRAY_SRC_' . uc $string;
	return $class->$method;
}

sub ReturnPattern {
	my ( $class, $string ) = @_;
	my $method = 'SHOULD_RETURN_' . uc $string;
	return $class->$method;
}

sub TypeInfo {
	my ( $class, $type ) = @_;
	
	die "This method returns a ( coderef, flags ) pair" unless wantarray;
	
	my $coderef;
	if ( is_Object $type and $type->can('compiled_check') ) {
		$coderef = $type->compiled_check;
	}
	elsif ( is_Object $type and $type->can('check') ) {
		$coderef = sub { $type->check( @_ ? $_[0] : $_ ) };
	}
	elsif ( is_CodeRef $type ) {
		$coderef = $type;
	}
	elsif ( is_CodeLike $type ) {
		$coderef = \&$type;
	}
	else {
		die "Not a type?";
	}
	
	my $type_flags = _type_to_number( $type );
	return ( $coderef, $type_flags );
}

sub _type_to_number {
	my ( $given_type, $no_recurse ) = @_;
	
	if ( is_TypeTiny $given_type ) {
		my $type = $given_type->find_constraining_type;
		
		if ( $type == Any or $type == Item ) {
			return TYPE_BASE_ANY;
		}
		elsif ( $type == Defined ) {
			return TYPE_BASE_DEFINED;
		}
		elsif ( $type == Ref ) {
			return TYPE_BASE_REF;
		}
		elsif ( $type == Bool ) {
			return TYPE_BASE_BOOL;
		}
		elsif ( $type == Int ) {
			return TYPE_BASE_INT;
		}
		elsif ( $type == PositiveOrZeroInt ) {
			return TYPE_BASE_PZINT;
		}
		elsif ( $type == Num ) {
			return TYPE_BASE_NUM;
		}
		elsif ( $type == PositiveOrZeroNum ) {
			return TYPE_BASE_PZNUM;
		}
		elsif ( $type == Str ) {
			return TYPE_BASE_STR;
		}
		elsif ( $type == NonEmptyStr ) {
			return TYPE_BASE_NESTR;
		}
		elsif ( $type == ClassName ) {
			return TYPE_BASE_CLASSNAME;
		}
		elsif ( $type == Object ) {
			return TYPE_BASE_OBJECT;
		}
		elsif ( $type == ScalarRef ) {
			return TYPE_BASE_SCALARREF;
		}
		elsif ( $type == CodeRef ) {
			return TYPE_BASE_CODEREF;
		}
		elsif ( $type == ArrayRef ) {
			return TYPE_ARRAYREF;
		}
		elsif ( $type == HashRef ) {
			return TYPE_HASHREF;
		}
		elsif ( $type->is_parameterized and @{ $type->parameters } == 1 and (
			$type->parameterized_from == ArrayRef
			or $type->parameterized_from == HashRef
			) ) {
			my $container_type = $type->parameterized_from;
			my $element_type   = $type->type_parameter;
			return _type_to_number( $container_type, 1 ) | _type_to_number( $element_type, 1 ) unless $no_recurse;
		}
	}
	
	return TYPE_OTHER;
}

no Types::Common;

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Sub::HandlesVia::XS - XS parts for Sub::HandlesVia; no user-serviceable parts inside

=head1 DESCRIPTION

Use L<Sub::HandlesVia>. That module will make use of Sub::HandlesVia::XS when
it can.

=head1 BUGS

Please report any bugs to
L<https://github.com/tobyink/p5-sub-handlesvia-xs/issues>.

=head1 SEE ALSO

L<Sub::HandlesVia>, L<Marlin>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2026 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.


=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.

