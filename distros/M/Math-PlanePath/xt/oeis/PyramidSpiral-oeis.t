#!/usr/bin/perl -w

# Copyright 2010, 2011, 2012, 2013, 2018, 2020, 2021 Kevin Ryde

# This file is part of Math-PlanePath.
#
# Math-PlanePath is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 3, or (at your option) any later
# version.
#
# Math-PlanePath is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License along
# with Math-PlanePath.  If not, see <http://www.gnu.org/licenses/>.


# A217295 Permutation of natural numbers arising from applying the walk of triangular horizontal-last spiral (defined in A214226) to the data of square spiral (e.g. A214526).
# A214227 -- sum of 4 neighbours horizontal-last


use 5.004;
use strict;
use Test;
plan tests => 6;

use lib 't','xt';
use MyTestHelpers;
BEGIN { MyTestHelpers::nowarnings(); }
use MyOEIS;

use Math::PlanePath::PyramidSpiral;
use Math::PlanePath::SquareSpiral;
use Math::NumSeq::PlanePathTurn;



#------------------------------------------------------------------------------
# A217013 - permutation, SquareSpiral -> PyramidSpiral
#   X,Y in SquareSpiral order, N of PyramidSpiral
# A217294 - inverse

{
  my $pyramid = Math::PlanePath::PyramidSpiral->new;
  my $square  = Math::PlanePath::SquareSpiral->new;

  # N= 1  2   3  4  5  6  7  8   9  10
  #    1, 3, 14, 4, 6, 7, 8, 2, 12, 30, 13, 32, 59, 33, 15, 5, 19, 20, 21
  MyOEIS::compare_values
      (anum => 'A217013',
       func => sub {
         my ($count) = @_;
         my @got;
         for (my $n = $square->n_start; @got < $count; $n++) {
           my ($x, $y) = $square->n_to_xy($n);
           ($x,$y) = (-$y,$x);  # rotate +90
           push @got, $pyramid->xy_to_n($x,$y);
         }
         return \@got;
       });
  # N= 1  2  3  4  5  6  7  8   9  10
  #    1, 8, 2, 4, 16, 5, 6, 7, 22, 45, 23, 9, 11, 3, 15, 35, 63, 36, 17
  MyOEIS::compare_values
      (anum => 'A217294',
       func => sub {
         my ($count) = @_;
         my @got;
         for (my $n = $pyramid->n_start; @got < $count; $n++) {
           my ($x,$y) = $pyramid->n_to_xy($n);
           ($x,$y) = ($y,-$x);  # rotate -90
           push @got, $square->xy_to_n ($x,$y);
         }
         return \@got;
       });

  # Different side lengths by horizontal long side at different phase ...
  #
  # side lengths 1,3,2,3,7,4           1,1,2,5,3,4,9
  #        picture A214226             PyramidSpiral
  #               21                         13
  #              /  \                       /  \ 
  #            20  7 22                   14  3 12
  #           /  /   \ \                 /  /  \  \
  #         19  6  1  8                15  4  1--2 11
  #        /  /     \   \             /  /           \
  #      18  5--4--3--2  9          16  5--6--7--8--9-10
  #     /                 \        /                        \
  #   17 16 15 14 13 12 11 10    17-18-19-20-21-22-23-24-25-26 51
  #
  # N= 1  2   3  4  5  6  7  8   9  10
  #    1, 7, 22, 8, 2, 3, 4, 6, 20, 42, 21, 44, 75, 45, 23, 9, 11, 12, 13
  # square spiral order, upward first, clockwise
}


#------------------------------------------------------------------------------
# A329116 - X coordinate

MyOEIS::compare_values
  (anum => 'A329116',  # OFFSET=0
   func => sub {
     my ($count) = @_;
     my @got;
     my $path = Math::PlanePath::PyramidSpiral->new (n_start => 0);
     for (my $n = 0; @got < $count; $n++) {
       my ($x,$y) = $path->n_to_xy($n);
       push @got, $x;
     }
     return \@got;
   });

# A329972 - Y coordinate
MyOEIS::compare_values
  (anum => 'A329972',  # OFFSET=0
   func => sub {
     my ($count) = @_;
     my @got;
     my $path = Math::PlanePath::PyramidSpiral->new (n_start => 0);
     for (my $n = 0; @got < $count; $n++) {
       my ($x,$y) = $path->n_to_xy($n);
       push @got, $y;
     }
     return \@got;
   });

# A053615 -- abs(X) distance to pronic
MyOEIS::compare_values
  (anum => 'A053615',  # OFFSET=0
   func => sub {
     my ($count) = @_;
     my $path = Math::PlanePath::PyramidSpiral->new (n_start => 0);
     my @got;
     for (my $n = 0; @got < $count; $n++) {
       my ($x, $y) = $path->n_to_xy ($n);
       push @got, abs($x);
     }
     return \@got;
   });


#------------------------------------------------------------------------------
# A080037 -- N positions not straight ahead
# not in OEIS: 13,17,26,31,37,50,57,65,82,91,101,122,133,145,170

# MyOEIS::compare_values
#   (anum => 'A999999',
#    func => sub {
#      my ($count) = @_;
#      my @got;
#      my $seq = Math::NumSeq::PlanePathTurn->new (planepath => 'PyramidSpiral',
#                                                  turn_type => 'Straight');
#      while (@got < $count) {
#        my ($i,$value) = $seq->next;
#        if (! $value) { push @got, $i; }
#      }
#      return \@got;
#    });


#------------------------------------------------------------------------------
# A217294 - permutation PyramidSpiral -> SquareSpiral
#   X,Y in PyramidSpiral order, N of SquareSpiral
#   but A217294 conceived by square spiral going up and clockwise
#                        and pyramid spiral going left and clockwise
#     which means rotate -90 here

MyOEIS::compare_values
  (anum => 'A217294',
   func => sub {
     my ($count) = @_;
     require Math::PlanePath::SquareSpiral;
     my $pyramid = Math::PlanePath::PyramidSpiral->new;
     my $square  = Math::PlanePath::SquareSpiral->new;
     my @got;
     for (my $n = $pyramid->n_start; @got < $count; $n++) {
       my ($x, $y) = $pyramid->n_to_xy($n);
       ($x,$y) = ($y,-$x);  # rotate -90
       push @got, $square->xy_to_n($x,$y);
     }
     return \@got;
   });


#------------------------------------------------------------------------------
# A214250 -- sum of 8 neighbours N

MyOEIS::compare_values
  (anum => 'A214250',
   func => sub {
     my ($count) = @_;
     my $path = Math::PlanePath::PyramidSpiral->new;
     my @got;
     for (my $n = $path->n_start; @got < $count; $n++) {
       my ($x,$y) = $path->n_to_xy ($n);
       push @got, ($path->xy_to_n($x+1,$y)
                   + $path->xy_to_n($x-1,$y)
                   + $path->xy_to_n($x,$y+1)
                   + $path->xy_to_n($x,$y-1)
                   + $path->xy_to_n($x+1,$y+1)
                   + $path->xy_to_n($x-1,$y-1)
                   + $path->xy_to_n($x-1,$y+1)
                   + $path->xy_to_n($x+1,$y-1)
                  );
     }
     return \@got;
   });

#------------------------------------------------------------------------------
exit 0;
