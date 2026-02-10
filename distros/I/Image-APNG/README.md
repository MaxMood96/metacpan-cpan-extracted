# APNG Generator

A Perl module for generating Animated PNG (APNG) files from individual PNG images.

## Quick Start

```perl
use Image::APNG;

my $frames =
	[
		['frame1.png', 100],
		['frame2.png', 150],
		['frame3.png', 100]
	];

my $result = Image::APNG::generate($frames);

if ($result->{status} == 0)
	{
	open my $fh, '>', 'animation.png';
	binmode $fh;
	print $fh $result->{data};
	close $fh;
	}
```

## Files

- **APNGGenerator.pm** - Main module with POD documentation
- **APNGGenerator_Documentation.md** - Comprehensive documentation
- **example_usage.pl** - Example script demonstrating usage
- **README.md** - This file

## Requirements

- Perl 5.10+
- Image::Magick

## Documentation

See `APNGGenerator_Documentation.md` for complete documentation including:

- Installation instructions
- Detailed API reference
- All configuration options
- Error handling guide
- Performance considerations
- Multiple usage examples
- Troubleshooting guide

## Key Features

- Generate APNG from multiple PNG files
- Individual frame timing control
- Support for different image resolutions
- Automatic frame centering and padding
- Optional palette optimization (8-bit)
- Configurable animation parameters
- Robust error handling
- APNG 1.0 specification compliant

## Basic Options

```perl
my $options = 
	{
	loop_count           => 0,              # 0 = infinite
	normalize_resolution => 1,     # Make all frames same size
	background_color     => [0, 0, 0, 0], # RGBA
	optimize_palette     => 0,         # Convert to 8-bit
	disposal_method      => 1,          # Frame disposal
	blend_operation      => 1           # Alpha blending
	};
```

## Return Value

```perl
{
status => 0,           # 0 = success, 1 = error
errors => [],          # Array of error messages
data   => $binary_data # APNG binary data
}
```

## License

See LICENSE file.

## References

- [APNG Specification](https://wiki.mozilla.org/APNG_Specification)
- [PNG Specification](http://www.w3.org/TR/PNG/)
