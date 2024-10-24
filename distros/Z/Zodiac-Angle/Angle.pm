package Zodiac::Angle;

use strict;
use warnings;

use Class::Utils qw(set_params);
use Error::Pure qw(err);
use List::Util 1.33 qw(none);
use Readonly;
use Unicode::UTF8 qw(decode_utf8);

Readonly::Array our @SIGN_TYPES => qw(ascii sign struct);
Readonly::Hash our %ZODIAC => (
	1 => {
		'sign' => decode_utf8('♈'), # Aries/Beran
		'ascii' => 'ar',
		'ascii_long' => 'aries',
	},
	2 => {
		'sign' => decode_utf8('♉'), # Taurus/Býk
		'ascii' => 'ta',
		'ascii_long' => 'taurus',
	},
	3 => {
		'sign' => decode_utf8('♊'), # Gemini/Blíženci
		'ascii' => 'ge',
		'ascii_long' => 'gemini',
	},
	4 => {
		'sign' => decode_utf8('♋'), # Cancer/Rak
		'ascii' => 'cn',
		'ascii_long' => 'cancer',
	},
	5 => {
		'sign' => decode_utf8('♌'), # Leo/Lev
		'ascii' => 'le',
		'ascii_long' => 'leo',
	},
	6 => {
		'sign' => decode_utf8('♍'), # Virgo/Panna
		'ascii' => 'vi',
		'ascii_long' => 'virgo',
	},
	7 => {
		'sign' => decode_utf8('♎'), # Libra/Váhy
		'ascii' => 'li',
		'ascii_long' => 'libra',
	},
	8 => {
		'sign' => decode_utf8('♏'), # Scorpio/Štír
		'ascii' => 'sc',
		'ascii_long' => 'scorpio',
	},
	9 => {
		'sign' => decode_utf8('♐'), # Sagittarius/Střelec
		'ascii' => 'sa',
		'ascii_long' => 'sagittarius',
	},
	10 => {
		'sign' => decode_utf8('♑'), # Capricorn/Kozoroh
		'ascii' => 'cp',
		'ascii_long' => 'capricorn',
	},
	11 => {
		'sign' => decode_utf8('♒'), # Aquarius/Vodnář
		'ascii' => 'aq',
		'ascii_long' => 'aquarius',
	},
	12 => {
		'sign' => decode_utf8('♓'), # Pisces/Ryby
		'ascii' => 'pi',
		'ascii_long' => 'pisces',
	},
);
Readonly::Scalar our $SPACE => ' ';
Readonly::Scalar our $SEP => '|';

our $VERSION = 0.07;

# Constructor.
sub new {
	my ($class, @params) = @_;

	# Create object.
	my $self = bless {}, $class;

	# Process parameters.
	set_params($self, @params);

	return $self;
}

sub angle2zodiac {
	my ($self, $angle, $opts_hr) = @_;

	# Options.
	if (! defined $opts_hr || ! exists $opts_hr->{'minute'}) {
		$opts_hr->{'minute'} = 1;
	}
	if (! exists $opts_hr->{'second'}) {
		$opts_hr->{'second'} = 0;
	}
	if (! exists $opts_hr->{'second_round'}) {
		$opts_hr->{'second_round'} = 4;
	}
	if (! exists $opts_hr->{'sign_type'}) {
		$opts_hr->{'sign_type'} = 'sign';
	}
	if (none { $opts_hr->{'sign_type'} eq $_ } @SIGN_TYPES) {
		err "Parameter 'sign_type' is bad. Possible values are 'sign', 'ascii' and 'struct'.";
	}

	my $ret = {};

	# Full angle degree.
	my $full_angle_degree = int($angle);
	$angle -= $full_angle_degree;
	$angle *= 60;

	# Angle minute.
	if ($opts_hr->{'minute'}) {
		$ret->{'angle_minute'} = int($angle);
		$angle -= $ret->{'angle_minute'};
		$angle *= 60;
	}

	# Angle second.
	if ($opts_hr->{'second'}) {
		my $print_format = '%0.'.$opts_hr->{'second_round'}.'f';
		$ret->{'angle_second'} = sprintf($print_format, $angle);
	}

	# Angle sign.
	$ret->{'sign'} = int($full_angle_degree / 30);

	# Angle degree in sign.
	$ret->{'angle_degree'} = $full_angle_degree - ($ret->{'sign'} * 30);

	# Output.
	my $zodiac_angle;

	# Output with sign (UTF-8).
	if ($opts_hr->{'sign_type'} eq 'sign') {
		$zodiac_angle = $ret->{'angle_degree'}.decode_utf8('°').
			$ZODIAC{$ret->{'sign'} + 1}->{'sign'};
		if ($opts_hr->{'minute'}) {
			$zodiac_angle .= $ret->{'angle_minute'}.decode_utf8("′");
			if ($opts_hr->{'second'}) {
				$zodiac_angle .= $ret->{'angle_second'}.decode_utf8("′′");
			}
		}

	# Output with ascii.
	} elsif ($opts_hr->{'sign_type'} eq 'ascii') {
		$zodiac_angle = $ret->{'angle_degree'}.$SPACE.
			$ZODIAC{$ret->{'sign'} + 1}->{'ascii'};
		if ($opts_hr->{'minute'}) {
			$zodiac_angle .= $SPACE.$ret->{'angle_minute'}."'";
			if ($opts_hr->{'second'}) {
				$zodiac_angle .= $ret->{'angle_second'}."''";
			}
		}

	# Structure.
	} else {
		$zodiac_angle = $ret->{'angle_degree'}.decode_utf8('°').$SEP.
			$ZODIAC{$ret->{'sign'} + 1}->{'ascii_long'};
		if ($opts_hr->{'minute'}) {
			$zodiac_angle .= $SEP.$ret->{'angle_minute'}.decode_utf8("′");
			if ($opts_hr->{'second'}) {
				$zodiac_angle .= $SEP.$ret->{'angle_second'}.decode_utf8("′′");
			}
		}
	}

	return $zodiac_angle;
}

sub zodiac2angle {
	my ($self, $zodiac_angle) = @_;

	# TODO
	my $angle;

	return $angle;
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

Zodiac::Angle - Class for zodiac_angle manipulation.

=head1 SYNOPSIS

 use Zodiac::Angle;

 my $obj = Zodiac::Angle->new(%params);
 my $zodiac_angle = $obj->angle2zodiac($angle, $opts_hr);
 my $angle = $obj->zodiac2angle($zodiac_angle);

=head1 METHODS

=head2 C<new>

 my $obj = Zodiac::Angle->new(%params);

Constructor.

Returns instance of 'Zodiac::Angle'.

=head2 C<angle2zodiac>

 my $zodiac_angle = $obj->angle2zodiac($angle, $opts_hr);

Convert angle to Zodiac angle.

Options defined C<$opts_hr> control output. Possible keys in reference to hash
are: minute (0/1 print minutes, default 1), second (0/1 print second, default 0),
second_round (number of round numbers, default 4), sign_type (sign, ascii and
struct, default sign).

Default value of C<$opts_hr> is { minute => 1 }.

Returns zodiac angle string.

=head2 C<zodiac2angle>

 my $angle = $obj->zodiac2angle($zodiac_angle);

Convert Zodiac angle to angle.

Returns angle.

=head1 ERRORS

 new():
         From Class::Utils::set_params():
                 Unknown parameter '%s'.

 angle2zodiac():
         Parameter 'sign_type' is bad. Possible values are 'sign', 'ascii' and 'struct'.

=head1 EXAMPLE1

=for comment filename=angle_to_zodiac.pl

 use strict;
 use warnings;

 use Zodiac::Angle;
 use Unicode::UTF8 qw(encode_utf8);

 # Object.
 my $obj = Zodiac::Angle->new;

 if (@ARGV < 1) {
         print STDERR "Usage: $0 angle\n";
         exit 1;
 }
 my $angle = $ARGV[0];

 my $zodiac_angle = Zodiac::Angle->new->angle2zodiac($angle);

 # Print out.
 print 'Angle: '.$angle."\n";
 print 'Zodiac angle: '.encode_utf8($zodiac_angle)."\n";

 # Output without arguments:
 # Usage: __SCRIPT__ angle

 # Output with '0.5' argument:
 # Angle: 0.5
 # Zodiac angle: 0°♈30′

=head1 EXAMPLE2

=for comment filename=angle_to_zodiac_only_minute.pl

 use strict;
 use warnings;

 use Zodiac::Angle;
 use Unicode::UTF8 qw(encode_utf8);

 # Object.
 my $obj = Zodiac::Angle->new;

 if (@ARGV < 1) {
         print STDERR "Usage: $0 angle\n";
         exit 1;
 }
 my $angle = $ARGV[0];

 my $zodiac_angle = Zodiac::Angle->new->angle2zodiac($angle, {
         'minute' => 0,
 });

 # Print out.
 print 'Angle: '.$angle."\n";
 print 'Zodiac angle: '.encode_utf8($zodiac_angle)."\n";

 # Output without arguments:
 # Usage: __SCRIPT__ angle

 # Output with '0.5' argument:
 # Angle: 0.5
 # Zodiac angle: 0°♈

=head1 EXAMPLE3

=for comment filename=angle_to_zodiac_explicit_second_with_round.pl

 use strict;
 use warnings;

 use Zodiac::Angle;
 use Unicode::UTF8 qw(encode_utf8);

 # Object.
 my $obj = Zodiac::Angle->new;

 if (@ARGV < 1) {
         print STDERR "Usage: $0 angle\n";
         exit 1;
 }
 my $angle = $ARGV[0];

 my $zodiac_angle = Zodiac::Angle->new->angle2zodiac($angle, {
         'minute' => 1,
         'second' => 1,
         'second_round' => 4,
 });

 # Print out.
 print 'Angle: '.$angle."\n";
 print 'Zodiac angle: '.encode_utf8($zodiac_angle)."\n";

 # Output without arguments:
 # Usage: __SCRIPT__ angle

 # Output with '0.5' argument:
 # Angle: 0.5
 # Zodiac angle: 0°♈30′0.0000′′

=head1 EXAMPLE4

=for comment filename=angle_to_zodiac_ascii_output.pl

 use strict;
 use warnings;

 use Zodiac::Angle;
 use Unicode::UTF8 qw(encode_utf8);

 # Object.
 my $obj = Zodiac::Angle->new;

 if (@ARGV < 1) {
         print STDERR "Usage: $0 angle\n";
         exit 1;
 }
 my $angle = $ARGV[0];

 my $zodiac_angle = Zodiac::Angle->new->angle2zodiac($angle, {
         'minute' => 1,
         'second' => 1,
         'second_round' => 4,
         'sign_type' => 'ascii',
 });

 # Print out.
 print 'Angle: '.$angle."\n";
 print 'Zodiac angle: '.encode_utf8($zodiac_angle)."\n";

 # Output without arguments:
 # Usage: __SCRIPT__ angle

 # Output with '0.5' argument:
 # Angle: 0.5
 # Zodiac angle: 0° ar 30'0.0000''

=head1 EXAMPLE5

=for comment filename=angle_to_zodiac_struct_output.pl

 use strict;
 use warnings;

 use Zodiac::Angle;
 use Unicode::UTF8 qw(encode_utf8);

 # Object.
 my $obj = Zodiac::Angle->new;

 if (@ARGV < 1) {
         print STDERR "Usage: $0 angle\n";
         exit 1;
 }
 my $angle = $ARGV[0];

 my $zodiac_angle = Zodiac::Angle->new->angle2zodiac($angle, {
         'minute' => 1,
         'second' => 1,
         'second_round' => 4,
         'sign_type' => 'struct',
 });

 # Print out.
 print 'Angle: '.$angle."\n";
 print 'Zodiac angle: '.encode_utf8($zodiac_angle)."\n";

 # Output without arguments:
 # Usage: __SCRIPT__ angle

 # Output with '0.5' argument:
 # Angle: 0.5
 # Zodiac angle: 0°|aries|30′|0.0000′′

=head1 DEPENDENCIES

L<Class::Utils>,
L<Error::Pure>,
L<List::Util>,
L<Readonly>,
L<Unicode::UTF8>.

=head1 SEE ALSO

=over

=item L<angle2zodiac>

Script to convert angle to zodiac string.

=item L<App::Angle2Zodiac>

Base class for angle2zodiac script.

=item L<Zodiac::Angle::SwissEph>

Class for zodiac_angle manipulation based on SwissEph.

=back

=head1 REPOSITORY

L<https://github.com/michal-josef-spacek/Zodiac-Angle>

=head1 AUTHOR

Michal Josef Špaček L<mailto:skim@cpan.org>

L<http://skim.cz>

=head1 LICENSE AND COPYRIGHT

© 2020-2024 Michal Josef Špaček

BSD 2-Clause License

=head1 VERSION

0.07

=cut
