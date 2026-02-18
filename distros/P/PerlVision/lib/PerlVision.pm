# -*-cperl-*-
#
# PerlVision -  Text-mode User Interface Widgets.
# Copyright (c) Ashish Gulhati <perlvision at hash.neo.email>
#
# $Id: lib/PerlVision.pm v1.508 Tue Feb 17 13:55:44 EST 2026 $

use 5.000;

package PerlVision;

use Curses;
use vars qw ( $VERSION );

our ( $VERSION ) = '$Revision: 1.508 $' =~ /\s+([\d\.]+)/;

sub init {			# Sets things up
  initscr();
  raw(); noecho();
  eval {
    keypad(1);
  };
  eval {
    start_color();
    init_pair(1,COLOR_BLACK,COLOR_WHITE);
    init_pair(2,COLOR_WHITE,COLOR_WHITE);
    init_pair(3,COLOR_BLACK,COLOR_CYAN);
    init_pair(4,COLOR_WHITE,COLOR_CYAN);
    init_pair(5,COLOR_BLUE,COLOR_WHITE);
    init_pair(6,COLOR_WHITE,COLOR_BLUE);
    init_pair(7,COLOR_BLUE,COLOR_CYAN);
  };
}

sub done {
  endwin();
}

sub getkey {			# Gets a keystroke and returns a code
  my $key = getch();		# and the key if it's printable.
  my $keycode = 0;
  if ($key eq KEY_HOME) {
    $keycode = 1;
  }
  elsif ($key eq KEY_IC) {
    $keycode = 2;
  }
  elsif ($key eq KEY_DC) {
    $keycode = 3;
  }
  elsif ($key eq KEY_END) {
    $keycode = 4;
  }
  elsif ($key eq KEY_PPAGE) {
    $keycode = 5;
  }
  elsif ($key eq KEY_NPAGE) {
    $keycode = 6;
  }
  elsif ($key eq KEY_UP) {
    $keycode = 7;
  }
  elsif ($key eq KEY_DOWN) {
    $keycode = 8;
  }
  elsif ($key eq KEY_RIGHT) {
    $keycode = 9;
  }
  elsif ($key eq KEY_LEFT) {
    $keycode = 10;
  }
  elsif ($key eq KEY_BACKSPACE) {
    $keycode = 11;
  }
  elsif ($key eq "\e") {
    $key = getch();
    if ($key =~ /[ WwBbFfIiQqVv<>DdXxHh]/) { # Meta keys
      ($key =~ /[Qq]/) && ($keycode = 12);   # M-q
      ($key =~ /[Bb]/) && ($keycode = 13);   # M-b
      ($key =~ /[Dd]/) && ($keycode = 14);   # M-d
      ($key =~ /[Vv]/) && ($keycode = 15);   # M-v
      ($key eq "<") && ($keycode = 16);      # M-<
      ($key eq ">") && ($keycode = 17);      # M->
      ($key =~ /[Hh]/) && ($keycode = 18);   # M-h
      ($key =~ /[Xx]/) && ($keycode = 19);   # M-x
      ($key =~ /[Ff]/) && ($keycode = 20);   # M-f
      ($key =~ /[Ii]/) && ($keycode = 21);   # M-i
      ($key =~ /[Ww]/) && ($keycode = 22);   # M-w
      ($key =~ / /) && ($keycode = 23);      # M-space
    }
    else {
      $keycode = 100;
    }
  }
  elsif ($key =~ /[A-Za-z0-9_ \t\n\r~\`!@#\$%^&*()\-+=\\|{}[\];:'"<>,.\/?]/) {
    ($keycode = 200);
  }
  return ($key, $keycode);
}

sub _mybox {			# Draws a basic box.
  my ($x1,$y1,$x2,$y2,$style,$color,$window)=@_;
  my $lines=$x2-$x1;
  my $j;
  my ($TOPL,$BOTR);
  if ($style) {$TOPL=1; $BOTR=0}
  else {$TOPL=0; $BOTR=1}
  move ($window,$y1,$x1); 
  attron ($window,COLOR_PAIR(1+$TOPL+$color*2));
  $TOPL ? attron ($window,A_BOLD) : attroff ($window,A_BOLD);
  addch ($window,ACS_ULCORNER); hline ($window,ACS_HLINE, $lines-1); 
  attron ($window,COLOR_PAIR(1+$BOTR+$color*2));
  $BOTR ? attron ($window,A_BOLD) : attroff ($window,A_BOLD);
  move ($window,$y1,$x1+$lines); 
  addch ($window,ACS_URCORNER); 
  move ($window,$y1+1,$x1);
  attron ($window,COLOR_PAIR(1+$TOPL+$color*2));
  $TOPL ? attron ($window,A_BOLD) : attroff ($window,A_BOLD);
  vline ($window,ACS_VLINE, $y2-$y1-1);
  move ($window,$y1+1,$x1+$lines);
  attron ($window,COLOR_PAIR(1+$BOTR+$color*2));
  $BOTR ? attron ($window,A_BOLD) : attroff ($window,A_BOLD);
  vline ($window,ACS_VLINE, $y2-$y1-1);
  move ($window,$y2,$x1); 
  attron ($window,COLOR_PAIR(1+$TOPL+$color*2));
  $TOPL ? attron ($window,A_BOLD) : attroff ($window,A_BOLD);
  addch ($window,ACS_LLCORNER); 
  attron ($window,COLOR_PAIR(1+$BOTR+$color*2));
  $BOTR ? attron ($window,A_BOLD) : attroff ($window,A_BOLD);
  hline ($window,ACS_HLINE, $lines-1);
  move ($window,$y2,$x1+$lines); 
  addch ($window,ACS_LRCORNER); 
  for ($j=$y1+1; $j<$y2; $j++) {
    move ($window,$j,$x1+1);
    addstr ($window," " x ($lines-1));
  }
  attroff ($window,A_BOLD);
}

package PerlVision::Static;		# Static text class for dialog boxes
use Curses;

sub new {
  my $type=shift;
  my @params=(stdscr,@_);
  my $self=\@params;
  bless $self;
}

sub place {
  my $self=shift;
  my @params = @{$self};
  my ($message,$x1,$y1,$x2,$y2)=@params[1..5];
  my @message=split("\n",$message);
  my $width=$x2-$x1;
  my $depth=$y2-$y1;
  my $i=$y1;
  attron ($params[0],COLOR_PAIR(3));
  foreach (@message[0..$depth]) {
    move ($params[0],$i,$x1);
    addstr ($params[0],substr ($_,0,$width));
    $i++;
  }
}

sub display {
  my $self=shift;
  $self->place;
  refresh ($$self[0]);
}

package PerlVision::Checkbox;
use Curses;

sub new {			# Creates a check box
  my $type = shift;		# $foo = new PerlVision::Checkbox (Label,x,y,stat);
  my @params = (stdscr,@_);		
  my $self = \@params;
  bless $self;
  return $self;
}

sub place {			
  my $self = shift;		
  move ($$self[0],$$self[3],$$self[2]); 
  attron ($$self[0],COLOR_PAIR(4));
  attron ($$self[0],A_BOLD);
  addstr ($$self[0],"["); 
  attroff ($$self[0],A_BOLD);
  attron ($$self[0],COLOR_PAIR(3));
  ($$self[4]) && addch ($$self[0],ACS_RARROW);
  ($$self[4]) || addstr ($$self[0]," ");
  attron ($$self[0],COLOR_PAIR(4));
  attron ($$self[0],A_BOLD);
  addstr ($$self[0],"]");    
  attroff ($$self[0],A_BOLD);
  attron ($$self[0],COLOR_PAIR(3));
  addstr ($$self[0]," $$self[1]");
}

sub display {
  my $self=shift;
  $self->place;
  refresh ($$self[0]);
}

sub rfsh {			# Refreshes display of check box
  my $self = shift;
  move ($$self[0],$$self[3],$$self[2]+1); 
  attron ($$self[0],COLOR_PAIR(3));
  ($$self[4]) && addch ($$self[0],ACS_RARROW);
  ($$self[4]) || addstr ($$self[0]," ");
  move ($$self[0],$$self[3],$$self[2]+1); 
  refresh ($$self[0]);
}

sub activate {			# Makes checkbox active
  my $self = shift;		# $foo->activate;
  my @key;
  $self->rfsh;
  # refresh_cursor();
  
  while (@key = PerlVision::getkey()) {
    
    if ($key[1]==7) {	        # UpArrow
      return 1;
    }
    elsif ($key[1]==8) {	# DnArrow
      return 2;
    }
    elsif ($key[1]==9) {	# RightArrow
      return 3;
    }
    elsif ($key[1]==10) {	# LeftArrow
      return 4;
    }
    elsif ($key[1]==18) {	# Help
      return 5;
    }
    elsif ($key[1]==19) {	# Menu
      return 6;
    }
    elsif (($key[0] eq "\t") && ($key[1]==200)) { 
      return 7;
    }
    
    elsif (($key[0] eq ' ') && ($key[1]==200)) {
      $self->select;
    }
    $self->rfsh;
    # refresh_cursor();
    
  }
}

sub select {			# Toggles checkbox status
  my $self = shift;
  $$self[4] = ($$self[4] ? 0 : 1);
}

sub stat {			# Returns status of checkbox
  my $self = shift;		# $bar = $foo->status;
  return $$self[4];
}

package PerlVision::Radio;
use Curses;
@ISA = (PerlVision::Checkbox);

sub new {			# Creates a radio button
  my $type = shift;		# $foo = new PerlVision::Radio (Label,x,y,stat);
  my @params = (stdscr,@_,0);
  my $self = \@params;
  bless $self;
  return $self;
}

sub place {			# Displays a radio button
  my $self = shift;		# $foo->display;
  move ($$self[0],$$self[3],$$self[2]); 
  attron ($$self[0],COLOR_PAIR(4));
  attron ($$self[0],A_BOLD);
  addstr ($$self[0],"(");
  attroff ($$self[0],A_BOLD);
  attron ($$self[0],COLOR_PAIR(3));
  ($$self[4]) && addch ($$self[0],ACS_DIAMOND);
  ($$self[4]) || addstr ($$self[0]," ");
  attron ($$self[0],COLOR_PAIR(4));
  attron ($$self[0],A_BOLD);
  addstr ($$self[0],")");
  attroff ($$self[0],A_BOLD);
  attron ($$self[0],COLOR_PAIR(3));
  addstr ($$self[0]," $$self[1]");
}

sub display {
  my $self=shift;
  $self->place;
  refresh ($$self[0]);
}

sub rfsh {			# Refreshes display of radio button
  my $self = shift;
  move ($$self[0],$$self[3],$$self[2]+1); 
  attron ($$self[0],COLOR_PAIR(3));
  ($$self[4]) && addch ($$self[0],ACS_DIAMOND);
  ($$self[4]) || addstr ($$self[0]," ");
  move ($$self[0],$$self[3],$$self[2]+1); 
  refresh ($$self[0]);
}

sub group {			# Puts the button in a group
  my $self = shift;		# Should not be called from outside
  $$self[6] = shift;
}

sub select {			# Turn radio button on
  my $self = shift;
  unless ($$self[4]) {
    $$self[6]->blank if $$self[6];
    $$self[4] = 1;
    $$self[6]->rfsh;
  }
}

sub unselect {			# Turn radio button off
  my $self = shift;
  $$self[4] = 0;
}

package PerlVision::RadioG;
use Curses;
	    
sub new {			# Creates a radio button group
  my $type = shift;		# $foo = new PerlVision::RadioG (rb1, rb2, rb3...)
  my @params = @_;		# where each rbn is of class PerlVision::Radio
  my $self = \@params;
  my $i;
  bless $self;
  foreach $i (@$self) {
    ($i->group($self));
  }
  return $self;
}

sub place {
  my $self = shift;
  my $i;
  foreach $i (@$self) {
    $i->display;
  }
}

sub display {
  my $self=shift;
  $self->place;
}

sub rfsh {
  my $self = shift;
  my $i;
  foreach $i (@$self) {
    $i->rfsh;
  }
}

sub blank {			# Unchecks all buttons in the group
  my $self = shift;
  my $i;
  foreach $i (@$self) {
    $i->unselect;
  }
}
    
sub stat {			# Returns label of selected radio button
  my $self = shift;
  my $i;
  foreach $i (@$self) {
    ($i->stat) && (return $$i[0]);
  }
  return undef;
}

package PerlVision::Pushbutton;
use Curses;

sub new {			# Creates a basic pushbutton
  my $type = shift;		# PerlVision::Pushbutton ("Label",x1,y1);
  my @params= (stdscr,@_);
  my $self = \@params;
  bless $self;
}

sub place {
  my $self=shift;
  PerlVision::_mybox(@$self[2..3],$$self[2]+length($$self[1])+3,$$self[3]+2,1,0,$$self[0]);
  attron ($$self[0],COLOR_PAIR(1));
  move ($$self[0],$$self[3]+1,$$self[2]+2);
  addstr ($$self[0],$$self[1]);
}    

sub display {
  my $self=shift;
  $self->place;
  refresh ($$self[0]);
}

sub press {
  my $self=shift;
  PerlVision::_mybox(@$self[2..3],$$self[2]+length($$self[1])+3,$$self[3]+2,0,0,$$self[0]);
  attron ($$self[0],COLOR_PAIR(1));
  move ($$self[0],$$self[3]+1,$$self[2]+2);
  addstr ($$self[0],$$self[1]);
  refresh ($$self[0]);
}

sub active {
  my $self=shift;
  attron ($$self[0],COLOR_PAIR(6));
  attron ($$self[0],A_BOLD);
  move ($$self[0],$$self[3]+1,$$self[2]+2);
  addstr ($$self[0],$$self[1]);
  attroff ($$self[0],A_BOLD);
  refresh ($$self[0]);
}

sub activate {
  my $self=shift;
  $self->active;
  while (@key = PerlVision::getkey()) {
    
    if ($key[1]==7) {	        # UpArrow
      $self->display;
      return 1;
    }
    elsif ($key[1]==8) {	# DnArrow
      $self->display;
      return 2;
    }
    elsif ($key[1]==9) {	# RightArrow
      $self->display;
      return 3;
    }
    elsif ($key[1]==10) {	# LeftArrow
      $self->display;
      return 4;
    }
    elsif ($key[1]==18) {	# Help
      $self->display;
      return 5;
    }
    elsif ($key[1]==19) {	# Menu
      $self->display;
      return 6;
    }
    elsif (($key[0] eq "\t") && ($key[1]==200)) { 
      $self->display;
      return 7;
    }
    
    elsif (($key[0] =~ /[ \n]/) && ($key[1]==200)) {
      $self->press;
      return 8;
    }
  }
}

package PerlVision::Cutebutton;
use Curses;
@ISA = (PerlVision::Pushbutton);

sub new {			# A smaller, cuter pushbutton
  my $type = shift;		# PerlVision::Pushbutton ("Label",x1,y1);
  my @params= (stdscr,@_);
  my $self = \@params;
  bless $self;
}

sub place {
  my $self=shift;  
  attron ($$self[0],COLOR_PAIR(5));
  addstr ($$self[0],$$self[3],$$self[2],"  ".$$self[1]." ");
  attron ($$self[0],COLOR_PAIR(1));
  addch ($$self[0],ACS_VLINE);
  attron ($$self[0],COLOR_PAIR(2));
  attron ($$self[0],A_BOLD);
  move ($$self[0],$$self[3],$$self[2]);
  attron ($$self[0],COLOR_PAIR(2));
  attron ($$self[0],A_BOLD);
  addch ($$self[0],ACS_VLINE);
  move ($$self[0],$$self[3]+1,$$self[2]);
  addch ($$self[0],ACS_LLCORNER);
  attroff ($$self[0],A_BOLD);
  attron ($$self[0],COLOR_PAIR(1));
  hline ($$self[0],ACS_HLINE, length($$self[1])+2);
  addch ($$self[0],$$self[3]+1,$$self[2]+length($$self[1])+3,ACS_LRCORNER);
}    

sub display {
  my $self=shift;
  $self->place;
  refresh ($$self[0]);
}

sub press {
  my $self=shift;
  attron ($$self[0],COLOR_PAIR(1));
  addch ($$self[0],$$self[3],$$self[2],ACS_ULCORNER);
  hline ($$self[0],ACS_HLINE,length($$self[1])+2);
  attron ($$self[0],COLOR_PAIR(2));
  attron ($$self[0],A_BOLD);
  addch ($$self[0],$$self[3],$$self[2]+length($$self[1])+3,ACS_URCORNER);
  move ($$self[0],$$self[3]+1,$$self[2]); 
  attron ($$self[0],COLOR_PAIR(1));
  attroff ($$self[0],A_BOLD);
  addch ($$self[0],ACS_VLINE);
  attron ($$self[0],COLOR_PAIR(5));
  addstr ($$self[0]," ".$$self[1]."  ");
  move ($$self[0],$$self[3]+1,$$self[2]+length($$self[1])+3);
  attron ($$self[0],COLOR_PAIR(2));
  attron ($$self[0],A_BOLD);
  addch ($$self[0],ACS_VLINE);
  refresh ($$self[0]);
}

sub active {
  my $self=shift;
  attron ($$self[0],COLOR_PAIR(5));
  attron ($$self[0],A_BOLD);
  attron ($$self[0],A_REVERSE);
  move ($$self[0],$$self[3],$$self[2]+2);
  addstr ($$self[0],$$self[1]);
  attroff ($$self[0],A_BOLD);
  attroff ($$self[0],A_REVERSE);
  refresh ($$self[0]);
}

package PerlVision::Plainbutton;
use Curses;
@ISA = (PerlVision::Pushbutton);

sub new {			# A minimal pushbutton
  my $type = shift;		# PerlVision::Pushbutton ("Label",x1,y1);
  my @params= (stdscr,@_);
  my $self = \@params;
  bless $self;
}

sub place {
  my $self=shift;
  attron ($$self[0],COLOR_PAIR(4));
  attron ($$self[0],A_BOLD);
  move ($$self[0],$$self[3],$$self[2]);
  addstr ($$self[0],$$self[1]);
  attroff ($$self[0],A_BOLD);
}    

sub display {
  my $self=shift;
  $self->place;
  refresh ($$self[0]);
}

sub press {
}

sub active {
  my $self=shift;
  attron ($$self[0],COLOR_PAIR(5));
  attron ($$self[0],A_BOLD);
  attron ($$self[0],A_REVERSE);
  move ($$self[0],$$self[3],$$self[2]);
  addstr ($$self[0],$$self[1]);
  refresh ($$self[0]);
  attroff ($$self[0],A_BOLD);
  attroff ($$self[0],A_REVERSE);
}

package PerlVision::_::SListbox;
use Curses;

sub new {			# Creates a superclass list box
  my $type = shift;		# PerlVision::_::SListbox (Head,top,x1,y1,x2,y2,list)
  my $head = shift;             # where list is (l1,s1,l2,s2,...)
  my @params = (stdscr,$head,0, @_);	
  my $self = \@params;	        # Do not use from outside
  bless $self;
}

sub place {
  my $self = shift;
  my ($top,$x1,$y1,$x2,$y2) = @$self[2..6];
  $self->draw_border;
  my $i = shift;
  $i *= 2;
  $x1++; $y1++;
  while (($y1 < $y2) && ($i+7 < $#$self)) {
    ($$self[8+$i]) && ($self->selected($y1,$i));
    ($$self[8+$i]) || ($self->unselected($y1,$i));
    $y1++;
    $i += 2;
  }
}

sub display {
  my $self=shift;
  $self->place;
  refresh ($$self[0]);
}

sub rfsh {
  my $self = shift;
  my ($top,$x1,$y1,$x2,$y2) = @$self[2..6];
  my $i = shift;
  unless ($i==$top) {
    $$self[2]=$i;
    $i *= 2;
    $x1++; $y1++;
    while (($y1 < $y2) && ($i+7 < $#$self)) {
      ($$self[8+$i]) && ($self->selected($y1,$i));
      ($$self[8+$i]) || ($self->unselected($y1,$i));
      $y1++;
      $i += 2;
    }
  }
  refresh ($$self[0]);
}

sub unhighlight {
  my $self = shift;
  my ($ypos,$i) = @_;
  ($$self[8+$i]) && ($self->selected($ypos,$i));
  ($$self[8+$i]) || ($self->unselected($ypos,$i));
  refresh ($$self[0]);
}

sub highlight {
  my $self = shift;
  my $ypos = shift;
  my $i = shift;
  my ($x1,$x2) = @$self[3,5];
  $x1++;
  attron ($$self[0],COLOR_PAIR(5));
  attron ($$self[0],A_BOLD);
  attron ($$self[0],A_REVERSE);
  move ($$self[0],$ypos,$x1+1);
  addstr ($$self[0],substr ($$self[7+$i],0,$x2-$x1-2).
	  " " x 
	  ($x2-$x1-2-length(substr($$self[7+$i],0,$x2-$x1-2))));
  attroff ($$self[0],A_BOLD);
  attroff ($$self[0],A_REVERSE);
  refresh ($$self[0]);
}

sub selected {
  my $self = shift;
  my $ypos = shift;
  my $i = shift;
  $self->unselected($ypos,$i);
}

sub reset {
  my $self = shift;
  my $i;
  for ($i=8; $i <= $#$self; $i +=2) {
    $$self[$i] = 0;
  }
  $self->rfsh(0);
}

sub stat {
  my $self = shift;
  my $i;
  my @returnlist = ();
  for ($i=8; $i <= $#$self; $i +=2) {
    ($$self[$i]) && (@returnlist = (@returnlist,$$self[$i-1]));
  }
  $self->reset;
  return @returnlist;
}

sub done {
  my $self = shift;
  my $i = shift;
  $$self[$i*2+8]=1;
  $self->rfsh(0);
}

sub deactivate {
  my $self = shift;
  $self->reset();
}

sub unselected {
  my $self = shift;
  my $ypos = shift;
  my $i = shift;
  my ($x1,$x2) = @$self[3,5];
  $x1++;
  attron ($$self[0],COLOR_PAIR(3));
  move ($$self[0],$ypos,$x1+1);
  addstr ($$self[0],substr ($$self[7+$i],0,$x2-$x1-2).
	  " " x 
	  ($x2-$x1-2-length(substr($$self[7+$i],0,$x2-$x1-2))));
}

sub activate {
  my $self = shift;
  my ($x1,$y1,$x2,$y2) = @$self[3..6];
  my $i = 0;
  my @key;
  $x1++; $y1++;
  my $ypos=$y1;
  $self->rfsh($i);
  $self->highlight($y1,$i*2);
  while (@key = PerlVision::getkey()) {
    
    if ($key[1]==18) {	# Help
      $self->unhighlight($ypos,$i*2);
      $self->deactivate();
      return 5;
    }
    elsif ($key[1]==19) {	# Menu
      $self->unhighlight($ypos,$i*2);
      $self->deactivate();
      return 6;
    }
    elsif ($key[1]==9) {	# RightArrow
      $self->unhighlight($ypos,$i*2);
      $self->deactivate();
      return 3;
    }
    elsif ($key[1]==10) {	# LeftArrow
      $self->unhighlight($ypos,$i*2);
      $self->deactivate();
      return 4;
    }
    elsif (($key[0] eq "\t") && ($key[1]==200)) { 
      $self->unhighlight($ypos,$i*2);
      $self->deactivate();
      return 7;
    }
    elsif (($key[0] eq "\n") && ($key[1] == 200)) {
      $self->unhighlight($ypos,$i*2);
      $self->done($i);
      return 8;		
    }
    elsif (($key[0] eq " ") && ($key[1] == 200)) {
      $self->select($i);
      $self->highlight($ypos,$i*2);
    }
    elsif (($key[1] == 7) && ($i != 0)) { # Up
      ($ypos == $y1) || do {$self->unhighlight($ypos,$i*2); $ypos--};
      $i--;
      $self->rfsh($i-$ypos+$y1);
      $self->highlight($ypos,$i*2);
    }
    elsif (($key[1] == 8) && (($i*2+9) < $#$self)) { # Down
      ($ypos == $y2-1) || do {$self->unhighlight($ypos,$i*2); $ypos++};
      $i++;
      $self->rfsh($i-$ypos+$y1);
      $self->highlight($ypos,$i*2);
    }
  }
}

sub draw_border {
  my $self = shift;
  PerlVision::_mybox(@$self[3..6],0,1,$$self[0]);
  attron ($$self[0],COLOR_PAIR(4));
  attron ($$self[0],A_BOLD);
  move ($$self[0],$$self[4],$$self[3]);
  addstr ($$self[0],$$self[1]);
  attroff ($$self[0],A_BOLD);
}

sub select {
}

package PerlVision::Listbox;
use Curses;
@ISA = (PerlVision::_::SListbox);

sub new {			# Basic single selection listbox
  my $type = shift;		# PerlVision::Listbox (Head,x1,y1,x2,y2,list)
  my @params = @_;		# where list is (l1,s1,l2,s2,...)
  my $self = new PerlVision::_::SListbox(@params);
  bless $self;
}

package PerlVision::Mlistbox;
use Curses;
@ISA = (PerlVision::_::SListbox);

sub new {			# A multiple selection listbox
  my $type = shift;		# PerlVision::Mlistbox (Head,x1,y1,x2,y2,list)
  my @params = @_;		# where list is (l1,s1,l2,s2,...)
  my $self = new PerlVision::_::SListbox(@params);
  bless $self;
}

sub select {
  my $self = shift;
  my $i = shift;
  if ($$self[8+$i*2]) {
    $$self[8+$i*2] = 0;
  }
  else {
    $$self[8+$i*2] = 1;
  }
}

sub selected {
  my $self = shift;
  my $ypos = shift;
  my $i = shift;
  my ($x1,$x2) = @$self[3,5];
  $x1++;
  attron ($$self[0],COLOR_PAIR(4));
  attron ($$self[0],A_BOLD);
  move ($$self[0],$ypos,$x1+1);
  addstr ($$self[0],substr ($$self[7+$i],0,$x2-$x1-2).
	  " " x 
	  ($x2-$x1-2-length(substr($$self[7+$i],0,$x2-$x1-2))));
  attroff ($$self[0],A_BOLD);
}

sub highlight {
  my $self = shift;
  my $ypos = shift;
  my $i = shift;
  my ($x1,$x2) = @$self[3,5];
  $x1++;
  attron ($$self[0],COLOR_PAIR(5));
  $$self[8+$i] && attron ($$self[0],A_BOLD);
  attron ($$self[0],A_REVERSE);
  move ($$self[0],$ypos,$x1+1);
  addstr ($$self[0],substr ($$self[7+$i],0,$x2-$x1-2).
	  " " x 
	  ($x2-$x1-2-length(substr($$self[7+$i],0,$x2-$x1-2))));
  attroff ($$self[0],A_BOLD);
  attroff ($$self[0],A_REVERSE);
  refresh ($$self[0]);
}

sub deactivate {
  my $self = shift;
  $self->rfsh();
}

sub done {
  my $self = shift;
  $self->rfsh();
}

package PerlVision::_::Pulldown;
use Curses;
@ISA = (PerlVision::_::SListbox);

sub new {			# A pulldown menu box. Used by PerlVision::Menubar
  my $type = shift;		# Don't use from outside
  my @params = (@_);
  my $self = new PerlVision::_::SListbox(@params);
  bless $self;
}

sub draw_border {
  my $self = shift;
  PerlVision::_mybox(@$self[3..6],1,0,$$self[0]);
  move ($$self[0],$$self[4],$$self[3]);
  attron ($$self[0],COLOR_PAIR(2));
  attron ($$self[0],A_BOLD);
  addch ($$self[0],($$self[$#$self] == 1) ? ACS_VLINE : ACS_URCORNER);
  attroff ($$self[0],A_BOLD);
  attron ($$self[0],COLOR_PAIR(1));
  addstr ($$self[0]," " x ($$self[5]-$$self[3]-1));
  move ($$self[0],$$self[4],$$self[5]);
  addch ($$self[0],ACS_ULCORNER);
}

sub unselected {
  my $self = shift;
  my $ypos = shift;
  my $i = shift;
  my ($x1,$x2) = @$self[3,5];
  $x1++;
  attron ($$self[0],COLOR_PAIR(5));
  move ($$self[0],$ypos,$x1+1);
  addstr ($$self[0],substr ($$self[7+$i],0,$x2-$x1-2).
	  " " x 
	  ($x2-$x1-2-length(substr($$self[7+$i],0,$x2-$x1-2))));
}

sub activate {
  my $self=shift;
  touchwin ($$self[0]);
  $self->display();
  my $ret=$self->PerlVision::_::SListbox::activate();
  touchwin (stdscr);
  refresh(stdscr);
  return ($ret,$self->stat());
}

package PerlVision::Menubar;		
use Curses;

sub new {			# A menu bar with pulldowns
  my $type=shift;		# new PerlVision::Menubar(Head,width,depth,l,0,l,0,l,0,l,0,l);
  my @params=@_;
  my $pulldown = new PerlVision::_::Pulldown ($params[0],0,0,$params[1],$params[2],
				      @params[3..$#params],1);
  my $panel = newwin ($params[2]+1,$params[1]+1,2,1);
  $$pulldown[0] = $panel;
  my $self=[$pulldown,3];
  bless $self;
}

sub add {			# Add a pulldown to the menubar
  my $self=shift;		# $foo->add(Head,width,depth,l,0,l,0,l,0,l,0,l);
  my @params=@_;
  my $pulldown = new PerlVision::_::Pulldown ($params[0],0,0,$params[1],$params[2],
				      @params[3..$#params],0);
  my $startoff = $$self[$#$self] + length ($$self[$#$self-1][1]) + 4;
  my $panel = newwin ($params[2]+1,$params[1]+1,2,$startoff-2);
  $$pulldown[0] = $panel;
  $$self[$#$self+1]=$pulldown;
  $$self[$#$self+1]=$startoff;
}

sub highlight {
  my $self=shift;
  my $i=shift;
  move (1,$$self[$i*2+1]);
  attron (COLOR_PAIR(7));
  attron (A_BOLD);
  attron (A_REVERSE);
  addstr ($$self[$i*2][1]);
  attroff (A_BOLD);
  attroff (A_REVERSE);
  refresh();
}

sub unhighlight {
  my $self=shift;
  my $i=shift;
  move (1,$$self[$i*2+1]);
  attron (COLOR_PAIR(1));
  addstr ($$self[$i*2][1]);
  refresh();
}

sub activate {
  my $self=shift;
  my $i=0;
  my @key;
  my @ret;
  $self->highlight($i);
  while (@key = PerlVision::getkey()) {
    
    if ($key[1]==18) {	# Help
      $self->unhighlight($i);
      return 5;
    }
    elsif ($key[1]==9) {	# RightArrow
      $$self[$i*2]->reset();
      $self->unhighlight($i);
      $i = (($i*2+1==$#$self) ? 0 : $i+1);
      $self->highlight($i);
    }
    elsif ($key[1]==10) {	# LeftArrow
      $$self[$i*2]->reset();
      $self->unhighlight($i);
      $i = ($i==0 ? ($#$self-1)/2 : $i-1);
      $self->highlight($i);
    }
    elsif (($key[0] eq "\t") && ($key[1]==200)) { 
      $self->unhighlight($i);
      return 7;
    }
    elsif ((($key[0] eq "\n") && ($key[1] == 200)) || ($key[1] == 8))  {
      while (@ret = ($$self[$i*2]->activate())) {
	if ($ret[0]==3) {
	  $$self[$i*2]->reset();
	  $self->unhighlight($i);
	  $i = (($i*2+1==$#$self) ? 0 : $i+1);
	  $self->highlight($i);
	}
	elsif ($ret[0]==4) {
	  $$self[$i*2]->reset();
	  $self->unhighlight($i);
	  $i = ($i==0 ? ($#$self-1)/2 : $i-1);
	  $self->highlight($i);
	}
	else {
	  last;
	}
      }
      refresh;
      if ($ret[0] == 5) {
	$self->unhighlight($i);
	return 5;
      }
      elsif ($ret[0] == 8) {
	$self->unhighlight($i);
	return (8,$$self[$i*2][1].":".$ret[1]);
      }
    }
  }
}

sub place {
  my $self=shift;
  my ($i);
  my ($height,$width); getmaxyx($height, $width);
  PerlVision::_mybox (1,0,$width-2,2,1,0,stdscr);
  for ($i=0; $i <= ($#$self-1)/2; $i++) {
    move (1,$$self[$i*2+1]);
    addstr ($$self[$i*2][1]);
  }
}

sub display {
  my $self=shift;
  $self->place;
  refresh();
}

package PerlVision::Entryfield;
use Curses;

sub new {			# Creates a text entry field
  my $type = shift;		# new PerlVision::Entryfield(x,y,len,start,label,value);
  my @params = (stdscr,@_);
  my $self = \@params;
  bless $self;
}

sub place {
  my $self = shift;
  my $start = shift;
  my ($x,$y,$len,$max,$label,$value)=@$self[1..6];
  move ($$self[0],$y,$x); 
  attron ($$self[0],COLOR_PAIR(1));
  addstr ($$self[0],$label." "); 
  attron ($$self[0],COLOR_PAIR(4));
  attron ($$self[0],A_BOLD);
  addstr ($$self[0]," ");
  addstr ($$self[0],substr($value,$start,$len)); 
  addstr ($$self[0],"." x ($len - length(substr($value,$start,$len)))); 
  addstr ($$self[0]," ");
  attroff ($$self[0],A_BOLD);
}

sub display {
  my $self=shift;
  $self->place;
  refresh ($$self[0]);
}

sub rfsh {
  my $self = shift;
  my $start = shift;
  my $i=shift;
  my ($x,$y,$len,$oldstart,$label,$value)=@$self[1..6];
  if ($oldstart == $start) {
    move ($$self[0],$y,$x+length($label)+2+$i-$start); 
    attron ($$self[0],COLOR_PAIR(4));
    attron ($$self[0],A_BOLD);
    addstr ($$self[0],substr($value,$i,$len-($i-$start))); 
    addstr ($$self[0],"." x ($len-($i-$start)-length(substr($value,$i,$len)))); 
    attroff ($$self[0],A_BOLD);
  }
  else {
    $$self[4]=$start;
    move ($$self[0],$y,$x+length($label)+2); 
    attron ($$self[0],COLOR_PAIR(4));
    attron ($$self[0],A_BOLD);
    addstr ($$self[0],substr($value,$start,$len)); 
    addstr ($$self[0],"." x ($len - length(substr($value,$start,$len)))); 
    attroff ($$self[0],A_BOLD);
  }
}

sub activate {			# Makes entryfield active
  my $self = shift;
  my $OVSTRK_MODE=0;
  my ($x,$y,$len,$max,$label)=@$self[1..5];
  my $i=0;
  $x += length($label)+2;
  my $start=0; my $savestart=0;
  my $jump=(($len % 2) ? ($len+1)/2 : $len/2);
  $self->rfsh($start,$i);
  move ($$self[0],$y,$x);
  refresh ($$self[0]);
  while (@key = PerlVision::getkey()) {
    
    if ($key[1]==7) {	        # UpArrow
      $self->rfsh(0,0);
      refresh ($$self[0]);
      return 1;
    }
    elsif ($key[1]==8) {	# DnArrow
      $self->rfsh(0,0);
      refresh ($$self[0]);
      return 2;
    }
    elsif ($key[1]==18) {	# Help
      $self->rfsh(0,0);
      refresh ($$self[0]);
      return 5;
    }
    elsif ($key[1]==19) {	# Menu
      $self->rfsh(0,0);
      refresh ($$self[0]);
      return 6;
    }
    
    ($key[1]==11) && do {	# Backspace
      if ($i) {
	$i--;
	substr ($$self[6],$i,1) = "";
	($i<$start) && ($start -= $jump);
	($start <0) && ($start = 0);
	$self->rfsh($start,$i);
	move ($$self[0],$y,$x+$i-$start);
	refresh ($$self[0]);
      }
    };
    ($key[1]==200) && do {
      if ($key[0] =~ /[\n\r\t\f]/) {
	($key[0] eq "\t") && do {
	  $self->rfsh(0,0);
	  refresh ($$self[0]);
	  return 7;
	};
	(($key[0] eq "\n") || ($key[0] eq "\r")) && do {
	  $self->rfsh(0,0);
	  refresh ($$self[0]);
	  return 8;
	};
	($key[0] eq "\f") && do {
	  
	};
      }
      else {
	substr ($$self[6],$i,$OVSTRK_MODE) = $key[0];
	($i-$start >= $len) && ($start += $jump);
	$self->rfsh($start,$i);
	$i++;
	move ($$self[0],$y,$x+$i-$start); 
	refresh ($$self[0]);
      }
    };
    ($key[1]==1) && do {	# Home
      ($start) && ($self->rfsh(0,0));
      $i=0; $start=0;
      move ($$self[0],$y,$x);
      refresh ($$self[0]);
    };
    ($key[1]==2) && do {	# Insert
      $OVSTRK_MODE = ($OVSTRK_MODE ? 0 : 1);
    };
    ($key[1]==3) && do {	# Del
      if ($i < length($$self[6])) {
	substr ($$self[6],$i,1) = "";
	$self->rfsh($start,$i);
	move ($$self[0],$y,$x+$i-$start); 
	refresh ($$self[0]);
      }
    };
    ($key[1]==4) && do {	# End
      $i=length($$self[6]); 
      $savestart=$start;
      ($start+$len <= length($$self[6])) && 
	(($start=$i-$len+1) < 0) && ($start = 0);
      ($savestart != $start) && ($self->rfsh($start,$i));
      move ($$self[0],$y,$x+$i-$start); 
      refresh ($$self[0]);
    };
    ($key[1]==9) && do {	# RightArrow
      if ($i < length($$self[6])) {
	$i++;
	$savestart=$start;
	($i-$start >= $len) && ($start += $jump);
	($savestart != $start) && ($self->rfsh($start,$i));
	move ($$self[0],$y,$x+$i-$start);
	refresh ($$self[0]);
      }
    };
    ($key[1]==10) && do {	# LeftArrow
      if ($i) {
	$i--;
	$savestart=$start;
	($i<$start) && ($start -= $jump);
	($start <0) && ($start = 0);
	($savestart != $start) && ($self->rfsh($start,$i));
	move ($$self[0],$y,$x+$i-$start); 
	refresh ($$self[0]);
      }
    };
  }
}

sub stat {
  my $self = shift;
  return $$self[6];
}

package PerlVision::Password;
use Curses;
@ISA = (PerlVision::Entryfield);

sub new {			# Creates a password entry field
  my $type = shift;		# new PerlVision::Entryfield(x,y,len,max,label,value);
  my @params = (stdscr,@_);
  my $self = \@params;
  bless $self;
}

sub place {
  my $self = shift;
  my $start = shift;
  my ($x,$y,$len,$max,$label,$value)=@$self[1..6];
  move ($$self[0],$y,$x); 
  attron ($$self[0],COLOR_PAIR(3));
  addstr ($$self[0],$label." "); 
  attron ($$self[0],COLOR_PAIR(6));
  attron ($$self[0],A_BOLD);
  addstr ($$self[0]," ");
  addstr ($$self[0],"*" x (length(substr($value,$start,$len)))); 
  addstr ($$self[0],"." x ($len - length(substr($value,$start,$len)))); 
  addstr ($$self[0]," ");
  attroff ($$self[0],A_BOLD);
}

sub display {
  my $self=shift;
  $self->place;
  refresh ($$self[0]);
}

sub rfsh {
  my $self = shift;
  my $start = shift;
  my $i=shift;
  my ($x,$y,$len,$oldstart,$label,$value)=@$self[1..6];
  if ($oldstart == $start) {
    move ($$self[0],$y,$x+length($label)+2+$i-$start); 
    attron ($$self[0],COLOR_PAIR(6));
    attron ($$self[0],A_BOLD);
    addstr ($$self[0],"*" x (length (substr($value,$i,$len-($i-$start))))); 
    addstr ($$self[0],"." x ($len-($i-$start)-length(substr($value,$i,$len)))); 
    attroff ($$self[0],A_BOLD);
  }
  else {
    $$self[4]=$start;
    move ($$self[0],$y,$x+length($label)+2); 
    attron ($$self[0],COLOR_PAIR(6));
    attron ($$self[0],A_BOLD);
    addstr ($$self[0],"*" x (length(substr($value,$start,$len)))); 
    addstr ($$self[0],"." x ($len - length(substr($value,$start,$len)))); 
    attroff ($$self[0],A_BOLD);
  }
  refresh ($$self[0]);
}

package PerlVision::Viewbox;		
use Curses;

sub new {			# A readonly text viewer
  my $type=shift;		# PerlVision::Viewbox (x1,y1,x2,y2,text,top);
  my @params=(stdscr,@_,[],[]);
  my $self=\@params;
  $$self[5]=~s/[\r\0]//g;	# Strip nulls & DOShit.
  $$self[5]=~s/\t/        /g;	# TABs = 8 spaces.
  $$self[5].="\n";
  my $text = $$self[5];
  $text=~s/\n/\n\t/g;
  @{$$self[7]}=split("\t",$text);
  @{$$self[8]}=();
  bless $self;
}

sub place {
  my $self=shift;
  my ($x1,$y1,$x2,$y2,$text,$start)=@$self[1..6];
  my $lines=$y2-$y1-2;
  my $i=0;
  $y1++;
  PerlVision::_mybox(@$self[1..4],0,0,$$self[0]);
  $self->rfsh(1);
}

sub display {
  my $self=shift;
  $self->place;
  refresh ($$self[0]);
}

sub rfsh {
  my $self=shift;
  my $display=shift;
  ($$self[6]>($#{$$self[7]}-$$self[4]+$$self[2]+2)) && 
    ($$self[6]=$#{$$self[7]}-$$self[4]+$$self[2]+2);
  ($$self[6]<0) && ($$self[6]=0);
  my ($x1,$y1,$x2,$y2,$text,$start)=@$self[1..6];
  my $lines=$y2-$y1-2;
  my $l;
  my $i=0;
  $y1++; my $len=0;
  attron ($$self[0],COLOR_PAIR(1));
  foreach (@{$$self[7]}[$start..$start+$lines]) {
    unless ($$self[8][$i] eq $_) {
      move ($$self[0],$y1+$i,$x1+2);
      $l=$_;
      $len=length ($$self[8][$i]);
      $$self[8][$i] = $l;
      chop ($l);
      (length($l) > $x2-$x1-3) && ($l=substr($l,0,$x2-$x1-3));
      addstr ($$self[0],$l); 
      if (length($l) < $x2-$x1-3) {
	addstr ($$self[0]," " x ($x2-$x1-3 - length ($l)));
      }
    }
    $i++;
  }
  $self->statusbar;
  ($display) || (refresh ($$self[0]));
}

sub statusbar {
}

sub activate {			# Makes viewer active
  my $self = shift;
  my ($x1,$y1,$x2,$y2,$text,$start)=@$self[1..6];
  $self->rfsh;
  move ($$self[0],$y2-1,$x2-1);
  refresh ($$self[0]);
  while (@key = PerlVision::getkey()) {
    
    if ($key[1]==18) {	        # Help
      $self->rfsh;
      return 5;
    }
    elsif ($key[1]==19) {	# Menu
      $self->rfsh;
      return 6;
    }
    ($key[1]==200) && do {
      if ($key[0] =~ /[\r\t\f]/) {
	($key[0] eq "\t") && do {
	  $self->rfsh;
	  return 7;
	};
      }
    };
    
    ($key[1]==1) && do {	# Home
      $$self[6]=0;
      $self->rfsh;
    };
    ($key[1]==4) && do {	# End
      $$self[6]=$#{$$self[7]}-$y2+$y1+2;
      $self->rfsh;
    };
    ($key[1]==5) && do {	# PgUp
      $$self[6]-=$y2-$y1-2;
      $self->rfsh;
    };
    ($key[1]==6) && do {	# PgDown
      $$self[6]+=$y2-$y1-2;
      $self->rfsh;
    };
    ($key[1]==7) && do {	# UpArrow
      $$self[6]--;
      $self->rfsh;
    };
    ($key[1]==8) && do {	# DownArrow
      $$self[6]++;
      $self->rfsh;
    };
  }
}

package PerlVision::Editbox;
use Curses;

sub new {			# A multi-line text edit box
  my $type=shift;		# PerlVision::Editbox (x1,y1,x2,y2,m,text,index,top);
  my @params=(stdscr,@_,[],[],0);
  my $self=\@params;
  $$self[6]=~s/[\r\0]//g;	# Strip nulls & DOShit.
  $$self[6]=~s/\t/        /g;	# TABs = 8 spaces.
  $$self[6].="\n";
  bless $self;
  $self->justify(1);
  return $self;
}

sub place {
  my $self=shift;
  my ($x1,$y1,$x2,$y2,$margin,$text,$index,$start)=@$self[1..8];
  my $lines=$y2-$y1-2;
  my $i=0;
  $y1++;
  PerlVision::_mybox(@$self[1..4],0,1,$$self[0]);
  $self->rfsh(1);
}

sub display {
  my $self=shift;
  $self->place;
  refresh ($$self[0]);
}

sub statusbar {
}

sub rfsh {
  my $self=shift;
  my $display=shift;
  my ($x1,$y1,$x2,$y2,$margin,$text,$index,$start)=@$self[1..8];
  my @visible=@{$$self[10]};
  my $lines=$y2-$y1-2;
  my $i=0; my $l;
  $y1++;
  attron ($$self[0],COLOR_PAIR(3));
  foreach (@{$$self[9]}[$start..$start+$lines]) {
    unless ($visible[$i] eq $_) {
      $$self[10][$i] = $_;
      move ($$self[0],$y1+$i,$x1+2);
      $l=$_;
      chop ($l);
      addstr ($$self[0],$l); addstr ($$self[0]," " x (length ($visible[$i]) - length ($l)));
    }
    $i++;
  }
  $self->statusbar;
  ($display) || (refresh ($$self[0]));
}

sub process_key {
}

sub justify {
  my $self=shift;
  my $mode=shift;
  my ($x1,$y1,$x2,$y2,$margin,$text,$index)=@$self[1..7];
  my ($i,$j)=(0,0); my $line; my @text; my $ta; my $tb;
  my @textqq;
  substr ($text,$index,0)="\0";
  $text=~s/ *\n/\n/g;
  if ($mode) {
    $ta="";
    $tb="";
  }
  else {
    $mode=length($text);
    ($ta,$tb)=split("\0",$text);
    $ta=$ta."\0";$tb="\0".$tb;
    $ta=~s/(.*)\n\s.*/$1/s; ($ta=~/\0/) && ($ta="");
    $tb=~s/.*?\n\s//s; ($tb=~/\0/) && ($tb="");
    $text=substr($text,length($ta),$mode-(length($ta)+length($tb)));
    $mode=0;
  }
  $text=~s/\n/\n\t/g;
  @text=split("\t",$text);
  $j=0;
  for ($i=0; $j<=$#text; $i++) {
    if (($text[$j] eq "\n") || ($text[$j] eq "\0\n")) {
      $textqq[$i]=$text[$j];
    }
    else {
      if (length($text[$j]) > $margin) {
	$line=$text[$j];
	$text[$j]=substr($text[$j],0,$margin);
	$text[$j]=~s/^(.*\s+)\S*$/$1/;
	$line=substr($line,length($text[$j])); 
	$line=~s/^\s*//;
	$text[$j]=~s/\s*$/\n/;
	if (($j==$#text) && ($line)) {
	  $text[$j+1]=$line;
	  $textqq[$i]=$text[$j];
	}
	elsif (($line) && 
	       ($text[$j+1]=~/^[\s\0]/)) {
	  $textqq[$i]=$text[$j];
	  $text[$j]=$line; $j--;
	}
	else {
	  $line=~s/\n$//;
	  $line=~s/(\S)$/$1 /;
	  $textqq[$i]=$text[$j];
	  $text[$j+1]=$line.$text[$j+1];
	}
      }
      elsif ((!$mode) && 
	     ($j < $#text) &&  
	     (length($text[$j])+
	      length ((split(" ",$text[$j+1]))[0]) < $margin) && 
	     ($text[$j+1] =~ /^[^\s\0]/)) { 
	
	chop ($text[$j]);
	($text[$j]=~/\s$/) || ($text[$j].=" ");
	$text[$j].=$text[$j+1];
	$textqq[$i]=$text[$j];
	$text[$j+1]=$text[$j];
	$i--;
      }
      else {
	$textqq[$i]=$text[$j];
      }
    }
    $j++;
  }
  $text=join("",@textqq);
  $text=$ta.$text.$tb;
  $index=length((split("\0",$text))[0]);
  substr($text,$index,1)="";
  $$self[7]=$index;
  $$self[6]=$text;
  $text =~ s/\n/\n\t/g;
  @{$$self[9]}=split("\t",$text);
}

sub cursor {
  my $self=shift;
  my ($x1,$y1,$x2,$y2,$margin,$text,$index,$start)=@$self[1..8];
  my $textthis=substr($text,0,$index+1);
  my $col=0;
  my $line=($textthis =~ tr/\n//);
  if ($textthis=~/\n$/) {
    ($line) && ($line--);
    $col++;
  }
  my $len=(length($$self[9][$line])-1);
  $col+=(length((split("\n",$textthis))[$line]));
  if ($line<$start) {
    $start=$line;
  }
  elsif ($line>=$start+$y2-$y1-1) {
    (($start=$line-$y2+$y1+2) <0) && ($start=0);
  }
  ($$self[8]!=$start) && do {
    $$self[8]=$start;
    $self->rfsh;
  };
  move ($$self[0],$y1+$line-$start+1,$col+$x1+1);
  return ($col,$line,$len);
}

sub linemove {
  my $self=shift;
  my $dir=shift;
  my $count=shift;
  my ($col, $line, $len) = $self->cursor;
  if ($dir) {
    ($line+$count >$#{$$self[9]}) && ($count = $#{$$self[9]} - $line);
    if ($count) {
      $$self[7]+=($len-$col+1);
      (length ($$self[9][$line+$count]) < $col) && 
	($col=length ($$self[9][$line+$count]));
      $$self[7]+=$col;
      $count--;
      while ($count) {
	$$self[7]+=length($$self[9][$count+$line]);
	$count--;
      }
    }
  }
  elsif ($line) {
    ($line - $count <0) && ($count = $line);
    $$self[7]-=($col+length($$self[9][$line-$count]));
    (length ($$self[9][$line-$count]) < $col) && 
      ($col=length ($$self[9][$line-$count]));
    $$self[7]+=$col;
    $count--;
    while ($count) {
      $$self[7]-=length($$self[9][$line-$count]);
      $count--;
    }
  }
}

sub e_bkspc {
  my $self = shift;
  my ($col, $line, $len) = $self->cursor;
  if ($$self[7]) {
    $$self[7]--;
    if (substr ($$self[6],$$self[7],1) eq "\n") {
      substr ($$self[6],$$self[7],1) = "";
      $self->justify;
    }
    else {
      substr ($$self[6],$$self[7],1) = "";
      substr ($$self[9][$line],$col-2,1) = "";
    }
    $self->rfsh;
  }
}

sub e_del {
  my $self=shift;
  my ($col, $line, $len) = $self->cursor;
  unless ($$self[7]==length($$self[6])-1) {
    if (substr ($$self[6],$$self[7],1) eq "\n") {
      substr ($$self[6],$$self[7],1) = "";
      $self->justify;
    }
    else {
      substr ($$self[6],$$self[7],1) = "";
      substr ($$self[9][$line],$col-1,1) = "";
    }
    $self->rfsh;
  }
}

sub e_ins {
  my $self = shift;
  my $keystroke = shift;
  my ($col, $line, $len) = $self->cursor;
  if (substr ($$self[6],$$self[7],1) eq "\n") {
    substr ($$self[6],$$self[7],0) = $keystroke;
    substr($$self[9][$line],$col-1,0)=$keystroke;
  }
  else {
    substr ($$self[6],$$self[7],$$self[11]) = $keystroke;
    substr($$self[9][$line],$col-1,$$self[11])=$keystroke;
  }
  $$self[7]++;
  if ((length($$self[9][$line]) >= $$self[5]) || 
      ($keystroke eq "\n")) {
    $self->justify;
  }
  $self->rfsh;
}

sub stat {
  my $self=shift;
  return $$self[6];
}

sub activate {			# Makes editbox active
  my $self = shift;
  my ($y1,$y2,$margin)=($$self[2],$$self[4],$$self[5]);
  my $exitcode;
  $self->rfsh;
  my ($col, $line, $len) = $self->cursor;
  refresh ($$self[0]);
  
  while (@key = PerlVision::getkey()) {
    
    if ($key[1]==18) {	        # Help
      $self->rfsh;
      return 5;
    }
    elsif ($key[1]==19) {	# Menu
      $self->rfsh;
      return 6;
    }
    else {			# Process key hook for subclasses
      @exitcode = ($self->process_key (@key));
      if ($exitcode[0] == 1) {
	$self->rfsh;
	return 8;
      }
      elsif ($exitcode[0] == 2) {
      }
      else {		        # Now defaults for the editbox.
	if ($exitcode[0] == 3) {
	  @key = @exitcode[1..2];
	}
	
	($key[1]==11) && ($self->e_bkspc());
	(($key[1]==200) && ($key[0] eq "\t")) && do {$self->rfsh; return 7;};
	(($key[1]==200) && ($key[0] =~ /\r\f/)) && do {pv::redraw(); last;};
	($key[1]==200) && ($self->e_ins($key[0]));
	(($key[1]==2) || ($key[1]==21)) && ($$self[11] = ($$self[11] ? 0 : 1)); 
	(($key[1]==3) || (($key[0] eq "") && (!$key[1]))) && ($self->e_del());
	
	(($key[1]==1) || (($key[0] eq "") && (!$key[1]))) && do {	# Home
	  $$self[7]-=(($self->cursor)[0]-1);
	};
	(($key[1]==4) || (($key[0] eq "") && (!$key[1]))) && do {	# End
	  $$self[7]+=(($self->cursor)[2] - (($self->cursor)[0]-1));
	};
	(($key[1]==5) || ($key[1]==15)) && do {	                        # PgUp
	  $self->linemove (0,$y2-$y1-2);
	};
	(($key[1]==6) || (($key[0] eq "") && (!$key[1]))) && do {	# PgDown
	  $self->linemove (1,$y2-$y1-2);
	};
	(($key[1]==7) || (($key[0] eq "") && (!$key[1]))) && do {	# UpArrow
	  $self->linemove (0,1);
	};
	(($key[1]==8) || (($key[0] eq "") && (!$key[1]))) && do {	# DownArrow
	  $self->linemove (1,1);
	};
	(($key[1]==9) || (($key[0] eq "") && (!$key[1]))) && do {	# RightArrow
	  unless ($$self[7]==length($$self[6])-1) {
	    $$self[7]++;
	  }
	};
	(($key[1]==10) || (($key[0] eq "") && (!$key[1]))) && do {	# LeftArrow
	  if ($$self[7]) {
	    $$self[7]--;
	  }
	};
	$self->cursor;
	$self->statusbar;
	($col, $line, $len) = $self->cursor;
	refresh ($$self[0]);
      }
    }
  }
}

package PerlVision::Dialog;
use Curses;

sub new {			# The dialog box object
  my $type=shift;		# PerlVision::Dialog ("Label",x1,y1,x2,y2,style,color,
  my @params=(0,@_);		#            Control1,1,2,3,4,5,6,7,8,
  my $self=\@params;		#            Control2,1,2,3,4,5,6,7,8,...)
  $$self[0] = newwin($$self[5]-$$self[3]+1,$$self[4]-$$self[2]+1,$$self[3]-1,$$self[2]-1);
  bless $self;      
}

sub display {
  my $self=shift;
  PerlVision::_mybox (0,0,$$self[4]-$$self[2],$$self[5]-$$self[3],1,0,$$self[0]);
  my $i=8;
  while ($i+7 < $#$self) {
    $$self[$i][0]=$$self[0];
    ($$self[$i])->place;
    $i+=9;
  }
  refresh();
}

sub activate {
  my $self=shift;
  my $nohide = shift;
  $self->display;
  my $i=1; my @last=();
  while ($i) {
    @last=($i,($$self[8+(($i-1)*9)]->activate));
    $i=$$self[8+(($i-1)*9)+$last[1]];
  }
  $self->hide unless $nohide;
  refresh($$self[0]);
  return (@last);
}

sub hide {
  my $self=shift;
  touchwin(stdscr);
  refresh(stdscr);
}

package PerlVision::PVD;		# Three commonly needed dialog box types
use Curses;

sub message {
  my ($message,$width,$depth)=@_;
  ($width<11) && ($width=11);
  $depth+=4;
  my ($maxheight,$maxwidth); getmaxyx($maxheight, $maxwidth);
  my $x1=int (($maxwidth-$width)/2);
  my $y1=4 + int (($maxheight - $depth)/2);
  my $x2=$x1+$width;
  my $y2=$y1+$depth;
  my $static=new PerlVision::Static($message,2,1,$x2-$x1,$y2-$y1-4);
  my $ok = new PerlVision::Cutebutton(" OK ",int($width/2)-3,$y2-$y1-2);
  my $dialog = new PerlVision::Dialog ("",$x1,$y1,$x2,$y2,1,1,
			       $ok,1,1,1,1,1,1,1,0,
			       $static,0,0,0,0,0,0,0,0);
  $dialog->activate;
}

sub yesno {
  my ($message,$width,$depth)=@_;
  my ($maxheight,$maxwidth); getmaxyx($maxheight, $maxwidth);
  my @message=split("\n",$message);
  ($width<21) && ($width=21);
  $depth+=4;
  my $x1=int (($maxwidth-$width)/2);
  my $y1=int (($maxheight-$depth)/2);
  my $x2=$x1+$width;
  my $y2=$y1+$depth+2;
  my $viewbox = new PerlVision::Viewbox(2,1,$width-2,$depth-2,$message,0);
  my $static=new PerlVision::Static($message,2,1,$x2-$x1,$y2-$y1-4);
  my $yes = new PerlVision::Cutebutton (" YES ",int($width/2)-9,$y2-$y1-2);
  my $no = new PerlVision::Cutebutton (" NO ",int($width/2)+2,$y2-$y1-2);
  my $dialog = new PerlVision::Dialog ("",$x1,$y1,$x2,$y2,1,1,
			       $yes,1,1,2,1,1,1,2,0,
			       $no,2,2,2,1,2,2,1,0,
			       $viewbox,0,0,0,0,0,0,0,0);
  my $stat=($dialog->activate)[0];
  ($stat==2) && ($stat=0);
  return $stat;
}

sub entry {
  my ($message,$width,$depth,$entrysize,$nohide)=@_;
  my ($maxheight,$maxwidth); getmaxyx($maxheight, $maxwidth);
  my @message=split("\n",$message);
  ($width<21) && ($width=21);
  $depth+=5;
  my $x1=int (($maxwidth-$width)/2+1);
  my $y1=int (($maxheight-$depth)/2);
  my $x2=$x1+$width;
  my $y2=$y1+$depth+1;
  my $viewbox = new PerlVision::Viewbox(2,1,$width-2,3,$message,0);
  my $static=new PerlVision::Static($message,2,1,$x2-$x1,$y2-$y1-4);
  my $entry = new PerlVision::Entryfield (($width-$entrysize)/2-2, 5, $entrysize, 256, " ", "");
  my $yes = new PerlVision::Cutebutton ("  OK   ",int($width/2)-13,$y2-$y1-2);
  my $no = new PerlVision::Cutebutton (" CANCEL ",int($width/2)+3,$y2-$y1-2);
  my $dialog = new PerlVision::Dialog ("",$x1,$y1,$x2,$y2,1,1,
			       $entry,1,2,1,1,1,1,2,2,
			       $yes,1,2,3,1,2,2,3,0,
			       $no,1,3,3,2,3,3,1,0,
			       $viewbox,0,0,0,0,0,0,0,0);
  my $stat=($dialog->activate($nohide))[0];
  if ($stat==3) { $stat=0 } else { $stat = $entry->stat }
  return $stat;
}

'True Value'

__END__

=head1 NAME

PerlVision - Text-mode User Interface Widgets.

=head1 SYNOPSIS

  use PerlVision;

  init PerlVision;

  my ($width, $height) = (50,1);
  my $dialog = new PerlVision::PVD::yesno ("Yes or no?", $width, $height);
  my $answer = $dialog->activate;

  PerlVision::done;

=head1 DESCRIPTION

PerlVision provides various text-mode user interface widgets,
including checkboxes, radiobuttons, pushbuttons, single and multiple
selection listboxes, an extensible editbox, a scrollable viewbox,
single line text entry fields, a menubar with pulldown menus, and
popup dialog boxes with multiple controls.

=head1 CLASSES

The following object classes are defined within PerlVision:

=over 2

=item L</PerlVision>

Not a widget. Provides a few important class methods.

=item L</PerlVision::Static>

A static text control.

=item L</PerlVision::Checkbox>

A single 2-state checkbox.

=item L</PerlVision::Radio>

A single 2-state radiobutton.

=item L</PerlVision::RadioG>

A group of connected radiobuttons.

=item L</PerlVision::Listbox>

A single selection list box.

=item L</PerlVision::Mlistbox>

A multiple selection list box.

=item L</PerlVision::Entryfield>

A single line text entry field.

=item L</PerlVision::Password>

A single line text entry field that echoes '*' to conceal the input.

=item L</PerlVision::Menubar>

A top line menu bar with single-level pulldown submenus.

=item L</PerlVision::Editbox>

A multi-line edit box.

=item L</PerlVision::Viewbox>

A readonly viewer/pager for text files.

=item L</PerlVision::Pushbutton>

A push button that uses 3 lines of screen real estate.

=item L</PerlVision::Cutebutton>

A push button that uses 2 lines of screen real estate.

=item L</PerlVision::Plainbutton>

A no-frills button that fits on a single line.

=item L</PerlVision::Dialog>

A dialog box with multiple controls.

=back

=head1 NOTES

=over

=item Internal Classes

Other classes are defined for internal use by PerlVision and should
not be used from outside. Also, see below why use of the C<PerlVision::Radio>
control is limited from outside.

=item Constructors

Constructors for all the classes are called C<new>.

=item Instance Data

All classes expect that you will not access the object's data
yourself.

=item The C<activate> method

Most controls (except C<PerlVision::Static> and C<PerlVision::RadioG>, see below) have
an C<activate> method. It makes the control active, and returns when
any traditional shift focus key is pressed. See the section on
C<PerlVision::Dialog> for more details.

=item The C<stat> method

All controls other than C<PerlVision::Static> have a C<stat> method, which
returns the status of the control (checked, unchecked, text,
whatever).

=item Widget positioning

The C<$x> and C<$y> arguments for all widgets are the X and Y
co-ordinates to place the control, relative to the origin (top left)
of the dialog box that contains the control.

=back

=head1 CLASS INTERFACES

=over

=item B<PerlVision>

Provides some helper methods

=over

=item B<init>

Initializes PerlVision. Call this before creating any widgets.

  init PerlVision;

=item B<done>

Call this before exiting.

  PerlVision::done;

=item B<getkey>

Wait for a keypress and return the key and a keycode.

  my ($key, $keycode) = PerlVision::getkey;

C<$key> will contain the actual key pressed, whereas C<$keycode> will
contain a key code if the key is a special key recognized by
PerlVision. A list of keycodes can be found in the source of the
C<getkey> method.

=back

=item B<PerlVision::Static>

A static text control.

  my $static = new PerlVision::Static ("Text", $x1, $y1, $x2, $y2);

This control displays static text in dialog boxes. It doesn't have an
C<activate> or C<stat> method.

  $static->display;      # Displays the widget.  

If your text doesn't fit in the space you allocate, it'll be
truncated. It's also your responsibility to provide line breaks if you
don't want all the text to be thought of as a single line.

=item B<PerlVision::Checkbox>

A single 2-state checkbox.

  my $checkbox = new PerlVision::Checkbox ("Label", $x, $y, $stat);

Set C<$stat> to 1 if the Checkbox should be checked by default, 0 if
not. C<"Label"> is printed to the right of the checkbox.

  $checkbox->display;    # Displays checkbox.
  $checkbox->activate;   # Gives it focus. Exits on 1,2,3,4,5,6,7 codes.
  $checkbox->select;     # Toggles status.
  $checkbox->stat;       # Returns status. (1 checked, 0 unchecked)

=item B<PerlVision::Radio>

A single 2-state radiobutton.

  my $radio = new PerlVision::Radio ("Label", $x, $y, $stat);

C<PerlVision::Radio> is a direct descendant of C<PerlVision::Checkbox> that looks a
bit different. All the methods defined for C<PerlVision::Checkbox> are defined
for C<PerlVision::Radio> as well, but C<PerlVision::Radio> is not just a different
looking C<PerlVision::Checkbox>.

Radio buttons are meant to be grouped and to affect the state of all
other buttons in the group. So to use a radio button, it needs to be
put in a group with C<PerlVision::RadioG> (see below). Once it's in a group you
can use all the methods outlined above for C<PerlVision::Checkbox>.

=item B<PerlVision::RadioG>

A group of connected radiobuttons.

  my $radiog = new PerlVision::RadioG ($radio_1, $radio_2, $radio_3...);

Where C<$radio_*> are PerlVision::Radio objects.

  $radiog->display;      # Displays all radio buttons in group.
  $radiog->stat;         # To figure out which button is the one that's
                         # selected. This returns the Label of the selected
                         # button.

C<PerlVision::RadioG> has no C<activate> method. You activate the C<PerlVision::Radio>
objects directly. This is more flexible for use in dialog boxes.

=item B<PerlVision::Listbox>

A single selection list box.

  my $listbox = new PerlVision::Listbox ($heading, $x1, $y1, $x2, $y2, 
                                 "Label1", 0, "Label2", 0...);

Yes, the element following each C<LabelN> should be 0.

C<Label*> are the strings that will be shown in the
listbox. C<$heading> will be printed across above the top of the
listbox.

  $listbox->activate;    # Gives it focus. Exits on 5,6,7,8 exit codes.
  $listbox->stat;        # Returns the label of the selected entry.

=item B<PerlVision::Mlistbox>

A multiple selection list box.

  my $mlistbox = new PerlVision::Mlistbox ($heading, $x1, $y1, $x2, $y2, 
                                   "Label1", 0, "Label2", 0...);

Yes, the element following each C<LabelN> should be 0.

C<Label*> are the strings that will be shown in the
listbox. C<$heading> will be printed across above the top of the
listbox.

  $mlistbox->activate;   # Gives it focus. Exits on 5,6,7,8 exit codes.
  $mlistbox->stat;       # Returns a list of all selected labels.

=item B<PerlVision::Entryfield>

A single line text entry field.

  my $entry = new PerlVision::Entryfield ($x, $y, $length, $max,
                                  "Label", "Initial Value");

C<$length> is the length of the text entry area. C<$max> is the
maximum length of the input. This is currently ignored. C<"Label"> is
printed to the left of the entry field. Can be "".  The entryfield is
pre-initialized to "Initial Value". Can be "".

  $entry->activate;      # Gives it focus. Exits on 1,2,5,6,7,8 exit codes.
                         # Changed text is always saved, regardless of
    		         # how the loop exited.
  $entry->stat;	         # Returns the text value of the entryfield.

=item B<PerlVision::Password>

A single line text entry field that echoes '*' to conceal the input.

Identical to C<PerlVision::Entryfield> except that it displays '*' instead of
each character that the user types.

=item B<PerlVision::Menubar>

A top line menu bar with single-level pulldown submenus.

The menu bar is a bit odd. The way you do it is set it up with just
one pulldown, then add pulldowns to it till you have enough. Don't add
too many (i.e. that there's not enough space for their heads on the
menubar).

  my $menubar = new PerlVision::Menubar ("Head", $width, $depth, 
                                 "label1", 0, "label2", 0...);

Just like with the listboxes, each list element is followed by a
0. This list becomes your first pulldown. Now to add more pulldowns,
do:

  $menubar->add("Head", $width, $depth, "label1", 0, "label2", 0...);

That's the second pulldown, and so on. Because of this step by step
method of building up the menubar, you need to display it once you're
finished adding pulldowns, it doesn't automatically display itself. Do
a:

  $menubar->display();

To activate:

  $menubar->activate();

It'll exit on 5, 7, and 8. On 8, it'll give you a second element in
the return list of the form "Pulldown:Selection". The "Pulldown" is
the head of the pulldown menu, the "Selection" is the label of the
selection.

Help context does not come through on the 5 exit code. i.e. you can't
tell which pulldown was active when help was requested, or which
selection in which pulldown.

=item B<PerlVision::Editbox>

A multi-line edit box.

  my $editbox = new PerlVision::Editbox ($x1, $y1, $x2, $y2, $margin, 
                                 "Text", $index, $start);

C<$margin> is the word-wrap boundary. If it's bigger than the size of
the box, that's your headache.

C<$text> is a text string to be pre-loaded into the editbox. it will
be stripped of CRs (not LFs), TABs, and nulls, and justified the way
the editbox does it (see below).

C<$index> is the start position within the text to initially place the
cursor at. First char is 0.

C<$start> is the line number to position at the top of the editbox, if
possible. First line is 0.

  $editbox->activate;  # Gives it focus. Exits on 5,6,7 exit codes.
                       # Changed text is always saved, regardless of
  		       # how the loop exited.
  $editbox->stat;      # Returns the text value of the editbox.

There are some hooks to enable extending the edit box by creating a
subclass. One is an empty C<sub statusbar> that's called every-time
the display is refreshed. Another is an empty C<sub process_key> which
is used extensively in C<rap> to build a full editor out of the
editbox control.

The editbox does automatic word-wrapping and reverse
word-wrapping. The style of auto-wrapping I chose is what personally
irritates me the least (all auto-wraps irritate me). Trying to change
the wrap style is likely to be very hairy, and will probably break the
editbox.

=item B<PerlVision::Viewbox>

A readonly viewer/pager for text files.

  my $viewbox = new PerlVision::Viewbox ($x1, $y1, $x2, $y2, $text, $start);

Much like C<PerlVision::Editbox> but it's readonly and the arrow keys have
different bindings.

=item B<PerlVision::Pushbutton>, B<PerlVision::Cutebutton>, B<PerlVision::Plainbutton>

Three styles of pushbuttons.

  my $button1 = new PerlVision::Pushbutton ("Label", $x1, $y1);
  my $button2 = new PerlVision::Cutebutton ("Label", $x1, $y1);
  my $button3 = new PerlVision::Plainbutton ("Label", $x1, $y1);

Makes a push button of the specified type.

  $button1->display();    # Displays it.
  $button1->activate();   # Activates it.

Exits on codes 1,2,3,4,5,6,7,8. On 8, it 'depresses' and it's up to
you to 'undepress' it by calling the C<display> method.

C<PerlVision::Pushbutton> is BIG. It uses 3 lines on the
screen. C<PerlVision::Cutebutton> is smaller - it uses only two lines, and
'depresses' when clicked. C<PerlVision::Plainbutton> is a basic one-line
button which does nothing fancy but is useful in some situations
(e.g. for hypertext links).

=item B<PerlVision::Dialog>

A dialog box with multiple controls.

This is the widget that brings other controls together, and manages
focus switching between multiple controls. Once you've created all the
controls you need, you can add them to a C<PerlVision::Dialog> object to
create a functional UI panel.

C<PerlVision::Dialog> uses the return code from each control's activate method
do decide how to switch focus between controls. The activate method
for all controls returns an exit code when focus is released. This is
what these codes mean:

1 = Up Arrow            (Traditional shift-focus key)

2 = Down Arrow          (Traditional shift-focus key)

3 = Right Arrow         (Traditional shift-focus key)

4 = Left Arrow          (Traditional shift-focus key)

5 = M-h                 (For  help)

6 = M-x                 (For menu)

7 = Tab                 (Traditional shift-focus key)

8 = Enter               (Traditional 'Done here' key)

These codes are used by the C<PerlVision::Dialog> control to figure out how to
switch focus between controls, and when to exit. Here's how to create
a C<PerlVision::Dialog> object:

  $dialog = new PerlVision::Dialog ("Title", $x1, $y1, $x2, $y2, $style, $color,
                            $control1, 1, 2, 2, 1, 1, 1, 2, 0,
                            $control2, 1, 3, 3, 1, 2, 2, 3, 0,
                            ...);

C<"Title"> is currently ignored.

C<$style>: if 1, creates a popup that is 'raised'. if 0, creates a
popup that is 'depressed'

C<$color> is the background color for the dialog. I'd recommend 6
(cyan) because of the overall hardcoded nature of colors at present.

C<$control*> are C<PerlVision::*> objects that you created beforehand They
can't be C<PerlVision::Menubar> objects. Note that the controls must be
positioned relative to the origin (top left) of the dialog box, not
relative to the screen origin.

How the dialog box works is that the control+exitcode matrix tells
C<PerlVision::Dialog> which control to switch focus to on each of the 8 exit
codes listed above. So when you do a:

  $dialog->activate;

C<PerlVision::Dialog> starts off by displaying itself and giving focus to
C<$control1>. When C<$control1> exits, C<$dialog> looks in the list
that follows C<$control1> in the constructor syntax above to figure
out which control to give focus to next. The list is simply numbers
that say which control. So 1 represents C<$control1>, 2 represents
C<$control2>, and so on, based on the order in which the controls
appear in the constructor invocation.

The special value 0 is reserved to tell C<PerlVision::Dialog> to exit and hide
the dialog box. I also use it as a place-holder for those exit-codes
that a certain control never returns, for example of C<$control1>
above was a C<PerlVision::Editbox>, I'd put 0's in the list following
C<$control1> at positions 1,2,3 and 4 because the edit box object
never exits on those codes (those keys have meaning within the
editbox)

If you don't want focus to switch off a control when a certain
exitcode is returned, simply put that control's own number in the
corresponding position in the list.

Look in the C<rap> code for an example of C<PerlVision::Dialog> use, the
C<$options> object.

When C<PerlVision::Dialog>'s C<activate> method exits, it returns a
two-element list. The first element tells you which was the last
control to be active (again numbered as they appear in the constructor
invocation), and the second element tells you what exitcode that
control returned.

After the dialog box has exited, you can call C<stat> on each control
to determine its status. Remember, don't put C<PerlVision::RadioG> controls in
a dialog box; they don't have an activate method. Put the
corresponding C<PerlVision::Radio> controls in. When you call C<stat>, call it on
the C<PerlVision::RadioG> object.

Also, don't put a C<PerlVision::Static> as the first control in a
C<PerlVision::Dialog>. It doesn't have an activate method. If you just want a
pop-up box with text and no other controls, you could use a
C<PerlVision::Viewbox control>.

=item B<PerlVision::PVD>

PerlVision also defines three often needed dialog box styles:

=over

=item B<PerlVision::PVD::message>

A simple message box with OK button

=item B<PerlVision::PVD::yesno>

An option box with Yes/No buttons

=item B<PerlVision::PVD::entry>

A text entry box with OK/Cancel buttons

=back

All three self-center on the screen, and make sure the box is big
enough to hold the buttons. They don't check if the screen is big
enough to hold the dialog box, or if the dialog box will hold your
text. A dialog box can be created as below:

  my $dialog = new PerlVision::PVD::message ("Text", $width, $height);

  my $dialog = new PerlVision::PVD::yesno ("Text", $width, $height);

C<PerlVision::PVD::yesno> returns 1 for Yes and 0 for No.

C<PerlVision::PVD::entry> returns 0 if Cancel was clicked, or the text from
the text entry box if OK was clicked.

C<$width> and C<$height> are how big you want the text part of the box
to be (the buttons are separate).

C<PerlVision::PVD::entry> expects an additional argument, the max size of the
entry field.

  my $dialog = new PerlVision::PVD::entry ("Text", $width, $height, $entrysize);

=back

=head1 AUTHOR

Ashish Gulhati C<< <perlvision at hash.neo.email> >>

=head1 BUGS

C<$max> in C<PerlVision::Entryfield> is a misnomer. It's actually used
internally and should be set to 0 when you create a new entryfield
object.

Colors are more-or-less hardcoded.

We should check if the terminal can support the minimum capabilities
required, as well as C<eval> uncertain curses calls.

Error checking needs work.

Text justification in the editbox control should be optional.

Please report any bugs or feature requests to C<bug-perlvision at rt.cpan.org>,
or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=PerlVision>.
I will be notified, and then you'll automatically be notified of progress
on your bug as I make changes.

=head1 COPYRIGHT AND LICENSE

Copyright (c) Ashish Gulhati. All Rights Reserved.

This software package is Open Software; you can use, redistribute,
and/or modify it under the terms of the Open Artistic License 4.0.

Please see the LICENSE file included with this package, or visit
L<http://www.opensoftware.ca/oal40.txt>, for the full license terms,
and ensure that the license grant applies to you before using or
modifying this software. By using or modifying this software, you
indicate your agreement with the license terms.

=cut

