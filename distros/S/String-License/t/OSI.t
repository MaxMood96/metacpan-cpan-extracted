use v5.40;

use Test2::V0;
use Test2::Require::Module 'Regexp::Pattern::License' => '3.9.0';

use Path::Tiny;

use lib 't/lib';
use Uncruft;

use String::License;
use String::License::Naming::Custom;

my $CORPUS_DIR = 't/OSI';

plan 26;

my $naming
	= String::License::Naming::Custom->new( schemes => [qw(osi internal)] );

sub scanner ( $path, $state )
{
	my ( $expected, $string, $got, $todo );

	$expected = $path->basename('.txt');
	$string   = $path->slurp_utf8;
	$got      = String::License->new(
		string => $string,
		naming => $naming,
	)->as_text;

	like $got, $expected, "Corpus file $path";
}

path($CORPUS_DIR)->visit( \&scanner );

done_testing;
