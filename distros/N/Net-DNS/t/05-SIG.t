#!/usr/bin/perl
# $Id: 05-SIG.t 2005 2025-01-28 13:22:10Z willem $	-*-perl-*-
#

use strict;
use warnings;
use Test::More;
use TestToolkit;

use Net::DNS;

my @prerequisite = qw(
		MIME::Base64
		Time::Local
		);

foreach my $package (@prerequisite) {
	next if eval "require $package";	## no critic
	plan skip_all => "$package not installed";
	exit;
}

plan tests => 70;


my $name = '.';
my $type = 'SIG';
my $code = 24;
my @attr = qw( typecovered algorithm labels orgttl sigexpiration siginception keytag signame signature );
my @data = (
	qw( TYPE0 1 0 0 20150814181655 20150814181155 2871 rsamd5.example ),
	join '', qw(	GOjsIo2JXz2ASClRhdbD5W+IYkq+Eo5iF9l3R+LYS/14Q
			fxqX2M9YHPvuLfz5ORAdnqyuKJTi3/LsrHmF/cUzwY3UM
			ZJDeGce77WiUJlR93VRKZ4fTs/wPP7JHxgAIhhlYFB4xs
			vISZr/tgvblxwJSpa4pJIahUuitfaiijFwQw= )
			);
my @also = qw( sig sigex sigin vrfyerrstr _size );

my $wire =
'000001000000000055CE309755CE2F6B0B37067273616D6435076578616D706C650018E8EC228D895F3D8048295185D6C3E56F88624ABE128E6217D97747E2D84BFD7841FC6A5F633D6073EFB8B7F3E4E440767AB2B8A2538B7FCBB2B1E617F714CF063750C6490DE19C7BBED689426547DDD544A6787D3B3FC0F3FB247C60008861958141E31B2F21266BFED82F6E5C70252A5AE292486A152E8AD7DA8A28C5C10C';

my $typecode = unpack 'xn', Net::DNS::RR->new( type => $type )->encode;
is( $typecode, $code, "$type RR type code = $code" );

my $hash = {};
@{$hash}{@attr} = @data;


for my $rr ( Net::DNS::RR->new( name => $name, type => $type, %$hash ) ) {
	my $string = $rr->string;
	my $rr2	   = Net::DNS::RR->new($string);
	is( $rr2->string, $string, 'new/string transparent' );

	is( $rr2->encode, $rr->encode, 'new($string) and new(%hash) equivalent' );

	foreach (@attr) {
		is( $rr->$_, $hash->{$_}, "expected result from rr->$_()" );
	}

	foreach (@also) {
		is( $rr2->$_, $rr->$_, "additional attribute rr->$_()" );
	}

	my $encoded = $rr->encode;
	my $decoded = Net::DNS::RR->decode( \$encoded );
	my $hex1    = uc unpack 'H*', $decoded->encode;
	my $hex2    = uc unpack 'H*', $encoded;
	my $hex3    = uc unpack 'H*', $rr->rdata;
	is( $hex1, $hex2, 'encode/decode transparent' );
	is( $hex3, $wire, 'encoded RDATA matches example' );

	my $wireformat = pack 'a* x', $encoded;
	exception( 'misplaced SIG RR', sub { Net::DNS::RR->decode( \$wireformat ) } );
}


for my $rr ( Net::DNS::RR->new(". $type") ) {
	foreach ( @attr, 'rdstring' ) {
		ok( !$rr->$_(), "'$_' attribute of empty RR undefined" );
	}

	my $class = ref($rr);

	$rr->algorithm(255);
	is( $rr->algorithm(), 255, 'algorithm number accepted' );
	$rr->algorithm('RSASHA1');
	is( $rr->algorithm(),		5,	   'algorithm mnemonic accepted' );
	is( $rr->algorithm('MNEMONIC'), 'RSASHA1', 'rr->algorithm("MNEMONIC") returns mnemonic' );
	is( $rr->algorithm(),		5,	   'rr->algorithm("MNEMONIC") preserves value' );

	exception( 'unknown mnemonic', sub { $rr->algorithm('X') } );

	is( $class->algorithm('RSASHA256'), 8,		 'class method algorithm("RSASHA256")' );
	is( $class->algorithm(8),	    'RSASHA256', 'class method algorithm(8)' );
	is( $class->algorithm(255),	    255,	 'class method algorithm(255)' );

	my $object = Net::DNS::RR->new(". $type");
	my $scalar = '';
	$object->{algorithm} = 0;	## methods callable with invalid arguments

	noexception( '_CreateSig callable',	sub { $object->_CreateSig( $scalar, $object ) } );
	noexception( '_CreateSigData callable', sub { $object->_CreateSigData($object) } );
	noexception( '_VerifySig callable',	sub { $object->_VerifySig( $object, $object ) } );

	exception( 'create callable', sub { $class->create( $scalar, $object ) } );
	exception( 'verify callable', sub { $object->verify( $object, $object ) } );
}


{
	my %testcase = (		## test time conversion edge cases
		-1	   => '21060207062815',
		0x00000000 => '19700101000000',
		0x7fffffff => '20380119031407',
		0x80000000 => '20380119031408',
		0xf4d41f7f => '21000228235959',
		0xf4d41f80 => '21000301000000',
		0xffffffff => '21060207062815',
		);

	foreach my $time ( sort keys %testcase ) {
		my $string = $testcase{$time};
		my $result = Net::DNS::RR::SIG::_time2string($time);
		is( $result, $string, "_time2string($time)" );

		# Test indirectly: $timeval can be 64-bit or negative 32-bit integer
		my $timeval = Net::DNS::RR::SIG::_string2time($string);
		my $timestr = Net::DNS::RR::SIG::_time2string($timeval);
		is( $timestr, $string, "_string2time($string)" );
	}

	my $timenow = time();
	my $timeval = Net::DNS::RR::SIG::_string2time($timenow);
	is( $timeval, $timenow, "_string2time( time() )\t$timeval" );
}


sub test_order {
	my @arg = @_;
	my ( $a, $b ) = map { defined($_) ? $_ : 'undef' } @arg;
	ok( Net::DNS::RR::SIG::_ordered(@arg),		  "_ordered( $a, $b )" );
	ok( !Net::DNS::RR::SIG::_ordered( reverse @arg ), "!_ordered( $b, $a )" );
}

test_order( 0,		 1 );
test_order( 0x7fffffff, 0x80000000 );
test_order( 0xffffffff,	 0 );
test_order( -1,		 0 );
test_order( -2,		-1 );
test_order( undef,	 0 );


Net::DNS::RR->new("$name $type @data")->print;

exit;

