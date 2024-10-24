use strict;
use warnings;
use utf8;
use Test::More;

BEGIN {
    for (grep /^GETOPTEX|^(COLORTERM|NO_COLOR)$/, keys %ENV) {
	delete $ENV{$_};
    }
}

use Getopt::EX::Colormap qw(colorize colorize24 ansi_code);

use constant {
    RESET => "\e[m\e[K",
};

sub rgb24(&) {
    my $sub = shift;
    local $Getopt::EX::Colormap::RGB24 = 1;
    $sub->();
}

is(colorize("N", "text"), "text", "N - NOP");
is(colorize(";", "text"), "text", "; - NOP");

is(colorize("R", "text"), "\e[31m"."text".RESET, "colorize");

is(colorize("ABCDEF", "text"), "\e[38;5;153m"."text".RESET, "colorize24");

is(colorize24("ABCDEF", "text"), "\e[38;2;171;205;239m"."text".RESET, "colorize24");

{
    my $text = colorize("R", "AB") . "CD" . colorize("R", "EF");
    my $rslt = colorize("R", "AB") . colorize("B", "CD") . colorize("R", "EF");
    is(colorize("B", $text), $rslt, "nested");
}

{
    my $text = "AB" . colorize("B", "CD") . "EF";
    my $rslt = colorize("R", "AB") . colorize("B", "CD") . colorize("R", "EF");
    is(colorize("R", $text), $rslt, "nested 2");
}

{
    my $text = colorize("R", "ABCDEF");
    is(colorize("B", $text), $text, "nested/unchange");
}

TODO: {

local $TODO = "\$RGB24 does not update cached data.";

local $Getopt::EX::Colormap::RGB24 = 1;
is(colorize("ABCDEF", "text"), "\e[38;2;171;205;239m"."text".RESET, "colorize (RGB24=1)");

}

{

local $Getopt::EX::Colormap::LINEAR256 = 1;

is(ansi_code("R"), "\e[31m", "color name");
is(ansi_code("W/R"), "\e[37;41m", "background");
{
    local $Getopt::EX::Colormap::SPLIT_ANSI = 1;
    is(ansi_code("W/R"), "\e[37m\e[41m", "background (SPLIT_ANSI)");
}
is(ansi_code("RDPIUFQSHX"), "\e[31;1;2;3;4;5;6;7;8;9m", "effect");

is(ansi_code("ABCDEF"), "\e[38;5;152m", "hex24");
rgb24 {
    is(ansi_code("ABCDEF"), "\e[38;2;171;205;239m", "hex24 24bit");
};

is(ansi_code("~D~P~I~U~F~Q~S~H~X"), "\e[21;22;23;24;25;26;27;28;29m", "negate effect");

is(ansi_code("#AABBCC"), "\e[38;5;146m", "hex24 with #");
is(ansi_code("#ABC"),    "\e[38;5;146m", "hex12");
rgb24 {
    is(ansi_code("#AABBCC"), "\e[38;2;170;187;204m", "hex24 24bit");
    is(ansi_code("#ABC"),    "\e[38;2;170;187;204m", "hex12 24bit");
};

is(ansi_code("(171,205,239)"), "\e[38;5;152m", "rgb");
rgb24 {
    is(ansi_code("(171,205,239)"), "\e[38;2;171;205;239m", "rgb 24bit");
    is(ansi_code("(1,2,3)"), "\e[38;2;1;2;3m", "rgb 24bit");
};

}


is(ansi_code("EE334E"), "\e[38;5;197m", "hex24 (DeePink2)");
is(ansi_code("ABCDEF"), "\e[38;5;153m", "hex24");
is(ansi_code("#AABBCC"), "\e[38;5;146m", "hex24 with #");
is(ansi_code("#ABC"),    "\e[38;5;146m", "hex12");
is(ansi_code("(171,205,239)"), "\e[38;5;153m", "rgb");

is(ansi_code("#AAABBBCCC"), "\e[38;5;146m", "hex36 with #");
is(ansi_code("#AAAABBBBCCCC"), "\e[38;5;146m", "hex48 with #");


is(ansi_code("DK/544"), "\e[1;30;48;5;224m", "256 color");
is(ansi_code("//DK///544"), "\e[1;30;48;5;224m", "multiple /");
is(ansi_code("L25/L00"), "\e[38;5;231;48;5;16m", "L25/L00 == 555/000");
is(ansi_code("L01/L24"), "\e[38;5;232;48;5;255m", "grey scale");
if ($Getopt::EX::Colormap::LINEAR_GREY) {
    is(ansi_code("CCCCCC"), "\e[38;5;251m", "hex to grey scale map");
} else {
    is(ansi_code("CCCCCC"), "\e[38;5;252m", "hex to grey scale map");
}
is(ansi_code("FFFFFF/000000"), "\e[38;5;231;48;5;16m", "hex, all 0/1");

is(ansi_code("DK/544E"), "\e[1;30;48;5;224m" . "\e[K", "E");
is(ansi_code("DK/544{EL}"), "\e[1;30;48;5;224m" . "\e[K", "{EL}");
is(ansi_code("DK/E544"), "\e[1;30m"."\e[K"."\e[48;5;224m" , "E");
is(ansi_code("DK/{EL}544"), "\e[1;30m"."\e[K"."\e[48;5;224m" , "{EL}");
is(ansi_code("{SGR}"), "\e[m", "{SGR}");
is(ansi_code("{SGR1;30;48;5;224}"), "\e[1;30;48;5;224m", "{SGR...}");
is(ansi_code("{SGR(1,30,48,5,224)}"), "\e[1;30;48;5;224m", "{SGR(...)}");

like(ansi_end("DK/544E"), qr/^\e\[?K/, "E before RESET");
like(ansi_end("DK/544{EL}"), qr/^\e\[?K/, "{EL} before RESET");

SKIP: {
    eval {
	is(ansi_code("<moccasin>"), "\e\[38;5;223m",
	   "color name (<moccasin>)");
    };
    skip $@ =~ s/\)\K.*//r if $@;
}

SKIP: {
    eval {
	rgb24 {
	    is(ansi_code("<moccasin>"), "\e[38;2;255;228;181m",
	       "<moccasin> 24bit");
	};
    };
    skip $@ =~ s/\)\K.*//r if $@;
}

SKIP: {
    eval {
	is(ansi_code("<fuchsia>"), "\e\[38;5;201m", "color name (<fuchsia>)");
    };
    skip $@ =~ s/\)\K.*//r, 1 if $@;
}

SKIP: {
    eval {
	is(ansi_code("<fuscia>"), "\e\[38;5;201m", "color name (<fuscia>)");
    };
    skip $@ =~ s/\)\K.*//r, 1 if $@;
}

done_testing;

sub ansi_end {
    my $color = shift;
    my($s, $e) = Getopt::EX::Colormap::ansi_pair($color);
    $e;
}
