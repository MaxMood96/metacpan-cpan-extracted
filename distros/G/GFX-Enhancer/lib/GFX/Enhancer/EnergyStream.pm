package GFX::Enhancer::EnergyStream;

use parent 'GFX::Enhancer::FloatStream';

sub new {
	my ($class, $length, @floats) = @_;
        my $self = $class->SUPER::new($length, @floats);

}

### public methods

sub edit {
	my ($self, $index, $value) = @_;

	$self->{listoffloats}[$index] = $value;
}

1;
