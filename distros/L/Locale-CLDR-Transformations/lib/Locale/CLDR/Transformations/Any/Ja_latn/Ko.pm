package Locale::CLDR::Transformations::Any::Ja_latn::Ko;
# This file auto generated from Data\common\transforms\ja_Latn-ko.xml
#	on Fri 17 Jan 12:03:31 pm GMT

use strict;
use warnings;
use version;

our $VERSION = version->declare('v0.46.0');

use v5.12.0;
use mro 'c3';
use utf8;
use feature 'unicode_strings';
use Types::Standard qw( Str Int HashRef ArrayRef CodeRef RegexpRef );
use Moo;

BEGIN {
	die "Transliteration requires Perl 5.18 or above"
		unless $^V ge v5.18.0;
}

no warnings 'experimental::regex_sets';
has 'transforms' => (
	is => 'ro',
	isa => ArrayRef,
	init_arg => undef,
	default => sub { [
		qr/(?^um:\G.)/,
		{
			type => 'transform',
			data => [
				{
					from => q(Any),
					to => q(NFD),
				},
			],
		},
		{
			type => 'filter',
			data => [
			],
		},
		{
			type => 'conversion',
			data => [
				{
					before  => q(),
					after   => q(),
					replace => q([\-\']),
					result  => q(),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(e[̂̄]),
					result  => q(),
					revisit => 2,
				},
				{
					before  => q(),
					after   => q(),
					replace => q([̂̄]),
					result  => q(),
					revisit => 0,
				},
				{
					before  => q([^[ᄀᄁᄂᄃᄄᄅᄆᄇᄈᄉᄊᄋᄌᄍᄎᄏᄐᄑᄒ]]),
					after   => q(),
					replace => q(([aiueoyw])),
					result  => q(ᄋ),
					revisit => 2,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(a),
					result  => q(ᅡ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(i\~e),
					result  => q(),
					revisit => 2,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(i),
					result  => q(ᅵ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(u\~a),
					result  => q(),
					revisit => 2,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(u\~i),
					result  => q(ᅱ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(u\~e),
					result  => q(ᅰ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(u\~o),
					result  => q(ᅯ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(u),
					result  => q(ᅮ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(e),
					result  => q(ᅦ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(o),
					result  => q(ᅩ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(kk),
					result  => q(ᆺ),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(ss),
					result  => q(ᆺ),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(tt),
					result  => q(ᆺ),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(tc),
					result  => q(ᆺ),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(cc),
					result  => q(ᆺ),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(hh),
					result  => q(ᆺ),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(ff),
					result  => q(ᆺ),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(rr),
					result  => q(ᆺ),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(gg),
					result  => q(ᆺ),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(zz),
					result  => q(ᆺ),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(jj),
					result  => q(ᆺ),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(dd),
					result  => q(ᆺ),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(bb),
					result  => q(ᆺ),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(vv),
					result  => q(ᆺ),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(pp),
					result  => q(ᆺ),
					revisit => 1,
				},
				{
					before  => q(\'),
					after   => q(),
					replace => q(k),
					result  => q(),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(^k),
					result  => q(),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(k),
					result  => q(ᄏ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(sh),
					result  => q(),
					revisit => 2,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(su),
					result  => q(스),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(s),
					result  => q(ᄉ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(te\~),
					result  => q(),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(to\~),
					result  => q(),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(tsu\~),
					result  => q(),
					revisit => 2,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(tsu),
					result  => q(쓰),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(ts),
					result  => q(),
					revisit => 2,
				},
				{
					before  => q(\'),
					after   => q(),
					replace => q(t),
					result  => q(),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(^t),
					result  => q(),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(t),
					result  => q(ᄐ),
					revisit => 0,
				},
				{
					before  => q(\'),
					after   => q(),
					replace => q(ch),
					result  => q(),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(^ch),
					result  => q(),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(ch),
					result  => q(ᄎ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q([\ \'bcdfghjkmnprstwz]),
					replace => q(n),
					result  => q(ᆫ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(n$),
					result  => q(ᆫ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(n),
					result  => q(ᄂ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(h),
					result  => q(ᄒ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(fu\~),
					result  => q(),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(fu),
					result  => q(),
					revisit => 2,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(f),
					result  => q(),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q([bmp]),
					replace => q(m),
					result  => q(ᆫ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(m),
					result  => q(ᄆ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(ya),
					result  => q(ᅣ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(yi),
					result  => q(ᅵ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(yu),
					result  => q(ᅲ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(ye),
					result  => q(ᅨ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(yo),
					result  => q(ᅭ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(r),
					result  => q(ᄅ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(wa),
					result  => q(ᅪ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(w),
					result  => q(),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(g),
					result  => q(ᄀ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(zu),
					result  => q(즈),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(z),
					result  => q(),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(j),
					result  => q(ᄌ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(de\~),
					result  => q(),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(dji\~),
					result  => q(),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(dji),
					result  => q(),
					revisit => 2,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(do\~),
					result  => q(),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(dzu\~),
					result  => q(),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(dzu),
					result  => q(),
					revisit => 2,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(dz),
					result  => q(),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(d),
					result  => q(ᄃ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(b),
					result  => q(ᄇ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(vu\~),
					result  => q(),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(v),
					result  => q(),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(p),
					result  => q(ᄑ),
					revisit => 0,
				},
			],
		},
		{
			type => 'transform',
			data => [
				{
					from => q(Any),
					to => q(NFC),
				},
			]
		},
	] },
);

no Moo;

1;

# vim: tabstop=4
