# Copyright 2001-2025, Paul Johnson (paul@pjcj.net)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# https://pjcj.net

package Devel::Cover::Condition_or_3;

use strict;
use warnings;

our $VERSION = '1.50'; # VERSION

use base "Devel::Cover::Condition";

sub count   { 3 }
sub headers { [qw( l !l&&r !l&&!r )] }

1

__END__

=head1 NAME

Devel::Cover::Condition_or_3 - Code coverage metrics for Perl

=head1 VERSION

version 1.50

=head1 SYNOPSIS

 use Devel::Cover::Condition_or_3;

=head1 DESCRIPTION

Module for storing condition coverage information for or conditions
where the right value is a constant.

=head1 SEE ALSO

 Devel::Cover::Condition

=head1 METHODS

=head1 BUGS

Huh?

=head1 LICENCE

Copyright 2001-2025, Paul Johnson (paul@pjcj.net)

This software is free.  It is licensed under the same terms as Perl itself.

The latest version of this software should be available from my homepage:
https://pjcj.net

=cut
