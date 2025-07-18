package Audio::Nama::Waveform;
use Audio::Nama::Globals qw($project $config $gui %ti);
use Audio::Nama::Util qw(join_path);
use v5.36;
our $VERSION = 1.0;
use Try::Tiny;
use vars qw(%by_name);
use Audio::Nama::Object qw(wav track project start end);

# * objects of this class represent a waveform display 
# * each object is associated with an audio file
# * object will find or generate PNG for the audio
# * will display waveform
#    + if shift, correctly position PNG
#    + if region, trim the PNG existing for the track

# the $track->waveform method will create a new object of this class 
# we will memoize since it remains constant between reconfigures

# keyed to the 
# + name of the WAV file
# + name of project
# + start and end times

# the get_png() method will find or generate the appropriate PNG


# files are of the form # sax_1.wav.1200x200-10.png 
# where the numbers correspond to width and height in pixels of the audio
# waveform image, and the x-scaling in pixels per second (default 10)

sub new {
	my $class = shift;
	my %args = @_;
	bless \%args, $class	
}

sub generate_waveform {
	my $self = shift;
	my ($width, $height, $pixels_per_second) = @_;
	$pixels_per_second //= $config->{waveform_pixels_per_second};
	$height //= $config->{waveform_height};
	$width //= int( $self->track->wav_length * $pixels_per_second);
	my $name = waveform_name($self->track->full_path, $width, $height, $pixels_per_second);
	my $cmd = join ' ', 'waveform', "-b #c2d6d6 -c #0080ff -W $width -H $height", $self->track->full_path, $name;
	say $cmd;
	system($cmd);
	$name;
}

# utility subroutine
sub waveform_name {
	my($path, $width, $height, $pixels, $start, $end) = @_;
			"$path."  . $width . 'x' . "$height-$pixels" . region_def($start,$end) . ".png"
}
sub region_def {}
sub find_waveform {

	my $self = shift;
	my $match = shift() // '*';
	my @files = File::Find::Rule->file()
	 ->name( $self->wav . ".$match.png"  )
	 ->in(   Audio::Nama::this_wav_dir()      );
	@files;
}
sub get_waveform {
	my $self = shift;
	my ($waveform) = $self->find_waveform; 
	$waveform or $self->generate_waveform; 
}
sub display {
	my $self = shift;
	my ($waveform) = $self->get_waveform; 
	my $widget = $gui->{ww}->Photo(-format => 'png', -file => $waveform);
	$gui->{waveform}{$self->track->name} = []; # unused? 
	$gui->{wwcanvas}->createImage(	0,
												$self->y_offset_multiplier * $config->{waveform_height}, 
												-anchor => 'nw', 
												-tags => ['waveform', $self->track->name],
												-image => $widget);
	my ($width, $height) = Audio::Nama::wh($gui->{ww});
	my $name_x = $width - 150;
	my $name_y = $config->{waveform_height} * $self->y_offset_multiplier  + 20;
	$gui->{wwcanvas}->createText( $name_x, $name_y, -font =>
'lucidasanstypewriter-bold-14', -text => uc($self->track->name) . ' - '.$self->track->current_wav);
}
sub width  {
	my $self = shift;
	my ($waveform) = $self->get_waveform; 
	my ($width, $height, $pixels_per_second) = $waveform =~ /(\d+)x(\d+)-(\d+)/
		or Audio::Nama::throw("cannot parse waveform filename: $waveform");
	$width
}
sub height  {
	my $self = shift;
	my ($waveform) = $self->get_waveform; 
	my ($width, $height, $pixels_per_second) = $waveform =~ /(\d+)x(\d+)-(\d+)/
		or Audio::Nama::throw("cannot parse waveform filename: $waveform");
	$height
}
sub pixels_per_second  {
	my $self = shift;
	my ($waveform) = $self->get_waveform;
	my ($width, $height, $pixels_per_second) = $waveform =~ /(\d+)x(\d+)-(\d+)/
		or Audio::Nama::throw("cannot parse waveform filename: $waveform");
	$pixels_per_second
}
sub y_offset_multiplier {
	my $self = shift;
	my $before_me;
	for (2 .. $self->track->n - 1){
		$before_me++ if $ti{$_} and $ti{$_}->play;
	}
	$before_me
}

1 # obligatory
	
__END__
=comment
Usage: waveform [options] source_audio [ouput.png]
    -W, --width WIDTH                Width (in pixels) of generated waveform image -- Default 1800.
    -H, --height HEIGHT              Height (in pixels) of generated waveform image -- Default 280.
    -c, --color COLOR                Color (hex code) to draw the waveform. Can also pass 'transparent' to cut it out of the background -- Default #00ccff.
    -b, --background COLOR           Background color (hex code) to draw waveform on -- Default #666666.
    -m, --method METHOD              Wave analyzation method (can be 'peak' or 'rms') -- Default 'peak'.
    -q, --quiet                      Don't print anything out when generating waveform
    -F, --force                      Force generationg of waveform if file exists
    -h, --help                       Display this screen
	
=cut