#! perl

use strict;
use warnings;
use ExtUtils::MakeMaker;
use lib 'inc';
use Config;

my $master = 'lib/HarfBuzz/Shaper.pm';
my $version = MM->parse_version($master);

my %args = (

  NAME             => 'HarfBuzz::Shaper',
  AUTHOR           => 'Johan Vromans <jv@cpan.org>',
  VERSION          => $version,
  ABSTRACT_FROM    => $master,
  LICENSE          => 'perl_5',
  PL_FILES         => {},
  LIBS             => [ '-lharfbuzz' ],
  INC              => '-I.',
  MIN_PERL_VERSION => '5.010001',

  PREREQ_PM => {
      'ExtUtils::MakeMaker' => 6.46, # for META_MERGE, LICENSE
      'Test::More' => 0,
      'Archive::Tar' => 0,
  },

  TEST_REQUIRES  => {
  },

  META_MERGE => {
    resources    => {
      repository => {
	type => 'git',
	web  => 'https://github.com/sciurius/perl-HarfBuzz-Shaper',
	url  => 'https://github.com/sciurius/perl-HarfBuzz-Shaper.git',
      },
      bugtracker => {
	web  => "https://github.com/sciurius/perl-HarfBuzz-Shaper/issues",
      },
    },
    'meta-spec' => {
      version => '2',
      url     => 'https://metacpan.org/pod/CPAN::Meta::Spec',
    },
    provides => {
      "HarfBuzz::Shaper"
		   => { file => "lib/HarfBuzz/Shaper.pm",
			version => $version },
    },

    no_index => {
      directory => [
		"inc", "t", "harfbuzz",
      ],
    },
  }
);

# Check whether there is a harfbuzz library installed that we can use.

my $hb_include;
my $hb_src = "hb_src.tar.gz";
my $got_hb = $ENV{INCHS} ? -1 : 0;

# First, try pkg-config.
my $res = `pkg-config --version`;
if ( !$got_hb && $res =~ /\d+\.\d+/ ) {
    $res = `pkg-config --libs harfbuzz`;
    if ( $res =~ /(?:(-L.+)\s+)?(-l.+)/ ) {
	$args{LIBS} = [ $res ];
	$res = `pkg-config --cflags harfbuzz`;
	if ( $res =~ /-I.+/ ) {
	    $args{INC} = $res;
	}
	warn("Using platform harfbuzz library (pkg-config)\n");
	$got_hb = 1;
    }
}

if ( !$got_hb ) {
    require Devel::CheckLib;
    my $ok =
    Devel::CheckLib::check_lib( lib      => "harfbuzz",
				header   => "harfbuzz/hb.h",
				function => <<EOF );
/* Need at least 1.7.7 */
hb_blob_create_from_file("");
return 0;
EOF

    if ( $ok ) {
	# Okay, the test program compiled and ran. We can use this library.
	warn("Using platform harfbuzz library (checklib)\n");
	$got_hb = 1;
	$args{CCFLAGS} = $Config{ccflags} . " -DHBDIR";
    }
}

# If not, try to include our own copy of the library.
# Note that this requires a C++ compiler. Luckily, there is often (but
# not always) a C++ compiler around when using the GNU C-compiler.

if ( $got_hb <= 0 && -s $hb_src ) {
    $hb_include = 1;
    warn(<<EOD);

NOTICE !! NOTICE !! NOTICE !! NOTICE !! NOTICE !!

We could not find a suitable harfbuzz library so we will try to
build our own. This will require a decent C++ compiler (C++11).

If building fails, see document INSTALL for (other options.

EOD

    $args{MYEXTLIB} = 'harfbuzz.o';

    # FreeBSD 10 doesn't want the stdc++ library???
    if ( $Config{osname} eq "freebsd" && $Config{osvers} =~ /^10\./ ) {
	$args{LIBS} = [];
    }
    elsif ( $^O =~ /darwin/i ) {
	$args{LIBS} = [ '-lc++' ];
	# https://github.com/Homebrew/homebrew-core/issues/145991
	$args{LDDLFLAGS} = $Config{lddlflags} . ' -Wl,-ld_classic';
    }
    else {
	$args{LIBS} = [ '-lstdc++' ];
    }
    $args{INC}      = '-I. -Ihb_src -Ihb_src/harfbuzz';
    $got_hb = 1;

    require Archive::Tar;
    Archive::Tar->new( $hb_src, undef, { extract => 1 } );
}

# Sorry, there is no point in continuing...

unless ( $got_hb >= 1 ) {
    warn("HarfBuzz::Shaper needs the harfbuzz library, version 1.7.7 or later.\n",
         "Please install it first. See file INSTALL for details.\n");
    exit(1);
}

# Write the Makefile.
WriteMakefile(%args);

################ Subroutines ################

sub MY::postamble {
    return unless $hb_include;
    my $cxx = $ENV{CXX} || "c++";
    return <<EOF;
\$(MYEXTLIB) : hb_src/harfbuzz/harfbuzz.cc
	$cxx -c -std=c++11 -fno-exceptions -o \$\@ -DHB_NO_MT \$(CCCDLFLAGS) \$<

clean ::
	\$(RM_RF) hb_src
EOF
}

