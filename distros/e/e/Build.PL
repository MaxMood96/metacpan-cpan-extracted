#!/bin/env perl

use 5.006;
use strict;
use warnings;
use Module::Build;
Module::Build->VERSION( '0.4004' );

my $class = Module::Build->subclass(
    code => q{
        use Cwd qw( cwd );

        #---------------------------------
        #            Build
        #---------------------------------

        sub ACTION_build {
            my ($s) = @_;
            $s->_readme();
            $s->SUPER::ACTION_build;
        }

        # Only for the maintainer on "Build build".
        sub _readme {
            my ($s) = @_;
            return if cwd() !~ m{ / git / perlmy / [^/]+ $ }x;

            my ($installed) =
                grep { -x "$_/pod2markdown" }
                split /:/, $ENV{PATH};
            return if !$installed;

            print "Building README\n";
            my $lib = $s->{properties}{dist_version_from};
            system "pod2markdown $lib > README.md";
        }

        #---------------------------------
        #           Install
        #---------------------------------

        sub ACTION_install {
            my ($s) = @_;
            $s->SUPER::ACTION_install;

            # Display logo/image.
            system qq( pod e -q head1=LOGO/Verbatim );
        }
    },
);

my $builder = $class->new(
    module_name        => 'e',
    license            => 'artistic_2',
    dist_author        => q{Tim Potapov <tim.potapov@gmail.com>},
    dist_version_from  => 'lib/e.pm',
    release_status     => 'stable',
    configure_requires => {
        'Module::Build' => '0.4004',
    },
    test_requires => {
        'Test::More' => '0',
    },
    requires => {
        'perl'                  => '5.016',
        'App::Pod'              => '0.39',
        'Data::Printer'         => '0',
        'Data::Trace'           => '1.05',
        'Mojolicious'           => '0',
        'Parallel::ForkManager' => '0',
        'Runtime::Debugger'     => '1.10',
        'Set::Scalar'           => '0',
        'Sub::Util'             => '0',
        'Term::Table'           => '0',
        'Text::CSV_XS'          => '0',
        'Tiny::Prof'            => '0.03',
        'YAML::XS'              => '0',
    },
    add_to_cleanup => [ 'e-*', 'MANIFEST*.bak', 'blib/', 'pod2htmd.tmp' ],
    meta_merge     => {
        resources => {
            bugtracker => 'https://github.com/poti1/e/issues',
            repository => 'https://github.com/poti1/e',
        },
    },
);

$builder->create_build_script();
