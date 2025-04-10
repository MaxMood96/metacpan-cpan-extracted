package Ascii::Text::Font::Standard;
use strict;
use warnings;
use Rope;
use Rope::Autoload;

# Standard by Glenn Chappell & Ian Chai 3/93 -- based on Frank's .sig

extends 'Ascii::Text::Font';

property character_height => (
	initable  => 0,
	writeable => 0,
	value     => 6
);

function space => sub {
	my (@character) = $_[0]->default_character(7);
	return \@character;
};

function character_A => sub {
	my @character = $_[0]->default_character(10);
	$character[1][4] = $character[2][3] = $character[3][2] = $character[4][1]
	    = $character[4][3] = "\/";
	$character[0][5] = $character[2][5] = $character[3][4] = $character[3][5]
	    = $character[3][6] = $character[4][2] = $character[4][8] = "_";
	$character[1][6] = $character[2][7] = $character[3][8] = $character[4][7]
	    = $character[4][9] = "\\";
	return \@character;
};

function character_B => sub {
	my @character = $_[0]->default_character(8);
	$character[2][6] = "\\";
	$character[0][2] = $character[0][3] = $character[0][4] = $character[0][5]
	    = $character[1][3] = $character[1][4] = $character[2][4]
	    = $character[3][4] = $character[4][2] = $character[4][3]
	    = $character[4][4] = $character[4][5] = "_";
	$character[1][6] = $character[3][5] = "\)";
	$character[1][1] = $character[2][1] = $character[3][1] = $character[3][3]
	    = $character[3][7] = $character[4][1] = "\|";
	$character[4][6] = "\/";
	return \@character;
};

function character_C => sub {
	my @character = $_[0]->default_character(8);
	$character[0][3] = $character[0][4] = $character[0][5] = $character[0][6]
	    = $character[1][4] = $character[1][5] = $character[1][6]
	    = $character[3][4] = $character[3][5] = $character[3][6]
	    = $character[4][3] = $character[4][4] = $character[4][5]
	    = $character[4][6] = "_";
	$character[4][2] = "\\";
	$character[1][2] = "\/";
	$character[1][7] = $character[2][1] = $character[2][3] = $character[3][1]
	    = $character[3][3] = $character[4][7] = "\|";
	return \@character;
};

function character_D => sub {
	my @character = $_[0]->default_character(8);
	$character[1][1] = $character[2][1] = $character[2][3] = $character[2][5]
	    = $character[2][7] = $character[3][1] = $character[3][3]
	    = $character[3][5] = $character[3][7] = $character[4][1] = "\|";
	$character[4][6] = "\/";
	$character[1][6] = "\\";
	$character[0][2] = $character[0][3] = $character[0][4] = $character[0][5]
	    = $character[1][4] = $character[3][4] = $character[4][2]
	    = $character[4][3] = $character[4][4] = $character[4][5] = "_";
	return \@character;
};

function character_E => sub {
	my @character = $_[0]->default_character(8);
	$character[0][2] = $character[0][3] = $character[0][4] = $character[0][5]
	    = $character[0][6] = $character[1][3] = $character[1][4]
	    = $character[1][5] = $character[1][6] = $character[2][4]
	    = $character[3][4] = $character[3][5] = $character[3][6]
	    = $character[4][2] = $character[4][3] = $character[4][4]
	    = $character[4][5] = $character[4][6] = "_";
	$character[1][1] = $character[1][7] = $character[2][1] = $character[2][5]
	    = $character[3][1] = $character[3][3] = $character[4][1]
	    = $character[4][7] = "\|";
	return \@character;
};

function character_F => sub {
	my @character = $_[0]->default_character(8);
	$character[1][1] = $character[1][7] = $character[2][1] = $character[2][3]
	    = $character[3][1] = $character[3][5] = $character[4][1]
	    = $character[4][3] = "\|";
	$character[0][2] = $character[0][3] = $character[0][4] = $character[0][5]
	    = $character[0][6] = $character[1][4] = $character[1][5]
	    = $character[1][6] = $character[2][4] = $character[3][4]
	    = $character[4][2] = "_";
	return \@character;
};

function character_G => sub {
	my @character = $_[0]->default_character(8);
	$character[0][3] = $character[0][4] = $character[0][5] = $character[0][6]
	    = $character[1][4] = $character[1][5] = $character[1][6]
	    = $character[2][6] = $character[3][4] = $character[4][3]
	    = $character[4][4] = $character[4][5] = $character[4][6] = "_";
	$character[4][2] = "\\";
	$character[1][2] = "\/";
	$character[1][7] = $character[2][1] = $character[2][3] = $character[3][1]
	    = $character[3][3] = $character[3][5] = $character[3][7]
	    = $character[4][7] = "\|";
	return \@character;
};

function character_H => sub {
	my @character = $_[0]->default_character(8);
	$character[1][1] = $character[1][3] = $character[1][5] = $character[1][7]
	    = $character[2][1] = $character[2][3] = $character[2][5]
	    = $character[2][7] = $character[3][1] = $character[3][7]
	    = $character[4][1] = $character[4][3] = $character[4][5]
	    = $character[4][7] = "\|";
	$character[0][2] = $character[0][6] = $character[2][4] = $character[3][4]
	    = $character[4][2] = $character[4][6] = "_";
	return \@character;
};

function character_I => sub {
	my @character = $_[0]->default_character(6);
	$character[1][1] = $character[1][5] = $character[2][2] = $character[2][4]
	    = $character[3][2] = $character[3][4] = $character[4][1]
	    = $character[4][5] = "\|";
	$character[0][2] = $character[0][3] = $character[0][4] = $character[1][2]
	    = $character[1][4] = $character[4][2] = $character[4][3]
	    = $character[4][4] = "_";
	return \@character;
};

function character_J => sub {
	my @character = $_[0]->default_character(8);
	$character[4][6] = "\/";
	$character[1][5] = $character[1][7] = $character[2][5] = $character[2][7]
	    = $character[3][1] = $character[3][3] = $character[3][5]
	    = $character[3][7] = "\|";
	$character[0][6] = $character[2][2] = $character[3][4] = $character[4][3]
	    = $character[4][4] = $character[4][5] = "_";
	$character[4][2] = "\\";
	return \@character;
};

function character_K => sub {
	my @character = $_[0]->default_character(7);
	$character[3][3] = "\.";
	$character[1][1] = $character[1][3] = $character[2][1] = $character[3][1]
	    = $character[4][1] = $character[4][3] = "\|";
	$character[1][4] = $character[1][6] = $character[2][5] = "\/";
	$character[3][5] = $character[4][4] = $character[4][6] = "\\";
	$character[0][2] = $character[0][5] = $character[0][6] = $character[4][2]
	    = $character[4][5] = "_";
	$character[2][3] = "\'";
	return \@character;
};

function character_L => sub {
	my @character = $_[0]->default_character(8);
	$character[1][1] = $character[1][3] = $character[2][1] = $character[2][3]
	    = $character[3][1] = $character[3][3] = $character[4][1]
	    = $character[4][7] = "\|";
	$character[0][2] = $character[3][4] = $character[3][5] = $character[3][6]
	    = $character[4][2] = $character[4][3] = $character[4][4]
	    = $character[4][5] = $character[4][6] = "_";
	return \@character;
};

function character_M => sub {
	my @character = $_[0]->default_character(9);
	$character[1][4] = $character[2][4] = "\\";
	$character[0][2] = $character[0][3] = $character[0][6] = $character[0][7]
	    = $character[4][2] = $character[4][7] = "_";
	$character[1][1] = $character[1][8] = $character[2][1] = $character[2][3]
	    = $character[2][6] = $character[2][8] = $character[3][1]
	    = $character[3][3] = $character[3][6] = $character[3][8]
	    = $character[4][1] = $character[4][3] = $character[4][6]
	    = $character[4][8] = "\|";
	$character[1][5] = $character[2][5] = "\/";
	return \@character;
};

function character_N => sub {
	my @character = $_[0]->default_character(8);
	$character[1][1] = $character[1][5] = $character[1][7] = $character[2][1]
	    = $character[2][5] = $character[2][7] = $character[3][1]
	    = $character[3][3] = $character[3][7] = $character[4][1]
	    = $character[4][3] = $character[4][7] = "\|";
	$character[0][2] = $character[0][6] = $character[4][2] = $character[4][6]
	    = "_";
	$character[1][3] = $character[2][4] = $character[3][4] = $character[4][5]
	    = "\\";
	return \@character;
};

function character_O => sub {
	my @character = $_[0]->default_character(8);
	$character[2][1] = $character[2][3] = $character[2][5] = $character[2][7]
	    = $character[3][1] = $character[3][3] = $character[3][5]
	    = $character[3][7] = "\|";
	$character[1][2] = $character[4][6] = "\/";
	$character[1][6] = $character[4][2] = "\\";
	$character[0][3] = $character[0][4] = $character[0][5] = $character[1][4]
	    = $character[3][4] = $character[4][3] = $character[4][4]
	    = $character[4][5] = "_";
	return \@character;
};

function character_P => sub {
	my @character = $_[0]->default_character(8);
	$character[1][1] = $character[2][1] = $character[2][3] = $character[2][7]
	    = $character[3][1] = $character[4][1] = $character[4][3] = "\|";
	$character[3][6] = "\/";
	$character[1][6] = "\\";
	$character[0][2] = $character[0][3] = $character[0][4] = $character[0][5]
	    = $character[1][4] = $character[2][4] = $character[3][4]
	    = $character[3][5] = $character[4][2] = "_";
	$character[2][5] = "\)";
	return \@character;
};

function character_Q => sub {
	my @character = $_[0]->default_character(8);
	$character[1][6] = $character[4][2] = $character[4][5] = $character[4][7]
	    = "\\";
	$character[0][3] = $character[0][4] = $character[0][5] = $character[1][4]
	    = $character[3][4] = $character[4][3] = $character[4][4]
	    = $character[4][6] = "_";
	$character[2][1] = $character[2][3] = $character[2][5] = $character[2][7]
	    = $character[3][1] = $character[3][3] = $character[3][5]
	    = $character[3][7] = "\|";
	$character[1][2] = "\/";
	return \@character;
};

function character_R => sub {
	my @character = $_[0]->default_character(8);
	$character[2][5] = "\)";
	$character[0][2] = $character[0][3] = $character[0][4] = $character[0][5]
	    = $character[1][4] = $character[2][4] = $character[3][4]
	    = $character[4][2] = $character[4][6] = "_";
	$character[1][6] = $character[4][5] = $character[4][7] = "\\";
	$character[3][6] = "\<";
	$character[1][1] = $character[2][1] = $character[2][3] = $character[2][7]
	    = $character[3][1] = $character[4][1] = $character[4][3] = "\|";
	return \@character;
};

function character_S => sub {
	my @character = $_[0]->default_character(8);
	$character[2][1] = $character[2][6] = "\\";
	$character[0][2] = $character[0][3] = $character[0][4] = $character[0][5]
	    = $character[1][3] = $character[1][4] = $character[1][5]
	    = $character[2][2] = $character[2][3] = $character[2][4]
	    = $character[3][2] = $character[3][3] = $character[3][4]
	    = $character[4][2] = $character[4][3] = $character[4][4]
	    = $character[4][5] = "_";
	$character[3][5] = "\)";
	$character[1][6] = $character[3][7] = $character[4][1] = "\|";
	$character[1][1] = $character[4][6] = "\/";
	return \@character;
};

function character_T => sub {
	my @character = $_[0]->default_character(8);
	$character[0][2] = $character[0][3] = $character[0][4] = $character[0][5]
	    = $character[0][6] = $character[1][2] = $character[1][6]
	    = $character[4][4] = "_";
	$character[1][1] = $character[1][7] = $character[2][3] = $character[2][5]
	    = $character[3][3] = $character[3][5] = $character[4][3]
	    = $character[4][5] = "\|";
	return \@character;
};

function character_U => sub {
	my @character = $_[0]->default_character(8);
	$character[1][1] = $character[1][3] = $character[1][5] = $character[1][7]
	    = $character[2][1] = $character[2][3] = $character[2][5]
	    = $character[2][7] = $character[3][1] = $character[3][3]
	    = $character[3][5] = $character[3][7] = "\|";
	$character[4][6] = "\/";
	$character[4][2] = "\\";
	$character[0][2] = $character[0][6] = $character[3][4] = $character[4][3]
	    = $character[4][4] = $character[4][5] = "_";
	return \@character;
};

function character_V => sub {
	my @character = $_[0]->default_character(10);
	$character[1][7] = $character[1][9] = $character[2][6] = $character[2][8]
	    = $character[3][7] = $character[4][6] = "\/";
	$character[3][5] = "V";
	$character[1][1] = $character[1][3] = $character[2][2] = $character[2][4]
	    = $character[3][3] = $character[4][4] = "\\";
	$character[0][1] = $character[0][2] = $character[0][8] = $character[0][9]
	    = $character[4][5] = "_";
	return \@character;
};

function character_W => sub {
	my @character = $_[0]->default_character(13);
	$character[1][10] = $character[1][12] = $character[2][6]
	    = $character[2][9] = $character[2][11] = $character[3][10]
	    = $character[4][6] = $character[4][9] = "\/";
	$character[3][5] = $character[3][8] = "V";
	$character[1][1] = $character[1][3] = $character[2][2] = $character[2][4]
	    = $character[2][7] = $character[3][3] = $character[4][4]
	    = $character[4][7] = "\\";
	$character[0][1] = $character[0][2] = $character[0][11]
	    = $character[0][12] = $character[4][5] = $character[4][8] = "_";
	return \@character;
};

function character_X => sub {
	my @character = $_[0]->default_character(7);
	$character[1][4] = $character[1][6] = $character[2][5] = $character[3][2]
	    = $character[4][1] = $character[4][3] = "\/";
	$character[1][1] = $character[1][3] = $character[2][2] = $character[3][5]
	    = $character[4][4] = $character[4][6] = "\\";
	$character[0][1] = $character[0][2] = $character[0][5] = $character[0][6]
	    = $character[4][2] = $character[4][5] = "_";
	return \@character;
};

function character_Y => sub {
	my @character = $_[0]->default_character(8);
	$character[1][5] = $character[1][7] = $character[2][6] = "\/";
	$character[3][3] = $character[3][5] = $character[4][3] = $character[4][5]
	    = "\|";
	$character[0][1] = $character[0][2] = $character[0][6] = $character[0][7]
	    = $character[4][4] = "_";
	$character[2][4] = "V";
	$character[1][1] = $character[1][3] = $character[2][2] = "\\";
	return \@character;
};

function character_Z => sub {
	my @character = $_[0]->default_character(7);
	$character[1][1] = $character[4][6] = "\|";
	$character[1][6] = $character[2][3] = $character[2][5] = $character[3][2]
	    = $character[3][4] = $character[4][1] = "\/";
	$character[0][2] = $character[0][3] = $character[0][4] = $character[0][5]
	    = $character[0][6] = $character[1][2] = $character[1][3]
	    = $character[3][5] = $character[4][2] = $character[4][3]
	    = $character[4][4] = $character[4][5] = "_";
	return \@character;
};

function character_a => sub {
	my @character = $_[0]->default_character(8);
	$character[2][2] = "\/";
	$character[2][7] = $character[3][1] = $character[3][5] = $character[3][7]
	    = $character[4][7] = "\|";
	$character[2][5] = "\`";
	$character[1][3] = $character[1][4] = $character[1][6] = $character[2][4]
	    = $character[3][4] = $character[4][3] = $character[4][4]
	    = $character[4][6] = "_";
	$character[3][3] = "\(";
	$character[4][2] = "\\";
	$character[4][5] = "\,";
	return \@character;
};

function character_b => sub {
	my @character = $_[0]->default_character(8);
	$character[0][2] = $character[1][4] = $character[1][5] = $character[2][4]
	    = $character[3][4] = $character[4][2] = $character[4][4]
	    = $character[4][5] = "_";
	$character[2][3] = "\'";
	$character[3][5] = "\)";
	$character[2][6] = "\\";
	$character[4][6] = "\/";
	$character[1][1] = $character[1][3] = $character[2][1] = $character[3][1]
	    = $character[3][3] = $character[3][7] = $character[4][1] = "\|";
	$character[4][3] = "\.";
	return \@character;
};

function character_c => sub {
	my @character = $_[0]->default_character(7);
	$character[2][6] = $character[3][1] = $character[4][6] = "\|";
	$character[2][2] = "\/";
	$character[4][2] = "\\";
	$character[1][3] = $character[1][4] = $character[1][5] = $character[2][4]
	    = $character[2][5] = $character[3][4] = $character[3][5]
	    = $character[4][3] = $character[4][4] = $character[4][5] = "_";
	$character[3][3] = "\(";
	return \@character;
};

function character_d => sub {
	my @character = $_[0]->default_character(8);
	$character[0][6] = $character[1][3] = $character[1][4] = $character[2][4]
	    = $character[3][4] = $character[4][3] = $character[4][4]
	    = $character[4][6] = "_";
	$character[3][3] = "\(";
	$character[4][2] = "\\";
	$character[2][2] = "\/";
	$character[1][5] = $character[1][7] = $character[2][7] = $character[3][1]
	    = $character[3][5] = $character[3][7] = $character[4][7] = "\|";
	$character[2][5] = "\`";
	$character[4][5] = "\,";
	return \@character;
};

function character_e => sub {
	my @character = $_[0]->default_character(7);
	$character[2][2] = $character[3][6] = "\/";
	$character[3][1] = $character[4][6] = "\|";
	$character[1][3] = $character[1][4] = $character[1][5] = $character[2][4]
	    = $character[3][4] = $character[3][5] = $character[4][3]
	    = $character[4][4] = $character[4][5] = "_";
	$character[2][6] = $character[4][2] = "\\";
	return \@character;
};

function character_f => sub {
	my @character = $_[0]->default_character(6);
	$character[1][5] = $character[2][1] = $character[2][3] = $character[3][1]
	    = $character[3][5] = $character[4][1] = $character[4][3] = "\|";
	$character[1][2] = "\/";
	$character[0][3] = $character[0][4] = $character[1][4] = $character[2][4]
	    = $character[3][4] = $character[4][2] = "_";
	return \@character;
};

function character_g => sub {
	my @character = $_[0]->default_character(8);
	$character[4][2] = "\\";
	$character[1][3] = $character[1][4] = $character[1][6] = $character[2][4]
	    = $character[3][4] = $character[4][3] = $character[4][4]
	    = $character[5][3] = $character[5][4] = $character[5][5] = "_";
	$character[3][3] = "\(";
	$character[2][5] = "\`";
	$character[2][7] = $character[3][1] = $character[3][5] = $character[3][7]
	    = $character[4][7] = $character[5][2] = "\|";
	$character[2][2] = $character[5][6] = "\/";
	$character[4][5] = "\,";
	return \@character;
};

function character_h => sub {
	my @character = $_[0]->default_character(8);
	$character[0][2] = $character[1][4] = $character[1][5] = $character[2][4]
	    = $character[4][2] = $character[4][6] = "_";
	$character[2][3] = "\'";
	$character[2][6] = "\\";
	$character[1][1] = $character[1][3] = $character[2][1] = $character[3][1]
	    = $character[3][3] = $character[3][5] = $character[3][7]
	    = $character[4][1] = $character[4][3] = $character[4][5]
	    = $character[4][7] = "\|";
	return \@character;
};

function character_i => sub {
	my @character = $_[0]->default_character(4);
	$character[2][1] = $character[2][3] = $character[3][1] = $character[3][3]
	    = $character[4][1] = $character[4][3] = "\|";
	$character[1][3] = "\)";
	$character[0][2] = $character[1][2] = $character[4][2] = "_";
	$character[1][1] = "\(";
	return \@character;
};

function character_j => sub {
	my @character = $_[0]->default_character(6);
	$character[4][3] = $character[5][4] = "\/";
	$character[2][3] = $character[2][5] = $character[3][3] = $character[3][5]
	    = $character[4][5] = $character[5][1] = "\|";
	$character[1][5] = "\)";
	$character[1][3] = "\(";
	$character[0][4] = $character[1][4] = $character[4][2] = $character[5][2]
	    = $character[5][3] = "_";
	return \@character;
};

function character_k => sub {
	my @character = $_[0]->default_character(7);
	$character[1][1] = $character[1][3] = $character[2][1] = $character[2][3]
	    = $character[3][1] = $character[4][1] = $character[4][3] = "\|";
	$character[2][4] = $character[2][6] = "\/";
	$character[4][4] = $character[4][6] = "\\";
	$character[0][2] = $character[1][5] = $character[1][6] = $character[4][2]
	    = $character[4][5] = "_";
	$character[3][5] = "\<";
	return \@character;
};

function character_l => sub {
	my @character = $_[0]->default_character(4);
	$character[0][2] = $character[4][2] = "_";
	$character[1][1] = $character[1][3] = $character[2][1] = $character[2][3]
	    = $character[3][1] = $character[3][3] = $character[4][1]
	    = $character[4][3] = "\|";
	return \@character;
};

function character_m => sub {
	my @character = $_[0]->default_character(12);
	$character[2][1] = $character[3][1] = $character[3][3] = $character[3][5]
	    = $character[3][7] = $character[3][9] = $character[3][11]
	    = $character[4][1] = $character[4][3] = $character[4][5]
	    = $character[4][7] = $character[4][9] = $character[4][11] = "\|";
	$character[2][6] = "\`";
	$character[1][2] = $character[1][4] = $character[1][5] = $character[1][7]
	    = $character[1][8]  = $character[1][9] = $character[2][4]
	    = $character[2][8]  = $character[4][2] = $character[4][6]
	    = $character[4][10] = "_";
	$character[2][3]  = "\'";
	$character[2][10] = "\\";
	return \@character;
};

function character_n => sub {
	my @character = $_[0]->default_character(8);
	$character[2][1] = $character[3][1] = $character[3][3] = $character[3][5]
	    = $character[3][7] = $character[4][1] = $character[4][3]
	    = $character[4][5] = $character[4][7] = "\|";
	$character[2][3] = "\'";
	$character[1][2] = $character[1][4] = $character[1][5] = $character[2][4]
	    = $character[4][2] = $character[4][6] = "_";
	$character[2][6] = "\\";
	return \@character;
};

function character_o => sub {
	my @character = $_[0]->default_character(8);
	$character[2][6] = $character[4][2] = "\\";
	$character[3][3] = "\(";
	$character[1][3] = $character[1][4] = $character[1][5] = $character[2][4]
	    = $character[3][4] = $character[4][3] = $character[4][4]
	    = $character[4][5] = "_";
	$character[3][5] = "\)";
	$character[3][1] = $character[3][7] = "\|";
	$character[2][2] = $character[4][6] = "\/";
	return \@character;
};

function character_p => sub {
	my @character = $_[0]->default_character(8);
	$character[4][6] = "\/";
	$character[2][1] = $character[3][1] = $character[3][3] = $character[3][7]
	    = $character[4][1] = $character[5][1] = $character[5][3] = "\|";
	$character[1][2] = $character[1][4] = $character[1][5] = $character[2][4]
	    = $character[3][4] = $character[4][4] = $character[4][5]
	    = $character[5][2] = "_";
	$character[2][3] = "\'";
	$character[3][5] = "\)";
	$character[2][6] = "\\";
	$character[4][3] = "\.";
	return \@character;
};

function character_q => sub {
	my @character = $_[0]->default_character(8);
	$character[2][2] = "\/";
	$character[2][5] = "\`";
	$character[2][7] = $character[3][1] = $character[3][5] = $character[3][7]
	    = $character[4][7] = $character[5][5] = $character[5][7] = "\|";
	$character[3][3] = "\(";
	$character[1][3] = $character[1][4] = $character[1][6] = $character[2][4]
	    = $character[3][4] = $character[4][3] = $character[4][4]
	    = $character[5][6] = "_";
	$character[4][2] = "\\";
	$character[4][5] = "\,";
	return \@character;
};

function character_r => sub {
	my @character = $_[0]->default_character(7);
	$character[2][1] = $character[2][6] = $character[3][1] = $character[3][3]
	    = $character[4][1] = $character[4][3] = "\|";
	$character[2][3] = "\'";
	$character[1][2] = $character[1][4] = $character[1][5] = $character[2][4]
	    = $character[2][5] = $character[4][2] = "_";
	return \@character;
};

function character_s => sub {
	my @character = $_[0]->default_character(6);
	$character[2][1] = $character[4][5] = "\/";
	$character[2][5] = $character[4][1] = "\|";
	$character[1][2] = $character[1][3] = $character[1][4] = $character[2][3]
	    = $character[2][4] = $character[3][2] = $character[3][3]
	    = $character[4][2] = $character[4][3] = $character[4][4] = "_";
	$character[3][1] = $character[3][5] = "\\";
	return \@character;
};

function character_t => sub {
	my @character = $_[0]->default_character(6);
	$character[1][1] = $character[1][3] = $character[2][1] = $character[2][5]
	    = $character[3][1] = $character[3][3] = $character[4][5] = "\|";
	$character[0][2] = $character[1][4] = $character[2][3] = $character[2][4]
	    = $character[3][4] = $character[4][3] = $character[4][4] = "_";
	$character[4][2] = "\\";
	return \@character;
};

function character_u => sub {
	my @character = $_[0]->default_character(8);
	$character[1][2] = $character[1][6] = $character[3][4] = $character[4][3]
	    = $character[4][4] = $character[4][6] = "_";
	$character[4][2] = "\\";
	$character[2][1] = $character[2][3] = $character[2][5] = $character[2][7]
	    = $character[3][1] = $character[3][3] = $character[3][5]
	    = $character[3][7] = $character[4][7] = "\|";
	$character[4][5] = "\,";
	return \@character;
};

function character_v => sub {
	my @character = $_[0]->default_character(8);
	$character[2][1] = $character[2][3] = $character[3][2] = $character[4][3]
	    = "\\";
	$character[3][4] = "V";
	$character[1][1] = $character[1][2] = $character[1][6] = $character[1][7]
	    = $character[4][4] = "_";
	$character[2][5] = $character[2][7] = $character[3][6] = $character[4][5]
	    = "\/";
	return \@character;
};

function character_w => sub {
	my @character = $_[0]->default_character(11);
	$character[1][1] = $character[1][2] = $character[1][9]
	    = $character[1][10] = $character[4][4] = $character[4][7] = "_";
	$character[2][1] = $character[2][3] = $character[2][6] = $character[3][2]
	    = $character[4][3] = $character[4][6] = "\\";
	$character[3][4] = $character[3][7] = "V";
	$character[2][5] = $character[2][8] = $character[2][10]
	    = $character[3][9] = $character[4][5] = $character[4][8] = "\/";
	return \@character;
};

function character_x => sub {
	my @character = $_[0]->default_character(7);
	$character[1][1] = $character[1][2] = $character[1][5] = $character[1][6]
	    = $character[4][2] = $character[4][5] = "_";
	$character[2][1] = $character[2][3] = $character[4][4] = $character[4][6]
	    = "\\";
	$character[3][2] = "\>";
	$character[2][4] = $character[2][6] = $character[4][1] = $character[4][3]
	    = "\/";
	$character[3][5] = "\<";
	return \@character;
};

function character_y => sub {
	my @character = $_[0]->default_character(8);
	$character[4][5] = "\,";
	$character[5][6] = "\/";
	$character[2][1] = $character[2][3] = $character[2][5] = $character[2][7]
	    = $character[3][1] = $character[3][3] = $character[3][5]
	    = $character[3][7] = $character[4][7] = $character[5][2] = "\|";
	$character[1][2] = $character[1][6] = $character[3][4] = $character[4][3]
	    = $character[4][4] = $character[5][3] = $character[5][4]
	    = $character[5][5] = "_";
	$character[4][2] = "\\";
	return \@character;
};

function character_z => sub {
	my @character = $_[0]->default_character(6);
	$character[2][5] = $character[3][2] = $character[3][4] = $character[4][1]
	    = "\/";
	$character[2][1] = $character[4][5] = "\|";
	$character[1][2] = $character[1][3] = $character[1][4] = $character[1][5]
	    = $character[2][2] = $character[4][2] = $character[4][3]
	    = $character[4][4] = "_";
	return \@character;
};

function character_0 => sub {
	my @character = $_[0]->default_character(8);
	$character[2][1] = $character[2][3] = $character[2][5] = $character[2][7]
	    = $character[3][1] = $character[3][3] = $character[3][5]
	    = $character[3][7] = "\|";
	$character[1][2] = $character[4][6] = "\/";
	$character[1][6] = $character[4][2] = "\\";
	$character[0][3] = $character[0][4] = $character[0][5] = $character[1][4]
	    = $character[3][4] = $character[4][3] = $character[4][4]
	    = $character[4][5] = "_";
	return \@character;
};

function character_1 => sub {
	my @character = $_[0]->default_character(4);
	$character[0][2] = $character[4][2] = "_";
	$character[1][1] = "\/";
	$character[1][3] = $character[2][1] = $character[2][3] = $character[3][1]
	    = $character[3][3] = $character[4][1] = $character[4][3] = "\|";
	return \@character;
};

function character_2 => sub {
	my @character = $_[0]->default_character(8);
	$character[0][2] = $character[0][3] = $character[0][4] = $character[0][5]
	    = $character[1][2] = $character[1][3] = $character[1][4]
	    = $character[2][3] = $character[2][4] = $character[3][4]
	    = $character[3][5] = $character[4][2] = $character[4][3]
	    = $character[4][4] = $character[4][5] = $character[4][6] = "_";
	$character[2][5] = "\)";
	$character[1][6] = "\\";
	$character[3][2] = $character[3][6] = "\/";
	$character[1][1] = $character[2][7] = $character[4][1] = $character[4][7]
	    = "\|";
	return \@character;
};

function character_3 => sub {
	my @character = $_[0]->default_character(8);
	$character[2][6] = "\\";
	$character[3][5] = "\)";
	$character[0][2] = $character[0][3] = $character[0][4] = $character[0][5]
	    = $character[0][6] = $character[1][2] = $character[1][3]
	    = $character[1][4] = $character[2][4] = $character[3][2]
	    = $character[3][3] = $character[3][4] = $character[4][2]
	    = $character[4][3] = $character[4][4] = $character[4][5] = "_";
	$character[1][1] = $character[2][3] = $character[3][7] = $character[4][1]
	    = "\|";
	$character[1][6] = $character[4][6] = "\/";
	return \@character;
};

function character_4 => sub {
	my @character = $_[0]->default_character(9);
	$character[1][1] = $character[1][3] = $character[1][4] = $character[1][6]
	    = $character[2][1] = $character[2][3] = $character[2][4]
	    = $character[2][6] = $character[3][1] = $character[3][8]
	    = $character[4][4] = $character[4][6] = "\|";
	$character[0][2] = $character[0][5] = $character[2][7] = $character[3][2]
	    = $character[3][3] = $character[3][7] = $character[4][5] = "_";
	return \@character;
};

function character_5 => sub {
	my @character = $_[0]->default_character(8);
	$character[4][6] = "\/";
	$character[1][1] = $character[1][6] = $character[2][1] = $character[3][7]
	    = $character[4][1] = "\|";
	$character[0][2] = $character[0][3] = $character[0][4] = $character[0][5]
	    = $character[1][3] = $character[1][4] = $character[1][5]
	    = $character[2][2] = $character[2][3] = $character[2][4]
	    = $character[3][2] = $character[3][3] = $character[3][4]
	    = $character[4][2] = $character[4][3] = $character[4][4]
	    = $character[4][5] = "_";
	$character[3][5] = "\)";
	$character[2][6] = "\\";
	return \@character;
};

function character_6 => sub {
	my @character = $_[0]->default_character(8);
	$character[1][2] = $character[1][4] = $character[4][6] = "\/";
	$character[2][1] = $character[3][1] = $character[3][7] = "\|";
	$character[3][5] = "\)";
	$character[3][3] = "\(";
	$character[2][3] = "\'";
	$character[0][3] = $character[0][4] = $character[1][5] = $character[2][4]
	    = $character[3][4] = $character[4][3] = $character[4][4]
	    = $character[4][5] = "_";
	$character[2][6] = $character[4][2] = "\\";
	return \@character;
};

function character_7 => sub {
	my @character = $_[0]->default_character(8);
	$character[0][2] = $character[0][3] = $character[0][4] = $character[0][5]
	    = $character[0][6] = $character[1][2] = $character[1][3]
	    = $character[1][4] = $character[4][3] = "_";
	$character[1][1] = $character[1][7] = "\|";
	$character[2][4] = $character[2][6] = $character[3][3] = $character[3][5]
	    = $character[4][2] = $character[4][4] = "\/";
	return \@character;
};

function character_8 => sub {
	my @character = $_[0]->default_character(8);
	$character[1][2] = $character[3][3] = "\(";
	$character[0][3] = $character[0][4] = $character[0][5] = $character[1][4]
	    = $character[2][4] = $character[3][4] = $character[4][3]
	    = $character[4][4] = $character[4][5] = "_";
	$character[1][6] = $character[3][5] = "\)";
	$character[2][6] = $character[4][2] = "\\";
	$character[2][2] = $character[4][6] = "\/";
	$character[3][1] = $character[3][7] = "\|";
	return \@character;
};

function character_9 => sub {
	my @character = $_[0]->default_character(8);
	$character[3][5] = "\,";
	$character[2][1] = $character[2][7] = $character[3][7] = "\|";
	$character[1][2] = $character[4][4] = $character[4][6] = "\/";
	$character[1][6] = $character[3][2] = "\\";
	$character[2][5] = "\)";
	$character[2][3] = "\(";
	$character[0][3] = $character[0][4] = $character[0][5] = $character[1][4]
	    = $character[2][4] = $character[3][3] = $character[3][4]
	    = $character[4][5] = "_";
	return \@character;
};

1;

__END__

=head1 NAME

Ascii::Text::Font::Standard - Standard Font

=head1 VERSION

Version 0.21

=cut

=head1 SYNOPSIS

Quick summary of what the module does.
	
	use Ascii::Text::Font::Standard;

	my $foo = Ascii::Text::Font::Standard->new();

	...

=head1 EXTENDS

=head2 Ascii::Text::Font

=head1 SUBROUTINES/METHODS

=head2 space

=head2 character_A

	     _    
	    / \   
	   / _ \  
	  / ___ \ 
	 /_/   \_\
	          

=head2 character_B

	  ____  
	 | __ ) 
	 |  _ \ 
	 | |_) |
	 |____/ 
	        

=head2 character_C

	   ____ 
	  / ___|
	 | |    
	 | |___ 
	  \____|
	        

=head2 character_D

	  ____  
	 |  _ \ 
	 | | | |
	 | |_| |
	 |____/ 
	        

=head2 character_E

	  _____ 
	 | ____|
	 |  _|  
	 | |___ 
	 |_____|
	        

=head2 character_F

	  _____ 
	 |  ___|
	 | |_   
	 |  _|  
	 |_|    
	        

=head2 character_G

	   ____ 
	  / ___|
	 | |  _ 
	 | |_| |
	  \____|
	        

=head2 character_H

	  _   _ 
	 | | | |
	 | |_| |
	 |  _  |
	 |_| |_|
	        

=head2 character_I

	  ___ 
	 |_ _|
	  | | 
	  | | 
	 |___|
	      

=head2 character_J

	      _ 
	     | |
	  _  | |
	 | |_| |
	  \___/ 
	        

=head2 character_K

	  _  __
	 | |/ /
	 | ' / 
	 | . \ 
	 |_|\_\
	       

=head2 character_L

	  _     
	 | |    
	 | |    
	 | |___ 
	 |_____|
	        

=head2 character_M

	  __  __ 
	 |  \/  |
	 | |\/| |
	 | |  | |
	 |_|  |_|
	         

=head2 character_N

	  _   _ 
	 | \ | |
	 |  \| |
	 | |\  |
	 |_| \_|
	        

=head2 character_O

	   ___  
	  / _ \ 
	 | | | |
	 | |_| |
	  \___/ 
	        

=head2 character_P

	  ____  
	 |  _ \ 
	 | |_) |
	 |  __/ 
	 |_|    
	        

=head2 character_Q

	   ___  
	  / _ \ 
	 | | | |
	 | |_| |
	  \__\_\
	        

=head2 character_R

	  ____  
	 |  _ \ 
	 | |_) |
	 |  _ < 
	 |_| \_\
	        

=head2 character_S

	  ____  
	 / ___| 
	 \___ \ 
	  ___) |
	 |____/ 
	        

=head2 character_T

	  _____ 
	 |_   _|
	   | |  
	   | |  
	   |_|  
	        

=head2 character_U

	  _   _ 
	 | | | |
	 | | | |
	 | |_| |
	  \___/ 
	        

=head2 character_V

	 __     __
	 \ \   / /
	  \ \ / / 
	   \ V /  
	    \_/   
	          

=head2 character_W

	 __        __
	 \ \      / /
	  \ \ /\ / / 
	   \ V  V /  
	    \_/\_/   
	             

=head2 character_X

	 __  __
	 \ \/ /
	  \  / 
	  /  \ 
	 /_/\_\
	       

=head2 character_Y

	 __   __
	 \ \ / /
	  \ V / 
	   | |  
	   |_|  
	        

=head2 character_Z

	  _____
	 |__  /
	   / / 
	  / /_ 
	 /____|
	       

=head2 character_a

	        
	   __ _ 
	  / _` |
	 | (_| |
	  \__,_|
	        

=head2 character_b

	  _     
	 | |__  
	 | '_ \ 
	 | |_) |
	 |_.__/ 
	        

=head2 character_c

	       
	   ___ 
	  / __|
	 | (__ 
	  \___|
	       

=head2 character_d

	      _ 
	   __| |
	  / _` |
	 | (_| |
	  \__,_|
	        

=head2 character_e

	       
	   ___ 
	  / _ \
	 |  __/
	  \___|
	       

=head2 character_f

	   __ 
	  / _|
	 | |_ 
	 |  _|
	 |_|  
	      

=head2 character_g

	        
	   __ _ 
	  / _` |
	 | (_| |
	  \__, |
	  |___/ 

=head2 character_h

	  _     
	 | |__  
	 | '_ \ 
	 | | | |
	 |_| |_|
	        

=head2 character_i

	  _ 
	 (_)
	 | |
	 | |
	 |_|
	    

=head2 character_j

	    _ 
	   (_)
	   | |
	   | |
	  _/ |
	 |__/ 

=head2 character_k

	  _    
	 | | __
	 | |/ /
	 |   < 
	 |_|\_\
	       

=head2 character_l

	  _ 
	 | |
	 | |
	 | |
	 |_|
	    

=head2 character_m

	            
	  _ __ ___  
	 | '_ ` _ \ 
	 | | | | | |
	 |_| |_| |_|
	            

=head2 character_n

	        
	  _ __  
	 | '_ \ 
	 | | | |
	 |_| |_|
	        

=head2 character_o

	        
	   ___  
	  / _ \ 
	 | (_) |
	  \___/ 
	        

=head2 character_p

	        
	  _ __  
	 | '_ \ 
	 | |_) |
	 | .__/ 
	 |_|    

=head2 character_q

	        
	   __ _ 
	  / _` |
	 | (_| |
	  \__, |
	     |_|

=head2 character_r

	       
	  _ __ 
	 | '__|
	 | |   
	 |_|   
	       

=head2 character_s

	      
	  ___ 
	 / __|
	 \__ \
	 |___/
	      

=head2 character_t

	  _   
	 | |_ 
	 | __|
	 | |_ 
	  \__|
	      

=head2 character_u

	        
	  _   _ 
	 | | | |
	 | |_| |
	  \__,_|
	        

=head2 character_v

	        
	 __   __
	 \ \ / /
	  \ V / 
	   \_/  
	        

=head2 character_w

	           
	 __      __
	 \ \ /\ / /
	  \ V  V / 
	   \_/\_/  
	           

=head2 character_x

	       
	 __  __
	 \ \/ /
	  >  < 
	 /_/\_\
	       

=head2 character_y

	        
	  _   _ 
	 | | | |
	 | |_| |
	  \__, |
	  |___/ 

=head2 character_z

	      
	  ____
	 |_  /
	  / / 
	 /___|
	      

=head2 character_0

	   ___  
	  / _ \ 
	 | | | |
	 | |_| |
	  \___/ 
	        

=head2 character_1

	  _ 
	 / |
	 | |
	 | |
	 |_|
	    

=head2 character_2

	  ____  
	 |___ \ 
	   __) |
	  / __/ 
	 |_____|
	        

=head2 character_3

	  _____ 
	 |___ / 
	   |_ \ 
	  ___) |
	 |____/ 
	        

=head2 character_4

	  _  _   
	 | || |  
	 | || |_ 
	 |__   _|
	    |_|  
	         

=head2 character_5

	  ____  
	 | ___| 
	 |___ \ 
	  ___) |
	 |____/ 
	        

=head2 character_6

	   __   
	  / /_  
	 | '_ \ 
	 | (_) |
	  \___/ 
	        

=head2 character_7

	  _____ 
	 |___  |
	    / / 
	   / /  
	  /_/   
	        

=head2 character_8

	   ___  
	  ( _ ) 
	  / _ \ 
	 | (_) |
	  \___/ 
	        

=head2 character_9

	   ___  
	  / _ \ 
	 | (_) |
	  \__, |
	    /_/ 
	        

=head1 PROPERTY

=head2 character_height



=head1 AUTHOR

AUTHOR, C<< <EMAIL> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-ascii::text::font::standard at rt.cpan.org>, or through
the web interface at L<https://rt.cpan.org/NoAuth/ReportBug.html?Queue=Ascii-Text-Font-Standard>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Ascii::Text::Font::Standard

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<https://rt.cpan.org/NoAuth/Bugs.html?Dist=Ascii-Text-Font-Standard>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Ascii-Text-Font-Standard>

=item * CPAN Ratings

L<https://cpanratings.perl.org/d/Ascii-Text-Font-Standard>

=item * Search CPAN

L<https://metacpan.org/release/Ascii-Text-Font-Standard>

=back

=head1 ACKNOWLEDGEMENTS

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2020 by AUTHOR.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut

 
