=head1 NAME

PDL::Graphics::TriD::Contours - 3D Surface contours for TriD

=head1 SYNOPSIS

=for usage

    # A simple contour plot in black and white

    use PDL::Graphics::TriD;
    use PDL::Graphics::TriD::Contours;
    $size = 25;
    $x = (xvals zeroes $size,$size) / $size;
    $y = (yvals zeroes $size,$size) / $size;
    $z = (sin($x*6.3) * sin($y*6.3)) ** 3;
    $data=PDL::Graphics::TriD::Contours->new($z,
               [$z->xvals/$size,$z->yvals/$size,0]);
    PDL::Graphics::TriD::graph_object($data)

=cut

package PDL::Graphics::TriD::Contours;
use strict;
use warnings;
use PDL;
use PDL::ImageND;
use PDL::Graphics::TriD;
use PDL::Graphics::TriD::Labels;
use base qw/PDL::Graphics::TriD::GObject/;
use fields qw/PathIndex ContourPathIndexEnd Labels LabelStrings/;

$PDL::Graphics::TriD::verbose //= 0;

=head1 FUNCTIONS

=head2 new()

=for ref

Define a new contour plot for TriD.

=for example

  $data=PDL::Graphics::TriD::Contours->new($d,[$x,$y,$z],[$r,$g,$b],$options);

where $d is a 2D pdl of data to be contoured. [$x,$y,$z] define a 3D
map of $d into the visualization space [$r,$g,$b] is an optional [3,1]
ndarray specifying the contour color and $options is a hash reference to
a list of options documented below.  Contours can also be coloured by
value using the set_color_table function.

=for opt

  ContourInt  => 0.7  # explicitly set a contour interval
  ContourMin  => 0.0  # explicitly set a contour minimum
  ContourMax  => 10.0 # explicitly set a contour maximum
  ContourVals => $pdl # explicitly set all contour values
  Label => [1,5,$myfont] # see addlabels below

  If ContourVals is specified ContourInt, ContourMin, and ContourMax
  are ignored.  If no options are specified, the algorithm tries to
  choose values based on the data supplied.

=cut

sub new{
  my($type,$data,$points,$colors,$options) = @_;

  if(! defined $points){
	 $points = [$data->xvals,$data->yvals,$data->zvals];
  }

  if(ref($colors) eq "HASH"){
    $options=$colors ;
    undef $colors;
  }

  $colors = PDL::Graphics::TriD::realcoords("COLOR",pdl[1,1,1]) unless defined $colors;

  my $this = $type->SUPER::new($points,$colors,$options);

  my $fac=1;
  my ($min,$max) = $data->minmax;

  unless(defined $this->{Options}{ContourMin}){
    while($fac*($max-$min)<10){
      $fac*=10;
    }
    $this->{Options}{ContourMin} = int($fac*$min) == $fac*$min ? $min : int($fac*$min+1)/$fac;
    print "ContourMin =  ",$this->{Options}{ContourMin},"\n"
                if $PDL::Graphics::TriD::verbose;
  }
  unless(defined $this->{Options}{ContourMax} &&
			$this->{Options}{ContourMax} > $this->{Options}{ContourMin} ){
    if(defined $this->{Options}{ContourInt}){
      $this->{Options}{ContourMax} = $this->{Options}{ContourMin};
      while($this->{Options}{ContourMax}+$this->{Options}{ContourInt} < $max){
	$this->{Options}{ContourMax}= $this->{Options}{ContourMax}+$this->{Options}{ContourInt};
      }
    }else{
      $this->{Options}{ContourMax} = int($fac*$max) == $fac*$max ? $max : (int($fac*$max)-1)/$fac;
    }
    print "ContourMax =  ",$this->{Options}{ContourMax},"\n"
                if $PDL::Graphics::TriD::verbose;
  }
  unless(defined $this->{Options}{ContourInt} &&  $this->{Options}{ContourInt}>0){
    $this->{Options}{ContourInt} = int($fac*($this->{Options}{ContourMax}-$this->{Options}{ContourMin}))/(10*$fac);
    print "ContourInt =  ",$this->{Options}{ContourInt},"\n"
		if($PDL::Graphics::TriD::verbose);
  }
#
# The user could also name cvals
#
  my $cvals;
  if (!defined($this->{Options}{ContourVals}) || $this->{Options}{ContourVals}->isempty){
    $cvals=zeroes(int(($this->{Options}{ContourMax}-$this->{Options}{ContourMin})/$this->{Options}{ContourInt}+1));
    $cvals = $cvals->xlinvals($this->{Options}{ContourMin},$this->{Options}{ContourMax});
  }else{
    $cvals = $this->{Options}{ContourVals};
    $this->{Options}{ContourMax}=$cvals->max->sclr;
    $this->{Options}{ContourMin}=$cvals->min->sclr;
  }
  $this->{Options}{ContourVals} = $cvals;
  print "Cvals = $cvals\n" if $PDL::Graphics::TriD::verbose;

  my ($pi, $p) = contour_polylines($cvals,$data,$this->{Points});
  $_ = PDL->null for @$this{qw(Points PathIndex)};
  my ($pcnt, $pval) = (0,0);
  for (my $i=0; $i<$cvals->nelem; $i++) {
    my $this_pi = $pi->slice(",($i)");
    next if $this_pi->at(0) == -1;
    my $thispi_maxind = $this_pi->maximum_ind->sclr;
    $this_pi = $this_pi->slice("0:$thispi_maxind");
    my $thispi_maxval = $this_pi->at($thispi_maxind);
    $this->{PathIndex} = $this->{PathIndex}->append($this_pi+$pval);
    $this->{Points} = $this->{Points}->glue(1,$p->slice(":,0:$thispi_maxval,($i)"));
    $this->{ContourPathIndexEnd}[$i] = $pcnt = $pcnt+$thispi_maxind;
    $pcnt += 1; $pval += $thispi_maxval + 1;
  }

  $this->addlabels($this->{Options}{Labels}) if defined $this->{Options}{Labels};

  return $this;
}

sub get_valid_options{
  return{ ContourInt => undef,
			 ContourMin => undef,
			 ContourMax=>  undef,
			 ContourVals=> pdl->null,
			 UseDefcols=>1,
	                 Labels=> undef}
}

=head2 addlabels()

=for ref

Add labels to a contour plot

=for usage

  $contour->addlabels($labelint,$segint);

$labelint is the integer interval between labeled contours.  If you
have 8 contour levels and specify $labelint=3 addlabels will attempt
to label the 1st, 4th, and 7th contours.  $labelint defaults to 1.

$segint specifies the density of labels on a single contour
level.  Each contour level consists of a number of connected
line segments, $segint defines how many of these segments get labels.
$segint defaults to 5, that is every fifth line segment will be labeled.

=cut

sub addlabels{
  my ($self,$labelint, $segint) = @_;

  $labelint = 1 unless(defined $labelint);
  $segint = 5 unless(defined $segint);

  my $cnt=0;

  my $strlist;
  my $lp=pdl->null;

  my $pcnt = 0;
  my $offset = pdl[0.5,0.5,0.5];

  for(my $i=0; $i<= $#{$self->{ContourSegCnt}}; $i++){
    next unless defined $self->{ContourSegCnt}[$i];
    $cnt = $self->{ContourSegCnt}[$i];
    my $val = $self->{Options}{ContourVals}->slice("($i)");

    my $leg =  $self->{Points}->slice(":,$pcnt:$cnt");
    $pcnt=$cnt+1;

    next if($i % $labelint);

    for(my $j=0; $j< $leg->getdim(1); $j+=2){
      next if(($j/2) % $segint);

		my $j1=$j+1;

      my $lp2 = $leg->slice(":,($j)") +
                $offset*($leg->slice(":,($j1)") -
					  $leg->slice(":,($j)"));


		$lp = $lp->append($lp2);
# need a label string for each point
		push(@$strlist,$val);

	 }

  }
  if($lp->nelem>0){
	 $self->{Points} = $self->{Points}->transpose
		->append($lp->reshape(3,$lp->nelem/3)->transpose)->transpose;
	 $self->{Labels} = [$cnt+1,$cnt+$lp->nelem/3];
	 $self->{LabelStrings} = $strlist;
  }

}

=head2 set_colortable($table)

=for ref

Sets contour level colors based on the color table.

=for usage

$table is passed in as either an ndarray of [3,n] colors, where n is the
number of contour levels, or as a reference to a function which
expects the number of contour levels as an argument and returns a
[3,n] ndarray.  It should be straight forward to use the
L<PDL::Graphics::LUT> tables in a function which subsets the 256
colors supplied by the look up table into the number of colors needed
by Contours.

=cut

sub set_colortable{
  my($self,$table) = @_;
  my $colors;
  if(ref($table) eq "CODE"){
	 my $min = $self->{Options}{ContourMin};
	 my $max = $self->{Options}{ContourMax};
	 my $int = $self->{Options}{ContourInt};
	 my $ncolors=($max-$min)/$int+1;
	 $colors= &$table($ncolors);
  }else{
	 $colors = $table;
  }

  if($colors->getdim(0)!=3){
    $colors->reshape(3,$colors->nelem/3);
  }
  print "Color info ",$self->{Colors}->info," ",$colors->info,"\n" if($PDL::Graphics::TriD::verbose);

  $self->{Colors} = $colors;
}

=head2 coldhot_colortable()

=for ref

A simple colortable function for use with the set_colortable function.

=for usage

coldhot_colortable defines a blue red spectrum of colors where the
smallest contour value is blue, the highest is red and the others are
shades in between.

=cut

sub coldhot_colortable{
  my($ncolors) = @_;
  my $colorpdl;
  # 0 red, 1 green, 2 blue
  for(my $i=0;$i<$ncolors;$i++){
    my $color = zeroes(float,3);
    (my $t = $color->slice("0")) .= 0.75*($i)/$ncolors;
    ($t = $color->slice("2")) .= 0.75*($ncolors-$i)/$ncolors;
    if($i==0){
      $colorpdl = $color;
    }else{
      $colorpdl = $colorpdl->append($color);
    }
  }
  return $colorpdl;
}

1;
