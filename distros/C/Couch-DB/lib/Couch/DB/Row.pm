# This code is part of Perl distribution Couch-DB version 0.201.
# The POD got stripped from this file by OODoc version 3.06.
# For contributors see file ChangeLog.

# This software is copyright (c) 2024-2026 by Mark Overmeer.

# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
# SPDX-License-Identifier: Artistic-1.0-Perl OR GPL-1.0-or-later


# SPDX-FileCopyrightText: 2024 Mark Overmeer <mark@overmeer.net>
# SPDX-License-Identifier: Artistic-2.0

package Couch::DB::Row;{
our $VERSION = '0.201';
}


use warnings;
use strict;

use Log::Report 'couch-db';

use Couch::DB::Util;
use Scalar::Util   qw/weaken/;

#--------------------

sub new(@) { my ($class, %args) = @_; (bless {}, $class)->init(\%args) }

sub init($)
{	my ($self, $args) = @_;

	$self->{CDR_result} = delete $args->{result} or panic;
	weaken $self->{CDR_result};

	$self->{CDR_doc}    = delete $args->{doc};
	$self->{CDR_answer} = delete $args->{answer} or panic;
	$self->{CDR_values} = delete $args->{values};
	$self->{CDR_rownr}  = delete $args->{rownr}  or panic;
	$self;
}

#--------------------

sub result() { $_[0]->{CDR_result} }


sub doc() { $_[0]->{CDR_doc} }


sub answer() { $_[0]->{CDR_answer} }


sub values() { $_[0]->{CDR_values} || $_[0]->answer }

#--------------------

sub pageNumber() { $_[0]->result->pageNumber }
sub rowNumberInPage() { ... }
sub rowNumberInSearch() { ... }
sub rowNumberInResult() { $_[0]->{CDR_rownr} }

1;
