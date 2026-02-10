use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
	module_name             => 'Image::APNG',
	license                 => 'perl',
	dist_author             => 'APNG Generator Author <nadim.khemir@gmail.com>',
	dist_version_from       => 'lib/Image/APNG.pm',
	dist_abstract           => 'Generate Animated PNG (APNG) files from individual PNG images',
	configure_requires      =>
		{
		'Module::Build' => '0.42',
		},
	
	requires => 
		{
		'perl'          => '5.010',
		'Image::Magick' => '0',
		'strict'        => 0,
		'warnings'      => 0,
		},
	
	test_requires => 
		{
		'Test::More' => '0.98',
		'File::Temp' => 0,
		},
	
	meta_merge => 
		{
		resources => 
			{
			repository => 'https://github.com/nkh/Image-APNG',
			bugtracker => 'https://github.com/nkh/Image-APNG/issues',
			},
		keywords => ['apng', 'animated', 'png', 'image', 'animation'],
		},
	
	add_to_cleanup     => ['Image-APNG-*'],
	create_makefile_pl => 'traditional',
	) ;

$builder->create_build_script() ;
