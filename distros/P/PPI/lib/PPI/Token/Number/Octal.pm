package PPI::Token::Number::Octal;

=pod

=head1 NAME

PPI::Token::Number::Octal - Token class for a binary number

=head1 SYNOPSIS

  $n = 0777;      # octal integer

=head1 INHERITANCE

  PPI::Token::Number::Octal
  isa PPI::Token::Number
      isa PPI::Token
          isa PPI::Element

=head1 DESCRIPTION

The C<PPI::Token::Number::Octal> class is used for tokens that
represent base-8 numbers.

=head1 METHODS

=cut

use strict;
use PPI::Token::Number ();

our $VERSION = '1.283';

our @ISA = "PPI::Token::Number";

=pod

=head2 base

Returns the base for the number: 8.

=cut

sub base() { 8 }

=pod

=head2 literal

Return the numeric value of this token.

=cut

sub literal {
	my $self = shift;
	return if $self->{_error};
	my $str = $self->_literal;
	# oct supports '0o' notation only since 5.34
	$str =~ s (^0[oO]) (0);
	my $neg = $str =~ s/^\-//;
	my $val = oct $str;
	return $neg ? -$val : $val;
}





#####################################################################
# Tokenizer Methods

sub __TOKENIZER__on_char {
	my $class = shift;
	my $t     = shift;
	my $char  = substr( $t->{line}, $t->{line_cursor}, 1 );

	# Allow underscores straight through
	return 1 if $char eq '_';

	if ( $char =~ /\d/ ) {
		# You cannot have 8s and 9s on octals
		if ( $char eq '8' or $char eq '9' ) {
			$t->{token}->{_error} = "Illegal character in octal number '$char'";
		}
		return 1;
	}

	# Doesn't fit a special case, or is after the end of the token
	# End of token.
	$t->_finalize_token->__TOKENIZER__on_char( $t );
}

1;

=pod

=head1 SUPPORT

See the L<support section|PPI/SUPPORT> in the main module.

=head1 AUTHOR

Chris Dolan E<lt>cdolan@cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2006 Chris Dolan.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
