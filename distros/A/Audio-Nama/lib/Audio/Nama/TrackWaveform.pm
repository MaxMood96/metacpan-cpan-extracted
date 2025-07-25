package Audio::Nama::TrackWaveform;
use Audio::Nama::Globals qw($project $config $gui %ti);
use v5.36;
our $VERSION = 1.0;
use Role::Tiny;
use Try::Tiny;

sub waveform {
	my $self = shift;
	Audio::Nama::Waveform->new( 	project => $self->project, 
						wav     => $self->current_wav,
						start   => $self->region_start_time,
						end     => $self->region_end_time,
						track	=> $self,
	);
}


1 # obligatory
	
__END__