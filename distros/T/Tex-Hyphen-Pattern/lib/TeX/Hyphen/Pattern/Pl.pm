## no critic qw(RequirePodSections)    # -*- cperl -*-
# This file is auto-generated by the Perl TeX::Hyphen::Pattern Suite hyphen
# pattern catalog generator. This code generator comes with the
# TeX::Hyphen::Pattern module distribution in the tools/ directory
#
# Do not edit this file directly.

package TeX::Hyphen::Pattern::Pl 0.100;
use strict;
use warnings;
use 5.014000;
use utf8;

use Moose;

my $pattern_file = q{};
while (<DATA>) {
    $pattern_file .= $_;
}

sub data {
    return $pattern_file;
}

sub version {
    return $TeX::Hyphen::Pattern::Pl::VERSION;
}

1;
## no critic qw(RequirePodAtEnd RequireASCII ProhibitFlagComments)

=encoding utf8

=head1 C<Pl> hyphenation pattern class

=head1 SUBROUTINES/METHODS

=over 4

=item $pattern-E<gt>data();

Returns the pattern data.

=item $pattern-E<gt>version();

Returns the version of the pattern package.

=back

=head1 Copyright

The copyright of the patterns is not covered by the copyright of this package
since this pattern is generated from the source at
L<svn://tug.org/texhyphen/trunk/hyph-utf8/tex/generic/hyph-utf8/patterns/tex/hyph-pl.tex>

The copyright of the source can be found in the DATA section in the source of
this package file.

=cut

__DATA__
% This file is part of hyph-utf8 package and resulted from
% semi-manual conversions of hyphenation patterns into UTF-8 in June 2008.
%
% Source: plhyph.tex (1995-06-26)
% Author: Hanna Kołodziejska, Bogusław Jackowski, Marek Ryćko
%
% The above mentioned file should become obsolete,
% and the author of the original file should preferably modify this file instead.
%
% Modifications were needed in order to support native UTF-8 engines,
% but functionality (hopefully) didn't change in any way, at least not intentionally.
% This file is no longer stand-alone; at least for 8-bit engines
% you probably want to use loadhyph-foo.tex (which will load this file) instead.
%
% Modifications were done by Jonathan Kew, Mojca Miklavec & Arthur Reutenauer
% with help & support from:
% - Karl Berry, who gave us free hands and all resources
% - Taco Hoekwater, with useful macros
% - Hans Hagen, who did the unicodification of patterns already long before
%               and helped with testing, suggestions and bug reports
% - Norbert Preining, who tested & integrated patterns into TeX Live
%
% However, the "copyright/copyleft" owner of patterns remains the original author.
%
% The copyright statement of this file is thus:
%
%    Do with this file whatever needs to be done in future for the sake of
%    "a better world" as long as you respect the copyright of original file.
%    If you're the original author of patterns or taking over a new revolution,
%    plese remove all of the TUG comments & credits that we added here -
%    you are the Queen / the King, we are only the servants.
%
% If you want to change this file, rather than uploading directly to CTAN,
% we would be grateful if you could send it to us (http://tug.org/tex-hyphen)
% or ask for credentials for SVN repository and commit it yourself;
% we will then upload the whole "package" to CTAN.
%
% Before a new "pattern-revolution" starts,
% please try to follow some guidelines if possible:
%
% - \lccode is *forbidden*, and I really mean it
% - all the patterns should be in UTF-8
% - the only "allowed" TeX commands in this file are: \patterns, \hyphenation,
%   and if you really cannot do without, also \input and \message
% - in particular, please no \catcode or \lccode changes,
%   they belong to loadhyph-foo.tex,
%   and no \lefthyphenmin and \righthyphenmin,
%   they have no influence here and belong elsewhere
% - \begingroup and/or \endinput is not needed
% - feel free to do whatever you want inside comments
%
% We know that TeX is extremely powerful, but give a stupid parser
% at least a chance to read your patterns.
%
% For more unformation see
%
%    http://tug.org/tex-hyphen
%
%------------------------------------------------------------------------------
%
% This is PLHYPH.TeX - the Polish hyphenation patterns
%          version 3.0a, Wednesday, May 17th, 1995
% to be used for the inclusion of Polish hyphenation patterns in any format,
% not necessarily in the MeX or LaMeX ones. The patterns are exactly
% the same as in the version 3.0 being the part of the MeX package,
% only the surrounding of the \pattern command is changed. The authors
% claim the upward compatibility, i.e., the version 3.0a can also be used
% with the MeX or LaMeX formats.

% The history of development of the Polish hyphenation patterns:
%
% The first version of the patterns was developed
% by Hanna Kołodziejska (1987).
%
% The adaptation to the LeX format (see below) and extensive modification
% were done by Bogusław Jackowski & Marek Ryćko (1987--1989).
%
% The hyphenation rules were further improved and adapted to the
% TeX 3.x requirements by Hanna Kołodziejska (1991).
%
% Lone-standing version (3.0a) of patterns was prepared (under pressure
% from LaTeX users) by Bogusław Jackowski and Marek Ryćko, following
% Mariusz Olko's suggestions, 1995.

% The LeX format mentioned above was the first version of the adaptation
% of TeX to the Polish language. The next version is called MeX.

\patterns{
.ćć8
.ćł8
.ćń8
.ćś8
.ćź8
.ćż8
.ć8
.ćb8
.ćc8
.ćd8
.ćf8
.ćg8
.ćh8
.ćj8
.ćk8
.ćl8
.ćm8
.ćn8
.ćp8
.ćr8
.ćs8
.ćt8
.ćv8
.ćw8
.ćwier2ć3
.ćx8
.ćz8
.łć8
.łł8
.łń8
.łś8
.łź8
.łż8
.ł8
.łb8
.łc8
.łd8
.łf8
.łg8
.łh8
.łj8
.łk8
.łl8
.łm8
.łn8
.łp8
.łr8
.łs8
.łt8
.łv8
.łw8
.łx8
.łz8
.ńć8
.ńł8
.ńń8
.ńś8
.ńź8
.ńż8
.ń8
.ńb8
.ńc8
.ńd8
.ńf8
.ńg8
.ńh8
.ńj8
.ńk8
.ńl8
.ńm8
.ńn8
.ńp8
.ńr8
.ńs8
.ńt8
.ńv8
.ńw8
.ńx8
.ńz8
.ść8
.śł8
.śń8
.śś8
.śź8
.śż8
.ś8
.śb8
.śc8
.śd8
.śf8
.śg8
.śh8
.śj8
.śk8
.śl8
.śm8
.śn8
.śp8
.śró2d5
.śródr2
.śr8
.śs8
.śt8
.śv8
.św8
.światło3w2
.śx8
.śz8
.źć8
.źł8
.źń8
.źś8
.źź8
.źż8
.ź8
.źb8
.źc8
.źdź8
.źd8
.źf8
.źg8
.źh8
.źj8
.źk8
.źl8
.źm8
.źn8
.źp8
.źr8
.źs8
.źt8
.źv8
.źw8
.źx8
.źz8
.żć8
.żł8
.żń8
.żś8
.żź8
.żż8
.ż8
.żb8
.żc8
.żd8
.żf8
.żg8
.żh8
.żj8
.żk8
.żl8
.żm8
.żn8
.żp8
.żr8
.żs8
.żt8
.żv8
.żw8
.żx8
.żz8
.a2b2s3t
.a2d3
.ad4a
.ad4e
.ad4i
.ad4o
.ad4u
.ad4y
.ad5apt
.ad5iu
.ad5op
.ad5or
.ae3ro
.aeroa2
.aeroe2
.aeroi2
.aeroo2
.aerou2
.antya2
.antye2
.antyi2
.antyo2
.antyu2
.arcy3ł2
.arcy3b2
.arcy3bz2
.arcy3k2
.arcy3m2
.arcya2
.arcye2
.arcyi2
.arcyo2
.arcyu2
.au3g2
.au3k2
.au3t2
.auto3ch2
.autoa2
.autoe2
.autoi2
.autoo2
.autotran2s3
.autou2
.bć8
.bł8
.bń8
.bś8
.bź8
.bż8
.b8
.bb8
.bc8
.bd8
.be2z3
.be3z4an
.be3z4ec
.be3z4ik
.bezch2
.bezm2
.bezo2
.bezo2b1j
.bezw2
.bezzw2
.bf8
.bg8
.bh8
.bj8
.bk8
.bl8
.bm8
.bn8
.bp8
.br8
.brz8
.bs8
.bt8
.bv8
.bw8
.bx8
.bz8
.cć8
.cł8
.cń8
.cś8
.cź8
.cż8
.c8
.cało3ś2
.cało3k2
.cb8
.cc8
.cd8
.cf8
.cg8
.ch8
.chrz8
.cienko3w2
.ciepło3kr2
.cj8
.ck8
.cl8
.cm8
.cn8
.cp8
.cr8
.cs8
.ct8
.cv8
.cw8
.cx8
.cz8
.czarno3k2
.czk8
.cztere2ch3
.czterechse2t3
.cztero3ś2
.czwó2r3
.czwó3r4ą
.czwó3r4ę
.czwó3r4a
.czwó3r4e
.czwó3r4o
.dć8
.dł8
.długo3tr2
.długo3w2
.dń8
.dś8
.dź8
.dż8
.d8
.daleko3w2
.db8
.dc8
.dd8
.de2z3
.de3z4a3bil
.de3z4a3wu
.de3z4el
.de3z4er
.de3z4y
.deza2
.dezo2
.df8
.dg8
.dh8
.dj8
.dk8
.dl8
.dm8
.dn8
.do3ć2
.do3ł2
.do3ś2
.do3ź2
.do3ż2
.do3b2
.do3c2
.do3d2
.do3f2
.do3g2
.do3h2
.do3k2
.do3l2
.do3m2
.do3p2
.do3r2
.do3s2
.do3t2
.do3w2
.do3z2
.do4ł3k
.do4k3t
.do4l3n
.do4m3k
.do4r3s
.do4w3c
.do5m4k2n
.dobr2
.dobrz2
.doch2
.docz2
.dodź2
.dodż2
.dodz2
.dogrz2
.dopch2
.doprz2
.dorż2
.dorz2
.dosch2
.dosm2
.dosz2
.dotk2
.dotr2
.dp8
.dr8
.drogo3w2
.drz8
.ds8
.dt8
.dv8
.dwó2j3
.dwó3j4ą
.dwó3j4ę
.dwó3j4a
.dwó3j4e
.dwó3j4o
.dw8
.dx8
.dy2s3
.dy2z3
.dy3s4e
.dy3s4o
.dy3s4ta
.dy3s4y
.dy3sz
.dy3z4e
.dyzu2
.dz8
.dziesięcio3ś2
.dziewięćse2t3
.dziewię2ć3
.dziewięcio3ś2
.e2k2s3
.e2m3e2s5ze2t
.e2s1e2s1ma
.e2s1ha
.e2s1t
.egoa2
.egoe2
.egoi2
.egoo2
.egou2
.eks4y
.elektroa2
.elektroe2
.elektroi2
.elektroo2
.elektrou2
.fć8
.fł8
.fń8
.fś8
.fź8
.fż8
.f8
.fb8
.fc8
.fd8
.ff8
.fg8
.fh8
.fj8
.fk8
.fl8
.fm8
.fn8
.fp8
.fr8
.fs8
.ft8
.fv8
.fw8
.fx8
.fz8
.gć8
.gł8
.gń8
.gś8
.gź8
.gż8
.g8
.gb8
.gc8
.gd8
.ge2o3
.gf8
.gg8
.gh8
.gj8
.gk8
.gl8
.gm8
.gn8
.go2u3
.gp8
.gr8
.grubo3w2
.grz8
.gs8
.gt8
.gv8
.gw8
.gx8
.gz8
.hć8
.hł8
.hń8
.hś8
.hź8
.hż8
.h8
.hb8
.hc8
.hd8
.hf8
.hg8
.hh8
.hipe2r3
.hipe3r4o
.hipera2
.hipere2
.hj8
.hk8
.hl8
.hm8
.hn8
.hp8
.hr8
.hs8
.ht8
.hv8
.hw8
.hx8
.hz8
.i2n3
.i2s3l
.i3n4ic
.i3n4o
.i3n4u
.i4n5o2k
.in4f3lan
.ino3w2
.izoa2
.izoe2
.izoi2
.izoo2
.izou2
.jć8
.jł8
.jń8
.jś8
.jź8
.jż8
.j8
.jadło3w2
.jb8
.jc8
.jd8
.jf8
.jg8
.jh8
.jj8
.jk8
.jl8
.jm8
.jn8
.jp8
.jr8
.js8
.jt8
.jv8
.jw8
.jx8
.jz8
.kć8
.kł8
.kń8
.kś8
.kź8
.kż8
.k8
.kb8
.kc8
.kd8
.kf8
.kg8
.kh8
.kilkuse2t3
.kilkuseto2
.kj8
.kk8
.kl8
.km8
.kn8
.koło3w2
.kon2t2r3
.kon3tr4a
.kon3tr4e
.kon3tr4o3l
.kon3tr4o3w
.kon3tr4y
.kon4tr5a2gi
.kon4tr5a2se
.kon4tr5a2sy
.kon4tr5a2ta
.kon4tr5adm
.kon4tr5akc
.kon4tr5alt
.kon4tr5arg
.kontro2
.kontru2
.kp8
.krótko3tr2
.krótko3w2
.kr8
.kro2ć3
.krz8
.ks8
.kt8
.kv8
.kw8
.kx8
.kz8
.lć8
.lł8
.lń8
.lś8
.lź8
.lż8
.l8
.lb8
.lc8
.ld8
.lf8
.lg8
.lh8
.lj8
.lk8
.ll8
.lm8
.ln8
.lp8
.lr8
.ls8
.lt8
.ludo3w2
.lv8
.lw8
.lx8
.lz8
.mć8
.mł8
.mń8
.mś8
.mź8
.mż8
.m8
.mb8
.mc8
.md8
.mf8
.mg8
.mh8
.mili3amp
.mj8
.mk8
.ml8
.mm8
.mn8
.możno3w2
.mp8
.mr8
.ms8
.mt8
.mv8
.mw8
.mx8
.mz8
.nć8
.nł8
.nń8
.nś8
.nź8
.nż8
.n8
.na2d2
.na2j
.na3ć2
.na3ł2
.na3ś2
.na3ź2
.na3ż2
.na3b2
.na3c2
.na3dą
.na3dę
.na3dź2
.na3d4łub
.na3d4ir
.na3d4much
.na3d4ręcz
.na3d4r2w
.na3d4repcz
.na3d4rept
.na3d4ruk
.na3d4rz
.na3d4worn
.na3daj
.na3de
.na3do
.na3dy
.na3dzi
.na3f2
.na3g2
.na3h2
.na3ją
.na3ję
.na3jazd
.na3je
.na3k2
.na3l2
.na3m2
.na3p2
.na3r2
.na3s2
.na3t2
.na3u2
.na3w2
.na3z2
.na4d3o2b2ł
.na4d3o2bojcz
.na4d3o2bowi
.na4d3o2brot
.na4d3o2drz
.na4d3o2kien
.na4d3olbrz
.na4d5rzą
.na4d5rzę
.na4d5rzecz
.na4d5rzy
.na4d5ziem
.na4f3c
.na4f3t
.na4j3e2f
.na4j3e2g
.na4j3e2k2s
.na4j3e2ko
.na4j3e2n
.na4j3e2r
.na4j3e2s
.na4j3e2w
.na4j3emf
.na4j3eu
.na4r3c
.na4r3d
.na4r3k
.na4r3r
.na4r3t
.nabrz2
.nach2
.nacz2
.nadśrod5ziem
.nad3ć2
.nad3ł2
.nad3ś2
.nad3b2
.nad3c2
.nad3d2
.nad3e2tat
.nad3f2
.nad3g2
.nad3h2
.nad3i2
.nad3j2
.nad3k2
.nad3l2
.nad3m2
.nad3n2
.nad3p2
.nad3r2
.nad3s2
.nad3t2
.nad3u2
.nad3w2
.nad5ż2
.nad5zó
.nad5z2mys
.nad5zo
.nad5zwycz
.nadch2
.nadcz2
.naddź2
.nade3ć2
.nade3ł2
.nade3ś2
.nade3ź2
.nade3ż2
.nade3b2
.nade3c2
.nade3d2
.nade3f2
.nade3g2
.nade3h2
.nade3k2
.nade3l2
.nade3m2
.nade3p2
.nade3r2
.nade3s2
.nade3t2
.nade3w2
.nade3z2
.nade4p3c
.nade4p3n
.nade4p3t
.nadech2
.nadecz2
.nadedź2
.nadedż2
.nadedz2
.naderż2
.naderz2
.nadesz2
.nadsz2
.nadtr2
.nadz2
.nagrz2
.naj3ć2
.naj3ł2
.naj3ś2
.naj3ź2
.naj3ż2
.naj3akt
.naj3au
.naj3b2
.naj3c2
.naj3d2
.naj3f2
.naj3g2
.naj3h2
.naj3i2
.naj3k2
.naj3l2
.naj3m2
.naj3o2
.naj3o2ć2
.naj3o2ł2
.naj3o2ś2
.naj3o2ź2
.naj3o2ż2
.naj3o2b2
.naj3o2c2
.naj3o2d2
.naj3o2f2
.naj3o2g2
.naj3o2h2
.naj3o2k2
.naj3o2l2
.naj3o2m2
.naj3o2p2
.naj3o2r2
.naj3o2s2
.naj3o2t2
.naj3o2w2
.naj3o2z2
.naj3p2
.naj3r2
.naj3ro2z3
.naj3s2
.naj3t2
.naj3u2
.naj3w2
.naj3z2
.najbe2z3
.najbezw2
.najch2
.najcz2
.najdź2
.najdż2
.najdo3ć2
.najdo3ł2
.najdo3ś2
.najdo3ź2
.najdo3ż2
.najdo3b2
.najdo3c2
.najdo3d2
.najdo3f2
.najdo3g2
.najdo3h2
.najdo3k2
.najdo3l2
.najdo3m2
.najdo3p2
.najdo3r2
.najdo3s2
.najdo3t2
.najdo3w2
.najdo3z2
.najdoch2
.najdocz2
.najdodź2
.najdodż2
.najdodz2
.najdorz2
.najdosz2
.najdotk2
.najdz2
.najkr2
.najob3ć2
.najob3ł2
.najob3ś2
.najob3ź2
.najob3ż2
.najob3c2
.najob3d2
.najob3f2
.najob3g2
.najob3h2
.najob3j2
.najob3k2
.najob3l2
.najob3m2
.najob3n2
.najob3p2
.najob3s2
.najob3t2
.najob3w2
.najobch2
.najobcz2
.najobdź2
.najobdż2
.najobdz2
.najobrz2
.najobsz2
.najoch2
.najocz2
.najodź2
.najod3ć2
.najod3ś2
.najod3c2
.najod3d2
.najod3f2
.najod3g2
.najod3h2
.najod3j2
.najod3k2
.najod3l2
.najod3m2
.najod3n2
.najod3p2
.najod3s2
.najod3t2
.najod3w2
.najod5ż2
.najodch2
.najodcz2
.najoddź2
.najoddż2
.najoddz2
.najodsz2
.najodz2
.najorz2
.najosz2
.najro3z4u
.najrz2
.najsm2
.najsz2
.najtk2
.najtr2
.najucz2
.najzw2
.nakr2
.napo2d2
.napo3ć2
.napo3ł2
.napo3ś2
.napo3ź2
.napo3ż2
.napo3b2
.napo3c2
.napo3f2
.napo3g2
.napo3h2
.napo3k2
.napo3l2
.napo3m2
.napo3p2
.napo3r2
.napo3s2
.napo3t2
.napo3w2
.napo3z2
.napo4m3p
.napoch2
.napocz2
.napodź2
.napodż2
.napod3d
.napomk2
.naporz2
.naposz2
.naprz2
.narż2
.naro2z3
.narz2
.nasm2
.nasz2
.natch2
.natk2
.naz3m2
.nazw2
.nb8
.nc8
.nd8
.ne2o3
.nf8
.ng8
.nh8
.nie3ć2
.nie3ł2
.nie3ś2
.nie3ź2
.nie3ż2
.nie3b2
.nie3c2
.nie3d2
.nie3f2
.nie3g2
.nie3h2
.nie3k2
.nie3l2
.nie3m2
.nie3p2
.nie3r2
.nie3s2
.nie3t2
.nie3u2
.nie3w2
.nie3z2
.nie4c3c
.nie4c3k
.nie4dź3
.nie4m3c
.nie4m3k
.niech2
.niecz2
.niedż2
.niedo3ć2
.niedo3ł2
.niedo3ś2
.niedo3ź2
.niedo3ż2
.niedo3b2
.niedo3c2
.niedo3d2
.niedo3f2
.niedo3g2
.niedo3h2
.niedo3k2
.niedo3l2
.niedo3m2
.niedo3p2
.niedo3r2
.niedo3s2
.niedo3t2
.niedo3w2
.niedo3z2
.niedobrz2
.niedoch2
.niedocz2
.niedodź2
.niedodż2
.niedodz2
.niedokr2
.niedomk2
.niedopch2
.niedorz2
.niedosz2
.niedotk2
.niedz2
.nieoć2
.nieoł2
.nieoś2
.nieoź2
.nieoż2
.nieo2
.nieob2
.nieob3ć2
.nieob3ś2
.nieob3ź2
.nieob3ż2
.nieob3c2
.nieob3d2
.nieob3f2
.nieob3g2
.nieob3h2
.nieob3j2
.nieob3k2
.nieob3m2
.nieob3p2
.nieob3s2
.nieob3w2
.nieobch2
.nieobcz2
.nieobdź2
.nieobdż2
.nieobdz2
.nieobsz2
.nieoc2
.nieoch2
.nieocz2
.nieodź2
.nieod2
.nieod3ć2
.nieod3ł2
.nieod3ś2
.nieod3c2
.nieod3d2
.nieod3f2
.nieod3g2
.nieod3h2
.nieod3j2
.nieod3k2
.nieod3l2
.nieod3n2
.nieod3p2
.nieod3s2
.nieod3t2
.nieod3wr
.nieod5ż2
.nieodch2
.nieodcz2
.nieoddź2
.nieoddż2
.nieoddz2
.nieodsz2
.nieodw2
.nieodz2
.nieof2
.nieog2
.nieoh2
.nieok2
.nieol2
.nieom2
.nieop2
.nieor2
.nieorz2
.nieos2
.nieosz2
.nieot2
.nieow2
.nieoz2
.niepo2d2
.niepo3ć2
.niepo3ł2
.niepo3ś2
.niepo3ź2
.niepo3ż2
.niepo3b2
.niepo3c2
.niepo3dź2
.niepo3d4łu
.niepo3d4much
.niepo3d4ręcz
.niepo3d4raż
.niepo3d4rap
.niepo3d4repcz
.niepo3d4rept
.niepo3d4waj
.niepo3d4woj
.niepo3do
.niepo3du
.niepo3dz2
.niepo3f2
.niepo3g2
.niepo3h2
.niepo3k2
.niepo3l2
.niepo3m2
.niepo3p2
.niepo3r2
.niepo3s2
.niepo3t2
.niepo3w2
.niepo3z2
.niepo4d3o2choc
.niepo4d3o2strz
.niepoch2
.niepocz2
.niepod3ć2
.niepod3ł2
.niepod3ś2
.niepod3b2
.niepod3c2
.niepod3d2
.niepod3f2
.niepod3g2
.niepod3h2
.niepod3j2
.niepod3k2
.niepod3l2
.niepod3m2
.niepod3n2
.niepod3p2
.niepod3r2
.niepod3s2
.niepod3t2
.niepod3w2
.niepod5ż
.niepodch2
.niepodcz2
.niepoddź2
.niepoddż2
.niepodsm2
.niepodsz2
.nieporz2
.nieposm2
.nieposz2
.nieprzełk2
.nieprze2d2
.nieprze3ć2
.nieprze3ł2
.nieprze3ś2
.nieprze3ź2
.nieprze3ż2
.nieprze3b2
.nieprze3brz2
.nieprze3c2
.nieprze3dź2
.nieprze3d4łuż
.nieprze3d4much
.nieprze3d4ramat
.nieprze3d4ruk
.nieprze3d4ryl
.nieprze3d4rz2
.nieprze3d4um
.nieprze3dy
.nieprze3dz2
.nieprze3e2k2s3
.nieprze3f2
.nieprze3g2
.nieprze3h2
.nieprze3k2
.nieprze3l2
.nieprze3m2
.nieprze3n2
.nieprze3p2
.nieprze3r2
.nieprze3s2
.nieprze3t2
.nieprze3w2
.nieprze3z2
.nieprze4d5łużyc
.nieprze4d5ż2
.nieprze4d5z2a
.nieprze4d5zg2
.nieprze4d5zim
.nieprze4d5zj
.nieprze4d5zl
.nieprze4d5zw2r
.nieprze4d5zwoj
.nieprzech2
.nieprzecz2
.nieprzed3ć2
.nieprzed3ł2
.nieprzed3ś2
.nieprzed3c2
.nieprzed3d2
.nieprzed3f2
.nieprzed3g2
.nieprzed3h2
.nieprzed3i2
.nieprzed3j2
.nieprzed3k2
.nieprzed3l2
.nieprzed3m2
.nieprzed3n2
.nieprzed3p2
.nieprzed3r2
.nieprzed3s2
.nieprzed3sz2
.nieprzed3t2
.nieprzed3u2
.nieprzed3w2
.nieprzedch2
.nieprzedcz2
.nieprzeddź2
.nieprzeddż2
.nieprzeddz2
.nieprzegrz2
.nieprzekl2
.nieprzekr2
.nieprzepch2
.nieprzerż2
.nieprzerz2
.nieprzesch2
.nieprzesm2
.nieprzesz2
.nieprzetk2
.nieprzetr2
.niero2z3
.niero3z4e
.niero3z4u
.nierozś2
.nierozbrz2
.nieroze3r2
.nierozm2
.nieroztr2
.nierz2
.niesu2b3
.niesu3b4ie
.niesz2
.nietk2
.nietr2
.nieucz2
.nieuw2
.niewy3ć2
.niewy3ł2
.niewy3ś2
.niewy3ź2
.niewy3ż2
.niewy3b2
.niewy3c2
.niewy3d2
.niewy3f2
.niewy3g2
.niewy3h2
.niewy3k2
.niewy3l2
.niewy3m2
.niewy3p2
.niewy3r2
.niewy3s2
.niewy3t2
.niewy3w2
.niewy3z2
.niewybrz2
.niewych2
.niewycz2
.niewydź2
.niewydż2
.niewydz2
.niewyrz2
.niewysz2
.niewytk2
.niewytr2
.niezw2
.nj8
.nk8
.nl8
.nm8
.nn8
.np8
.nr8
.ns8
.nt8
.nv8
.nw8
.nx8
.nz8
.oć2
.oś2
.ośmio3ś2
.oź2
.oż2
.o2b2
.o2d2
.o2t3chł
.o3b4łą
.o3b4łę
.o3b4łoc
.o3b4luzg
.o3b4rać
.o3b4raso
.o3b4roń
.o3b4ron
.o3b4ryź
.o3b4ryz
.o3b4rz2
.o3be
.o3bi
.o3d4iu
.o3d4ręt
.o3d4rap
.o3d4robin
.o3d4rut
.o3d4rwi
.o3d4rzeć
.o3d4rzw
.o3d6zia
.o3d6zie
.o3de
.o3l2śn
.o4b5łocz
.o4b5rzą
.o4b5rzęd
.o4b5rzez
.o4b5rzuc
.o4b5rzut
.o4b5rzyn
.o4d7ziar
.o4d7ziem
.oa3z
.ob3ć2
.ob3ł2
.ob3ś2
.ob3ź2
.ob3ż2
.ob3c2
.ob3d2
.ob3f2
.ob3g2
.ob3h2
.ob3j2
.ob3k2
.ob3l2
.ob3m2
.ob3n2
.ob3o2strz
.ob3p2
.ob3r
.ob3s2
.ob3t2
.ob3u2m2
.ob3w2
.obch2
.obcz2
.obdź2
.obdż2
.obdz2
.obe3ć2
.obe3ł2
.obe3ś2
.obe3ź2
.obe3ż2
.obe3b2
.obe3c2
.obe3d2
.obe3f2
.obe3g2
.obe3h2
.obe3k2
.obe3l2
.obe3m2
.obe3p2
.obe3r2
.obe3r3t
.obe3s2
.obe3t2
.obe3w2
.obe3z2
.obe4c3n
.obe4z3w
.obech2
.obecz2
.obedź2
.obedż2
.obedz2
.oberż2
.ober3m
.oberz2
.obesch2
.obesz2
.obetk2
.obi3b2
.obsz2
.oc2
.och2
.ochrz2
.ocz2
.odź2
.od3ć2
.od3ś2
.od3au
.od3b2
.od3c2
.od3d2
.od3f2
.od3g2
.od3h2
.od3i2
.od3i2zo
.od3j2
.od3k2
.od3l2
.od3m2
.od3n2
.od3o2s
.od3p2
.od3r2
.od3s2
.od3t2
.od3u2cz
.od3u2m2
.od3w2
.od5ż2
.od5z2
.odbe2z3
.odch2
.odcz2
.oddź2
.oddż2
.oddz2
.ode3ć2
.ode3ł2
.ode3ś2
.ode3ź2
.ode3ż2
.ode3b2
.ode3c2
.ode3d2
.ode3f2
.ode3g2
.ode3h2
.ode3k2
.ode3l2
.ode3m2
.ode3mk2
.ode3p2
.ode3r2
.ode3s2
.ode3t2
.ode3w2
.ode3z2
.odech2
.odecz2
.odedź2
.odedż2
.odedz2
.odepch2
.oderż2
.oderz2
.odesz2
.odetch2
.odetk2
.odkrz2
.odrz2
.odsz2
.of2
.ogólno3k2
.og2
.ognio3tr2
.oh2
.ok2
.oka3m2
.okr2
.ole2o3
.om2
.op2
.opch2
.or2ż2
.or2tę
.or2z2
.os2
.osie2m3
.osiemse2t3
.osz2
.ot2
.ow2
.oz2
.pć8
.pł8
.płasko3w2
.pń8
.półk2
.półkr2
.półm2
.póło2
.półob3r
.półom2d
.półprzy3m2k
.pó2ł3
.pó3ł4ą
.pó3ł4ę
.pó3ł4ecz
.pó3ł4y
.pś8
.pź8
.pż8
.p8
.pb8
.pc8
.pch8
.pd8
.pełno3kr2
.pe2r3
.pe3c2k
.pe3r4e
.pe3r4i
.pe3r4o
.pe3r4u
.pe3r4y
.pe4r5i2n
.pee2se2l
.pepee2r
.pepee2s
.peze2t1pee2r
.pf8
.pg8
.ph8
.pięćse2t3
.pię2ć3
.pięcio3ś2
.pierwo3w2
.piono3w2
.pj8
.pk8
.pl8
.pm8
.pn8
.połk2
.po2d2
.po3ć2
.po3ł2
.po3ś2
.po3ź2
.po3ż2
.po3b2
.po3c2
.po3dą
.po3dę
.po3dź2
.po3d4łu
.po3d4much
.po3d4naw
.po3d4ręcz
.po3d4rętw
.po3d4róż
.po3d4r2wi
.po3d4raż
.po3d4rap
.po3d4repcz
.po3d4rept
.po3d4roż
.po3d4robó
.po3d4roba
.po3d4robo
.po3d4roby
.po3d4rocz
.po3d4ruzg
.po3d4ryg
.po3d4rze
.po3d4wójn
.po3d4wór
.po3d4waj
.po3d4woi
.po3d4woj
.po3d4worz
.po3da
.po3de
.po3dej
.po3diu
.po3do
.po3du
.po3dy
.po3dz2
.po3e2k2s3
.po3f2
.po3g2
.po3h2
.po3k2
.po3l2
.po3m2
.po3p2
.po3rż
.po3r2
.po3s2
.po3t2
.po3w2
.po3z2
.po4ń3c
.po4cz3d
.po4cz3t
.po4d3ów
.po4d3e4k2s3
.po4d3o2bóz
.po4d3o2biad
.po4d3o2bojcz
.po4d3o2braz
.po4d3o2choc
.po4d3o2dm
.po4d3o2f
.po4d3o2g
.po4d3o2kien
.po4d3o2kn
.po4d3o2kręg
.po4d3o2kres
.po4d3o2piecz
.po4d3o2ryw
.po4d3o2siniak
.po4d3o2strz
.po4d3obsz
.po4d3odd
.po4d3olbrz
.po4d3u2cz
.po4d3u2dz
.po4d3u2pa
.po4d3u2ral
.po4d3u2sta
.po4d3u2szcz
.po4d5ręczn
.po4d5zakr
.po4d5zam
.po4d5zast
.po4d5zbi
.po4d5ze
.po4d5zielenią
.po4d5zielenić
.po4d5zielenię
.po4d5zielenił
.po4d5zielenic
.po4d5zielenien
.po4d5zielenil
.po4d5zielenim
.po4d5zielenio
.po4d5zielenis
.po4d5ziem
.po4d5ziom
.po4d5zw2r
.po4l3s
.po4m3p
.po4r3c
.po4r3f
.po4r3n
.po4r3t
.po4st3d
.po4st3f
.po4st3g
.po4st3h
.po4st3i2
.po4st3k
.po4st3l
.po4st3m
.po4st3p
.po4st3rom
.po4st3s
.po5d4uszczyn
.po5r4tę
.pobr2
.pobrz2
.poch2
.pochrz2
.pocz2
.pod3ć2
.pod3ł2
.pod3ś2
.pod3śró2d5
.pod3alp
.pod3b2
.pod3c2
.pod3d2
.pod3f2
.pod3g2
.pod3h2
.pod3i2n
.pod3j2
.pod3k2
.pod3l2
.pod3m2
.pod3n2
.pod3p2
.pod3r2
.pod3s2
.pod3t2
.pod3w2
.pod5ż2
.podch2
.podcz2
.poddź2
.poddż2
.pode3ć2
.pode3ł2
.pode3ś2
.pode3ź2
.pode3ż2
.pode3b2
.pode3c2
.pode3d2
.pode3f2
.pode3g2
.pode3h2
.pode3k2
.pode3l2
.pode3m2
.pode3p2
.pode3r2
.pode3s2
.pode3t2
.pode3tk2
.pode3w2
.pode3z2
.podech2
.podecz2
.podedź2
.podedż2
.podedz2
.podepch2
.poderż2
.poderz2
.podesch2
.podesz2
.podro2z3
.podsm2
.podsz2
.pogrz2
.pokl2
.pokr2
.pom4pk
.pomk2
.pona2d2
.pona3ć2
.pona3ł2
.pona3ś2
.pona3ź2
.pona3ż2
.pona3b2
.pona3c2
.pona3cz2
.pona3dź2
.pona3do
.pona3f2
.pona3g2
.pona3h2
.pona3k2
.pona3l2
.pona3m2
.pona3p2
.pona3r2
.pona3s2
.pona3t2
.pona3w2
.pona3z2
.pona4f3t
.ponabrz2
.ponach2
.ponad3ć2
.ponad3ś2
.ponad3c2
.ponad3ch2
.ponad3cz2
.ponad3dź2
.ponad3f2
.ponad3g2
.ponad3h2
.ponad3j2
.ponad3k2
.ponad3l2
.ponad3p2
.ponad3s2
.ponad3t2
.ponadz2
.ponarz2
.ponasm2
.ponasz2
.ponaz3m2
.ponazw2
.ponie3k2
.ponie3w2
.popch2
.popo3w2
.poprz2
.por4t1w
.por4tf
.por4tm
.poro2z3
.poro3z4u
.porz2
.posch2
.posm2
.posz2
.potk2
.potr2
.poz4m2
.poza3u2
.pozw2
.pp8
.pr8
.pra3s2
.pra3w2nu
.pra3w2z
.prapra3w2nu
.predy2s3po
.prz8
.przełk2
.prze2d2
.prze3ć2
.prze3ł2
.prze3ś2
.prze3ź2
.prze3ż2
.prze3b2
.prze3c2
.prze3dą
.prze3dę
.prze3dź2
.prze3d4łuż
.prze3d4much
.prze3d4o3br
.prze3d4o3st
.prze3d4o3zo
.prze3d4ramat
.prze3d4ruk
.prze3d4ryl
.prze3d4rz2
.prze3d4um
.prze3dy
.prze3dz2
.prze3e2k2s3
.prze3f2
.prze3g2
.prze3h2
.prze3k2
.prze3l2
.prze3m2
.prze3n2
.prze3p2
.prze3r2
.prze3s2
.prze3t2
.prze3u2
.prze3w2
.prze3z2
.prze4d5łużyc
.prze4d5ż2
.prze4d5o4stat
.prze4d5za
.prze4d5zg2
.prze4d5zim
.prze4d5zj
.prze4d5zl
.prze4d5zw2r
.prze4d5zwoj
.przebr2
.przebrz2
.przech2
.przechrz2
.przeci2w3
.przeci3w4ie
.przeciwa2
.przeciww2
.przecz2
.przed3ć2
.przed3ł2
.przed3ś2
.przed3a2gon
.przed3a2kc
.przed3alp
.przed3b2
.przed3c2
.przed3d2
.przed3e2gz
.przed3e2mer
.przed3f2
.przed3g2
.przed3h2
.przed3i2
.przed3j2
.przed3k2
.przed3l2
.przed3m2
.przed3n2
.przed3o2
.przed3p2
.przed3r2
.przed3s2
.przed3się3w2
.przed3sz2
.przed3t2
.przed3u2
.przed3w2
.przedch2
.przedcz2
.przeddź2
.przeddż2
.przeddz2
.przedgrz2
.przedy2s3ku
.przegrz2
.przekl2
.przekr2
.przemk2
.przepch2
.przerż2
.przerz2
.przesch2
.przesm2
.przesz2
.przetk2
.przetr2
.przetran2s3
.przy3ć2
.przy3ł2
.przy3ś2
.przy3ź2
.przy3ż2
.przy3b2
.przy3c2
.przy3d2
.przy3f2
.przy3g2
.przy3h2
.przy3k2
.przy3l2
.przy3m2
.przy3p2
.przy3r2
.przy3s2
.przy3t2
.przy3w2
.przy3z2
.przybr2
.przych2
.przycz2
.przydź2
.przydż2
.przydz2
.przygrz2
.przymk2
.przyoz2
.przypch2
.przyrż2
.przyrz2
.przysch2
.przysz2
.przytk2
.ps8
.pt8
.pv8
.pw8
.px8
.pz8
.rć8
.rł8
.rń8
.rś8
.rź8
.rż8
.r8
.rb8
.rc8
.rd8
.retran2s3
.rf8
.rg8
.rh8
.rj8
.rk8
.rl8
.rm8
.rn8
.ro2z3
.ro3z4a
.ro3z4e
.ro3z4e3ć2
.ro3z4e3ł2
.ro3z4e3ś2
.ro3z4e3ź2
.ro3z4e3ż2
.ro3z4e3b2
.ro3z4e3c2
.ro3z4e3d2
.ro3z4e3f2
.ro3z4e3g2
.ro3z4e3h2
.ro3z4e3k2
.ro3z4e3l2
.ro3z4e3m2
.ro3z4e3p2
.ro3z4e3r2
.ro3z4e3s2
.ro3z4e3t2
.ro3z4e3w2
.ro3z4e3z2
.ro3z4ej
.ro3z4u
.ro4z5a2gi
.ro4z5a2nie
.ro4z5e2mo
.ro4z5e4g3z
.ro4z5e4n3t
.rozś2
.rozbrz2
.rozd2
.rozech2
.rozecz2
.rozedź2
.rozedż2
.rozedz2
.rozepch2
.rozerż2
.rozerz2
.rozesch2
.rozesz2
.rozi2
.rozm2
.rozo2
.rozpo3w2
.rozt2
.roztr2
.rozw2
.rp8
.rr8
.rs8
.rt8
.rv8
.rw8
.rx8
.rz8
.sć8
.sł8
.sń8
.sś8
.sź8
.sż8
.s8
.samo3ch2
.samo3k2
.samo3p2
.samo3w2
.samoro2z3
.sb8
.sc8
.sch8
.sd8
.sf8
.sg8
.sh8
.siede2m3
.siedemse2t3
.siedmio3ś2
.sj8
.ską2d5że
.sk8
.skl8
.skr8
.sl8
.sm8
.sn8
.sobo3w2
.spó2ł3
.sp8
.spo2d2
.spo3ć2
.spo3ł2
.spo3ś2
.spo3ź2
.spo3ż2
.spo3b2
.spo3c2
.spo3dz2
.spo3f2
.spo3g2
.spo3h2
.spo3k2
.spo3l2
.spo3m2
.spo3p2
.spo3r2
.spo3s2
.spo3t2
.spo3w2
.spo3z2
.spo4r3n
.spo4r3t
.spoch2
.spocz2
.spodź2
.spodż2
.spod3d
.sporz2
.sposz2
.sr8
.ss8
.st8
.stere2o3
.stereoa2
.stereoe2
.stereoi2
.stereoo2
.stereou2
.su2b3
.su3b4ie
.su3b4otn
.supe2r3
.supe3r4at
.supe3r4io
.supe4r5a2tr
.super5z2b
.supere2
.supero2d1rzut
.sv8
.sw8
.sx8
.sz8
.sześćse2t3
.sześcio3ś2
.sze2ś2ć3
.sze2s3
.tć8
.tł8
.tń8
.tś8
.tź8
.tż8
.t8
.ta2o3
.ta2r7zan
.tb8
.tc8
.tch8
.td8
.te2o3
.tf8
.tg8
.th8
.tj8
.tk8
.tl8
.tm8
.tn8
.toa3
.tp8
.tró2j3
.tró3j4ą
.tró3j4ę
.tró3j4ecz
.tr8
.tran2s3
.tran3s4e
.tran3s4ie
.tran3s4y
.tran3sz
.tran4s5eu
.transa2
.transo2
.trz8
.trze2ch3
.trzechse2t3
.ts8
.tt8
.tv8
.tw8
.tx8
.tysią2c3
.tysią3c4a
.tysią3c4e
.tysią3cz
.tysią4c5zł
.tz8
.uć2
.uś2
.u3ł2
.u3ź2
.u3ż2
.u3b2
.u3c2
.u3d2
.u3f2
.u3g2
.u3h2
.u3k2
.u3l2
.u3m2
.u3n2
.u3p2
.u3r2
.u3s2
.u3t2
.u3w2
.u3z2
.u4d3k
.u4f3n
.u4k3lej
.u4l3s
.u4l3t
.u4m3br
.u4n3c
.u4n3d
.u4p3p2s
.u4r3s
.u4st3n
.u4stc
.u4stk
.u4z3be
.ube2z3
.ubezw2
.ubr2
.uch2
.ucz2
.udź2
.udż2
.udz2
.ukr2
.umk2
.upch2
.upo2d2
.upo3ć2
.upo3ł2
.upo3ś2
.upo3ź2
.upo3ż2
.upo3b2
.upo3c2
.upo3da
.upo3f2
.upo3g2
.upo3h2
.upo3k2
.upo3l2
.upo3m2
.upo3p2
.upo3r2
.upo3s2
.upo3t2
.upo3w2
.upo3z2
.upoch2
.upocz2
.upodź2
.upodż2
.upod3d
.uporz2
.uposz2
.urż2
.uro2z3
.urz2
.usch2
.usz2
.utk2
.utr2
.uze3w2
.vć8
.vł8
.vń8
.vś8
.vź8
.vż8
.v8
.vb8
.vc8
.vd8
.vf8
.vg8
.vh8
.vj8
.vk8
.vl8
.vm8
.vn8
.vp8
.vr8
.vs8
.vt8
.vv8
.vw8
.vx8
.vz8
.wć8
.wł8
.wń8
.wś8
.wź8
.wż8
.w8
.wb8
.wc8
.wd8
.we3ć2
.we3ł2
.we3ś2
.we3ż2
.we3b2
.we3c2
.we3d2
.we3f2
.we3g2
.we3h2
.we3k2
.we3l2
.we3m2
.we3n2
.we3p2
.we3r2
.we3s2
.we3t2
.we3w2
.we3z2
.we4ł3n
.we4k3t
.we4l3w
.we4n3d
.we4n3t
.we4r3b
.we4r3d
.we4r3n
.we4r3s
.we4r3t
.we4s3prz
.we4s3tch2
.we4z3br
.we4z3gł
.wech2
.wecz2
.wedź2
.wedż2
.wedz2
.wemk2
.wepch2
.werz2
.wesz2
.wetk2
.wewną2trz3
.wf8
.wg8
.wh8
.wielo3ś2
.wielo3d2
.wielo3k2
.wieluse2t3
.wilczo3m2
.wj8
.wk8
.wl8
.wm8
.wn8
.wniebo3w2
.wodo3w2
.wp8
.wr8
.ws8
.współi2
.współo2b3w
.współu2
.współw2
.wspó2ł3
.wsze2ch3
.wszecho2
.wszechw2
.wt8
.wv8
.ww8
.wx8
.wy3ć2
.wy3ł2
.wy3ś2
.wy3ź2
.wy3ż2
.wy3b2
.wy3c2
.wy3d2
.wy3f2
.wy3g2
.wy3h2
.wy3k2
.wy3l2
.wy3m2
.wy3o2d3r
.wy3p2
.wy3r2
.wy3s2
.wy3t2
.wy3w2
.wy3z2
.wy4ż3sz
.wy4cz3ha
.wybr2
.wybrz2
.wych2
.wycz2
.wydź2
.wydż2
.wydr2
.wydz2
.wye2k2s3
.wygrz2
.wyi2zo
.wykl2
.wykr2
.wykrz2
.wymk2
.wypch2
.wyprz2
.wyrż2
.wyrz2
.wysch2
.wysm2
.wysz2
.wytch2
.wytk2
.wytr2
.wz8
.xć8
.xł8
.xń8
.xś8
.xź8
.xż8
.x8
.xb8
.xc8
.xd8
.xf8
.xg8
.xh8
.xj8
.xk8
.xl8
.xm8
.xn8
.xp8
.xr8
.xs8
.xt8
.xv8
.xw8
.xx8
.xz8
.zć8
.zł8
.zło3w2
.zń8
.zś8
.zź8
.zż8
.z8
.za3ć2
.za3ł2
.za3ś2
.za3ź2
.za3ż2
.za3b2
.za3c2
.za3d2
.za3f2
.za3g2
.za3h2
.za3k2
.za3l2
.za3m2
.za3o2b3r
.za3o2b3s
.za3p2
.za3r2
.za3s2
.za3t2
.za3u2
.za3w2
.za3z2
.za4k3t
.za4l3g
.za4l3k
.za4l3t
.za4m3k
.za4r3ch
.za4uto
.za5m4k2n
.zabr2
.zabrz2
.zach2
.zacz2
.zadź2
.zadż2
.zadośću4
.zado2ść3
.zadr2
.zady2s3po
.zadz2
.zagrz2
.zai2n3
.zai2zo
.zain4ic
.zakl2
.zakr2
.zakrz2
.zanie3d2
.zarż2
.zarz2
.zasch2
.zasm2
.zasz2
.zatk2
.zatr2
.zb8
.zc8
.zd8
.zde2z3
.zde3z4awu
.zde3z4el
.zde3z4er
.zde3z4y
.zdy2s3kont
.zdy2s3kred
.zdy2s3kwal
.ze3ć2
.ze3ł2
.ze3ś2
.ze3ź2
.ze3ż2
.ze3b2
.ze3c2
.ze3d2
.ze3f2
.ze3g2
.ze3h2
.ze3k2
.ze3l2
.ze3m2
.ze3p2
.ze3r2
.ze3s2
.ze3t2
.ze3tk2
.ze3w2
.ze3z2
.ze4r3k
.ze4t3e2m1e2s
.ze4t3e2s1e2l
.ze4t3emp
.ze4t3hap
.zech2
.zecz2
.zedź2
.zedż2
.zedz2
.zekl2
.zepch2
.zerż2
.zerz2
.zesch2
.zesm4
.zesz2
.zf8
.zg8
.zh8
.zimno3kr2
.zj8
.zk8
.zl8
.zm8
.zmartwy2ch3
.zmartwychw2
.zn8
.znie3ć2
.znie3ł2
.znie3ń2
.znie3ś2
.znie3ź2
.znie3ż2
.znie3b2
.znie3c2
.znie3d2
.znie3f2
.znie3g2
.znie3h2
.znie3k2
.znie3l2
.znie3m2
.znie3n2
.znie3p2
.znie3r2
.znie3s2
.znie3t2
.znie3w2
.znie3z2
.znie4dź3
.znie4m3c
.zniech2
.zniecz2
.zniedż2
.zniedz2
.znierz2
.zniesz2
.zo2o3
.zp8
.zr8
.zro2z3
.zro3z4u
.zs8
.zt8
.zv8
.zw8
.zx8
.zz8
ą1
ę1
ó1
ó4w3cz
ś1c
ź2dź
1ś2ci
2ć1ń
2ć1ś
2ć1ź
2ć1ż
2ć1b
2ć1c
2ć1d
2ć1f
2ć1g
2ć1k
2ć1m
2ć1n
2ć1p
2ć1s
2ć1t
2ć1z
2ł1ć
2ł1ń
2ł1ś
2ł1ź
2ł1ż
2ł1b
2ł1c
2ł1d
2ł1f
2ł1g
2ł1h
2ł1j
2ł1k
2ł1l
2ł1m
2ł1n
2ł1p
2ł1r
2ł1s
2ł1t
2ł1w
2ł1z
2ń1ć
2ń1ł
2ń1ń
2ń1ś
2ń1ź
2ń1ż
2ń1b
2ń1c
2ń1d
2ń1f
2ń1g
2ń1h
2ń1j
2ń1k
2ń1l
2ń1m
2ń1n
2ń1p
2ń1r
2ń1s
2ń1t
2ń1w
2ń1z
2śćc
2ś1ś
2ś1ź
2ś1ż
2ś1b
2ś1d
2ś1f
2ś1g
2ś1k
2ś1p
2ś1s
2ś1t
2ś1z
2ślm
2śln
2ź1ć
2ź1ś
2ź1ż
2ź1b
2ź1c
2ź1d
2ź1f
2ź1g
2ź1k
2ź1l
2ź1m
2ź1n
2ź1p
2ź1s
2ź1t
2ź1w
2ź1z
2ż1ć
2ż1ł
2ż1ń
2ż1ś
2ż1ź
2ż1b
2ż1c
2ż1d
2ż1f
2ż1g
2ż1j
2ż1k
2ż1l
2ż1m
2ż1n
2ż1p
2ż1r
2ż1s
2ż1t
2ż1w
2ż1z
2błk
2b1ć
2b1ń
2b1ś
2b1ź
2b1ż
2b1c
2b1d
2b1f
2b1g
2b1k
2b1m
2b1n
2b1p
2b1s
2b1t
2b1z
2brn
2c1ć
2c1ń
2c1ś
2c1ź
2c1ż
2c1b
2c1d
2c1f
2c1g
2c1k
2c1l
2c1m
2c1n
2c1p
2c1s
2c1t
2ch1ć
2ch1ń
2ch1ś
2ch1ź
2ch1ż
2ch1b
2ch1c
2ch1d
2ch1f
2ch1g
2ch1k
2ch1m
2ch1n
2ch1p
2ch1s
2ch1t
2ch1z
2cz1ć
2cz1ń
2cz1ś
2cz1ź
2cz1ż
2cz1b
2cz1c
2cz1d
2cz1f
2cz1g
2cz1k
2cz1l
2cz1m
2cz1n
2cz1p
2cz1s
2cz1t
2cz1z
2dłb
2dłsz
2dź1ć
2dź1ń
2dź1ś
2dź1ź
2dź1ż
2dź1b
2dź1c
2dź1d
2dź1f
2dź1g
2dź1k
2dź1m
2dź1n
2dź1p
2dź1s
2dź1t
2dź1z
2dż1ć
2dż1ń
2dż1ś
2dż1ź
2dż1ż
2dż1b
2dż1c
2dż1d
2dż1f
2dż1g
2dż1k
2dż1m
2dż1n
2dż1p
2dż1s
2dż1t
2dż1z
2d1ć
2d1ń
2d1ś
2d1b
2d1c
2d1f
2d1g
2d1k
2d1m
2d1n
2d1p
2d1s
2d1t
2drn
2dz1ć
2dz1ń
2dz1ś
2dz1ź
2dz1ż
2dz1b
2dz1c
2dz1d
2dz1f
2dz1g
2dz1k
2dz1l
2dz1m
2dz1n
2dz1p
2dz1s
2dz1t
2dz1z
2f1c
2f1k
2f1m
2f1n
2głb
2g1ć
2g1ń
2g1ś
2g1ź
2g1ż
2g1b
2g1c
2g1d
2g1f
2g1k
2g1m
2g1p
2g1s
2g1t
2g1z
2h1ć
2h1ł
2h1ń
2h1ś
2h1ź
2h1ż
2h1b
2h1c
2h1d
2h1f
2h1g
2h1j
2h1k
2h1l
2h1m
2h1n
2h1p
2h1r
2h1s
2h1t
2h1w
2h1z
2j1ć
2j1ł
2j1ń
2j1ś
2j1ź
2j1ż
2j1b
2j1c
2j1d
2j1f
2j1g
2j1h
2j1k
2j1l
2j1m
2j1n
2j1p
2j1r
2j1s
2j1t
2j1w
2j1z
2kłb
2k1ć
2k1ń
2k1ś
2k1ź
2k1ż
2k1b
2k1c
2k1d
2k1f
2k1g
2k1m
2k1n
2k1p
2k1s
2k1sz
2k1t
2k1z
2l1ć
2l1ł
2l1ń
2l1ś
2l1ź
2l1ż
2l1b
2l1c
2l1d
2l1f
2l1g
2l1h
2l1j
2l1k
2l1m
2l1n
2l1p
2l1r
2l1s
2l1t
2l1w
2l1z
2m1ć
2m1ł
2m1ń
2m1ś
2m1ź
2m1ż
2m1b
2m1c
2m1d
2m1f
2m1g
2m1h
2m1j
2m1k
2m1l
2m1n
2m1p
2m1r
2m1s
2m1t
2m1w
2m1z
2n1ć
2n1ł
2n1ń
2n1ś
2n1ź
2n1ż
2n1b
2n1c
2n1d
2n1f
2n1g
2n1h
2n1j
2n1k
2n1l
2n1m
2n1p
2n1r
2n1s
2n1t
2n1w
2n1z
2ntn
2p1ć
2p1ń
2p1ś
2p1ź
2p1ż
2p1b
2p1c
2p1d
2p1f
2p1g
2p1k
2p1m
2p1n
2p1s
2p1sz
2p1t
2p1z
2pln
2r1ć
2r1ł
2r1ń
2r1ś
2r1ź
2r1ż
2r1b
2r1c
2r1d
2r1f
2r1g
2r1h
2r1j
2r1k
2r1l
2r1m
2r1n
2r1p
2r1s
2r1t
2r1w
2rz1ć
2rz1ł
2rz1ń
2rz1ś
2rz1ź
2rz1ż
2rz1b
2rz1c
2rz1d
2rz1f
2rz1g
2rz1h
2rz1j
2rz1k
2rz1l
2rz1m
2rz1n
2rz1p
2rz1r
2rz1s
2rz1t
2rz1w
2słb
2s1ź
2s1ż
2s1b
2s1d
2s1f
2s1g
2s1s
2snk
2stk
2stn
2stsz
2sz1ć
2sz1ś
2sz1c
2sz1f
2sz1k
2sz1l
2sz1m
2sz1n
2sz1p
2sz1s
2sz1t
2sz1w
2sz1z
2szln
2t1ć
2t1ń
2t1ś
2t1ź
2t1ż
2t1b
2t1c
2t1d
2t1f
2t1g
2t1k
2t1m
2t1n
2t1p
2t1s
2t1z
2tln
2trk
2trzn
2w1ć
2w1ł
2w1ń
2w1ś
2w1ź
2w1ż
2w1b
2w1c
2w1d
2w1f
2w1g
2w1j
2w1k
2w1l
2w1m
2w1n
2w1p
2w1r
2w1s
2w1t
2w1z
2z1ć
2z1ś
2z1c
2z1d
2z1f
2z1k
2z1p
2z1s
2z1t
2zdk
2zdn
3d2niow
3k2sz2t
3m2k2n
3m2nest
3m2nezj
3m2sk2n
3p2neu
3w2ład
3w2łos
3w2czas
4ć3ć
4ł3ł
4ź3ź
4ż3ż
4b3b
4c3c
4d3d
4f3f
4g3g
4h3h
4j3j
4k3k
4l3l
4m3m
4n3n
4p3p
4r3r
4t3t
4w3w
4z3z
8ć.
8ćć.
8ćł.
8ćń.
8ćś.
8ćź.
8ćż.
8ćb.
8ćc.
8ćd.
8ćf.
8ćg.
8ćh.
8ćj.
8ćk.
8ćl.
8ćm.
8ćn.
8ćp.
8ćr.
8ćs.
8ćt.
8ćv.
8ćw.
8ćx.
8ćz.
8ł.
8łć.
8łł.
8łń.
8łś.
8łź.
8łż.
8łb.
8łc.
8łd.
8łf.
8łg.
8łh.
8łj.
8łk.
8łl.
8łm.
8łn.
8łp.
8łr.
8łs.
8łt.
8łv.
8łw.
8łx.
8łz.
8ń.
8ńć.
8ńł.
8ńń.
8ńś.
8ńź.
8ńż.
8ńb.
8ńc.
8ńd.
8ńf.
8ńg.
8ńh.
8ńj.
8ńk.
8ńl.
8ńm.
8ńn.
8ńp.
8ńr.
8ńs.
8ńt.
8ńv.
8ńw.
8ńx.
8ńz.
8ś.
8ść.
8śł.
8śń.
8śś.
8śź.
8śż.
8śb.
8śc.
8śd.
8śf.
8śg.
8śh.
8śj.
8śk.
8śl.
8śm.
8śn.
8śp.
8śr.
8śs.
8śt.
8śv.
8św.
8śx.
8śz.
8ź.
8źć.
8źł.
8źń.
8źś.
8źź.
8źż.
8źb.
8źc.
8źd.
8źf.
8źg.
8źh.
8źj.
8źk.
8źl.
8źm.
8źn.
8źp.
8źr.
8źs.
8źt.
8źv.
8źw.
8źx.
8źz.
8ż.
8żć.
8żł.
8żń.
8żś.
8żź.
8żż.
8żb.
8żc.
8żd.
8żf.
8żg.
8żh.
8żj.
8żk.
8żl.
8żm.
8żn.
8żp.
8żr.
8żs.
8żt.
8żv.
8żw.
8żx.
8żz.
8b.
8bć.
8bł.
8bń.
8bś.
8bź.
8bż.
8bb.
8bc.
8bd.
8bf.
8bg.
8bh.
8bj.
8bk.
8bl.
8bm.
8bn.
8bp.
8br.
8brz.
8bs.
8bt.
8bv.
8bw.
8bx.
8bz.
8c.
8cć.
8cł.
8cń.
8cś.
8cź.
8cż.
8cb.
8cc.
8cd.
8cf.
8cg.
8ch.
8chł.
8chrz.
8chw.
8cj.
8ck.
8cl.
8cm.
8cn.
8cp.
8cr.
8cs.
8ct.
8cv.
8cw.
8cx.
8cz.
8czt.
8d.
8dć.
8dł.
8dń.
8dś.
8dź.
8dż.
8db.
8dc.
8dd.
8df.
8dg.
8dh.
8dj.
8dk.
8dl.
8dm.
8dn.
8dp.
8dr.
8drz.
8ds.
8dt.
8dv.
8dw.
8dx.
8dz.
8f.
8fć.
8fł.
8fń.
8fś.
8fź.
8fż.
8fb.
8fc.
8fd.
8ff.
8fg.
8fh.
8fj.
8fk.
8fl.
8fm.
8fn.
8fp.
8fr.
8fs.
8ft.
8fv.
8fw.
8fx.
8fz.
8g.
8gć.
8gł.
8gń.
8gś.
8gź.
8gż.
8gb.
8gc.
8gd.
8gf.
8gg.
8gh.
8gj.
8gk.
8gl.
8gm.
8gn.
8gp.
8gr.
8gs.
8gt.
8gv.
8gw.
8gx.
8gz.
8h.
8hć.
8hł.
8hń.
8hś.
8hź.
8hż.
8hb.
8hc.
8hd.
8hf.
8hg.
8hh.
8hj.
8hk.
8hl.
8hm.
8hn.
8hp.
8hr.
8hs.
8ht.
8hv.
8hw.
8hx.
8hz.
8j.
8jć.
8jł.
8jń.
8jś.
8jź.
8jż.
8jb.
8jc.
8jd.
8jf.
8jg.
8jh.
8jj.
8jk.
8jl.
8jm.
8jn.
8jp.
8jr.
8js.
8jt.
8jv.
8jw.
8jx.
8jz.
8k.
8kć.
8kł.
8kń.
8kś.
8kź.
8kż.
8kb.
8kc.
8kd.
8kf.
8kg.
8kh.
8kj.
8kk.
8kl.
8km.
8kn.
8kp.
8kr.
8ks.
8kst.
8kt.
8kv.
8kw.
8kx.
8kz.
8l.
8lć.
8lł.
8lń.
8lś.
8lź.
8lż.
8lb.
8lc.
8ld.
8lf.
8lg.
8lh.
8lj.
8lk.
8ll.
8lm.
8ln.
8lp.
8lr.
8ls.
8lt.
8lv.
8lw.
8lx.
8lz.
8m.
8mć.
8mł.
8mń.
8mś.
8mź.
8mż.
8mb.
8mc.
8md.
8mf.
8mg.
8mh.
8mj.
8mk.
8ml.
8mm.
8mn.
8mp.
8mr.
8ms.
8mst.
8mt.
8mv.
8mw.
8mx.
8mz.
8n.
8nć.
8nł.
8nń.
8nś.
8nź.
8nż.
8nb.
8nc.
8nd.
8nf.
8ng.
8nh.
8nj.
8nk.
8nl.
8nm.
8nn.
8np.
8nr.
8ns.
8nt.
8nv.
8nw.
8nx.
8nz.
8p.
8pć.
8pł.
8pń.
8pś.
8pź.
8pż.
8pb.
8pc.
8pd.
8pf.
8pg.
8ph.
8pj.
8pk.
8pl.
8pm.
8pn.
8pp.
8pr.
8prz.
8ps.
8pt.
8pv.
8pw.
8px.
8pz.
8r.
8rć.
8rł.
8rń.
8rś.
8rź.
8rż.
8rb.
8rc.
8rd.
8rf.
8rg.
8rh.
8rj.
8rk.
8rl.
8rm.
8rn.
8rp.
8rr.
8rs.
8rsz.
8rt.
8rv.
8rw.
8rx.
8rz.
8rzł.
8s.
8sć.
8sł.
8sń.
8sś.
8sź.
8sż.
8sb.
8sc.
8sch.
8sd.
8sf.
8sg.
8sh.
8sj.
8sk.
8skrz.
8sl.
8sm.
8sn.
8sp.
8sr.
8ss.
8st.
8str.
8strz.
8stw.
8sv.
8sw.
8sx.
8sz.
8szcz.
8szczb.
8szk.
8szn.
8szt.
8sztr.
8t.
8tć.
8tł.
8tń.
8tś.
8tź.
8tż.
8tb.
8tc.
8td.
8tf.
8tg.
8th.
8tj.
8tk.
8tl.
8tm.
8tn.
8tp.
8tr.
8trz.
8ts.
8tt.
8tv.
8tw.
8tx.
8tz.
8v.
8vć.
8vł.
8vń.
8vś.
8vź.
8vż.
8vb.
8vc.
8vd.
8vf.
8vg.
8vh.
8vj.
8vk.
8vl.
8vm.
8vn.
8vp.
8vr.
8vs.
8vt.
8vv.
8vw.
8vx.
8vz.
8w.
8wć.
8wł.
8wń.
8wś.
8wź.
8wż.
8wb.
8wc.
8wd.
8wf.
8wg.
8wh.
8wj.
8wk.
8wl.
8wm.
8wn.
8wp.
8wr.
8ws.
8wt.
8wv.
8ww.
8wx.
8wz.
8x.
8xć.
8xł.
8xń.
8xś.
8xź.
8xż.
8xb.
8xc.
8xd.
8xf.
8xg.
8xh.
8xj.
8xk.
8xl.
8xm.
8xn.
8xp.
8xr.
8xs.
8xt.
8xv.
8xw.
8xx.
8xz.
8z.
8zć.
8zł.
8zń.
8zś.
8zź.
8zż.
8zb.
8zc.
8zd.
8zdr.
8zdrz.
8zf.
8zg.
8zh.
8zj.
8zk.
8zl.
8zm.
8zn.
8zp.
8zr.
8zs.
8zt.
8zv.
8zw.
8zx.
8zz.
a1
a2u
a2y
aa2
ae2
ai2
ao2
be2eth
be2f3sz2
be2k1hend
bi2n3o2ku
bi2sz3kop
bi2z3ne2s3m
bi2z3nes
birmin2g1ham
blo2k1hauz
bo2s3ma
br2d
bro2a2d3way
bu2sz3me
buk2sz3pan
busine2ss3m
busines2s
c4h
c4z
cal2d1well
ch2ł
ch2j
ch2l
ch2r
ch2w
chus1t
cu2r7zon
dż2ł
dż2j
dż2l
dż2r
dż2w
dże4z3b
dże4z3m
d4ź
d4ż
d4z
deut4sch3land
drz2w
du2sz3past
e1
e2r5zac
e2u
e2y
e3u2sz
ea2
ee2
ei2
eo2
fi2s3harm
fi2sz3bin
fo2k2s3t
fo2r5zac
fol2k1lor
fos2f1a2zot
ga3d2get
gado3p2ta
gol2f3s
golfsz2
gran2d1ilo
gro4t3r
hi2sz3p
hu2cz1w
hu2x3ley
i1
i2ą
i2ę
i2ó
i2a
i2e
i2i
i2o
i2u
i2y
in4nsbruck
in4sbruc
j2t1ł
j2t1r
ja4z4z3b
ja4z4z3m
karl2s1kron
karl2s1ruhe
kir2chhoff
kongre2s3m
led1w
lu2ft3waffe
lu2ks1fer
ly2o
ma2r5zł
ma2r5zl
ma2r5zn
mi2sz1masz
mie2r5zł
mie2r5zi
mon2t3real
moza2i3k
mu2r7zasich3l
na4ł3kows
na4r3v
o1
o2y
oa2
och3mistrz
oe2
of2f3set
oi2
oo2
ou2
pa2n3a2mer
pa2s3cal
pa2s3ch
połu3d2ni
po3d4nieprz
po3m2ną
po3m2nę
po3m2ni
po4rt2s3mo2uth
po4rt3land
poli3e2t
poli3u2re
powsze3d2ni
pr2chal
pre2sz3pa
r4z
ro2e3nt2gen
ro2k3rocz
ro2s3to3c2k
s4z
se2t3le
sko2r5zoner
sm2r
sowi3z2
sy2n3opt
sy2s1tem
sza2sz1ły
sze2z1long
sze4ść
szto2k1holm
szyn2k1was
to3y2o3t
turboo2d3rzut
tygo3d2ni
u1
u2y
ua2
ue2
ui2
uo2
uu2
vo2lk2s3
we2e2k1end
we4st3f
we4st3m
y1
ya2
ye2
yi2
yo2
yu2
ze4p3p
}

\hyphenation{
be-zach
be-zami
by-naj-mniej
gdzie-nie-gdzie
ina-czej
na-dal
ni-gdy
ni-gdzie
niech-że
niech-by
ow-szem
pó-łach
pó-łami
pó-łek
pod-ów-czas
przy-naj-mniej
skąd-inąd
tró-jach
tró-jami
tró-jek
}


