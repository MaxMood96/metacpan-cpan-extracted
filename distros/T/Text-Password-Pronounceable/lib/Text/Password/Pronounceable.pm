package Text::Password::Pronounceable;

use strict;
use warnings;
use Carp;
use Crypt::URandom ();

our $VERSION = '0.31';

# frequency of English digraphs (from D Edwards 1/27/66) 
my  $frequency = [
        [
            4, 20, 28, 52, 2,  11,  28, 4,  32, 4, 6, 62, 23, 167,
            2, 14, 0,  83, 76, 127, 7,  25, 8,  1, 9, 1
        ],    # aa - az
        [
            13, 0, 0, 0,  55, 0, 0,  0, 8, 2, 0,  22, 0, 0,
            11, 0, 0, 15, 4,  2, 13, 0, 0, 0, 15, 0
        ],    # ba - bz
        [
            32, 0, 7, 1,  69, 0,  0,  33, 17, 0, 10, 9, 1, 0,
            50, 3, 0, 10, 0,  28, 11, 0,  0,  0, 3,  0
        ],    # ca - cz
        [
            40, 16, 9, 5,  65, 18, 3,  9, 56, 0, 1, 4, 15, 6,
            16, 4,  0, 21, 18, 53, 19, 5, 15, 0, 3, 0
        ],    # da - dz
        [
            84, 20, 55, 125, 51, 40, 19, 16,  50,  1,
            4,  55, 54, 146, 35, 37, 6,  191, 149, 65,
            9,  26, 21, 12,  5,  0
        ],    # ea - ez
        [
            19, 3, 5, 1,  19, 21, 1, 3, 30, 2, 0, 11, 1, 0,
            51, 0, 0, 26, 8,  47, 6, 3, 3,  0, 2, 0
        ],    # fa - fz
        [
            20, 4, 3, 2,  35, 1,  3, 15, 18, 0, 0, 5, 1, 4,
            21, 1, 1, 20, 9,  21, 9, 0,  5,  0, 1, 0
        ],    # ga - gz
        [
            101, 1, 3, 0, 270, 5,  1, 6, 57, 0, 0, 0, 3, 2,
            44,  1, 0, 3, 10,  18, 6, 0, 5,  0, 3, 0
        ],    # ha - hz
        [
            40, 7,  51, 23, 25, 9,   11, 3,  0, 0, 2, 38, 25, 202,
            56, 12, 1,  46, 79, 117, 1,  22, 0, 4, 0, 3
        ],    # ia - iz
        [
            3, 0, 0, 0, 5, 0, 0, 0, 1, 0, 0, 0, 0, 0,
            4, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0
        ],    # ja - jz
        [
            1, 0, 0, 0, 11, 0, 0, 0, 13, 0, 0, 0, 0, 2,
            0, 0, 0, 0, 6,  2, 1, 0, 2,  0, 1, 0
        ],    # ka - kz
        [
            44, 2, 5, 12, 62, 7,  5, 2, 42, 1, 1,  53, 2, 2,
            25, 1, 1, 2,  16, 23, 9, 0, 1,  0, 33, 0
        ],    # la - lz
        [
            52, 14, 1, 0, 64, 0, 0, 3, 37, 0, 0, 0, 7, 1,
            17, 18, 1, 2, 12, 3, 8, 0, 1,  0, 2, 0
        ],    # ma - mz
        [
            42, 10, 47, 122, 63, 19, 106, 12, 30, 1,
            6,  6,  9,  7,   54, 7,  1,   7,  44, 124,
            6,  1,  15, 0,   12, 0
        ],    # na - nz
        [
            7,  12, 14, 17, 5,  95, 3,  5,  14, 0, 0, 19, 41, 134,
            13, 23, 0,  91, 23, 42, 55, 16, 28, 0, 4, 1
        ],    # oa - oz
        [
            19, 1, 0, 0,  37, 0, 0, 4, 8, 0, 0, 15, 1, 0,
            27, 9, 0, 33, 14, 7, 6, 0, 0, 0, 0, 0
        ],    # pa - pz
        [
            0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 17, 0, 0, 0, 0, 0
        ],    # qa - qz
        [
            83, 8, 16, 23, 169, 4,  8, 8,  77, 1, 10, 5, 26, 16,
            60, 4, 0,  24, 37,  55, 6, 11, 4,  0, 28, 0
        ],    # ra - rz
        [
            65, 9,  17, 9, 73, 13,  1,  47, 75, 3, 0, 7, 11, 12,
            56, 17, 6,  9, 48, 116, 35, 1,  28, 0, 4, 0
        ],    # sa - sz
        [
            57, 22, 3,  1, 76, 5, 2, 330, 126, 1,
            0,  14, 10, 6, 79, 7, 0, 49,  50,  56,
            21, 2,  27, 0, 24, 0
        ],    # ta - tz
        [
            11, 5,  9, 6,  9,  1,  6, 0, 9, 0, 1, 19, 5, 31,
            1,  15, 0, 47, 39, 31, 0, 3, 0, 0, 0, 0
        ],    # ua - uz
        [
            7, 0, 0, 0, 72, 0, 0, 0, 28, 0, 0, 0, 0, 0,
            5, 0, 0, 0, 0,  0, 0, 0, 0,  0, 3, 0
        ],    # va - vz
        [
            36, 1, 1, 0, 38, 0, 0, 33, 36, 0, 0, 4, 1, 8,
            15, 0, 0, 0, 4,  2, 0, 0,  1,  0, 0, 0
        ],    # wa - wz
        [
            1, 0, 2, 0, 0, 1, 0, 0, 3, 0, 0, 0, 0, 0,
            1, 5, 0, 0, 0, 3, 0, 0, 1, 0, 0, 0
        ],    # xa - xz
        [
            14, 5, 4, 2, 7,  12, 12, 6, 10, 0, 0, 3, 7, 5,
            17, 3, 0, 4, 16, 30, 0,  0, 5,  0, 0, 0
        ],    # ya - yz
        [
            1, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        ]
    ];    # za - zz

# We need to know the totals for each row 
my  $row_sums = [
        map {
            my $sum = 0;
            map { $sum += $_ } @$_;
            $sum;
          } @$frequency
    ];


# Frequency with which a given letter starts a word.
my  $start_freq = [
        1299, 425, 725, 271, 375, 470, 93, 223, 1009, 24,
        20,   355, 379, 319, 823, 618, 21, 317, 962,  1991,
        271,  104, 516, 6,   16,  14
    ];

my  $total_sum = 0;
$total_sum += $_ for @$start_freq;

# Store why the last attempt to generate a password failed,
# for the generate method to report.
my $GENERATE_ERROR;

# A draw is four bytes wide, so it has this many possible values.
my $DRAW_BYTES = 4;
my $DRAW_SPACE = 2 ** ( 8 * $DRAW_BYTES );

sub _check_lengths {
    my ($min, $max) = @_;

    Carp::carp "min length should be defined" unless defined $min;
    Carp::carp "min length should be > 0" unless $min>0;

    Carp::carp "max length should be defined" unless defined $max;
    Carp::carp "max length should be > 0" unless $max>0;

    Carp::carp "max length must be >= min length" unless $min<=$max;
}

sub new {
    my $class = shift;
    my ($min, $max) = @_;
    $max ||= $min;

    if (@_) {
	_check_lengths($min, $max);
    }

    return bless { min => $min, max => $max }, $class;
}

sub generate {
    my $self = shift;
    my ($min, $max) = @_;

    if (@_) {
        $max ||= $min;
        _check_lengths($min, $max);
    } elsif (ref $self) { # if given no arguments,
        # use the factory settings (if any)
        $min = $self->{min};
        $max = $self->{max};
    }
    if ( !$min && !$max ) {
        # what? no parameters?
        return q[]; # no random password
    }

    undef $GENERATE_ERROR;
    my $password = $self->_build_password( $min, $max );

    if ( !defined $password ) {
        my $error = defined $GENERATE_ERROR ? $GENERATE_ERROR : 'unknown error';
        Carp::carp "Unable to generate a password: $error";
        return q[]; # never fall back on weaker randomness
    }

    # Return the password
    return $password;
}

# A private helper function for RandomPassword
# Takes a row summary and a frequency chart for the next character to be searched
sub _generate_nextchar {
    my $self = shift;
    my ( $all, $freq ) = @_;
    my ( $pos, $i );

    $pos = $self->_random_int($all);
    return undef if !defined $pos;

    for ( $i = 0 ;
        $pos >= $freq->[$i] ;
        $pos -= $freq->[$i], $i++ )
    {
    }

    return ($i);
}

# The password itself, or undef if a draw from the CSPRNG failed.
sub _build_password {
    my $self = shift;
    my ($min, $max) = @_;

    # When munging characters, we need to know where to start counting letters from
    my $a = ord('a');

    # Lengths run from $min to $max inclusive.  A $max below $min is an error
    # that _check_lengths carps about but has never been fatal: the old
    # int( rand( $max - $min ) ) drew downwards from $min there, so keep that
    # rather than silently pinning every such password to $min.
    my $span = $max - $min;
    my $offset = $self->_random_int( $span >= 0 ? $span + 1 : -$span );
    return undef if !defined $offset;
    my $length = $span >= 0 ? $min + $offset : $min - $offset;

    my $char = $self->_generate_nextchar( $total_sum, $start_freq );
    return undef if !defined $char;

    my @word = ( $char + $a );
    for ( 2 .. $length ) {
        $char =
          $self->_generate_nextchar( $row_sums->[$char],
            $frequency->[$char] );
        return undef if !defined $char;
        push ( @word, $char + $a );
    }

    return pack( "C*", @word );
}

# A uniformly distributed integer in [0, $limit), or undef if the CSPRNG cannot
# be read.  Crypt::URandom deals only in bytes, so a draw of four of them is
# unpacked into a number in [0, 2**32) and reduced modulo $limit.
#
# Modulo on its own would favor the low end of the range, since $limit rarely
# divides the draw space evenly. Draws landing in that leftover partial block
# are discarded and redrawn, leaving a span that does divide evenly.  The block
# is a thin slice of 2**32, so a redraw should be very infrequent.
sub _random_int {
    my ($self, $limit) = @_;
    return 0 if !$limit || $limit <= 1;

    # Only reachable from an absurd max length. Guarded because a wider limit
    # would leave $ceiling at zero, so no draw could ever be accepted and the
    # loop below would spin forever.
    if ( $limit > $DRAW_SPACE ) {
        $GENERATE_ERROR =
            "a range of $limit values is wider than a $DRAW_BYTES byte draw";
        return undef;
    }

    my $ceiling = int( $DRAW_SPACE / $limit ) * $limit;

    while (1) {
        my $draw = _random_bytes($DRAW_BYTES);
        return undef if !defined $draw;

        my $value = unpack 'N', $draw;
        return $value % $limit if $value < $ceiling;
    }
}

# Bytes from the system CSPRNG, or undef if none are to be had.  Crypt::URandom
# dies on error. Trap that here.
sub _random_bytes {
    my ($count) = @_;

    # $@ is localized so that a draw leaves the caller's copy alone, and so
    # that nothing unwinding out of the eval can clobber the reason on the way.
    my ( $bytes, $err );
    {
        local $@;
        $bytes = eval { Crypt::URandom::urandom($count) };
        $err   = $@;
    }

    return $bytes if defined $bytes && length $bytes == $count;

    my $why;
    if ( defined $bytes ) {
        $why = sprintf 'asked for %d byte(s) but received %d',
            $count, length $bytes;
    }
    else {
        $why = $err || 'unknown error';
        $why =~ s/\s+\z//;
    }

    $GENERATE_ERROR
        = "no secure source of randomness is available: $why";

    return undef;
}


1;

=head1 NAME

Text::Password::Pronounceable - Generate pronounceable passwords

=head1 SYNOPSIS

  # Generate a pronounceable password that is between 6 and 10 characters.
  Text::Password::Pronounceable->generate(6, 10);

  # Ditto
  my $pp = Text::Password::Pronounceable->new(6, 10);
  $pp->generate;

=head1 DESCRIPTION

This module generates pronuceable passwords, based the the English
digraphs by D Edwards.

=head2 METHODS

=over

=item B<new>

  $pp = Text::Password::Pronounceable->new($min, $max);
  $pp = Text::Password::Pronounceable->new($len);

Construct a password factory with length limits of $min and $max.
Or create a password factory with fixed length if only one argument
is provided.

=item B<generate>

  $pp->generate;
  $pp->generate($len);
  $pp->generate($min, $max);

  Text::Password::Pronounceable->generate($len);
  Text::Password::Pronounceable->generate($min, $max);

Generate password. If used as an instance method, arguments override
the factory settings.

Returns an empty string on failure, emitting an appropriate error message via
Carp::carp.

=back

=head1 HISTORY

This code derived from mpw.pl, a bit of code with a sordid history.

=over 4

=item *

CPAN module by Chia-liang Kao 9/11/2006.

=item *

Perl cleaned up a bit by Jesse Vincent 1/14/2001.

=item *

Converted to perl from C by Marc Horowitz, 1/20/2000.

=item *

Converted to C from Multics PL/I by Bill Sommerfeld, 4/21/86.

=item *

Original PL/I version provided by Jerry Saltzer.

=back

=head1 LICENSE

Copyright 2006 by Best Practical Solutions, LLC.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See <http://www.perl.com/perl/misc/Artistic.html>

=cut
