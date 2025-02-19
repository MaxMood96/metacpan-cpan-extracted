# $Id$
package MY;
use strict;
use ExtUtils::MakeMaker;
use Config;
use Prima::Config;

my @libs;
my @inc;
my @obj  = ('OpenGL.o');

if ( 
	$^O eq 'MSWin32' or 
	( $^O eq 'cygwin' and $Prima::Config::Config{platform} eq 'win32')
) {
	push @libs, '-L/lib/w32api' if $^O eq 'cygwin';
	push @libs, '-lopengl32 -lgdi32 -lmsimg32';
	push @obj,  'win32.o';
} elsif ( $^O eq 'darwin') {
	push @libs, map { "-L$_" } @{$Prima::Config::Config{ldpaths} };
	push @libs, '-L/opt/X11/lib -lGL';
	push @obj,  'x11.o';
	push @inc, "-I/opt/X11/include";
} else {
	push @libs, '-lGL';
	push @obj,  'x11.o';
}

push @libs, $Prima::Config::Config{libs};

WriteMakefile(
	NAME               => 'Prima::OpenGL',
	VERSION_FROM       => 'lib/Prima/OpenGL.pm',
	MIN_PERL_VERSION   => '5.012',
	PREREQ_PM          => {
		'Prima'		=> 1.49,
		'OpenGL'	=> 0,
	},
	CONFIGURE_REQUIRES => {
		'Prima'		=> 0,
	},
	ABSTRACT_FROM      => 'lib/Prima/OpenGL.pm',
	AUTHOR             => 'Dmitry Karasik <dmitry@karasik.eu.org>',
	LIBS               => "@libs",
	DEFINE             => "$Prima::Config::Config{define}",
	INC                => "$Prima::Config::Config{inc} @inc -Iinclude",
	OBJECT             => "@obj",
	META_MERGE        => {
		resources => {
			repository => 'http://github.com/dk/Prima-OpenGL',
		},
	},
	
);
