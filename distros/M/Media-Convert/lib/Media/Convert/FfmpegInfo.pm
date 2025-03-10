package Media::Convert::FfmpegInfo;

use MooseX::Singleton;
use SemVer;
use JSON::MaybeXS;

has 'codecs' => (
	is => 'ro',
	isa => 'HashRef',
	lazy => 1,
	builder => '_build_codecs',
);

sub _build_codecs {
	local $/ = "";
	open my $ffmpeg, "-|", "ffmpeg -codecs 2>/dev/null";
	my $codeclist = <$ffmpeg>;
	close $ffmpeg;
	my $parsing = 0;
	my $rv = {};
	foreach my $line(split /\n/, $codeclist) {
		if(!$parsing) {
			if($line =~ /^ ---+/) {
				$parsing = 1;
			}
			next;
		}
		my ($decode, $encode, $type, $intra, $lossy, $lossless, $name, $desc) = unpack("xAAAAAAxA20xA*", $line);
		my $h = {};
		$h->{decode} = ($decode eq "D") ? 1 : 0;
		$h->{encode} = ($encode eq "E") ? 1 : 0;
		$h->{type} = $type;
		$h->{is_video} = ($type eq "V") ? 1 : 0;
		$h->{is_audio} = ($type eq "A") ? 1 : 0;
		$h->{is_subtitle} = ($type eq "S") ? 1 : 0;
		$h->{is_data} = ($type eq "D") ? 1 : 0;
		$h->{is_attachment} = ($type eq "T") ? 1 : 0;
		$h->{is_intra_only} = ($intra eq "I") ? 1 : 0;
		$h->{is_lossy} = ($lossy eq "L") ? 1 : 0;
		$h->{is_lossless} = ($lossless eq "S") ? 1 : 0;
		$h->{name} = $name;
		$h->{description} = $desc;
		$rv->{$name} = $h;
	};
	return $rv;
}

has version => (
	is => 'ro',
	isa => 'SemVer',
	lazy => 1,
	builder => '_build_version',
);

sub _build_version {
	open my $ffprobe, "-|", "ffprobe -loglevel quiet -show_program_version -print_format json";
	local $/ = undef;
	my $json = decode_json(<$ffprobe>);
	my $version = $json->{program_version}{version};
	if($version =~ /([0-9.]+)/) {
		my $ver = $1;
		while(scalar(split /\./, $ver) < 3) {
			$ver .= ".0";
		}
		return SemVer->new($ver);
	}
}

1;
