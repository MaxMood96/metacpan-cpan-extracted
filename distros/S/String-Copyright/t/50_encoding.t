use v5.40;
use utf8;

use Test2::V0;

use lib 't/lib';
use Test2::Require::WorkingUtf8;

use Encode qw(decode encode is_utf8);
use Log::Any::Test;
use Log::Any qw($log);

use String::Copyright;

my $BW  = "Björn Müller";
my $CJK = "大森紀人";

subtest 'clean UTF-8 © statement (control)' => sub {
	my $c = copyright("Copyright © 1999 $BW");
	like "$c", qr/©/;
	like "$c", qr/1999/;
	like "$c", qr/$BW/;
};

subtest 'FIXME: latin1-© and utf8-© both succeed once decoded' => sub {
	is decode( 'UTF-8',  "\xC2\xA9" ), "\x{00A9}", 'utf8 ©  -> ©';
	is decode( 'latin1', "\xA9" ),     "\x{00A9}", 'latin1 © -> ©';
	for my $s (
		decode(
			'UTF-8',
			encode( 'UTF-8', "Copyright \x{00A9} 1999 $BW" )
		),
		decode(
			'latin1',
			encode( 'latin1', "Copyright \x{00A9} 1999 $BW" )
		),
		)
	{
		my $c = copyright($s);
		like "$c", qr/1999/,           'year kept';
		like "$c", qr/Björn Müller/, 'owner kept';
	}
};

subtest 'FIXME: double-byte owner names succeed' => sub {
	my $c = copyright("Copyright 2001 $CJK");
	like "$c", qr/2001/;
	like "$c", qr/$CJK/;
};

subtest 'FIXME: double-byte merged lines normalized per line' => sub {
	my $c = copyright("© 1999 $BW\nCopyright 2001 $CJK");
	my @l = split /\n/, "$c";
	is scalar @l, 2, 'two output lines';
	like $l[0], qr/1999/;
	like $l[1], qr/2001/;
};

subtest 'FIXME: double-byte whitespace / exotic marker cleanup' => sub {
	my $c = copyright("Copyright  1999  大森 紀人  ");
	unlike "$c", qr/\s{2,}/, 'extra whitespace collapsed';
};

subtest 'sign-soup normalized: UTF-8 © read as latin1 (Â©) becomes ©' =>
	sub {
	my $mojibake = decode 'iso-8859-1', encode( 'UTF-8', "© 1999 $BW" );
	ok is_utf8($mojibake), 'input is a decoded character string';
	diag "mojibake input: $mojibake";

	my $c = copyright("Copyright $mojibake");
	ok( length "$c", 'statement detected (non-empty output)' );
	like "$c",   qr/©/,   'sign soup normalized to a clean ©';
	like "$c",   qr/1999/, 'year still present in output';
	unlike "$c", qr/Â/,   'stray mojibake accent gone';
	};

subtest 'wrongly UTF-8-tagged content still parses as a statement' => sub {
	my $bad = decode 'iso-8859-1', encode( 'UTF-8', "Copyright 2001 $CJK" );
	my $c   = copyright($bad);
	ok( length "$c", 'statement still detected' );
	diag "parsed: $c";
};

subtest 'UTF-8 © mis-read as latin1 ("Â©") normalizes to ©' => sub {
	my $c = copyright("Copyright \xC2\xA9 1999 $BW");   # "Â©", latin1 chars
	like "$c", qr/©/, 'UTF-8-latin1 soup -> ©';
	like "$c", qr/1999/;
};

subtest 'EUC-JP © ("¡¤") normalizes to ©' => sub {
	my $c = copyright("Copyright \xA1\xA4 1999 $BW");
	like "$c", qr/©/, 'EUC-JP soup -> ©';
	like "$c", qr/1999/;
};

subtest 'Shift-JIS/CP932 © (C1 controls) normalizes to ©' => sub {
	my $c = copyright("Copyright \x81\x98 1999 $BW");
	like "$c", qr/©/, 'Shift-JIS soup -> ©';
	like "$c", qr/1999/;
};

subtest 'GBK © ("¢©") normalizes to ©' => sub {
	my $c = copyright("Copyright \xA2\xA9 1999 $BW");
	like "$c", qr/©/, 'GBK soup -> ©';
	like "$c", qr/1999/;
};

subtest 'bare © byte (\xA9) is not double-normalized' => sub {
	my $s = "Copyright \xA9 1999 $BW";    # already the char U+00A9
	my $c = copyright($s);
	like "$c", qr/©/;                    # one clean ©, no doubling
	unlike "$c", qr/©\s*©/, 'no doubled sign';
};

subtest 'lone soup byte pair does not trigger a copyright (guarded)' => sub {
	for my $s ( "\xA1\xA4", "\x81\x98" ) {
		my $c = copyright("Some prose with $s and no sign context");

		# no label, no real glyph -> soup must not become a sign
		ok( defined($c), 'no crash on lone soup' );
		my $out = defined $c ? "$c" : '';
		unlike $out, qr/©/, 'no fabricated © from lone soup';
	}
};

subtest 'debug fires when soup is normalized (label present)' => sub {
	$log->clear;
	copyright("Copyright \xA1\xA4 1999 $BW");
	$log->contains_ok(
		qr/normalized copyright string/i,
		'warn describes soup'
	);
	$log->clear;
};

subtest 'no warn on clean input (hot path stays silent)' => sub {
	$log->clear;
	copyright("Copyright © 1999 $BW");
	$log->does_not_contain_ok(
		qr/normalized copyright string/i,
		'no warn on clean input'
	);
	$log->clear;
};

subtest 'dash-soup normalized: year ranges get a clean hyphen' => sub {
	my @soup = (
		[ "\x{E2}\x{80}\x{93}",       'EN-DASH, UTF-8 as Latin-1' ],
		[ "\x{E2}\x{80}\x{94}",       'EM-DASH, UTF-8 as Latin-1' ],
		[ "\x{E2}\x{20AC}\x{201C}",   'EN-DASH, UTF-8 as CP1252' ],
		[ "\x{E2}\x{20AC}\x{201D}",   'EM-DASH, UTF-8 as CP1252' ],
		[ "\x{0432}\x{0402}\x{2019}", 'EN-DASH, UTF-8 as CP1251' ],
		[ "\x{0432}\x{0402}\x{201D}", 'EM-DASH, UTF-8 as CP1251' ],
	);
	for my $pair (@soup) {
		my ( $soup, $what ) = @$pair;
		my $c = copyright("Copyright 1999${soup}2000 $BW");
		like "$c",   qr/1999-2000/, "$what -> hyphenated range";
		unlike "$c", qr/\Q$soup\E/, "$what bytes gone";
		ok length($c), 'statement still detected';
	}
};

subtest 'lone dash-soup does not fabricate a copyright (guarded)' => sub {
	for my $s ( "\x{E2}\x{80}\x{93}", "\x{E2}\x{20AC}\x{201C}" ) {
		my $c = copyright("Some prose with $s and no sign context");
		ok( defined($c), 'no crash on lone dash-soup' );
		my $out = defined $c ? "$c" : '';
		unlike $out, qr/©/, 'no fabricated © from lone dash-soup';
	}
};

subtest 'warn fires when dash-soup is normalized' => sub {
	$log->clear;
	copyright("Copyright 1999\x{E2}\x{80}\x{93}2000 $BW");
	$log->contains_ok(
		qr/normalized copyright string/i,
		'debug describes the normalization'
	);
	$log->clear;
};

done_testing;
