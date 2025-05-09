package Locale::CLDR::Transformations::Any::It::Ja;
# This file auto generated from Data\common\transforms\it-ja.xml
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
				{
					from => q(Any),
					to => q(Lower),
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
					replace => q(([bcdfghjklmnpqrstvwxyz])\'),
					result  => q(),
					revisit => 2,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(\'),
					result  => q(),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(cqu),
					result  => q(ック),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(cc),
					result  => q(ッ),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(ca),
					result  => q(カ),
					revisit => 0,
				},
				{
					before  => q(ッ),
					after   => q(),
					replace => q(cia),
					result  => q(チャ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(cio),
					result  => q(チョ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(ci),
					result  => q(チ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(cu),
					result  => q(ク),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(ce),
					result  => q(チェ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(co),
					result  => q(コ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(cha),
					result  => q(シャ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(chi),
					result  => q(キ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(chu),
					result  => q(チュ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(che),
					result  => q(ケ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(cho),
					result  => q(チョ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(gg),
					result  => q(ッ),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(ghi),
					result  => q(ギ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(ghe),
					result  => q(ゲ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(ghu),
					result  => q(グ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(gli),
					result  => q(),
					revisit => 2,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(gna),
					result  => q(ニャ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(gni),
					result  => q(ニ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(gnu),
					result  => q(ヌ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(gne),
					result  => q(ニェ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(gno),
					result  => q(ニョ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(ga),
					result  => q(ガ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(gia),
					result  => q(ジャ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(giu),
					result  => q(ジュ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(gio),
					result  => q(ジョ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(gi),
					result  => q(ジ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(gu),
					result  => q(グ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(ge),
					result  => q(ジェ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(go),
					result  => q(ゴ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(rr),
					result  => q(ッ),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(ra),
					result  => q(ラ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(ri),
					result  => q(リ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(ru),
					result  => q(ル),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(re),
					result  => q(レ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(ro),
					result  => q(ロ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(ll),
					result  => q(ッ),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(la),
					result  => q(ラ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(li),
					result  => q(リ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(lu),
					result  => q(ル),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(le),
					result  => q(レ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(lo),
					result  => q(ロ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(tt),
					result  => q(ッ),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(ta),
					result  => q(タ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(ti),
					result  => q(ティ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(thi),
					result  => q(ティ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(tu),
					result  => q(トゥ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(thu),
					result  => q(トゥ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(te),
					result  => q(テ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(the),
					result  => q(テ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(to),
					result  => q(ト),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(tho),
					result  => q(ト),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(tzu),
					result  => q(),
					revisit => 2,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(tz),
					result  => q(),
					revisit => 2,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(dd),
					result  => q(ッ),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(da),
					result  => q(ダ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(di),
					result  => q(ディ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(du),
					result  => q(ドゥ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(de),
					result  => q(デ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(do),
					result  => q(ド),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(ma),
					result  => q(マ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(mi),
					result  => q(ミ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(mu),
					result  => q(ム),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(me),
					result  => q(メ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(mo),
					result  => q(モ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q([bcdfghjklmnpqrstvwxyz]),
					replace => q(m),
					result  => q(ン),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(na),
					result  => q(ナ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(ni),
					result  => q(ニ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(nu),
					result  => q(ヌ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(ne),
					result  => q(ネ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(no),
					result  => q(ノ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(ff),
					result  => q(ッ),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(fa),
					result  => q(ファ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(fi),
					result  => q(フィ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(fu),
					result  => q(フ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(fe),
					result  => q(フェ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(fo),
					result  => q(フォ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(bb),
					result  => q(ッ),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(ba),
					result  => q(バ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(bi),
					result  => q(ビ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(bu),
					result  => q(ブ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(be),
					result  => q(ベ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(bo),
					result  => q(ボ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(pp),
					result  => q(ッ),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(pa),
					result  => q(パ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(pi),
					result  => q(ピ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(pu),
					result  => q(プ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(pe),
					result  => q(ペ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(po),
					result  => q(ポ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(vv),
					result  => q(ッ),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(va),
					result  => q(ヴァ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(vi),
					result  => q(ヴィ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(vu),
					result  => q(ヴ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(ve),
					result  => q(ヴェ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(vo),
					result  => q(ヴォ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(nt[ao]),
					replace => q(sa),
					result  => q(サ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(ss),
					result  => q(ッ),
					revisit => 3,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(sb),
					result  => q(ズ),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(sd),
					result  => q(ズ),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(sg),
					result  => q(ズ),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(sl),
					result  => q(ズ),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(sm),
					result  => q(ズ),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(sn),
					result  => q(ズ),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(sr),
					result  => q(ズ),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(sv),
					result  => q(ズ),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q([aeiou]),
					replace => q(([bcdfghjklmnpqrstvwxyz])s),
					result  => q(),
					revisit => 5,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(\~sa),
					result  => q(サ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(\~si),
					result  => q(シ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(\~su),
					result  => q(ス),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(\~se),
					result  => q(セ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(\~so),
					result  => q(ソ),
					revisit => 0,
				},
				{
					before  => q(\p{^Letter}),
					after   => q(),
					replace => q(sa),
					result  => q(サ),
					revisit => 0,
				},
				{
					before  => q(\p{^Letter}),
					after   => q(),
					replace => q(si),
					result  => q(シ),
					revisit => 0,
				},
				{
					before  => q(\p{^Letter}),
					after   => q(),
					replace => q(su),
					result  => q(ス),
					revisit => 0,
				},
				{
					before  => q(\p{^Letter}),
					after   => q(),
					replace => q(se),
					result  => q(セ),
					revisit => 0,
				},
				{
					before  => q(\p{^Letter}),
					after   => q(),
					replace => q(so),
					result  => q(ソ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(sa),
					result  => q(ザ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(si),
					result  => q(ジ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(su),
					result  => q(ズ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(se),
					result  => q(ゼ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(so),
					result  => q(ゾ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(scia),
					result  => q(シャ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(sci),
					result  => q(シ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(sce),
					result  => q(シェ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(zz),
					result  => q(ッ),
					revisit => 3,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(([bcdfghjklmnpqrstvwxyz])z),
					result  => q(),
					revisit => 5,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(\~za),
					result  => q(ツァ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(\~zi),
					result  => q(ツィ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(\~zu),
					result  => q(ツ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(\~ze),
					result  => q(ツェ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(\~zo),
					result  => q(ツォ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(za),
					result  => q(ザ),
					revisit => 0,
				},
				{
					before  => q(\p{^Letter}),
					after   => q(),
					replace => q(zi),
					result  => q(ジ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(zi),
					result  => q(ツィ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(zu),
					result  => q(ズ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(ze),
					result  => q(ゼ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(zo),
					result  => q(ゾ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(ja),
					result  => q(ヤ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(je),
					result  => q(イェ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(j),
					result  => q(),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(a),
					result  => q(ア),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(i),
					result  => q(イ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(u),
					result  => q(ウ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(e),
					result  => q(エ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(o),
					result  => q(オ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(b),
					result  => q(ブ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(c),
					result  => q(ク),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(d),
					result  => q(ド),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(f),
					result  => q(フ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(g),
					result  => q(グ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(h),
					result  => q(),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(k),
					result  => q(),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(l),
					result  => q(ル),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(m),
					result  => q(ム),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(n),
					result  => q(ン),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(p),
					result  => q(プ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(q),
					result  => q(),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(r),
					result  => q(ル),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(s),
					result  => q(ス),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(t),
					result  => q(ト),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(v),
					result  => q(ヴ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(x),
					result  => q(),
					revisit => 2,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(y),
					result  => q(),
					revisit => 1,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(z),
					result  => q(ツ),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(\'),
					result  => q(・),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(\-),
					result  => q(＝),
					revisit => 0,
				},
				{
					before  => q(),
					after   => q(),
					replace => q(\p{Nonspacing_Mark}),
					result  => q(),
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
