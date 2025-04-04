#!/usr/bin/perl

use 5.006;

use strict;
use warnings;
no  warnings 'syntax';

use ExtUtils::MakeMaker;

my  $PACKAGE      =  'Math::Sequence::DeBruijn';

my  $LIB_FILE     =  "lib/$PACKAGE.pm";
    $LIB_FILE     =~  s!::!/!g;
my  $LOCAL_ADDR   =  'cpan';
my  $DOMAIN       =  'abigail.be';
my  $REPO         =   $PACKAGE;
    $REPO         =~  s!::!-!g;
my  $REPO_HOST    =  'github.com';
my  $ME           =  'Abigail';
my  $REPOSITORY   =  "git://$REPO_HOST/$ME/$REPO.git";


my %args = (
    NAME                 =>  $PACKAGE,
    VERSION_FROM         =>  $LIB_FILE,
    ABSTRACT_FROM        =>  $LIB_FILE,
    PREREQ_PM            => {
        'strict'             =>  0,
        'warnings'           =>  0,
    },
    MIN_PERL_VERSION     =>   5.028,
    AUTHOR               =>  "$ME <$LOCAL_ADDR\@$DOMAIN>",
    LICENSE              =>  'mit',
    META_MERGE           => {
        test_requires    => {
            'strict'             => 0,
            'warnings'           => 0,
            'Test::More'         => 0.88,
        },
        resources        => {
            repository   => $REPOSITORY,
        },
        keywords         => ['De Bruijn', 'De Bruijn sequence',
                              qw [sequence combinatorics]],
    },
);

$args {META_MERGE} {build_requires} ||= {
    'ExtUtils::MakeMaker' =>  0,
    %{$args {META_MERGE} {test_requires}}
};

$args {META_MERGE} {configure_requires} ||=
    $args {META_MERGE} {build_requires};

my %filter = (
    MIN_PERL_VERSION     => '6.48',
    LICENSE              => '6.48',
    META_MERGE           => '6.46',
    AUTHOR               => '6.07',
    ABSTRACT_FROM        => '6.07',
);

delete $args {$_} for grep {defined $filter {$_} &&
                            $ExtUtils::MakeMaker::VERSION lt $filter {$_}}
                            keys %args;


WriteMakefile %args;

__END__
