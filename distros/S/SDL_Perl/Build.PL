#! perl -w
#
# Copyright (C) 2003 chromatic 
# Copyright (C) 2004 David J. Goehrig
#

use strict;

use lib  'make/lib';

use SDL::Build;

my $sdl_compile_flags = `sdl-config --cflags`;
my $sdl_link_flags    = `sdl-config --libs`;

if ($? >> 8)
{
	die "SDL doesn't appear to be installed.\n" .
		"Please check that sdl-config is in your path and try again.\n";
}

chomp( $sdl_compile_flags );
chomp( $sdl_link_flags );

# subsystem to build
#	file
#		location of source file => location of build file to get name right
#	libraries
#		name of shared library (soname)
#			preprocessor definition
#			name of header file
my %subsystems =
(
	SDL => {
		file      => {
			from  => 'src/SDL.xs',
			to    => 'src/SDL_perl.xs',
		},
		libraries => [qw( SDL SDL_image SDL_mixer SDL_net SDL_ttf SDL_gfx
		                  png jpeg smpeg )],
	},
	OpenGL => {
		file      => {
			from => 'src/OpenGL.xs',
			to   => 'src/SDL/OpenGL.xs', 
		},
		libraries => [qw( SDL GL GLU )],
	},
	SFont => {
		file	=> {
			from => 'src/SFont.xs',
			to   =>	'src/SDL/SFont.xs',
		},
		libraries => [qw( SDL SDL_image )],
	},	
);

my %libraries = (
	SDL         => {
		define => 'HAVE_SDL', 
		header => 'SDL.h',
	},
	SDL_image   => {
		define => 'HAVE_SDL_IMAGE',   
		header => 'SDL_image.h'
	},
	SDL_mixer   => {
		define => 'HAVE_SDL_MIXER',   
		header => 'SDL_mixer.h'
	},
	SDL_net     => {
		define => 'HAVE_SDL_NET',     
		header => 'SDL_net.h'
	},
	SDL_ttf     => {
		define => 'HAVE_SDL_TTF',     
		header => 'SDL_ttf.h'
	},
	SDL_gfx     => {
		define => 'HAVE_SDL_GFX',     
		header => 'SDL_gfxPrimitives.h'
	},
	png         => {
		define    => 'HAVE_PNG',
		header    => 'png.h',
	},
	jpeg        => {	
		define    => 'HAVE_JPEG',
		header    => 'jpeglib.h',
	},
	smpeg       => {
		define    => 'HAVE_SMPEG',
		header    => 'smpeg.h',
	},
	GL          => {
		define => 'HAVE_GL',  
		header => 'gl.h'
	},
	GLU         => {
		define => 'HAVE_GLU', 
		header => 'glu.h'
	},
);

# need the platform-specific module to find include paths correctly
# see build/lib/SDL/Build/*pm
my $arch          = SDL::Build->get_arch( $^O );

# see which subsystems can be built -- do we have headers for them?
my $build_systems = $arch->find_subsystems( \%subsystems, \%libraries );

# now write SDL::Config
$arch->write_sdl_config( $build_systems );

# and fetch all of the information needed to compile
my $defines       = $arch->build_defines( \%libraries, $build_systems );
my $includes      = $arch->build_includes( \%libraries, $build_systems );
my $links         = $arch->build_links( \%libraries, $build_systems );

# mangle the compilable files into a format Module::Build can understand
my %xs = map { $subsystems{$_}{file}{from} => $subsystems{$_}{file}{to} }
	     keys %subsystems;

my $build   = SDL::Build->new(
	dist_name            => 'SDL_Perl', 
	license		     => 'lgpl',
	dist_version_from    => 'lib/SDL.pm',
	build_requires       =>
	{
		'Test::Simple' => '0.47',
	},
	build_recommends     =>
	{
		'Pod::ToDemo'  => '0.20',
	},
	xs_files             => \%xs,
	dist_author	     => 'David J. Goehrig <DGOEHRIG@cpan.org>',
);

# and here's where the real (and ugly) magic works... see SDL::Build
$build->set_flags(
	\%subsystems,
	$build_systems,
	$defines,
	$includes,
	$links,
	$sdl_compile_flags,
	$sdl_link_flags,
);

# now we're ready to go!
$build->create_build_script();
