# Copyright 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020 Kevin Ryde

# This file is part of Math-PlanePath.
#
# Math-PlanePath is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by the
# Free Software Foundation; either version 3, or (at your option) any later
# version.
#
# Math-PlanePath is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License along
# with Math-PlanePath.  If not, see <http://www.gnu.org/licenses/>.


# http://www.cisl.ucar.edu/css/papers/sfc3.pdf
#    Hilbert + Peano-meander
#     
# http://oceans11.lanl.gov/svn/POP/trunk/pop/source/distribution.F90
#

package Math::PlanePath::CincoCurve;
use 5.004;
use strict;
#use List::Util 'min', 'max';
*min = \&Math::PlanePath::_min;
*max = \&Math::PlanePath::_max;

use vars '$VERSION', '@ISA';
$VERSION = 129;
use Math::PlanePath;
use Math::PlanePath::Base::NSEW;
@ISA = ('Math::PlanePath::Base::NSEW',
        'Math::PlanePath');

use Math::PlanePath::Base::Generic
  'is_infinite',
  'round_nearest';
use Math::PlanePath::Base::Digits
  'round_down_pow',
  'digit_split_lowtohigh',
  'digit_join_lowtohigh';


use constant n_start => 0;
use constant class_x_negative => 0;
use constant class_y_negative => 0;
*xy_is_visited = \&Math::PlanePath::Base::Generic::xy_is_visited_quad1;


#------------------------------------------------------------------------------
# tables generated by tools/dekking-curve-table.pl
#
my @next_state = ( 0, 0,50,50,50,  # 0
                  75,25,25,50,50,
                   0, 0,75,50, 0,
                   0, 0,25,75,75,
                   0,25,75,75, 0,
                  25,25,75,75,75,  # 25
                  50, 0, 0,75,75,
                  25,25,50,75,25,
                  25,25, 0,50,50,
                  25, 0,50,50,25,
                  50,50, 0, 0, 0,  # 50
                  25,75,75, 0, 0,
                  50,50,25, 0,50,
                  50,50,75,25,25,
                  50,75,25,25,50,
                  75,75,25,25,25,  # 75
                   0,50,50,25,25,
                  75,75, 0,25,75,
                  75,75,50, 0, 0,
                  75,50, 0, 0,75);
my @digit_to_x = (0,1,2,2,2, 1,1,0,0,0, 0,1,1,2,2, 3,4,4,3,3, 4,4,3,3,4,
                  4,3,2,2,2, 3,3,4,4,4, 4,3,3,2,2, 1,0,0,1,1, 0,0,1,1,0,
                  0,0,0,1,2, 2,1,1,2,3, 4,4,3,3,4, 4,4,3,3,2, 2,1,1,0,0,
                  4,4,4,3,2, 2,3,3,2,1, 0,0,1,1,0, 0,0,1,1,2, 2,3,3,4,4);
my @digit_to_y = (0,0,0,1,2, 2,1,1,2,3, 4,4,3,3,4, 4,4,3,3,2, 2,1,1,0,0,
                  4,4,4,3,2, 2,3,3,2,1, 0,0,1,1,0, 0,0,1,1,2, 2,3,3,4,4,
                  0,1,2,2,2, 1,1,0,0,0, 0,1,1,2,2, 3,4,4,3,3, 4,4,3,3,4,
                  4,3,2,2,2, 3,3,4,4,4, 4,3,3,2,2, 1,0,0,1,1, 0,0,1,1,0);
my @yx_to_digit = ( 0, 1, 2,23,24,  # 0
                    7, 6, 3,22,21,
                    8, 5, 4,19,20,
                    9,12,13,18,17,
                   10,11,14,15,16,
                   16,15,14,11,10,  # 25
                   17,18,13,12, 9,
                   20,19, 4, 5, 8,
                   21,22, 3, 6, 7,
                   24,23, 2, 1, 0,
                    0, 7, 8, 9,10,  # 50
                    1, 6, 5,12,11,
                    2, 3, 4,13,14,
                   23,22,19,18,15,
                   24,21,20,17,16,
                   16,17,20,21,24,  # 75
                   15,18,19,22,23,
                   14,13, 4, 3, 2,
                   11,12, 5, 6, 1,
                   10, 9, 8, 7, 0);
my @min_digit = ( 0, 0, 0, 0, 0,  # 0
                  7, 7, 7, 7, 8,
                  8, 8, 9, 9,10,
                  0, 0, 0, 0, 0,
                  6, 5, 5, 5, 5,
                  5, 5, 9, 9,10,  # 25
                  0, 0, 0, 0, 0,
                  3, 3, 3, 3, 4,
                  4, 4, 9, 9,10,
                  0, 0, 0, 0, 0,
                  3, 3, 3, 3, 4,  # 50
                  4, 4, 9, 9,10,
                  0, 0, 0, 0, 0,
                  3, 3, 3, 3, 4,
                  4, 4, 9, 9,10,
                  1, 1, 1, 1, 1,  # 75
                  6, 5, 5, 5, 5,
                  5, 5,12,11,11,
                  1, 1, 1, 1, 1,
                  3, 3, 3, 3, 4,
                  4, 4,12,11,11,  # 100
                  1, 1, 1, 1, 1,
                  3, 3, 3, 3, 4,
                  4, 4,12,11,11,
                  1, 1, 1, 1, 1,
                  3, 3, 3, 3, 4,  # 125
                  4, 4,12,11,11,
                  2, 2, 2, 2, 2,
                  3, 3, 3, 3, 4,
                  4, 4,13,13,14,
                  2, 2, 2, 2, 2,  # 150
                  3, 3, 3, 3, 4,
                  4, 4,13,13,14,
                  2, 2, 2, 2, 2,
                  3, 3, 3, 3, 4,
                  4, 4,13,13,14,  # 175
                 23,22,19,18,15,
                 22,19,18,15,19,
                 18,15,18,15,15,
                 23,21,19,17,15,
                 21,19,17,15,19,  # 200
                 17,15,17,15,15,
                 24,21,20,17,16,
                 21,20,17,16,20,
                 17,16,17,16,16,
                 16,16,16,16,16,  # 225
                 17,17,17,17,20,
                 20,20,21,21,24,
                 15,15,15,15,15,
                 17,17,17,17,19,
                 19,19,21,21,23,  # 250
                 14,13, 4, 3, 2,
                 13, 4, 3, 2, 4,
                  3, 2, 3, 2, 2,
                 11,11, 4, 3, 1,
                 12, 4, 3, 1, 4,  # 275
                  3, 1, 3, 1, 1,
                 10, 9, 4, 3, 0,
                  9, 4, 3, 0, 4,
                  3, 0, 3, 0, 0,
                 15,15,15,15,15,  # 300
                 18,18,18,18,19,
                 19,19,22,22,23,
                 14,13, 4, 3, 2,
                 13, 4, 3, 2, 4,
                  3, 2, 3, 2, 2,  # 325
                 11,11, 4, 3, 1,
                 12, 4, 3, 1, 4,
                  3, 1, 3, 1, 1,
                 10, 9, 4, 3, 0,
                  9, 4, 3, 0, 4,  # 350
                  3, 0, 3, 0, 0,
                 14,13, 4, 3, 2,
                 13, 4, 3, 2, 4,
                  3, 2, 3, 2, 2,
                 11,11, 4, 3, 1,  # 375
                 12, 4, 3, 1, 4,
                  3, 1, 3, 1, 1,
                 10, 9, 4, 3, 0,
                  9, 4, 3, 0, 4,
                  3, 0, 3, 0, 0,  # 400
                 11,11, 5, 5, 1,
                 12, 5, 5, 1, 5,
                  5, 1, 6, 1, 1,
                 10, 9, 5, 5, 0,
                  9, 5, 5, 0, 5,  # 425
                  5, 0, 6, 0, 0,
                 10, 9, 8, 7, 0,
                  9, 8, 7, 0, 8,
                  7, 0, 7, 0, 0,
                  0, 0, 0, 0, 0,  # 450
                  1, 1, 1, 1, 2,
                  2, 2,23,23,24,
                  0, 0, 0, 0, 0,
                  1, 1, 1, 1, 2,
                  2, 2,22,21,21,  # 475
                  0, 0, 0, 0, 0,
                  1, 1, 1, 1, 2,
                  2, 2,19,19,20,
                  0, 0, 0, 0, 0,
                  1, 1, 1, 1, 2,  # 500
                  2, 2,18,17,17,
                  0, 0, 0, 0, 0,
                  1, 1, 1, 1, 2,
                  2, 2,15,15,16,
                  7, 6, 3, 3, 3,  # 525
                  6, 3, 3, 3, 3,
                  3, 3,22,21,21,
                  7, 5, 3, 3, 3,
                  5, 3, 3, 3, 3,
                  3, 3,19,19,20,  # 550
                  7, 5, 3, 3, 3,
                  5, 3, 3, 3, 3,
                  3, 3,18,17,17,
                  7, 5, 3, 3, 3,
                  5, 3, 3, 3, 3,  # 575
                  3, 3,15,15,16,
                  8, 5, 4, 4, 4,
                  5, 4, 4, 4, 4,
                  4, 4,19,19,20,
                  8, 5, 4, 4, 4,  # 600
                  5, 4, 4, 4, 4,
                  4, 4,18,17,17,
                  8, 5, 4, 4, 4,
                  5, 4, 4, 4, 4,
                  4, 4,15,15,16,  # 625
                  9, 9, 9, 9, 9,
                 12,12,12,12,13,
                 13,13,18,17,17,
                  9, 9, 9, 9, 9,
                 11,11,11,11,13,  # 650
                 13,13,15,15,16,
                 10,10,10,10,10,
                 11,11,11,11,14,
                 14,14,15,15,16,
                 16,15,14,11,10,  # 675
                 15,14,11,10,14,
                 11,10,11,10,10,
                 16,15,13,11, 9,
                 15,13,11, 9,13,
                 11, 9,11, 9, 9,  # 700
                 16,15, 4, 4, 4,
                 15, 4, 4, 4, 4,
                  4, 4, 5, 5, 8,
                 16,15, 3, 3, 3,
                 15, 3, 3, 3, 3,  # 725
                  3, 3, 5, 5, 7,
                 16,15, 2, 1, 0,
                 15, 2, 1, 0, 2,
                  1, 0, 1, 0, 0,
                 17,17,13,12, 9,  # 750
                 18,13,12, 9,13,
                 12, 9,12, 9, 9,
                 17,17, 4, 4, 4,
                 18, 4, 4, 4, 4,
                  4, 4, 5, 5, 8,  # 775
                 17,17, 3, 3, 3,
                 18, 3, 3, 3, 3,
                  3, 3, 5, 5, 7,
                 17,17, 2, 1, 0,
                 18, 2, 1, 0, 2,  # 800
                  1, 0, 1, 0, 0,
                 20,19, 4, 4, 4,
                 19, 4, 4, 4, 4,
                  4, 4, 5, 5, 8,
                 20,19, 3, 3, 3,  # 825
                 19, 3, 3, 3, 3,
                  3, 3, 5, 5, 7,
                 20,19, 2, 1, 0,
                 19, 2, 1, 0, 2,
                  1, 0, 1, 0, 0,  # 850
                 21,21, 3, 3, 3,
                 22, 3, 3, 3, 3,
                  3, 3, 6, 6, 7,
                 21,21, 2, 1, 0,
                 22, 2, 1, 0, 2,  # 875
                  1, 0, 1, 0, 0,
                 24,23, 2, 1, 0,
                 23, 2, 1, 0, 2,
                  1, 0, 1, 0, 0);
my @max_digit = ( 0, 7, 8, 9,10,  # 0
                  7, 8, 9,10, 8,
                  9,10, 9,10,10,
                  1, 7, 8,12,12,
                  7, 8,12,12, 8,
                 12,12,12,12,11,  # 25
                  2, 7, 8,13,14,
                  7, 8,13,14, 8,
                 13,14,13,14,14,
                 23,23,23,23,23,
                 22,22,22,22,19,  # 50
                 19,19,18,18,15,
                 24,24,24,24,24,
                 22,22,22,22,20,
                 20,20,18,18,16,
                  1, 6, 6,12,12,  # 75
                  6, 6,12,12, 5,
                 12,12,12,12,11,
                  2, 6, 6,13,14,
                  6, 6,13,14, 5,
                 13,14,13,14,14,  # 100
                 23,23,23,23,23,
                 22,22,22,22,19,
                 19,19,18,18,15,
                 24,24,24,24,24,
                 22,22,22,22,20,  # 125
                 20,20,18,18,16,
                  2, 3, 4,13,14,
                  3, 4,13,14, 4,
                 13,14,13,14,14,
                 23,23,23,23,23,  # 150
                 22,22,22,22,19,
                 19,19,18,18,15,
                 24,24,24,24,24,
                 22,22,22,22,20,
                 20,20,18,18,16,  # 175
                 23,23,23,23,23,
                 22,22,22,22,19,
                 19,19,18,18,15,
                 24,24,24,24,24,
                 22,22,22,22,20,  # 200
                 20,20,18,18,16,
                 24,24,24,24,24,
                 21,21,21,21,20,
                 20,20,17,17,16,
                 16,17,20,21,24,  # 225
                 17,20,21,24,20,
                 21,24,21,24,24,
                 16,18,20,22,24,
                 18,20,22,24,20,
                 22,24,22,24,24,  # 250
                 16,18,20,22,24,
                 18,20,22,24,20,
                 22,24,22,24,24,
                 16,18,20,22,24,
                 18,20,22,24,20,  # 275
                 22,24,22,24,24,
                 16,18,20,22,24,
                 18,20,22,24,20,
                 22,24,22,24,24,
                 15,18,19,22,23,  # 300
                 18,19,22,23,19,
                 22,23,22,23,23,
                 15,18,19,22,23,
                 18,19,22,23,19,
                 22,23,22,23,23,  # 325
                 15,18,19,22,23,
                 18,19,22,23,19,
                 22,23,22,23,23,
                 15,18,19,22,23,
                 18,19,22,23,19,  # 350
                 22,23,22,23,23,
                 14,14,14,14,14,
                 13,13,13,13, 4,
                  4, 4, 3, 3, 2,
                 14,14,14,14,14,  # 375
                 13,13,13,13, 5,
                  6, 6, 6, 6, 2,
                 14,14,14,14,14,
                 13,13,13,13, 8,
                  8, 8, 7, 7, 2,  # 400
                 11,12,12,12,12,
                 12,12,12,12, 5,
                  6, 6, 6, 6, 1,
                 11,12,12,12,12,
                 12,12,12,12, 8,  # 425
                  8, 8, 7, 7, 1,
                 10,10,10,10,10,
                  9, 9, 9, 9, 8,
                  8, 8, 7, 7, 0,
                  0, 1, 2,23,24,  # 450
                  1, 2,23,24, 2,
                 23,24,23,24,24,
                  7, 7, 7,23,24,
                  6, 6,23,24, 3,
                 23,24,23,24,24,  # 475
                  8, 8, 8,23,24,
                  6, 6,23,24, 4,
                 23,24,23,24,24,
                  9,12,13,23,24,
                 12,13,23,24,13,  # 500
                 23,24,23,24,24,
                 10,12,14,23,24,
                 12,14,23,24,14,
                 23,24,23,24,24,
                  7, 7, 7,22,22,  # 525
                  6, 6,22,22, 3,
                 22,22,22,22,21,
                  8, 8, 8,22,22,
                  6, 6,22,22, 4,
                 22,22,22,22,21,  # 550
                  9,12,13,22,22,
                 12,13,22,22,13,
                 22,22,22,22,21,
                 10,12,14,22,22,
                 12,14,22,22,14,  # 575
                 22,22,22,22,21,
                  8, 8, 8,19,20,
                  5, 5,19,20, 4,
                 19,20,19,20,20,
                  9,12,13,19,20,  # 600
                 12,13,19,20,13,
                 19,20,19,20,20,
                 10,12,14,19,20,
                 12,14,19,20,14,
                 19,20,19,20,20,  # 625
                  9,12,13,18,18,
                 12,13,18,18,13,
                 18,18,18,18,17,
                 10,12,14,18,18,
                 12,14,18,18,14,  # 650
                 18,18,18,18,17,
                 10,11,14,15,16,
                 11,14,15,16,14,
                 15,16,15,16,16,
                 16,16,16,16,16,  # 675
                 15,15,15,15,14,
                 14,14,11,11,10,
                 17,18,18,18,18,
                 18,18,18,18,14,
                 14,14,12,12,10,  # 700
                 20,20,20,20,20,
                 19,19,19,19,14,
                 14,14,12,12,10,
                 21,22,22,22,22,
                 22,22,22,22,14,  # 725
                 14,14,12,12,10,
                 24,24,24,24,24,
                 23,23,23,23,14,
                 14,14,12,12,10,
                 17,18,18,18,18,  # 750
                 18,18,18,18,13,
                 13,13,12,12, 9,
                 20,20,20,20,20,
                 19,19,19,19,13,
                 13,13,12,12, 9,  # 775
                 21,22,22,22,22,
                 22,22,22,22,13,
                 13,13,12,12, 9,
                 24,24,24,24,24,
                 23,23,23,23,13,  # 800
                 13,13,12,12, 9,
                 20,20,20,20,20,
                 19,19,19,19, 4,
                  5, 8, 5, 8, 8,
                 21,22,22,22,22,  # 825
                 22,22,22,22, 4,
                  6, 8, 6, 8, 8,
                 24,24,24,24,24,
                 23,23,23,23, 4,
                  6, 8, 6, 8, 8,  # 850
                 21,22,22,22,22,
                 22,22,22,22, 3,
                  6, 7, 6, 7, 7,
                 24,24,24,24,24,
                 23,23,23,23, 3,  # 875
                  6, 7, 6, 7, 7,
                 24,24,24,24,24,
                 23,23,23,23, 2,
                  2, 2, 1, 1, 0);
# state length 100 in each of 4 tables = 400
# min/max 2 of 900 each = 1800

sub n_to_xy {
  my ($self, $n) = @_;
  ### CincoCurve n_to_xy(): $n

  if ($n < 0) { return; }
  if (is_infinite($n)) { return ($n,$n); }

  my $int = int($n);
  $n -= $int;  # fraction part

  my @digits = digit_split_lowtohigh($int,25);
  my $len = ($int*0 + 5) ** scalar(@digits);  # inherit bignum

  ### digits: join(', ',@digits)."   count ".scalar(@digits)
  ### $len

  my $state = my $dir = 0;
  my $x = 0;
  my $y = 0;

  while (defined (my $digit = pop @digits)) {
    $len /= 5;
    $state += $digit;
    if ($digit != 24) {
      $dir = $state;
    }

    ### $len
    ### $state
    ### digit_to_x: $digit_to_x[$state]
    ### digit_to_y: $digit_to_y[$state]
    ### next_state: $next_state[$state]

    $x += $len * $digit_to_x[$state];
    $y += $len * $digit_to_y[$state];
    $state = $next_state[$state];
  }

  ### final integer: "$x,$y"
  ### assert: ($dir % 25) != 24

  # with $n fractional part
  return ($n * ($digit_to_x[$dir+1] - $digit_to_x[$dir]) + $x,
          $n * ($digit_to_y[$dir+1] - $digit_to_y[$dir]) + $y);
}

sub xy_to_n {
  my ($self, $x, $y) = @_;
  ### CincoCurve xy_to_n(): "$x, $y"

  $x = round_nearest ($x);
  $y = round_nearest ($y);
  if ($x < 0 || $y < 0) {
    return undef;
  }
  if (is_infinite($x)) {
    return $x;
  }
  if (is_infinite($y)) {
    return $y;
  }

  my @xdigits = digit_split_lowtohigh ($x, 5);
  my @ydigits = digit_split_lowtohigh ($y, 5);
  my $state = 0;
  my @ndigits;

  foreach my $i (reverse 0 .. max($#xdigits,$#ydigits)) {  # high to low
    my $ndigit = $yx_to_digit[$state
                              + 5*($ydigits[$i]||0)
                              + ($xdigits[$i]||0)];
    $ndigits[$i] = $ndigit;
    $state = $next_state[$state+$ndigit];
  }

  return digit_join_lowtohigh (\@ndigits, 25,
                               $x * 0 * $y); # bignum zero
}

# exact
sub rect_to_n_range {
  my ($self, $x1,$y1, $x2,$y2) = @_;
  ### BetaOmega rect_to_n_range(): "$x1,$y1, $x2,$y2"

  $x1 = round_nearest ($x1);
  $x2 = round_nearest ($x2);
  $y1 = round_nearest ($y1);
  $y2 = round_nearest ($y2);
  ($x1,$x2) = ($x2,$x1) if $x1 > $x2;
  ($y1,$y2) = ($y2,$y1) if $y1 > $y2;

  if ($x2 < 0 || $y2 < 0) {
    return (1, 0);
  }
  if ($x1 < 0) { $x1 *= 0; }   # "*=" to preserve bigint x1 or y1
  if ($y1 < 0) { $y1 *= 0; }

  my ($len, $level) = round_down_pow (($x2 > $y2 ? $x2 : $y2),
                                      5);
  if (is_infinite($len)) {
    return (0, $len);
  }

  # At this point an over-estimate would be:  return (0, 25*$len*$len-1);


  my $n_min = my $n_max
    = my $y_min = my $y_max
      = my $x_min = my $x_max
        = my $min_state = my $max_state
          = 0;
  ### $x_min
  ### $y_min

  while ($level >= 0) {
    ### $level
    ### $len
    {
      my $digit = $min_digit[9*$min_state
                             + _rect_key($x1, $x2, $x_min, $len) * 15
                             + _rect_key($y1, $y2, $y_min, $len)];

      ### $min_state
      ### $x_min
      ### $y_min
      ### $digit

      $n_min = 25*$n_min + $digit;
      $min_state += $digit;
      $x_min += $len * $digit_to_x[$min_state];
      $y_min += $len * $digit_to_y[$min_state];
      $min_state = $next_state[$min_state];
    }
    {
      my $digit = $max_digit[9*$max_state
                             + _rect_key($x1, $x2, $x_max, $len) * 15
                             + _rect_key($y1, $y2, $y_max, $len)];

      $n_max = 25*$n_max + $digit;
      $max_state += $digit;
      $x_max += $len * $digit_to_x[$max_state];
      $y_max += $len * $digit_to_y[$max_state];
      $max_state = $next_state[$max_state];
    }

    $len = int($len/5);
    $level--;
  }

  return ($n_min, $n_max);
}

sub _rect_key {
  my ($z1, $z2, $zbase, $len) = @_;
  $z1 = max (0, min (4, int (($z1 - $zbase)/$len)));
  $z2 = max (0, min (4, int (($z2 - $zbase)/$len)));
  ### assert: $z1 <= $z2
  return (9-$z1)*$z1/2 + $z2;
}

#------------------------------------------------------------------------------
# levels

use Math::PlanePath::DekkingCentres;
*level_to_n_range = \&Math::PlanePath::DekkingCentres::level_to_n_range;
*n_to_level = \&Math::PlanePath::DekkingCentres::n_to_level;


#------------------------------------------------------------------------------
1;
__END__

=for stopwords eg Ryde ie CincoCurve Math-PlanePath Cinco COSIM

=head1 NAME

Math::PlanePath::CincoCurve -- 5x5 self-similar curve

=head1 SYNOPSIS

 use Math::PlanePath::CincoCurve;
 my $path = Math::PlanePath::CincoCurve->new;
 my ($x, $y) = $path->n_to_xy (123);

=head1 DESCRIPTION

X<Dennis, John>This is the 5x5 self-similar Cinco curve

=over

John Dennis, "Inverse Space-Filling Curve Partitioning of a Global Ocean
Model", and source code from COSIM

L<http://www.cecs.uci.edu/~papers/ipdps07/pdfs/IPDPS-1569010963-paper-2.pdf>

L<http://oceans11.lanl.gov/trac/POP/browser/trunk/pop/source/spacecurve_mod.F90>,
L<http://oceans11.lanl.gov/svn/POP/trunk/pop/source/spacecurve_mod.F90>

=back

It makes a 5x5 self-similar traversal of the first quadrant XE<gt>0,YE<gt>0.

                                                    |
      4  |  10--11  14--15--16  35--36  39--40--41  74  71--70  67--66
         |   |   |   |       |   |   |   |       |   |   |   |   |   |
      3  |   9  12--13  18--17  34  37--38  43--42  73--72  69--68  65
         |   |           |       |           |                       |
      2  |   8   5-- 4  19--20  33  30--29  44--45  52--53--54  63--64
         |   |   |   |       |   |   |   |       |   |       |   |
      1  |   7-- 6   3  22--21  32--31  28  47--46  51  56--55  62--61
         |           |   |               |   |       |   |           |
    Y=0  |   0-- 1-- 2  23--24--25--26--27  48--49--50  57--58--59--60
         |
         +--------------------------------------------------------------
            X=0  1   2   3   4   5   6   7   8   9  10  11  12  13  14

The base pattern is the N=0 to N=24 part.  It repeats transposed and rotated
to make the ends join.  N=25 to N=49 is a repeat of the base, then N=50 to
N=74 is a transpose to go upwards.  The sub-part arrangements are as
follows.

    +------+------+------+------+------+
    |  10  |  11  |  14  |  15  |  16  |
    |      |      |      |      |      |
    |----->|----->|----->|----->|----->|
    +------+------+------+------+------+
    |^  9  |  12 ||^ 13  |  18 ||<-----|
    ||  T  |  T  |||  T  |  T  ||  17  |
    ||     |     v||     |     v|      |
    +------+------+------+------+------+
    |^  8  |  5  ||^  4  |  19 ||  20  |
    ||  T  |  T  |||  T  |  T  ||      |
    ||     |     v||     |     v|----->|
    +------+------+------+------+------+
    |<-----|<---- |^  3  |  22 ||<-----|
    |  7   |  6   ||  T  |  T  ||  21  |
    |      |      ||     |     v|      |
    +------+------+------+------+------+
    |  0   |  1   |^  2  |  23 ||  24  |
    |      |      ||  T  |  T  ||      |
    |----->|----->||     |     v|----->|
    +------+------+------+------+------+

Parts such as 6 going left are the base rotated 180 degrees.  The verticals
like 2 are a transpose of the base, ie. swap X,Y, and downward vertical like
23 is transpose plus rotate 180 (which is equivalent to a mirror across the
anti-diagonal).  Notice the base shape fills its sub-part to the left side
and the transpose instead fills on the right.

The N values along the X axis are increasing, as are the values along the Y
axis.  This occurs because the values along the sub-parts of the base are
increasing along the X and Y axes, and the other two sides are increasing
too when rotated or transposed for sub-parts such as 2 and 23, or 7, 8
and 9.

Dennis conceives this for use in combination with 2x2 Hilbert and 3x3
meander shapes so that sizes which are products of 2, 3 and 5 can be used
for partitioning.  Such mixed patterns can't be done with the code here,
mainly since a mixture depends on having a top-level target size rather than
the unlimited first quadrant here.

=head1 FUNCTIONS

See L<Math::PlanePath/FUNCTIONS> for behaviour common to all path classes.

=over 4

=item C<$path = Math::PlanePath::CincoCurve-E<gt>new ()>

Create and return a new path object.

=item C<($x,$y) = $path-E<gt>n_to_xy ($n)>

Return the X,Y coordinates of point number C<$n> on the path.  Points begin
at 0 and if C<$n E<lt> 0> then the return is an empty list.

=back

=head2 Level Methods

=over

=item C<($n_lo, $n_hi) = $path-E<gt>level_to_n_range($level)>

Return C<(0, 25**$level - 1)>.

=back

=head1 SEE ALSO

L<Math::PlanePath>,
L<Math::PlanePath::PeanoCurve>,
L<Math::PlanePath::DekkingCentres>

=head1 HOME PAGE

L<http://user42.tuxfamily.org/math-planepath/index.html>

=head1 LICENSE

Copyright 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020 Kevin Ryde

Math-PlanePath is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation; either version 3, or (at your option) any later
version.

Math-PlanePath is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
more details.

You should have received a copy of the GNU General Public License along with
Math-PlanePath.  If not, see <http://www.gnu.org/licenses/>.

=cut
