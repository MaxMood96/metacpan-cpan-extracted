package Ekoi8r;
use strict;
BEGIN { $INC{'warnings.pm'} = '' if $] < 5.006 } use warnings;
######################################################################
#
# Ekoi8r - Run-time routines for KOI8R.pm
#
# http://search.cpan.org/dist/Char-KOI8R/
#
# Copyright (c) 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2018, 2019 INABA Hitoshi <ina@cpan.org>
######################################################################

use 5.00503;    # Galapagos Consensus 1998 for primetools
# use 5.008001; # Lancaster Consensus 2013 for toolchains

# 12.3. Delaying use Until Runtime
# in Chapter 12. Packages, Libraries, and Modules
# of ISBN 0-596-00313-7 Perl Cookbook, 2nd Edition.
# (and so on)

# Version numbers should be boring
# http://www.dagolden.com/index.php/369/version-numbers-should-be-boring/
# For the impatient, the disinterested or those who just want to follow
# a recipe, my advice for all modules is this:
# our $VERSION = "0.001"; # or "0.001_001" for a dev release
# $VERSION = eval $VERSION; # No!! because '1.10' makes '1.1'

use vars qw($VERSION);
$VERSION = '1.22';
$VERSION = $VERSION;

BEGIN {
    if ($^X =~ / jperl /oxmsi) {
        die __FILE__, ": needs perl(not jperl) 5.00503 or later. (\$^X==$^X)\n";
    }
    if (CORE::ord('A') == 193) {
        die __FILE__, ": is not US-ASCII script (may be EBCDIC or EBCDIK script).\n";
    }
    if (CORE::ord('A') != 0x41) {
        die __FILE__, ": is not US-ASCII script (must be US-ASCII script).\n";
    }
}

BEGIN {

    # instead of utf8.pm
    CORE::eval q{
        no warnings qw(redefine);
        *utf8::upgrade   = sub { CORE::length $_[0] };
        *utf8::downgrade = sub { 1 };
        *utf8::encode    = sub {   };
        *utf8::decode    = sub { 1 };
        *utf8::is_utf8   = sub {   };
        *utf8::valid     = sub { 1 };
    };
    if ($@) {
        *utf8::upgrade   = sub { CORE::length $_[0] };
        *utf8::downgrade = sub { 1 };
        *utf8::encode    = sub {   };
        *utf8::decode    = sub { 1 };
        *utf8::is_utf8   = sub {   };
        *utf8::valid     = sub { 1 };
    }
}

# instead of Symbol.pm
BEGIN {
    sub gensym () {
        if ($] < 5.006) {
            return \do { local *_ };
        }
        else {
            return undef;
        }
    }

    sub qualify ($$) {
        my($name) = @_;

        if (ref $name) {
            return $name;
        }
        elsif (Ekoi8r::index($name,'::') >= 0) {
            return $name;
        }
        elsif (Ekoi8r::index($name,"'") >= 0) {
            return $name;
        }

        # special character, "^xyz"
        elsif ($name =~ /\A \^ [ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_]+ \z/x) {

            # RGS 2001-11-05 : translate leading ^X to control-char
            $name =~ s{\A \^ ([ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_]) }{'qq(\c'.$1.')'}xee;
            return 'main::' . $name;
        }

        # Global names
        elsif ($name =~ /\A (?: ARGV | ARGVOUT | ENV | INC | SIG | STDERR | STDIN | STDOUT ) \z/x) {
            return 'main::' . $name;
        }

        # or other
        elsif ($name =~ /\A [^ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz] \z/x) {
            return 'main::' . $name;
        }

        elsif (defined $_[1]) {
            return $_[1] . '::' . $name;
        }
        else {
            return (caller)[0] . '::' . $name;
        }
    }

    sub qualify_to_ref ($;$) {
        if (defined $_[1]) {
            no strict qw(refs);
            return \*{ qualify $_[0], $_[1] };
        }
        else {
            no strict qw(refs);
            return \*{ qualify $_[0], (caller)[0] };
        }
    }
}

# P.714 29.2.39. flock
# in Chapter 29: Functions
# of ISBN 0-596-00027-8 Programming Perl Third Edition.

# P.863 flock
# in Chapter 27: Functions
# of ISBN 978-0-596-00492-7 Programming Perl 4th Edition.

sub LOCK_SH() {1}
sub LOCK_EX() {2}
sub LOCK_UN() {8}
sub LOCK_NB() {4}

# instead of Carp.pm
sub carp;
sub croak;
sub cluck;
sub confess;

# 6.18. Matching Multiple-Byte Characters
# in Chapter 6. Pattern Matching
# of ISBN 978-1-56592-243-3 Perl Perl Cookbook.
# (and so on)

# regexp of character
my $your_char = q{[\x00-\xFF]};
use vars qw($qq_char); $qq_char = qr/\\c[\x40-\x5F]|\\?(?:$your_char)/oxms;
use vars qw($q_char);  $q_char  = qr/$your_char/oxms;

#
# KOI8-R character range per length
#
my %range_tr = ();

#
# KOI8-R case conversion
#
my %lc = ();
@lc{qw(A B C D E F G H I J K L M N O P Q R S T U V W X Y Z)} =
    qw(a b c d e f g h i j k l m n o p q r s t u v w x y z);
my %uc = ();
@uc{qw(a b c d e f g h i j k l m n o p q r s t u v w x y z)} =
    qw(A B C D E F G H I J K L M N O P Q R S T U V W X Y Z);
my %fc = ();
@fc{qw(A B C D E F G H I J K L M N O P Q R S T U V W X Y Z)} =
    qw(a b c d e f g h i j k l m n o p q r s t u v w x y z);

if (0) {
}

elsif (__PACKAGE__ =~ / \b Ekoi8r \z/oxms) {
    %range_tr = (
        1 => [ [0x00..0xFF],
             ],
    );

    %lc = (%lc,
        "\xB3" => "\xA3",     # CYRILLIC LETTER IO
        "\xE0" => "\xC0",     # CYRILLIC LETTER IU
        "\xE1" => "\xC1",     # CYRILLIC LETTER A
        "\xE2" => "\xC2",     # CYRILLIC LETTER BE
        "\xE3" => "\xC3",     # CYRILLIC LETTER TSE
        "\xE4" => "\xC4",     # CYRILLIC LETTER DE
        "\xE5" => "\xC5",     # CYRILLIC LETTER IE
        "\xE6" => "\xC6",     # CYRILLIC LETTER EF
        "\xE7" => "\xC7",     # CYRILLIC LETTER GE
        "\xE8" => "\xC8",     # CYRILLIC LETTER KHA
        "\xE9" => "\xC9",     # CYRILLIC LETTER II
        "\xEA" => "\xCA",     # CYRILLIC LETTER SHORT II
        "\xEB" => "\xCB",     # CYRILLIC LETTER KA
        "\xEC" => "\xCC",     # CYRILLIC LETTER EL
        "\xED" => "\xCD",     # CYRILLIC LETTER EM
        "\xEE" => "\xCE",     # CYRILLIC LETTER EN
        "\xEF" => "\xCF",     # CYRILLIC LETTER O
        "\xF0" => "\xD0",     # CYRILLIC LETTER PE
        "\xF1" => "\xD1",     # CYRILLIC LETTER IA
        "\xF2" => "\xD2",     # CYRILLIC LETTER ER
        "\xF3" => "\xD3",     # CYRILLIC LETTER ES
        "\xF4" => "\xD4",     # CYRILLIC LETTER TE
        "\xF5" => "\xD5",     # CYRILLIC LETTER U
        "\xF6" => "\xD6",     # CYRILLIC LETTER ZHE
        "\xF7" => "\xD7",     # CYRILLIC LETTER VE
        "\xF8" => "\xD8",     # CYRILLIC LETTER SOFT SIGN
        "\xF9" => "\xD9",     # CYRILLIC LETTER YERI
        "\xFA" => "\xDA",     # CYRILLIC LETTER ZE
        "\xFB" => "\xDB",     # CYRILLIC LETTER SHA
        "\xFC" => "\xDC",     # CYRILLIC LETTER REVERSED E
        "\xFD" => "\xDD",     # CYRILLIC LETTER SHCHA
        "\xFE" => "\xDE",     # CYRILLIC LETTER CHE
        "\xFF" => "\xDF",     # CYRILLIC LETTER HARD SIGN
    );

    %uc = (%uc,
        "\xA3" => "\xB3",     # CYRILLIC LETTER IO
        "\xC0" => "\xE0",     # CYRILLIC LETTER IU
        "\xC1" => "\xE1",     # CYRILLIC LETTER A
        "\xC2" => "\xE2",     # CYRILLIC LETTER BE
        "\xC3" => "\xE3",     # CYRILLIC LETTER TSE
        "\xC4" => "\xE4",     # CYRILLIC LETTER DE
        "\xC5" => "\xE5",     # CYRILLIC LETTER IE
        "\xC6" => "\xE6",     # CYRILLIC LETTER EF
        "\xC7" => "\xE7",     # CYRILLIC LETTER GE
        "\xC8" => "\xE8",     # CYRILLIC LETTER KHA
        "\xC9" => "\xE9",     # CYRILLIC LETTER II
        "\xCA" => "\xEA",     # CYRILLIC LETTER SHORT II
        "\xCB" => "\xEB",     # CYRILLIC LETTER KA
        "\xCC" => "\xEC",     # CYRILLIC LETTER EL
        "\xCD" => "\xED",     # CYRILLIC LETTER EM
        "\xCE" => "\xEE",     # CYRILLIC LETTER EN
        "\xCF" => "\xEF",     # CYRILLIC LETTER O
        "\xD0" => "\xF0",     # CYRILLIC LETTER PE
        "\xD1" => "\xF1",     # CYRILLIC LETTER IA
        "\xD2" => "\xF2",     # CYRILLIC LETTER ER
        "\xD3" => "\xF3",     # CYRILLIC LETTER ES
        "\xD4" => "\xF4",     # CYRILLIC LETTER TE
        "\xD5" => "\xF5",     # CYRILLIC LETTER U
        "\xD6" => "\xF6",     # CYRILLIC LETTER ZHE
        "\xD7" => "\xF7",     # CYRILLIC LETTER VE
        "\xD8" => "\xF8",     # CYRILLIC LETTER SOFT SIGN
        "\xD9" => "\xF9",     # CYRILLIC LETTER YERI
        "\xDA" => "\xFA",     # CYRILLIC LETTER ZE
        "\xDB" => "\xFB",     # CYRILLIC LETTER SHA
        "\xDC" => "\xFC",     # CYRILLIC LETTER REVERSED E
        "\xDD" => "\xFD",     # CYRILLIC LETTER SHCHA
        "\xDE" => "\xFE",     # CYRILLIC LETTER CHE
        "\xDF" => "\xFF",     # CYRILLIC LETTER HARD SIGN
    );

    %fc = (%fc,
        "\xB3" => "\xA3",     # CYRILLIC CAPITAL LETTER IO        --> CYRILLIC SMALL LETTER IO
        "\xE0" => "\xC0",     # CYRILLIC CAPITAL LETTER YU        --> CYRILLIC SMALL LETTER YU
        "\xE1" => "\xC1",     # CYRILLIC CAPITAL LETTER A         --> CYRILLIC SMALL LETTER A
        "\xE2" => "\xC2",     # CYRILLIC CAPITAL LETTER BE        --> CYRILLIC SMALL LETTER BE
        "\xE3" => "\xC3",     # CYRILLIC CAPITAL LETTER TSE       --> CYRILLIC SMALL LETTER TSE
        "\xE4" => "\xC4",     # CYRILLIC CAPITAL LETTER DE        --> CYRILLIC SMALL LETTER DE
        "\xE5" => "\xC5",     # CYRILLIC CAPITAL LETTER IE        --> CYRILLIC SMALL LETTER IE
        "\xE6" => "\xC6",     # CYRILLIC CAPITAL LETTER EF        --> CYRILLIC SMALL LETTER EF
        "\xE7" => "\xC7",     # CYRILLIC CAPITAL LETTER GHE       --> CYRILLIC SMALL LETTER GHE
        "\xE8" => "\xC8",     # CYRILLIC CAPITAL LETTER HA        --> CYRILLIC SMALL LETTER HA
        "\xE9" => "\xC9",     # CYRILLIC CAPITAL LETTER I         --> CYRILLIC SMALL LETTER I
        "\xEA" => "\xCA",     # CYRILLIC CAPITAL LETTER SHORT I   --> CYRILLIC SMALL LETTER SHORT I
        "\xEB" => "\xCB",     # CYRILLIC CAPITAL LETTER KA        --> CYRILLIC SMALL LETTER KA
        "\xEC" => "\xCC",     # CYRILLIC CAPITAL LETTER EL        --> CYRILLIC SMALL LETTER EL
        "\xED" => "\xCD",     # CYRILLIC CAPITAL LETTER EM        --> CYRILLIC SMALL LETTER EM
        "\xEE" => "\xCE",     # CYRILLIC CAPITAL LETTER EN        --> CYRILLIC SMALL LETTER EN
        "\xEF" => "\xCF",     # CYRILLIC CAPITAL LETTER O         --> CYRILLIC SMALL LETTER O
        "\xF0" => "\xD0",     # CYRILLIC CAPITAL LETTER PE        --> CYRILLIC SMALL LETTER PE
        "\xF1" => "\xD1",     # CYRILLIC CAPITAL LETTER YA        --> CYRILLIC SMALL LETTER YA
        "\xF2" => "\xD2",     # CYRILLIC CAPITAL LETTER ER        --> CYRILLIC SMALL LETTER ER
        "\xF3" => "\xD3",     # CYRILLIC CAPITAL LETTER ES        --> CYRILLIC SMALL LETTER ES
        "\xF4" => "\xD4",     # CYRILLIC CAPITAL LETTER TE        --> CYRILLIC SMALL LETTER TE
        "\xF5" => "\xD5",     # CYRILLIC CAPITAL LETTER U         --> CYRILLIC SMALL LETTER U
        "\xF6" => "\xD6",     # CYRILLIC CAPITAL LETTER ZHE       --> CYRILLIC SMALL LETTER ZHE
        "\xF7" => "\xD7",     # CYRILLIC CAPITAL LETTER VE        --> CYRILLIC SMALL LETTER VE
        "\xF8" => "\xD8",     # CYRILLIC CAPITAL LETTER SOFT SIGN --> CYRILLIC SMALL LETTER SOFT SIGN
        "\xF9" => "\xD9",     # CYRILLIC CAPITAL LETTER YERU      --> CYRILLIC SMALL LETTER YERU
        "\xFA" => "\xDA",     # CYRILLIC CAPITAL LETTER ZE        --> CYRILLIC SMALL LETTER ZE
        "\xFB" => "\xDB",     # CYRILLIC CAPITAL LETTER SHA       --> CYRILLIC SMALL LETTER SHA
        "\xFC" => "\xDC",     # CYRILLIC CAPITAL LETTER E         --> CYRILLIC SMALL LETTER E
        "\xFD" => "\xDD",     # CYRILLIC CAPITAL LETTER SHCHA     --> CYRILLIC SMALL LETTER SHCHA
        "\xFE" => "\xDE",     # CYRILLIC CAPITAL LETTER CHE       --> CYRILLIC SMALL LETTER CHE
        "\xFF" => "\xDF",     # CYRILLIC CAPITAL LETTER HARD SIGN --> CYRILLIC SMALL LETTER HARD SIGN
    );
}

else {
    croak "Don't know my package name '@{[__PACKAGE__]}'";
}

#
# @ARGV wildcard globbing
#
sub import {

    if ($^O =~ /\A (?: MSWin32 | NetWare | symbian | dos ) \z/oxms) {
        my @argv = ();
        for (@ARGV) {

            # has space
            if (/\A (?:$q_char)*? [ ] /oxms) {
                if (my @glob = Ekoi8r::glob(qq{"$_"})) {
                    push @argv, @glob;
                }
                else {
                    push @argv, $_;
                }
            }

            # has wildcard metachar
            elsif (/\A (?:$q_char)*? [*?] /oxms) {
                if (my @glob = Ekoi8r::glob($_)) {
                    push @argv, @glob;
                }
                else {
                    push @argv, $_;
                }
            }

            # no wildcard globbing
            else {
                push @argv, $_;
            }
        }
        @ARGV = @argv;
    }

    *Char::ord           = \&KOI8R::ord;
    *Char::ord_          = \&KOI8R::ord_;
    *Char::reverse       = \&KOI8R::reverse;
    *Char::getc          = \&KOI8R::getc;
    *Char::length        = \&KOI8R::length;
    *Char::substr        = \&KOI8R::substr;
    *Char::index         = \&KOI8R::index;
    *Char::rindex        = \&KOI8R::rindex;
    *Char::eval          = \&KOI8R::eval;
    *Char::escape        = \&KOI8R::escape;
    *Char::escape_token  = \&KOI8R::escape_token;
    *Char::escape_script = \&KOI8R::escape_script;
}

# P.230 Care with Prototypes
# in Chapter 6: Subroutines
# of ISBN 0-596-00027-8 Programming Perl Third Edition.
#
# If you aren't careful, you can get yourself into trouble with prototypes.
# But if you are careful, you can do a lot of neat things with them. This is
# all very powerful, of course, and should only be used in moderation to make
# the world a better place.

# P.332 Care with Prototypes
# in Chapter 7: Subroutines
# of ISBN 978-0-596-00492-7 Programming Perl 4th Edition.
#
# If you aren't careful, you can get yourself into trouble with prototypes.
# But if you are careful, you can do a lot of neat things with them. This is
# all very powerful, of course, and should only be used in moderation to make
# the world a better place.

#
# Prototypes of subroutines
#
sub unimport {}
sub Ekoi8r::split(;$$$);
sub Ekoi8r::tr($$$$;$);
sub Ekoi8r::chop(@);
sub Ekoi8r::index($$;$);
sub Ekoi8r::rindex($$;$);
sub Ekoi8r::lcfirst(@);
sub Ekoi8r::lcfirst_();
sub Ekoi8r::lc(@);
sub Ekoi8r::lc_();
sub Ekoi8r::ucfirst(@);
sub Ekoi8r::ucfirst_();
sub Ekoi8r::uc(@);
sub Ekoi8r::uc_();
sub Ekoi8r::fc(@);
sub Ekoi8r::fc_();
sub Ekoi8r::ignorecase;
sub Ekoi8r::classic_character_class;
sub Ekoi8r::capture;
sub Ekoi8r::chr(;$);
sub Ekoi8r::chr_();
sub Ekoi8r::glob($);
sub Ekoi8r::glob_();

sub KOI8R::ord(;$);
sub KOI8R::ord_();
sub KOI8R::reverse(@);
sub KOI8R::getc(;*@);
sub KOI8R::length(;$);
sub KOI8R::substr($$;$$);
sub KOI8R::index($$;$);
sub KOI8R::rindex($$;$);
sub KOI8R::escape(;$);

#
# Regexp work
#
use vars qw(
    $re_a
    $re_t
    $re_n
    $re_r
);

#
# Character class
#
use vars qw(
    $dot
    $dot_s
    $eD
    $eS
    $eW
    $eH
    $eV
    $eR
    $eN
    $not_alnum
    $not_alpha
    $not_ascii
    $not_blank
    $not_cntrl
    $not_digit
    $not_graph
    $not_lower
    $not_lower_i
    $not_print
    $not_punct
    $not_space
    $not_upper
    $not_upper_i
    $not_word
    $not_xdigit
    $eb
    $eB
);

${Ekoi8r::dot}         = qr{(?>[^\x0A])};
${Ekoi8r::dot_s}       = qr{(?>[\x00-\xFF])};
${Ekoi8r::eD}          = qr{(?>[^0-9])};

# Vertical tabs are now whitespace
# \s in a regex now matches a vertical tab in all circumstances.
# http://search.cpan.org/dist/perl-5.18.0/pod/perldelta.pod#Vertical_tabs_are_now_whitespace
# ${Ekoi8r::eS}          = qr{(?>[^\x09\x0A    \x0C\x0D\x20])};
# ${Ekoi8r::eS}          = qr{(?>[^\x09\x0A\x0B\x0C\x0D\x20])};
${Ekoi8r::eS}            = qr{(?>[^\s])};

${Ekoi8r::eW}            = qr{(?>[^0-9A-Z_a-z])};
${Ekoi8r::eH}            = qr{(?>[^\x09\x20])};
${Ekoi8r::eV}            = qr{(?>[^\x0A\x0B\x0C\x0D])};
${Ekoi8r::eR}            = qr{(?>\x0D\x0A|[\x0A\x0D])};
${Ekoi8r::eN}            = qr{(?>[^\x0A])};
${Ekoi8r::not_alnum}     = qr{(?>[^\x30-\x39\x41-\x5A\x61-\x7A])};
${Ekoi8r::not_alpha}     = qr{(?>[^\x41-\x5A\x61-\x7A])};
${Ekoi8r::not_ascii}     = qr{(?>[^\x00-\x7F])};
${Ekoi8r::not_blank}     = qr{(?>[^\x09\x20])};
${Ekoi8r::not_cntrl}     = qr{(?>[^\x00-\x1F\x7F])};
${Ekoi8r::not_digit}     = qr{(?>[^\x30-\x39])};
${Ekoi8r::not_graph}     = qr{(?>[^\x21-\x7F])};
${Ekoi8r::not_lower}     = qr{(?>[^\x61-\x7A])};
${Ekoi8r::not_lower_i}   = qr{(?>[^\x41-\x5A\x61-\x7A])}; # Perl 5.16 compatible
# ${Ekoi8r::not_lower_i} = qr{(?>[\x00-\xFF])};                   # older Perl compatible
${Ekoi8r::not_print}     = qr{(?>[^\x20-\x7F])};
${Ekoi8r::not_punct}     = qr{(?>[^\x21-\x2F\x3A-\x3F\x40\x5B-\x5F\x60\x7B-\x7E])};
${Ekoi8r::not_space}     = qr{(?>[^\s\x0B])};
${Ekoi8r::not_upper}     = qr{(?>[^\x41-\x5A])};
${Ekoi8r::not_upper_i}   = qr{(?>[^\x41-\x5A\x61-\x7A])}; # Perl 5.16 compatible
# ${Ekoi8r::not_upper_i} = qr{(?>[\x00-\xFF])};                   # older Perl compatible
${Ekoi8r::not_word}      = qr{(?>[^\x30-\x39\x41-\x5A\x5F\x61-\x7A])};
${Ekoi8r::not_xdigit}    = qr{(?>[^\x30-\x39\x41-\x46\x61-\x66])};
${Ekoi8r::eb}            = qr{(?:\A(?=[0-9A-Z_a-z])|(?<=[\x00-\x2F\x40\x5B-\x5E\x60\x7B-\xFF])(?=[0-9A-Z_a-z])|(?<=[0-9A-Z_a-z])(?=[\x00-\x2F\x40\x5B-\x5E\x60\x7B-\xFF]|\z))};
${Ekoi8r::eB}            = qr{(?:(?<=[0-9A-Z_a-z])(?=[0-9A-Z_a-z])|(?<=[\x00-\x2F\x40\x5B-\x5E\x60\x7B-\xFF])(?=[\x00-\x2F\x40\x5B-\x5E\x60\x7B-\xFF]))};

# avoid: Name "Ekoi8r::foo" used only once: possible typo at here.
${Ekoi8r::dot}         = ${Ekoi8r::dot};
${Ekoi8r::dot_s}       = ${Ekoi8r::dot_s};
${Ekoi8r::eD}          = ${Ekoi8r::eD};
${Ekoi8r::eS}          = ${Ekoi8r::eS};
${Ekoi8r::eW}          = ${Ekoi8r::eW};
${Ekoi8r::eH}          = ${Ekoi8r::eH};
${Ekoi8r::eV}          = ${Ekoi8r::eV};
${Ekoi8r::eR}          = ${Ekoi8r::eR};
${Ekoi8r::eN}          = ${Ekoi8r::eN};
${Ekoi8r::not_alnum}   = ${Ekoi8r::not_alnum};
${Ekoi8r::not_alpha}   = ${Ekoi8r::not_alpha};
${Ekoi8r::not_ascii}   = ${Ekoi8r::not_ascii};
${Ekoi8r::not_blank}   = ${Ekoi8r::not_blank};
${Ekoi8r::not_cntrl}   = ${Ekoi8r::not_cntrl};
${Ekoi8r::not_digit}   = ${Ekoi8r::not_digit};
${Ekoi8r::not_graph}   = ${Ekoi8r::not_graph};
${Ekoi8r::not_lower}   = ${Ekoi8r::not_lower};
${Ekoi8r::not_lower_i} = ${Ekoi8r::not_lower_i};
${Ekoi8r::not_print}   = ${Ekoi8r::not_print};
${Ekoi8r::not_punct}   = ${Ekoi8r::not_punct};
${Ekoi8r::not_space}   = ${Ekoi8r::not_space};
${Ekoi8r::not_upper}   = ${Ekoi8r::not_upper};
${Ekoi8r::not_upper_i} = ${Ekoi8r::not_upper_i};
${Ekoi8r::not_word}    = ${Ekoi8r::not_word};
${Ekoi8r::not_xdigit}  = ${Ekoi8r::not_xdigit};
${Ekoi8r::eb}          = ${Ekoi8r::eb};
${Ekoi8r::eB}          = ${Ekoi8r::eB};

#
# KOI8-R split
#
sub Ekoi8r::split(;$$$) {

    # P.794 29.2.161. split
    # in Chapter 29: Functions
    # of ISBN 0-596-00027-8 Programming Perl Third Edition.

    # P.951 split
    # in Chapter 27: Functions
    # of ISBN 978-0-596-00492-7 Programming Perl 4th Edition.

    my $pattern = $_[0];
    my $string  = $_[1];
    my $limit   = $_[2];

    # if $pattern is also omitted or is the literal space, " "
    if (not defined $pattern) {
        $pattern = ' ';
    }

    # if $string is omitted, the function splits the $_ string
    if (not defined $string) {
        if (defined $_) {
            $string = $_;
        }
        else {
            $string = '';
        }
    }

    my @split = ();

    # when string is empty
    if ($string eq '') {

        # resulting list value in list context
        if (wantarray) {
            return @split;
        }

        # count of substrings in scalar context
        else {
            carp "Use of implicit split to \@_ is deprecated" if $^W;
            @_ = @split;
            return scalar @_;
        }
    }

    # split's first argument is more consistently interpreted
    #
    # After some changes earlier in v5.17, split's behavior has been simplified:
    # if the PATTERN argument evaluates to a string containing one space, it is
    # treated the way that a literal string containing one space once was.
    # http://search.cpan.org/dist/perl-5.18.0/pod/perldelta.pod#split's_first_argument_is_more_consistently_interpreted

    # if $pattern is also omitted or is the literal space, " ", the function splits
    # on whitespace, /\s+/, after skipping any leading whitespace
    # (and so on)

    elsif ($pattern eq ' ') {
        if (not defined $limit) {
            return CORE::split(' ', $string);
        }
        else {
            return CORE::split(' ', $string, $limit);
        }
    }

    # if $limit is negative, it is treated as if an arbitrarily large $limit has been specified
    if ((not defined $limit) or ($limit <= 0)) {

        # a pattern capable of matching either the null string or something longer than the
        # null string will split the value of $string into separate characters wherever it
        # matches the null string between characters
        # (and so on)

        if ('' =~ / \A $pattern \z /xms) {
            my $last_subexpression_offsets = _last_subexpression_offsets($pattern);
            my $limit = scalar(() = $string =~ /($pattern)/oxmsg);

            # P.1024 Appendix W.10 Multibyte Processing
            # of ISBN 1-56592-224-7 CJKV Information Processing
            # (and so on)

            # the //m modifier is assumed when you split on the pattern /^/
            # (and so on)

            eval q{ no warnings }; # avoid: Complex regular subexpression recursion limit (32766) exceeded at ...
            #                                                     V
            while ((--$limit > 0) and ($string =~ s/\A((?:$q_char)+?)$pattern//m)) {

                # if the $pattern contains parentheses, then the substring matched by each pair of parentheses
                # is included in the resulting list, interspersed with the fields that are ordinarily returned
                # (and so on)

                local $@;
                eval q{ no warnings }; # avoid: Complex regular subexpression recursion limit (32766) exceeded at ...
                for (my $digit=1; $digit <= ($last_subexpression_offsets + 1); $digit++) {
                    push @split, CORE::eval('$' . $digit);
                }
            }
        }

        else {
            my $last_subexpression_offsets = _last_subexpression_offsets($pattern);

            eval q{ no warnings }; # avoid: Complex regular subexpression recursion limit (32766) exceeded at ...
            #                                 V
            while ($string =~ s/\A((?:$q_char)*?)$pattern//m) {
                local $@;
                eval q{ no warnings }; # avoid: Complex regular subexpression recursion limit (32766) exceeded at ...
                for (my $digit=1; $digit <= ($last_subexpression_offsets + 1); $digit++) {
                    push @split, CORE::eval('$' . $digit);
                }
            }
        }
    }

    elsif ($limit > 0) {
        if ('' =~ / \A $pattern \z /xms) {
            my $last_subexpression_offsets = _last_subexpression_offsets($pattern);
            while ((--$limit > 0) and (CORE::length($string) > 0)) {

                eval q{ no warnings }; # avoid: Complex regular subexpression recursion limit (32766) exceeded at ...
                #                              V
                if ($string =~ s/\A((?:$q_char)+?)$pattern//m) {
                    local $@;
                    for (my $digit=1; $digit <= ($last_subexpression_offsets + 1); $digit++) {
                        push @split, CORE::eval('$' . $digit);
                    }
                }
            }
        }
        else {
            my $last_subexpression_offsets = _last_subexpression_offsets($pattern);
            while ((--$limit > 0) and (CORE::length($string) > 0)) {

                eval q{ no warnings }; # avoid: Complex regular subexpression recursion limit (32766) exceeded at ...
                #                              V
                if ($string =~ s/\A((?:$q_char)*?)$pattern//m) {
                    local $@;
                    for (my $digit=1; $digit <= ($last_subexpression_offsets + 1); $digit++) {
                        push @split, CORE::eval('$' . $digit);
                    }
                }
            }
        }
    }

    if (CORE::length($string) > 0) {
        push @split, $string;
    }

    # if $_[2] (NOT "$limit") is omitted or zero, trailing null fields are stripped from the result
    if ((not defined $_[2]) or ($_[2] == 0)) {
        while ((scalar(@split) >= 1) and ($split[-1] eq '')) {
            pop @split;
        }
    }

    # resulting list value in list context
    if (wantarray) {
        return @split;
    }

    # count of substrings in scalar context
    else {
        carp "Use of implicit split to \@_ is deprecated" if $^W;
        @_ = @split;
        return scalar @_;
    }
}

#
# get last subexpression offsets
#
sub _last_subexpression_offsets {
    my $pattern = $_[0];

    # remove comment
    $pattern =~ s/\(\?\# .*? \)//oxmsg;

    my $modifier = '';
    if ($pattern =~ /\(\?\^? ([\-A-Za-z]+) :/oxms) {
        $modifier = $1;
        $modifier =~ s/-[A-Za-z]*//;
    }

    # with /x modifier
    my @char = ();
    if ($modifier =~ /x/oxms) {
        @char = $pattern =~ /\G((?>
            [^\\\#\[\(] |
            \\ $q_char      |
            \# (?>[^\n]*) $ |
            \[ (?>(?:[^\\\]]|\\\\|\\\]|$q_char)+) \] |
            \(\?            |
                $q_char
        ))/oxmsg;
    }

    # without /x modifier
    else {
        @char = $pattern =~ /\G((?>
            [^\\\[\(] |
            \\ $q_char      |
            \[ (?>(?:[^\\\]]|\\\\|\\\]|$q_char)+) \] |
            \(\?            |
                $q_char
        ))/oxmsg;
    }

    return scalar grep { $_ eq '(' } @char;
}

#
# KOI8-R transliteration (tr///)
#
sub Ekoi8r::tr($$$$;$) {

    my $bind_operator   = $_[1];
    my $searchlist      = $_[2];
    my $replacementlist = $_[3];
    my $modifier        = $_[4] || '';

    if ($modifier =~ /r/oxms) {
        if ($bind_operator =~ / !~ /oxms) {
            croak "Using !~ with tr///r doesn't make sense";
        }
    }

    my @char            = $_[0] =~ /\G (?>$q_char) /oxmsg;
    my @searchlist      = _charlist_tr($searchlist);
    my @replacementlist = _charlist_tr($replacementlist);

    my %tr = ();
    for (my $i=0; $i <= $#searchlist; $i++) {
        if (not exists $tr{$searchlist[$i]}) {
            if (defined $replacementlist[$i] and ($replacementlist[$i] ne '')) {
                $tr{$searchlist[$i]} = $replacementlist[$i];
            }
            elsif ($modifier =~ /d/oxms) {
                $tr{$searchlist[$i]} = '';
            }
            elsif (defined $replacementlist[-1] and ($replacementlist[-1] ne '')) {
                $tr{$searchlist[$i]} = $replacementlist[-1];
            }
            else {
                $tr{$searchlist[$i]} = $searchlist[$i];
            }
        }
    }

    my $tr = 0;
    my $replaced = '';
    if ($modifier =~ /c/oxms) {
        while (defined(my $char = shift @char)) {
            if (not exists $tr{$char}) {
                if (defined $replacementlist[-1]) {
                    $replaced .= $replacementlist[-1];
                }
                $tr++;
                if ($modifier =~ /s/oxms) {
                    while (@char and (not exists $tr{$char[0]})) {
                        shift @char;
                        $tr++;
                    }
                }
            }
            else {
                $replaced .= $char;
            }
        }
    }
    else {
        while (defined(my $char = shift @char)) {
            if (exists $tr{$char}) {
                $replaced .= $tr{$char};
                $tr++;
                if ($modifier =~ /s/oxms) {
                    while (@char and (exists $tr{$char[0]}) and ($tr{$char[0]} eq $tr{$char})) {
                        shift @char;
                        $tr++;
                    }
                }
            }
            else {
                $replaced .= $char;
            }
        }
    }

    if ($modifier =~ /r/oxms) {
        return $replaced;
    }
    else {
        $_[0] = $replaced;
        if ($bind_operator =~ / !~ /oxms) {
            return not $tr;
        }
        else {
            return $tr;
        }
    }
}

#
# KOI8-R chop
#
sub Ekoi8r::chop(@) {

    my $chop;
    if (@_ == 0) {
        my @char = /\G (?>$q_char) /oxmsg;
        $chop = pop @char;
        $_ = join '', @char;
    }
    else {
        for (@_) {
            my @char = /\G (?>$q_char) /oxmsg;
            $chop = pop @char;
            $_ = join '', @char;
        }
    }
    return $chop;
}

#
# KOI8-R index by octet
#
sub Ekoi8r::index($$;$) {

    my($str,$substr,$position) = @_;
    $position ||= 0;
    my $pos = 0;

    while ($pos < CORE::length($str)) {
        if (CORE::substr($str,$pos,CORE::length($substr)) eq $substr) {
            if ($pos >= $position) {
                return $pos;
            }
        }
        if (CORE::substr($str,$pos) =~ /\A ($q_char) /oxms) {
            $pos += CORE::length($1);
        }
        else {
            $pos += 1;
        }
    }
    return -1;
}

#
# KOI8-R reverse index
#
sub Ekoi8r::rindex($$;$) {

    my($str,$substr,$position) = @_;
    $position ||= CORE::length($str) - 1;
    my $pos = 0;
    my $rindex = -1;

    while (($pos < CORE::length($str)) and ($pos <= $position)) {
        if (CORE::substr($str,$pos,CORE::length($substr)) eq $substr) {
            $rindex = $pos;
        }
        if (CORE::substr($str,$pos) =~ /\A ($q_char) /oxms) {
            $pos += CORE::length($1);
        }
        else {
            $pos += 1;
        }
    }
    return $rindex;
}

#
# KOI8-R lower case first with parameter
#
sub Ekoi8r::lcfirst(@) {
    if (@_) {
        my $s = shift @_;
        if (@_ and wantarray) {
            return Ekoi8r::lc(CORE::substr($s,0,1)) . CORE::substr($s,1), @_;
        }
        else {
            return Ekoi8r::lc(CORE::substr($s,0,1)) . CORE::substr($s,1);
        }
    }
    else {
        return Ekoi8r::lc(CORE::substr($_,0,1)) . CORE::substr($_,1);
    }
}

#
# KOI8-R lower case first without parameter
#
sub Ekoi8r::lcfirst_() {
    return Ekoi8r::lc(CORE::substr($_,0,1)) . CORE::substr($_,1);
}

#
# KOI8-R lower case with parameter
#
sub Ekoi8r::lc(@) {
    if (@_) {
        my $s = shift @_;
        if (@_ and wantarray) {
            return join('', map {defined($lc{$_}) ? $lc{$_} : $_} ($s =~ /\G ($q_char) /oxmsg)), @_;
        }
        else {
            return join('', map {defined($lc{$_}) ? $lc{$_} : $_} ($s =~ /\G ($q_char) /oxmsg));
        }
    }
    else {
        return Ekoi8r::lc_();
    }
}

#
# KOI8-R lower case without parameter
#
sub Ekoi8r::lc_() {
    my $s = $_;
    return join '', map {defined($lc{$_}) ? $lc{$_} : $_} ($s =~ /\G ($q_char) /oxmsg);
}

#
# KOI8-R upper case first with parameter
#
sub Ekoi8r::ucfirst(@) {
    if (@_) {
        my $s = shift @_;
        if (@_ and wantarray) {
            return Ekoi8r::uc(CORE::substr($s,0,1)) . CORE::substr($s,1), @_;
        }
        else {
            return Ekoi8r::uc(CORE::substr($s,0,1)) . CORE::substr($s,1);
        }
    }
    else {
        return Ekoi8r::uc(CORE::substr($_,0,1)) . CORE::substr($_,1);
    }
}

#
# KOI8-R upper case first without parameter
#
sub Ekoi8r::ucfirst_() {
    return Ekoi8r::uc(CORE::substr($_,0,1)) . CORE::substr($_,1);
}

#
# KOI8-R upper case with parameter
#
sub Ekoi8r::uc(@) {
    if (@_) {
        my $s = shift @_;
        if (@_ and wantarray) {
            return join('', map {defined($uc{$_}) ? $uc{$_} : $_} ($s =~ /\G ($q_char) /oxmsg)), @_;
        }
        else {
            return join('', map {defined($uc{$_}) ? $uc{$_} : $_} ($s =~ /\G ($q_char) /oxmsg));
        }
    }
    else {
        return Ekoi8r::uc_();
    }
}

#
# KOI8-R upper case without parameter
#
sub Ekoi8r::uc_() {
    my $s = $_;
    return join '', map {defined($uc{$_}) ? $uc{$_} : $_} ($s =~ /\G ($q_char) /oxmsg);
}

#
# KOI8-R fold case with parameter
#
sub Ekoi8r::fc(@) {
    if (@_) {
        my $s = shift @_;
        if (@_ and wantarray) {
            return join('', map {defined($fc{$_}) ? $fc{$_} : $_} ($s =~ /\G ($q_char) /oxmsg)), @_;
        }
        else {
            return join('', map {defined($fc{$_}) ? $fc{$_} : $_} ($s =~ /\G ($q_char) /oxmsg));
        }
    }
    else {
        return Ekoi8r::fc_();
    }
}

#
# KOI8-R fold case without parameter
#
sub Ekoi8r::fc_() {
    my $s = $_;
    return join '', map {defined($fc{$_}) ? $fc{$_} : $_} ($s =~ /\G ($q_char) /oxmsg);
}

#
# KOI8-R regexp capture
#
{
    sub Ekoi8r::capture {
        return $_[0];
    }
}

#
# KOI8-R regexp ignore case modifier
#
sub Ekoi8r::ignorecase {

    my @string = @_;
    my $metachar = qr/[\@\\|[\]{]/oxms;

    # ignore case of $scalar or @array
    for my $string (@string) {

        # split regexp
        my @char = $string =~ /\G (?>\[\^|\\$q_char|$q_char) /oxmsg;

        # unescape character
        for (my $i=0; $i <= $#char; $i++) {
            next if not defined $char[$i];

            # open character class [...]
            if ($char[$i] eq '[') {
                my $left = $i;

                # [] make die "unmatched [] in regexp ...\n"

                if ($char[$i+1] eq ']') {
                    $i++;
                }

                while (1) {
                    if (++$i > $#char) {
                        croak "Unmatched [] in regexp";
                    }
                    if ($char[$i] eq ']') {
                        my $right = $i;
                        my @charlist = charlist_qr(@char[$left+1..$right-1], 'i');

                        # escape character
                        for my $char (@charlist) {
                            if (0) {
                            }

                            elsif ($char =~ /\A [.|)] \z/oxms) {
                                $char = '\\' . $char;
                            }
                        }

                        # [...]
                        splice @char, $left, $right-$left+1, '(?:' . join('|', @charlist) . ')';

                        $i = $left;
                        last;
                    }
                }
            }

            # open character class [^...]
            elsif ($char[$i] eq '[^') {
                my $left = $i;

                # [^] make die "unmatched [] in regexp ...\n"

                if ($char[$i+1] eq ']') {
                    $i++;
                }

                while (1) {
                    if (++$i > $#char) {
                        croak "Unmatched [] in regexp";
                    }
                    if ($char[$i] eq ']') {
                        my $right = $i;
                        my @charlist = charlist_not_qr(@char[$left+1..$right-1], 'i');

                        # escape character
                        for my $char (@charlist) {
                            if (0) {
                            }

                            elsif ($char =~ /\A [.|)] \z/oxms) {
                                $char = '\\' . $char;
                            }
                        }

                        # [^...]
                        splice @char, $left, $right-$left+1, '(?!' . join('|', @charlist) . ")(?:$your_char)";

                        $i = $left;
                        last;
                    }
                }
            }

            # rewrite classic character class or escape character
            elsif (my $char = classic_character_class($char[$i])) {
                $char[$i] = $char;
            }

            # with /i modifier
            elsif ($char[$i] =~ /\A [\x00-\xFF] \z/oxms) {
                my $uc = Ekoi8r::uc($char[$i]);
                my $fc = Ekoi8r::fc($char[$i]);
                if ($uc ne $fc) {
                    if (CORE::length($fc) == 1) {
                        $char[$i] = '['   . $uc       . $fc . ']';
                    }
                    else {
                        $char[$i] = '(?:' . $uc . '|' . $fc . ')';
                    }
                }
            }
        }

        # characterize
        for (my $i=0; $i <= $#char; $i++) {
            next if not defined $char[$i];

            if (0) {
            }

            # quote character before ? + * {
            elsif (($i >= 1) and ($char[$i] =~ /\A [\?\+\*\{] \z/oxms)) {
                if ($char[$i-1] !~ /\A [\x00-\xFF] \z/oxms) {
                    $char[$i-1] = '(?:' . $char[$i-1] . ')';
                }
            }
        }

        $string = join '', @char;
    }

    # make regexp string
    return @string;
}

#
# classic character class ( \D \S \W \d \s \w \C \X \H \V \h \v \R \N \b \B )
#
sub Ekoi8r::classic_character_class {
    my($char) = @_;

    return {
        '\D' => '${Ekoi8r::eD}',
        '\S' => '${Ekoi8r::eS}',
        '\W' => '${Ekoi8r::eW}',
        '\d' => '[0-9]',

        # Before Perl 5.6, \s only matched the five whitespace characters
        # tab, newline, form-feed, carriage return, and the space character
        # itself, which, taken together, is the character class [\t\n\f\r ].

        # Vertical tabs are now whitespace
        # \s in a regex now matches a vertical tab in all circumstances.
        # http://search.cpan.org/dist/perl-5.18.0/pod/perldelta.pod#Vertical_tabs_are_now_whitespace
        #            \t  \n  \v  \f  \r space
        # '\s' => '[\x09\x0A    \x0C\x0D\x20]',
        # '\s' => '[\x09\x0A\x0B\x0C\x0D\x20]',
        '\s'   => '\s',

        '\w' => '[0-9A-Z_a-z]',
        '\C' => '[\x00-\xFF]',
        '\X' => 'X',

        # \h \v \H \V

        # P.114 Character Class Shortcuts
        # in Chapter 7: In the World of Regular Expressions
        # of ISBN 978-0-596-52010-6 Learning Perl, Fifth Edition

        # P.357 13.2.3 Whitespace
        # in Chapter 13: perlrecharclass: Perl Regular Expression Character Classes
        # of ISBN-13: 978-1-906966-02-7 The Perl Language Reference Manual (for Perl version 5.12.1)
        #
        # 0x00009   CHARACTER TABULATION  h s
        # 0x0000a         LINE FEED (LF)   vs
        # 0x0000b        LINE TABULATION   v
        # 0x0000c         FORM FEED (FF)   vs
        # 0x0000d   CARRIAGE RETURN (CR)   vs
        # 0x00020                  SPACE  h s

        # P.196 Table 5-9. Alphanumeric regex metasymbols
        # in Chapter 5. Pattern Matching
        # of ISBN 978-0-596-00492-7 Programming Perl 4th Edition.

        # (and so on)

        '\H' => '${Ekoi8r::eH}',
        '\V' => '${Ekoi8r::eV}',
        '\h' => '[\x09\x20]',
        '\v' => '[\x0A\x0B\x0C\x0D]',
        '\R' => '${Ekoi8r::eR}',

        # \N
        #
        # http://perldoc.perl.org/perlre.html
        # Character Classes and other Special Escapes
        # Any character but \n (experimental). Not affected by /s modifier

        '\N' => '${Ekoi8r::eN}',

        # \b \B

        # P.180 Boundaries: The \b and \B Assertions
        # in Chapter 5: Pattern Matching
        # of ISBN 0-596-00027-8 Programming Perl Third Edition.

        # P.219 Boundaries: The \b and \B Assertions
        # in Chapter 5: Pattern Matching
        # of ISBN 978-0-596-00492-7 Programming Perl 4th Edition.

        # \b really means (?:(?<=\w)(?!\w)|(?<!\w)(?=\w))
        #           or (?:(?<=\A|\W)(?=\w)|(?<=\w)(?=\W|\z))
        '\b' => '${Ekoi8r::eb}',

        # \B really means (?:(?<=\w)(?=\w)|(?<!\w)(?!\w))
        #              or (?:(?<=\w)(?=\w)|(?<=\W)(?=\W))
        '\B' => '${Ekoi8r::eB}',

    }->{$char} || '';
}

#
# prepare KOI8-R characters per length
#

# 1 octet characters
my @chars1 = ();
sub chars1 {
    if (@chars1) {
        return @chars1;
    }
    if (exists $range_tr{1}) {
        my @ranges = @{ $range_tr{1} };
        while (my @range = splice(@ranges,0,1)) {
            for my $oct0 (@{$range[0]}) {
                push @chars1, pack 'C', $oct0;
            }
        }
    }
    return @chars1;
}

# 2 octets characters
my @chars2 = ();
sub chars2 {
    if (@chars2) {
        return @chars2;
    }
    if (exists $range_tr{2}) {
        my @ranges = @{ $range_tr{2} };
        while (my @range = splice(@ranges,0,2)) {
            for my $oct0 (@{$range[0]}) {
                for my $oct1 (@{$range[1]}) {
                    push @chars2, pack 'CC', $oct0,$oct1;
                }
            }
        }
    }
    return @chars2;
}

# 3 octets characters
my @chars3 = ();
sub chars3 {
    if (@chars3) {
        return @chars3;
    }
    if (exists $range_tr{3}) {
        my @ranges = @{ $range_tr{3} };
        while (my @range = splice(@ranges,0,3)) {
            for my $oct0 (@{$range[0]}) {
                for my $oct1 (@{$range[1]}) {
                    for my $oct2 (@{$range[2]}) {
                        push @chars3, pack 'CCC', $oct0,$oct1,$oct2;
                    }
                }
            }
        }
    }
    return @chars3;
}

# 4 octets characters
my @chars4 = ();
sub chars4 {
    if (@chars4) {
        return @chars4;
    }
    if (exists $range_tr{4}) {
        my @ranges = @{ $range_tr{4} };
        while (my @range = splice(@ranges,0,4)) {
            for my $oct0 (@{$range[0]}) {
                for my $oct1 (@{$range[1]}) {
                    for my $oct2 (@{$range[2]}) {
                        for my $oct3 (@{$range[3]}) {
                            push @chars4, pack 'CCCC', $oct0,$oct1,$oct2,$oct3;
                        }
                    }
                }
            }
        }
    }
    return @chars4;
}

#
# KOI8-R open character list for tr
#
sub _charlist_tr {

    local $_ = shift @_;

    # unescape character
    my @char = ();
    while (not /\G \z/oxmsgc) {
        if (/\G (\\0?55|\\x2[Dd]|\\-) /oxmsgc) {
            push @char, '\-';
        }
        elsif (/\G \\ ([0-7]{2,3}) /oxmsgc) {
            push @char, CORE::chr(oct $1);
        }
        elsif (/\G \\x ([0-9A-Fa-f]{1,2}) /oxmsgc) {
            push @char, CORE::chr(hex $1);
        }
        elsif (/\G \\c ([\x40-\x5F]) /oxmsgc) {
            push @char, CORE::chr(CORE::ord($1) & 0x1F);
        }
        elsif (/\G (\\ [0nrtfbae]) /oxmsgc) {
            push @char, {
                '\0' => "\0",
                '\n' => "\n",
                '\r' => "\r",
                '\t' => "\t",
                '\f' => "\f",
                '\b' => "\x08", # \b means backspace in character class
                '\a' => "\a",
                '\e' => "\e",
            }->{$1};
        }
        elsif (/\G \\ ($q_char) /oxmsgc) {
            push @char, $1;
        }
        elsif (/\G ($q_char) /oxmsgc) {
            push @char, $1;
        }
    }

    # join separated multiple-octet
    @char = join('',@char) =~ /\G (?>\\-|$q_char) /oxmsg;

    # unescape '-'
    my @i = ();
    for my $i (0 .. $#char) {
        if ($char[$i] eq '\-') {
            $char[$i] = '-';
        }
        elsif ($char[$i] eq '-') {
            if ((0 < $i) and ($i < $#char)) {
                push @i, $i;
            }
        }
    }

    # open character list (reverse for splice)
    for my $i (CORE::reverse @i) {
        my @range = ();

        # range error
        if ((CORE::length($char[$i-1]) > CORE::length($char[$i+1])) or ($char[$i-1] gt $char[$i+1])) {
            croak "Invalid tr/// range \"\\x" . unpack('H*',$char[$i-1]) . '-\x' . unpack('H*',$char[$i+1]) . '"';
        }

        # range of multiple-octet code
        if (CORE::length($char[$i-1]) == 1) {
            if (CORE::length($char[$i+1]) == 1) {
                push @range, grep {($char[$i-1] le $_) and ($_ le $char[$i+1])} chars1();
            }
            elsif (CORE::length($char[$i+1]) == 2) {
                push @range, grep {$char[$i-1] le $_}                           chars1();
                push @range, grep {$_ le $char[$i+1]}                           chars2();
            }
            elsif (CORE::length($char[$i+1]) == 3) {
                push @range, grep {$char[$i-1] le $_}                           chars1();
                push @range,                                                    chars2();
                push @range, grep {$_ le $char[$i+1]}                           chars3();
            }
            elsif (CORE::length($char[$i+1]) == 4) {
                push @range, grep {$char[$i-1] le $_}                           chars1();
                push @range,                                                    chars2();
                push @range,                                                    chars3();
                push @range, grep {$_ le $char[$i+1]}                           chars4();
            }
            else {
                croak "Invalid tr/// range (over 4octets) \"\\x" . unpack('H*',$char[$i-1]) . '-\x' . unpack('H*',$char[$i+1]) . '"';
            }
        }
        elsif (CORE::length($char[$i-1]) == 2) {
            if (CORE::length($char[$i+1]) == 2) {
                push @range, grep {($char[$i-1] le $_) and ($_ le $char[$i+1])} chars2();
            }
            elsif (CORE::length($char[$i+1]) == 3) {
                push @range, grep {$char[$i-1] le $_}                           chars2();
                push @range, grep {$_ le $char[$i+1]}                           chars3();
            }
            elsif (CORE::length($char[$i+1]) == 4) {
                push @range, grep {$char[$i-1] le $_}                           chars2();
                push @range,                                                    chars3();
                push @range, grep {$_ le $char[$i+1]}                           chars4();
            }
            else {
                croak "Invalid tr/// range (over 4octets) \"\\x" . unpack('H*',$char[$i-1]) . '-\x' . unpack('H*',$char[$i+1]) . '"';
            }
        }
        elsif (CORE::length($char[$i-1]) == 3) {
            if (CORE::length($char[$i+1]) == 3) {
                push @range, grep {($char[$i-1] le $_) and ($_ le $char[$i+1])} chars3();
            }
            elsif (CORE::length($char[$i+1]) == 4) {
                push @range, grep {$char[$i-1] le $_}                           chars3();
                push @range, grep {$_ le $char[$i+1]}                           chars4();
            }
            else {
                croak "Invalid tr/// range (over 4octets) \"\\x" . unpack('H*',$char[$i-1]) . '-\x' . unpack('H*',$char[$i+1]) . '"';
            }
        }
        elsif (CORE::length($char[$i-1]) == 4) {
            if (CORE::length($char[$i+1]) == 4) {
                push @range, grep {($char[$i-1] le $_) and ($_ le $char[$i+1])} chars4();
            }
            else {
                croak "Invalid tr/// range (over 4octets) \"\\x" . unpack('H*',$char[$i-1]) . '-\x' . unpack('H*',$char[$i+1]) . '"';
            }
        }
        else {
            croak "Invalid tr/// range (over 4octets) \"\\x" . unpack('H*',$char[$i-1]) . '-\x' . unpack('H*',$char[$i+1]) . '"';
        }

        splice @char, $i-1, 3, @range;
    }

    return @char;
}

#
# KOI8-R open character class
#
sub _cc {
    if (scalar(@_) == 0) {
        die __FILE__, ": subroutine cc got no parameter.\n";
    }
    elsif (scalar(@_) == 1) {
        return sprintf('\x%02X',$_[0]);
    }
    elsif (scalar(@_) == 2) {
        if ($_[0] > $_[1]) {
            die __FILE__, ": subroutine cc got \$_[0] > \$_[1] parameters).\n";
        }
        elsif ($_[0] == $_[1]) {
            return sprintf('\x%02X',$_[0]);
        }
        elsif (($_[0]+1) == $_[1]) {
            return sprintf('[\\x%02X\\x%02X]',$_[0],$_[1]);
        }
        else {
            return sprintf('[\\x%02X-\\x%02X]',$_[0],$_[1]);
        }
    }
    else {
        die __FILE__, ": subroutine cc got 3 or more parameters (@{[scalar(@_)]} parameters).\n";
    }
}

#
# KOI8-R octet range
#
sub _octets {
    my $length = shift @_;

    if ($length == 1) {
        my($a1) = unpack 'C', $_[0];
        my($z1) = unpack 'C', $_[1];

        if ($a1 > $z1) {
            croak 'Invalid [] range in regexp (CORE::ord(A) > CORE::ord(B)) ' . '\x' . unpack('H*',$a1) . '-\x' . unpack('H*',$z1);
        }

        if ($a1 == $z1) {
            return sprintf('\x%02X',$a1);
        }
        elsif (($a1+1) == $z1) {
            return sprintf('\x%02X\x%02X',$a1,$z1);
        }
        else {
            return sprintf('\x%02X-\x%02X',$a1,$z1);
        }
    }
    else {
        die __FILE__, ": subroutine _octets got invalid length ($length).\n";
    }
}

#
# KOI8-R range regexp
#
sub _range_regexp {
    my($length,$first,$last) = @_;

    my @range_regexp = ();
    if (not exists $range_tr{$length}) {
        return @range_regexp;
    }

    my @ranges = @{ $range_tr{$length} };
    while (my @range = splice(@ranges,0,$length)) {
        my $min = '';
        my $max = '';
        for (my $i=0; $i < $length; $i++) {
            $min .= pack 'C', $range[$i][0];
            $max .= pack 'C', $range[$i][-1];
        }

# min___max
#            FIRST_____________LAST
#       (nothing)

        if ($max lt $first) {
        }

#            **********
#       min_________max
#            FIRST_____________LAST
#            **********

        elsif (($min le $first) and ($first le $max) and ($max le $last)) {
            push @range_regexp, _octets($length,$first,$max,$min,$max);
        }

#            **********************
#            min________________max
#            FIRST_____________LAST
#            **********************

        elsif (($min eq $first) and ($max eq $last)) {
            push @range_regexp, _octets($length,$first,$last,$min,$max);
        }

#                   *********
#                   min___max
#            FIRST_____________LAST
#                   *********

        elsif (($first le $min) and ($max le $last)) {
            push @range_regexp, _octets($length,$min,$max,$min,$max);
        }

#            **********************
#       min__________________________max
#            FIRST_____________LAST
#            **********************

        elsif (($min le $first) and ($last le $max)) {
            push @range_regexp, _octets($length,$first,$last,$min,$max);
        }

#                         *********
#                         min________max
#            FIRST_____________LAST
#                         *********

        elsif (($first le $min) and ($min le $last) and ($last le $max)) {
            push @range_regexp, _octets($length,$min,$last,$min,$max);
        }

#                                    min___max
#            FIRST_____________LAST
#                              (nothing)

        elsif ($last lt $min) {
        }

        else {
            die __FILE__, ": subroutine _range_regexp panic.\n";
        }
    }

    return @range_regexp;
}

#
# KOI8-R open character list for qr and not qr
#
sub _charlist {

    my $modifier = pop @_;
    my @char = @_;

    my $ignorecase = ($modifier =~ /i/oxms) ? 1 : 0;

    # unescape character
    for (my $i=0; $i <= $#char; $i++) {

        # escape - to ...
        if ($char[$i] eq '-') {
            if ((0 < $i) and ($i < $#char)) {
                $char[$i] = '...';
            }
        }

        # octal escape sequence
        elsif ($char[$i] =~ /\A \\o \{ ([0-7]+) \} \z/oxms) {
            $char[$i] = octchr($1);
        }

        # hexadecimal escape sequence
        elsif ($char[$i] =~ /\A \\x \{ ([0-9A-Fa-f]+) \} \z/oxms) {
            $char[$i] = hexchr($1);
        }

        # \b{...}      --> b\{...}
        # \B{...}      --> B\{...}
        # \N{CHARNAME} --> N\{CHARNAME}
        # \p{PROPERTY} --> p\{PROPERTY}
        # \P{PROPERTY} --> P\{PROPERTY}
        elsif ($char[$i] =~ /\A \\ ([bBNpP]) ( \{ ([^0-9\}][^\}]*) \} ) \z/oxms) {
            $char[$i] = $1 . '\\' . $2;
        }

        # \p, \P, \X --> p, P, X
        elsif ($char[$i] =~ /\A \\ ( [pPX] ) \z/oxms) {
            $char[$i] = $1;
        }

        elsif ($char[$i] =~ /\A \\ ([0-7]{2,3}) \z/oxms) {
            $char[$i] = CORE::chr oct $1;
        }
        elsif ($char[$i] =~ /\A \\x ([0-9A-Fa-f]{1,2}) \z/oxms) {
            $char[$i] = CORE::chr hex $1;
        }
        elsif ($char[$i] =~ /\A \\c ([\x40-\x5F]) \z/oxms) {
            $char[$i] = CORE::chr(CORE::ord($1) & 0x1F);
        }
        elsif ($char[$i] =~ /\A (\\ [0nrtfbaedswDSWHVhvR]) \z/oxms) {
            $char[$i] = {
                '\0' => "\0",
                '\n' => "\n",
                '\r' => "\r",
                '\t' => "\t",
                '\f' => "\f",
                '\b' => "\x08", # \b means backspace in character class
                '\a' => "\a",
                '\e' => "\e",
                '\d' => '[0-9]',

                # Vertical tabs are now whitespace
                # \s in a regex now matches a vertical tab in all circumstances.
                # http://search.cpan.org/dist/perl-5.18.0/pod/perldelta.pod#Vertical_tabs_are_now_whitespace
                #            \t  \n  \v  \f  \r space
                # '\s' => '[\x09\x0A    \x0C\x0D\x20]',
                # '\s' => '[\x09\x0A\x0B\x0C\x0D\x20]',
                '\s'   => '\s',

                '\w' => '[0-9A-Z_a-z]',
                '\D' => '${Ekoi8r::eD}',
                '\S' => '${Ekoi8r::eS}',
                '\W' => '${Ekoi8r::eW}',

                '\H' => '${Ekoi8r::eH}',
                '\V' => '${Ekoi8r::eV}',
                '\h' => '[\x09\x20]',
                '\v' => '[\x0A\x0B\x0C\x0D]',
                '\R' => '${Ekoi8r::eR}',

            }->{$1};
        }

        # POSIX-style character classes
        elsif ($ignorecase and ($char[$i] =~ /\A ( \[\: \^? (?:lower|upper) :\] ) \z/oxms)) {
            $char[$i] = {

                '[:lower:]'   => '[\x41-\x5A\x61-\x7A]',
                '[:upper:]'   => '[\x41-\x5A\x61-\x7A]',
                '[:^lower:]'  => '${Ekoi8r::not_lower_i}',
                '[:^upper:]'  => '${Ekoi8r::not_upper_i}',

            }->{$1};
        }
        elsif ($char[$i] =~ /\A ( \[\: \^? (?:alnum|alpha|ascii|blank|cntrl|digit|graph|lower|print|punct|space|upper|word|xdigit) :\] ) \z/oxms) {
            $char[$i] = {

                '[:alnum:]'   => '[\x30-\x39\x41-\x5A\x61-\x7A]',
                '[:alpha:]'   => '[\x41-\x5A\x61-\x7A]',
                '[:ascii:]'   => '[\x00-\x7F]',
                '[:blank:]'   => '[\x09\x20]',
                '[:cntrl:]'   => '[\x00-\x1F\x7F]',
                '[:digit:]'   => '[\x30-\x39]',
                '[:graph:]'   => '[\x21-\x7F]',
                '[:lower:]'   => '[\x61-\x7A]',
                '[:print:]'   => '[\x20-\x7F]',
                '[:punct:]'   => '[\x21-\x2F\x3A-\x3F\x40\x5B-\x5F\x60\x7B-\x7E]',

                # P.174 POSIX-Style Character Classes
                # in Chapter 5: Pattern Matching
                # of ISBN 0-596-00027-8 Programming Perl Third Edition.

                # P.311 11.2.4 Character Classes and other Special Escapes
                # in Chapter 11: perlre: Perl regular expressions
                # of ISBN-13: 978-1-906966-02-7 The Perl Language Reference Manual (for Perl version 5.12.1)

                # P.210 POSIX-Style Character Classes
                # in Chapter 5: Pattern Matching
                # of ISBN 978-0-596-00492-7 Programming Perl 4th Edition.

                '[:space:]'   => '[\s\x0B]', # "\s" plus vertical tab ("\cK")

                '[:upper:]'   => '[\x41-\x5A]',
                '[:word:]'    => '[\x30-\x39\x41-\x5A\x5F\x61-\x7A]',
                '[:xdigit:]'  => '[\x30-\x39\x41-\x46\x61-\x66]',
                '[:^alnum:]'  => '${Ekoi8r::not_alnum}',
                '[:^alpha:]'  => '${Ekoi8r::not_alpha}',
                '[:^ascii:]'  => '${Ekoi8r::not_ascii}',
                '[:^blank:]'  => '${Ekoi8r::not_blank}',
                '[:^cntrl:]'  => '${Ekoi8r::not_cntrl}',
                '[:^digit:]'  => '${Ekoi8r::not_digit}',
                '[:^graph:]'  => '${Ekoi8r::not_graph}',
                '[:^lower:]'  => '${Ekoi8r::not_lower}',
                '[:^print:]'  => '${Ekoi8r::not_print}',
                '[:^punct:]'  => '${Ekoi8r::not_punct}',
                '[:^space:]'  => '${Ekoi8r::not_space}',
                '[:^upper:]'  => '${Ekoi8r::not_upper}',
                '[:^word:]'   => '${Ekoi8r::not_word}',
                '[:^xdigit:]' => '${Ekoi8r::not_xdigit}',

            }->{$1};
        }
        elsif ($char[$i] =~ /\A \\ ($q_char) \z/oxms) {
            $char[$i] = $1;
        }
    }

    # open character list
    my @singleoctet   = ();
    my @multipleoctet = ();
    for (my $i=0; $i <= $#char; ) {

        # escaped -
        if (defined($char[$i+1]) and ($char[$i+1] eq '...')) {
            $i += 1;
            next;
        }

        # make range regexp
        elsif ($char[$i] eq '...') {

            # range error
            if (CORE::length($char[$i-1]) > CORE::length($char[$i+1])) {
                croak 'Invalid [] range in regexp (length(A) > length(B)) ' . '\x' . unpack('H*',$char[$i-1]) . '-\x' . unpack('H*',$char[$i+1]);
            }
            elsif (CORE::length($char[$i-1]) == CORE::length($char[$i+1])) {
                if ($char[$i-1] gt $char[$i+1]) {
                    croak 'Invalid [] range in regexp (CORE::ord(A) > CORE::ord(B)) ' . '\x' . unpack('H*',$char[$i-1]) . '-\x' . unpack('H*',$char[$i+1]);
                }
            }

            # make range regexp per length
            for my $length (CORE::length($char[$i-1]) .. CORE::length($char[$i+1])) {
                my @regexp = ();

                # is first and last
                if (($length == CORE::length($char[$i-1])) and ($length == CORE::length($char[$i+1]))) {
                    push @regexp, _range_regexp($length, $char[$i-1], $char[$i+1]);
                }

                # is first
                elsif ($length == CORE::length($char[$i-1])) {
                    push @regexp, _range_regexp($length, $char[$i-1], "\xFF" x $length);
                }

                # is inside in first and last
                elsif ((CORE::length($char[$i-1]) < $length) and ($length < CORE::length($char[$i+1]))) {
                    push @regexp, _range_regexp($length, "\x00" x $length, "\xFF" x $length);
                }

                # is last
                elsif ($length == CORE::length($char[$i+1])) {
                    push @regexp, _range_regexp($length, "\x00" x $length, $char[$i+1]);
                }

                else {
                    die __FILE__, ": subroutine make_regexp panic.\n";
                }

                if ($length == 1) {
                    push @singleoctet, @regexp;
                }
                else {
                    push @multipleoctet, @regexp;
                }
            }

            $i += 2;
        }

        # with /i modifier
        elsif ($char[$i] =~ /\A [\x00-\xFF] \z/oxms) {
            if ($modifier =~ /i/oxms) {
                my $uc = Ekoi8r::uc($char[$i]);
                my $fc = Ekoi8r::fc($char[$i]);
                if ($uc ne $fc) {
                    if (CORE::length($fc) == 1) {
                        push @singleoctet, $uc, $fc;
                    }
                    else {
                        push @singleoctet,   $uc;
                        push @multipleoctet, $fc;
                    }
                }
                else {
                    push @singleoctet, $char[$i];
                }
            }
            else {
                push @singleoctet, $char[$i];
            }
            $i += 1;
        }

        # single character of single octet code
        elsif ($char[$i] =~ /\A (?: \\h ) \z/oxms) {
            push @singleoctet, "\t", "\x20";
            $i += 1;
        }
        elsif ($char[$i] =~ /\A (?: \\v ) \z/oxms) {
            push @singleoctet, "\x0A", "\x0B", "\x0C", "\x0D";
            $i += 1;
        }
        elsif ($char[$i] =~ /\A (?: \\d | \\s | \\w ) \z/oxms) {
            push @singleoctet, $char[$i];
            $i += 1;
        }

        # single character of multiple-octet code
        else {
            push @multipleoctet, $char[$i];
            $i += 1;
        }
    }

    # quote metachar
    for (@singleoctet) {
        if ($_ eq '...') {
            $_ = '-';
        }
        elsif (/\A \n \z/oxms) {
            $_ = '\n';
        }
        elsif (/\A \r \z/oxms) {
            $_ = '\r';
        }
        elsif (/\A ([\x00-\x20\x7F-\xFF]) \z/oxms) {
            $_ = sprintf('\x%02X', CORE::ord $1);
        }
        elsif (/\A [\x00-\xFF] \z/oxms) {
            $_ = quotemeta $_;
        }
    }

    # return character list
    return \@singleoctet, \@multipleoctet;
}

#
# KOI8-R octal escape sequence
#
sub octchr {
    my($octdigit) = @_;

    my @binary = ();
    for my $octal (split(//,$octdigit)) {
        push @binary, {
            '0' => '000',
            '1' => '001',
            '2' => '010',
            '3' => '011',
            '4' => '100',
            '5' => '101',
            '6' => '110',
            '7' => '111',
        }->{$octal};
    }
    my $binary = join '', @binary;

    my $octchr = {
        #                1234567
        1 => pack('B*', "0000000$binary"),
        2 => pack('B*', "000000$binary"),
        3 => pack('B*', "00000$binary"),
        4 => pack('B*', "0000$binary"),
        5 => pack('B*', "000$binary"),
        6 => pack('B*', "00$binary"),
        7 => pack('B*', "0$binary"),
        0 => pack('B*', "$binary"),

    }->{CORE::length($binary) % 8};

    return $octchr;
}

#
# KOI8-R hexadecimal escape sequence
#
sub hexchr {
    my($hexdigit) = @_;

    my $hexchr = {
        1 => pack('H*', "0$hexdigit"),
        0 => pack('H*', "$hexdigit"),

    }->{CORE::length($_[0]) % 2};

    return $hexchr;
}

#
# KOI8-R open character list for qr
#
sub charlist_qr {

    my $modifier = pop @_;
    my @char = @_;

    my($singleoctet, $multipleoctet) = _charlist(@char, $modifier);
    my @singleoctet   = @$singleoctet;
    my @multipleoctet = @$multipleoctet;

    # return character list
    if (scalar(@singleoctet) >= 1) {

        # with /i modifier
        if ($modifier =~ m/i/oxms) {
            my %singleoctet_ignorecase = ();
            for (@singleoctet) {
                while (s/ \A \\x(..) - \\x(..) //oxms or s/ \A \\x((..)) //oxms) {
                    for my $ord (hex($1) .. hex($2)) {
                        my $char = CORE::chr($ord);
                        my $uc = Ekoi8r::uc($char);
                        my $fc = Ekoi8r::fc($char);
                        if ($uc eq $fc) {
                            $singleoctet_ignorecase{unpack 'C*', $char} = 1;
                        }
                        else {
                            if (CORE::length($fc) == 1) {
                                $singleoctet_ignorecase{unpack 'C*', $uc} = 1;
                                $singleoctet_ignorecase{unpack 'C*', $fc} = 1;
                            }
                            else {
                                $singleoctet_ignorecase{unpack 'C*', $uc} = 1;
                                push @multipleoctet, join '', map {sprintf('\x%02X',$_)} unpack 'C*', $fc;
                            }
                        }
                    }
                }
                if ($_ ne '') {
                    $singleoctet_ignorecase{unpack 'C*', $_} = 1;
                }
            }
            my $i = 0;
            my @singleoctet_ignorecase = ();
            for my $ord (0 .. 255) {
                if (exists $singleoctet_ignorecase{$ord}) {
                    push @{$singleoctet_ignorecase[$i]}, $ord;
                }
                else {
                    $i++;
                }
            }
            @singleoctet = ();
            for my $range (@singleoctet_ignorecase) {
                if (ref $range) {
                    if (scalar(@{$range}) == 1) {
                        push @singleoctet, sprintf('\x%02X', @{$range}[0]);
                    }
                    elsif (scalar(@{$range}) == 2) {
                        push @singleoctet, sprintf('\x%02X\x%02X', @{$range}[0], @{$range}[-1]);
                    }
                    else {
                        push @singleoctet, sprintf('\x%02X-\x%02X', @{$range}[0], @{$range}[-1]);
                    }
                }
            }
        }

        my $not_anchor = '';

        push @multipleoctet, join('', $not_anchor, '[', @singleoctet, ']' );
    }
    if (scalar(@multipleoctet) >= 2) {
        return '(?:' . join('|', @multipleoctet) . ')';
    }
    else {
        return $multipleoctet[0];
    }
}

#
# KOI8-R open character list for not qr
#
sub charlist_not_qr {

    my $modifier = pop @_;
    my @char = @_;

    my($singleoctet, $multipleoctet) = _charlist(@char, $modifier);
    my @singleoctet   = @$singleoctet;
    my @multipleoctet = @$multipleoctet;

    # with /i modifier
    if ($modifier =~ m/i/oxms) {
        my %singleoctet_ignorecase = ();
        for (@singleoctet) {
            while (s/ \A \\x(..) - \\x(..) //oxms or s/ \A \\x((..)) //oxms) {
                for my $ord (hex($1) .. hex($2)) {
                    my $char = CORE::chr($ord);
                    my $uc = Ekoi8r::uc($char);
                    my $fc = Ekoi8r::fc($char);
                    if ($uc eq $fc) {
                        $singleoctet_ignorecase{unpack 'C*', $char} = 1;
                    }
                    else {
                        if (CORE::length($fc) == 1) {
                            $singleoctet_ignorecase{unpack 'C*', $uc} = 1;
                            $singleoctet_ignorecase{unpack 'C*', $fc} = 1;
                        }
                        else {
                            $singleoctet_ignorecase{unpack 'C*', $uc} = 1;
                            push @multipleoctet, join '', map {sprintf('\x%02X',$_)} unpack 'C*', $fc;
                        }
                    }
                }
            }
            if ($_ ne '') {
                $singleoctet_ignorecase{unpack 'C*', $_} = 1;
            }
        }
        my $i = 0;
        my @singleoctet_ignorecase = ();
        for my $ord (0 .. 255) {
            if (exists $singleoctet_ignorecase{$ord}) {
                push @{$singleoctet_ignorecase[$i]}, $ord;
            }
            else {
                $i++;
            }
        }
        @singleoctet = ();
        for my $range (@singleoctet_ignorecase) {
            if (ref $range) {
                if (scalar(@{$range}) == 1) {
                    push @singleoctet, sprintf('\x%02X', @{$range}[0]);
                }
                elsif (scalar(@{$range}) == 2) {
                    push @singleoctet, sprintf('\x%02X\x%02X', @{$range}[0], @{$range}[-1]);
                }
                else {
                    push @singleoctet, sprintf('\x%02X-\x%02X', @{$range}[0], @{$range}[-1]);
                }
            }
        }
    }

    # return character list
    if (scalar(@multipleoctet) >= 1) {
        if (scalar(@singleoctet) >= 1) {

            # any character other than multiple-octet and single octet character class
            return '(?!' . join('|', @multipleoctet) . ')(?:[^' . join('', @singleoctet) . '])';
        }
        else {

            # any character other than multiple-octet character class
            return '(?!' . join('|', @multipleoctet) . ")(?:$your_char)";
        }
    }
    else {
        if (scalar(@singleoctet) >= 1) {

            # any character other than single octet character class
            return                                      '(?:[^' . join('', @singleoctet) . '])';
        }
        else {

            # any character
            return                                      "(?:$your_char)";
        }
    }
}

#
# open file in read mode
#
sub _open_r {
    my(undef,$file) = @_;
    use Fcntl qw(O_RDONLY);
    return CORE::sysopen($_[0], $file, &O_RDONLY);
}

#
# open file in append mode
#
sub _open_a {
    my(undef,$file) = @_;
    use Fcntl qw(O_WRONLY O_APPEND O_CREAT);
    return CORE::sysopen($_[0], $file, &O_WRONLY|&O_APPEND|&O_CREAT);
}

#
# safe system
#
sub _systemx {

    # P.707 29.2.33. exec
    # in Chapter 29: Functions
    # of ISBN 0-596-00027-8 Programming Perl Third Edition.
    #
    # Be aware that in older releases of Perl, exec (and system) did not flush
    # your output buffer, so you needed to enable command buffering by setting $|
    # on one or more filehandles to avoid lost output in the case of exec, or
    # misordererd output in the case of system. This situation was largely remedied
    # in the 5.6 release of Perl. (So, 5.005 release not yet.)

    # P.855 exec
    # in Chapter 27: Functions
    # of ISBN 978-0-596-00492-7 Programming Perl 4th Edition.
    #
    # In very old release of Perl (before v5.6), exec (and system) did not flush
    # your output buffer, so you needed to enable command buffering by setting $|
    # on one or more filehandles to avoid lost output with exec or misordered
    # output with system.

    $| = 1;

    # P.565 23.1.2. Cleaning Up Your Environment
    # in Chapter 23: Security
    # of ISBN 0-596-00027-8 Programming Perl Third Edition.

    # P.656 Cleaning Up Your Environment
    # in Chapter 20: Security
    # of ISBN 978-0-596-00492-7 Programming Perl 4th Edition.

    # local $ENV{'PATH'} = '.';
    local @ENV{qw(IFS CDPATH ENV BASH_ENV)}; # Make %ENV safer

    # P.707 29.2.33. exec
    # in Chapter 29: Functions
    # of ISBN 0-596-00027-8 Programming Perl Third Edition.
    #
    # As we mentioned earlier, exec treats a discrete list of arguments as an
    # indication that it should bypass shell processing. However, there is one
    # place where you might still get tripped up. The exec call (and system, too)
    # will not distinguish between a single scalar argument and an array containing
    # only one element.
    #
    #     @args = ("echo surprise");  # just one element in list
    #     exec @args                  # still subject to shell escapes
    #         or die "exec: $!";      #   because @args == 1
    #
    # To avoid this, you can use the PATHNAME syntax, explicitly duplicating the
    # first argument as the pathname, which forces the rest of the arguments to be
    # interpreted as a list, even if there is only one of them:
    #
    #     exec { $args[0] } @args  # safe even with one-argument list
    #         or die "can't exec @args: $!";

    # P.855 exec
    # in Chapter 27: Functions
    # of ISBN 978-0-596-00492-7 Programming Perl 4th Edition.
    #
    # As we mentioned earlier, exec treats a discrete list of arguments as a
    # directive to bypass shell processing. However, there is one place where
    # you might still get tripped up. The exec call (and system, too) cannot
    # distinguish between a single scalar argument and an array containing
    # only one element.
    #
    #     @args = ("echo surprise");  # just one element in list
    #     exec @args                  # still subject to shell escapes
    #         || die "exec: $!";      #   because @args == 1
    #
    # To avoid this, use the PATHNAME syntax, explicitly duplicating the first
    # argument as the pathname, which forces the rest of the arguments to be
    # interpreted as a list, even if there is only one of them:
    #
    #     exec { $args[0] } @args  # safe even with one-argument list
    #         || die "can't exec @args: $!";

    return CORE::system { $_[0] } @_; # safe even with one-argument list
}

#
# KOI8-R order to character (with parameter)
#
sub Ekoi8r::chr(;$) {

    my $c = @_ ? $_[0] : $_;

    if ($c == 0x00) {
        return "\x00";
    }
    else {
        my @chr = ();
        while ($c > 0) {
            unshift @chr, ($c % 0x100);
            $c = int($c / 0x100);
        }
        return pack 'C*', @chr;
    }
}

#
# KOI8-R order to character (without parameter)
#
sub Ekoi8r::chr_() {

    my $c = $_;

    if ($c == 0x00) {
        return "\x00";
    }
    else {
        my @chr = ();
        while ($c > 0) {
            unshift @chr, ($c % 0x100);
            $c = int($c / 0x100);
        }
        return pack 'C*', @chr;
    }
}

#
# KOI8-R path globbing (with parameter)
#
sub Ekoi8r::glob($) {

    if (wantarray) {
        my @glob = _DOS_like_glob(@_);
        for my $glob (@glob) {
            $glob =~ s{ \A (?:\./)+ }{}oxms;
        }
        return @glob;
    }
    else {
        my $glob = _DOS_like_glob(@_);
        $glob =~ s{ \A (?:\./)+ }{}oxms;
        return $glob;
    }
}

#
# KOI8-R path globbing (without parameter)
#
sub Ekoi8r::glob_() {

    if (wantarray) {
        my @glob = _DOS_like_glob();
        for my $glob (@glob) {
            $glob =~ s{ \A (?:\./)+ }{}oxms;
        }
        return @glob;
    }
    else {
        my $glob = _DOS_like_glob();
        $glob =~ s{ \A (?:\./)+ }{}oxms;
        return $glob;
    }
}

#
# KOI8-R path globbing via File::DosGlob 1.10
#
# Often I confuse "_dosglob" and "_doglob".
# So, I renamed "_dosglob" to "_DOS_like_glob".
#
my %iter;
my %entries;
sub _DOS_like_glob {

    # context (keyed by second cxix argument provided by core)
    my($expr,$cxix) = @_;

    # glob without args defaults to $_
    $expr = $_ if not defined $expr;

    # represents the current user's home directory
    #
    # 7.3. Expanding Tildes in Filenames
    # in Chapter 7. File Access
    # of ISBN 0-596-00313-7 Perl Cookbook, 2nd Edition.
    #
    # and File::HomeDir, File::HomeDir::Windows module

    # DOS-like system
    if ($^O =~ /\A (?: MSWin32 | NetWare | symbian | dos ) \z/oxms) {
        $expr =~ s{ \A ~ (?= [^/\\] ) }
                  { my_home_MSWin32() }oxmse;
    }

    # UNIX-like system
    else {
        $expr =~ s{ \A ~ ( (?:[^/])* ) }
                  { $1 ? (CORE::eval(q{(getpwnam($1))[7]})||my_home()) : my_home() }oxmse;
    }

    # assume global context if not provided one
    $cxix = '_G_' if not defined $cxix;
    $iter{$cxix} = 0 if not exists $iter{$cxix};

    # if we're just beginning, do it all first
    if ($iter{$cxix} == 0) {
            $entries{$cxix} = [ _do_glob(1, _parse_line($expr)) ];
    }

    # chuck it all out, quick or slow
    if (wantarray) {
        delete $iter{$cxix};
        return @{delete $entries{$cxix}};
    }
    else {
        if ($iter{$cxix} = scalar @{$entries{$cxix}}) {
            return shift @{$entries{$cxix}};
        }
        else {
            # return undef for EOL
            delete $iter{$cxix};
            delete $entries{$cxix};
            return undef;
        }
    }
}

#
# KOI8-R path globbing subroutine
#
sub _do_glob {

    my($cond,@expr) = @_;
    my @glob = ();
    my $fix_drive_relative_paths = 0;

OUTER:
    for my $expr (@expr) {
        next OUTER if not defined $expr;
        next OUTER if $expr eq '';

        my @matched = ();
        my @globdir = ();
        my $head    = '.';
        my $pathsep = '/';
        my $tail;

        # if argument is within quotes strip em and do no globbing
        if ($expr =~ /\A " ((?:$q_char)*?) " \z/oxms) {
            $expr = $1;
            if ($cond eq 'd') {
                if (-d $expr) {
                    push @glob, $expr;
                }
            }
            else {
                if (-e $expr) {
                    push @glob, $expr;
                }
            }
            next OUTER;
        }

        # wildcards with a drive prefix such as h:*.pm must be changed
        # to h:./*.pm to expand correctly
        if ($^O =~ /\A (?: MSWin32 | NetWare | symbian | dos ) \z/oxms) {
            if ($expr =~ s# \A ((?:[A-Za-z]:)?) ([^/\\]) #$1./$2#oxms) {
                $fix_drive_relative_paths = 1;
            }
        }

        if (($head, $tail) = _parse_path($expr,$pathsep)) {
            if ($tail eq '') {
                push @glob, $expr;
                next OUTER;
            }
            if ($head =~ / \A (?:$q_char)*? [*?] /oxms) {
                if (@globdir = _do_glob('d', $head)) {
                    push @glob, _do_glob($cond, map {"$_$pathsep$tail"} @globdir);
                    next OUTER;
                }
            }
            if ($head eq '' or $head =~ /\A [A-Za-z]: \z/oxms) {
                $head .= $pathsep;
            }
            $expr = $tail;
        }

        # If file component has no wildcards, we can avoid opendir
        if ($expr !~ / \A (?:$q_char)*? [*?] /oxms) {
            if ($head eq '.') {
                $head = '';
            }
            if ($head ne '' and ($head =~ / \G ($q_char) /oxmsg)[-1] ne $pathsep) {
                $head .= $pathsep;
            }
            $head .= $expr;
            if ($cond eq 'd') {
                if (-d $head) {
                    push @glob, $head;
                }
            }
            else {
                if (-e $head) {
                    push @glob, $head;
                }
            }
            next OUTER;
        }
        opendir(*DIR, $head) or next OUTER;
        my @leaf = readdir DIR;
        closedir DIR;

        if ($head eq '.') {
            $head = '';
        }
        if ($head ne '' and ($head =~ / \G ($q_char) /oxmsg)[-1] ne $pathsep) {
            $head .= $pathsep;
        }

        my $pattern = '';
        while ($expr =~ / \G ($q_char) /oxgc) {
            my $char = $1;

            # 6.9. Matching Shell Globs as Regular Expressions
            # in Chapter 6. Pattern Matching
            # of ISBN 0-596-00313-7 Perl Cookbook, 2nd Edition.
            # (and so on)

            if ($char eq '*') {
                $pattern .= "(?:$your_char)*",
            }
            elsif ($char eq '?') {
                $pattern .= "(?:$your_char)?",  # DOS style
#               $pattern .= "(?:$your_char)",   # UNIX style
            }
            elsif ((my $fc = Ekoi8r::fc($char)) ne $char) {
                $pattern .= $fc;
            }
            else {
                $pattern .= quotemeta $char;
            }
        }
        my $matchsub = sub { Ekoi8r::fc($_[0]) =~ /\A $pattern \z/xms };

#       if ($@) {
#           print STDERR "$0: $@\n";
#           next OUTER;
#       }

INNER:
        for my $leaf (@leaf) {
            if ($leaf eq '.' or $leaf eq '..') {
                next INNER;
            }
            if ($cond eq 'd' and not -d "$head$leaf") {
                next INNER;
            }

            if (&$matchsub($leaf)) {
                push @matched, "$head$leaf";
                next INNER;
            }

            # [DOS compatibility special case]
            # Failed, add a trailing dot and try again, but only...

            if (Ekoi8r::index($leaf,'.') == -1 and   # if name does not have a dot in it *and*
                CORE::length($leaf) <= 8 and        # name is shorter than or equal to 8 chars *and*
                Ekoi8r::index($pattern,'\\.') != -1  # pattern has a dot.
            ) {
                if (&$matchsub("$leaf.")) {
                    push @matched, "$head$leaf";
                    next INNER;
                }
            }
        }
        if (@matched) {
            push @glob, @matched;
        }
    }
    if ($fix_drive_relative_paths) {
        for my $glob (@glob) {
            $glob =~ s# \A ([A-Za-z]:) \./ #$1#oxms;
        }
    }
    return @glob;
}

#
# KOI8-R parse line
#
sub _parse_line {

    my($line) = @_;

    $line .= ' ';
    my @piece = ();
    while ($line =~ /
        " ( (?>(?: [^"]   )* ) ) " (?>\s+) |
          ( (?>(?: [^"\s] )* ) )   (?>\s+)
        /oxmsg
    ) {
        push @piece, defined($1) ? $1 : $2;
    }
    return @piece;
}

#
# KOI8-R parse path
#
sub _parse_path {

    my($path,$pathsep) = @_;

    $path .= '/';
    my @subpath = ();
    while ($path =~ /
        ((?: [^\/\\] )+?) [\/\\]
        /oxmsg
    ) {
        push @subpath, $1;
    }

    my $tail = pop @subpath;
    my $head = join $pathsep, @subpath;
    return $head, $tail;
}

#
# via File::HomeDir::Windows 1.00
#
sub my_home_MSWin32 {

    # A lot of unix people and unix-derived tools rely on
    # the ability to overload HOME. We will support it too
    # so that they can replace raw HOME calls with File::HomeDir.
    if (exists $ENV{'HOME'} and $ENV{'HOME'}) {
        return $ENV{'HOME'};
    }

    # Do we have a user profile?
    elsif (exists $ENV{'USERPROFILE'} and $ENV{'USERPROFILE'}) {
        return $ENV{'USERPROFILE'};
    }

    # Some Windows use something like $ENV{'HOME'}
    elsif (exists $ENV{'HOMEDRIVE'} and exists $ENV{'HOMEPATH'} and $ENV{'HOMEDRIVE'} and $ENV{'HOMEPATH'}) {
        return join '', $ENV{'HOMEDRIVE'}, $ENV{'HOMEPATH'};
    }

    return undef;
}

#
# via File::HomeDir::Unix 1.00
#
sub my_home {
    my $home;

    if (exists $ENV{'HOME'} and defined $ENV{'HOME'}) {
        $home = $ENV{'HOME'};
    }

    # This is from the original code, but I'm guessing
    # it means "login directory" and exists on some Unixes.
    elsif (exists $ENV{'LOGDIR'} and $ENV{'LOGDIR'}) {
        $home = $ENV{'LOGDIR'};
    }

    ### More-desperate methods

    # Light desperation on any (Unixish) platform
    else {
        $home = CORE::eval q{ (getpwuid($<))[7] };
    }

    # On Unix in general, a non-existant home means "no home"
    # For example, "nobody"-like users might use /nonexistant
    if (defined $home and ! -d($home)) {
        $home = undef;
    }
    return $home;
}

#
# ${^PREMATCH}, $PREMATCH, $` the string preceding what was matched
#
sub Ekoi8r::PREMATCH {
    return $`;
}

#
# ${^MATCH}, $MATCH, $& the string that matched
#
sub Ekoi8r::MATCH {
    return $&;
}

#
# ${^POSTMATCH}, $POSTMATCH, $' the string following what was matched
#
sub Ekoi8r::POSTMATCH {
    return $';
}

#
# KOI8-R character to order (with parameter)
#
sub KOI8R::ord(;$) {

    local $_ = shift if @_;

    if (/\A ($q_char) /oxms) {
        my @ord = unpack 'C*', $1;
        my $ord = 0;
        while (my $o = shift @ord) {
            $ord = $ord * 0x100 + $o;
        }
        return $ord;
    }
    else {
        return CORE::ord $_;
    }
}

#
# KOI8-R character to order (without parameter)
#
sub KOI8R::ord_() {

    if (/\A ($q_char) /oxms) {
        my @ord = unpack 'C*', $1;
        my $ord = 0;
        while (my $o = shift @ord) {
            $ord = $ord * 0x100 + $o;
        }
        return $ord;
    }
    else {
        return CORE::ord $_;
    }
}

#
# KOI8-R reverse
#
sub KOI8R::reverse(@) {

    if (wantarray) {
        return CORE::reverse @_;
    }
    else {

        # One of us once cornered Larry in an elevator and asked him what
        # problem he was solving with this, but he looked as far off into
        # the distance as he could in an elevator and said, "It seemed like
        # a good idea at the time."

        return join '', CORE::reverse(join('',@_) =~ /\G ($q_char) /oxmsg);
    }
}

#
# KOI8-R getc (with parameter, without parameter)
#
sub KOI8R::getc(;*@) {

    my($package) = caller;
    my $fh = @_ ? qualify_to_ref(shift,$package) : \*STDIN;
    croak 'Too many arguments for KOI8R::getc' if @_ and not wantarray;

    my @length = sort { $a <=> $b } keys %range_tr;
    my $getc = '';
    for my $length ($length[0] .. $length[-1]) {
        $getc .= CORE::getc($fh);
        if (exists $range_tr{CORE::length($getc)}) {
            if ($getc =~ /\A ${Ekoi8r::dot_s} \z/oxms) {
                return wantarray ? ($getc,@_) : $getc;
            }
        }
    }
    return wantarray ? ($getc,@_) : $getc;
}

#
# KOI8-R length by character
#
sub KOI8R::length(;$) {

    local $_ = shift if @_;

    local @_ = /\G ($q_char) /oxmsg;
    return scalar @_;
}

#
# KOI8-R substr by character
#
BEGIN {

    # P.232 The lvalue Attribute
    # in Chapter 6: Subroutines
    # of ISBN 0-596-00027-8 Programming Perl Third Edition.

    # P.336 The lvalue Attribute
    # in Chapter 7: Subroutines
    # of ISBN 978-0-596-00492-7 Programming Perl 4th Edition.

    # P.144 8.4 Lvalue subroutines
    # in Chapter 8: perlsub: Perl subroutines
    # of ISBN-13: 978-1-906966-02-7 The Perl Language Reference Manual (for Perl version 5.12.1)

    CORE::eval sprintf(<<'END', ($] >= 5.014000) ? ':lvalue' : '');
    #                       vv----------------------*******
    sub KOI8R::substr($$;$$) %s {

        my @char = $_[0] =~ /\G (?>$q_char) /oxmsg;

        # If the substring is beyond either end of the string, substr() returns the undefined
        # value and produces a warning. When used as an lvalue, specifying a substring that
        # is entirely outside the string raises an exception.
        # http://perldoc.perl.org/functions/substr.html

        # A return with no argument returns the scalar value undef in scalar context,
        # an empty list () in list context, and (naturally) nothing at all in void
        # context.

        my $offset = $_[1];
        if (($offset > scalar(@char)) or ($offset < (-1 * scalar(@char)))) {
            return;
        }

        # substr($string,$offset,$length,$replacement)
        if (@_ == 4) {
            my(undef,undef,$length,$replacement) = @_;
            my $substr = join '', splice(@char, $offset, $length, $replacement);
            $_[0] = join '', @char;

            # return $substr; this doesn't work, don't say "return"
            $substr;
        }

        # substr($string,$offset,$length)
        elsif (@_ == 3) {
            my(undef,undef,$length) = @_;
            my $octet_offset = 0;
            my $octet_length = 0;
            if ($offset == 0) {
                $octet_offset = 0;
            }
            elsif ($offset > 0) {
                local $SIG{__WARN__} = sub {}; # avoid: Use of uninitialized value in join or string at here
                $octet_offset =      CORE::length(join '', @char[0..$offset-1]);
            }
            else {
                local $SIG{__WARN__} = sub {}; # avoid: Use of uninitialized value in join or string at here
                $octet_offset = -1 * CORE::length(join '', @char[$#char+$offset+1..$#char]);
            }
            if ($length == 0) {
                $octet_length = 0;
            }
            elsif ($length > 0) {
                local $SIG{__WARN__} = sub {}; # avoid: Use of uninitialized value in join or string at here
                $octet_length =      CORE::length(join '', @char[$offset..$offset+$length-1]);
            }
            else {
                local $SIG{__WARN__} = sub {}; # avoid: Use of uninitialized value in join or string at here
                $octet_length = -1 * CORE::length(join '', @char[$#char+$length+1..$#char]);
            }
            CORE::substr($_[0], $octet_offset, $octet_length);
        }

        # substr($string,$offset)
        else {
            my $octet_offset = 0;
            if ($offset == 0) {
                $octet_offset = 0;
            }
            elsif ($offset > 0) {
                $octet_offset =      CORE::length(join '', @char[0..$offset-1]);
            }
            else {
                $octet_offset = -1 * CORE::length(join '', @char[$#char+$offset+1..$#char]);
            }
            CORE::substr($_[0], $octet_offset);
        }
    }
END
}

#
# KOI8-R index by character
#
sub KOI8R::index($$;$) {

    my $index;
    if (@_ == 3) {
        $index = Ekoi8r::index($_[0], $_[1], CORE::length(KOI8R::substr($_[0], 0, $_[2])));
    }
    else {
        $index = Ekoi8r::index($_[0], $_[1]);
    }

    if ($index == -1) {
        return -1;
    }
    else {
        return KOI8R::length(CORE::substr $_[0], 0, $index);
    }
}

#
# KOI8-R rindex by character
#
sub KOI8R::rindex($$;$) {

    my $rindex;
    if (@_ == 3) {
        $rindex = Ekoi8r::rindex($_[0], $_[1], CORE::length(KOI8R::substr($_[0], 0, $_[2])));
    }
    else {
        $rindex = Ekoi8r::rindex($_[0], $_[1]);
    }

    if ($rindex == -1) {
        return -1;
    }
    else {
        return KOI8R::length(CORE::substr $_[0], 0, $rindex);
    }
}

# when 'm//', '/' means regexp match 'm//' and '?' means regexp match '??'
# when 'div', '/' means division operator and '?' means conditional operator (condition ? then : else)
use vars qw($slash); $slash = 'm//';

# ord() to ord() or KOI8R::ord()
my $function_ord = 'ord';

# ord to ord or KOI8R::ord_
my $function_ord_ = 'ord';

# reverse to reverse or KOI8R::reverse
my $function_reverse = 'reverse';

# getc to getc or KOI8R::getc
my $function_getc = 'getc';

# P.1023 Appendix W.9 Multibyte Anchoring
# of ISBN 1-56592-224-7 CJKV Information Processing

my $anchor = '';

use vars qw($nest);

# regexp of nested parens in qqXX

# P.340 Matching Nested Constructs with Embedded Code
# in Chapter 7: Perl
# of ISBN 0-596-00289-0 Mastering Regular Expressions, Second edition

my $qq_paren   = qr{(?{local $nest=0}) (?>(?:
                       [^\\()] |
                           \(  (?{$nest++}) |
                           \)  (?(?{$nest>0})(?{$nest--})|(?!)))*) (?(?{$nest!=0})(?!)) |
                    \\ [^c] |
                    \\c[\x40-\x5F] |
                       [\x00-\xFF]
                 }xms;

my $qq_brace   = qr{(?{local $nest=0}) (?>(?:
                       [^\\{}] |
                           \{  (?{$nest++}) |
                           \}  (?(?{$nest>0})(?{$nest--})|(?!)))*) (?(?{$nest!=0})(?!)) |
                    \\ [^c] |
                    \\c[\x40-\x5F] |
                       [\x00-\xFF]
                 }xms;

my $qq_bracket = qr{(?{local $nest=0}) (?>(?:
                       [^\\\[\]] |
                           \[  (?{$nest++}) |
                           \]  (?(?{$nest>0})(?{$nest--})|(?!)))*) (?(?{$nest!=0})(?!)) |
                    \\ [^c] |
                    \\c[\x40-\x5F] |
                       [\x00-\xFF]
                 }xms;

my $qq_angle   = qr{(?{local $nest=0}) (?>(?:
                       [^\\<>] |
                           \<  (?{$nest++}) |
                           \>  (?(?{$nest>0})(?{$nest--})|(?!)))*) (?(?{$nest!=0})(?!)) |
                    \\ [^c] |
                    \\c[\x40-\x5F] |
                       [\x00-\xFF]
                 }xms;

my $qq_scalar  = qr{(?: \{ (?:$qq_brace)*? \} |
                       (?: ::)? (?:
                             (?> [a-zA-Z_][a-zA-Z_0-9]* (?: ::[a-zA-Z_][a-zA-Z_0-9]*)* )
                                                    (?>(?:                                   \[ (?: \$\[ | \$\] | $qq_char )*? \] |           \{ (?:$qq_brace)*? \} )*)
                                      (?>(?: (?: -> )? (?: [\$\@\%\&\*]\* | \$\#\* | [\@\%]? \[ (?: \$\[ | \$\] | $qq_char )*? \] | [\@\%\*]? \{ (?:$qq_brace)*? \} ) )*)
                   ))
                 }xms;

my $qq_variable = qr{(?: \{ (?:$qq_brace)*? \}                    |
                        (?: ::)? (?:
                              (?>[0-9]+)                          |
                              [^a-zA-Z_0-9\[\]] |
                              ^[A-Z]                              |
                              (?> [a-zA-Z_][a-zA-Z_0-9]* (?: ::[a-zA-Z_][a-zA-Z_0-9]*)* )
                                                     (?>(?:                                   \[ (?: \$\[ | \$\] | $qq_char )*? \] |           \{ (?:$qq_brace)*? \} )*)
                                       (?>(?: (?: -> )? (?: [\$\@\%\&\*]\* | \$\#\* | [\@\%]? \[ (?: \$\[ | \$\] | $qq_char )*? \] | [\@\%\*]? \{ (?:$qq_brace)*? \} ) )*)
                    ))
                  }xms;

my $qq_substr  = qr{(?> Char::substr | KOI8R::substr | CORE::substr | substr ) (?>\s*) \( $qq_paren \)
                 }xms;

# regexp of nested parens in qXX
my $q_paren    = qr{(?{local $nest=0}) (?>(?:
                       [^()] |
                             \(  (?{$nest++}) |
                             \)  (?(?{$nest>0})(?{$nest--})|(?!)))*) (?(?{$nest!=0})(?!)) |
                       [\x00-\xFF]
                 }xms;

my $q_brace    = qr{(?{local $nest=0}) (?>(?:
                       [^\{\}] |
                             \{  (?{$nest++}) |
                             \}  (?(?{$nest>0})(?{$nest--})|(?!)))*) (?(?{$nest!=0})(?!)) |
                       [\x00-\xFF]
                 }xms;

my $q_bracket  = qr{(?{local $nest=0}) (?>(?:
                       [^\[\]] |
                             \[  (?{$nest++}) |
                             \]  (?(?{$nest>0})(?{$nest--})|(?!)))*) (?(?{$nest!=0})(?!)) |
                    [\x00-\xFF]
                 }xms;

my $q_angle    = qr{(?{local $nest=0}) (?>(?:
                    [^<>] |
                             \<  (?{$nest++}) |
                             \>  (?(?{$nest>0})(?{$nest--})|(?!)))*) (?(?{$nest!=0})(?!)) |
                    [\x00-\xFF]
                 }xms;

my $matched     = '';
my $s_matched   = '';

my $tr_variable   = '';   # variable of tr///
my $sub_variable  = '';   # variable of s///
my $bind_operator = '';   # =~ or !~

my @heredoc = ();         # here document
my @heredoc_delimiter = ();
my $here_script = '';     # here script

#
# escape KOI8-R script
#
sub KOI8R::escape(;$) {
    local($_) = $_[0] if @_;

    # P.359 The Study Function
    # in Chapter 7: Perl
    # of ISBN 0-596-00289-0 Mastering Regular Expressions, Second edition

    study $_; # Yes, I studied study yesterday.

    # while all script

    # 6.14. Matching from Where the Last Pattern Left Off
    # in Chapter 6. Pattern Matching
    # of ISBN 0-596-00313-7 Perl Cookbook, 2nd Edition.
    # (and so on)

    # one member of Tag-team
    #
    # P.128 Start of match (or end of previous match): \G
    # P.130 Advanced Use of \G with Perl
    # in Chapter 3: Overview of Regular Expression Features and Flavors
    # P.255 Use leading anchors
    # P.256 Expose ^ and \G at the front expressions
    # in Chapter 6: Crafting an Efficient Expression
    # P.315 "Tag-team" matching with /gc
    # in Chapter 7: Perl
    # of ISBN 0-596-00289-0 Mastering Regular Expressions, Second edition

    my $e_script = '';
    while (not /\G \z/oxgc) { # member
        $e_script .= KOI8R::escape_token();
    }

    return $e_script;
}

#
# escape KOI8-R token of script
#
sub KOI8R::escape_token {

# \n output here document

    my $ignore_modules = join('|', qw(
        utf8
        bytes
        charnames
        I18N::Japanese
        I18N::Collate
        I18N::JExt
        File::DosGlob
        Wild
        Wildcard
        Japanese
    ));

    # another member of Tag-team
    #
    # P.315 "Tag-team" matching with /gc
    # in Chapter 7: Perl
    # of ISBN 0-596-00289-0 Mastering Regular Expressions, Second edition

    if (/\G ( \n ) /oxgc) { # another member (and so on)
        my $heredoc = '';
        if (scalar(@heredoc_delimiter) >= 1) {
            $slash = 'm//';

            $heredoc = join '', @heredoc;
            @heredoc = ();

            # skip here document
            for my $heredoc_delimiter (@heredoc_delimiter) {
                /\G .*? \n $heredoc_delimiter \n/xmsgc;
            }
            @heredoc_delimiter = ();

            $here_script = '';
        }
        return "\n" . $heredoc;
    }

# ignore space, comment
    elsif (/\G ((?>\s+)|\#.*) /oxgc) { return $1; }

# if (, elsif (, unless (, while (, until (, given (, and when (

    # given, when

    # P.225 The given Statement
    # in Chapter 15: Smart Matching and given-when
    # of ISBN 978-0-596-52010-6 Learning Perl, Fifth Edition

    # P.133 The given Statement
    # in Chapter 4: Statements and Declarations
    # of ISBN 978-0-596-00492-7 Programming Perl 4th Edition.

    elsif (/\G ( (?: if | elsif | unless | while | until | given | when ) (?>\s*) \( ) /oxgc) {
        $slash = 'm//';
        return $1;
    }

# scalar variable ($scalar = ...) =~ tr///;
# scalar variable ($scalar = ...) =~ s///;

    # state

    # P.68 Persistent, Private Variables
    # in Chapter 4: Subroutines
    # of ISBN 978-0-596-52010-6 Learning Perl, Fifth Edition

    # P.160 Persistent Lexically Scoped Variables: state
    # in Chapter 4: Statements and Declarations
    # of ISBN 978-0-596-00492-7 Programming Perl 4th Edition.

    # (and so on)

    elsif (/\G ( \( (?>\s*) (?: local \b | my \b | our \b | state \b )? (?>\s*) \$ $qq_scalar ) /oxgc) {
        my $e_string = e_string($1);

        if (/\G ( (?>\s*) = $qq_paren \) ) ( (?>\s*) (?: =~ | !~ ) (?>\s*) ) (?= (?: tr | y ) \b ) /oxgc) {
            $tr_variable = $e_string . e_string($1);
            $bind_operator = $2;
            $slash = 'm//';
            return '';
        }
        elsif (/\G ( (?>\s*) = $qq_paren \) ) ( (?>\s*) (?: =~ | !~ ) (?>\s*) ) (?= s \b ) /oxgc) {
            $sub_variable = $e_string . e_string($1);
            $bind_operator = $2;
            $slash = 'm//';
            return '';
        }
        else {
            $slash = 'div';
            return $e_string;
        }
    }

# $`, ${`}, $PREMATCH, ${PREMATCH}, ${^PREMATCH} --> Ekoi8r::PREMATCH()
    elsif (/\G ( \$` | \$\{`\} | \$ (?>\s*) PREMATCH  \b | \$ (?>\s*) \{ (?>\s*) PREMATCH  (?>\s*) \} | \$ (?>\s*) \{\^PREMATCH\}  ) /oxmsgc) {
        $slash = 'div';
        return q{Ekoi8r::PREMATCH()};
    }

# $&, ${&}, $MATCH, ${MATCH}, ${^MATCH} --> Ekoi8r::MATCH()
    elsif (/\G ( \$& | \$\{&\} | \$ (?>\s*) MATCH     \b | \$ (?>\s*) \{ (?>\s*) MATCH     (?>\s*) \} | \$ (?>\s*) \{\^MATCH\}     ) /oxmsgc) {
        $slash = 'div';
        return q{Ekoi8r::MATCH()};
    }

# $', ${'} --> $', ${'}
    elsif (/\G ( \$' | \$\{'\}                                                                                                     ) /oxmsgc) {
        $slash = 'div';
        return $1;
    }

# $POSTMATCH, ${POSTMATCH}, ${^POSTMATCH} --> Ekoi8r::POSTMATCH()
    elsif (/\G (                 \$ (?>\s*) POSTMATCH \b | \$ (?>\s*) \{ (?>\s*) POSTMATCH (?>\s*) \} | \$ (?>\s*) \{\^POSTMATCH\} ) /oxmsgc) {
        $slash = 'div';
        return q{Ekoi8r::POSTMATCH()};
    }

# scalar variable $scalar =~ tr///;
# scalar variable $scalar =~ s///;
# substr() =~ tr///;
# substr() =~ s///;
    elsif (/\G ( \$ $qq_scalar | $qq_substr ) /oxgc) {
        my $scalar = e_string($1);

        if (/\G (    (?>\s*) (?: =~ | !~ ) (?>\s*) ) (?= (?: tr | y ) \b ) /oxgc) {
            $tr_variable = $scalar;
            $bind_operator = $1;
            $slash = 'm//';
            return '';
        }
        elsif (/\G ( (?>\s*) (?: =~ | !~ ) (?>\s*) ) (?= s            \b ) /oxgc) {
            $sub_variable = $scalar;
            $bind_operator = $1;
            $slash = 'm//';
            return '';
        }
        else {
            $slash = 'div';
            return $scalar;
        }
    }

    # end of statement
    elsif (/\G ( [,;] ) /oxgc) {
        $slash = 'm//';

        # clear tr/// variable
        $tr_variable  = '';

        # clear s/// variable
        $sub_variable  = '';

        $bind_operator = '';

        return $1;
    }

# bareword
    elsif (/\G ( \{ (?>\s*) (?: tr | index | rindex | reverse ) (?>\s*) \} ) /oxmsgc) {
        return $1;
    }

# $0 --> $0
    elsif (/\G ( \$ 0 ) /oxmsgc) {
        $slash = 'div';
        return $1;
    }
    elsif (/\G ( \$ \{ (?>\s*) 0 (?>\s*) \} ) /oxmsgc) {
        $slash = 'div';
        return $1;
    }

# $$ --> $$
    elsif (/\G ( \$ \$ ) (?![\w\{]) /oxmsgc) {
        $slash = 'div';
        return $1;
    }

# $1, $2, $3 --> $2, $3, $4 after s/// with multibyte anchoring
# $1, $2, $3 --> $1, $2, $3 otherwise
    elsif (/\G \$ ((?>[1-9][0-9]*)) /oxmsgc) {
        $slash = 'div';
        return e_capture($1);
    }
    elsif (/\G \$ \{ (?>\s*) ((?>[1-9][0-9]*)) (?>\s*) \} /oxmsgc) {
        $slash = 'div';
        return e_capture($1);
    }

# $$foo[ ... ] --> $ $foo->[ ... ]
    elsif (/\G \$ ( \$ (?> [A-Za-z_][A-Za-z0-9_]*(?: ::[A-Za-z_][A-Za-z0-9_]*)* )) ( \[ .+? \] ) /oxmsgc) {
        $slash = 'div';
        return e_capture($1.'->'.$2);
    }

# $$foo{ ... } --> $ $foo->{ ... }
    elsif (/\G \$ ( \$ (?> [A-Za-z_][A-Za-z0-9_]*(?: ::[A-Za-z_][A-Za-z0-9_]*)* )) ( \{ .+? \} ) /oxmsgc) {
        $slash = 'div';
        return e_capture($1.'->'.$2);
    }

# $$foo
    elsif (/\G \$ ( \$ (?> [A-Za-z_][A-Za-z0-9_]*(?: ::[A-Za-z_][A-Za-z0-9_]*)* )) /oxmsgc) {
        $slash = 'div';
        return e_capture($1);
    }

# ${ foo }
    elsif (/\G \$ (?>\s*) \{ ( (?>\s*) (?> [A-Za-z_][A-Za-z0-9_]*(?: ::[A-Za-z_][A-Za-z0-9_]*)* ) (?>\s*) ) \} /oxmsgc) {
        $slash = 'div';
        return '${' . $1 . '}';
    }

# ${ ... }
    elsif (/\G \$ (?>\s*) \{ (?>\s*) ( $qq_brace ) (?>\s*) \} /oxmsgc) {
        $slash = 'div';
        return e_capture($1);
    }

# variable or function
    #                  $ @ % & *     $ #
    elsif (/\G ( (?: [\$\@\%\&\*] | \$\# | -> | \b sub \b) (?>\s*) (?: split | chop | index | rindex | lc | uc | fc | chr | ord | reverse | getc | tr | y | q | qq | qx | qw | m | s | qr | glob | lstat | opendir | stat | unlink | chdir ) ) \b /oxmsgc) {
        $slash = 'div';
        return $1;
    }
    #                $ $ $ $ $ $ $ $ $ $ $ $ $ $
    #                $ @ # \ ' " / ? ( ) [ ] < >
    elsif (/\G ( \$[\$\@\#\\\'\"\/\?\(\)\[\]\<\>] ) /oxmsgc) {
        $slash = 'div';
        return $1;
    }

# while (<FILEHANDLE>)
    elsif (/\G \b (while (?>\s*) \( (?>\s*) <[\$]?[A-Za-z_][A-Za-z_0-9]*> (?>\s*) \)) \b /oxgc) {
        return $1;
    }

# while (<WILDCARD>) --- glob

    # avoid "Error: Runtime exception" of perl version 5.005_03

    elsif (/\G \b while (?>\s*) \( (?>\s*) < ((?:[^>\0\a\e\f\n\r\t])+?) > (?>\s*) \) \b /oxgc) {
        return 'while ($_ = Ekoi8r::glob("' . $1 . '"))';
    }

# while (glob)
    elsif (/\G \b while (?>\s*) \( (?>\s*) glob (?>\s*) \) /oxgc) {
        return 'while ($_ = Ekoi8r::glob_)';
    }

# while (glob(WILDCARD))
    elsif (/\G \b while (?>\s*) \( (?>\s*) glob \b /oxgc) {
        return 'while ($_ = Ekoi8r::glob';
    }

# doit if, doit unless, doit while, doit until, doit for, doit when
    elsif (/\G \b ( if | unless | while | until | for | when ) \b /oxgc) { $slash = 'm//'; return $1; }

# subroutines of package Ekoi8r
    elsif (/\G \b (CORE:: | ->(>?\s*) (?: atan2 | [a-z]{2,})) \b       /oxgc) { $slash = 'm//'; return $1;                  }
    elsif (/\G \b Char::eval       (?= (?>\s*) \{ )                    /oxgc) { $slash = 'm//'; return 'eval';              }
    elsif (/\G \b KOI8R::eval       (?= (?>\s*) \{ )                    /oxgc) { $slash = 'm//'; return 'eval';              }
    elsif (/\G \b Char::eval    \b (?! (?>\s*) => )                    /oxgc) { $slash = 'm//'; return 'eval Char::escape'; }
    elsif (/\G \b KOI8R::eval    \b (?! (?>\s*) => )                    /oxgc) { $slash = 'm//'; return 'eval KOI8R::escape'; }
    elsif (/\G \b bytes::substr \b (?! (?>\s*) => )                    /oxgc) { $slash = 'm//'; return 'substr';            }
    elsif (/\G \b chop \b          (?! (?>\s*) => )                    /oxgc) { $slash = 'm//'; return 'Ekoi8r::chop';       }
    elsif (/\G \b bytes::index \b  (?! (?>\s*) => )                    /oxgc) { $slash = 'm//'; return 'index';             }
    elsif (/\G \b Char::index \b   (?! (?>\s*) => )                    /oxgc) { $slash = 'm//'; return 'Char::index';       }
    elsif (/\G \b KOI8R::index \b   (?! (?>\s*) => )                    /oxgc) { $slash = 'm//'; return 'KOI8R::index';       }
    elsif (/\G \b index \b         (?! (?>\s*) => )                    /oxgc) { $slash = 'm//'; return 'Ekoi8r::index';      }
    elsif (/\G \b bytes::rindex \b (?! (?>\s*) => )                    /oxgc) { $slash = 'm//'; return 'rindex';            }
    elsif (/\G \b Char::rindex \b  (?! (?>\s*) => )                    /oxgc) { $slash = 'm//'; return 'Char::rindex';      }
    elsif (/\G \b KOI8R::rindex \b  (?! (?>\s*) => )                    /oxgc) { $slash = 'm//'; return 'KOI8R::rindex';      }
    elsif (/\G \b rindex \b        (?! (?>\s*) => )                    /oxgc) { $slash = 'm//'; return 'Ekoi8r::rindex';     }
    elsif (/\G \b lc      (?= (?>\s+)[A-Za-z_]|(?>\s*)['"`\$\@\&\*\(]) /oxgc) { $slash = 'm//'; return 'Ekoi8r::lc';         }
    elsif (/\G \b lcfirst (?= (?>\s+)[A-Za-z_]|(?>\s*)['"`\$\@\&\*\(]) /oxgc) { $slash = 'm//'; return 'Ekoi8r::lcfirst';    }
    elsif (/\G \b uc      (?= (?>\s+)[A-Za-z_]|(?>\s*)['"`\$\@\&\*\(]) /oxgc) { $slash = 'm//'; return 'Ekoi8r::uc';         }
    elsif (/\G \b ucfirst (?= (?>\s+)[A-Za-z_]|(?>\s*)['"`\$\@\&\*\(]) /oxgc) { $slash = 'm//'; return 'Ekoi8r::ucfirst';    }
    elsif (/\G \b fc      (?= (?>\s+)[A-Za-z_]|(?>\s*)['"`\$\@\&\*\(]) /oxgc) { $slash = 'm//'; return 'Ekoi8r::fc';         }

    # "-s '' ..." means file test "-s 'filename' ..." (not means "- s/// ...")
    elsif (/\G -s                                          (?>\s*) (\") ((?:$qq_char)+?)               (\") /oxgc) { $slash = 'm//'; return '-s ' . e_qq('',  $1,$3,$2); }
    elsif (/\G -s                               (?>\s+) qq (?>\s*) (\#) ((?:$qq_char)+?)               (\#) /oxgc) { $slash = 'm//'; return '-s ' . e_qq('qq',$1,$3,$2); }
    elsif (/\G -s                               (?>\s+) qq (?>\s*) (\() ((?:$qq_paren)+?)              (\)) /oxgc) { $slash = 'm//'; return '-s ' . e_qq('qq',$1,$3,$2); }
    elsif (/\G -s                               (?>\s+) qq (?>\s*) (\{) ((?:$qq_brace)+?)              (\}) /oxgc) { $slash = 'm//'; return '-s ' . e_qq('qq',$1,$3,$2); }
    elsif (/\G -s                               (?>\s+) qq (?>\s*) (\[) ((?:$qq_bracket)+?)            (\]) /oxgc) { $slash = 'm//'; return '-s ' . e_qq('qq',$1,$3,$2); }
    elsif (/\G -s                               (?>\s+) qq (?>\s*) (\<) ((?:$qq_angle)+?)              (\>) /oxgc) { $slash = 'm//'; return '-s ' . e_qq('qq',$1,$3,$2); }
    elsif (/\G -s                               (?>\s+) qq (?>\s*) (\S) ((?:$qq_char)+?)               (\1) /oxgc) { $slash = 'm//'; return '-s ' . e_qq('qq',$1,$3,$2); }

    elsif (/\G -s                                          (?>\s*) (\') ((?:\\\'|\\\\|$q_char)+?)      (\') /oxgc) { $slash = 'm//'; return '-s ' . e_q ('',  $1,$3,$2); }
    elsif (/\G -s                               (?>\s+) q  (?>\s*) (\#) ((?:\\\#|\\\\|$q_char)+?)      (\#) /oxgc) { $slash = 'm//'; return '-s ' . e_q ('q', $1,$3,$2); }
    elsif (/\G -s                               (?>\s+) q  (?>\s*) (\() ((?:\\\)|\\\\|$q_paren)+?)     (\)) /oxgc) { $slash = 'm//'; return '-s ' . e_q ('q', $1,$3,$2); }
    elsif (/\G -s                               (?>\s+) q  (?>\s*) (\{) ((?:\\\}|\\\\|$q_brace)+?)     (\}) /oxgc) { $slash = 'm//'; return '-s ' . e_q ('q', $1,$3,$2); }
    elsif (/\G -s                               (?>\s+) q  (?>\s*) (\[) ((?:\\\]|\\\\|$q_bracket)+?)   (\]) /oxgc) { $slash = 'm//'; return '-s ' . e_q ('q', $1,$3,$2); }
    elsif (/\G -s                               (?>\s+) q  (?>\s*) (\<) ((?:\\\>|\\\\|$q_angle)+?)     (\>) /oxgc) { $slash = 'm//'; return '-s ' . e_q ('q', $1,$3,$2); }
    elsif (/\G -s                               (?>\s+) q  (?>\s*) (\S) ((?:\\\1|\\\\|$q_char)+?)      (\1) /oxgc) { $slash = 'm//'; return '-s ' . e_q ('q', $1,$3,$2); }

    elsif (/\G -s                               (?>\s*) (\$ (?> \w+ (?: ::\w+)* ) (?: (?: ->)? (?: [\$\@\%\&\*]\* | \$\#\* | \( (?:$qq_paren)*? \) | [\@\%\*]? \{ (?:$qq_brace)+? \} | [\@\%]? \[ (?:$qq_bracket)+? \] ) )*) /oxgc)
                                                                                                                   { $slash = 'm//'; return "-s $1";   }
    elsif (/\G -s                               (?>\s*) \( ((?:$qq_paren)*?) \)                             /oxgc) { $slash = 'm//'; return "-s ($1)"; }
    elsif (/\G -s                               (?= (?>\s+) [a-z]+)                                         /oxgc) { $slash = 'm//'; return '-s';      }
    elsif (/\G -s                               (?>\s+) ((?>\w+))                                           /oxgc) { $slash = 'm//'; return "-s $1";   }

    elsif (/\G \b bytes::length (?= (?>\s+)[A-Za-z_]|(?>\s*)['"`\$\@\&\*\(]) /oxgc) { $slash = 'm//'; return 'length';                   }
    elsif (/\G \b bytes::chr    (?= (?>\s+)[A-Za-z_]|(?>\s*)['"`\$\@\&\*\(]) /oxgc) { $slash = 'm//'; return 'chr';                      }
    elsif (/\G \b chr           (?= (?>\s+)[A-Za-z_]|(?>\s*)['"`\$\@\&\*\(]) /oxgc) { $slash = 'm//'; return 'Ekoi8r::chr';               }
    elsif (/\G \b bytes::ord    (?= (?>\s+)[A-Za-z_]|(?>\s*)['"`\$\@\&\*\(]) /oxgc) { $slash = 'div'; return 'ord';                      }
    elsif (/\G \b ord           (?= (?>\s+)[A-Za-z_]|(?>\s*)['"`\$\@\&\*\(]) /oxgc) { $slash = 'div'; return $function_ord;              }
    elsif (/\G \b glob          (?= (?>\s+)[A-Za-z_]|(?>\s*)['"`\$\@\&\*\(]) /oxgc) { $slash = 'm//'; return 'Ekoi8r::glob';              }
    elsif (/\G \b lc \b            (?! (?>\s*) => )                          /oxgc) { $slash = 'm//'; return 'Ekoi8r::lc_';               }
    elsif (/\G \b lcfirst \b       (?! (?>\s*) => )                          /oxgc) { $slash = 'm//'; return 'Ekoi8r::lcfirst_';          }
    elsif (/\G \b uc \b            (?! (?>\s*) => )                          /oxgc) { $slash = 'm//'; return 'Ekoi8r::uc_';               }
    elsif (/\G \b ucfirst \b       (?! (?>\s*) => )                          /oxgc) { $slash = 'm//'; return 'Ekoi8r::ucfirst_';          }
    elsif (/\G \b fc \b            (?! (?>\s*) => )                          /oxgc) { $slash = 'm//'; return 'Ekoi8r::fc_';               }
    elsif (/\G    -s \b            (?! (?>\s*) => )                          /oxgc) { $slash = 'm//'; return '-s ';                      }

    elsif (/\G \b bytes::length \b (?! (?>\s*) => )                          /oxgc) { $slash = 'm//'; return 'length';                   }
    elsif (/\G \b bytes::chr \b    (?! (?>\s*) => )                          /oxgc) { $slash = 'm//'; return 'chr';                      }
    elsif (/\G \b chr \b           (?! (?>\s*) => )                          /oxgc) { $slash = 'm//'; return 'Ekoi8r::chr_';              }
    elsif (/\G \b bytes::ord \b    (?! (?>\s*) => )                          /oxgc) { $slash = 'div'; return 'ord';                      }
    elsif (/\G \b ord \b           (?! (?>\s*) => )                          /oxgc) { $slash = 'div'; return $function_ord_;             }
    elsif (/\G \b glob \b          (?! (?>\s*) => )                          /oxgc) { $slash = 'm//'; return 'Ekoi8r::glob_';             }
    elsif (/\G \b reverse \b       (?! (?>\s*) => )                          /oxgc) { $slash = 'm//'; return $function_reverse;          }
    elsif (/\G \b getc \b          (?! (?>\s*) => )                          /oxgc) { $slash = 'm//'; return $function_getc;             }
# split
    elsif (/\G \b (split) \b (?! (?>\s*) => ) /oxgc) {
        $slash = 'm//';

        my $e = '';
        while (/\G ( (?>\s+) | \( | \#.* ) /oxgc) {
            $e .= $1;
        }

# end of split
        if    (/\G (?= [,;\)\}\]] )          /oxgc) { return 'Ekoi8r::split' . $e;                 }

# split scalar value
        elsif (/\G ( [\$\@\&\*] $qq_scalar ) /oxgc) { return 'Ekoi8r::split' . $e . e_string($1);  }

# split literal space
        elsif (/\G \b qq           (\#) [ ] (\#) /oxgc) { return 'Ekoi8r::split' . $e . qq  {qq$1 $2}; }
        elsif (/\G \b qq ((?>\s*)) (\() [ ] (\)) /oxgc) { return 'Ekoi8r::split' . $e . qq{$1qq$2 $3}; }
        elsif (/\G \b qq ((?>\s*)) (\{) [ ] (\}) /oxgc) { return 'Ekoi8r::split' . $e . qq{$1qq$2 $3}; }
        elsif (/\G \b qq ((?>\s*)) (\[) [ ] (\]) /oxgc) { return 'Ekoi8r::split' . $e . qq{$1qq$2 $3}; }
        elsif (/\G \b qq ((?>\s*)) (\<) [ ] (\>) /oxgc) { return 'Ekoi8r::split' . $e . qq{$1qq$2 $3}; }
        elsif (/\G \b qq ((?>\s*)) (\S) [ ] (\2) /oxgc) { return 'Ekoi8r::split' . $e . qq{$1qq$2 $3}; }
        elsif (/\G \b q            (\#) [ ] (\#) /oxgc) { return 'Ekoi8r::split' . $e . qq   {q$1 $2}; }
        elsif (/\G \b q  ((?>\s*)) (\() [ ] (\)) /oxgc) { return 'Ekoi8r::split' . $e . qq {$1q$2 $3}; }
        elsif (/\G \b q  ((?>\s*)) (\{) [ ] (\}) /oxgc) { return 'Ekoi8r::split' . $e . qq {$1q$2 $3}; }
        elsif (/\G \b q  ((?>\s*)) (\[) [ ] (\]) /oxgc) { return 'Ekoi8r::split' . $e . qq {$1q$2 $3}; }
        elsif (/\G \b q  ((?>\s*)) (\<) [ ] (\>) /oxgc) { return 'Ekoi8r::split' . $e . qq {$1q$2 $3}; }
        elsif (/\G \b q  ((?>\s*)) (\S) [ ] (\2) /oxgc) { return 'Ekoi8r::split' . $e . qq {$1q$2 $3}; }
        elsif (/\G                    ' [ ] '    /oxgc) { return 'Ekoi8r::split' . $e . qq     {' '};  }
        elsif (/\G                    " [ ] "    /oxgc) { return 'Ekoi8r::split' . $e . qq     {" "};  }

# split qq//
        elsif (/\G \b (qq) \b /oxgc) {
            if (/\G (\#) ((?:$qq_char)*?) (\#) /oxgc)                        { return e_split($e.'qr',$1,$3,$2,'');   } # qq# #  --> qr # #
            else {
                while (not /\G \z/oxgc) {
                    if    (/\G ((?>\s+)|\#.*)                         /oxgc) { $e .= $1; }
                    elsif (/\G (\()          ((?:$qq_paren)*?)   (\)) /oxgc) { return e_split($e.'qr',$1,$3,$2,'');   } # qq ( ) --> qr ( )
                    elsif (/\G (\{)          ((?:$qq_brace)*?)   (\}) /oxgc) { return e_split($e.'qr',$1,$3,$2,'');   } # qq { } --> qr { }
                    elsif (/\G (\[)          ((?:$qq_bracket)*?) (\]) /oxgc) { return e_split($e.'qr',$1,$3,$2,'');   } # qq [ ] --> qr [ ]
                    elsif (/\G (\<)          ((?:$qq_angle)*?)   (\>) /oxgc) { return e_split($e.'qr',$1,$3,$2,'');   } # qq < > --> qr < >
                    elsif (/\G ([*\-:?\\^|]) ((?:$qq_char)*?)    (\1) /oxgc) { return e_split($e.'qr','{','}',$2,''); } # qq | | --> qr { }
                    elsif (/\G (\S)          ((?:$qq_char)*?)    (\1) /oxgc) { return e_split($e.'qr',$1,$3,$2,'');   } # qq * * --> qr * *
                }
                die __FILE__, ": Can't find string terminator anywhere before EOF\n";
            }
        }

# split qr//
        elsif (/\G \b (qr) \b /oxgc) {
            if (/\G (\#) ((?:$qq_char)*?) (\#) ([imosxpadlunbB]*) /oxgc)                        { return e_split  ($e.'qr',$1,$3,$2,$4);   } # qr# #
            else {
                while (not /\G \z/oxgc) {
                    if    (/\G ((?>\s+)|\#.*)                                            /oxgc) { $e .= $1; }
                    elsif (/\G (\()          ((?:$qq_paren)*?)   (\)) ([imosxpadlunbB]*) /oxgc) { return e_split  ($e.'qr',$1, $3, $2,$4); } # qr ( )
                    elsif (/\G (\{)          ((?:$qq_brace)*?)   (\}) ([imosxpadlunbB]*) /oxgc) { return e_split  ($e.'qr',$1, $3, $2,$4); } # qr { }
                    elsif (/\G (\[)          ((?:$qq_bracket)*?) (\]) ([imosxpadlunbB]*) /oxgc) { return e_split  ($e.'qr',$1, $3, $2,$4); } # qr [ ]
                    elsif (/\G (\<)          ((?:$qq_angle)*?)   (\>) ([imosxpadlunbB]*) /oxgc) { return e_split  ($e.'qr',$1, $3, $2,$4); } # qr < >
                    elsif (/\G (\')          ((?:$qq_char)*?)    (\') ([imosxpadlunbB]*) /oxgc) { return e_split_q($e.'qr',$1, $3, $2,$4); } # qr ' '
                    elsif (/\G ([*\-:?\\^|]) ((?:$qq_char)*?)    (\1) ([imosxpadlunbB]*) /oxgc) { return e_split  ($e.'qr','{','}',$2,$4); } # qr | | --> qr { }
                    elsif (/\G (\S)          ((?:$qq_char)*?)    (\1) ([imosxpadlunbB]*) /oxgc) { return e_split  ($e.'qr',$1, $3, $2,$4); } # qr * *
                }
                die __FILE__, ": Can't find string terminator anywhere before EOF\n";
            }
        }

# split q//
        elsif (/\G \b (q) \b /oxgc) {
            if (/\G (\#) ((?:\\\#|\\\\|$q_char)*?) (\#) /oxgc)                    { return e_split_q($e.'qr',$1,$3,$2,'');   } # q# #  --> qr # #
            else {
                while (not /\G \z/oxgc) {
                    if    (/\G ((?>\s+)|\#.*)                              /oxgc) { $e .= $1; }
                    elsif (/\G (\() ((?:\\\\|\\\)|\\\(|$q_paren)*?)   (\)) /oxgc) { return e_split_q($e.'qr',$1,$3,$2,'');   } # q ( ) --> qr ( )
                    elsif (/\G (\{) ((?:\\\\|\\\}|\\\{|$q_brace)*?)   (\}) /oxgc) { return e_split_q($e.'qr',$1,$3,$2,'');   } # q { } --> qr { }
                    elsif (/\G (\[) ((?:\\\\|\\\]|\\\[|$q_bracket)*?) (\]) /oxgc) { return e_split_q($e.'qr',$1,$3,$2,'');   } # q [ ] --> qr [ ]
                    elsif (/\G (\<) ((?:\\\\|\\\>|\\\<|$q_angle)*?)   (\>) /oxgc) { return e_split_q($e.'qr',$1,$3,$2,'');   } # q < > --> qr < >
                    elsif (/\G ([*\-:?\\^|])       ((?:$q_char)*?)    (\1) /oxgc) { return e_split_q($e.'qr','{','}',$2,''); } # q | | --> qr { }
                    elsif (/\G (\S) ((?:\\\\|\\\1|     $q_char)*?)    (\1) /oxgc) { return e_split_q($e.'qr',$1,$3,$2,'');   } # q * * --> qr * *
                }
                die __FILE__, ": Can't find string terminator anywhere before EOF\n";
            }
        }

# split m//
        elsif (/\G \b (m) \b /oxgc) {
            if (/\G (\#) ((?:$qq_char)*?) (\#) ([cgimosxpadlunbB]*) /oxgc)                        { return e_split  ($e.'qr',$1,$3,$2,$4);   } # m# #  --> qr # #
            else {
                while (not /\G \z/oxgc) {
                    if    (/\G ((?>\s+)|\#.*)                                              /oxgc) { $e .= $1; }
                    elsif (/\G (\()          ((?:$qq_paren)*?)   (\)) ([cgimosxpadlunbB]*) /oxgc) { return e_split  ($e.'qr',$1, $3, $2,$4); } # m ( ) --> qr ( )
                    elsif (/\G (\{)          ((?:$qq_brace)*?)   (\}) ([cgimosxpadlunbB]*) /oxgc) { return e_split  ($e.'qr',$1, $3, $2,$4); } # m { } --> qr { }
                    elsif (/\G (\[)          ((?:$qq_bracket)*?) (\]) ([cgimosxpadlunbB]*) /oxgc) { return e_split  ($e.'qr',$1, $3, $2,$4); } # m [ ] --> qr [ ]
                    elsif (/\G (\<)          ((?:$qq_angle)*?)   (\>) ([cgimosxpadlunbB]*) /oxgc) { return e_split  ($e.'qr',$1, $3, $2,$4); } # m < > --> qr < >
                    elsif (/\G (\')          ((?:$qq_char)*?)    (\') ([cgimosxpadlunbB]*) /oxgc) { return e_split_q($e.'qr',$1, $3, $2,$4); } # m ' ' --> qr ' '
                    elsif (/\G ([*\-:?\\^|]) ((?:$qq_char)*?)    (\1) ([cgimosxpadlunbB]*) /oxgc) { return e_split  ($e.'qr','{','}',$2,$4); } # m | | --> qr { }
                    elsif (/\G (\S)          ((?:$qq_char)*?)    (\1) ([cgimosxpadlunbB]*) /oxgc) { return e_split  ($e.'qr',$1, $3, $2,$4); } # m * * --> qr * *
                }
                die __FILE__, ": Search pattern not terminated\n";
            }
        }

# split ''
        elsif (/\G (\') /oxgc) {
            my $q_string = '';
            while (not /\G \z/oxgc) {
                if    (/\G (\\\\)    /oxgc) { $q_string .= $1; }
                elsif (/\G (\\\')    /oxgc) { $q_string .= $1; }                               # splitqr'' --> split qr''
                elsif (/\G \'        /oxgc)                                                    { return e_split_q($e.q{ qr},"'","'",$q_string,''); } # ' ' --> qr ' '
                elsif (/\G ($q_char) /oxgc) { $q_string .= $1; }
            }
            die __FILE__, ": Can't find string terminator anywhere before EOF\n";
        }

# split ""
        elsif (/\G (\") /oxgc) {
            my $qq_string = '';
            while (not /\G \z/oxgc) {
                if    (/\G (\\\\)    /oxgc) { $qq_string .= $1; }
                elsif (/\G (\\\")    /oxgc) { $qq_string .= $1; }                              # splitqr"" --> split qr""
                elsif (/\G \"        /oxgc)                                                    { return e_split($e.q{ qr},'"','"',$qq_string,''); } # " " --> qr " "
                elsif (/\G ($q_char) /oxgc) { $qq_string .= $1; }
            }
            die __FILE__, ": Can't find string terminator anywhere before EOF\n";
        }

# split //
        elsif (/\G (\/) /oxgc) {
            my $regexp = '';
            while (not /\G \z/oxgc) {
                if    (/\G (\\\\)                  /oxgc) { $regexp .= $1; }
                elsif (/\G (\\\/)                  /oxgc) { $regexp .= $1; }                   # splitqr// --> split qr//
                elsif (/\G \/ ([cgimosxpadlunbB]*) /oxgc)                                      { return e_split($e.q{ qr}, '/','/',$regexp,$1); } # / / --> qr / /
                elsif (/\G ($q_char)               /oxgc) { $regexp .= $1; }
            }
            die __FILE__, ": Search pattern not terminated\n";
        }
    }

# tr/// or y///

    # about [cdsrbB]* (/B modifier)
    #
    # P.559 appendix C
    # of ISBN 4-89052-384-7 Programming perl
    # (Japanese title is: Perl puroguramingu)

    elsif (/\G \b ( tr | y ) \b /oxgc) {
        my $ope = $1;

        #        $1   $2               $3   $4               $5   $6
        if (/\G (\#) ((?:$qq_char)*?) (\#) ((?:$qq_char)*?) (\#) ([cdsrbB]*) /oxgc) { # tr# # #
            my @tr = ($tr_variable,$2);
            return e_tr(@tr,'',$4,$6);
        }
        else {
            my $e = '';
            while (not /\G \z/oxgc) {
                if    (/\G ((?>\s+)|\#.*)              /oxgc) { $e .= $1; }
                elsif (/\G (\() ((?:$qq_paren)*?) (\)) /oxgc) {
                    my @tr = ($tr_variable,$2);
                    while (not /\G \z/oxgc) {
                        if    (/\G ((?>\s+)|\#.*)                            /oxgc) { $e .= $1; }
                        elsif (/\G (\() ((?:$qq_paren)*?)   (\)) ([cdsrbB]*) /oxgc) { return e_tr(@tr,$e,$2,$4); } # tr ( ) ( )
                        elsif (/\G (\{) ((?:$qq_brace)*?)   (\}) ([cdsrbB]*) /oxgc) { return e_tr(@tr,$e,$2,$4); } # tr ( ) { }
                        elsif (/\G (\[) ((?:$qq_bracket)*?) (\]) ([cdsrbB]*) /oxgc) { return e_tr(@tr,$e,$2,$4); } # tr ( ) [ ]
                        elsif (/\G (\<) ((?:$qq_angle)*?)   (\>) ([cdsrbB]*) /oxgc) { return e_tr(@tr,$e,$2,$4); } # tr ( ) < >
                        elsif (/\G (\S) ((?:$qq_char)*?)    (\1) ([cdsrbB]*) /oxgc) { return e_tr(@tr,$e,$2,$4); } # tr ( ) * *
                    }
                    die __FILE__, ": Transliteration replacement not terminated\n";
                }
                elsif (/\G (\{) ((?:$qq_brace)*?) (\}) /oxgc) {
                    my @tr = ($tr_variable,$2);
                    while (not /\G \z/oxgc) {
                        if    (/\G ((?>\s+)|\#.*)                            /oxgc) { $e .= $1; }
                        elsif (/\G (\() ((?:$qq_paren)*?)   (\)) ([cdsrbB]*) /oxgc) { return e_tr(@tr,$e,$2,$4); } # tr { } ( )
                        elsif (/\G (\{) ((?:$qq_brace)*?)   (\}) ([cdsrbB]*) /oxgc) { return e_tr(@tr,$e,$2,$4); } # tr { } { }
                        elsif (/\G (\[) ((?:$qq_bracket)*?) (\]) ([cdsrbB]*) /oxgc) { return e_tr(@tr,$e,$2,$4); } # tr { } [ ]
                        elsif (/\G (\<) ((?:$qq_angle)*?)   (\>) ([cdsrbB]*) /oxgc) { return e_tr(@tr,$e,$2,$4); } # tr { } < >
                        elsif (/\G (\S) ((?:$qq_char)*?)    (\1) ([cdsrbB]*) /oxgc) { return e_tr(@tr,$e,$2,$4); } # tr { } * *
                    }
                    die __FILE__, ": Transliteration replacement not terminated\n";
                }
                elsif (/\G (\[) ((?:$qq_bracket)*?) (\]) /oxgc) {
                    my @tr = ($tr_variable,$2);
                    while (not /\G \z/oxgc) {
                        if    (/\G ((?>\s+)|\#.*)                            /oxgc) { $e .= $1; }
                        elsif (/\G (\() ((?:$qq_paren)*?)   (\)) ([cdsrbB]*) /oxgc) { return e_tr(@tr,$e,$2,$4); } # tr [ ] ( )
                        elsif (/\G (\{) ((?:$qq_brace)*?)   (\}) ([cdsrbB]*) /oxgc) { return e_tr(@tr,$e,$2,$4); } # tr [ ] { }
                        elsif (/\G (\[) ((?:$qq_bracket)*?) (\]) ([cdsrbB]*) /oxgc) { return e_tr(@tr,$e,$2,$4); } # tr [ ] [ ]
                        elsif (/\G (\<) ((?:$qq_angle)*?)   (\>) ([cdsrbB]*) /oxgc) { return e_tr(@tr,$e,$2,$4); } # tr [ ] < >
                        elsif (/\G (\S) ((?:$qq_char)*?)    (\1) ([cdsrbB]*) /oxgc) { return e_tr(@tr,$e,$2,$4); } # tr [ ] * *
                    }
                    die __FILE__, ": Transliteration replacement not terminated\n";
                }
                elsif (/\G (\<) ((?:$qq_angle)*?) (\>) /oxgc) {
                    my @tr = ($tr_variable,$2);
                    while (not /\G \z/oxgc) {
                        if    (/\G ((?>\s+)|\#.*)                            /oxgc) { $e .= $1; }
                        elsif (/\G (\() ((?:$qq_paren)*?)   (\)) ([cdsrbB]*) /oxgc) { return e_tr(@tr,$e,$2,$4); } # tr < > ( )
                        elsif (/\G (\{) ((?:$qq_brace)*?)   (\}) ([cdsrbB]*) /oxgc) { return e_tr(@tr,$e,$2,$4); } # tr < > { }
                        elsif (/\G (\[) ((?:$qq_bracket)*?) (\]) ([cdsrbB]*) /oxgc) { return e_tr(@tr,$e,$2,$4); } # tr < > [ ]
                        elsif (/\G (\<) ((?:$qq_angle)*?)   (\>) ([cdsrbB]*) /oxgc) { return e_tr(@tr,$e,$2,$4); } # tr < > < >
                        elsif (/\G (\S) ((?:$qq_char)*?)    (\1) ([cdsrbB]*) /oxgc) { return e_tr(@tr,$e,$2,$4); } # tr < > * *
                    }
                    die __FILE__, ": Transliteration replacement not terminated\n";
                }
                #           $1   $2               $3   $4               $5   $6
                elsif (/\G (\S) ((?:$qq_char)*?) (\1) ((?:$qq_char)*?) (\1) ([cdsrbB]*) /oxgc) { # tr * * *
                    my @tr = ($tr_variable,$2);
                    return e_tr(@tr,'',$4,$6);
                }
            }
            die __FILE__, ": Transliteration pattern not terminated\n";
        }
    }

# qq//
    elsif (/\G \b (qq) \b /oxgc) {
        my $ope = $1;

#       if (/\G (\#) ((?:$qq_char)*?) (\#) /oxgc) { return e_qq($ope,$1,$3,$2); } # qq# #
        if (/\G (\#) /oxgc) {                                                     # qq# #
            my $qq_string = '';
            while (not /\G \z/oxgc) {
                if    (/\G (\\\\)     /oxgc) { $qq_string .= $1;                     }
                elsif (/\G (\\\#)     /oxgc) { $qq_string .= $1;                     }
                elsif (/\G (\#)       /oxgc) { return e_qq($ope,'#','#',$qq_string); }
                elsif (/\G ($qq_char) /oxgc) { $qq_string .= $1;                     }
            }
            die __FILE__, ": Can't find string terminator anywhere before EOF\n";
        }

        else {
            my $e = '';
            while (not /\G \z/oxgc) {
                if    (/\G ((?>\s+)|\#.*)              /oxgc) { $e .= $1; }

#               elsif (/\G (\() ((?:$qq_paren)*?) (\)) /oxgc) { return $e . e_qq($ope,$1,$3,$2); } # qq ( )
                elsif (/\G (\() /oxgc) {                                                           # qq ( )
                    my $qq_string = '';
                    local $nest = 1;
                    while (not /\G \z/oxgc) {
                        if    (/\G (\\\\)     /oxgc) { $qq_string .= $1;                          }
                        elsif (/\G (\\\))     /oxgc) { $qq_string .= $1;                          }
                        elsif (/\G (\()       /oxgc) { $qq_string .= $1; $nest++;                 }
                        elsif (/\G (\))       /oxgc) {
                            if (--$nest == 0)        { return $e . e_qq($ope,'(',')',$qq_string); }
                            else                     { $qq_string .= $1;                          }
                        }
                        elsif (/\G ($qq_char) /oxgc) { $qq_string .= $1;                          }
                    }
                    die __FILE__, ": Can't find string terminator anywhere before EOF\n";
                }

#               elsif (/\G (\{) ((?:$qq_brace)*?) (\}) /oxgc) { return $e . e_qq($ope,$1,$3,$2); } # qq { }
                elsif (/\G (\{) /oxgc) {                                                           # qq { }
                    my $qq_string = '';
                    local $nest = 1;
                    while (not /\G \z/oxgc) {
                        if    (/\G (\\\\)     /oxgc) { $qq_string .= $1;                          }
                        elsif (/\G (\\\})     /oxgc) { $qq_string .= $1;                          }
                        elsif (/\G (\{)       /oxgc) { $qq_string .= $1; $nest++;                 }
                        elsif (/\G (\})       /oxgc) {
                            if (--$nest == 0)        { return $e . e_qq($ope,'{','}',$qq_string); }
                            else                     { $qq_string .= $1;                          }
                        }
                        elsif (/\G ($qq_char) /oxgc) { $qq_string .= $1;                          }
                    }
                    die __FILE__, ": Can't find string terminator anywhere before EOF\n";
                }

#               elsif (/\G (\[) ((?:$qq_bracket)*?) (\]) /oxgc) { return $e . e_qq($ope,$1,$3,$2); } # qq [ ]
                elsif (/\G (\[) /oxgc) {                                                             # qq [ ]
                    my $qq_string = '';
                    local $nest = 1;
                    while (not /\G \z/oxgc) {
                        if    (/\G (\\\\)     /oxgc) { $qq_string .= $1;                          }
                        elsif (/\G (\\\])     /oxgc) { $qq_string .= $1;                          }
                        elsif (/\G (\[)       /oxgc) { $qq_string .= $1; $nest++;                 }
                        elsif (/\G (\])       /oxgc) {
                            if (--$nest == 0)        { return $e . e_qq($ope,'[',']',$qq_string); }
                            else                     { $qq_string .= $1;                          }
                        }
                        elsif (/\G ($qq_char) /oxgc) { $qq_string .= $1;                          }
                    }
                    die __FILE__, ": Can't find string terminator anywhere before EOF\n";
                }

#               elsif (/\G (\<) ((?:$qq_angle)*?) (\>) /oxgc) { return $e . e_qq($ope,$1,$3,$2); } # qq < >
                elsif (/\G (\<) /oxgc) {                                                           # qq < >
                    my $qq_string = '';
                    local $nest = 1;
                    while (not /\G \z/oxgc) {
                        if    (/\G (\\\\)     /oxgc) { $qq_string .= $1;                          }
                        elsif (/\G (\\\>)     /oxgc) { $qq_string .= $1;                          }
                        elsif (/\G (\<)       /oxgc) { $qq_string .= $1; $nest++;                 }
                        elsif (/\G (\>)       /oxgc) {
                            if (--$nest == 0)        { return $e . e_qq($ope,'<','>',$qq_string); }
                            else                     { $qq_string .= $1;                          }
                        }
                        elsif (/\G ($qq_char) /oxgc) { $qq_string .= $1;                          }
                    }
                    die __FILE__, ": Can't find string terminator anywhere before EOF\n";
                }

#               elsif (/\G (\S) ((?:$qq_char)*?) (\1) /oxgc) { return $e . e_qq($ope,$1,$3,$2); } # qq * *
                elsif (/\G (\S) /oxgc) {                                                          # qq * *
                    my $delimiter = $1;
                    my $qq_string = '';
                    while (not /\G \z/oxgc) {
                        if    (/\G (\\\\)             /oxgc) { $qq_string .= $1;                                        }
                        elsif (/\G (\\\Q$delimiter\E) /oxgc) { $qq_string .= $1;                                        }
                        elsif (/\G (\Q$delimiter\E)   /oxgc) { return $e . e_qq($ope,$delimiter,$delimiter,$qq_string); }
                        elsif (/\G ($qq_char)         /oxgc) { $qq_string .= $1;                                        }
                    }
                    die __FILE__, ": Can't find string terminator anywhere before EOF\n";
                }
            }
            die __FILE__, ": Can't find string terminator anywhere before EOF\n";
        }
    }

# qr//
    elsif (/\G \b (qr) \b /oxgc) {
        my $ope = $1;
        if (/\G (\#) ((?:$qq_char)*?) (\#) ([imosxpadlunbB]*) /oxgc) { # qr# # #
            return e_qr($ope,$1,$3,$2,$4);
        }
        else {
            my $e = '';
            while (not /\G \z/oxgc) {
                if    (/\G ((?>\s+)|\#.*)                                            /oxgc) { $e .= $1; }
                elsif (/\G (\()          ((?:$qq_paren)*?)   (\)) ([imosxpadlunbB]*) /oxgc) { return $e . e_qr  ($ope,$1, $3, $2,$4); } # qr ( )
                elsif (/\G (\{)          ((?:$qq_brace)*?)   (\}) ([imosxpadlunbB]*) /oxgc) { return $e . e_qr  ($ope,$1, $3, $2,$4); } # qr { }
                elsif (/\G (\[)          ((?:$qq_bracket)*?) (\]) ([imosxpadlunbB]*) /oxgc) { return $e . e_qr  ($ope,$1, $3, $2,$4); } # qr [ ]
                elsif (/\G (\<)          ((?:$qq_angle)*?)   (\>) ([imosxpadlunbB]*) /oxgc) { return $e . e_qr  ($ope,$1, $3, $2,$4); } # qr < >
                elsif (/\G (\')          ((?:$qq_char)*?)    (\') ([imosxpadlunbB]*) /oxgc) { return $e . e_qr_q($ope,$1, $3, $2,$4); } # qr ' '
                elsif (/\G ([*\-:?\\^|]) ((?:$qq_char)*?)    (\1) ([imosxpadlunbB]*) /oxgc) { return $e . e_qr  ($ope,'{','}',$2,$4); } # qr | | --> qr { }
                elsif (/\G (\S)          ((?:$qq_char)*?)    (\1) ([imosxpadlunbB]*) /oxgc) { return $e . e_qr  ($ope,$1, $3, $2,$4); } # qr * *
            }
            die __FILE__, ": Can't find string terminator anywhere before EOF\n";
        }
    }

# qw//
    elsif (/\G \b (qw) \b /oxgc) {
        my $ope = $1;
        if (/\G (\#) (.*?) (\#) /oxmsgc) { # qw# #
            return e_qw($ope,$1,$3,$2);
        }
        else {
            my $e = '';
            while (not /\G \z/oxgc) {
                if    (/\G ((?>\s+)|\#.*)                        /oxgc)   { $e .= $1; }

                elsif (/\G (\()          ([^(]*?)           (\)) /oxmsgc) { return $e . e_qw($ope,$1,$3,$2); } # qw ( )
                elsif (/\G (\()          ((?:$q_paren)*?)   (\)) /oxmsgc) { return $e . e_qw($ope,$1,$3,$2); } # qw ( )

                elsif (/\G (\{)          ([^{]*?)           (\}) /oxmsgc) { return $e . e_qw($ope,$1,$3,$2); } # qw { }
                elsif (/\G (\{)          ((?:$q_brace)*?)   (\}) /oxmsgc) { return $e . e_qw($ope,$1,$3,$2); } # qw { }

                elsif (/\G (\[)          ([^[]*?)           (\]) /oxmsgc) { return $e . e_qw($ope,$1,$3,$2); } # qw [ ]
                elsif (/\G (\[)          ((?:$q_bracket)*?) (\]) /oxmsgc) { return $e . e_qw($ope,$1,$3,$2); } # qw [ ]

                elsif (/\G (\<)          ([^<]*?)           (\>) /oxmsgc) { return $e . e_qw($ope,$1,$3,$2); } # qw < >
                elsif (/\G (\<)          ((?:$q_angle)*?)   (\>) /oxmsgc) { return $e . e_qw($ope,$1,$3,$2); } # qw < >

                elsif (/\G ([\x21-\x3F]) (.*?)              (\1) /oxmsgc) { return $e . e_qw($ope,$1,$3,$2); } # qw * *
                elsif (/\G (\S)          ((?:$q_char)*?)    (\1) /oxmsgc) { return $e . e_qw($ope,$1,$3,$2); } # qw * *
            }
            die __FILE__, ": Can't find string terminator anywhere before EOF\n";
        }
    }

# qx//
    elsif (/\G \b (qx) \b /oxgc) {
        my $ope = $1;
        if (/\G (\#) ((?:$qq_char)*?) (\#) /oxgc) { # qx# #
            return e_qq($ope,$1,$3,$2);
        }
        else {
            my $e = '';
            while (not /\G \z/oxgc) {
                if    (/\G ((?>\s+)|\#.*)                /oxgc) { $e .= $1; }
                elsif (/\G (\() ((?:$qq_paren)*?)   (\)) /oxgc) { return $e . e_qq($ope,$1,$3,$2); } # qx ( )
                elsif (/\G (\{) ((?:$qq_brace)*?)   (\}) /oxgc) { return $e . e_qq($ope,$1,$3,$2); } # qx { }
                elsif (/\G (\[) ((?:$qq_bracket)*?) (\]) /oxgc) { return $e . e_qq($ope,$1,$3,$2); } # qx [ ]
                elsif (/\G (\<) ((?:$qq_angle)*?)   (\>) /oxgc) { return $e . e_qq($ope,$1,$3,$2); } # qx < >
                elsif (/\G (\') ((?:$qq_char)*?)    (\') /oxgc) { return $e . e_q ($ope,$1,$3,$2); } # qx ' '
                elsif (/\G (\S) ((?:$qq_char)*?)    (\1) /oxgc) { return $e . e_qq($ope,$1,$3,$2); } # qx * *
            }
            die __FILE__, ": Can't find string terminator anywhere before EOF\n";
        }
    }

# q//
    elsif (/\G \b (q) \b /oxgc) {
        my $ope = $1;

#       if (/\G (\#) ((?:\\\#|\\\\|$q_char)*?) (\#) /oxgc) { return e_q($ope,$1,$3,$2); } # q# #

        # avoid "Error: Runtime exception" of perl version 5.005_03
        # (and so on)

        if (/\G (\#) /oxgc) {                                                             # q# #
            my $q_string = '';
            while (not /\G \z/oxgc) {
                if    (/\G (\\\\)    /oxgc) { $q_string .= $1;                    }
                elsif (/\G (\\\#)    /oxgc) { $q_string .= $1;                    }
                elsif (/\G (\#)      /oxgc) { return e_q($ope,'#','#',$q_string); }
                elsif (/\G ($q_char) /oxgc) { $q_string .= $1;                    }
            }
            die __FILE__, ": Can't find string terminator anywhere before EOF\n";
        }

        else {
            my $e = '';
            while (not /\G \z/oxgc) {
                if    (/\G ((?>\s+)|\#.*)                       /oxgc) { $e .= $1; }

#               elsif (/\G (\() ((?:\\\)|\\\\|$q_paren)*?) (\)) /oxgc) { return $e . e_q($ope,$1,$3,$2); } # q ( )
                elsif (/\G (\() /oxgc) {                                                                   # q ( )
                    my $q_string = '';
                    local $nest = 1;
                    while (not /\G \z/oxgc) {
                        if    (/\G (\\\\)    /oxgc) { $q_string .= $1;                         }
                        elsif (/\G (\\\))    /oxgc) { $q_string .= $1;                         }
                        elsif (/\G (\\\()    /oxgc) { $q_string .= $1;                         }
                        elsif (/\G (\()      /oxgc) { $q_string .= $1; $nest++;                }
                        elsif (/\G (\))      /oxgc) {
                            if (--$nest == 0)       { return $e . e_q($ope,'(',')',$q_string); }
                            else                    { $q_string .= $1;                         }
                        }
                        elsif (/\G ($q_char) /oxgc) { $q_string .= $1;                         }
                    }
                    die __FILE__, ": Can't find string terminator anywhere before EOF\n";
                }

#               elsif (/\G (\{) ((?:\\\}|\\\\|$q_brace)*?) (\}) /oxgc) { return $e . e_q($ope,$1,$3,$2); } # q { }
                elsif (/\G (\{) /oxgc) {                                                                   # q { }
                    my $q_string = '';
                    local $nest = 1;
                    while (not /\G \z/oxgc) {
                        if    (/\G (\\\\)    /oxgc) { $q_string .= $1;                         }
                        elsif (/\G (\\\})    /oxgc) { $q_string .= $1;                         }
                        elsif (/\G (\\\{)    /oxgc) { $q_string .= $1;                         }
                        elsif (/\G (\{)      /oxgc) { $q_string .= $1; $nest++;                }
                        elsif (/\G (\})      /oxgc) {
                            if (--$nest == 0)       { return $e . e_q($ope,'{','}',$q_string); }
                            else                    { $q_string .= $1;                         }
                        }
                        elsif (/\G ($q_char) /oxgc) { $q_string .= $1;                         }
                    }
                    die __FILE__, ": Can't find string terminator anywhere before EOF\n";
                }

#               elsif (/\G (\[) ((?:\\\]|\\\\|$q_bracket)*?) (\]) /oxgc) { return $e . e_q($ope,$1,$3,$2); } # q [ ]
                elsif (/\G (\[) /oxgc) {                                                                     # q [ ]
                    my $q_string = '';
                    local $nest = 1;
                    while (not /\G \z/oxgc) {
                        if    (/\G (\\\\)    /oxgc) { $q_string .= $1;                         }
                        elsif (/\G (\\\])    /oxgc) { $q_string .= $1;                         }
                        elsif (/\G (\\\[)    /oxgc) { $q_string .= $1;                         }
                        elsif (/\G (\[)      /oxgc) { $q_string .= $1; $nest++;                }
                        elsif (/\G (\])      /oxgc) {
                            if (--$nest == 0)       { return $e . e_q($ope,'[',']',$q_string); }
                            else                    { $q_string .= $1;                         }
                        }
                        elsif (/\G ($q_char) /oxgc) { $q_string .= $1;                         }
                    }
                    die __FILE__, ": Can't find string terminator anywhere before EOF\n";
                }

#               elsif (/\G (\<) ((?:\\\>|\\\\|$q_angle)*?) (\>) /oxgc) { return $e . e_q($ope,$1,$3,$2); } # q < >
                elsif (/\G (\<) /oxgc) {                                                                   # q < >
                    my $q_string = '';
                    local $nest = 1;
                    while (not /\G \z/oxgc) {
                        if    (/\G (\\\\)    /oxgc) { $q_string .= $1;                         }
                        elsif (/\G (\\\>)    /oxgc) { $q_string .= $1;                         }
                        elsif (/\G (\\\<)    /oxgc) { $q_string .= $1;                         }
                        elsif (/\G (\<)      /oxgc) { $q_string .= $1; $nest++;                }
                        elsif (/\G (\>)      /oxgc) {
                            if (--$nest == 0)       { return $e . e_q($ope,'<','>',$q_string); }
                            else                    { $q_string .= $1;                         }
                        }
                        elsif (/\G ($q_char) /oxgc) { $q_string .= $1;                         }
                    }
                    die __FILE__, ": Can't find string terminator anywhere before EOF\n";
                }

#               elsif (/\G (\S) ((?:\\\1|\\\\|$q_char)*?) (\1) /oxgc) { return $e . e_q($ope,$1,$3,$2); } # q * *
                elsif (/\G (\S) /oxgc) {                                                                  # q * *
                    my $delimiter = $1;
                    my $q_string = '';
                    while (not /\G \z/oxgc) {
                        if    (/\G (\\\\)             /oxgc) { $q_string .= $1;                                       }
                        elsif (/\G (\\\Q$delimiter\E) /oxgc) { $q_string .= $1;                                       }
                        elsif (/\G (\Q$delimiter\E)   /oxgc) { return $e . e_q($ope,$delimiter,$delimiter,$q_string); }
                        elsif (/\G ($q_char)          /oxgc) { $q_string .= $1;                                       }
                    }
                    die __FILE__, ": Can't find string terminator anywhere before EOF\n";
                }
            }
            die __FILE__, ": Can't find string terminator anywhere before EOF\n";
        }
    }

# m//
    elsif (/\G \b (m) \b /oxgc) {
        my $ope = $1;
        if (/\G (\#) ((?:$qq_char)*?) (\#) ([cgimosxpadlunbB]*) /oxgc) { # m# #
            return e_qr($ope,$1,$3,$2,$4);
        }
        else {
            my $e = '';
            while (not /\G \z/oxgc) {
                if    (/\G ((?>\s+)|\#.*)                                             /oxgc) { $e .= $1; }
                elsif (/\G (\()         ((?:$qq_paren)*?)   (\)) ([cgimosxpadlunbB]*) /oxgc) { return $e . e_qr  ($ope,$1, $3, $2,$4); } # m ( )
                elsif (/\G (\{)         ((?:$qq_brace)*?)   (\}) ([cgimosxpadlunbB]*) /oxgc) { return $e . e_qr  ($ope,$1, $3, $2,$4); } # m { }
                elsif (/\G (\[)         ((?:$qq_bracket)*?) (\]) ([cgimosxpadlunbB]*) /oxgc) { return $e . e_qr  ($ope,$1, $3, $2,$4); } # m [ ]
                elsif (/\G (\<)         ((?:$qq_angle)*?)   (\>) ([cgimosxpadlunbB]*) /oxgc) { return $e . e_qr  ($ope,$1, $3, $2,$4); } # m < >
                elsif (/\G (\?)         ((?:$qq_char)*?)    (\?) ([cgimosxpadlunbB]*) /oxgc) { return $e . e_qr  ($ope,$1, $3, $2,$4); } # m ? ?
                elsif (/\G (\')         ((?:$qq_char)*?)    (\') ([cgimosxpadlunbB]*) /oxgc) { return $e . e_qr_q($ope,$1, $3, $2,$4); } # m ' '
                elsif (/\G ([*\-:\\^|]) ((?:$qq_char)*?)    (\1) ([cgimosxpadlunbB]*) /oxgc) { return $e . e_qr  ($ope,'{','}',$2,$4); } # m | | --> m { }
                elsif (/\G (\S)         ((?:$qq_char)*?)    (\1) ([cgimosxpadlunbB]*) /oxgc) { return $e . e_qr  ($ope,$1, $3, $2,$4); } # m * *
            }
            die __FILE__, ": Search pattern not terminated\n";
        }
    }

# s///

    # about [cegimosxpradlunbB]* (/cg modifier)
    #
    # P.67 Pattern-Matching Operators
    # of ISBN 0-596-00241-6 Perl in a Nutshell, Second Edition.

    elsif (/\G \b (s) \b /oxgc) {
        my $ope = $1;

        #        $1   $2               $3   $4               $5   $6
        if (/\G (\#) ((?:$qq_char)*?) (\#) ((?:$qq_char)*?) (\#) ([cegimosxpradlunbB]*) /oxgc) { # s# # #
            return e_sub($sub_variable,$1,$2,$3,$3,$4,$5,$6);
        }
        else {
            my $e = '';
            while (not /\G \z/oxgc) {
                if (/\G ((?>\s+)|\#.*) /oxgc) { $e .= $1; }
                elsif (/\G (\() ((?:$qq_paren)*?) (\)) /oxgc) {
                    my @s = ($1,$2,$3);
                    while (not /\G \z/oxgc) {
                        if    (/\G ((?>\s+)|\#.*)                                       /oxgc) { $e .= $1; }
                        #           $1   $2                  $3   $4
                        elsif (/\G (\() ((?:$qq_paren)*?)   (\)) ([cegimosxpradlunbB]*) /oxgc) { return e_sub($sub_variable,@s,$1,$2,$3,$4); }
                        elsif (/\G (\{) ((?:$qq_brace)*?)   (\}) ([cegimosxpradlunbB]*) /oxgc) { return e_sub($sub_variable,@s,$1,$2,$3,$4); }
                        elsif (/\G (\[) ((?:$qq_bracket)*?) (\]) ([cegimosxpradlunbB]*) /oxgc) { return e_sub($sub_variable,@s,$1,$2,$3,$4); }
                        elsif (/\G (\<) ((?:$qq_angle)*?)   (\>) ([cegimosxpradlunbB]*) /oxgc) { return e_sub($sub_variable,@s,$1,$2,$3,$4); }
                        elsif (/\G (\') ((?:$qq_char)*?)    (\') ([cegimosxpradlunbB]*) /oxgc) { return e_sub($sub_variable,@s,$1,$2,$3,$4); }
                        elsif (/\G (\$) ((?:$qq_char)*?)    (\$) ([cegimosxpradlunbB]*) /oxgc) { return e_sub($sub_variable,@s,$1,$2,$3,$4); }
                        elsif (/\G (\:) ((?:$qq_char)*?)    (\:) ([cegimosxpradlunbB]*) /oxgc) { return e_sub($sub_variable,@s,$1,$2,$3,$4); }
                        elsif (/\G (\@) ((?:$qq_char)*?)    (\@) ([cegimosxpradlunbB]*) /oxgc) { return e_sub($sub_variable,@s,$1,$2,$3,$4); }
                        elsif (/\G (\S) ((?:$qq_char)*?)    (\1) ([cegimosxpradlunbB]*) /oxgc) { return e_sub($sub_variable,@s,$1,$2,$3,$4); }
                    }
                    die __FILE__, ": Substitution replacement not terminated\n";
                }
                elsif (/\G (\{) ((?:$qq_brace)*?) (\}) /oxgc) {
                    my @s = ($1,$2,$3);
                    while (not /\G \z/oxgc) {
                        if    (/\G ((?>\s+)|\#.*)                                       /oxgc) { $e .= $1; }
                        #           $1   $2                  $3   $4
                        elsif (/\G (\() ((?:$qq_paren)*?)   (\)) ([cegimosxpradlunbB]*) /oxgc) { return e_sub($sub_variable,@s,$1,$2,$3,$4); }
                        elsif (/\G (\{) ((?:$qq_brace)*?)   (\}) ([cegimosxpradlunbB]*) /oxgc) { return e_sub($sub_variable,@s,$1,$2,$3,$4); }
                        elsif (/\G (\[) ((?:$qq_bracket)*?) (\]) ([cegimosxpradlunbB]*) /oxgc) { return e_sub($sub_variable,@s,$1,$2,$3,$4); }
                        elsif (/\G (\<) ((?:$qq_angle)*?)   (\>) ([cegimosxpradlunbB]*) /oxgc) { return e_sub($sub_variable,@s,$1,$2,$3,$4); }
                        elsif (/\G (\') ((?:$qq_char)*?)    (\') ([cegimosxpradlunbB]*) /oxgc) { return e_sub($sub_variable,@s,$1,$2,$3,$4); }
                        elsif (/\G (\$) ((?:$qq_char)*?)    (\$) ([cegimosxpradlunbB]*) /oxgc) { return e_sub($sub_variable,@s,$1,$2,$3,$4); }
                        elsif (/\G (\:) ((?:$qq_char)*?)    (\:) ([cegimosxpradlunbB]*) /oxgc) { return e_sub($sub_variable,@s,$1,$2,$3,$4); }
                        elsif (/\G (\@) ((?:$qq_char)*?)    (\@) ([cegimosxpradlunbB]*) /oxgc) { return e_sub($sub_variable,@s,$1,$2,$3,$4); }
                        elsif (/\G (\S) ((?:$qq_char)*?)    (\1) ([cegimosxpradlunbB]*) /oxgc) { return e_sub($sub_variable,@s,$1,$2,$3,$4); }
                    }
                    die __FILE__, ": Substitution replacement not terminated\n";
                }
                elsif (/\G (\[) ((?:$qq_bracket)*?) (\]) /oxgc) {
                    my @s = ($1,$2,$3);
                    while (not /\G \z/oxgc) {
                        if    (/\G ((?>\s+)|\#.*)                                       /oxgc) { $e .= $1; }
                        #           $1   $2                  $3   $4
                        elsif (/\G (\() ((?:$qq_paren)*?)   (\)) ([cegimosxpradlunbB]*) /oxgc) { return e_sub($sub_variable,@s,$1,$2,$3,$4); }
                        elsif (/\G (\{) ((?:$qq_brace)*?)   (\}) ([cegimosxpradlunbB]*) /oxgc) { return e_sub($sub_variable,@s,$1,$2,$3,$4); }
                        elsif (/\G (\[) ((?:$qq_bracket)*?) (\]) ([cegimosxpradlunbB]*) /oxgc) { return e_sub($sub_variable,@s,$1,$2,$3,$4); }
                        elsif (/\G (\<) ((?:$qq_angle)*?)   (\>) ([cegimosxpradlunbB]*) /oxgc) { return e_sub($sub_variable,@s,$1,$2,$3,$4); }
                        elsif (/\G (\') ((?:$qq_char)*?)    (\') ([cegimosxpradlunbB]*) /oxgc) { return e_sub($sub_variable,@s,$1,$2,$3,$4); }
                        elsif (/\G (\$) ((?:$qq_char)*?)    (\$) ([cegimosxpradlunbB]*) /oxgc) { return e_sub($sub_variable,@s,$1,$2,$3,$4); }
                        elsif (/\G (\S) ((?:$qq_char)*?)    (\1) ([cegimosxpradlunbB]*) /oxgc) { return e_sub($sub_variable,@s,$1,$2,$3,$4); }
                    }
                    die __FILE__, ": Substitution replacement not terminated\n";
                }
                elsif (/\G (\<) ((?:$qq_angle)*?) (\>) /oxgc) {
                    my @s = ($1,$2,$3);
                    while (not /\G \z/oxgc) {
                        if    (/\G ((?>\s+)|\#.*)                                       /oxgc) { $e .= $1; }
                        #           $1   $2                  $3   $4
                        elsif (/\G (\() ((?:$qq_paren)*?)   (\)) ([cegimosxpradlunbB]*) /oxgc) { return e_sub($sub_variable,@s,$1,$2,$3,$4); }
                        elsif (/\G (\{) ((?:$qq_brace)*?)   (\}) ([cegimosxpradlunbB]*) /oxgc) { return e_sub($sub_variable,@s,$1,$2,$3,$4); }
                        elsif (/\G (\[) ((?:$qq_bracket)*?) (\]) ([cegimosxpradlunbB]*) /oxgc) { return e_sub($sub_variable,@s,$1,$2,$3,$4); }
                        elsif (/\G (\<) ((?:$qq_angle)*?)   (\>) ([cegimosxpradlunbB]*) /oxgc) { return e_sub($sub_variable,@s,$1,$2,$3,$4); }
                        elsif (/\G (\') ((?:$qq_char)*?)    (\') ([cegimosxpradlunbB]*) /oxgc) { return e_sub($sub_variable,@s,$1,$2,$3,$4); }
                        elsif (/\G (\$) ((?:$qq_char)*?)    (\$) ([cegimosxpradlunbB]*) /oxgc) { return e_sub($sub_variable,@s,$1,$2,$3,$4); }
                        elsif (/\G (\:) ((?:$qq_char)*?)    (\:) ([cegimosxpradlunbB]*) /oxgc) { return e_sub($sub_variable,@s,$1,$2,$3,$4); }
                        elsif (/\G (\@) ((?:$qq_char)*?)    (\@) ([cegimosxpradlunbB]*) /oxgc) { return e_sub($sub_variable,@s,$1,$2,$3,$4); }
                        elsif (/\G (\S) ((?:$qq_char)*?)    (\1) ([cegimosxpradlunbB]*) /oxgc) { return e_sub($sub_variable,@s,$1,$2,$3,$4); }
                    }
                    die __FILE__, ": Substitution replacement not terminated\n";
                }
                #           $1   $2               $3   $4               $5   $6
                elsif (/\G (\') ((?:$qq_char)*?) (\') ((?:$qq_char)*?) (\') ([cegimosxpradlunbB]*) /oxgc) {
                    return e_sub($sub_variable,$1,$2,$3,$3,$4,$5,$6);
                }
                #           $1            $2               $3   $4               $5   $6
                elsif (/\G ([*\-:?\\^|]) ((?:$qq_char)*?) (\1) ((?:$qq_char)*?) (\1) ([cegimosxpradlunbB]*) /oxgc) {
                    return e_sub($sub_variable,'{',$2,'}','{',$4,'}',$6); # s | | | --> s { } { }
                }
                #           $1   $2               $3   $4               $5   $6
                elsif (/\G (\$) ((?:$qq_char)*?) (\1) ((?:$qq_char)*?) (\1) ([cegimosxpradlunbB]*) /oxgc) {
                    return e_sub($sub_variable,$1,$2,$3,$3,$4,$5,$6);
                }
                #           $1   $2               $3   $4               $5   $6
                elsif (/\G (\S) ((?:$qq_char)*?) (\1) ((?:$qq_char)*?) (\1) ([cegimosxpradlunbB]*) /oxgc) {
                    return e_sub($sub_variable,$1,$2,$3,$3,$4,$5,$6);
                }
            }
            die __FILE__, ": Substitution pattern not terminated\n";
        }
    }

# require ignore module
    elsif (/\G \b require ((?>\s+) (?:$ignore_modules) .*? ;) ([ \t]* [#\n])                  /oxmsgc) { return "# require$1$2";     }
    elsif (/\G \b require ((?>\s+) (?:$ignore_modules) .*? ;) ([ \t]* [^#]) /oxmsgc) { return "# require$1\n$2";   }
    elsif (/\G \b require ((?>\s+) (?:$ignore_modules)) \b                                    /oxmsgc) { return "# require$1";       }

# use strict; --> use strict; no strict qw(refs);
    elsif (/\G \b use ((?>\s+) strict .*? ;) ([ \t]* [#\n])                                   /oxmsgc) { return "use$1 no strict qw(refs);$2";   }
    elsif (/\G \b use ((?>\s+) strict .*? ;) ([ \t]* [^#])                  /oxmsgc) { return "use$1 no strict qw(refs);\n$2"; }
    elsif (/\G \b use ((?>\s+) strict) \b                                                     /oxmsgc) { return "use$1; no strict qw(refs)";     }

# use 5.12.0; --> use 5.12.0; no strict qw(refs);
    elsif (/\G \b use (?>\s+) ((?>([1-9][0-9_]*)(?:\.([0-9_]+))*))  (?>\s*) ; /oxmsgc) {
        if (($2 >= 6) or (($2 == 5) and ($3 ge '012'))) {
            return "use $1; no strict qw(refs);";
        }
        else {
            return "use $1;";
        }
    }
    elsif (/\G \b use (?>\s+) ((?>v([0-9][0-9_]*)(?:\.([0-9_]+))*)) (?>\s*) ; /oxmsgc) {
        if (($2 >= 6) or (($2 == 5) and ($3 >= 12))) {
            return "use $1; no strict qw(refs);";
        }
        else {
            return "use $1;";
        }
    }

# ignore use module
    elsif (/\G \b use ((?>\s+) (?:$ignore_modules) .*? ;) ([ \t]* [#\n])                  /oxmsgc) { return "# use$1$2";         }
    elsif (/\G \b use ((?>\s+) (?:$ignore_modules) .*? ;) ([ \t]* [^#]) /oxmsgc) { return "# use$1\n$2";       }
    elsif (/\G \b use ((?>\s+) (?:$ignore_modules)) \b                                    /oxmsgc) { return "# use$1";           }

# ignore no module
    elsif (/\G \b no  ((?>\s+) (?:$ignore_modules) .*? ;) ([ \t]* [#\n])                  /oxmsgc) { return "# no$1$2";          }
    elsif (/\G \b no  ((?>\s+) (?:$ignore_modules) .*? ;) ([ \t]* [^#]) /oxmsgc) { return "# no$1\n$2";        }
    elsif (/\G \b no  ((?>\s+) (?:$ignore_modules)) \b                                    /oxmsgc) { return "# no$1";            }

# use else
    elsif (/\G \b use \b /oxmsgc) { return "use"; }

# use else
    elsif (/\G \b no  \b /oxmsgc) { return "no";  }

# ''
    elsif (/\G (?<![\w\$\@\%\&\*]) (\') /oxgc) {
        my $q_string = '';
        while (not /\G \z/oxgc) {
            if    (/\G (\\\\)                  /oxgc) { $q_string .= $1;                   }
            elsif (/\G (\\\')                  /oxgc) { $q_string .= $1;                   }
            elsif (/\G \'                      /oxgc) { return e_q('', "'","'",$q_string); }
            elsif (/\G ($q_char)               /oxgc) { $q_string .= $1;                   }
        }
        die __FILE__, ": Can't find string terminator anywhere before EOF\n";
    }

# ""
    elsif (/\G (\") /oxgc) {
        my $qq_string = '';
        while (not /\G \z/oxgc) {
            if    (/\G (\\\\)                  /oxgc) { $qq_string .= $1;                    }
            elsif (/\G (\\\")                  /oxgc) { $qq_string .= $1;                    }
            elsif (/\G \"                      /oxgc) { return e_qq('', '"','"',$qq_string); }
            elsif (/\G ($q_char)               /oxgc) { $qq_string .= $1;                    }
        }
        die __FILE__, ": Can't find string terminator anywhere before EOF\n";
    }

# ``
    elsif (/\G (\`) /oxgc) {
        my $qx_string = '';
        while (not /\G \z/oxgc) {
            if    (/\G (\\\\)                  /oxgc) { $qx_string .= $1;                    }
            elsif (/\G (\\\`)                  /oxgc) { $qx_string .= $1;                    }
            elsif (/\G \`                      /oxgc) { return e_qq('', '`','`',$qx_string); }
            elsif (/\G ($q_char)               /oxgc) { $qx_string .= $1;                    }
        }
        die __FILE__, ": Can't find string terminator anywhere before EOF\n";
    }

# //   --- not divide operator (num / num), not defined-or
    elsif (($slash eq 'm//') and /\G (\/) /oxgc) {
        my $regexp = '';
        while (not /\G \z/oxgc) {
            if    (/\G (\\\\)                  /oxgc) { $regexp .= $1;                       }
            elsif (/\G (\\\/)                  /oxgc) { $regexp .= $1;                       }
            elsif (/\G \/ ([cgimosxpadlunbB]*) /oxgc) { return e_qr('', '/','/',$regexp,$1); }
            elsif (/\G ($q_char)               /oxgc) { $regexp .= $1;                       }
        }
        die __FILE__, ": Search pattern not terminated\n";
    }

# ??   --- not conditional operator (condition ? then : else)
    elsif (($slash eq 'm//') and /\G (\?) /oxgc) {
        my $regexp = '';
        while (not /\G \z/oxgc) {
            if    (/\G (\\\\)                  /oxgc) { $regexp .= $1;                       }
            elsif (/\G (\\\?)                  /oxgc) { $regexp .= $1;                       }
            elsif (/\G \? ([cgimosxpadlunbB]*) /oxgc) { return e_qr('m','?','?',$regexp,$1); }
            elsif (/\G ($q_char)               /oxgc) { $regexp .= $1;                       }
        }
        die __FILE__, ": Search pattern not terminated\n";
    }

# <<>> (a safer ARGV)
    elsif (/\G ( <<>> ) /oxgc)                         { $slash = 'm//'; return $1;          }

# << (bit shift)   --- not here document
    elsif (/\G ( << (?>\s*) ) (?= [0-9\$\@\&] ) /oxgc) { $slash = 'm//'; return $1;          }

# <<~'HEREDOC'
    elsif (/\G ( <<~ [\t ]* '([a-zA-Z_0-9]*)' ) /oxgc) {
        $slash = 'm//';
        my $here_quote = $1;
        my $delimiter  = $2;

        # get here document
        if ($here_script eq '') {
            $here_script = CORE::substr $_, pos $_;
            $here_script =~ s/.*?\n//oxm;
        }
        if ($here_script =~ s/\A (.*?) \n ([\t ]*) $delimiter \n //xms) {
            my $heredoc = $1;
            my $indent  = $2;
            $heredoc =~ s{^$indent}{}msg; # no /ox
            push @heredoc, $heredoc . qq{\n$delimiter\n};
            push @heredoc_delimiter, qq{\\s*$delimiter};
        }
        else {
            die __FILE__, ": Can't find string terminator $delimiter anywhere before EOF\n";
        }
        return qq{<<'$delimiter'};
    }

# <<~\HEREDOC

    # P.66 2.6.6. "Here" Documents
    # in Chapter 2: Bits and Pieces
    # of ISBN 0-596-00027-8 Programming Perl Third Edition.

    # P.73 "Here" Documents
    # in Chapter 2: Bits and Pieces
    # of ISBN 978-0-596-00492-7 Programming Perl 4th Edition.

    elsif (/\G ( <<~ \\([a-zA-Z_0-9]+) ) /oxgc) {
        $slash = 'm//';
        my $here_quote = $1;
        my $delimiter  = $2;

        # get here document
        if ($here_script eq '') {
            $here_script = CORE::substr $_, pos $_;
            $here_script =~ s/.*?\n//oxm;
        }
        if ($here_script =~ s/\A (.*?) \n ([\t ]*) $delimiter \n //xms) {
            my $heredoc = $1;
            my $indent  = $2;
            $heredoc =~ s{^$indent}{}msg; # no /ox
            push @heredoc, $heredoc . qq{\n$delimiter\n};
            push @heredoc_delimiter, qq{\\s*$delimiter};
        }
        else {
            die __FILE__, ": Can't find string terminator $delimiter anywhere before EOF\n";
        }
        return qq{<<\\$delimiter};
    }

# <<~"HEREDOC"
    elsif (/\G ( <<~ [\t ]* "([a-zA-Z_0-9]*)" ) /oxgc) {
        $slash = 'm//';
        my $here_quote = $1;
        my $delimiter  = $2;

        # get here document
        if ($here_script eq '') {
            $here_script = CORE::substr $_, pos $_;
            $here_script =~ s/.*?\n//oxm;
        }
        if ($here_script =~ s/\A (.*?) \n ([\t ]*) $delimiter \n //xms) {
            my $heredoc = $1;
            my $indent  = $2;
            $heredoc =~ s{^$indent}{}msg; # no /ox
            push @heredoc, e_heredoc($heredoc) . qq{\n$delimiter\n};
            push @heredoc_delimiter, qq{\\s*$delimiter};
        }
        else {
            die __FILE__, ": Can't find string terminator $delimiter anywhere before EOF\n";
        }
        return qq{<<"$delimiter"};
    }

# <<~HEREDOC
    elsif (/\G ( <<~ ([a-zA-Z_0-9]+) ) /oxgc) {
        $slash = 'm//';
        my $here_quote = $1;
        my $delimiter  = $2;

        # get here document
        if ($here_script eq '') {
            $here_script = CORE::substr $_, pos $_;
            $here_script =~ s/.*?\n//oxm;
        }
        if ($here_script =~ s/\A (.*?) \n ([\t ]*) $delimiter \n //xms) {
            my $heredoc = $1;
            my $indent  = $2;
            $heredoc =~ s{^$indent}{}msg; # no /ox
            push @heredoc, e_heredoc($heredoc) . qq{\n$delimiter\n};
            push @heredoc_delimiter, qq{\\s*$delimiter};
        }
        else {
            die __FILE__, ": Can't find string terminator $delimiter anywhere before EOF\n";
        }
        return qq{<<$delimiter};
    }

# <<~`HEREDOC`
    elsif (/\G ( <<~ [\t ]* `([a-zA-Z_0-9]*)` ) /oxgc) {
        $slash = 'm//';
        my $here_quote = $1;
        my $delimiter  = $2;

        # get here document
        if ($here_script eq '') {
            $here_script = CORE::substr $_, pos $_;
            $here_script =~ s/.*?\n//oxm;
        }
        if ($here_script =~ s/\A (.*?) \n ([\t ]*) $delimiter \n //xms) {
            my $heredoc = $1;
            my $indent  = $2;
            $heredoc =~ s{^$indent}{}msg; # no /ox
            push @heredoc, e_heredoc($heredoc) . qq{\n$delimiter\n};
            push @heredoc_delimiter, qq{\\s*$delimiter};
        }
        else {
            die __FILE__, ": Can't find string terminator $delimiter anywhere before EOF\n";
        }
        return qq{<<`$delimiter`};
    }

# <<'HEREDOC'
    elsif (/\G ( << '([a-zA-Z_0-9]*)' ) /oxgc) {
        $slash = 'm//';
        my $here_quote = $1;
        my $delimiter  = $2;

        # get here document
        if ($here_script eq '') {
            $here_script = CORE::substr $_, pos $_;
            $here_script =~ s/.*?\n//oxm;
        }
        if ($here_script =~ s/\A (.*?) \n $delimiter \n //xms) {
            push @heredoc, $1 . qq{\n$delimiter\n};
            push @heredoc_delimiter, $delimiter;
        }
        else {
            die __FILE__, ": Can't find string terminator $delimiter anywhere before EOF\n";
        }
        return $here_quote;
    }

# <<\HEREDOC

    # P.66 2.6.6. "Here" Documents
    # in Chapter 2: Bits and Pieces
    # of ISBN 0-596-00027-8 Programming Perl Third Edition.

    # P.73 "Here" Documents
    # in Chapter 2: Bits and Pieces
    # of ISBN 978-0-596-00492-7 Programming Perl 4th Edition.

    elsif (/\G ( << \\([a-zA-Z_0-9]+) ) /oxgc) {
        $slash = 'm//';
        my $here_quote = $1;
        my $delimiter  = $2;

        # get here document
        if ($here_script eq '') {
            $here_script = CORE::substr $_, pos $_;
            $here_script =~ s/.*?\n//oxm;
        }
        if ($here_script =~ s/\A (.*?) \n $delimiter \n //xms) {
            push @heredoc, $1 . qq{\n$delimiter\n};
            push @heredoc_delimiter, $delimiter;
        }
        else {
            die __FILE__, ": Can't find string terminator $delimiter anywhere before EOF\n";
        }
        return $here_quote;
    }

# <<"HEREDOC"
    elsif (/\G ( << "([a-zA-Z_0-9]*)" ) /oxgc) {
        $slash = 'm//';
        my $here_quote = $1;
        my $delimiter  = $2;

        # get here document
        if ($here_script eq '') {
            $here_script = CORE::substr $_, pos $_;
            $here_script =~ s/.*?\n//oxm;
        }
        if ($here_script =~ s/\A (.*?) \n $delimiter \n //xms) {
            push @heredoc, e_heredoc($1) . qq{\n$delimiter\n};
            push @heredoc_delimiter, $delimiter;
        }
        else {
            die __FILE__, ": Can't find string terminator $delimiter anywhere before EOF\n";
        }
        return $here_quote;
    }

# <<HEREDOC
    elsif (/\G ( << ([a-zA-Z_0-9]+) ) /oxgc) {
        $slash = 'm//';
        my $here_quote = $1;
        my $delimiter  = $2;

        # get here document
        if ($here_script eq '') {
            $here_script = CORE::substr $_, pos $_;
            $here_script =~ s/.*?\n//oxm;
        }
        if ($here_script =~ s/\A (.*?) \n $delimiter \n //xms) {
            push @heredoc, e_heredoc($1) . qq{\n$delimiter\n};
            push @heredoc_delimiter, $delimiter;
        }
        else {
            die __FILE__, ": Can't find string terminator $delimiter anywhere before EOF\n";
        }
        return $here_quote;
    }

# <<`HEREDOC`
    elsif (/\G ( << `([a-zA-Z_0-9]*)` ) /oxgc) {
        $slash = 'm//';
        my $here_quote = $1;
        my $delimiter  = $2;

        # get here document
        if ($here_script eq '') {
            $here_script = CORE::substr $_, pos $_;
            $here_script =~ s/.*?\n//oxm;
        }
        if ($here_script =~ s/\A (.*?) \n $delimiter \n //xms) {
            push @heredoc, e_heredoc($1) . qq{\n$delimiter\n};
            push @heredoc_delimiter, $delimiter;
        }
        else {
            die __FILE__, ": Can't find string terminator $delimiter anywhere before EOF\n";
        }
        return $here_quote;
    }

# <<= <=> <= < operator
    elsif (/\G ( <<= | <=> | <= | < ) (?= (?>\s*) [A-Za-z_0-9'"`\$\@\&\*\(\+\-] )/oxgc) {
        return $1;
    }

# <FILEHANDLE>
    elsif (/\G (<[\$]?[A-Za-z_][A-Za-z_0-9]*>) /oxgc) {
        return $1;
    }

# <WILDCARD> --- glob

    # avoid "Error: Runtime exception" of perl version 5.005_03

    elsif (/\G < ((?:[^>\0\a\e\f\n\r\t])+?) > /oxgc) {
        return 'Ekoi8r::glob("' . $1 . '")';
    }

# __DATA__
    elsif (/\G ^ ( __DATA__ \n .*) \z /oxmsgc) { return $1; }

# __END__
    elsif (/\G ^ ( __END__  \n .*) \z /oxmsgc) { return $1; }

# \cD Control-D

    # P.68 2.6.8. Other Literal Tokens
    # in Chapter 2: Bits and Pieces
    # of ISBN 0-596-00027-8 Programming Perl Third Edition.

    # P.76 Other Literal Tokens
    # in Chapter 2: Bits and Pieces
    # of ISBN 978-0-596-00492-7 Programming Perl 4th Edition.

    elsif (/\G   ( \cD         .*) \z /oxmsgc) { return $1; }

# \cZ Control-Z
    elsif (/\G   ( \cZ         .*) \z /oxmsgc) { return $1; }

    # any operator before div
    elsif (/\G (
            -- | \+\+ |
            [\)\}\]]

            ) /oxgc) { $slash = 'div'; return $1; }

    # yada-yada or triple-dot operator
    elsif (/\G (
            \.\.\.

            ) /oxgc) { $slash = 'm//'; return q{die('Unimplemented')}; }

    # any operator before m//

    # //, //= (defined-or)

    # P.164 Logical Operators
    # in Chapter 10: More Control Structures
    # of ISBN 978-0-596-52010-6 Learning Perl, Fifth Edition

    # P.119 C-Style Logical (Short-Circuit) Operators
    # in Chapter 3: Unary and Binary Operators
    # of ISBN 978-0-596-00492-7 Programming Perl 4th Edition.

    # (and so on)

    # ~~

    # P.221 The Smart Match Operator
    # in Chapter 15: Smart Matching and given-when
    # of ISBN 978-0-596-52010-6 Learning Perl, Fifth Edition

    # P.112 Smartmatch Operator
    # in Chapter 3: Unary and Binary Operators
    # of ISBN 978-0-596-00492-7 Programming Perl 4th Edition.

    # (and so on)

    elsif (/\G ((?>

            !~~ | !~ | != | ! |
            %= | % |
            &&= | && | &= | &\.= | &\. | & |
            -= | -> | - |
            :(?>\s*)= |
            : |
            <<>> |
            <<= | <=> | <= | < |
            == | => | =~ | = |
            >>= | >> | >= | > |
            \*\*= | \*\* | \*= | \* |
            \+= | \+ |
            \.\. | \.= | \. |
            \/\/= | \/\/ |
            \/= | \/ |
            \? |
            \\ |
            \^= | \^\.= | \^\. | \^ |
            \b x= |
            \|\|= | \|\| | \|= | \|\.= | \|\. | \| |
            ~~ | ~\. | ~ |
            \b(?: and | cmp | eq | ge | gt | le | lt | ne | not | or | xor | x )\b |
            \b(?: print )\b |

            [,;\(\{\[]

            )) /oxgc) { $slash = 'm//'; return $1; }

    # other any character
    elsif (/\G ($q_char) /oxgc) { $slash = 'div'; return $1; }

    # system error
    else {
        die __FILE__, ": Oops, this shouldn't happen!\n";
    }
}

# escape KOI8-R string
sub e_string {
    my($string) = @_;
    my $e_string = '';

    local $slash = 'm//';

    # P.1024 Appendix W.10 Multibyte Processing
    # of ISBN 1-56592-224-7 CJKV Information Processing
    # (and so on)

    my @char = $string =~ / \G (?>[^\\]|\\$q_char|$q_char) /oxmsg;

    # without { ... }
    if (not (grep(/\A \{ \z/xms, @char) and grep(/\A \} \z/xms, @char))) {
        if ($string !~ /<</oxms) {
            return $string;
        }
    }

E_STRING_LOOP:
    while ($string !~ /\G \z/oxgc) {
        if (0) {
        }

# $`, ${`}, $PREMATCH, ${PREMATCH}, ${^PREMATCH} --> @{[Ekoi8r::PREMATCH()]}
        elsif ($string =~ /\G ( \$` | \$\{`\} | \$ (?>\s*) PREMATCH  \b | \$ (?>\s*) \{ (?>\s*) PREMATCH  (?>\s*) \} | \$ (?>\s*) \{\^PREMATCH\}  ) /oxmsgc) {
            $e_string .= q{Ekoi8r::PREMATCH()};
            $slash = 'div';
        }

# $&, ${&}, $MATCH, ${MATCH}, ${^MATCH} --> @{[Ekoi8r::MATCH()]}
        elsif ($string =~ /\G ( \$& | \$\{&\} | \$ (?>\s*) MATCH     \b | \$ (?>\s*) \{ (?>\s*) MATCH     (?>\s*) \} | \$ (?>\s*) \{\^MATCH\}     ) /oxmsgc) {
            $e_string .= q{Ekoi8r::MATCH()};
            $slash = 'div';
        }

# $', ${'} --> $', ${'}
        elsif ($string =~ /\G ( \$' | \$\{'\}                                                                                                     ) /oxmsgc) {
            $e_string .= $1;
            $slash = 'div';
        }

# $POSTMATCH, ${POSTMATCH}, ${^POSTMATCH} --> @{[Ekoi8r::POSTMATCH()]}
        elsif ($string =~ /\G (                 \$ (?>\s*) POSTMATCH \b | \$ (?>\s*) \{ (?>\s*) POSTMATCH (?>\s*) \} | \$ (?>\s*) \{\^POSTMATCH\} ) /oxmsgc) {
            $e_string .= q{Ekoi8r::POSTMATCH()};
            $slash = 'div';
        }

# bareword
        elsif ($string =~ /\G ( \{ (?>\s*) (?: tr | index | rindex | reverse ) (?>\s*) \} ) /oxmsgc) {
            $e_string .= $1;
            $slash = 'div';
        }

# $0 --> $0
        elsif ($string =~ /\G ( \$ 0 ) /oxmsgc) {
            $e_string .= $1;
            $slash = 'div';
        }
        elsif ($string =~ /\G ( \$ \{ (?>\s*) 0 (?>\s*) \} ) /oxmsgc) {
            $e_string .= $1;
            $slash = 'div';
        }

# $$ --> $$
        elsif ($string =~ /\G ( \$ \$ ) (?![\w\{]) /oxmsgc) {
            $e_string .= $1;
            $slash = 'div';
        }

# $1, $2, $3 --> $2, $3, $4 after s/// with multibyte anchoring
# $1, $2, $3 --> $1, $2, $3 otherwise
        elsif ($string =~ /\G \$ ((?>[1-9][0-9]*)) /oxmsgc) {
            $e_string .= e_capture($1);
            $slash = 'div';
        }
        elsif ($string =~ /\G \$ \{ (?>\s*) ((?>[1-9][0-9]*)) (?>\s*) \} /oxmsgc) {
            $e_string .= e_capture($1);
            $slash = 'div';
        }

# $$foo[ ... ] --> $ $foo->[ ... ]
        elsif ($string =~ /\G \$ ((?> \$ [A-Za-z_][A-Za-z0-9_]*(?: ::[A-Za-z_][A-Za-z0-9_]*)* )) ( \[ .+? \] ) /oxmsgc) {
            $e_string .= e_capture($1.'->'.$2);
            $slash = 'div';
        }

# $$foo{ ... } --> $ $foo->{ ... }
        elsif ($string =~ /\G \$ ((?> \$ [A-Za-z_][A-Za-z0-9_]*(?: ::[A-Za-z_][A-Za-z0-9_]*)* )) ( \{ .+? \} ) /oxmsgc) {
            $e_string .= e_capture($1.'->'.$2);
            $slash = 'div';
        }

# $$foo
        elsif ($string =~ /\G \$ ((?> \$ [A-Za-z_][A-Za-z0-9_]*(?: ::[A-Za-z_][A-Za-z0-9_]*)* )) /oxmsgc) {
            $e_string .= e_capture($1);
            $slash = 'div';
        }

# ${ foo }
        elsif ($string =~ /\G \$ (?>\s*) \{ ((?> \s* [A-Za-z_][A-Za-z0-9_]*(?: ::[A-Za-z_][A-Za-z0-9_]*)* \s* )) \} /oxmsgc) {
            $e_string .= '${' . $1 . '}';
            $slash = 'div';
        }

# ${ ... }
        elsif ($string =~ /\G \$ (?>\s*) \{ (?>\s*) ( $qq_brace ) (?>\s*) \} /oxmsgc) {
            $e_string .= e_capture($1);
            $slash = 'div';
        }

# variable or function
        #                             $ @ % & *     $ #
        elsif ($string =~ /\G ( (?: [\$\@\%\&\*] | \$\# | -> | \b sub \b) (?>\s*) (?: split | chop | index | rindex | lc | uc | fc | chr | ord | reverse | getc | tr | y | q | qq | qx | qw | m | s | qr | glob | lstat | opendir | stat | unlink | chdir ) ) \b /oxmsgc) {
            $e_string .= $1;
            $slash = 'div';
        }
        #                           $ $ $ $ $ $ $ $ $ $ $ $ $ $
        #                           $ @ # \ ' " / ? ( ) [ ] < >
        elsif ($string =~ /\G ( \$[\$\@\#\\\'\"\/\?\(\)\[\]\<\>] ) /oxmsgc) {
            $e_string .= $1;
            $slash = 'div';
        }

# qq//
        elsif ($string =~ /\G \b (qq) \b /oxgc) {
            my $ope = $1;
            if ($string =~ /\G (\#) ((?:$qq_char)*?) (\#) /oxgc) { # qq# #
                $e_string .= e_qq($ope,$1,$3,$2);
            }
            else {
                my $e = '';
                while ($string !~ /\G \z/oxgc) {
                    if    ($string =~ /\G ((?>\s+)|\#.*)                /oxgc) { $e .= $1; }
                    elsif ($string =~ /\G (\() ((?:$qq_paren)*?)   (\)) /oxgc) { $e_string .= $e . e_qq($ope,$1,$3,$2); next E_STRING_LOOP; } # qq ( )
                    elsif ($string =~ /\G (\{) ((?:$qq_brace)*?)   (\}) /oxgc) { $e_string .= $e . e_qq($ope,$1,$3,$2); next E_STRING_LOOP; } # qq { }
                    elsif ($string =~ /\G (\[) ((?:$qq_bracket)*?) (\]) /oxgc) { $e_string .= $e . e_qq($ope,$1,$3,$2); next E_STRING_LOOP; } # qq [ ]
                    elsif ($string =~ /\G (\<) ((?:$qq_angle)*?)   (\>) /oxgc) { $e_string .= $e . e_qq($ope,$1,$3,$2); next E_STRING_LOOP; } # qq < >
                    elsif ($string =~ /\G (\S) ((?:$qq_char)*?)    (\1) /oxgc) { $e_string .= $e . e_qq($ope,$1,$3,$2); next E_STRING_LOOP; } # qq * *
                }
                die __FILE__, ": Can't find string terminator anywhere before EOF\n";
            }
        }

# qx//
        elsif ($string =~ /\G \b (qx) \b /oxgc) {
            my $ope = $1;
            if ($string =~ /\G (\#) ((?:$qq_char)*?) (\#) /oxgc) { # qx# #
                $e_string .= e_qq($ope,$1,$3,$2);
            }
            else {
                my $e = '';
                while ($string !~ /\G \z/oxgc) {
                    if    ($string =~ /\G ((?>\s+)|\#.*)                /oxgc) { $e .= $1; }
                    elsif ($string =~ /\G (\() ((?:$qq_paren)*?)   (\)) /oxgc) { $e_string .= $e . e_qq($ope,$1,$3,$2); next E_STRING_LOOP; } # qx ( )
                    elsif ($string =~ /\G (\{) ((?:$qq_brace)*?)   (\}) /oxgc) { $e_string .= $e . e_qq($ope,$1,$3,$2); next E_STRING_LOOP; } # qx { }
                    elsif ($string =~ /\G (\[) ((?:$qq_bracket)*?) (\]) /oxgc) { $e_string .= $e . e_qq($ope,$1,$3,$2); next E_STRING_LOOP; } # qx [ ]
                    elsif ($string =~ /\G (\<) ((?:$qq_angle)*?)   (\>) /oxgc) { $e_string .= $e . e_qq($ope,$1,$3,$2); next E_STRING_LOOP; } # qx < >
                    elsif ($string =~ /\G (\') ((?:$qq_char)*?)    (\') /oxgc) { $e_string .= $e . e_q ($ope,$1,$3,$2); next E_STRING_LOOP; } # qx ' '
                    elsif ($string =~ /\G (\S) ((?:$qq_char)*?)    (\1) /oxgc) { $e_string .= $e . e_qq($ope,$1,$3,$2); next E_STRING_LOOP; } # qx * *
                }
                die __FILE__, ": Can't find string terminator anywhere before EOF\n";
            }
        }

# q//
        elsif ($string =~ /\G \b (q) \b /oxgc) {
            my $ope = $1;
            if ($string =~ /\G (\#) ((?:\\\#|\\\\|$q_char)*?) (\#) /oxgc) { # q# #
                $e_string .= e_q($ope,$1,$3,$2);
            }
            else {
                my $e = '';
                while ($string !~ /\G \z/oxgc) {
                    if    ($string =~ /\G ((?>\s+)|\#.*)                              /oxgc) { $e .= $1; }
                    elsif ($string =~ /\G (\() ((?:\\\\|\\\)|\\\(|$q_paren)*?)   (\)) /oxgc) { $e_string .= $e . e_q($ope,$1,$3,$2); next E_STRING_LOOP; } # q ( )
                    elsif ($string =~ /\G (\{) ((?:\\\\|\\\}|\\\{|$q_brace)*?)   (\}) /oxgc) { $e_string .= $e . e_q($ope,$1,$3,$2); next E_STRING_LOOP; } # q { }
                    elsif ($string =~ /\G (\[) ((?:\\\\|\\\]|\\\[|$q_bracket)*?) (\]) /oxgc) { $e_string .= $e . e_q($ope,$1,$3,$2); next E_STRING_LOOP; } # q [ ]
                    elsif ($string =~ /\G (\<) ((?:\\\\|\\\>|\\\<|$q_angle)*?)   (\>) /oxgc) { $e_string .= $e . e_q($ope,$1,$3,$2); next E_STRING_LOOP; } # q < >
                    elsif ($string =~ /\G (\S) ((?:\\\\|\\\1|     $q_char)*?)    (\1) /oxgc) { $e_string .= $e . e_q($ope,$1,$3,$2); next E_STRING_LOOP; } # q * *
                }
                die __FILE__, ": Can't find string terminator anywhere before EOF\n";
            }
        }

# ''
        elsif ($string =~ /\G (?<![\w\$\@\%\&\*]) (\') ((?:\\\'|\\\\|$q_char)*?) (\')           /oxgc) { $e_string .= e_q('',$1,$3,$2);  }

# ""
        elsif ($string =~ /\G (\") ((?:$qq_char)*?) (\")                                        /oxgc) { $e_string .= e_qq('',$1,$3,$2); }

# ``
        elsif ($string =~ /\G (\`) ((?:$qq_char)*?) (\`)                                        /oxgc) { $e_string .= e_qq('',$1,$3,$2); }

        # other any character
        elsif ($string =~ /\G ($q_char) /oxgc) { $e_string .= $1; }

        # system error
        else {
            die __FILE__, ": Oops, this shouldn't happen!\n";
        }
    }

    return $e_string;
}

#
# character class
#
sub character_class {
    my($char,$modifier) = @_;

    if ($char eq '.') {
        if ($modifier =~ /s/) {
            return '${Ekoi8r::dot_s}';
        }
        else {
            return '${Ekoi8r::dot}';
        }
    }
    else {
        return Ekoi8r::classic_character_class($char);
    }
}

#
# escape capture ($1, $2, $3, ...)
#
sub e_capture {

    return join '', '${',                $_[0],  '}';
}

#
# escape transliteration (tr/// or y///)
#
sub e_tr {
    my($variable,$charclass,$e,$charclass2,$modifier) = @_;
    my $e_tr = '';
    $modifier ||= '';

    $slash = 'div';

    # quote character class 1
    $charclass  = q_tr($charclass);

    # quote character class 2
    $charclass2 = q_tr($charclass2);

    # /b /B modifier
    if ($modifier =~ tr/bB//d) {
        if ($variable eq '') {
            $e_tr = qq{tr$charclass$e$charclass2$modifier};
        }
        else {
            $e_tr = qq{$variable${bind_operator}tr$charclass$e$charclass2$modifier};
        }
    }
    else {
        if ($variable eq '') {
            $e_tr = qq{Ekoi8r::tr(\$_,' =~ ',$charclass,$e$charclass2,'$modifier')};
        }
        else {
            $e_tr = qq{Ekoi8r::tr($variable,'$bind_operator',$charclass,$e$charclass2,'$modifier')};
        }
    }

    # clear tr/// variable
    $tr_variable = '';
    $bind_operator = '';

    return $e_tr;
}

#
# quote for escape transliteration (tr/// or y///)
#
sub q_tr {
    my($charclass) = @_;

    # quote character class
    if ($charclass !~ /'/oxms) {
        return e_q('',  "'", "'", $charclass); # --> q' '
    }
    elsif ($charclass !~ /\//oxms) {
        return e_q('q',  '/', '/', $charclass); # --> q/ /
    }
    elsif ($charclass !~ /\#/oxms) {
        return e_q('q',  '#', '#', $charclass); # --> q# #
    }
    elsif ($charclass !~ /[\<\>]/oxms) {
        return e_q('q', '<', '>', $charclass); # --> q< >
    }
    elsif ($charclass !~ /[\(\)]/oxms) {
        return e_q('q', '(', ')', $charclass); # --> q( )
    }
    elsif ($charclass !~ /[\{\}]/oxms) {
        return e_q('q', '{', '}', $charclass); # --> q{ }
    }
    else {
        for my $char (qw( ! " $ % & * + . : = ? @ ^ ` | ~ ), "\x00".."\x1F", "\x7F", "\xFF") {
            if ($charclass !~ /\Q$char\E/xms) {
                return e_q('q', $char, $char, $charclass);
            }
        }
    }

    return e_q('q', '{', '}', $charclass);
}

#
# escape q string (q//, '')
#
sub e_q {
    my($ope,$delimiter,$end_delimiter,$string) = @_;

    $slash = 'div';

    return join '', $ope, $delimiter, $string, $end_delimiter;
}

#
# escape qq string (qq//, "", qx//, ``)
#
sub e_qq {
    my($ope,$delimiter,$end_delimiter,$string) = @_;

    $slash = 'div';

    my $left_e  = 0;
    my $right_e = 0;

    # split regexp
    my @char = $string =~ /\G((?>
        [^\\\$] |
        \\x\{ (?>[0-9A-Fa-f]+) \}            |
        \\o\{ (?>[0-7]+)       \}            |
        \\N\{ (?>[^0-9\}][^\}]*) \} |
        \\ $q_char                           |
        \$` | \$\{`\} | \$ (?>\s*) PREMATCH  | \$ (?>\s*) \{ (?>\s*) PREMATCH  (?>\s*) \} | \$ (?>\s*) \{\^PREMATCH\}  |
        \$& | \$\{&\} | \$ (?>\s*) MATCH     | \$ (?>\s*) \{ (?>\s*) MATCH     (?>\s*) \} | \$ (?>\s*) \{\^MATCH\}     |
                        \$ (?>\s*) POSTMATCH | \$ (?>\s*) \{ (?>\s*) POSTMATCH (?>\s*) \} | \$ (?>\s*) \{\^POSTMATCH\} |
        \$ (?>\s* [0-9]+)                    |
        \$ (?>\s*) \{ (?>\s* [0-9]+ \s*) \}  |
        \$ \$ (?![\w\{])                     |
        \$ (?>\s*) \$ (?>\s*) $qq_variable   |
           $q_char
    ))/oxmsg;

    for (my $i=0; $i <= $#char; $i++) {

        # "\L\u" --> "\u\L"
        if (($char[$i] eq '\L') and ($char[$i+1] eq '\u')) {
            @char[$i,$i+1] = @char[$i+1,$i];
        }

        # "\U\l" --> "\l\U"
        elsif (($char[$i] eq '\U') and ($char[$i+1] eq '\l')) {
            @char[$i,$i+1] = @char[$i+1,$i];
        }

        # octal escape sequence
        elsif ($char[$i] =~ /\A \\o \{ ([0-7]+) \} \z/oxms) {
            $char[$i] = Ekoi8r::octchr($1);
        }

        # hexadecimal escape sequence
        elsif ($char[$i] =~ /\A \\x \{ ([0-9A-Fa-f]+) \} \z/oxms) {
            $char[$i] = Ekoi8r::hexchr($1);
        }

        # \N{CHARNAME} --> N{CHARNAME}
        elsif ($char[$i] =~ /\A \\ ( N\{ ([^0-9\}][^\}]*) \} ) \z/oxms) {
            $char[$i] = $1;
        }

        if (0) {
        }

        # \F
        #
        # P.69 Table 2-6. Translation escapes
        # in Chapter 2: Bits and Pieces
        # of ISBN 978-0-596-00492-7 Programming Perl 4th Edition.
        # (and so on)

        # \u \l \U \L \F \Q \E
        elsif ($char[$i] =~ /\A ([<>]) \z/oxms) {
            if ($right_e < $left_e) {
                $char[$i] = '\\' . $char[$i];
            }
        }
        elsif ($char[$i] eq '\u') {

            # "STRING @{[ LIST EXPR ]} MORE STRING"

            # P.257 Other Tricks You Can Do with Hard References
            # in Chapter 8: References
            # of ISBN 0-596-00027-8 Programming Perl Third Edition.

            # P.353 Other Tricks You Can Do with Hard References
            # in Chapter 8: References
            # of ISBN 978-0-596-00492-7 Programming Perl 4th Edition.

            # (and so on)

            $char[$i] = '@{[Ekoi8r::ucfirst qq<';
            $left_e++;
        }
        elsif ($char[$i] eq '\l') {
            $char[$i] = '@{[Ekoi8r::lcfirst qq<';
            $left_e++;
        }
        elsif ($char[$i] eq '\U') {
            $char[$i] = '@{[Ekoi8r::uc qq<';
            $left_e++;
        }
        elsif ($char[$i] eq '\L') {
            $char[$i] = '@{[Ekoi8r::lc qq<';
            $left_e++;
        }
        elsif ($char[$i] eq '\F') {
            $char[$i] = '@{[Ekoi8r::fc qq<';
            $left_e++;
        }
        elsif ($char[$i] eq '\Q') {
            $char[$i] = '@{[CORE::quotemeta qq<';
            $left_e++;
        }
        elsif ($char[$i] eq '\E') {
            if ($right_e < $left_e) {
                $char[$i] = '>]}';
                $right_e++;
            }
            else {
                $char[$i] = '';
            }
        }
        elsif ($char[$i] eq '\Q') {
            while (1) {
                if (++$i > $#char) {
                    last;
                }
                if ($char[$i] eq '\E') {
                    last;
                }
            }
        }
        elsif ($char[$i] eq '\E') {
        }

        # $0 --> $0
        elsif ($char[$i] =~ /\A \$ 0 \z/oxms) {
        }
        elsif ($char[$i] =~ /\A \$ \{ (?>\s*) 0 (?>\s*) \} \z/oxms) {
        }

        # $$ --> $$
        elsif ($char[$i] =~ /\A \$\$ \z/oxms) {
        }

        # $1, $2, $3 --> $2, $3, $4 after s/// with multibyte anchoring
        # $1, $2, $3 --> $1, $2, $3 otherwise
        elsif ($char[$i] =~ /\A \$ ((?>[1-9][0-9]*)) \z/oxms) {
            $char[$i] = e_capture($1);
        }
        elsif ($char[$i] =~ /\A \$ \{ (?>\s*) ((?>[1-9][0-9]*)) (?>\s*) \} \z/oxms) {
            $char[$i] = e_capture($1);
        }

        # $$foo[ ... ] --> $ $foo->[ ... ]
        elsif ($char[$i] =~ /\A \$ ((?> \$ [A-Za-z_][A-Za-z0-9_]*(?: ::[A-Za-z_][A-Za-z0-9_]*)* )) ( \[ (?:$qq_bracket)*? \] ) \z/oxms) {
            $char[$i] = e_capture($1.'->'.$2);
        }

        # $$foo{ ... } --> $ $foo->{ ... }
        elsif ($char[$i] =~ /\A \$ ((?> \$ [A-Za-z_][A-Za-z0-9_]*(?: ::[A-Za-z_][A-Za-z0-9_]*)* )) ( \{ (?:$qq_brace)*? \} ) \z/oxms) {
            $char[$i] = e_capture($1.'->'.$2);
        }

        # $$foo
        elsif ($char[$i] =~ /\A \$ ((?> \$ [A-Za-z_][A-Za-z0-9_]*(?: ::[A-Za-z_][A-Za-z0-9_]*)* )) \z/oxms) {
            $char[$i] = e_capture($1);
        }

        # $`, ${`}, $PREMATCH, ${PREMATCH}, ${^PREMATCH} --> Ekoi8r::PREMATCH()
        elsif ($char[$i] =~ /\A ( \$` | \$\{`\} | \$ (?>\s*) PREMATCH  | \$ (?>\s*) \{ (?>\s*) PREMATCH (?>\s*) \}  | \$ (?>\s*) \{\^PREMATCH\}  ) \z/oxmsgc) {
            $char[$i] = '@{[Ekoi8r::PREMATCH()]}';
        }

        # $&, ${&}, $MATCH, ${MATCH}, ${^MATCH} --> Ekoi8r::MATCH()
        elsif ($char[$i] =~ /\A ( \$& | \$\{&\} | \$ (?>\s*) MATCH     | \$ (?>\s*) \{ (?>\s*) MATCH     (?>\s*) \} | \$ (?>\s*) \{\^MATCH\}     ) \z/oxmsgc) {
            $char[$i] = '@{[Ekoi8r::MATCH()]}';
        }

        # $POSTMATCH, ${POSTMATCH}, ${^POSTMATCH} --> Ekoi8r::POSTMATCH()
        elsif ($char[$i] =~ /\A (                 \$ (?>\s*) POSTMATCH | \$ (?>\s*) \{ (?>\s*) POSTMATCH (?>\s*) \} | \$ (?>\s*) \{\^POSTMATCH\} ) \z/oxmsgc) {
            $char[$i] = '@{[Ekoi8r::POSTMATCH()]}';
        }

        # ${ foo } --> ${ foo }
        elsif ($char[$i] =~ /\A \$ (?>\s*) \{ (?> \s* [A-Za-z_][A-Za-z0-9_]*(?: ::[A-Za-z_][A-Za-z0-9_]*)* \s* ) \}                                \z/oxms) {
        }

        # ${ ... }
        elsif ($char[$i] =~ /\A \$ (?>\s*) \{ ( .+ ) \} \z/oxms) {
            $char[$i] = e_capture($1);
        }
    }

    # return string
    if ($left_e > $right_e) {
        return join '', $ope, $delimiter, @char, '>]}' x ($left_e - $right_e), $end_delimiter;
    }
    return     join '', $ope, $delimiter, @char,                               $end_delimiter;
}

#
# escape qw string (qw//)
#
sub e_qw {
    my($ope,$delimiter,$end_delimiter,$string) = @_;

    $slash = 'div';

    # choice again delimiter
    my %octet = map {$_ => 1} ($string =~ /\G ([\x00-\xFF]) /oxmsg);
    if (not $octet{$end_delimiter}) {
        return join '', $ope, $delimiter, $string, $end_delimiter;
    }
    elsif (not $octet{')'}) {
        return join '', $ope, '(',        $string, ')';
    }
    elsif (not $octet{'}'}) {
        return join '', $ope, '{',        $string, '}';
    }
    elsif (not $octet{']'}) {
        return join '', $ope, '[',        $string, ']';
    }
    elsif (not $octet{'>'}) {
        return join '', $ope, '<',        $string, '>';
    }
    else {
        for my $char (qw( ! " $ % & * + - . / : = ? @ ^ ` | ~ ), "\x00".."\x1F", "\x7F", "\xFF") {
            if (not $octet{$char}) {
                return join '', $ope,      $char, $string, $char;
            }
        }
    }

    # qw/AAA BBB C'CC/ --> ('AAA', 'BBB', 'C\'CC')
    my @string = CORE::split(/\s+/, $string);
    for my $string (@string) {
        my @octet = $string =~ /\G ([\x00-\xFF]) /oxmsg;
        for my $octet (@octet) {
            if ($octet =~ /\A (['\\]) \z/oxms) {
                $octet = '\\' . $1;
            }
        }
        $string = join '', @octet;
    }
    return join '', '(', (join ', ', map { "'$_'" } @string), ')';
}

#
# escape here document (<<"HEREDOC", <<HEREDOC, <<`HEREDOC`, <<~"HEREDOC", <<~HEREDOC, <<~`HEREDOC`)
#
sub e_heredoc {
    my($string) = @_;

    $slash = 'm//';

    my $metachar = qr/[\@\\|]/oxms; # '|' is for <<`HEREDOC`

    my $left_e  = 0;
    my $right_e = 0;

    # split regexp
    my @char = $string =~ /\G((?>
        [^\\\$] |
        \\x\{ (?>[0-9A-Fa-f]+) \}            |
        \\o\{ (?>[0-7]+)       \}            |
        \\N\{ (?>[^0-9\}][^\}]*) \} |
        \\ $q_char                           |
        \$` | \$\{`\} | \$ (?>\s*) PREMATCH  | \$ (?>\s*) \{ (?>\s*) PREMATCH  (?>\s*) \} | \$ (?>\s*) \{\^PREMATCH\}  |
        \$& | \$\{&\} | \$ (?>\s*) MATCH     | \$ (?>\s*) \{ (?>\s*) MATCH     (?>\s*) \} | \$ (?>\s*) \{\^MATCH\}     |
                        \$ (?>\s*) POSTMATCH | \$ (?>\s*) \{ (?>\s*) POSTMATCH (?>\s*) \} | \$ (?>\s*) \{\^POSTMATCH\} |
        \$ (?>\s* [0-9]+)                    |
        \$ (?>\s*) \{ (?>\s* [0-9]+ \s*) \}  |
        \$ \$ (?![\w\{])                     |
        \$ (?>\s*) \$ (?>\s*) $qq_variable   |
           $q_char
    ))/oxmsg;

    for (my $i=0; $i <= $#char; $i++) {

        # "\L\u" --> "\u\L"
        if (($char[$i] eq '\L') and ($char[$i+1] eq '\u')) {
            @char[$i,$i+1] = @char[$i+1,$i];
        }

        # "\U\l" --> "\l\U"
        elsif (($char[$i] eq '\U') and ($char[$i+1] eq '\l')) {
            @char[$i,$i+1] = @char[$i+1,$i];
        }

        # octal escape sequence
        elsif ($char[$i] =~ /\A \\o \{ ([0-7]+) \} \z/oxms) {
            $char[$i] = Ekoi8r::octchr($1);
        }

        # hexadecimal escape sequence
        elsif ($char[$i] =~ /\A \\x \{ ([0-9A-Fa-f]+) \} \z/oxms) {
            $char[$i] = Ekoi8r::hexchr($1);
        }

        # \N{CHARNAME} --> N{CHARNAME}
        elsif ($char[$i] =~ /\A \\ ( N\{ ([^0-9\}][^\}]*) \} ) \z/oxms) {
            $char[$i] = $1;
        }

        if (0) {
        }

        # \u \l \U \L \F \Q \E
        elsif ($char[$i] =~ /\A ([<>]) \z/oxms) {
            if ($right_e < $left_e) {
                $char[$i] = '\\' . $char[$i];
            }
        }
        elsif ($char[$i] eq '\u') {
            $char[$i] = '@{[Ekoi8r::ucfirst qq<';
            $left_e++;
        }
        elsif ($char[$i] eq '\l') {
            $char[$i] = '@{[Ekoi8r::lcfirst qq<';
            $left_e++;
        }
        elsif ($char[$i] eq '\U') {
            $char[$i] = '@{[Ekoi8r::uc qq<';
            $left_e++;
        }
        elsif ($char[$i] eq '\L') {
            $char[$i] = '@{[Ekoi8r::lc qq<';
            $left_e++;
        }
        elsif ($char[$i] eq '\F') {
            $char[$i] = '@{[Ekoi8r::fc qq<';
            $left_e++;
        }
        elsif ($char[$i] eq '\Q') {
            $char[$i] = '@{[CORE::quotemeta qq<';
            $left_e++;
        }
        elsif ($char[$i] eq '\E') {
            if ($right_e < $left_e) {
                $char[$i] = '>]}';
                $right_e++;
            }
            else {
                $char[$i] = '';
            }
        }
        elsif ($char[$i] eq '\Q') {
            while (1) {
                if (++$i > $#char) {
                    last;
                }
                if ($char[$i] eq '\E') {
                    last;
                }
            }
        }
        elsif ($char[$i] eq '\E') {
        }

        # $0 --> $0
        elsif ($char[$i] =~ /\A \$ 0 \z/oxms) {
        }
        elsif ($char[$i] =~ /\A \$ \{ (?>\s*) 0 (?>\s*) \} \z/oxms) {
        }

        # $$ --> $$
        elsif ($char[$i] =~ /\A \$\$ \z/oxms) {
        }

        # $1, $2, $3 --> $2, $3, $4 after s/// with multibyte anchoring
        # $1, $2, $3 --> $1, $2, $3 otherwise
        elsif ($char[$i] =~ /\A \$ ((?>[1-9][0-9]*)) \z/oxms) {
            $char[$i] = e_capture($1);
        }
        elsif ($char[$i] =~ /\A \$ \{ (?>\s*) ((?>[1-9][0-9]*)) (?>\s*) \} \z/oxms) {
            $char[$i] = e_capture($1);
        }

        # $$foo[ ... ] --> $ $foo->[ ... ]
        elsif ($char[$i] =~ /\A \$ ((?> \$ [A-Za-z_][A-Za-z0-9_]*(?: ::[A-Za-z_][A-Za-z0-9_]*)* )) ( \[ (?:$qq_bracket)*? \] ) \z/oxms) {
            $char[$i] = e_capture($1.'->'.$2);
        }

        # $$foo{ ... } --> $ $foo->{ ... }
        elsif ($char[$i] =~ /\A \$ ((?> \$ [A-Za-z_][A-Za-z0-9_]*(?: ::[A-Za-z_][A-Za-z0-9_]*)* )) ( \{ (?:$qq_brace)*? \} ) \z/oxms) {
            $char[$i] = e_capture($1.'->'.$2);
        }

        # $$foo
        elsif ($char[$i] =~ /\A \$ ((?> \$ [A-Za-z_][A-Za-z0-9_]*(?: ::[A-Za-z_][A-Za-z0-9_]*)* )) \z/oxms) {
            $char[$i] = e_capture($1);
        }

        # $`, ${`}, $PREMATCH, ${PREMATCH}, ${^PREMATCH} --> Ekoi8r::PREMATCH()
        elsif ($char[$i] =~ /\A ( \$` | \$\{`\} | \$ (?>\s*) PREMATCH  | \$ (?>\s*) \{ (?>\s*) PREMATCH  (?>\s*) \} | \$ (?>\s*) \{\^PREMATCH\}  ) \z/oxmsgc) {
            $char[$i] = '@{[Ekoi8r::PREMATCH()]}';
        }

        # $&, ${&}, $MATCH, ${MATCH}, ${^MATCH} --> Ekoi8r::MATCH()
        elsif ($char[$i] =~ /\A ( \$& | \$\{&\} | \$ (?>\s*) MATCH     | \$ (?>\s*) \{ (?>\s*) MATCH     (?>\s*) \} | \$ (?>\s*) \{\^MATCH\}     ) \z/oxmsgc) {
            $char[$i] = '@{[Ekoi8r::MATCH()]}';
        }

        # $POSTMATCH, ${POSTMATCH}, ${^POSTMATCH} --> Ekoi8r::POSTMATCH()
        elsif ($char[$i] =~ /\A (                 \$ (?>\s*) POSTMATCH | \$ (?>\s*) \{ (?>\s*) POSTMATCH (?>\s*) \} | \$ (?>\s*) \{\^POSTMATCH\} ) \z/oxmsgc) {
            $char[$i] = '@{[Ekoi8r::POSTMATCH()]}';
        }

        # ${ foo } --> ${ foo }
        elsif ($char[$i] =~ /\A \$ (?>\s*) \{ (?> \s* [A-Za-z_][A-Za-z0-9_]*(?: ::[A-Za-z_][A-Za-z0-9_]*)* \s* ) \}                                \z/oxms) {
        }

        # ${ ... }
        elsif ($char[$i] =~ /\A \$ (?>\s*) \{ ( .+ ) \} \z/oxms) {
            $char[$i] = e_capture($1);
        }
    }

    # return string
    if ($left_e > $right_e) {
        return join '', @char, '>]}' x ($left_e - $right_e);
    }
    return     join '', @char;
}

#
# escape regexp (m//, qr//)
#
sub e_qr {
    my($ope,$delimiter,$end_delimiter,$string,$modifier) = @_;
    $modifier ||= '';

    $modifier =~ tr/p//d;
    if ($modifier =~ /([adlu])/oxms) {
        my $line = 0;
        for (my $i=0; my($package,$filename,$use_line,$subroutine) = caller($i); $i++) {
            if ($filename ne __FILE__) {
                $line = $use_line + (CORE::substr($_,0,pos($_)) =~ tr/\n//) + 1;
                last;
            }
        }
        die qq{Unsupported modifier "$1" used at line $line.\n};
    }

    $slash = 'div';

    # literal null string pattern
    if ($string eq '') {
        $modifier =~ tr/bB//d;
        $modifier =~ tr/i//d;
        return join '', $ope, $delimiter, $end_delimiter, $modifier;
    }

    # /b /B modifier
    elsif ($modifier =~ tr/bB//d) {

        # choice again delimiter
        if ($delimiter =~ / [\@:] /oxms) {
            my @char = $string =~ /\G ([\x00-\xFF]) /oxmsg;
            my %octet = map {$_ => 1} @char;
            if (not $octet{')'}) {
                $delimiter     = '(';
                $end_delimiter = ')';
            }
            elsif (not $octet{'}'}) {
                $delimiter     = '{';
                $end_delimiter = '}';
            }
            elsif (not $octet{']'}) {
                $delimiter     = '[';
                $end_delimiter = ']';
            }
            elsif (not $octet{'>'}) {
                $delimiter     = '<';
                $end_delimiter = '>';
            }
            else {
                for my $char (qw( ! " $ % & * + - . / = ? ^ ` | ~ ), "\x00".."\x1F", "\x7F", "\xFF") {
                    if (not $octet{$char}) {
                        $delimiter     = $char;
                        $end_delimiter = $char;
                        last;
                    }
                }
            }
        }

        if (($ope =~ /\A m? \z/oxms) and ($delimiter eq '?')) {
            return join '', $ope, $delimiter,        $string,      $matched, $end_delimiter, $modifier;
        }
        else {
            return join '', $ope, $delimiter, '(?:', $string, ')', $matched, $end_delimiter, $modifier;
        }
    }

    my $ignorecase = ($modifier =~ /i/oxms) ? 1 : 0;
    my $metachar = qr/[\@\\|[\]{^]/oxms;

    # split regexp
    my @char = $string =~ /\G((?>
        [^\\\$\@\[\(] |
        \\x   (?>[0-9A-Fa-f]{1,2}) |
        \\    (?>[0-7]{2,3})       |
        \\c   [\x40-\x5F]          |
        \\x\{ (?>[0-9A-Fa-f]+) \}  |
        \\o\{ (?>[0-7]+)       \}  |
        \\[bBNpP]\{ (?>[^0-9\}][^\}]*) \} |
        \\  $q_char                |
        \$` | \$\{`\} | \$ (?>\s*) PREMATCH  | \$ (?>\s*) \{ (?>\s*) PREMATCH  (?>\s*) \} | \$ (?>\s*) \{\^PREMATCH\}  |
        \$& | \$\{&\} | \$ (?>\s*) MATCH     | \$ (?>\s*) \{ (?>\s*) MATCH     (?>\s*) \} | \$ (?>\s*) \{\^MATCH\}     |
                        \$ (?>\s*) POSTMATCH | \$ (?>\s*) \{ (?>\s*) POSTMATCH (?>\s*) \} | \$ (?>\s*) \{\^POSTMATCH\} |
        [\$\@] $qq_variable        |
        \$ (?>\s* [0-9]+)          |
        \$ (?>\s*) \{ (?>\s* [0-9]+ \s*) \}  |
        \$ \$ (?![\w\{])           |
        \$ (?>\s*) \$ (?>\s*) $qq_variable   |
        \[\^                       |
        \[\:   (?>[a-z]+) :\]      |
        \[\:\^ (?>[a-z]+) :\]      |
        \(\?                       |
            $q_char
    ))/oxmsg;

    # choice again delimiter
    if ($delimiter =~ / [\@:] /oxms) {
        my %octet = map {$_ => 1} @char;
        if (not $octet{')'}) {
            $delimiter     = '(';
            $end_delimiter = ')';
        }
        elsif (not $octet{'}'}) {
            $delimiter     = '{';
            $end_delimiter = '}';
        }
        elsif (not $octet{']'}) {
            $delimiter     = '[';
            $end_delimiter = ']';
        }
        elsif (not $octet{'>'}) {
            $delimiter     = '<';
            $end_delimiter = '>';
        }
        else {
            for my $char (qw( ! " $ % & * + - . / = ? ^ ` | ~ ), "\x00".."\x1F", "\x7F", "\xFF") {
                if (not $octet{$char}) {
                    $delimiter     = $char;
                    $end_delimiter = $char;
                    last;
                }
            }
        }
    }

    my $left_e  = 0;
    my $right_e = 0;
    for (my $i=0; $i <= $#char; $i++) {

        # "\L\u" --> "\u\L"
        if (($char[$i] eq '\L') and ($char[$i+1] eq '\u')) {
            @char[$i,$i+1] = @char[$i+1,$i];
        }

        # "\U\l" --> "\l\U"
        elsif (($char[$i] eq '\U') and ($char[$i+1] eq '\l')) {
            @char[$i,$i+1] = @char[$i+1,$i];
        }

        # octal escape sequence
        elsif ($char[$i] =~ /\A \\o \{ ([0-7]+) \} \z/oxms) {
            $char[$i] = Ekoi8r::octchr($1);
        }

        # hexadecimal escape sequence
        elsif ($char[$i] =~ /\A \\x \{ ([0-9A-Fa-f]+) \} \z/oxms) {
            $char[$i] = Ekoi8r::hexchr($1);
        }

        # \b{...}      --> b\{...}
        # \B{...}      --> B\{...}
        # \N{CHARNAME} --> N\{CHARNAME}
        # \p{PROPERTY} --> p\{PROPERTY}
        # \P{PROPERTY} --> P\{PROPERTY}
        elsif ($char[$i] =~ /\A \\ ([bBNpP]) ( \{ ([^0-9\}][^\}]*) \} ) \z/oxms) {
            $char[$i] = $1 . '\\' . $2;
        }

        # \p, \P, \X --> p, P, X
        elsif ($char[$i] =~ /\A \\ ( [pPX] ) \z/oxms) {
            $char[$i] = $1;
        }

        if (0) {
        }

        # join separated multiple-octet
        elsif ($char[$i] =~ /\A (?: \\ [0-7]{2,3} | \\x [0-9A-Fa-f]{1,2}) \z/oxms) {
            if (   ($i+3 <= $#char) and (grep(/\A (?: \\ [0-7]{2,3} | \\x [0-9A-Fa-f]{1,2}) \z/oxms, @char[$i+1..$i+3]) == 3) and (CORE::eval(sprintf '"%s%s%s%s"', @char[$i..$i+3]) =~ /\A $q_char \z/oxms)) {
                $char[$i] .= join '', splice @char, $i+1, 3;
            }
            elsif (($i+2 <= $#char) and (grep(/\A (?: \\ [0-7]{2,3} | \\x [0-9A-Fa-f]{1,2}) \z/oxms, @char[$i+1..$i+2]) == 2) and (CORE::eval(sprintf '"%s%s%s"',   @char[$i..$i+2]) =~ /\A $q_char \z/oxms)) {
                $char[$i] .= join '', splice @char, $i+1, 2;
            }
            elsif (($i+1 <= $#char) and (grep(/\A (?: \\ [0-7]{2,3} | \\x [0-9A-Fa-f]{1,2}) \z/oxms, $char[$i+1      ]) == 1) and (CORE::eval(sprintf '"%s%s"',     @char[$i..$i+1]) =~ /\A $q_char \z/oxms)) {
                $char[$i] .= join '', splice @char, $i+1, 1;
            }
        }

        # open character class [...]
        elsif ($char[$i] eq '[') {
            my $left = $i;

            # [] make die "Unmatched [] in regexp ...\n"
            # (and so on)

            if ($char[$i+1] eq ']') {
                $i++;
            }

            while (1) {
                if (++$i > $#char) {
                    die __FILE__, ": Unmatched [] in regexp\n";
                }
                if ($char[$i] eq ']') {
                    my $right = $i;

                    # [...]
                    if (grep(/\A [\$\@]/oxms,@char[$left+1..$right-1]) >= 1) {
                        splice @char, $left, $right-$left+1, sprintf(q{@{[Ekoi8r::charlist_qr(%s,'%s')]}}, join(',', map {qq_stuff($delimiter,$end_delimiter,$_)} @char[$left+1..$right-1]), $modifier);
                    }
                    else {
                        splice @char, $left, $right-$left+1, Ekoi8r::charlist_qr(@char[$left+1..$right-1], $modifier);
                    }

                    $i = $left;
                    last;
                }
            }
        }

        # open character class [^...]
        elsif ($char[$i] eq '[^') {
            my $left = $i;

            # [^] make die "Unmatched [] in regexp ...\n"
            # (and so on)

            if ($char[$i+1] eq ']') {
                $i++;
            }

            while (1) {
                if (++$i > $#char) {
                    die __FILE__, ": Unmatched [] in regexp\n";
                }
                if ($char[$i] eq ']') {
                    my $right = $i;

                    # [^...]
                    if (grep(/\A [\$\@]/oxms,@char[$left+1..$right-1]) >= 1) {
                        splice @char, $left, $right-$left+1, sprintf(q{@{[Ekoi8r::charlist_not_qr(%s,'%s')]}}, join(',', map {qq_stuff($delimiter,$end_delimiter,$_)} @char[$left+1..$right-1]), $modifier);
                    }
                    else {
                        splice @char, $left, $right-$left+1, Ekoi8r::charlist_not_qr(@char[$left+1..$right-1], $modifier);
                    }

                    $i = $left;
                    last;
                }
            }
        }

        # rewrite character class or escape character
        elsif (my $char = character_class($char[$i],$modifier)) {
            $char[$i] = $char;
        }

        # /i modifier
        elsif ($ignorecase and ($char[$i] =~ /\A [\x00-\xFF] \z/oxms) and (Ekoi8r::uc($char[$i]) ne Ekoi8r::fc($char[$i]))) {
            if (CORE::length(Ekoi8r::fc($char[$i])) == 1) {
                $char[$i] = '['   . Ekoi8r::uc($char[$i])       . Ekoi8r::fc($char[$i]) . ']';
            }
            else {
                $char[$i] = '(?:' . Ekoi8r::uc($char[$i]) . '|' . Ekoi8r::fc($char[$i]) . ')';
            }
        }

        # \u \l \U \L \F \Q \E
        elsif ($char[$i] =~ /\A [<>] \z/oxms) {
            if ($right_e < $left_e) {
                $char[$i] = '\\' . $char[$i];
            }
        }
        elsif ($char[$i] eq '\u') {
            $char[$i] = '@{[Ekoi8r::ucfirst qq<';
            $left_e++;
        }
        elsif ($char[$i] eq '\l') {
            $char[$i] = '@{[Ekoi8r::lcfirst qq<';
            $left_e++;
        }
        elsif ($char[$i] eq '\U') {
            $char[$i] = '@{[Ekoi8r::uc qq<';
            $left_e++;
        }
        elsif ($char[$i] eq '\L') {
            $char[$i] = '@{[Ekoi8r::lc qq<';
            $left_e++;
        }
        elsif ($char[$i] eq '\F') {
            $char[$i] = '@{[Ekoi8r::fc qq<';
            $left_e++;
        }
        elsif ($char[$i] eq '\Q') {
            $char[$i] = '@{[CORE::quotemeta qq<';
            $left_e++;
        }
        elsif ($char[$i] eq '\E') {
            if ($right_e < $left_e) {
                $char[$i] = '>]}';
                $right_e++;
            }
            else {
                $char[$i] = '';
            }
        }
        elsif ($char[$i] eq '\Q') {
            while (1) {
                if (++$i > $#char) {
                    last;
                }
                if ($char[$i] eq '\E') {
                    last;
                }
            }
        }
        elsif ($char[$i] eq '\E') {
        }

        # $0 --> $0
        elsif ($char[$i] =~ /\A \$ 0 \z/oxms) {
            if ($ignorecase) {
                $char[$i] = '@{[Ekoi8r::ignorecase(' . $char[$i] . ')]}';
            }
        }
        elsif ($char[$i] =~ /\A \$ \{ (?>\s*) 0 (?>\s*) \} \z/oxms) {
            if ($ignorecase) {
                $char[$i] = '@{[Ekoi8r::ignorecase(' . $char[$i] . ')]}';
            }
        }

        # $$ --> $$
        elsif ($char[$i] =~ /\A \$\$ \z/oxms) {
        }

        # $1, $2, $3 --> $2, $3, $4 after s/// with multibyte anchoring
        # $1, $2, $3 --> $1, $2, $3 otherwise
        elsif ($char[$i] =~ /\A \$ ((?>[1-9][0-9]*)) \z/oxms) {
            $char[$i] = e_capture($1);
            if ($ignorecase) {
                $char[$i] = '@{[Ekoi8r::ignorecase(' . $char[$i] . ')]}';
            }
        }
        elsif ($char[$i] =~ /\A \$ \{ (?>\s*) ((?>[1-9][0-9]*)) (?>\s*) \} \z/oxms) {
            $char[$i] = e_capture($1);
            if ($ignorecase) {
                $char[$i] = '@{[Ekoi8r::ignorecase(' . $char[$i] . ')]}';
            }
        }

        # $$foo[ ... ] --> $ $foo->[ ... ]
        elsif ($char[$i] =~ /\A \$ ((?> \$ [A-Za-z_][A-Za-z0-9_]*(?: ::[A-Za-z_][A-Za-z0-9_]*)* )) ( \[ (?:$qq_bracket)*? \] ) \z/oxms) {
            $char[$i] = e_capture($1.'->'.$2);
            if ($ignorecase) {
                $char[$i] = '@{[Ekoi8r::ignorecase(' . $char[$i] . ')]}';
            }
        }

        # $$foo{ ... } --> $ $foo->{ ... }
        elsif ($char[$i] =~ /\A \$ ((?> \$ [A-Za-z_][A-Za-z0-9_]*(?: ::[A-Za-z_][A-Za-z0-9_]*)* )) ( \{ (?:$qq_brace)*? \} ) \z/oxms) {
            $char[$i] = e_capture($1.'->'.$2);
            if ($ignorecase) {
                $char[$i] = '@{[Ekoi8r::ignorecase(' . $char[$i] . ')]}';
            }
        }

        # $$foo
        elsif ($char[$i] =~ /\A \$ ((?> \$ [A-Za-z_][A-Za-z0-9_]*(?: ::[A-Za-z_][A-Za-z0-9_]*)* )) \z/oxms) {
            $char[$i] = e_capture($1);
            if ($ignorecase) {
                $char[$i] = '@{[Ekoi8r::ignorecase(' . $char[$i] . ')]}';
            }
        }

        # $`, ${`}, $PREMATCH, ${PREMATCH}, ${^PREMATCH} --> Ekoi8r::PREMATCH()
        elsif ($char[$i] =~ /\A ( \$` | \$\{`\} | \$ (?>\s*) PREMATCH  | \$ (?>\s*) \{ (?>\s*) PREMATCH  (?>\s*) \} | \$ (?>\s*) \{\^PREMATCH\}  ) \z/oxmsgc) {
            if ($ignorecase) {
                $char[$i] = '@{[Ekoi8r::ignorecase(Ekoi8r::PREMATCH())]}';
            }
            else {
                $char[$i] = '@{[Ekoi8r::PREMATCH()]}';
            }
        }

        # $&, ${&}, $MATCH, ${MATCH}, ${^MATCH} --> Ekoi8r::MATCH()
        elsif ($char[$i] =~ /\A ( \$& | \$\{&\} | \$ (?>\s*) MATCH     | \$ (?>\s*) \{ (?>\s*) MATCH     (?>\s*) \} | \$ (?>\s*) \{\^MATCH\}     ) \z/oxmsgc) {
            if ($ignorecase) {
                $char[$i] = '@{[Ekoi8r::ignorecase(Ekoi8r::MATCH())]}';
            }
            else {
                $char[$i] = '@{[Ekoi8r::MATCH()]}';
            }
        }

        # $POSTMATCH, ${POSTMATCH}, ${^POSTMATCH} --> Ekoi8r::POSTMATCH()
        elsif ($char[$i] =~ /\A (                 \$ (?>\s*) POSTMATCH | \$ (?>\s*) \{ (?>\s*) POSTMATCH (?>\s*) \} | \$ (?>\s*) \{\^POSTMATCH\} ) \z/oxmsgc) {
            if ($ignorecase) {
                $char[$i] = '@{[Ekoi8r::ignorecase(Ekoi8r::POSTMATCH())]}';
            }
            else {
                $char[$i] = '@{[Ekoi8r::POSTMATCH()]}';
            }
        }

        # ${ foo }
        elsif ($char[$i] =~ /\A \$ (?>\s*) \{ ((?> \s* [A-Za-z_][A-Za-z0-9_]*(?: ::[A-Za-z_][A-Za-z0-9_]*)* \s* )) \}                              \z/oxms) {
            if ($ignorecase) {
                $char[$i] = '@{[Ekoi8r::ignorecase(' . $char[$i] . ')]}';
            }
        }

        # ${ ... }
        elsif ($char[$i] =~ /\A \$ (?>\s*) \{ ( .+ ) \} \z/oxms) {
            $char[$i] = e_capture($1);
            if ($ignorecase) {
                $char[$i] = '@{[Ekoi8r::ignorecase(' . $char[$i] . ')]}';
            }
        }

        # $scalar or @array
        elsif ($char[$i] =~ /\A [\$\@].+ /oxms) {
            $char[$i] = e_string($char[$i]);
            if ($ignorecase) {
                $char[$i] = '@{[Ekoi8r::ignorecase(' . $char[$i] . ')]}';
            }
        }

        # quote character before ? + * {
        elsif (($i >= 1) and ($char[$i] =~ /\A [\?\+\*\{] \z/oxms)) {
            if ($char[$i-1] =~ /\A (?:[\x00-\xFF]|\\[0-7]{2,3}|\\x[0-9-A-Fa-f]{1,2}) \z/oxms) {
            }
            elsif (($ope =~ /\A m? \z/oxms) and ($delimiter eq '?')) {
                my $char = $char[$i-1];
                if ($char[$i] eq '{') {
                    die __FILE__, qq{: "MULTIBYTE{n}" should be "(MULTIBYTE){n}" in m?? (and shift \$1,\$2,\$3,...) ($char){n}\n};
                }
                else {
                    die __FILE__, qq{: "MULTIBYTE$char[$i]" should be "(MULTIBYTE)$char[$i]" in m?? (and shift \$1,\$2,\$3,...) ($char)$char[$i]\n};
                }
            }
            else {
                $char[$i-1] = '(?:' . $char[$i-1] . ')';
            }
        }
    }

    # make regexp string
    $modifier =~ tr/i//d;
    if ($left_e > $right_e) {
        if (($ope =~ /\A m? \z/oxms) and ($delimiter eq '?')) {
            return join '', $ope, $delimiter, $anchor,        @char, '>]}' x ($left_e - $right_e),      $matched, $end_delimiter, $modifier;
        }
        else {
            return join '', $ope, $delimiter, $anchor, '(?:', @char, '>]}' x ($left_e - $right_e), ')', $matched, $end_delimiter, $modifier;
        }
    }
    if (($ope =~ /\A m? \z/oxms) and ($delimiter eq '?')) {
        return     join '', $ope, $delimiter, $anchor,        @char,                                    $matched, $end_delimiter, $modifier;
    }
    else {
        return     join '', $ope, $delimiter, $anchor, '(?:', @char,                               ')', $matched, $end_delimiter, $modifier;
    }
}

#
# double quote stuff
#
sub qq_stuff {
    my($delimiter,$end_delimiter,$stuff) = @_;

    # scalar variable or array variable
    if ($stuff =~ /\A [\$\@] /oxms) {
        return $stuff;
    }

    # quote by delimiter
    my %octet = map {$_ => 1} ($stuff =~ /\G ([\x00-\xFF]) /oxmsg);
    for my $char (qw( ! " $ % & * + - . / : = ? @ ^ ` | ~ ), "\x00".."\x1F", "\x7F", "\xFF") {
        next if $char eq $delimiter;
        next if $char eq $end_delimiter;
        if (not $octet{$char}) {
            return join '', 'qq', $char, $stuff, $char;
        }
    }
    return join '', 'qq', '<', $stuff, '>';
}

#
# escape regexp (m'', qr'', and m''b, qr''b)
#
sub e_qr_q {
    my($ope,$delimiter,$end_delimiter,$string,$modifier) = @_;
    $modifier ||= '';

    $modifier =~ tr/p//d;
    if ($modifier =~ /([adlu])/oxms) {
        my $line = 0;
        for (my $i=0; my($package,$filename,$use_line,$subroutine) = caller($i); $i++) {
            if ($filename ne __FILE__) {
                $line = $use_line + (CORE::substr($_,0,pos($_)) =~ tr/\n//) + 1;
                last;
            }
        }
        die qq{Unsupported modifier "$1" used at line $line.\n};
    }

    $slash = 'div';

    # literal null string pattern
    if ($string eq '') {
        $modifier =~ tr/bB//d;
        $modifier =~ tr/i//d;
        return join '', $ope, $delimiter, $end_delimiter, $modifier;
    }

    # with /b /B modifier
    elsif ($modifier =~ tr/bB//d) {
        return e_qr_qb($ope,$delimiter,$end_delimiter,$string,$modifier);
    }

    # without /b /B modifier
    else {
        return e_qr_qt($ope,$delimiter,$end_delimiter,$string,$modifier);
    }
}

#
# escape regexp (m'', qr'')
#
sub e_qr_qt {
    my($ope,$delimiter,$end_delimiter,$string,$modifier) = @_;

    my $ignorecase = ($modifier =~ /i/oxms) ? 1 : 0;

    # split regexp
    my @char = $string =~ /\G((?>
        [^\\\[\$\@\/] |
        [\x00-\xFF] |
        \[\^                            |
        \[\:   (?>[a-z]+) \:\]          |
        \[\:\^ (?>[a-z]+) \:\]          |
        [\$\@\/]                        |
        \\     (?:$q_char)              |
               (?:$q_char)
    ))/oxmsg;

    # unescape character
    for (my $i=0; $i <= $#char; $i++) {
        if (0) {
        }

        # open character class [...]
        elsif ($char[$i] eq '[') {
            my $left = $i;
            if ($char[$i+1] eq ']') {
                $i++;
            }
            while (1) {
                if (++$i > $#char) {
                    die __FILE__, ": Unmatched [] in regexp\n";
                }
                if ($char[$i] eq ']') {
                    my $right = $i;

                    # [...]
                    splice @char, $left, $right-$left+1, Ekoi8r::charlist_qr(@char[$left+1..$right-1], $modifier);

                    $i = $left;
                    last;
                }
            }
        }

        # open character class [^...]
        elsif ($char[$i] eq '[^') {
            my $left = $i;
            if ($char[$i+1] eq ']') {
                $i++;
            }
            while (1) {
                if (++$i > $#char) {
                    die __FILE__, ": Unmatched [] in regexp\n";
                }
                if ($char[$i] eq ']') {
                    my $right = $i;

                    # [^...]
                    splice @char, $left, $right-$left+1, Ekoi8r::charlist_not_qr(@char[$left+1..$right-1], $modifier);

                    $i = $left;
                    last;
                }
            }
        }

        # escape $ @ / and \
        elsif ($char[$i] =~ /\A [\$\@\/\\] \z/oxms) {
            $char[$i] = '\\' . $char[$i];
        }

        # rewrite character class or escape character
        elsif (my $char = character_class($char[$i],$modifier)) {
            $char[$i] = $char;
        }

        # /i modifier
        elsif ($ignorecase and ($char[$i] =~ /\A [\x00-\xFF] \z/oxms) and (Ekoi8r::uc($char[$i]) ne Ekoi8r::fc($char[$i]))) {
            if (CORE::length(Ekoi8r::fc($char[$i])) == 1) {
                $char[$i] = '['   . Ekoi8r::uc($char[$i])       . Ekoi8r::fc($char[$i]) . ']';
            }
            else {
                $char[$i] = '(?:' . Ekoi8r::uc($char[$i]) . '|' . Ekoi8r::fc($char[$i]) . ')';
            }
        }

        # quote character before ? + * {
        elsif (($i >= 1) and ($char[$i] =~ /\A [\?\+\*\{] \z/oxms)) {
            if ($char[$i-1] =~ /\A [\x00-\xFF] \z/oxms) {
            }
            else {
                $char[$i-1] = '(?:' . $char[$i-1] . ')';
            }
        }
    }

    $delimiter     = '/';
    $end_delimiter = '/';

    $modifier =~ tr/i//d;
    return join '', $ope, $delimiter, $anchor, '(?:', @char, ')', $matched, $end_delimiter, $modifier;
}

#
# escape regexp (m''b, qr''b)
#
sub e_qr_qb {
    my($ope,$delimiter,$end_delimiter,$string,$modifier) = @_;

    # split regexp
    my @char = $string =~ /\G ((?>[^\\]|\\\\)) /oxmsg;

    # unescape character
    for (my $i=0; $i <= $#char; $i++) {
        if (0) {
        }

        # remain \\
        elsif ($char[$i] eq '\\\\') {
        }

        # escape $ @ / and \
        elsif ($char[$i] =~ /\A [\$\@\/\\] \z/oxms) {
            $char[$i] = '\\' . $char[$i];
        }
    }

    $delimiter     = '/';
    $end_delimiter = '/';
    return join '', $ope, $delimiter, '(?:', @char, ')', $matched, $end_delimiter, $modifier;
}

#
# escape regexp (s/here//)
#
sub e_s1 {
    my($ope,$delimiter,$end_delimiter,$string,$modifier) = @_;
    $modifier ||= '';

    $modifier =~ tr/p//d;
    if ($modifier =~ /([adlu])/oxms) {
        my $line = 0;
        for (my $i=0; my($package,$filename,$use_line,$subroutine) = caller($i); $i++) {
            if ($filename ne __FILE__) {
                $line = $use_line + (CORE::substr($_,0,pos($_)) =~ tr/\n//) + 1;
                last;
            }
        }
        die qq{Unsupported modifier "$1" used at line $line.\n};
    }

    $slash = 'div';

    # literal null string pattern
    if ($string eq '') {
        $modifier =~ tr/bB//d;
        $modifier =~ tr/i//d;
        return join '', $ope, $delimiter, $end_delimiter, $modifier;
    }

    # /b /B modifier
    elsif ($modifier =~ tr/bB//d) {

        # choice again delimiter
        if ($delimiter =~ / [\@:] /oxms) {
            my @char = $string =~ /\G ([\x00-\xFF]) /oxmsg;
            my %octet = map {$_ => 1} @char;
            if (not $octet{')'}) {
                $delimiter     = '(';
                $end_delimiter = ')';
            }
            elsif (not $octet{'}'}) {
                $delimiter     = '{';
                $end_delimiter = '}';
            }
            elsif (not $octet{']'}) {
                $delimiter     = '[';
                $end_delimiter = ']';
            }
            elsif (not $octet{'>'}) {
                $delimiter     = '<';
                $end_delimiter = '>';
            }
            else {
                for my $char (qw( ! " $ % & * + - . / = ? ^ ` | ~ ), "\x00".."\x1F", "\x7F", "\xFF") {
                    if (not $octet{$char}) {
                        $delimiter     = $char;
                        $end_delimiter = $char;
                        last;
                    }
                }
            }
        }

        my $prematch = '';
        return join '', $ope, $delimiter, $prematch, '(?:', $string, ')', $matched, $end_delimiter, $modifier;
    }

    my $ignorecase = ($modifier =~ /i/oxms) ? 1 : 0;
    my $metachar = qr/[\@\\|[\]{^]/oxms;

    # split regexp
    my @char = $string =~ /\G((?>
        [^\\\$\@\[\(] |
        \\                               (?>[1-9][0-9]*)            |
        \\g (?>\s*)                      (?>[1-9][0-9]*)            |
        \\g (?>\s*) \{ (?>\s*)           (?>[1-9][0-9]*) (?>\s*) \} |
        \\g (?>\s*) \{ (?>\s*) - (?>\s*) (?>[1-9][0-9]*) (?>\s*) \} |
        \\x                              (?>[0-9A-Fa-f]{1,2})       |
        \\                               (?>[0-7]{2,3})             |
        \\c                              [\x40-\x5F]                |
        \\x\{                            (?>[0-9A-Fa-f]+)        \} |
        \\o\{                            (?>[0-7]+)              \} |
        \\[bBNpP]\{                      (?>[^0-9\}][^\}]*) \} |
        \\ $q_char                           |
        \$` | \$\{`\} | \$ (?>\s*) PREMATCH  | \$ (?>\s*) \{ (?>\s*) PREMATCH  (?>\s*) \} | \$ (?>\s*) \{\^PREMATCH\}  |
        \$& | \$\{&\} | \$ (?>\s*) MATCH     | \$ (?>\s*) \{ (?>\s*) MATCH     (?>\s*) \} | \$ (?>\s*) \{\^MATCH\}     |
                        \$ (?>\s*) POSTMATCH | \$ (?>\s*) \{ (?>\s*) POSTMATCH (?>\s*) \} | \$ (?>\s*) \{\^POSTMATCH\} |
        [\$\@] $qq_variable                  |
        \$ (?>\s* [0-9]+)                    |
        \$ (?>\s*) \{ (?>\s* [0-9]+ \s*) \}  |
        \$ \$ (?![\w\{])                     |
        \$ (?>\s*) \$ (?>\s*) $qq_variable   |
        \[\^                                 |
        \[\:   (?>[a-z]+) :\]                |
        \[\:\^ (?>[a-z]+) :\]                |
        \(\?                                 |
            $q_char
    ))/oxmsg;

    # choice again delimiter
    if ($delimiter =~ / [\@:] /oxms) {
        my %octet = map {$_ => 1} @char;
        if (not $octet{')'}) {
            $delimiter     = '(';
            $end_delimiter = ')';
        }
        elsif (not $octet{'}'}) {
            $delimiter     = '{';
            $end_delimiter = '}';
        }
        elsif (not $octet{']'}) {
            $delimiter     = '[';
            $end_delimiter = ']';
        }
        elsif (not $octet{'>'}) {
            $delimiter     = '<';
            $end_delimiter = '>';
        }
        else {
            for my $char (qw( ! " $ % & * + - . / = ? ^ ` | ~ ), "\x00".."\x1F", "\x7F", "\xFF") {
                if (not $octet{$char}) {
                    $delimiter     = $char;
                    $end_delimiter = $char;
                    last;
                }
            }
        }
    }

    # count '('
    my $parens = grep { $_ eq '(' } @char;

    my $left_e  = 0;
    my $right_e = 0;
    for (my $i=0; $i <= $#char; $i++) {

        # "\L\u" --> "\u\L"
        if (($char[$i] eq '\L') and ($char[$i+1] eq '\u')) {
            @char[$i,$i+1] = @char[$i+1,$i];
        }

        # "\U\l" --> "\l\U"
        elsif (($char[$i] eq '\U') and ($char[$i+1] eq '\l')) {
            @char[$i,$i+1] = @char[$i+1,$i];
        }

        # octal escape sequence
        elsif ($char[$i] =~ /\A \\o \{ ([0-7]+) \} \z/oxms) {
            $char[$i] = Ekoi8r::octchr($1);
        }

        # hexadecimal escape sequence
        elsif ($char[$i] =~ /\A \\x \{ ([0-9A-Fa-f]+) \} \z/oxms) {
            $char[$i] = Ekoi8r::hexchr($1);
        }

        # \b{...}      --> b\{...}
        # \B{...}      --> B\{...}
        # \N{CHARNAME} --> N\{CHARNAME}
        # \p{PROPERTY} --> p\{PROPERTY}
        # \P{PROPERTY} --> P\{PROPERTY}
        elsif ($char[$i] =~ /\A \\ ([bBNpP]) ( \{ ([^0-9\}][^\}]*) \} ) \z/oxms) {
            $char[$i] = $1 . '\\' . $2;
        }

        # \p, \P, \X --> p, P, X
        elsif ($char[$i] =~ /\A \\ ( [pPX] ) \z/oxms) {
            $char[$i] = $1;
        }

        if (0) {
        }

        # join separated multiple-octet
        elsif ($char[$i] =~ /\A (?: \\ [0-7]{2,3} | \\x [0-9A-Fa-f]{1,2}) \z/oxms) {
            if (   ($i+3 <= $#char) and (grep(/\A (?: \\ [0-7]{2,3} | \\x [0-9A-Fa-f]{1,2}) \z/oxms, @char[$i+1..$i+3]) == 3) and (CORE::eval(sprintf '"%s%s%s%s"', @char[$i..$i+3]) =~ /\A $q_char \z/oxms)) {
                $char[$i] .= join '', splice @char, $i+1, 3;
            }
            elsif (($i+2 <= $#char) and (grep(/\A (?: \\ [0-7]{2,3} | \\x [0-9A-Fa-f]{1,2}) \z/oxms, @char[$i+1..$i+2]) == 2) and (CORE::eval(sprintf '"%s%s%s"',   @char[$i..$i+2]) =~ /\A $q_char \z/oxms)) {
                $char[$i] .= join '', splice @char, $i+1, 2;
            }
            elsif (($i+1 <= $#char) and (grep(/\A (?: \\ [0-7]{2,3} | \\x [0-9A-Fa-f]{1,2}) \z/oxms, $char[$i+1      ]) == 1) and (CORE::eval(sprintf '"%s%s"',     @char[$i..$i+1]) =~ /\A $q_char \z/oxms)) {
                $char[$i] .= join '', splice @char, $i+1, 1;
            }
        }

        # open character class [...]
        elsif ($char[$i] eq '[') {
            my $left = $i;
            if ($char[$i+1] eq ']') {
                $i++;
            }
            while (1) {
                if (++$i > $#char) {
                    die __FILE__, ": Unmatched [] in regexp\n";
                }
                if ($char[$i] eq ']') {
                    my $right = $i;

                    # [...]
                    if (grep(/\A [\$\@]/oxms,@char[$left+1..$right-1]) >= 1) {
                        splice @char, $left, $right-$left+1, sprintf(q{@{[Ekoi8r::charlist_qr(%s,'%s')]}}, join(',', map {qq_stuff($delimiter,$end_delimiter,$_)} @char[$left+1..$right-1]), $modifier);
                    }
                    else {
                        splice @char, $left, $right-$left+1, Ekoi8r::charlist_qr(@char[$left+1..$right-1], $modifier);
                    }

                    $i = $left;
                    last;
                }
            }
        }

        # open character class [^...]
        elsif ($char[$i] eq '[^') {
            my $left = $i;
            if ($char[$i+1] eq ']') {
                $i++;
            }
            while (1) {
                if (++$i > $#char) {
                    die __FILE__, ": Unmatched [] in regexp\n";
                }
                if ($char[$i] eq ']') {
                    my $right = $i;

                    # [^...]
                    if (grep(/\A [\$\@]/oxms,@char[$left+1..$right-1]) >= 1) {
                        splice @char, $left, $right-$left+1, sprintf(q{@{[Ekoi8r::charlist_not_qr(%s,'%s')]}}, join(',', map {qq_stuff($delimiter,$end_delimiter,$_)} @char[$left+1..$right-1]), $modifier);
                    }
                    else {
                        splice @char, $left, $right-$left+1, Ekoi8r::charlist_not_qr(@char[$left+1..$right-1], $modifier);
                    }

                    $i = $left;
                    last;
                }
            }
        }

        # rewrite character class or escape character
        elsif (my $char = character_class($char[$i],$modifier)) {
            $char[$i] = $char;
        }

        # /i modifier
        elsif ($ignorecase and ($char[$i] =~ /\A [\x00-\xFF] \z/oxms) and (Ekoi8r::uc($char[$i]) ne Ekoi8r::fc($char[$i]))) {
            if (CORE::length(Ekoi8r::fc($char[$i])) == 1) {
                $char[$i] = '['   . Ekoi8r::uc($char[$i])       . Ekoi8r::fc($char[$i]) . ']';
            }
            else {
                $char[$i] = '(?:' . Ekoi8r::uc($char[$i]) . '|' . Ekoi8r::fc($char[$i]) . ')';
            }
        }

        # \u \l \U \L \F \Q \E
        elsif ($char[$i] =~ /\A [<>] \z/oxms) {
            if ($right_e < $left_e) {
                $char[$i] = '\\' . $char[$i];
            }
        }
        elsif ($char[$i] eq '\u') {
            $char[$i] = '@{[Ekoi8r::ucfirst qq<';
            $left_e++;
        }
        elsif ($char[$i] eq '\l') {
            $char[$i] = '@{[Ekoi8r::lcfirst qq<';
            $left_e++;
        }
        elsif ($char[$i] eq '\U') {
            $char[$i] = '@{[Ekoi8r::uc qq<';
            $left_e++;
        }
        elsif ($char[$i] eq '\L') {
            $char[$i] = '@{[Ekoi8r::lc qq<';
            $left_e++;
        }
        elsif ($char[$i] eq '\F') {
            $char[$i] = '@{[Ekoi8r::fc qq<';
            $left_e++;
        }
        elsif ($char[$i] eq '\Q') {
            $char[$i] = '@{[CORE::quotemeta qq<';
            $left_e++;
        }
        elsif ($char[$i] eq '\E') {
            if ($right_e < $left_e) {
                $char[$i] = '>]}';
                $right_e++;
            }
            else {
                $char[$i] = '';
            }
        }
        elsif ($char[$i] eq '\Q') {
            while (1) {
                if (++$i > $#char) {
                    last;
                }
                if ($char[$i] eq '\E') {
                    last;
                }
            }
        }
        elsif ($char[$i] eq '\E') {
        }

        # \0 --> \0
        elsif ($char[$i] =~ /\A \\ (?>\s*) 0 \z/oxms) {
        }

        # \g{N}, \g{-N}

        # P.108 Using Simple Patterns
        # in Chapter 7: In the World of Regular Expressions
        # of ISBN 978-0-596-52010-6 Learning Perl, Fifth Edition

        # P.221 Capturing
        # in Chapter 5: Pattern Matching
        # of ISBN 978-0-596-00492-7 Programming Perl 4th Edition.

        # \g{-1}, \g{-2}, \g{-3} --> \g{-1}, \g{-2}, \g{-3}
        elsif ($char[$i] =~ /\A \\g (?>\s*) \{ (?>\s*) - (?>\s*) ((?>[1-9][0-9]*)) (?>\s*) \} \z/oxms) {
        }

        # \g{1}, \g{2}, \g{3} --> \g{2}, \g{3}, \g{4} (only when multibyte anchoring is enable)
        elsif ($char[$i] =~ /\A \\g (?>\s*) \{ (?>\s*) ((?>[1-9][0-9]*)) (?>\s*) \} \z/oxms) {
        }

        # \g1, \g2, \g3 --> \g2, \g3, \g4 (only when multibyte anchoring is enable)
        elsif ($char[$i] =~ /\A \\g (?>\s*) ((?>[1-9][0-9]*)) \z/oxms) {
        }

        # \1, \2, \3 --> \2, \3, \4 (only when multibyte anchoring is enable)
        elsif ($char[$i] =~ /\A \\ (?>\s*) ((?>[1-9][0-9]*)) \z/oxms) {
        }

        # $0 --> $0
        elsif ($char[$i] =~ /\A \$ 0 \z/oxms) {
            if ($ignorecase) {
                $char[$i] = '@{[Ekoi8r::ignorecase(' . $char[$i] . ')]}';
            }
        }
        elsif ($char[$i] =~ /\A \$ \{ (?>\s*) 0 (?>\s*) \} \z/oxms) {
            if ($ignorecase) {
                $char[$i] = '@{[Ekoi8r::ignorecase(' . $char[$i] . ')]}';
            }
        }

        # $$ --> $$
        elsif ($char[$i] =~ /\A \$\$ \z/oxms) {
        }

        # $1, $2, $3 --> $2, $3, $4 after s/// with multibyte anchoring
        # $1, $2, $3 --> $1, $2, $3 otherwise
        elsif ($char[$i] =~ /\A \$ ((?>[1-9][0-9]*)) \z/oxms) {
            $char[$i] = e_capture($1);
            if ($ignorecase) {
                $char[$i] = '@{[Ekoi8r::ignorecase(' . $char[$i] . ')]}';
            }
        }
        elsif ($char[$i] =~ /\A \$ \{ (?>\s*) ((?>[1-9][0-9]*)) (?>\s*) \} \z/oxms) {
            $char[$i] = e_capture($1);
            if ($ignorecase) {
                $char[$i] = '@{[Ekoi8r::ignorecase(' . $char[$i] . ')]}';
            }
        }

        # $$foo[ ... ] --> $ $foo->[ ... ]
        elsif ($char[$i] =~ /\A \$ ((?> \$ [A-Za-z_][A-Za-z0-9_]*(?: ::[A-Za-z_][A-Za-z0-9_]*)* )) ( \[ (?:$qq_bracket)*? \] ) \z/oxms) {
            $char[$i] = e_capture($1.'->'.$2);
            if ($ignorecase) {
                $char[$i] = '@{[Ekoi8r::ignorecase(' . $char[$i] . ')]}';
            }
        }

        # $$foo{ ... } --> $ $foo->{ ... }
        elsif ($char[$i] =~ /\A \$ ((?> \$ [A-Za-z_][A-Za-z0-9_]*(?: ::[A-Za-z_][A-Za-z0-9_]*)* )) ( \{ (?:$qq_brace)*? \} ) \z/oxms) {
            $char[$i] = e_capture($1.'->'.$2);
            if ($ignorecase) {
                $char[$i] = '@{[Ekoi8r::ignorecase(' . $char[$i] . ')]}';
            }
        }

        # $$foo
        elsif ($char[$i] =~ /\A \$ ((?> \$ [A-Za-z_][A-Za-z0-9_]*(?: ::[A-Za-z_][A-Za-z0-9_]*)* )) \z/oxms) {
            $char[$i] = e_capture($1);
            if ($ignorecase) {
                $char[$i] = '@{[Ekoi8r::ignorecase(' . $char[$i] . ')]}';
            }
        }

        # $`, ${`}, $PREMATCH, ${PREMATCH}, ${^PREMATCH} --> Ekoi8r::PREMATCH()
        elsif ($char[$i] =~ /\A ( \$` | \$\{`\} | \$ (?>\s*) PREMATCH  | \$ (?>\s*) \{ (?>\s*) PREMATCH  (?>\s*) \} | \$ (?>\s*) \{\^PREMATCH\}  ) \z/oxmsgc) {
            if ($ignorecase) {
                $char[$i] = '@{[Ekoi8r::ignorecase(Ekoi8r::PREMATCH())]}';
            }
            else {
                $char[$i] = '@{[Ekoi8r::PREMATCH()]}';
            }
        }

        # $&, ${&}, $MATCH, ${MATCH}, ${^MATCH} --> Ekoi8r::MATCH()
        elsif ($char[$i] =~ /\A ( \$& | \$\{&\} | \$ (?>\s*) MATCH     | \$ (?>\s*) \{ (?>\s*) MATCH     (?>\s*) \} | \$ (?>\s*) \{\^MATCH\}     ) \z/oxmsgc) {
            if ($ignorecase) {
                $char[$i] = '@{[Ekoi8r::ignorecase(Ekoi8r::MATCH())]}';
            }
            else {
                $char[$i] = '@{[Ekoi8r::MATCH()]}';
            }
        }

        # $POSTMATCH, ${POSTMATCH}, ${^POSTMATCH} --> Ekoi8r::POSTMATCH()
        elsif ($char[$i] =~ /\A (                 \$ (?>\s*) POSTMATCH | \$ (?>\s*) \{ (?>\s*) POSTMATCH (?>\s*) \} | \$ (?>\s*) \{\^POSTMATCH\} ) \z/oxmsgc) {
            if ($ignorecase) {
                $char[$i] = '@{[Ekoi8r::ignorecase(Ekoi8r::POSTMATCH())]}';
            }
            else {
                $char[$i] = '@{[Ekoi8r::POSTMATCH()]}';
            }
        }

        # ${ foo }
        elsif ($char[$i] =~ /\A \$ (?>\s*) \{ ((?> \s* [A-Za-z_][A-Za-z0-9_]*(?: ::[A-Za-z_][A-Za-z0-9_]*)* \s* )) \}                              \z/oxms) {
            if ($ignorecase) {
                $char[$i] = '@{[Ekoi8r::ignorecase(' . $char[$i] . ')]}';
            }
        }

        # ${ ... }
        elsif ($char[$i] =~ /\A \$ (?>\s*) \{ ( .+ ) \} \z/oxms) {
            $char[$i] = e_capture($1);
            if ($ignorecase) {
                $char[$i] = '@{[Ekoi8r::ignorecase(' . $char[$i] . ')]}';
            }
        }

        # $scalar or @array
        elsif ($char[$i] =~ /\A [\$\@].+ /oxms) {
            $char[$i] = e_string($char[$i]);
            if ($ignorecase) {
                $char[$i] = '@{[Ekoi8r::ignorecase(' . $char[$i] . ')]}';
            }
        }

        # quote character before ? + * {
        elsif (($i >= 1) and ($char[$i] =~ /\A [\?\+\*\{] \z/oxms)) {
            if ($char[$i-1] =~ /\A (?:[\x00-\xFF]|\\[0-7]{2,3}|\\x[0-9-A-Fa-f]{1,2}) \z/oxms) {
            }
            else {
                $char[$i-1] = '(?:' . $char[$i-1] . ')';
            }
        }
    }

    # make regexp string
    my $prematch = '';
    $modifier =~ tr/i//d;
    if ($left_e > $right_e) {
        return join '', $ope, $delimiter, $prematch, '(?:', @char, '>]}' x ($left_e - $right_e), ')', $matched, $end_delimiter, $modifier;
    }
    return     join '', $ope, $delimiter, $prematch, '(?:', @char,                               ')', $matched, $end_delimiter, $modifier;
}

#
# escape regexp (s'here'' or s'here''b)
#
sub e_s1_q {
    my($ope,$delimiter,$end_delimiter,$string,$modifier) = @_;
    $modifier ||= '';

    $modifier =~ tr/p//d;
    if ($modifier =~ /([adlu])/oxms) {
        my $line = 0;
        for (my $i=0; my($package,$filename,$use_line,$subroutine) = caller($i); $i++) {
            if ($filename ne __FILE__) {
                $line = $use_line + (CORE::substr($_,0,pos($_)) =~ tr/\n//) + 1;
                last;
            }
        }
        die qq{Unsupported modifier "$1" used at line $line.\n};
    }

    $slash = 'div';

    # literal null string pattern
    if ($string eq '') {
        $modifier =~ tr/bB//d;
        $modifier =~ tr/i//d;
        return join '', $ope, $delimiter, $end_delimiter, $modifier;
    }

    # with /b /B modifier
    elsif ($modifier =~ tr/bB//d) {
        return e_s1_qb($ope,$delimiter,$end_delimiter,$string,$modifier);
    }

    # without /b /B modifier
    else {
        return e_s1_qt($ope,$delimiter,$end_delimiter,$string,$modifier);
    }
}

#
# escape regexp (s'here'')
#
sub e_s1_qt {
    my($ope,$delimiter,$end_delimiter,$string,$modifier) = @_;

    my $ignorecase = ($modifier =~ /i/oxms) ? 1 : 0;

    # split regexp
    my @char = $string =~ /\G((?>
        [^\\\[\$\@\/] |
        [\x00-\xFF] |
        \[\^                            |
        \[\:   (?>[a-z]+) \:\]          |
        \[\:\^ (?>[a-z]+) \:\]          |
        [\$\@\/]                        |
        \\     (?:$q_char)              |
               (?:$q_char)
    ))/oxmsg;

    # unescape character
    for (my $i=0; $i <= $#char; $i++) {
        if (0) {
        }

        # open character class [...]
        elsif ($char[$i] eq '[') {
            my $left = $i;
            if ($char[$i+1] eq ']') {
                $i++;
            }
            while (1) {
                if (++$i > $#char) {
                    die __FILE__, ": Unmatched [] in regexp\n";
                }
                if ($char[$i] eq ']') {
                    my $right = $i;

                    # [...]
                    splice @char, $left, $right-$left+1, Ekoi8r::charlist_qr(@char[$left+1..$right-1], $modifier);

                    $i = $left;
                    last;
                }
            }
        }

        # open character class [^...]
        elsif ($char[$i] eq '[^') {
            my $left = $i;
            if ($char[$i+1] eq ']') {
                $i++;
            }
            while (1) {
                if (++$i > $#char) {
                    die __FILE__, ": Unmatched [] in regexp\n";
                }
                if ($char[$i] eq ']') {
                    my $right = $i;

                    # [^...]
                    splice @char, $left, $right-$left+1, Ekoi8r::charlist_not_qr(@char[$left+1..$right-1], $modifier);

                    $i = $left;
                    last;
                }
            }
        }

        # escape $ @ / and \
        elsif ($char[$i] =~ /\A [\$\@\/\\] \z/oxms) {
            $char[$i] = '\\' . $char[$i];
        }

        # rewrite character class or escape character
        elsif (my $char = character_class($char[$i],$modifier)) {
            $char[$i] = $char;
        }

        # /i modifier
        elsif ($ignorecase and ($char[$i] =~ /\A [\x00-\xFF] \z/oxms) and (Ekoi8r::uc($char[$i]) ne Ekoi8r::fc($char[$i]))) {
            if (CORE::length(Ekoi8r::fc($char[$i])) == 1) {
                $char[$i] = '['   . Ekoi8r::uc($char[$i])       . Ekoi8r::fc($char[$i]) . ']';
            }
            else {
                $char[$i] = '(?:' . Ekoi8r::uc($char[$i]) . '|' . Ekoi8r::fc($char[$i]) . ')';
            }
        }

        # quote character before ? + * {
        elsif (($i >= 1) and ($char[$i] =~ /\A [\?\+\*\{] \z/oxms)) {
            if ($char[$i-1] =~ /\A [\x00-\xFF] \z/oxms) {
            }
            else {
                $char[$i-1] = '(?:' . $char[$i-1] . ')';
            }
        }
    }

    $modifier =~ tr/i//d;
    $delimiter     = '/';
    $end_delimiter = '/';
    my $prematch = '';
    return join '', $ope, $delimiter, $prematch, '(?:', @char, ')', $matched, $end_delimiter, $modifier;
}

#
# escape regexp (s'here''b)
#
sub e_s1_qb {
    my($ope,$delimiter,$end_delimiter,$string,$modifier) = @_;

    # split regexp
    my @char = $string =~ /\G (?>[^\\]|\\\\) /oxmsg;

    # unescape character
    for (my $i=0; $i <= $#char; $i++) {
        if (0) {
        }

        # remain \\
        elsif ($char[$i] eq '\\\\') {
        }

        # escape $ @ / and \
        elsif ($char[$i] =~ /\A [\$\@\/\\] \z/oxms) {
            $char[$i] = '\\' . $char[$i];
        }
    }

    $delimiter     = '/';
    $end_delimiter = '/';
    my $prematch = '';
    return join '', $ope, $delimiter, $prematch, '(?:', @char, ')', $matched, $end_delimiter, $modifier;
}

#
# escape regexp (s''here')
#
sub e_s2_q {
    my($ope,$delimiter,$end_delimiter,$string) = @_;

    $slash = 'div';

    my @char = $string =~ / \G (?>[^\\]|\\\\|$q_char) /oxmsg;
    for (my $i=0; $i <= $#char; $i++) {
        if (0) {
        }

        # not escape \\
        elsif ($char[$i] =~ /\A \\\\ \z/oxms) {
        }

        # escape $ @ / and \
        elsif ($char[$i] =~ /\A [\$\@\/\\] \z/oxms) {
            $char[$i] = '\\' . $char[$i];
        }
    }

    return join '', $ope, $delimiter, @char,   $end_delimiter;
}

#
# escape regexp (s/here/and here/modifier)
#
sub e_sub {
    my($variable,$delimiter1,$pattern,$end_delimiter1,$delimiter2,$replacement,$end_delimiter2,$modifier) = @_;
    $modifier ||= '';

    $modifier =~ tr/p//d;
    if ($modifier =~ /([adlu])/oxms) {
        my $line = 0;
        for (my $i=0; my($package,$filename,$use_line,$subroutine) = caller($i); $i++) {
            if ($filename ne __FILE__) {
                $line = $use_line + (CORE::substr($_,0,pos($_)) =~ tr/\n//) + 1;
                last;
            }
        }
        die qq{Unsupported modifier "$1" used at line $line.\n};
    }

    if ($variable eq '') {
        $variable      = '$_';
        $bind_operator = ' =~ ';
    }

    $slash = 'div';

    # P.128 Start of match (or end of previous match): \G
    # P.130 Advanced Use of \G with Perl
    # in Chapter 3: Overview of Regular Expression Features and Flavors
    # P.312 Iterative Matching: Scalar Context, with /g
    # in Chapter 7: Perl
    # of ISBN 0-596-00289-0 Mastering Regular Expressions, Second edition

    # P.181 Where You Left Off: The \G Assertion
    # in Chapter 5: Pattern Matching
    # of ISBN 0-596-00027-8 Programming Perl Third Edition.

    # P.220 Where You Left Off: The \G Assertion
    # in Chapter 5: Pattern Matching
    # of ISBN 978-0-596-00492-7 Programming Perl 4th Edition.

    my $e_modifier = $modifier =~ tr/e//d;
    my $r_modifier = $modifier =~ tr/r//d;

    my $my = '';
    if ($variable =~ s/\A \( (?>\s*) ( (?>(?: local \b | my \b | our \b | state \b )?) .+ ) \) \z/$1/oxms) {
        $my = $variable;
        $variable =~ s/ (?: local \b | my \b | our \b | state \b ) (?>\s*) //oxms;
        $variable =~ s/ = .+ \z//oxms;
    }

    (my $variable_basename = $variable) =~ s/ [\[\{].* \z//oxms;
    $variable_basename =~ s/ \s+ \z//oxms;

    # quote replacement string
    my $e_replacement = '';
    if ($e_modifier >= 1) {
        $e_replacement = e_qq('', '', '', $replacement);
        $e_modifier--;
    }
    else {
        if ($delimiter2 eq "'") {
            $e_replacement = e_s2_q('qq', '/',         '/',             $replacement);
        }
        else {
            $e_replacement = e_qq  ('qq', $delimiter2, $end_delimiter2, $replacement);
        }
    }

    my $sub = '';

    # with /r
    if ($r_modifier) {
        if (0) {
        }

        # s///gr without multibyte anchoring
        elsif ($modifier =~ /g/oxms) {
            $sub = sprintf(
                #                               1                         2   3                                  4   5
                q<CORE::eval{local $Ekoi8r::re_t=%s; while($Ekoi8r::re_t =~ %s){%s local $^W=0; local $Ekoi8r::re_r=%s; %s$Ekoi8r::re_t="$`$Ekoi8r::re_r$'"; pos($Ekoi8r::re_t)=length "$`$Ekoi8r::re_r"; } return $Ekoi8r::re_t}>,

                $variable,                                                       #  1
                ($delimiter1 eq "'") ?                                           #  2
                e_s1_q('m', $delimiter1, $end_delimiter1, $pattern, $modifier) : #  :
                e_s1  ('m', $delimiter1, $end_delimiter1, $pattern, $modifier),  #  :
                $s_matched,                                                      #  3
                $e_replacement,                                                  #  4
                '$Ekoi8r::re_r=CORE::eval $Ekoi8r::re_r; ' x $e_modifier,          #  5
            );
        }

        # s///r
        else {

            my $prematch = q{$`};

            $sub = sprintf(
                #  1     2                3                                  4   5  6                     7
                q<(%s =~ %s) ? CORE::eval{%s local $^W=0; local $Ekoi8r::re_r=%s; %s"%s$Ekoi8r::re_r$'" } : %s>,

                $variable,                                                       #  1
                ($delimiter1 eq "'") ?                                           #  2
                e_s1_q('m', $delimiter1, $end_delimiter1, $pattern, $modifier) : #  :
                e_s1  ('m', $delimiter1, $end_delimiter1, $pattern, $modifier),  #  :
                $s_matched,                                                      #  3
                $e_replacement,                                                  #  4
                '$Ekoi8r::re_r=CORE::eval $Ekoi8r::re_r; ' x $e_modifier,          #  5
                $prematch,                                                       #  6
                $variable,                                                       #  7
            );
        }

        # $var !~ s///r doesn't make sense
        if ($bind_operator =~ / !~ /oxms) {
            $sub = q{die("$0: Using !~ with s///r doesn't make sense"), } . $sub;
        }
    }

    # without /r
    else {
        if (0) {
        }

        # s///g without multibyte anchoring
        elsif ($modifier =~ /g/oxms) {
            $sub = sprintf(
                #                                        1     2   3                                  4   5 6                          7                                                   8
                q<CORE::eval{local $Ekoi8r::re_n=0; while(%s =~ %s){%s local $^W=0; local $Ekoi8r::re_r=%s; %s%s="$`$Ekoi8r::re_r$'"; pos(%s)=length "$`$Ekoi8r::re_r"; $Ekoi8r::re_n++} return %s$Ekoi8r::re_n}>,

                $variable,                                                       #  1
                ($delimiter1 eq "'") ?                                           #  2
                e_s1_q('m', $delimiter1, $end_delimiter1, $pattern, $modifier) : #  :
                e_s1  ('m', $delimiter1, $end_delimiter1, $pattern, $modifier),  #  :
                $s_matched,                                                      #  3
                $e_replacement,                                                  #  4
                '$Ekoi8r::re_r=CORE::eval $Ekoi8r::re_r; ' x $e_modifier,          #  5
                $variable,                                                       #  6
                $variable,                                                       #  7
                ($bind_operator =~ / !~ /oxms) ? '!' : '',                       #  8
            );
        }

        # s///
        else {

            my $prematch = q{$`};

            $sub = sprintf(

                ($bind_operator =~ / =~ /oxms) ?

                #  1 2 3                4                                  5   6 7   8
                q<(%s%s%s) ? CORE::eval{%s local $^W=0; local $Ekoi8r::re_r=%s; %s%s="%s$Ekoi8r::re_r$'"; 1 } : undef> :

                #  1 2 3                    4                                  5   6 7   8
                q<(%s%s%s) ? 1 : CORE::eval{%s local $^W=0; local $Ekoi8r::re_r=%s; %s%s="%s$Ekoi8r::re_r$'"; undef }>,

                $variable,                                                       #  1
                $bind_operator,                                                  #  2
                ($delimiter1 eq "'") ?                                           #  3
                e_s1_q('m', $delimiter1, $end_delimiter1, $pattern, $modifier) : #  :
                e_s1  ('m', $delimiter1, $end_delimiter1, $pattern, $modifier),  #  :
                $s_matched,                                                      #  4
                $e_replacement,                                                  #  5
                '$Ekoi8r::re_r=CORE::eval $Ekoi8r::re_r; ' x $e_modifier,          #  6
                $variable,                                                       #  7
                $prematch,                                                       #  8
            );
        }
    }

    # (my $foo = $bar) =~ s///   -->   (my $foo = $bar, CORE::eval { ... })[1]
    if ($my ne '') {
        $sub = "($my, $sub)[1]";
    }

    # clear s/// variable
    $sub_variable = '';
    $bind_operator = '';

    return $sub;
}

#
# escape regexp of split qr//
#
sub e_split {
    my($ope,$delimiter,$end_delimiter,$string,$modifier) = @_;
    $modifier ||= '';

    $modifier =~ tr/p//d;
    if ($modifier =~ /([adlu])/oxms) {
        my $line = 0;
        for (my $i=0; my($package,$filename,$use_line,$subroutine) = caller($i); $i++) {
            if ($filename ne __FILE__) {
                $line = $use_line + (CORE::substr($_,0,pos($_)) =~ tr/\n//) + 1;
                last;
            }
        }
        die qq{Unsupported modifier "$1" used at line $line.\n};
    }

    $slash = 'div';

    # /b /B modifier
    if ($modifier =~ tr/bB//d) {
        return join '', 'split', $ope, $delimiter, $string, $end_delimiter, $modifier;
    }

    my $ignorecase = ($modifier =~ /i/oxms) ? 1 : 0;
    my $metachar = qr/[\@\\|[\]{^]/oxms;

    # split regexp
    my @char = $string =~ /\G((?>
        [^\\\$\@\[\(] |
        \\x   (?>[0-9A-Fa-f]{1,2}) |
        \\    (?>[0-7]{2,3})       |
        \\c   [\x40-\x5F]          |
        \\x\{ (?>[0-9A-Fa-f]+) \}  |
        \\o\{ (?>[0-7]+)       \}  |
        \\[bBNpP]\{ (?>[^0-9\}][^\}]*) \} |
        \\  $q_char                |
        \$` | \$\{`\} | \$ (?>\s*) PREMATCH  | \$ (?>\s*) \{ (?>\s*) PREMATCH  (?>\s*) \} | \$ (?>\s*) \{\^PREMATCH\}  |
        \$& | \$\{&\} | \$ (?>\s*) MATCH     | \$ (?>\s*) \{ (?>\s*) MATCH     (?>\s*) \} | \$ (?>\s*) \{\^MATCH\}     |
                        \$ (?>\s*) POSTMATCH | \$ (?>\s*) \{ (?>\s*) POSTMATCH (?>\s*) \} | \$ (?>\s*) \{\^POSTMATCH\} |
        [\$\@] $qq_variable        |
        \$ (?>\s* [0-9]+)          |
        \$ (?>\s*) \{ (?>\s* [0-9]+ \s*) \}  |
        \$ \$ (?![\w\{])           |
        \$ (?>\s*) \$ (?>\s*) $qq_variable   |
        \[\^                       |
        \[\:   (?>[a-z]+) :\]      |
        \[\:\^ (?>[a-z]+) :\]      |
        \(\?                       |
            $q_char
    ))/oxmsg;

    my $left_e  = 0;
    my $right_e = 0;
    for (my $i=0; $i <= $#char; $i++) {

        # "\L\u" --> "\u\L"
        if (($char[$i] eq '\L') and ($char[$i+1] eq '\u')) {
            @char[$i,$i+1] = @char[$i+1,$i];
        }

        # "\U\l" --> "\l\U"
        elsif (($char[$i] eq '\U') and ($char[$i+1] eq '\l')) {
            @char[$i,$i+1] = @char[$i+1,$i];
        }

        # octal escape sequence
        elsif ($char[$i] =~ /\A \\o \{ ([0-7]+) \} \z/oxms) {
            $char[$i] = Ekoi8r::octchr($1);
        }

        # hexadecimal escape sequence
        elsif ($char[$i] =~ /\A \\x \{ ([0-9A-Fa-f]+) \} \z/oxms) {
            $char[$i] = Ekoi8r::hexchr($1);
        }

        # \b{...}      --> b\{...}
        # \B{...}      --> B\{...}
        # \N{CHARNAME} --> N\{CHARNAME}
        # \p{PROPERTY} --> p\{PROPERTY}
        # \P{PROPERTY} --> P\{PROPERTY}
        elsif ($char[$i] =~ /\A \\ ([bBNpP]) ( \{ ([^0-9\}][^\}]*) \} ) \z/oxms) {
            $char[$i] = $1 . '\\' . $2;
        }

        # \p, \P, \X --> p, P, X
        elsif ($char[$i] =~ /\A \\ ( [pPX] ) \z/oxms) {
            $char[$i] = $1;
        }

        if (0) {
        }

        # join separated multiple-octet
        elsif ($char[$i] =~ /\A (?: \\ [0-7]{2,3} | \\x [0-9A-Fa-f]{1,2}) \z/oxms) {
            if (   ($i+3 <= $#char) and (grep(/\A (?: \\ [0-7]{2,3} | \\x [0-9A-Fa-f]{1,2}) \z/oxms, @char[$i+1..$i+3]) == 3) and (CORE::eval(sprintf '"%s%s%s%s"', @char[$i..$i+3]) =~ /\A $q_char \z/oxms)) {
                $char[$i] .= join '', splice @char, $i+1, 3;
            }
            elsif (($i+2 <= $#char) and (grep(/\A (?: \\ [0-7]{2,3} | \\x [0-9A-Fa-f]{1,2}) \z/oxms, @char[$i+1..$i+2]) == 2) and (CORE::eval(sprintf '"%s%s%s"',   @char[$i..$i+2]) =~ /\A $q_char \z/oxms)) {
                $char[$i] .= join '', splice @char, $i+1, 2;
            }
            elsif (($i+1 <= $#char) and (grep(/\A (?: \\ [0-7]{2,3} | \\x [0-9A-Fa-f]{1,2}) \z/oxms, $char[$i+1      ]) == 1) and (CORE::eval(sprintf '"%s%s"',     @char[$i..$i+1]) =~ /\A $q_char \z/oxms)) {
                $char[$i] .= join '', splice @char, $i+1, 1;
            }
        }

        # open character class [...]
        elsif ($char[$i] eq '[') {
            my $left = $i;
            if ($char[$i+1] eq ']') {
                $i++;
            }
            while (1) {
                if (++$i > $#char) {
                    die __FILE__, ": Unmatched [] in regexp\n";
                }
                if ($char[$i] eq ']') {
                    my $right = $i;

                    # [...]
                    if (grep(/\A [\$\@]/oxms,@char[$left+1..$right-1]) >= 1) {
                        splice @char, $left, $right-$left+1, sprintf(q{@{[Ekoi8r::charlist_qr(%s,'%s')]}}, join(',', map {qq_stuff($delimiter,$end_delimiter,$_)} @char[$left+1..$right-1]), $modifier);
                    }
                    else {
                        splice @char, $left, $right-$left+1, Ekoi8r::charlist_qr(@char[$left+1..$right-1], $modifier);
                    }

                    $i = $left;
                    last;
                }
            }
        }

        # open character class [^...]
        elsif ($char[$i] eq '[^') {
            my $left = $i;
            if ($char[$i+1] eq ']') {
                $i++;
            }
            while (1) {
                if (++$i > $#char) {
                    die __FILE__, ": Unmatched [] in regexp\n";
                }
                if ($char[$i] eq ']') {
                    my $right = $i;

                    # [^...]
                    if (grep(/\A [\$\@]/oxms,@char[$left+1..$right-1]) >= 1) {
                        splice @char, $left, $right-$left+1, sprintf(q{@{[Ekoi8r::charlist_not_qr(%s,'%s')]}}, join(',', map {qq_stuff($delimiter,$end_delimiter,$_)} @char[$left+1..$right-1]), $modifier);
                    }
                    else {
                        splice @char, $left, $right-$left+1, Ekoi8r::charlist_not_qr(@char[$left+1..$right-1], $modifier);
                    }

                    $i = $left;
                    last;
                }
            }
        }

        # rewrite character class or escape character
        elsif (my $char = character_class($char[$i],$modifier)) {
            $char[$i] = $char;
        }

        # P.794 29.2.161. split
        # in Chapter 29: Functions
        # of ISBN 0-596-00027-8 Programming Perl Third Edition.

        # P.951 split
        # in Chapter 27: Functions
        # of ISBN 978-0-596-00492-7 Programming Perl 4th Edition.

        # said "The //m modifier is assumed when you split on the pattern /^/",
        # but perl5.008 is not so. Therefore, this software adds //m.
        # (and so on)

        # split(m/^/) --> split(m/^/m)
        elsif (($char[$i] eq '^') and ($modifier !~ /m/oxms)) {
            $modifier .= 'm';
        }

        # /i modifier
        elsif ($ignorecase and ($char[$i] =~ /\A [\x00-\xFF] \z/oxms) and (Ekoi8r::uc($char[$i]) ne Ekoi8r::fc($char[$i]))) {
            if (CORE::length(Ekoi8r::fc($char[$i])) == 1) {
                $char[$i] = '['   . Ekoi8r::uc($char[$i])       . Ekoi8r::fc($char[$i]) . ']';
            }
            else {
                $char[$i] = '(?:' . Ekoi8r::uc($char[$i]) . '|' . Ekoi8r::fc($char[$i]) . ')';
            }
        }

        # \u \l \U \L \F \Q \E
        elsif ($char[$i] =~ /\A ([<>]) \z/oxms) {
            if ($right_e < $left_e) {
                $char[$i] = '\\' . $char[$i];
            }
        }
        elsif ($char[$i] eq '\u') {
            $char[$i] = '@{[Ekoi8r::ucfirst qq<';
            $left_e++;
        }
        elsif ($char[$i] eq '\l') {
            $char[$i] = '@{[Ekoi8r::lcfirst qq<';
            $left_e++;
        }
        elsif ($char[$i] eq '\U') {
            $char[$i] = '@{[Ekoi8r::uc qq<';
            $left_e++;
        }
        elsif ($char[$i] eq '\L') {
            $char[$i] = '@{[Ekoi8r::lc qq<';
            $left_e++;
        }
        elsif ($char[$i] eq '\F') {
            $char[$i] = '@{[Ekoi8r::fc qq<';
            $left_e++;
        }
        elsif ($char[$i] eq '\Q') {
            $char[$i] = '@{[CORE::quotemeta qq<';
            $left_e++;
        }
        elsif ($char[$i] eq '\E') {
            if ($right_e < $left_e) {
                $char[$i] = '>]}';
                $right_e++;
            }
            else {
                $char[$i] = '';
            }
        }
        elsif ($char[$i] eq '\Q') {
            while (1) {
                if (++$i > $#char) {
                    last;
                }
                if ($char[$i] eq '\E') {
                    last;
                }
            }
        }
        elsif ($char[$i] eq '\E') {
        }

        # $0 --> $0
        elsif ($char[$i] =~ /\A \$ 0 \z/oxms) {
            if ($ignorecase) {
                $char[$i] = '@{[Ekoi8r::ignorecase(' . $char[$i] . ')]}';
            }
        }
        elsif ($char[$i] =~ /\A \$ \{ (?>\s*) 0 (?>\s*) \} \z/oxms) {
            if ($ignorecase) {
                $char[$i] = '@{[Ekoi8r::ignorecase(' . $char[$i] . ')]}';
            }
        }

        # $$ --> $$
        elsif ($char[$i] =~ /\A \$\$ \z/oxms) {
        }

        # $1, $2, $3 --> $2, $3, $4 after s/// with multibyte anchoring
        # $1, $2, $3 --> $1, $2, $3 otherwise
        elsif ($char[$i] =~ /\A \$ ((?>[1-9][0-9]*)) \z/oxms) {
            $char[$i] = e_capture($1);
            if ($ignorecase) {
                $char[$i] = '@{[Ekoi8r::ignorecase(' . $char[$i] . ')]}';
            }
        }
        elsif ($char[$i] =~ /\A \$ \{ (?>\s*) ((?>[1-9][0-9]*)) (?>\s*) \} \z/oxms) {
            $char[$i] = e_capture($1);
            if ($ignorecase) {
                $char[$i] = '@{[Ekoi8r::ignorecase(' . $char[$i] . ')]}';
            }
        }

        # $$foo[ ... ] --> $ $foo->[ ... ]
        elsif ($char[$i] =~ /\A \$ ((?> \$ [A-Za-z_][A-Za-z0-9_]*(?: ::[A-Za-z_][A-Za-z0-9_]*)* )) ( \[ (?:$qq_bracket)*? \] ) \z/oxms) {
            $char[$i] = e_capture($1.'->'.$2);
            if ($ignorecase) {
                $char[$i] = '@{[Ekoi8r::ignorecase(' . $char[$i] . ')]}';
            }
        }

        # $$foo{ ... } --> $ $foo->{ ... }
        elsif ($char[$i] =~ /\A \$ ((?> \$ [A-Za-z_][A-Za-z0-9_]*(?: ::[A-Za-z_][A-Za-z0-9_]*)* )) ( \{ (?:$qq_brace)*? \} ) \z/oxms) {
            $char[$i] = e_capture($1.'->'.$2);
            if ($ignorecase) {
                $char[$i] = '@{[Ekoi8r::ignorecase(' . $char[$i] . ')]}';
            }
        }

        # $$foo
        elsif ($char[$i] =~ /\A \$ ((?> \$ [A-Za-z_][A-Za-z0-9_]*(?: ::[A-Za-z_][A-Za-z0-9_]*)* )) \z/oxms) {
            $char[$i] = e_capture($1);
            if ($ignorecase) {
                $char[$i] = '@{[Ekoi8r::ignorecase(' . $char[$i] . ')]}';
            }
        }

        # $`, ${`}, $PREMATCH, ${PREMATCH}, ${^PREMATCH} --> Ekoi8r::PREMATCH()
        elsif ($char[$i] =~ /\A ( \$` | \$\{`\} | \$ (?>\s*) PREMATCH  | \$ (?>\s*) \{ (?>\s*) PREMATCH  (?>\s*) \} | \$ (?>\s*) \{\^PREMATCH\}  ) \z/oxmsgc) {
            if ($ignorecase) {
                $char[$i] = '@{[Ekoi8r::ignorecase(Ekoi8r::PREMATCH())]}';
            }
            else {
                $char[$i] = '@{[Ekoi8r::PREMATCH()]}';
            }
        }

        # $&, ${&}, $MATCH, ${MATCH}, ${^MATCH} --> Ekoi8r::MATCH()
        elsif ($char[$i] =~ /\A ( \$& | \$\{&\} | \$ (?>\s*) MATCH     | \$ (?>\s*) \{ (?>\s*) MATCH     (?>\s*) \} | \$ (?>\s*) \{\^MATCH\}     ) \z/oxmsgc) {
            if ($ignorecase) {
                $char[$i] = '@{[Ekoi8r::ignorecase(Ekoi8r::MATCH())]}';
            }
            else {
                $char[$i] = '@{[Ekoi8r::MATCH()]}';
            }
        }

        # $POSTMATCH, ${POSTMATCH}, ${^POSTMATCH} --> Ekoi8r::POSTMATCH()
        elsif ($char[$i] =~ /\A (                 \$ (?>\s*) POSTMATCH | \$ (?>\s*) \{ (?>\s*) POSTMATCH (?>\s*) \} | \$ (?>\s*) \{\^POSTMATCH\} ) \z/oxmsgc) {
            if ($ignorecase) {
                $char[$i] = '@{[Ekoi8r::ignorecase(Ekoi8r::POSTMATCH())]}';
            }
            else {
                $char[$i] = '@{[Ekoi8r::POSTMATCH()]}';
            }
        }

        # ${ foo }
        elsif ($char[$i] =~ /\A \$ (?>\s*) \{ ((?> \s* [A-Za-z_][A-Za-z0-9_]*(?: ::[A-Za-z_][A-Za-z0-9_]*)* \s* )) \}                            \z/oxms) {
            if ($ignorecase) {
                $char[$i] = '@{[Ekoi8r::ignorecase(' . $1 . ')]}';
            }
        }

        # ${ ... }
        elsif ($char[$i] =~ /\A \$ (?>\s*) \{ ( .+ ) \} \z/oxms) {
            $char[$i] = e_capture($1);
            if ($ignorecase) {
                $char[$i] = '@{[Ekoi8r::ignorecase(' . $char[$i] . ')]}';
            }
        }

        # $scalar or @array
        elsif ($char[$i] =~ /\A [\$\@].+ /oxms) {
            $char[$i] = e_string($char[$i]);
            if ($ignorecase) {
                $char[$i] = '@{[Ekoi8r::ignorecase(' . $char[$i] . ')]}';
            }
        }

        # quote character before ? + * {
        elsif (($i >= 1) and ($char[$i] =~ /\A [\?\+\*\{] \z/oxms)) {
            if ($char[$i-1] =~ /\A (?:[\x00-\xFF]|\\[0-7]{2,3}|\\x[0-9-A-Fa-f]{1,2}) \z/oxms) {
            }
            else {
                $char[$i-1] = '(?:' . $char[$i-1] . ')';
            }
        }
    }

    # make regexp string
    $modifier =~ tr/i//d;
    if ($left_e > $right_e) {
        return join '', 'Ekoi8r::split', $ope, $delimiter, @char, '>]}' x ($left_e - $right_e), $end_delimiter, $modifier;
    }
    return     join '', 'Ekoi8r::split', $ope, $delimiter, @char,                               $end_delimiter, $modifier;
}

#
# escape regexp of split qr''
#
sub e_split_q {
    my($ope,$delimiter,$end_delimiter,$string,$modifier) = @_;
    $modifier ||= '';

    $modifier =~ tr/p//d;
    if ($modifier =~ /([adlu])/oxms) {
        my $line = 0;
        for (my $i=0; my($package,$filename,$use_line,$subroutine) = caller($i); $i++) {
            if ($filename ne __FILE__) {
                $line = $use_line + (CORE::substr($_,0,pos($_)) =~ tr/\n//) + 1;
                last;
            }
        }
        die qq{Unsupported modifier "$1" used at line $line.\n};
    }

    $slash = 'div';

    # /b /B modifier
    if ($modifier =~ tr/bB//d) {
        return join '', 'split', $ope, $delimiter, $string, $end_delimiter, $modifier;
    }

    my $ignorecase = ($modifier =~ /i/oxms) ? 1 : 0;

    # split regexp
    my @char = $string =~ /\G((?>
        [^\\\[]       |
        [\x00-\xFF] |
        \[\^                            |
        \[\:   (?>[a-z]+) \:\]          |
        \[\:\^ (?>[a-z]+) \:\]          |
        \\     (?:$q_char)              |
               (?:$q_char)
    ))/oxmsg;

    # unescape character
    for (my $i=0; $i <= $#char; $i++) {
        if (0) {
        }

        # open character class [...]
        elsif ($char[$i] eq '[') {
            my $left = $i;
            if ($char[$i+1] eq ']') {
                $i++;
            }
            while (1) {
                if (++$i > $#char) {
                    die __FILE__, ": Unmatched [] in regexp\n";
                }
                if ($char[$i] eq ']') {
                    my $right = $i;

                    # [...]
                    splice @char, $left, $right-$left+1, Ekoi8r::charlist_qr(@char[$left+1..$right-1], $modifier);

                    $i = $left;
                    last;
                }
            }
        }

        # open character class [^...]
        elsif ($char[$i] eq '[^') {
            my $left = $i;
            if ($char[$i+1] eq ']') {
                $i++;
            }
            while (1) {
                if (++$i > $#char) {
                    die __FILE__, ": Unmatched [] in regexp\n";
                }
                if ($char[$i] eq ']') {
                    my $right = $i;

                    # [^...]
                    splice @char, $left, $right-$left+1, Ekoi8r::charlist_not_qr(@char[$left+1..$right-1], $modifier);

                    $i = $left;
                    last;
                }
            }
        }

        # rewrite character class or escape character
        elsif (my $char = character_class($char[$i],$modifier)) {
            $char[$i] = $char;
        }

        # split(m/^/) --> split(m/^/m)
        elsif (($char[$i] eq '^') and ($modifier !~ /m/oxms)) {
            $modifier .= 'm';
        }

        # /i modifier
        elsif ($ignorecase and ($char[$i] =~ /\A [\x00-\xFF] \z/oxms) and (Ekoi8r::uc($char[$i]) ne Ekoi8r::fc($char[$i]))) {
            if (CORE::length(Ekoi8r::fc($char[$i])) == 1) {
                $char[$i] = '['   . Ekoi8r::uc($char[$i])       . Ekoi8r::fc($char[$i]) . ']';
            }
            else {
                $char[$i] = '(?:' . Ekoi8r::uc($char[$i]) . '|' . Ekoi8r::fc($char[$i]) . ')';
            }
        }

        # quote character before ? + * {
        elsif (($i >= 1) and ($char[$i] =~ /\A [\?\+\*\{] \z/oxms)) {
            if ($char[$i-1] =~ /\A [\x00-\xFF] \z/oxms) {
            }
            else {
                $char[$i-1] = '(?:' . $char[$i-1] . ')';
            }
        }
    }

    $modifier =~ tr/i//d;
    return join '', 'Ekoi8r::split', $ope, $delimiter, @char, $end_delimiter, $modifier;
}

#
# instead of Carp::carp
#
sub carp {
    my($package,$filename,$line) = caller(1);
    print STDERR "@_ at $filename line $line.\n";
}

#
# instead of Carp::croak
#
sub croak {
    my($package,$filename,$line) = caller(1);
    print STDERR "@_ at $filename line $line.\n";
    die "\n";
}

#
# instead of Carp::cluck
#
sub cluck {
    my $i = 0;
    my @cluck = ();
    while (my($package,$filename,$line,$subroutine) = caller($i)) {
        push @cluck, "[$i] $filename($line) $package::$subroutine\n";
        $i++;
    }
    print STDERR CORE::reverse @cluck;
    print STDERR "\n";
    print STDERR @_;
}

#
# instead of Carp::confess
#
sub confess {
    my $i = 0;
    my @confess = ();
    while (my($package,$filename,$line,$subroutine) = caller($i)) {
        push @confess, "[$i] $filename($line) $package::$subroutine\n";
        $i++;
    }
    print STDERR CORE::reverse @confess;
    print STDERR "\n";
    print STDERR @_;
    die "\n";
}

1;

__END__

=pod

=head1 NAME

Ekoi8r - Run-time routines for KOI8R.pm

=head1 SYNOPSIS

  use Ekoi8r;

    Ekoi8r::split(...);
    Ekoi8r::tr(...);
    Ekoi8r::chop(...);
    Ekoi8r::index(...);
    Ekoi8r::rindex(...);
    Ekoi8r::lc(...);
    Ekoi8r::lc_;
    Ekoi8r::lcfirst(...);
    Ekoi8r::lcfirst_;
    Ekoi8r::uc(...);
    Ekoi8r::uc_;
    Ekoi8r::ucfirst(...);
    Ekoi8r::ucfirst_;
    Ekoi8r::fc(...);
    Ekoi8r::fc_;
    Ekoi8r::ignorecase(...);
    Ekoi8r::capture(...);
    Ekoi8r::chr(...);
    Ekoi8r::chr_;
    Ekoi8r::glob(...);
    Ekoi8r::glob_;

  # "no Ekoi8r;" not supported

=head1 ABSTRACT

This module has run-time routines for use KOI8R software automatically, you
do not have to use.

=head1 BUGS AND LIMITATIONS

I have tested and verified this software using the best of my ability.
However, a software containing much regular expression is bound to contain
some bugs. Thus, if you happen to find a bug that's in KOI8R software and not
your own program, you can try to reduce it to a minimal test case and then
report it to the following author's address. If you have an idea that could
make this a more useful tool, please let everyone share it.

=head1 HISTORY

This Ekoi8r module first appeared in ActivePerl Build 522 Built under
MSWin32 Compiled at Nov 2 1999 09:52:28

=head1 AUTHOR

INABA Hitoshi E<lt>ina@cpan.orgE<gt>

This project was originated by INABA Hitoshi.
For any questions, use E<lt>ina@cpan.orgE<gt> so we can share
this file.

=head1 LICENSE AND COPYRIGHT

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=head1 EXAMPLES

=over 2

=item * Split string

  @split = Ekoi8r::split(/pattern/,$string,$limit);
  @split = Ekoi8r::split(/pattern/,$string);
  @split = Ekoi8r::split(/pattern/);
  @split = Ekoi8r::split('',$string,$limit);
  @split = Ekoi8r::split('',$string);
  @split = Ekoi8r::split('');
  @split = Ekoi8r::split();
  @split = Ekoi8r::split;

  This subroutine scans a string given by $string for separators, and splits the
  string into a list of substring, returning the resulting list value in list
  context or the count of substring in scalar context. Scalar context also causes
  split to write its result to @_, but this usage is deprecated. The separators
  are determined by repeated pattern matching, using the regular expression given
  in /pattern/, so the separators may be of any size and need not be the same
  string on every match. (The separators are not ordinarily returned; exceptions
  are discussed later in this section.) If the /pattern/ doesn't match the string
  at all, Ekoi8r::split returns the original string as a single substring, If it
  matches once, you get two substrings, and so on. You may supply regular
  expression modifiers to the /pattern/, like /pattern/i, /pattern/x, etc. The
  //m modifier is assumed when you split on the pattern /^/.

  If $limit is specified and positive, the subroutine splits into no more than that
  many fields (though it may split into fewer if it runs out of separators). If
  $limit is negative, it is treated as if an arbitrarily large $limit has been
  specified If $limit is omitted or zero, trailing null fields are stripped from
  the result (which potential users of pop would do wel to remember). If $string
  is omitted, the subroutine splits the $_ string. If /pattern/ is also omitted or
  is the literal space, " ", the subroutine split on whitespace, /\s+/, after
  skipping any leading whitespace.

  A /pattern/ of /^/ is secretly treated if it it were /^/m, since it isn't much
  use otherwise.

  String of any length can be split:

  @chars  = Ekoi8r::split(//,  $word);
  @fields = Ekoi8r::split(/:/, $line);
  @words  = Ekoi8r::split(" ", $paragraph);
  @lines  = Ekoi8r::split(/^/, $buffer);

  A pattern capable of matching either the null string or something longer than
  the null string (for instance, a pattern consisting of any single character
  modified by a * or ?) will split the value of $string into separate characters
  wherever it matches the null string between characters; nonnull matches will
  skip over the matched separator characters in the usual fashion. (In other words,
  a pattern won't match in one spot more than once, even if it matched with a zero
  width.) For example:

  print join(":" => Ekoi8r::split(/ */, "hi there"));

  produces the output "h:i:t:h:e:r:e". The space disappers because it matches
  as part of the separator. As a trivial case, the null pattern // simply splits
  into separate characters, and spaces do not disappear. (For normal pattern
  matches, a // pattern would repeat the last successfully matched pattern, but
  Ekoi8r::split's pattern is exempt from that wrinkle.)

  The $limit parameter splits only part of a string:

  my ($login, $passwd, $remainder) = Ekoi8r::split(/:/, $_, 3);

  We encourage you to split to lists of names like this to make your code
  self-documenting. (For purposes of error checking, note that $remainder would
  be undefined if there were fewer than three fields.) When assigning to a list,
  if $limit is omitted, Perl supplies a $limit one larger than the number of
  variables in the list, to avoid unneccessary work. For the split above, $limit
  would have been 4 by default, and $remainder would have received only the third
  field, not all the rest of the fields. In time-critical applications, it behooves
  you not to split into more fields than you really need. (The trouble with
  powerful languages it that they let you be powerfully stupid at times.)

  We said earlier that the separators are not returned, but if the /pattern/
  contains parentheses, then the substring matched by each pair of parentheses is
  included in the resulting list, interspersed with the fields that are ordinarily
  returned. Here's a simple example:

  Ekoi8r::split(/([-,])/, "1-10,20");

  which produces the list value:

  (1, "-", 10, ",", 20)

  With more parentheses, a field is returned for each pair, even if some pairs
  don't match, in which case undefined values are returned in those positions. So
  if you say:

  Ekoi8r::split(/(-)|(,)/, "1-10,20");

  you get the value:

  (1, "-", undef, 10, undef, ",", 20)

  The /pattern/ argument may be replaced with an expression to specify patterns
  that vary at runtime. As with ordinary patterns, to do run-time compilation only
  once, use /$variable/o.

  As a special case, if the expression is a single space (" "), the subroutine
  splits on whitespace just as Ekoi8r::split with no arguments does. Thus,
  Ekoi8r::split(" ") can be used to emulate awk's default behavior. In contrast,
  Ekoi8r::split(/ /) will give you as many null initial fields as there are
  leading spaces. (Other than this special case, if you supply a string instead
  of a regular expression, it'll be interpreted as a regular expression anyway.)
  You can use this property to remove leading and trailing whitespace from a
  string and to collapse intervaning stretches of whitespace into a single
  space:

  $string = join(" ", Ekoi8r::split(" ", $string));

  The following example splits an RFC822 message header into a hash containing
  $head{'Date'}, $head{'Subject'}, and so on. It uses the trick of assigning a
  list of pairs to a hash, because separators altinate with separated fields, It
  users parentheses to return part of each separator as part of the returned list
  value. Since the split pattern is guaranteed to return things in pairs by virtue
  of containing one set of parentheses, the hash assignment is guaranteed to
  receive a list consisting of key/value pairs, where each key is the name of a
  header field. (Unfortunately, this technique loses information for multiple lines
  with the same key field, such as Received-By lines. Ah well)

  $header =~ s/\n\s+/ /g; # Merge continuation lines.
  %head = ("FRONTSTUFF", Ekoi8r::split(/^(\S*?):\s*/m, $header));

  The following example processes the entries in a Unix passwd(5) file. You could
  leave out the chomp, in which case $shell would have a newline on the end of it.

  open(PASSWD, "/etc/passwd");
  while (<PASSWD>) {
      chomp; # remove trailing newline.
      ($login, $passwd, $uid, $gid, $gcos, $home, $shell) =
          Ekoi8r::split(/:/);
      ...
  }

  Here's how process each word of each line of each file of input to create a
  word-frequency hash.

  while (<>) {
      for my $word (Ekoi8r::split()) {
          $count{$word}++;
      }
  }

  The inverse of Ekoi8r::split is join, except that join can only join with the
  same separator between all fields. To break apart a string with fixed-position
  fields, use unpack.

  Processing long $string (over 32766 octets) requires Perl 5.010001 or later.

=item * Transliteration

  $tr = Ekoi8r::tr($variable,$bind_operator,$searchlist,$replacementlist,$modifier);
  $tr = Ekoi8r::tr($variable,$bind_operator,$searchlist,$replacementlist);

  This is the transliteration (sometimes erroneously called translation) operator,
  which is like the y/// operator in the Unix sed program, only better, in
  everybody's humble opinion.

  This subroutine scans a KOI8-R string character by character and replaces all
  occurrences of the characters found in $searchlist with the corresponding character
  in $replacementlist. It returns the number of characters replaced or deleted.
  If no KOI8-R string is specified via =~ operator, the $_ variable is translated.
  $modifier are:

  ---------------------------------------------------------------------------
  Modifier   Meaning
  ---------------------------------------------------------------------------
  c          Complement $searchlist.
  d          Delete found but unreplaced characters.
  s          Squash duplicate replaced characters.
  r          Return transliteration and leave the original string untouched.
  ---------------------------------------------------------------------------

  To use with a read-only value without raising an exception, use the /r modifier.

  print Ekoi8r::tr('bookkeeper','=~','boep','peob','r'); # prints 'peekkoobor'

=item * Chop string

  $chop = Ekoi8r::chop(@list);
  $chop = Ekoi8r::chop();
  $chop = Ekoi8r::chop;

  This subroutine chops off the last character of a string variable and returns the
  character chopped. The Ekoi8r::chop subroutine is used primary to remove the newline
  from the end of an input recoed, and it is more efficient than using a
  substitution. If that's all you're doing, then it would be safer to use chomp,
  since Ekoi8r::chop always shortens the string no matter what's there, and chomp
  is more selective. If no argument is given, the subroutine chops the $_ variable.

  You cannot Ekoi8r::chop a literal, only a variable. If you Ekoi8r::chop a list of
  variables, each string in the list is chopped:

  @lines = `cat myfile`;
  Ekoi8r::chop(@lines);

  You can Ekoi8r::chop anything that is an lvalue, including an assignment:

  Ekoi8r::chop($cwd = `pwd`);
  Ekoi8r::chop($answer = <STDIN>);

  This is different from:

  $answer = Ekoi8r::chop($tmp = <STDIN>); # WRONG

  which puts a newline into $answer because Ekoi8r::chop returns the character
  chopped, not the remaining string (which is in $tmp). One way to get the result
  intended here is with substr:

  $answer = substr <STDIN>, 0, -1;

  But this is more commonly written as:

  Ekoi8r::chop($answer = <STDIN>);

  In the most general case, Ekoi8r::chop can be expressed using substr:

  $last_code = Ekoi8r::chop($var);
  $last_code = substr($var, -1, 1, ""); # same thing

  Once you understand this equivalence, you can use it to do bigger chops. To
  Ekoi8r::chop more than one character, use substr as an lvalue, assigning a null
  string. The following removes the last five characters of $caravan:

  substr($caravan, -5) = '';

  The negative subscript causes substr to count from the end of the string instead
  of the beginning. To save the removed characters, you could use the four-argument
  form of substr, creating something of a quintuple Ekoi8r::chop;

  $tail = substr($caravan, -5, 5, '');

  This is all dangerous business dealing with characters instead of graphemes. Perl
  doesn't really have a grapheme mode, so you have to deal with them yourself.

=item * Index string

  $byte_pos = Ekoi8r::index($string,$substr,$byte_offset);
  $byte_pos = Ekoi8r::index($string,$substr);

  This subroutine searches for one string within another. It returns the byte position
  of the first occurrence of $substring in $string. The $byte_offset, if specified,
  says how many bytes from the start to skip before beginning to look. Positions are
  based at 0. If the substring is not found, the subroutine returns one less than the
  base, ordinarily -1. To work your way through a string, you might say:

  $byte_pos = -1;
  while (($byte_pos = Ekoi8r::index($string, $lookfor, $byte_pos)) > -1) {
      print "Found at $byte_pos\n";
      $byte_pos++;
  }

=item * Reverse index string

  $byte_pos = Ekoi8r::rindex($string,$substr,$byte_offset);
  $byte_pos = Ekoi8r::rindex($string,$substr);

  This subroutine works just like Ekoi8r::index except that it returns the byte
  position of the last occurrence of $substring in $string (a reverse Ekoi8r::index).
  The subroutine returns -1 if $substring is not found. $byte_offset, if specified,
  is the rightmost byte position that may be returned. To work your way through a
  string backward, say:

  $byte_pos = length($string);
  while (($byte_pos = KOI8R::rindex($string, $lookfor, $byte_pos)) >= 0) {
      print "Found at $byte_pos\n";
      $byte_pos--;
  }

=item * Lower case string

  $lc = Ekoi8r::lc($string);
  $lc = Ekoi8r::lc_;

  This subroutine returns a lowercased version of KOI8-R $string (or $_, if
  $string is omitted). This is the internal subroutine implementing the \L escape
  in double-quoted strings.

  You can use the Ekoi8r::fc subroutine for case-insensitive comparisons via KOI8R
  software.

=item * Lower case first character of string

  $lcfirst = Ekoi8r::lcfirst($string);
  $lcfirst = Ekoi8r::lcfirst_;

  This subroutine returns a version of KOI8-R $string with the first character
  lowercased (or $_, if $string is omitted). This is the internal subroutine
  implementing the \l escape in double-quoted strings.

=item * Upper case string

  $uc = Ekoi8r::uc($string);
  $uc = Ekoi8r::uc_;

  This subroutine returns an uppercased version of KOI8-R $string (or $_, if
  $string is omitted). This is the internal subroutine implementing the \U escape
  in interpolated strings. For titlecase, use Ekoi8r::ucfirst instead.

  You can use the Ekoi8r::fc subroutine for case-insensitive comparisons via KOI8R
  software.

=item * Upper case first character of string

  $ucfirst = Ekoi8r::ucfirst($string);
  $ucfirst = Ekoi8r::ucfirst_;

  This subroutine returns a version of KOI8-R $string with the first character
  titlecased and other characters left alone (or $_, if $string is omitted).
  Titlecase is "Camel" for an initial capital that has (or expects to have)
  lowercase characters following it, not uppercase ones. Exsamples are the first
  letter of a sentence, of a person's name, of a newspaper headline, or of most
  words in a title. Characters with no titlecase mapping return the uppercase
  mapping instead. This is the internal subroutine implementing the \u escape in
  double-quoted strings.

  To capitalize a string by mapping its first character to titlecase and the rest
  to lowercase, use:

  $titlecase = Ekoi8r::ucfirst(substr($word,0,1)) . Ekoi8r::lc(substr($word,1));

  or

  $string =~ s/(\w)((?>\w*))/\u$1\L$2/g;

  Do not use:

  $do_not_use = Ekoi8r::ucfirst(Ekoi8r::lc($word));

  or "\u\L$word", because that can produce a different and incorrect answer with
  certain characters. The titlecase of something that's been lowercased doesn't
  always produce the same thing titlecasing the original produces.

  Because titlecasing only makes sense at the start of a string that's followed
  by lowercase characters, we can't think of any reason you might want to titlecase
  every character in a string.

  See also P.287 A Case of Mistaken Identity
  in Chapter 6: Unicode
  of ISBN 978-0-596-00492-7 Programming Perl 4th Edition.

=item * Fold case string

  P.860 fc
  in Chapter 27: Functions
  of ISBN 978-0-596-00492-7 Programming Perl 4th Edition.

  $fc = Ekoi8r::fc($string);
  $fc = Ekoi8r::fc_;

  New to KOI8R software, this subroutine returns the full Unicode-like casefold of
  KOI8-R $string (or $_, if omitted). This is the internal subroutine implementing
  the \F escape in double-quoted strings.

  Just as title-case is based on uppercase but different, foldcase is based on
  lowercase but different. In ASCII there is a one-to-one mapping between only
  two cases, but in other encoding there is a one-to-many mapping and between three
  cases. Because that's too many combinations to check manually each time, a fourth
  casemap called foldcase was invented as a common intermediary for the other three.
  It is not a case itself, but it is a casemap.

  To compare whether two strings are the same without regard to case, do this:

  Ekoi8r::fc($a) eq Ekoi8r::fc($b)

  The reliable way to compare string case-insensitively was with the /i pattern
  modifier, because KOI8R software has always used casefolding semantics for
  case-insensitive pattern matches. Knowing this, you can emulate equality
  comparisons like this:

  sub fc_eq ($$) {
      my($a,$b) = @_;
      return $a =~ /\A\Q$b\E\z/i;
  }

=item * Make ignore case string

  @ignorecase = Ekoi8r::ignorecase(@string);

  This subroutine is internal use to m/ /i, s/ / /i, split / /i, and qr/ /i.

=item * Make capture number

  $capturenumber = Ekoi8r::capture($string);

  This subroutine is internal use to m/ /, s/ / /, split / /, and qr/ /.

=item * Make character

  $chr = Ekoi8r::chr($code);
  $chr = Ekoi8r::chr_;

  This subroutine returns a programmer-visible character, character represented by
  that $code in the character set. For example, Ekoi8r::chr(65) is "A" in either
  ASCII or KOI8-R, not Unicode. For the reverse of Ekoi8r::chr, use KOI8R::ord.

=item * Filename expansion (globbing)

  @glob = Ekoi8r::glob($string);
  @glob = Ekoi8r::glob_;

  This subroutine returns the value of $string with filename expansions the way a
  DOS-like shell would expand them, returning the next successive name on each
  call. If $string is omitted, $_ is globbed instead. This is the internal
  subroutine implementing the <*> and glob operator.
  This subroutine function when the pathname ends with chr(0x5C) on MSWin32.

  For ease of use, the algorithm matches the DOS-like shell's style of expansion,
  not the UNIX-like shell's. An asterisk ("*") matches any sequence of any
  character (including none). A question mark ("?") matches any one character or
  none. A tilde ("~") expands to a home directory, as in "~/.*rc" for all the
  current user's "rc" files, or "~jane/Mail/*" for all of Jane's mail files.

  Note that all path components are case-insensitive, and that backslashes and
  forward slashes are both accepted, and preserved. You may have to double the
  backslashes if you are putting them in literally, due to double-quotish parsing
  of the pattern by perl.

  The Ekoi8r::glob subroutine grandfathers the use of whitespace to separate multiple
  patterns such as <*.c *.h>. If you want to glob filenames that might contain
  whitespace, you'll have to use extra quotes around the spacy filename to protect
  it. For example, to glob filenames that have an "e" followed by a space followed
  by an "f", use either of:

  @spacies = <"*e f*">;
  @spacies = Ekoi8r::glob('"*e f*"');
  @spacies = Ekoi8r::glob(q("*e f*"));

  If you had to get a variable through, you could do this:

  @spacies = Ekoi8r::glob("'*${var}e f*'");
  @spacies = Ekoi8r::glob(qq("*${var}e f*"));

  Another way on MSWin32

  # relative path
  @relpath_file = split(/\n/,`dir /b wildcard\\here*.txt 2>NUL`);

  # absolute path
  @abspath_file = split(/\n/,`dir /s /b wildcard\\here*.txt 2>NUL`);

  # on COMMAND.COM
  @relpath_file = split(/\n/,`dir /b wildcard\\here*.txt`);
  @abspath_file = split(/\n/,`dir /s /b wildcard\\here*.txt`);

=back

=cut
