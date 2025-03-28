package Ascii::Text;

use 5.006;
use strict;
use warnings;

our $VERSION = '0.21';

use Rope;
use Rope::Autoload;
use Term::Size::ReadKey;
use Module::Load;
use Types::Standard qw/Int Str Enum HashRef FileHandle/;

use overload "&{}" => sub {
	my $self = shift; 
	return sub { $self->render(@_); } 
};

property max_width => (
	initable => 1,
	writeable => 1,
	type => Int,
	builder => sub {
		Term::Size::ReadKey::chars *STDOUT{IO};
	}
);

property pad => (
	initable => 1,
	writeable => 1,
	type => Int,
	value => 0,
);

property font => (
	initable => 1,
	writeable => 1,
	type => Str,
	value => 'Boomer'
);

property align => (
	initable => 1,
	writeable => 1,
	type => Enum[qw( left center right )],
	value => 'left'
);

property color => (
	initable => 1,
	type => Str,
	writeable => 1,
);

property color_map => (
	initable => 1,
	writeable => 1,
	type => HashRef,
	builder => sub { return {
		black => "\e[30m",
		red => "\e[31m",
		green => "\e[32m",
		yellow => "\e[33m",
		blue => "\e[34m",
		magenta => "\e[35m",
		cyan => "\e[36m",
		white => "\e[37m",
		bright_black => "\e[90m",
		bright_red => "\e[91m",
		bright_green => "\e[92m",
		bright_yellow => "\e[93m",
		bright_blue => "\e[94m",
		bright_magenta => "\e[95m",
		bright_cyan => "\e[96m",
		bright_white => "\e[37m",
	} }
);

property fh => (
	initable => 1,
	writeable => 1,
	builder => sub {
		return *STDOUT;
	}
);

function font_class => sub {
	my $class = sprintf "Ascii::Text::Font::%s", $_[0]->font;
	load $class;
	return $class;
};

function stringify => sub {
	my ($self, $text, $wrap) = @_;
	my $stringify = [];
	$self->render($text, $stringify);
	return join "", grep { $wrap ? $_ !~ m/^\s+$/ : $_ } @{$stringify};
};

function render => sub {
	my ($self, $text, $stringify) = @_;
	$text =~ s/[^ 0-9A-Za-z]//;
	my $class = $self->font_class->new;
	my @words = split /\s+/, $text;
	my %character_map;
	for (@words) {
		my @characters = split //, $_;
		for (@characters) {
			next if $character_map{$_};
			my $character = "character_$_";
			$character = $class->$character;
			$character_map{$_} = $character;
		}
	}
	my ($width, @line) = $self->new_line();
	while (@words) {
		my @characters = split //, shift @words;
		for (my $i = 0; $i < scalar @characters; $i++) {
			my $character = $character_map{$characters[$i]};
			for (my $i = 0; $i < scalar @{$character}; $i++) {
				push @{$line[$i]}, @{$character->[$i]};
			}
			$width -= scalar @{$character->[0]};

			my $next = $characters[$i + 1];
			if ($next && $width < scalar @{$character_map{$next}->[0]}) {
				$self->print_line(\@line, $stringify);
				($width, @line) = $self->new_line();
			}
		}
		if ($words[0]) {
			@characters = split //, $words[0];
			my $space = $class->space;
			my $required_width = scalar @{$space->[0]};
			$required_width += @{$character_map{$_}->[0]} for @characters;
			if ($width > $required_width) {
				for (my $i = 0; $i < scalar @{$space}; $i++) {
					push @{$line[$i]}, @{$space->[$i]}, " ";
				}
				$width = $width - scalar @{$space->[0]};
				next;
			}
		}
		$self->print_line(\@line, $stringify);
		($width, @line) = $self->new_line();
	}
	if ($self->color && $self->color_map->{$self->color}) {
		if ($stringify) {
			push @{$stringify}, "\e[0m";
		} else {
			my $fh = $self->fh;
			print $fh "\e[0m";
		}
	}
};

function new_line => sub {
	return ($_[0]->max_width, [],[],[],[],[],[]);
};

function print_line => sub {
	my ($self, $line, $stringify) = @_;
	my $line_width = @{$line->[0]};
	my $pad = $self->align eq 'center' 
		? ($self->max_width - $line_width) / 2
		: $self->align eq 'right'
		? $self->max_width - $line_width
		: $self->pad;
	$pad = $pad && $pad > 0 ? " " x $pad : ""; 
	my $fh = $self->fh;
	for (@{$line}) {
		next unless scalar @{$_};
		if ($self->color && $self->color_map->{$self->color}) {
			if ($stringify) {
				push @{$stringify}, $self->color_map->{$self->color};
			} else {
				print $fh $self->color_map->{$self->color};
			}
		}
		my $l = $pad;
		$l .= join "", @{$_};
		$l .= "\n";
		if ($stringify) {
			push @{$stringify}, $l;
		} else {
			print $fh $l;
		}
	}
};

1;

__END__

=head1 NAME

Ascii::Text - module for generating ASCII text in various fonts and styles

=head1 VERSION

Version 0.21

=cut

=head1 SYNOPSIS

	use Ascii::Text;

	my $foo = Ascii::Text->new(
		color => 'red',
		align => 'center'
	);

	$foo->("Hello World");

	 _   _        _  _                 _    _              _      _
	| | | |      | || |               | |  | |            | |    | |
	| |_| |  ___ | || |  ___          | |  | |  ___   _ _ | |  __| |
	|  _  | / _ \| || | / _ \         | |/\| | / _ \ | '_|| | / _` |
	| | | ||  __/| || || (_) |        \  /\  /| (_) || |  | || (_| |
	\_| |_/ \___||_||_| \___/          \/  \/  \___/ |_|  |_| \__,_|

=head1 SUBROUTINES/METHODS

=head2 new

Instantiate a new Ascii::Text object.

	my $ascii = Ascii::Text->new(
		font => 'Boomer',
		max_width => 100
	);

=head2 render

Render the passed string as ascii text. By default this will print to the terminal.

	$ascii->render("Hello World");

...

You can capture lines of text instead by passing an array reference as the second argument.

	my $lines = [];
	$ascii->render("Hello World", $lines);
	print join "", @{$lines};

=head2 stringify

Stringify the ascii text. Optionally you can pass an additional true value which will wrap the ascii text removing trailing empty lines which maybe unused based on the character set.

	$ascii->stringify("Hello World");

	$ascii->stringify("Hello World", 1);

=cut

=head1 ATTRIBUTES

=head2 max_width

Set/Get the max width of a line of text by default this uses L<Term::Size::ReadKey> so that the max width of your terminal is used.

	$ascii->max_width(100);

=head2 pad

Set/Get the left padding of the text on a line. When "align" is set to center or right this value will become redundant. The default value is 0.

	$ascii->pad(10);

=head2 font

Set/Get the reference to the font class.

	$ascii->font("Boomer");

=head2 align

Set/Get the alignment of the text on the line. Options are left, center or right.

	$ascii->align('right');

=head2 color

Set/Get the font color

	$ascii->color("red");

=head2 color_map

Override the default ANSI color map.

	$ascii->color_map({
		red => "\e[31m",
		...
	});

=head2 fh

A filehandle to print the ascii text.

	open my $fh, '>', 'test.txt';
	$ascii->fh($fh);
	$ascii->("Hello World");

=head1 AUTHOR

LNATION, C<< <email at lnation.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-ascii-text at rt.cpan.org>, or through
the web interface at L<https://rt.cpan.org/NoAuth/ReportBug.html?Queue=Ascii-Text>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Ascii::Text

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<https://rt.cpan.org/NoAuth/Bugs.html?Dist=Ascii-Text>

=item * CPAN Ratings

L<https://cpanratings.perl.org/d/Ascii-Text>

=item * Search CPAN

L<https://metacpan.org/release/Ascii-Text>

=back

=head1 ACKNOWLEDGEMENTS

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2024 by LNATION.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut

1; # End of Ascii::Text
