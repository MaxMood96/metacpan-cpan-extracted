# This code is part of Perl distribution Math-Formula version 0.18.
# The POD got stripped from this file by OODoc version 3.03.
# For contributors see file ChangeLog.

# This software is copyright (c) 2023-2025 by Mark Overmeer.

# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
# SPDX-License-Identifier: Artistic-1.0-Perl OR GPL-1.0-or-later

#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Math::Formula::Config::INI;{
our $VERSION = '0.18';
}

use parent 'Math::Formula::Config';

use warnings;
use strict;

use Log::Report 'math-formula';
use Scalar::Util 'blessed';

use Config::INI::Writer  ();
use Config::INI::Reader  ();

use Math::Formula::Context ();
use Math::Formula          ();

#--------------------

#--------------------

sub save($%)
{	my ($self, $context, %args) = @_;
	my $name  = $context->name;

	my $index = $context->_index;
	my %tree  = (
		_        => $self->_set_encode($index->{attributes}),
		formulas => $self->_set_encode($index->{formulas}),
	);

	my $fn = $self->path_for($args{filename} || "$name.ini");
	Config::INI::Writer->write_file(\%tree, $fn);
}

sub _set_encode($)
{	my ($self, $set) = @_;
	my %data;
	$data{$_ =~ s/^ctx_//r} = $self->_serialize($_, $set->{$_}) for keys %$set;
	\%data;
}

sub _double_quoted($) { '"' . ($_[0] =~ s/"/\\"/gr) . '"' }

sub _serialize($$)
{	my ($self, $name, $what) = @_;
	my %attrs;

	if(blessed $what && $what->isa('Math::Formula'))
	{	if(my $r = $what->returns) { $attrs{returns} = $r };
		$what = $what->expression;
	}

	my $v = '';
	if(blessed $what && $what->isa('Math::Formula::Type'))
	{	# No attributes possible for simple types
		return $what->value
			if $what->isa('MF::STRING') || $what->isa('MF::FLOAT') || $what->isa('MF::INTEGER');

		$v = _double_quoted($what->token);
	}
	elsif(ref $what eq 'CODE')
	{	warning __x"cannot (yet) save CODE, skipped '{name}'", name => $name;
		return undef;
	}
	elsif(length $what)
	{	$v = _double_quoted $what;
	}

	if(keys %attrs)
	{	$v .= '; ' . (join ', ', map "$_='$attrs{$_}'", sort keys %attrs);
	}

	return $v;
}


sub load($%)
{	my ($self, $name, %args) = @_;
	my $fn = $self->path_for($args{filename} || "$name.ini");

	my $read  = Config::INI::Reader->read_file($fn);
	my $attrs = $self->_set_decode($read->{_});
	Math::Formula::Context->new(name => $name, %$attrs,
		formulas => $self->_set_decode($read->{formulas}),
	);
}

sub _set_decode($)
{	my ($self, $set) = @_;
	$set or return {};

	my %forms;
	$forms{$_} = $self->_unpack($_, $set->{$_}) for keys %$set;
	\%forms;
}

sub _unpack($$)
{	my ($self, $name, $encoded) = @_;
	my $dummy = Math::Formula->new('dummy', '7');

	if($encoded =~ m/^"(.*?)"(?:;\s*(.*))?$/)
	{	my ($expr, $attrs) = ($1, $2 // '');
		my %attrs = $attrs =~ m/(\w+)\='([^']+)'/g;
		return Math::Formula->new($name, $expr =~ s/\\"/"/gr, %attrs);
	}

	  $encoded =~ qr/^[0-9]+$/           ? MF::INTEGER->new($encoded)
	: $encoded =~ qr/^[0-9][0-9.e+\-]+$/ ? MF::FLOAT->new($encoded)
	: MF::STRING->new(undef, $encoded);
}

#--------------------

1;
