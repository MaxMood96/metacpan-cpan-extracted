# This code is part of Perl distribution Couch-DB version 0.201.
# The POD got stripped from this file by OODoc version 3.06.
# For contributors see file ChangeLog.

# This software is copyright (c) 2024-2026 by Mark Overmeer.

# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
# SPDX-License-Identifier: Artistic-1.0-Perl OR GPL-1.0-or-later


package Couch::DB::Util;{
our $VERSION = '0.201';
}

use parent 'Exporter';

use warnings;
use strict;

use Log::Report    'couch-db';
use Data::Dumper   ();
use Scalar::Util   qw/blessed/;

our @EXPORT_OK   = qw/flat pile apply_tree simplified/;
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

sub import
{	my $class  = shift;
	$_->import for qw(strict warnings utf8 version);
	$class->export_to_level(1, undef, @_);
}

#--------------------

sub flat(@) { grep defined, map +(ref eq 'ARRAY' ? @$_ : $_), @_ }


sub pile(@) { +[ flat @_ ] }


#XXX why can't I find a CPAN module which does this?

sub apply_tree($$);
sub apply_tree($$)
{	my ($tree, $code) = @_;
	  ! ref $tree          ? $code->($tree)
	: ref $tree eq 'ARRAY' ? +[ map apply_tree($_, $code), @$tree ]
	: ref $tree eq 'HASH'  ? +{ map +($_ => apply_tree($tree->{$_}, $code)), keys %$tree }
	: ref $tree eq 'CODE'  ? "$tree"
	:    $code->($tree);
}


sub simplified($$)
{	my ($name, $data) = @_;

	my $v = apply_tree $data, sub ($) {
		my $e = shift;
		  ! blessed $e         ? $e
		: $e->isa('DateTime')  ? "DATETIME($e)"
		: $e->isa('Couch::DB::Document') ? 'DOCUMENT('.$e->id.')'
		: $e->isa('JSON::PP::Boolean')   ? ($e ? 'BOOL(true)' : 'BOOL(false)')
		: $e->isa('version')   ? "VERSION($e)"
		:    'OBJECT('.(ref $e).')';
	};

	Data::Dumper->new([$v], [$name])->Indent(1)->Quotekeys(0)->Sortkeys(1)->Dump;
}

1;
