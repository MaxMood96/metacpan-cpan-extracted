package Gherkin::Token;
$Gherkin::Token::VERSION = '35.1.0';
use strict;
use warnings;

use Class::XSAccessor
  constructor => 'new',
  accessors   => [
    qw/line location/,
    map { "matched_$_" } qw/type keyword keyword_type
      indent items text gherkin_dialect/
  ],
  ;

sub is_eof { my $self = shift; return !$self->line }
sub detach { }

sub token_value {
    my $self = shift;
    return $self->is_eof ? "EOF" : $self->line->get_line_text;
}

1;
