# Copyright 2001-2025, Paul Johnson (paul@pjcj.net)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# https://pjcj.net

package Devel::Cover::Statement;

use strict;
use warnings;

our $VERSION = '1.50'; # VERSION

use base "Devel::Cover::Criterion";

sub val         { $_[0][0] }
sub uncoverable { $_[0][1] }
sub covered     { $_[0][0] }
sub total       { 1 }
sub percentage  { $_[0][0] ? 100 : 0 }
sub error       { $_[0]->simple_error }
sub criterion   { "statement" }

1

__END__

=head1 NAME

Devel::Cover::Statement - Code coverage metrics for Perl

=head1 VERSION

version 1.50

=head1 SYNOPSIS

 use Devel::Cover::Statement;

=head1 DESCRIPTION

Module for storing statement coverage information.

=head1 SEE ALSO

 Devel::Cover::Criterion

=head1 METHODS

=head1 BUGS

Huh?

=head1 LICENCE

Copyright 2001-2025, Paul Johnson (paul@pjcj.net)

This software is free.  It is licensed under the same terms as Perl itself.

The latest version of this software should be available from my homepage:
https://pjcj.net

=cut
