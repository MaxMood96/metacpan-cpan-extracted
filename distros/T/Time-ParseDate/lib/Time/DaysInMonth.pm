package Time::DaysInMonth;

use Carp;

require 5.008001;

@ISA = qw(Exporter);
@EXPORT = qw(days_in is_leap);
@EXPORT_OK = qw(%mltable);

use strict;

use vars qw($VERSION %mltable);

$VERSION = 2026.0219;

CONFIG:	{
	%mltable = qw(
		 1	31
		 3	31
		 4	30
		 5	31
		 6	30
		 7	31
		 8	31
		 9	30
		10	31
		11	30
		12	31);
}

sub days_in
{
	# Month is 1..12
	my ($year, $month) = @_;
	return $mltable{$month+0} unless $month == 2;
	return 28 unless &is_leap($year);
	return 29;
}

sub is_leap
{
	my ($year) = @_;
	return 0 unless $year % 4 == 0;
	return 1 unless $year % 100 == 0;
	return 0 unless $year % 400 == 0;
	return 1;
}

1;

__END__

=head1 NAME

Time::DaysInMonth -- simply report the number of days in a month

=head1 SYNOPSIS

	use Time::DaysInMonth;
	$days = days_in($year, $month_1_to_12);
	$leapyear = is_leap($year);

=head1 DESCRIPTION

DaysInMonth is simply a package to report the number of days in
a month.  That's all it does.  Really!

=head1 AUTHOR

Best Practical Solutions, LLC E<lt>modules@bestpractical.comE<gt>

=head1 ORIGINAL AUTHOR

David Muir Sharnoff

=head1 BUGS

This only deals with the "modern" calendar.  Look elsewhere for
historical time and date support.

=head1 LICENSE AND COPYRIGHT

Copyright (C) 1996-1999 David Muir Sharnoff.
Copyright (C) 2026 Best Practical Solutions, LLC.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

