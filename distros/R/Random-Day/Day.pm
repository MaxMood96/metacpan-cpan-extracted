package Random::Day;

use strict;
use warnings;

use Class::Utils qw(set_params);
use DateTime;
use DateTime::Event::Random;
use DateTime::Event::Recurrence;
use English;
use Error::Pure qw(err);
use Mo::utils 0.08 qw(check_isa);

our $VERSION = 0.17;

# Constructor.
sub new {
	my ($class, @params) = @_;

	# Create object.
	my $self = bless {}, $class;

	# Day.
	$self->{'day'} = undef;

	# DateTime object from.
	$self->{'dt_from'} = DateTime->new(
		'year' => 1900,
	);

	# DateTime object to.
	$self->{'dt_to'} = DateTime->new(
		'year' => 2050,
	);

	# Month.
	$self->{'month'} = undef;

	# Year.
	$self->{'year'} = undef;

	# Process parameters.
	set_params($self, @params);

	check_isa($self, 'dt_from', 'DateTime');
	check_isa($self, 'dt_to', 'DateTime');

	if (DateTime->compare($self->{'dt_from'}, $self->{'dt_to'}) == 1) {
		err "Parameter 'dt_from' must have older or same date than 'dt_to'.",
			'Date from', $self->{'dt_from'},
			'Date to', $self->{'dt_to'},
		;
	}

	# There is no sense in case that dt_from and dt_to parameters are in
	# same day and not in 00:00:00.
	if ($self->{'dt_from'}->year == $self->{'dt_to'}->year
		&& $self->{'dt_from'}->month == $self->{'dt_to'}->month
		&& $self->{'dt_from'}->day == $self->{'dt_to'}->day
		&& $self->{'dt_from'}->hms ne '00:00:00') {

		err "Parameters 'dt_from' and 'dt_to' are in the same day and not on begin.",
			'Date from', $self->{'dt_from'},
			'Date to', $self->{'dt_to'},
		;
	}

	return $self;
}

# Get DateTime object with random date.
sub get {
	my ($self, $date) = @_;

	if ($self->{'year'}) {
		if ($self->{'month'}) {
			if ($self->{'day'}) {
				$date = $self->random_day_month_year(
					$self->{'day'},
					$self->{'month'},
					$self->{'year'},
				);
			} else {
				$date = $self->random_month_year(
					$self->{'month'},
					$self->{'year'},
				);
			}
		} else {
			if ($self->{'day'}) {
				$date = $self->random_day_year(
					$self->{'day'},
					$self->{'year'},
				);
			} else {
				$date = $self->random_year($self->{'year'});
			}
		}
	} else {
		if ($self->{'month'}) {
			if ($self->{'day'}) {
				$date = $self->random_day_month(
					$self->{'day'},
					$self->{'month'},
				);
			} else {
				$date = $self->random_month($self->{'month'});
			}
		} else {
			if ($self->{'day'}) {
				$date = $self->random_day($self->{'day'});
			} else {
				$date = $self->random;
			}
		}
	}

	return $date;
}

# Random DateTime object for day.
sub random {
	my $self = shift;

	# Random DateTime between from and to.
	my $dt_from = $self->{'dt_from'}->clone;
	if ($dt_from->hms ne '00:00:00') {
		$dt_from->add('days' => 1);
		$dt_from->set(
			'hour' => 0,
			'minute' => 0,
			'second' => 0,
		);
	}
	my $dt = DateTime::Event::Random->datetime(
		'after' => $dt_from,
		'before' => $self->{'dt_to'},
	);

	# Unify to begin of day.
	my $daily = DateTime::Event::Recurrence->daily;
	my $ret_dt = $daily->current($dt);

	return $ret_dt;
}

# Random DateTime object for day defined by day.
sub random_day {
	my ($self, $day) = @_;

	$self->_check_day($day);
	my $monthly_day = DateTime::Event::Recurrence->monthly(
		'days' => $day,
	);

	return $monthly_day->next($self->random);
}

# Random DateTime object for day defined by day and month.
sub random_day_month {
	my ($self, $day, $month) = @_;

	$self->_check_day($day);
	my $yearly_day_month = DateTime::Event::Recurrence->yearly(
		'days' => $day,
		'months' => $month,
	);
	my $dt = $yearly_day_month->next($self->random);
	if (! defined $dt) {
		err 'Cannot create DateTime object.';
	}

	return $dt;
}

# Random DateTime object for day defined by day and year.
sub random_day_year {
	my ($self, $day, $year) = @_;

	$self->_check_day($day);
	if ($day > 31) {
		err 'Day is greater than possible day.',
			'Day', $day,
		;
	}
	if ($self->{'dt_from'}->year > $year) {
		err 'Year is lesser than minimal year.',
			'Expected year', $year,
			'Minimal year', $self->{'dt_from'}->year,
		;
	}
	if ($self->{'dt_to'}->year < $year) {
		err 'Year is greater than maximal year.',
			'Expected year', $year,
			'Maximal year', $self->{'dt_to'}->year,
		;
	}
	my ($from_month, $to_month) = (1, 12);
	if ($self->{'dt_from'}->year == $year) {
		$from_month = $self->{'dt_from'}->month;
		if ($self->{'dt_from'}->day > $day) {
			$from_month++;
		}
		if ($from_month > 12) {
			err 'Day is lesser than minimal possible date.';
		}
	}
	if ($self->{'dt_to'}->year == $year) {
		$to_month = $self->{'dt_to'}->month;
		if ($self->{'dt_to'}->day < $day) {
			$to_month--;
		}
		if ($to_month < 1) {
			err 'Day is greater than maximal possible date.';
		}
	}
	if ($to_month < $from_month) {
		err 'Day not fit between start and end dates.';
	}
	my @possible_months = ($from_month .. $to_month);
	my $dt;
	while (! $dt) {
		my $random_month = $possible_months[int(rand(scalar @possible_months))];
		$dt = eval {
			DateTime->new(
				'day' => $day,
				'month' => $random_month,
				'year' => $year,
			);
		};
	}

	return $dt;
}

# DateTime object for day defined by day, month and year.
sub random_day_month_year {
	my ($self, $day, $month, $year) = @_;

	$self->_check_day($day);
	my $dt = eval {
		DateTime->new(
			'day' => $day,
			'month' => $month,
			'year' => $year,
		);
	};
	if ($EVAL_ERROR) {
		err 'Cannot create DateTime object.',
			'Error', $EVAL_ERROR;
	}

	if (DateTime->compare($self->{'dt_from'}, $dt) == 1) {
		err "Begin of expected month is lesser than minimal date.",
			'Expected year', $year,
			'Expected month', $month,
			'Expected day', $day,
			'Minimal year', $self->{'dt_from'}->year,
			'Minimal month', $self->{'dt_from'}->month,
			'Minimal day', $self->{'dt_from'}->day,
		;
	}

	if (DateTime->compare($dt, $self->{'dt_to'}) == 1) {
		err "End of expected month is greater than maximal date.",
			'Expected year', $year,
			'Expected month', $month,
			'Expected day', $day,
			'Maximal year', $self->{'dt_to'}->year,
			'Maximal month', $self->{'dt_to'}->month,
			'Maximal day', $self->{'dt_to'}->day,
		;
	}

	return $dt;
}

# Random DateTime object for day defined by month.
sub random_month {
	my ($self, $month) = @_;

	my @possible_years = ($self->{'dt_from'}->year .. $self->{'dt_to'}->year);
	if ($month > $self->{'dt_to'}->month) {
		pop @possible_years;
	}
	my $random_year_index =  int(rand(scalar @possible_years));
	my $random_year = $possible_years[$random_year_index];

	return $self->random_month_year($month, $random_year);
}

# Random DateTime object for day defined by month and year.
sub random_month_year {
	my ($self, $month, $year) = @_;

	my $after = eval {
		DateTime->new(
			'day' => 1,
			'month' => $month,
			'year' => $year,
		);
	};
	if ($EVAL_ERROR) {
		err 'Cannot create DateTime object.',
			'Error', $EVAL_ERROR;
	}

	if (DateTime->compare($self->{'dt_from'}, $after) == 1) {
		err "Begin of expected month is lesser than minimal date.",
			'Expected year', $year,
			'Expected month', $month,
			'Minimal year', $self->{'dt_from'}->year,
			'Minimal month', $self->{'dt_from'}->month,
		;
	}

	my $before = $after->clone;
	$before->add(months => 1)->subtract(days => 1);

	if (DateTime->compare($before, $self->{'dt_to'}) == 1) {
		err "End of expected month is greater than maximal date.",
			'Expected year', $year,
			'Expected month', $month,
			'Maximal year', $self->{'dt_to'}->year,
			'Maximal month', $self->{'dt_to'}->month,
		;
	}

	my $daily = DateTime::Event::Recurrence->daily;
	return $daily->next(DateTime::Event::Random->datetime(
		'after' => $after,
		'before' => $before,
	));
}

# Random DateTime object for day defined by year.
sub random_year {
	my ($self, $year) = @_;

	if ($self->{'dt_from'}->year > $year) {
		err "Year is lesser than minimal year.",
			'Expected year', $year,
			'Minimal year', $self->{'dt_from'}->year,
		;
	}
	if ($self->{'dt_to'}->year < $year) {
		err "Year is greater than maximal year.",
			'Expected year', $year,
			'Maximal year', $self->{'dt_to'}->year,
		;
	}

	my $daily = DateTime::Event::Recurrence->daily;

	return $daily->next(DateTime::Event::Random->datetime(
		'after' => DateTime->new(
			'day' => 1,
			'month' => 1,
			'year' => $year,
		),
		'before' => DateTime->new(
			'day' => 31,
			'month' => 12,
			'year' => $year,
		),
	));
}

# Check day.
sub _check_day {
	my ($self, $day) = @_;

	if ($day !~ m/^\d+$/ms) {
		err "Day isn't positive number.";
	}
	if ($day == 0) {
		err 'Day cannot be a zero.';
	}
	return;
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

Random::Day - Class for random day generation.

=head1 SYNOPSIS

 use Random::Day;

 my $obj = Random::Day->new(%params);
 my $dt = $obj->get;
 my $dt = $obj->random;
 my $dt = $obj->random_day($day);
 my $dt = $obj->random_day_month($day, $month);
 my $dt = $obj->random_day_month_year($day, $month, $year);
 my $dt = $obj->random_day_year($day, $year);
 my $dt = $obj->random_month($month);
 my $dt = $obj->random_month_year($month, $year);
 my $dt = $obj->random_year($year);

=head1 METHODS

=head2 C<new>

 my $obj = Random::Day->new(%params);

Constructor.

=over 8

=item * C<day>

Day.

Default value is undef.

=item * C<dt_from>

DateTime object from.

Default value is DateTime object for 1900 year.

=item * C<dt_to>

DateTime object to.

Default value is DateTime object for 2050 year.

=item * C<month>

Month.

Default value is undef.

=item * C<year>

Year.

Default value is undef.

=back

Returns instance of object.

=head2 C<get>

 my $dt = $obj->get;

Get random date defined by constructor parameters.

Returns DateTime object for date.

=head2 C<random>

 my $dt = $obj->random;

Get random date.

Returns DateTime object for date.

=head2 C<random_day>

 my $dt = $obj->random_day($day);

Get random date defined by day.

Returns DateTime object for date.

=head2 C<random_day_month>

 my $dt = $obj->random_day_month($day, $month);

Get random date defined by day and month.

Returns DateTime object for date.

=head2 C<random_day_year>

 my $dt = $obj->random_day_year($day, $year);

Get random date defined by day and year.

Returns DateTime object for date.

=head2 C<random_day_month_year>

 my $dt = $obj->random_day_month_year($day, $month, $year);

Get random date defined by day, month and year.

Returns DateTime object for date.

=head2 C<random_month>

 my $dt = $obj->random_month($month);

Get random date defined by month.

Returns DateTime object for date.

=head2 C<random_month_year>

 my $dt = $obj->random_month_year($month, $year);

Get random date defined by month and year.

Returns DateTime object for date.

=head2 C<random_year>

 my $dt = $obj->random_year($year);

Get random date defined by year.

Returns DateTime object for date.

=head1 ERRORS

 new():
         From Class::Utils::set_params():
                 Unknown parameter '%s'.
         From Mo::utils::check_isa():
                 Parameter 'dt_from' must be a 'DateTime' object.
                         Value: %s
                         Reference: %s
                 Parameter 'dt_to' must be a 'DateTime' object.
                         Value: %s
                         Reference: %s
         Parameter 'dt_from' must have older or same date than 'dt_to'.
                 Date from: %s
                 Date to: %s
         Parameters 'dt_from' and 'dt_to' are in the same day and not on begin.
                 Date from: %s
                 Date to: %s

 random_day():
         Day cannot be a zero.
         Day isn't positive number.

 random_day_month():
         Cannot create DateTime object.
         Day cannot be a zero.
         Day isn't positive number.

 random_day_month_year():
         Begin of expected month is lesser than minimal date.
                 Expected year: %s
                 Expected month: %s
                 Expected day: %s
                 Minimal year: %s
                 Minimal month: %s
                 Minimal day: %s
         Cannot create DateTime object.
                 Error: %s
         Day cannot be a zero.
         Day isn't positive number.
         End of expected month is greater than maximal date.
                 Expected year: %s
                 Expected month: %s
                 Expected day: %s
                 Maximal year: %s
                 Maximal month: %s
                 Maximal day: %s

 random_day_year():
         Day cannot be a zero.
         Day is greater than maximal possible date.
         Day is greater than possible day.
                 Day: %s
         Day is lesser than minimal possible date.
         Day isn't positive number.
         Day not fit between start and end dates.
         Year is lesser than minimal year.
                 Expected year: %s
                 Minimal year: %s
         Year is greater than maximal year.
                 Expected year: %s
                 Maximal year: %s

 random_month():
         Cannot create DateTime object.
                 Error: %s

 random_month_year():
         Begin of expected month is lesser than minimal date.
                 Expected year: %s
                 Expected month: %s
                 Minimal year: %s
                 Minimal month: %s
         Cannot create DateTime object.
                 Error: %s
         End of expected month is greater than maximal date.
                 Expected year: %s
                 Expected month: %s
                 Maximal year: %s
                 Maximal month: %s

 random_year():
         Year is greater than maximal year.
                 Expected year: %s
                 Maximal year: %s
         Year is lesser than minimal year.
                 Expected year: %s
                 Minimal year: %s

=head1 EXAMPLE

=for comment filename=get_random_day.pl

 use strict;
 use warnings;

 use Random::Day;

 # Object.
 my $obj = Random::Day->new;

 # Get date.
 my $dt = $obj->get;

 # Print out.
 print $dt->ymd."\n";

 # Output like:
 # \d\d\d\d-\d\d-\d\d

=head1 DEPENDENCIES

L<Class::Utils>,
L<DateTime>,
L<DateTime::Event::Random>,
L<DateTime::Event::Recurrence>,
L<English>,
L<Error::Pure>,
L<Mo::utils>.

=head1 SEE ALSO

=over

=item L<Data::Random>

Perl module to generate random data

=item L<DateTime::Event::Random>

DateTime extension for creating random datetimes.

=item L<Random::Day::InTheFuture>

Class for random day generation in the future.

=item L<Random::Day::InThePast>

Class for random day generation in the past.

=back

=head1 REPOSITORY

L<https://github.com/michal-josef-spacek/Random-Day>

=head1 AUTHOR

Michal Josef Špaček L<mailto:skim@cpan.org>

L<http://skim.cz>

=head1 LICENSE AND COPYRIGHT

© 2013-2025 Michal Josef Špaček

BSD 2-Clause License

=head1 VERSION

0.17

=cut
