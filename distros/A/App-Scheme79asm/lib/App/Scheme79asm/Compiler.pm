package App::Scheme79asm::Compiler;

use 5.014000;
use strict;
use warnings;

our $VERSION = '1.000';

use Carp qw/croak/;
use Data::Dumper qw/Dumper/;
use Scalar::Util qw/looks_like_number/;

use Data::SExpression qw/cons consp scalarp/;
use List::MoreUtils qw/firstidx/;

our @PRIMOPS = qw/car cdr cons atom progn reverse-list/;

sub make_symbol { Data::SExpression::Symbol->new(shift) }

# types
our $LIST   = make_symbol 'LIST';
our $SYMBOL = make_symbol 'SYMBOL';
our $VAR    = make_symbol 'VAR';
# no need for closures
our $PROC   = make_symbol 'PROC';
our $IF     = make_symbol 'IF';
our $CALL   = make_symbol 'CALL';
# no need for quoted constants

# primitives
our $MORE    = make_symbol 'MORE';
our $FUNCALL = make_symbol 'FUNCALL';

BEGIN {
	*cons    = *Data::SExpression::cons;
	*consp   = *Data::SExpression::consp;
	*scalarp = *Data::SExpression::scalarp;
}

# list processing routines
sub append {
	my ($expr, $rest) = @_;
	if (defined $expr) {
		cons $expr->car, append($expr->cdr, $rest)
	} else {
		$rest
	}
}

sub mapcar (&@);

sub mapcar (&@) {
	my ($block, $expr) = @_;
	if (defined $expr) {
		my $result;
		do {
			local $_ = $expr->car;
			$result = $block->()
		};
		cons $result, mapcar { $block->($_) } $expr->cdr
	} else {
		undef
	}
}

sub revacc {
	my ($expr, $acc) = @_;
	if (defined $expr) {
		revacc ($expr->cdr, cons($expr->car, $acc))
	} else {
		$acc
	}
}

sub rev {
	my ($expr) = @_;
	revacc $expr, undef;
}

sub positionacc {
	my ($expr, $list, $acc) = @_;
	if (!defined $list) {
		undef
	} elsif ($list->car eq $expr) {
		$acc
	} else {
		positionacc($expr, $list->cdr, $acc + 1)
	}
}

sub position {
	my ($expr, $list) = @_;
	positionacc $expr, $list, 0
}
# end list processing routines

sub new {
	my ($class) = @_;
	my %self = (
		symbols => ['', '', 'T'],
		nsymbols => 3,
		symbol_map => {T => 2},
	);
	bless \%self, $class;
}

sub process_quoted {
	my ($self, $expr) = @_;
	if (!defined $expr) { # nil
		[$LIST => 0]
	} elsif (scalarp $expr) {
		$expr = uc $expr;
		if ($expr eq 'NIL') {
			return [$LIST => 0]
		}
		if (!exists $self->{symbol_map}{$expr}) {
			$self->{symbol_map}{$expr} = $self->{nsymbols};
			$self->{nsymbols}++;
			push @{$self->{symbols}}, $expr;
		}
		[$SYMBOL => $self->{symbol_map}{$expr}]
	} elsif (consp $expr) {
		[$LIST => $self->process_quoted($expr->cdr), $self->process_quoted($expr->car)]
	} else {
		croak 'argument to process_quoted is not a scalar, cons, or nil: ', Dumper($expr);
	}
}

sub process_proc {
	my ($self, $func_name, $func_args, $func_body, $env) = @_;
	my $new_env = append cons($func_name, rev $func_args), $env;
	$self->process_toplevel($func_body, $new_env)
}

sub rest_of_funcall {
	my ($self, $func, $args) = @_;
	if (!defined $args) {
		$func
	} else {
		[$MORE => $self->rest_of_funcall($func, $args->cdr), $args->car]
	}
}

sub process_funcall {
	my ($self, $func_name, $func_args, $env) = @_;
	my $prim_idx = firstidx { uc $_ eq uc $func_name } @PRIMOPS;
	my $processed_args =
	  mapcar { $self->process_toplevel($_, $env) } $func_args;
	if ($prim_idx > -1) {
		if (!defined $processed_args) {
			croak "Cannot call primitive $func_name with no arguments";
		}
		[$CALL => $self->rest_of_funcall([make_symbol(uc $func_name), 0], $processed_args->cdr), $processed_args->car]
	} else {
		my $final_args = append $processed_args, cons ($self->process_toplevel($func_name, $env), undef);
		[$CALL => $self->rest_of_funcall([$FUNCALL => 0], $final_args->cdr), $final_args->car]
	}
}

sub process_toplevel {
	my ($self, $expr, $env) = @_;
	if (!defined $expr) {
		[$LIST => 0]
	} elsif (scalarp $expr) {
		if (looks_like_number $expr) {
			$self->process_quoted($expr);
		} elsif (uc $expr eq 'T') {
			[$SYMBOL => 2]
		} elsif (uc $expr eq 'NIL') {
			[$LIST => 0]
		} else {
			my $position = position $expr, $env;
			if (defined $position) {
				[$VAR => -1 - $position]
			} else {
				croak "Variable $expr not in environment";
			}
		}
	} else {
		my $func = uc $expr->car;
		if ($func eq 'QUOTE') {
			$self->process_quoted($expr->cdr->car)
		} elsif ($func eq 'LAMBDA') {
			my $func_name = $expr->cdr->car;
			my $func_args = $expr->cdr->cdr->car;
			my $func_body = $expr->cdr->cdr->cdr->car; ## no critic (ProhibitLongChainsOfMethodCalls)
			[$PROC => $self->process_proc($func_name, $func_args, $func_body, $env)]
		} elsif ($func eq 'IF') {
			my ($if_cond, $if_then, $if_else) =
			  map { $self->process_toplevel($_, $env) }
			  ($expr->cdr->car, $expr->cdr->cdr->car, $expr->cdr->cdr->cdr->car); ## no critic (ProhibitLongChainsOfMethodCalls)
			[$IF => [$LIST => $if_else, $if_then], $if_cond]
		} else {
			$self->process_funcall($expr->car, $expr->cdr, $env)
		}
	}
}

sub compile_sexp {
	my ($self, $expr) = @_;
	$self->process_toplevel($expr, undef)
}

sub compile_string {
	my ($self, $string) = @_;
	my $sexp = Data::SExpression->new(
		{fold_lists => 0, use_symbol_class => 1}
	);
	my $expr = $sexp->read($string);
	$self->compile_sexp($expr)
}

1;
__END__

=encoding utf-8

=head1 NAME

App::Scheme79asm::Compiler - compile Lisp code to SIMPLE assembly

=head1 SYNOPSIS

  use App::Scheme79asm;
  use App::Scheme79asm::Compiler;
  use Data::SExpression qw/cons/;

  my $asm = App::Scheme79asm->new;
  my $compiler = App::Scheme79asm::Compiler->new;
  my $string = '(reverse-list 2 1)';
  my $assembly_sexp = $compiler->compile_string($string);
  $asm->process($assembly_sexp);
  $asm->finish;
  $asm->print_verilog

=head1 DESCRIPTION

This module takes Lisp code and compiles it to the format that
L<App::Scheme79asm> wants it to be.

The two main methods are B<compile_sexp>(I<$sexp>) which compiles an
already-parsed sexp to assembly format, and
B<compile_string>(I<$string>) which compiles a string to assembly
format.

The assembly format is a sexp. These functions return an
already-parsed sexp (an arrayref like the ones returned by
L<Data::SExpression>'s B<read> method). This arrayref can be passed
directly to L<App::Scheme79asm>'s B<process> method.

If a string representation of the sexp is required, it can be obtained
by calling the B<dump_sexp> function in L<Data::Dump::Sexp> with such an arrayref.

=head1 AUTHOR

Marius Gavrilescu, E<lt>marius@ieval.roE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2018 by Marius Gavrilescu

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.24.3 or,
at your option, any later version of Perl 5 you may have available.


=cut
