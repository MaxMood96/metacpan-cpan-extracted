package Clearquest::Utils;

use strict;
use warnings;

use base 'Exporter';
use POSIX qw(strftime);

our @EXPORT = qw(
  verbose
  debug
  display
  error
);

=pod

=head1 NAME Utils.pm

Clearquest::Utils - Utility functions for Clearquest modules

=head1 VERSION

=over

=item Author

Andrew DeFaria <Andrew@DeFaria.com>

=item Revision

$Revision: 1.0 $

=item Created

Wednesday, January 14, 2026

=back

=head1 DESCRIPTION

This module provides common utility functions for Clearquest modules.

=head1 ROUTINES

=cut

=pod

=head2 verbose ($)

Print a verbose message if verbose mode is on.

Parameters:

=for html <blockquote>

=over

=item $msg

The message to print

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item nothing

=back

=for html </blockquote>

=cut

sub verbose ($) {
  my ($msg) = @_;
  print strftime ("%Y-%m-%d %H:%M:%S ", localtime) . $msg . "\n"
    if $ENV{VERBOSE};

  return;
}    # verbose

=pod

=head2 debug ($)

Print a debug message if debug mode is on.

Parameters:

=for html <blockquote>

=over

=item $msg

The message to print

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item nothing

=back

=for html </blockquote>

=cut

sub debug ($) {
  my ($msg) = @_;
  print strftime ("%Y-%m-%d %H:%M:%S ", localtime) . $msg . "\n"
    if $ENV{DEBUG};

  return;
}    # debug

=pod

=head2 display ($)

Display a message.

Parameters:

=for html <blockquote>

=over

=item $msg

The message to display

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item nothing

=back

=for html </blockquote>

=cut

sub display ($) {
  my ($msg) = @_;
  print strftime ("%Y-%m-%d %H:%M:%S ", localtime) . $msg . "\n";

  return;
}    # display

=pod

=head2 error ($;$)

Print an error message and optionally exit.

Parameters:

=for html <blockquote>

=over

=item $msg

The error message

=item $code

Exit code (optional)

=back

=for html </blockquote>

Returns:

=for html <blockquote>

=over

=item nothing

=back

=for html </blockquote>

=cut

sub error ($;$) {
  my ($msg, $code) = @_;
  print strftime ("%Y-%m-%d %H:%M:%S ", localtime) . "ERROR: $msg\n";
  exit ($code) if defined $code;

  return;
}    # error

1;
