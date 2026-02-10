package Image::APNG ;

use strict ;
use warnings ;
use Image::Magick ;

our $VERSION = '1.0.0' ;

=head1 NAME

Image::APNG - Generate Animated PNG (APNG) files from individual PNG images

=head1 SYNOPSIS

	use Image::APNG;
	
	my $frames =
		[
			['frame1.png', 100],
			['frame2.png', 150],
			['frame3.png', 100]
		] ;
	
	my $options = 
		{
		loop_count           => 0,
		normalize_resolution => 1,
		background_color     => [255, 255, 255, 0]
		} ;
	
	my $result = Image::APNG::generate($frames, $options) ;
	
	if ($result->{status} == 0)
		{
		open my $fh, '>', 'output.png' ;
		binmode $fh ;
		print $fh $result->{data} ;
		close $fh ;
		}
	else
		{
		print "Errors: " . join("\n", @{$result->{errors}}) ;
		}

=head1 DESCRIPTION

Generates APNG files from a list of PNG images with individual frame delays.

=cut

#----------------------------------------------------------------------------------------------

sub generate
{
my ($frames, $options) = @_ ;

$options //= {} ;
my $errors = [] ;

my $default_options = 
	{
	optimize_palette     => 0,
	normalize_resolution => 0,
	target_resolution    => undef,
	background_color     => [0, 0, 0, 0],
	loop_count           => 0,
	disposal_method      => 1,
	blend_operation      => 1
	} ;

$options = {%$default_options, %$options} ;
return {status => 1, errors => ['No frames provided'], data => undef} unless $frames && @$frames ;

my $loaded_frames = load_frames($frames, $errors, $options) ;
return {status => 1, errors => $errors, data => undef} unless @$loaded_frames ;

$loaded_frames = normalize_frames($loaded_frames, $options, $errors)  if $options->{normalize_resolution} ;
$loaded_frames = optimize_palettes($loaded_frames, $errors)  if $options->{optimize_palette} ;

return
	{
	status => @$errors ? 1 : 0,
	errors => $errors,
	data => assemble_apng($loaded_frames, $options, $errors),
	} ;
}

#----------------------------------------------------------------------------------------------

sub load_frames
{
my ($frames, $errors, $options) = @_ ;

my ($loaded, $previous_valid) = ([]) ;

for my $frame_data (@$frames)
	{
	my ($filename, $delay_ms) = @$frame_data ;
	
	my $image  = Image::Magick->new() ;
	my $status = $image->Read($filename) ;
	
	if ($status)
		{
		push @$errors, "Failed to load $filename: $status" ;
		
		if ($previous_valid)
			{
			my $blank = $previous_valid->Clone() ;
			$blank->Quantize(colorspace => 'Transparent') ;
			
			push @$loaded, 
				{
				image  => $blank,
				delay  => $delay_ms,
				width  => $previous_valid->Get('width'),
				height => $previous_valid->Get('height')
				} ;
			}
		else
			{
			push @$errors, "Cannot create blank frame: no previous valid frame" ;
			}
		
		next ;
		}
	
	my $width  = $image->Get('width') ;
	my $height = $image->Get('height') ;
	
	push @$loaded,
		{
		image  => $image,
		delay  => $delay_ms,
		width  => $width,
		height => $height
		} ;
	
	$previous_valid = $image ;
	}

return $loaded ;
}

#----------------------------------------------------------------------------------------------

sub normalize_frames
{
my ($frames, $options, $errors) = @_ ;

my ($max_width, $max_height) ;

if ($options->{target_resolution})
	{
	($max_width, $max_height) = @{$options->{target_resolution}} ;
	}
else
	{
	$max_width  = 0 ;
	$max_height = 0 ;
	
	for my $frame (@$frames)
		{
		$max_width  = $frame->{width}  if $frame->{width}  > $max_width ;
		$max_height = $frame->{height} if $frame->{height} > $max_height ;
		}
	}

my $bg_color  = $options->{background_color} ;
my $bg_string = sprintf
		(
		'rgba(%d,%d,%d,%f)',
		$bg_color->[0],
		$bg_color->[1],
		$bg_color->[2],
		$bg_color->[3] / 255.0
		) ;

for my $frame (@$frames)
	{
	next if $frame->{width} == $max_width && $frame->{height} == $max_height ;
	
	my $canvas = Image::Magick->new(size => "${max_width}x${max_height}") ;
	$canvas->Read("xc:$bg_string") ;
	
	my $x_offset = int(($max_width - $frame->{width}) / 2) ;
	my $y_offset = int(($max_height - $frame->{height}) / 2) ;
	
	$canvas->Composite
			(
			image   => $frame->{image},
			x       => $x_offset,
			y       => $y_offset,
			compose => 'Over'
			) ;
	
	$frame->{image}  = $canvas ;
	$frame->{width}  = $max_width ;
	$frame->{height} = $max_height ;
	}

return $frames ;
}

#----------------------------------------------------------------------------------------------

sub optimize_palettes
{
my ($frames, $errors) = @_ ;

for my $frame (@$frames)
	{
	my $img = $frame->{image} ;
	
	my $status = $img->Quantize
				(
				colors     => 256,
				colorspace => 'RGB',
				dither     => 'True',
				treedepth  => 8,
				) ;
	
	push @$errors, "Palette optimization failed: $status" if $status ;
	
	$img->Set(type => 'Palette') ;
	}

return $frames ;
}

#----------------------------------------------------------------------------------------------

sub assemble_apng
{
my ($frames, $options, $errors) = @_ ;

my $first_frame = $frames->[0] ;
my $width       = $first_frame->{width} ;
my $height      = $first_frame->{height} ;

my $png_signature = pack('C8', 137, 80, 78, 71, 13, 10, 26, 10) ;

my $ihdr = create_ihdr($width, $height, $first_frame->{image}) ;
my $actl = create_actl(scalar @$frames, $options->{loop_count}) ;

my $sequence = 0 ;
my $chunks = '' ;

for my $i (0 .. $#$frames)
	{
	my $frame = $frames->[$i] ;
	my $fctl = create_fctl
			(
			$sequence++,
			$frame->{width},
			$frame->{height},
			0,
			0,
			$frame->{delay},
			1000,
			$options->{disposal_method},
			$options->{blend_operation},
			) ;
	
	$chunks .= $fctl ;
	
	my $frame_data = get_compressed_image_data($frame->{image}) ;
	
	if ($i == 0)
		{
		$chunks .= create_idat($frame_data) ;
		}
	else
		{
		$chunks .= create_fdat($sequence++, $frame_data) ;
		}
	}

my $iend = create_iend() ;

return $png_signature . $ihdr . $actl . $chunks . $iend ;
}

#----------------------------------------------------------------------------------------------

sub create_ihdr
{
my ($width, $height, $image) = @_ ;

my $bit_depth = $image->Get('depth') || 8 ;
my $color_type = get_color_type($image) ;

my $data = pack
		('N2C5',
		$width,
		$height,
		$bit_depth,
		$color_type,
		0,
		0,
		0,
		) ;

return create_chunk('IHDR', $data) ;
}

#----------------------------------------------------------------------------------------------

sub get_color_type
{
my ($image) = @_ ;

my $type  = $image->Get('type') ;
my $matte = $image->Get('matte') ;

return 6 if $matte ;
return 3 if $type eq 'Palette' ;
return 2 if $type eq 'TrueColor' ;
return 0 if $type eq 'Grayscale' ;
return 4 if $type eq 'GrayscaleMatte' ;

return 6 ;
}

#----------------------------------------------------------------------------------------------

sub create_actl
{
my ($num_frames, $num_plays) = @_ ;

my $data = pack('N2', $num_frames, $num_plays) ;
return create_chunk('acTL', $data) ;
}

#----------------------------------------------------------------------------------------------

sub create_fctl
{
my ($sequence, $width, $height, $x_offset, $y_offset, $delay_num, $delay_den, $dispose_op, $blend_op) = @_ ;

my $data = pack
		('N5n2C2',
		$sequence,
		$width,
		$height,
		$x_offset,
		$y_offset,
		$delay_num,
		$delay_den,
		$dispose_op,
		$blend_op,
		) ;

return create_chunk('fcTL', $data) ;
}

#----------------------------------------------------------------------------------------------

sub create_idat
{
my ($compressed_data) = @_ ;

return create_chunk('IDAT', $compressed_data) ;
}

#----------------------------------------------------------------------------------------------

sub create_fdat
{
my ($sequence, $compressed_data) = @_ ;

my $data = pack('N', $sequence) . $compressed_data ;
return create_chunk('fdAT', $data) ;
}

#----------------------------------------------------------------------------------------------

sub create_iend
{
return create_chunk('IEND', '') ;
}

#----------------------------------------------------------------------------------------------

sub create_chunk
{
my ($type, $data) = @_ ;

my $length = length($data) ;
my $crc    = calculate_crc($type . $data) ;

return pack('N', $length) . $type . $data . pack('N', $crc) ;
}

#----------------------------------------------------------------------------------------------

sub calculate_crc
{
my ($data) = @_ ;

my $crc = 0xFFFFFFFF ;
my @crc_table ;

unless (@crc_table)
	{
	for my $n (0 .. 255)
		{
		my $c = $n ;
		for my $k (0 .. 7)
			{
			if ($c & 1)
				{
				$c = 0xEDB88320 ^ ($c >> 1) ;
				}
			else
				{
				$c = $c >> 1 ;
				}
			}
		$crc_table[$n] = $c ;
		}
	}

for my $byte (unpack('C*', $data))
	{
	$crc = $crc_table[($crc ^ $byte) & 0xFF] ^ ($crc >> 8) ;
	}

return $crc ^ 0xFFFFFFFF ;
}

#----------------------------------------------------------------------------------------------

sub get_compressed_image_data
{
my ($image) = @_ ;

my $temp_file = "/tmp/apng_temp_$$.png" ;
$image->Write(filename => $temp_file, compression => 9) ;

open my $fh, '<', $temp_file or die "Cannot open temp file: $!" ;
binmode $fh ;

my $png_data = do { local $/; <$fh> } ;

close $fh ;
unlink $temp_file ;

my $idat_data = '' ;
my $pos = 8 ;

while ($pos < length($png_data))
	{
	my $chunk_length = unpack('N', substr($png_data, $pos, 4)) ;
	my $chunk_type   = substr($png_data, $pos + 4, 4) ;
	my $chunk_data   = substr($png_data, $pos + 8, $chunk_length) ;
	
	$idat_data .= $chunk_data if $chunk_type eq 'IDAT' ;
	
	$pos += 12 + $chunk_length ;
	}

return $idat_data ;
}

#----------------------------------------------------------------------------------------------

1;

=head1 OPTIONS

=over 4

=item optimize_palette

Boolean. Convert frames to 8-bit indexed PNG. Default: 0

=item normalize_resolution

Boolean. Make all frames the same resolution. Default: 0

=item target_resolution

Array reference [width, height]. Override automatic resolution. Default: undef

=item background_color

Array reference [R, G, B, A] (0-255). Background for smaller frames. Default: [0, 0, 0, 0]

=item loop_count

Integer. Animation loops (0 = infinite). Default: 0

=item disposal_method

Integer (0-2). Frame disposal method. Default: 1

=item blend_operation

Integer (0-1). Frame blending operation. Default: 1

=back

=head1 RETURN VALUE

Hash reference with keys:

=over 4

=item status

0 for success, 1 for error

=item errors

Array reference of error messages

=item data

Binary APNG data (undef on error)

=back

=head1 AUTHOR

Generated for APNG creation

=cut
