package Sim::OPT::Stats;
# This is the module Sim::OPT::Stats of Sim::OPT.
# Copyright (C) 2008-2025 by Gian Luca Brunetti, gianluca.brunetti@gmail.com. This software is distributed under a dual licence, open-source (GPL v3) and proprietary. The present copy is GPL. By consequence, this is free software.  You can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3.
# This software is distributed under a dual licence, open-source (GPL v3) and proprietary.
# The present copy is proprietary. The open-source, GPL version of it can be found at
# https://metacpan.org/dist/Sim-OPT.

use Sim::OPT;
use Sim::OPT::Morph;
use Sim::OPT::Sim;
use Sim::OPT::Report;
use Sim::OPT::Descend;
use Sim::OPT::Takechance;
use Sim::OPT::Interlinear;
use Sim::OPT::Parcoord3d;

eval { use Sim::OPTcue::OPTcue; 1 };
eval { use Sim::OPTcue::Metabridge; 1 };
eval { use Sim::OPTcue::Exogen::PatternSearch; 1 };
eval { use Sim::OPTcue::Exogen::NelderMead; 1 };
eval { use Sim::OPTcue::Exogen::Armijo; 1 };
eval { use Sim::OPTcue::Exogen::NSGAII; 1 };
eval { use Sim::OPTcue::Exogen::ParticleSwarm; 1 };
eval { use Sim::OPTcue::Exogen::SimulatedAnnealing; 1 };
eval { use Sim::OPTcue::Exogen::NSGAIII; 1 };
eval { use Sim::OPTcue::Exogen::MOEAD; 1 };
eval { use Sim::OPTcue::Exogen::SPEA2; 1 };
eval { use Sim::OPTcue::Exogen::ParticleSwarm; 1 };
eval { use Sim::OPTcue::Exogen::RadialBasis; 1 };
eval { use Sim::OPTcue::Exogen::Kriging; 1 };
eval { use Sim::OPTcue::Exogen::DecisionTree; 1 };
eval { use Sim::OPTcue::Exogen::KNN; 1 };
eval { use Sim::OPTcue::Exogen::FFNN; 1 };
eval { use Sim::OPTcue::Exogen::GBDT; 1 };
eval { use Sim::OPTcue::Endogen::DWGN2; 1 };
eval { use Sim::OPTcue::Endogen::NeuralBoltzmann; 1 };

use Exporter qw();
our @ISA = qw(Exporter);
our $stats = bless( {}, "Sim::OPT::Stats" );
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

sub import 
{
  my ( $class, @args ) = @_;
  my @export_args;
    for my $a (@args) 
    {
      if ($a eq 'unbias')         
      { 
        $UNBIAS = 1; next; 
      }

      if ($a =~ /^unbias=(0|1)$/) 
      { 
        $UNBIAS = $1; next; 
      }
    push( @export_args, $a );
  }
  Exporter::import( $class, @export_args );
}

no strict;
no warnings;

use Carp ();

use Scalar::Util ();
use List::Util ();


our $UNBIAS = 0;

our @EXPORT_OK = qw( 
    vector mean average avg median variance var stddev
    covariance cov correlation cor corr
);

################################################

sub _as_vector 
{
    my $input = $_[0];
    if ( Scalar::Util::blessed($input) ) 
    {
        if ($input->isa('Sim::OPT::Stats::Vector')) 
        {
            return( $input );
        }
    }

    my $argument_count = @_;
    if ($argument_count == 0) 
    {
        return Sim::OPT::Stats::Vector->new([]);
    }

    if ($argument_count == 1) 
    {
        if (ref($input) eq 'ARRAY') 
        {
            return Sim::OPT::Stats::Vector->new($input);
        }
    }


    my @all_arguments = @_;
    return Sim::OPT::Stats::Vector->new([ @all_arguments ]);
}

sub _as_two_vectors 
{
    my ($first_item, $second_item) = @_;
    my $vec1 = _as_vector($first_item);
    my $vec2 = _as_vector($second_item);
    return ($vec1, $vec2);
}



sub vector  
{ 
  return( _as_vector( @_ ) ); 
}

sub mean 
{ 
    my $vec = _as_vector(@_);
    return( Sim::OPT::Stats::Mean->new($vec) ); 
}
sub average 
{ 
  return( mean(@_) ); 
}

sub avg 
{ 
  return( mean(@_) ); 
}

sub median 
{ 
    my $vec = _as_vector(@_);
    return( Sim::OPT::Stats::Median->new($vec) ); 
}

sub variance 
{ 
    my $vec = _as_vector(@_);
    return( Sim::OPT::Stats::Variance->new($vec) ); 
}

sub var 
{ 
  return( variance(@_) ); 
}

sub stddev 
{ 
    my $vec = _as_vector(@_);
    return( Sim::OPT::Stats::StdDev->new($vec) ); 
}

sub covariance 
{
    my ($v1, $v2) = _as_two_vectors(@_);
    return( Sim::OPT::Stats::Covariance->new($v1, $v2) );
}
sub cov 
{ 
  return( covariance(@_) ); 
}

sub correlation 
{
    my ($v1, $v2) = _as_two_vectors(@_);
    return( Sim::OPT::Stats::Correlation->new($v1, $v2) );
}
sub cor  
{ 
  return( correlation(@_) ); 
}

sub corr 
{ 
  return( correlation(@_) ); 
}


############################################

package Sim::OPT::Stats::Vector;

sub new 
{
    my ($class, $aref) = @_;
    
    if ( !defined( $aref ) ) 
    {
        $aref = [];
    }

    if (ref($aref) ne 'ARRAY') 
    {
        Carp::croak("Vector->new expects an ARRAY ref");
    }

    my @copy = @{$aref};
    my $self = 
    {
        data => [ @copy ]
    };

    return( bless $self, $class );
}

sub query 
{
    my ($self) = @_;
    my $data_list_ref = $self->{data};

    if (wantarray) 
    {
        return( @{ $data_list_ref } );
    }
    else 
    {
        return( $data_list_ref );
    }
}

sub size 
{
    my ($self) = @_;
    my @elements = @{ $self->{data} };
    return( scalar @elements );
}

sub as_arrayref 
{
    my ($self) = @_;
    my @copy = @{ $self->{data} };
    return( [ @copy ] );
}

sub as_string 
{
    my ($self) = @_;
    my @elements = @{ $self->{data} };
    my $joined = join(', ', @elements);
    return( '[' . $joined . ']' );
}


######################################

package Sim::OPT::Stats::Mean;
our @ISA = ('Sim::OPT::Stats::_Base');

sub query 
{
    my ($self) = @_;
    my @numbers = $self->{v}->query();
    my $count = @numbers;

    if ($count == 0) {
        return( 0 );
    }

    my $sum = 0;
    foreach my $n (@numbers) 
    {
        $sum = $sum + $n;
    }

    return( $sum / $count );
}


###############################################

package Sim::OPT::Stats::Median;
our @ISA = ('Sim::OPT::Stats::_Base');

sub query 
{
    my ($self) = @_;
    my @numbers = $self->{v}->query();
    my $count = @numbers;

    if ($count == 0) 
    {
        return 0;
    }

    my @sorted = sort { $a <=> $b } @numbers;
    my $middle_index = int($count / 2);

    if ($count % 2 != 0) 
    {
        return $sorted[$middle_index];
    }

    else {
        my $lower = $sorted[$middle_index - 1];
        my $upper = $sorted[$middle_index];
        return( ($lower + $upper) / 2 );
    }
}


##################################################

package Sim::OPT::Stats::Variance;

our @ISA = ('Sim::OPT::Stats::_Base');

sub query {
    my ($self) = @_;
    my @numbers = $self->{v}->query();
    my $n = @numbers;

    if ($n == 0) 
    { 
      return( 0 ); 
    }

    my $total = 0;
    foreach my $val (@numbers) 
    { 
      $total += $val; 
    }

    my $mean = ( $total / $n );

    my $sum_sq_diff = 0;
    foreach my $xi (@numbers) 
    {
        my $diff = $xi - $mean;
        $sum_sq_diff += ($diff * $diff);
    }

    my $divisor = $n;
    if ($Sim::OPT::Stats::UNBIAS) 
    {
        if ($n < 2) 
        { 
          return( 0 ); 
        }
        $divisor = $n - 1;
    }

    return( $sum_sq_diff / $divisor );
}


######################################

package Sim::OPT::Stats::Covariance;

our @ISA = ('Sim::OPT::Stats::_BinaryBase');

sub query 
{
    my ($self) = @_;
    my @x = $self->{v1}->query();
    my @y = $self->{v2}->query();
    my $n = @x;

    # Basic safety check
    if ( ( $n == 0 ) or ( @y != $n ) ) 
    {
        return( 0 );
    }

    # Get means
    my $sum_x = 0; foreach (@x) 
    { 
      $sum_x += $_; 
    }

    my $sum_y = 0; foreach (@y) 
    { 
      $sum_y += $_; 
    }

    my $mean_x = $sum_x / $n;
    my $mean_y = $sum_y / $n;

    my $sum_product = 0;
    for (my $i = 0; $i < $n; $i++) 
    {
        my $diff_x = $x[$i] - $mean_x;
        my $diff_y = $y[$i] - $mean_y;
        $sum_product += ($diff_x * $diff_y);
    }

    my $divisor = $n;
    if ($Sim::OPT::Stats::UNBIAS) 
    {
        if ($n < 2) { return 0; }
        $divisor = $n - 1;
    }
    return( $sum_product / $divisor );
}


1;
