package EBook::Ishmael::Time;
use 5.016;
our $VERSION = '2.00';
use strict;
use warnings;

use Exporter 'import';
our @EXPORT = qw(guess_time format_locale_time format_rfc3339_time);

use Time::Piece;

# Format strings should be order from most specificity to least.
my @STRPTIME_FMTS = (
    # Date/time representation in current locale
    "%c",
    # '%c' + %Z
    "%a %b %d %T %Y %Z",
    # '%c' on my system (en_US.UTF-8)
    "%a %b %d %T %Y",
    # RFC3339
    "%Y-%m-%dT%T%z",
    # RFC822
    "%d %b %y %H:%M %Z",
    "%d %b %y %H:%M %z",
    # RFC1123
    "%a %d %b %Y %T %Z",
    "%a %d %b %Y %T %z",
    # RFC850
    "%a %d-%b-%y %T %Z",
    # output of my date(1)
    "%a %b %e %T %p %Z %Y",
    # misc. date formats
    "%d.%m.%Y",
    "%m.%d.%Y",
    "%d.%m.%y",
    "%m.%d.%y",
    "%d/%m/%Y",
    "%m/%d/%Y",
    "%d/%m/%y",
    "%m/%d/%y",
    "%Y",
);

sub guess_time {

    my ($str) = @_;

    $str =~ s/^\s+|\s+$//g;
    $str =~ s/,/ /g;
    $str =~ s/\s+/ /g;

    for my $f (@STRPTIME_FMTS) {
        my $tp = eval {
            # Silence "garbage at end of string" warning message
            local $SIG{__WARN__} = sub {};
            Time::Piece->strptime($str, $f);
        };
        if (defined $tp) {
            return $tp->epoch;
        }
    }

    return undef;

}

sub format_locale_time {

    my $time = shift;

    return gmtime($time)->strftime("%c");

}

sub format_rfc3339_time {

    my $time = shift;

    return gmtime($time)->strftime("%Y-%m-%dT%H:%M:%S%z");

}

1;

=head1 NAME

EBook::Ishmael::Time - Time-handling subroutines for ishmael

=head1 SYNOPSIS

  use EBook::Ishmael::Time qw(guess_time);

  my $t = guess_time("01.14.2025");

=head1 DESCRIPTION

B<EBook::Ishmael::Time> is a module that provides various time-handling
subroutines for L<ishmael>. This is a private module, please consult the
L<ishmael> manual for user documentation.

=head1 SUBROUTINES

=over 4

=item $epoch = guess_time($str)

C<guess_time()> guesses the timestamp format of C<$str> and returns the number
seconds since the Unix epoch, or C<undef> if it could not identify the
timestamp format.

=item $locale = format_locale_time($epoch)

Formats the given time in the preferred format of the current locale.

=item $rfc3339 = format_rfc3339_time($epoch)

Formats the given time as an RFC3339 timestamp.

=back

=head1 AUTHOR

Written by Samuel Young, E<lt>samyoung12788@gmail.comE<gt>.

This project's source can be found on its
L<Codeberg Page|https://codeberg.org/1-1sam/ishmael>. Comments and pull
requests are welcome!

=head1 COPYRIGHT

Copyright (C) 2025-2026 Samuel Young

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

=cut
