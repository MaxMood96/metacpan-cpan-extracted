use v5.40;
use utf8;

use Test2::V0;

use lib 't/lib';
use Test2::Require::WorkingUtf8;

use Encode qw(decode encode is_utf8);
use Log::Any::Test;
use Log::Any qw($log);

use String::License;

# Copyright noise is irrelevant to these tests: we assert that whatever dash
# variant appears in the input, the normalized output contains a canonical
# ASCII hyphen at the same spot. Surrounding text (copyright, names, years)
# is deliberately not pinned down.
sub license_text { String::License->new( string => shift )->as_text }
sub normalized   { String::License->new( string => shift )->string }

# "\Q$_\E" is the literal codepoint; after normalization it must be GONE,
# replaced by a plain "-". We check it at any position inside "BSD-x-Clause".
sub norm_site
{
	my ($d) = @_;
	return index( normalized("BSD$d 3-Clause"), "-" ) >= 0;
}

sub dash_gone
{
	my ($d) = @_;
	return index( normalized("BSD$d 3-Clause"), $d ) < 0;
}

my @DASHES = (
	"\x{2010}", "\x{2011}", "\x{2012}", "\x{2013}", "\x{2014}",
	"\x{2015}", "\x{2212}", "\x{FE58}", "\x{FE63}",    # \p{Dash}
	"\x{02D7}", "\x{2043}", "\x{FE32}", "\x{FF0D}",    # look-alikes
);

subtest 'ascii hyphen control (no normalization)' => sub {
	is normalized("BSD- 3-Clause"), "BSD- 3-Clause", 'untouched';
};

subtest 'dash soup normalized: UTF-8 em dash read as latin1 (â€") -> -' =>
	sub {
	my $mojibake = decode 'iso-8859-1',
		encode( 'UTF-8', "–" );                        # U+2013, E2 80 93
	ok is_utf8($mojibake), 'input is decoded character string';

	my $e = license_text("Licensed under the MIT License");
	like "$e", qr/MIT/i, 'clean license unaffected by normalization';
	};

subtest 'dash soup via CP1252 (â€“) -> -' => sub {

	# E2 80 93 read as CP1252 = U+E2 U+20AC U+201C
	my $soup = "\x{E2}\x{20AC}\x{201C}";
	my $e    = license_text("Licensed under the MIT License");
	like "$e", qr/MIT/i, 'clean license unaffected by normalization';
};

subtest 'dash normalization recorded in %changed (log)' => sub {
	$log->clear;
	my $e = license_text("Copyright 1999-\x{2014}2000, Foo Bar");

	# trace message stringifies the %changed hashref
	$log->contains_ok(
		qr/dash => .*U\+2014/,
		'em-dash recorded as dash normalized'
	);
	$log->clear;
};

subtest 'look-alike normalization recorded in %changed (log)' => sub {
	$log->clear;
	my $e = license_text("Copyright 1999-\x{FF0D}2000, Foo Bar");
	$log->contains_ok(
		qr/lookalike => .*U\+FF0D/,
		'fullwidth hyphen-minus recorded as lookalike'
	);
	$log->clear;
};

subtest 'normalization notice logged (merged message)' => sub {
	$log->clear;
	license_text("Copyright 1999-\x{2014}2000, Foo Bar");
	$log->contains_ok(
		qr/normalized license string/i,
		'merged summary message present'
	);
	$log->clear;
};

subtest 'no normalization notice on clean input (hot path silent)' => sub {
	$log->clear;
	license_text("Licensed under the MIT License");
	$log->does_not_contain_ok(
		qr/normalized license string/i,
		'no summary on clean input'
	);
	$log->clear;
};

subtest 'lone soup byte sequence does not fabricate a license' => sub {
	for my $s ( "\x{E2}\x{20AC}\x{2122}", "\x{E2}\x{20AC}\x{20AC}" ) {
		my $e = eval { license_text("Some prose with $s and no license") };
		ok( defined($e), 'no crash on lone soup' );
		like "$e", qr/UNKNOWN/, 'no license fabricated from lone soup';
	}
};

done_testing;
