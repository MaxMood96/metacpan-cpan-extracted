package Evo::Inference::GraphAPINodeV;

use parent 'Evo::Inference::APINodeV';

sub new {
	my ($class) = @_;

	my $self = {
	};

	$class = ref($class) || $class;

	bless $self, $class;
}

1;
