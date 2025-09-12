# This code is part of Perl distribution Log-Report version 1.41.
# The POD got stripped from this file by OODoc version 3.04.
# For contributors see file ChangeLog.

# This software is copyright (c) 2007-2025 by Mark Overmeer.

# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
# SPDX-License-Identifier: Artistic-1.0-Perl OR GPL-1.0-or-later

#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Log::Report::DBIC::Profiler;{
our $VERSION = '1.41';
}

use base 'DBIx::Class::Storage::Statistics';

use strict;
use warnings;

use Log::Report  'log-report', import => 'trace';
use Time::HiRes  qw/time/;

#--------------------

my $start;

sub print($) { trace $_[1] }

sub query_start(@)
{	my $self = shift;
	$self->SUPER::query_start(@_);
	$start   = time;
}

sub query_end(@)
{	my $self = shift;
	$self->SUPER::query_end(@_);
	trace sprintf "execution took %0.4f seconds elapse", time-$start;
}

1;
