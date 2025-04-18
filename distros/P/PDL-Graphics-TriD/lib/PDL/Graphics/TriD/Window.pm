# The PDL::Graphics::TriD::Window is already partially defined in
# the appropriate gdriver (GL or VRML) items defined here are common
# to both

package PDL::Graphics::TriD::Window;
use strict;
use warnings;
use PDL::Graphics::TriD::ViewPort;
use Data::Dumper;

$PDL::Graphics::TriD::verbose //= 0;

sub new {
  my($arg,$options) = @_;
  print "PDL::Graphics::TriD::Window - calling SUPER::new...\n" if($PDL::Graphics::TriD::verbose);
  my $this = $arg->SUPER::new();
  print "PDL::Graphics::TriD::Window - got back $this\n" if($PDL::Graphics::TriD::verbose);
  # Make sure the Graphics has been initialized
  $options->{width} =	600 unless defined $options->{width};
  $options->{height} =	600 unless defined $options->{height};
  $this->{Width} = $options->{width};
  $this->{Height} = $options->{height};
  print "PDL::Graphics::TriD::Window: calling gdriver....\n" if($PDL::Graphics::TriD::verbose);
  $this->{Interactive} = $this->gdriver($options);
  print "PDL::Graphics::TriD::Window: gdriver gave back $this->{Interactive}....\n" if($PDL::Graphics::TriD::verbose);
  # set default values
  if($this->{Interactive}){
      print "\tIt's interactive... calling ev_defaults...\n" if($PDL::Graphics::TriD::verbose);
	 $this->{Ev} = $this->ev_defaults(); 
      print "\tcalling new_viewport...\n" if($PDL::Graphics::TriD::verbose);
	 $this->new_viewport(0,0,$this->{Width},$this->{Height});  
  }else{
	 $this->new_viewport(0,0,1,1);  
  }
  $this->current_viewport(0);
  return($this);
}

#
# adds to all viewports
#
sub add_object {
  my($this,$object) = @_;
#  print "add_object ",ref($this),"\n";
  for(@{$this->{_ViewPorts}}) {
	 $_->add_object($object);
  }
}

sub new_viewport {
  my($this,$x0,$y0,$x1,$y1, $options) = @_;
  my $vp = PDL::Graphics::TriD::ViewPort->new($x0,$y0,$x1,$y1);
  print "Adding viewport $x0,$y0,$x1,$y1\n" if $PDL::Graphics::TriD::verbose;
  push @{$this->{_ViewPorts}}, $vp;
  if ($this->{Interactive}) {
    # set a default controller
    use PDL::Graphics::TriD::ArcBall;
    use PDL::Graphics::TriD::SimpleScaler;
    use PDL::Graphics::TriD::ScrollButtonScaler;
    use PDL::Graphics::TriD::SimpleController;
    if (defined($PDL::Graphics::TriD::offline) and $PDL::Graphics::TriD::offline==1 ) {
      eval "use PDL::Graphics::TriD::VRML";  
    } else {
      eval "use PDL::Graphics::TriD::GL";  
    }
    my $ev = $options->{EHandler} // PDL::Graphics::TriD::EventHandler->new($vp);
    my $cont = $options->{Transformer} // PDL::Graphics::TriD::SimpleController->new;
    $vp->transformer($cont);
    if (ref($ev)) {
      $ev->set_button(0,PDL::Graphics::TriD::Orbiter->new($vp, 0, $cont->{WRotation}));
      $ev->set_button(2,PDL::Graphics::TriD::SimpleScaler->new($vp, \$cont->{CDistance}));
      $ev->set_button(3,PDL::Graphics::TriD::ScrollButtonScaler->new($vp, \$cont->{CDistance}, 0.9));
      $ev->set_button(4,PDL::Graphics::TriD::ScrollButtonScaler->new($vp, \$cont->{CDistance}, 1.1));
      $vp->eventhandler($ev);
    }
  }
  print "new_viewport: ",ref($vp)," ",$#{$this->{_ViewPorts}},"\n" if $PDL::Graphics::TriD::verbose;
  return $vp;
}

sub resize_viewport {
  my($this,$x0,$y0,$x1,$y1,$vpnum) = @_;
  $vpnum = $this->{_CurrentViewPort} unless(defined $vpnum);
  my $vp;
  if(defined($this->{_ViewPorts}[$vpnum])){
	 $vp = $this->{_ViewPorts}[$vpnum]->resize($x0,$y0,$x1,$y1);
  }
  return $vp;
}

sub current_viewport {
  my($this,$num) = @_;
  if(defined $num){
	 if(ref($num)){
		my $cnt=0;
		foreach (@{$this->{_ViewPorts}}){
		  if($num == $_){
			 $this->{_CurrentViewPort} = $cnt;
			 $_->{Active}=1;
		  }elsif(defined $_){
			 $_->{Active}=0;
		  }
		  $cnt++;
		}
	 }else{
		if(defined $this->{_ViewPorts}[$num]){
		  $this->{_CurrentViewPort} = $num;
		  $this->{_ViewPorts}[$num]->{Active}=1;
		}else{
		  print "ERROR: ViewPort $num undefined\n";
		}
	 }
  }
  return $this->{_ViewPorts}[$this->{_CurrentViewPort}];
}

sub viewports {
  my ($this) = shift;
  return $this->{_ViewPorts};
}

sub _vp_num_fromref {
  my ($this,$vp) = @_;
  if(! defined $vp){  
	 $vp = $this->{_CurrentViewPort};
  }elsif(ref($vp)){
	 my $cnt=0;
	 foreach(@{$this->{_ViewPorts}}){
		last if($vp == $_);
		$cnt++;
	 }
	 $vp = $cnt;
  }
  return $vp;
}

sub delete_viewport {
  my($this, $vp) = @_;
  my $cnt;
  if(($cnt=$#{$this->{_ViewPorts}})<= 0){
	 print "WARNING: Cannot delete final viewport - request ignored\n";
	 return;
  }
  $vp = $this->_vp_num_fromref($vp);
  $this->{_ViewPorts}[$vp]->DESTROY();
  splice(@{$this->{_ViewPorts}},$vp,1);
  if($vp == $cnt){
	 $this->current_viewport($vp-1);
  }
}

sub clear_viewports {
  my($this) = @_;
  foreach(@{$this->{_ViewPorts}}){
	 $_->clear_objects();
  }
}

sub clear_viewport {
  my($this, $vp) = @_;
  my $cnt;

  $vp = $this->_vp_num_fromref($vp);
  $this->{_ViewPorts}[$vp]->clear_objects();

}

sub set_eventhandler {
  my($this,$handler) = @_;
  $this->{EHandler} = $handler;
#  for(@{$this->{_ViewPorts}}) {
#	 $_->eventhandler($handler);
#  }
}

#sub set_transformer {
#  my($this,$transformer) = @_;
#
#  for(@{$this->{_ViewPorts}}) {
#	 $_->transformer($transformer);
#  }
#}

sub AUTOLOAD {
  my ($self,@args)=@_;
  use vars qw($AUTOLOAD);
  my $sub = $AUTOLOAD;
  return if $sub =~ /::DESTROY$/;
# If an unrecognized function is called for window it trys to apply it
# to all of the defined ViewPorts
  $sub =~ s/.*:://;
  print "AUTOLOAD: $sub at ",__FILE__," line ", __LINE__  ,".\n" 
	 if($PDL::Graphics::TriD::verbose);
  print "Window AUTOLOADing '$sub': self=$self, args='".join("','",@args),"'\n" if($PDL::Graphics::TriD::verbose);
  if($sub =~ /^gl/ && defined  $self->{_GLObject}){
	 return  $self->{_GLObject}->$sub(@args);
  }
  for(@{$self->{_ViewPorts}}) {
    next unless defined $_;
	 $_->$sub(@args);
  }
}

1;
