package RogueCurses::NPCs::trenchgnome;

use Curses;
use parent 'RogueCurses::entity';

sub new {
	my ($class,$x,$y,$w,$h,$name,$interface) = @_;
	my $self = $class->SUPER::new($x,$y,$w,$h,'t',$interface);	

}

sub get_message {
	my $self = shift;
	my $n = shift;

	### FIXME trenchgnome speaks
}

sub interface_get_message {
	my $self = shift;
	my $n = shift;

	return $self->{messages}[$n];
}
 
### The trench gnome answers to the following keys and returns a message
### number to hash the messages
sub compare_and_execute
{
	my $self = shift;
	my $key = shift;

	### Do something
	switch ($key) {
		
	}

	return -1;
}

1;
