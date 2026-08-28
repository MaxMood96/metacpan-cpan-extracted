#!/usr/bin/perl

use strict;
use warnings;
use Perl::Critic;

use PPI;
use Perl::Critic::Policy::Subroutines::RequireSubOrder;

use Test::More tests=>6;

my $failure=qr/dependency order/;

subtest 'Valid order'=>sub {
	plan tests=>23;
	my $critic=Perl::Critic->new(-profile=>'NONE',-only=>1,-severity=>1);
	$critic->add_policy(-policy=>'Perl::Critic::Policy::Subroutines::RequireSubOrder');
	#
	foreach my $code (
		q|sub a{}|,
		q|sub b{}|,
		q|sub a{external()}|,
		q|sub a{} sub b{a()}|,
		q|sub a{} sub b{a 1 2;}|,
		q|sub a{} sub b{main::a()}|,
		q|package One;sub a{};package main;sub a{}|,
		q|package One;sub a{};package main;sub b{}|,
		q|package One;sub a{};package main;sub a{external()}|,
		q|package One;sub a{};package main;sub a{} sub b{a()}|,
		q|package One;sub a{};package main;sub a{} sub b{One::a()}|,
		q|package One;sub a{};package main;sub a{} sub b{Ext::a()}|,
		q|package One::Two;sub a{} sub b{a()};package main;|,
		q|package One::Two;sub a{} sub b{One::Two::a()};package main;|,
		q|{package One;sub a{}} sub a{}|,
		q|{package One;sub a{}} sub b{}|,
		q|{package One;sub a{}} sub a{external()}|,
		q|{package One;sub a{}} sub a{} sub b{a()}|,
		q|package One{sub a{}} sub a{}|,
		q|package One{sub a{}} sub b{}|,
		q|package One{sub a{}} sub a{external()}|,
		q|package One{sub a{}} sub a{} sub b{a()}|,
		#
		q|sub a; sub b{a()} sub a{b()}|, # forward declaration
		#
	) {
		is_deeply([$critic->critique(\$code)],[],$code);
	}
};

subtest 'Invalid order'=>sub {
	plan tests=>15;
	my $critic=Perl::Critic->new(-profile=>'NONE',-only=>1,-severity=>1);
	$critic->add_policy(-policy=>'Perl::Critic::Policy::Subroutines::RequireSubOrder');
	#
	foreach my $code (
		q|sub b{a()} sub a{}|,
		q|sub b{a 1 2;} sub a{}|,
		q|sub b{main::a()} sub a{}|,
		q|package One;sub a{};package main;sub b{a()} sub a{}|,
		q|package One::Two;sub a{One::Two::b()} sub b{};package main;|,
		q|package One::Two;sub a{One::Two::b()} sub b{};package main;|,
		q|package One::Two{sub a{One::Two::b()} sub b{}}|,
		q|{package One;sub a{}} sub b{a()} sub a{}|,
		q|package One{sub a{}} sub b{a()} sub a{}|,
		q|package One;sub b{a()};package main;sub a{};package One;sub a{}|,
		q|package One;sub b{One::a()};package main;sub a{};package One;sub a{}|,
		#
		q|sub b{a();c();} sub a{} sub c{}|,
		q|sub b{a()} sub a{b()}|,
		#
		q|main(); sub main{"hi"}|,
		q|main();if(1){1};sub main{"hi"}|,
		#
	) {
		like(($critic->critique(\$code))[0],$failure,$code);
	}
};

subtest 'Main callers'=>sub {
	plan tests=>4;
	my ($code,@critiques);
	my $criticFwd=Perl::Critic->new(-profile=>'NONE',-only=>1,-severity=>1);
	my $criticBwd=Perl::Critic->new(-profile=>'NONE',-only=>1,-severity=>1);
	$criticFwd->add_policy(-policy=>'Perl::Critic::Policy::Subroutines::RequireSubOrder',-params=>{backwards=>0});
	$criticBwd->add_policy(-policy=>'Perl::Critic::Policy::Subroutines::RequireSubOrder',-params=>{backwards=>1});
	#
	$code=q|main(); sub main{"hi"}|;
	@critiques=$criticFwd->critique(\$code);
	like($critiques[0],qr/dependency order.*main::main.*before caller on line 1/,"Forward:  $code");
	@critiques=$criticBwd->critique(\$code);
	ok(!@critiques,"Backward:  $code");
	#
	$code=q|sub main{"hi"} main()|;
	@critiques=$criticFwd->critique(\$code);
	ok(!@critiques,"Forward:  $code");
	@critiques=$criticBwd->critique(\$code);
	like($critiques[0],qr/dependency order.*main::main.*after caller on line 1/,"Backward:  $code");
	#
};

subtest 'Parameter "all"'=>sub {
	plan tests=>2;
	my $code;
	my $criticOne=Perl::Critic->new(-profile=>'NONE',-only=>1,-severity=>1);
	my $criticAll=Perl::Critic->new(-profile=>'NONE',-only=>1,-severity=>1);
	$criticOne->add_policy(-policy=>'Perl::Critic::Policy::Subroutines::RequireSubOrder',-params=>{all=>0});
	$criticAll->add_policy(-policy=>'Perl::Critic::Policy::Subroutines::RequireSubOrder',-params=>{all=>1});
	#
	$code=q|sub b{a();c();} sub a{} sub c{}|;
	like(($criticOne->critique(\$code))[0],qr/dependency order.*main::c/,     "All=0:  $code");
	like(($criticAll->critique(\$code))[0],qr/dependency order.*main::a.*::c/,"All=1:  $code");
};

subtest 'Parameter "backwards"'=>sub {
	plan tests=>2;
	my ($code,@critiques);
	my $critic=Perl::Critic->new(-profile=>'NONE',-only=>1,-severity=>1);
	$critic->add_policy(-policy=>'Perl::Critic::Policy::Subroutines::RequireSubOrder',-params=>{backwards=>1});
	#
	$code=q|sub a{} sub b{a()} sub c{b()}|;
	@critiques=$critic->critique(\$code);
	like($critiques[0],qr/dependency order.*main::a.*after.*main::b/,"a after b:  $code");
	like($critiques[1],qr/dependency order.*main::b.*after.*main::c/,"b after c:  $code");
};

subtest 'Cycles'=>sub {
	plan tests=>3;
	my ($code,@critiques);
	my $critic=Perl::Critic->new(-profile=>'NONE',-only=>1,-severity=>1);
	$critic->add_policy(-policy=>'Perl::Critic::Policy::Subroutines::RequireSubOrder');
	#
	$code=q|sub b{a()} sub a{}|;
	@critiques=$critic->critique(\$code);
	like  ($critiques[0],qr/dependency order.*main::b.*after.*main::a/,"b after a:  $code");
	unlike($critiques[0],qr/cyclic/,"(not cyclic):  $code");
	#
	$code=q|sub b{a()} sub a{b()}|;
	@critiques=$critic->critique(\$code);
	like($critiques[0],qr/dependency order.*main::b.*after.*main::a.*cyclic/,"(cyclic):  $code");
};

