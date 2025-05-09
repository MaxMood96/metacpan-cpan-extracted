#!/usr/bin/env perl

use strict;
use warnings;

use Module::Build;

my $build = Module::Build->new(
    module_name => 'Mite',
    license  => 'perl',

    configure_requires => {
        'Module::Build' => 0.42
    },

    requires => {
        'namespace::autoclean'  => '0',
        'perl'                  => '5.10.1',
        'version'               => '0.77',
        'App::Cmd'              => '0.323',
        'Import::Into'          => '0',
        'Moo'                   => '2.000',
        'Path::Tiny'            => '0.052',
        'Types::Path::Tiny'     => '0',
        'Types::Standard'       => '1.012',
        'YAML::XS'              => '0.41',
    },

    build_requires => {
        'Test::Sims'    => '20130412',
        'Test::Most'    => '0.31',
        'Test::Deep'    => '0.110',
        'Test::Compile' => '0.24',
        'Test::Output'  => '1.02',
        'Test::FailWarnings' => '0.008',
        'Fennec'        => '2.016',
        'Child'         => '0.010',     # fix for die in eval bug
        'File::Copy::Recursive' => '0.38',
        'Capture::Tiny' => '0.22',
        'Devel::Hide'   => '0.0009',
    },

    recursive_test_files => 1,

    create_license      => 1,

    meta_merge => {
        resources => {
            bugtracker => 'https://github.com/tobyink/p5-mite/issues',
            repository => 'https://github.com/tobyink/p5-mite',
        },
        no_index => {
            package => [qw(MY)],
        },
    }
);
$build->create_build_script;
