package ExtUtils::Typemaps::Signo;
$ExtUtils::Typemaps::Signo::VERSION = '0.009';
use strict;
use warnings;

use parent 'ExtUtils::Typemaps';

sub new {
	my $class = shift;
	my $self = $class->SUPER::new(@_);

	$self->add_string(string => <<'END');
TYPEMAP
	signo_t		T_SIGNO

INPUT
T_SIGNO
	$var = (SvIOK($arg) || looks_like_number($arg)) ? SvIV($arg) : whichsig(SvPV_nolen($arg));
END

	return $self;
}

1;

#ABSTRACT: A typemap for dealing with signal numbers and names

__END__

=pod

=encoding UTF-8

=head1 NAME

ExtUtils::Typemaps::Signo - A typemap for dealing with signal numbers and names

=head1 VERSION

version 0.009

=head1 SYNOPSIS

 use ExtUtils::Typemaps::Signo;
 # First, read my own type maps:
 my $private_map = ExtUtils::Typemaps->new(file => 'my.map');

 # Then, get the Signo template and merge it into my maps
 my $map = ExtUtils::Typemaps::Signo->new;
 $private_map->merge(typemap => $map);

 # Now, write the combined map to an output file
 $private_map->write(file => 'typemap');

=head1 DESCRIPTION

ExtUtils::Typemaps::Signo is an ExtUtils::Typemaps subclass that provides a typemap (C<T_SIGNO>) for the C type C<signo_t>. It will take a signal name (e.g. C<TERM>) or number (e.g. C<15>), and turn it into the appropriate number. Do note you need to typedef int to this type yourself to use it.

=head1 AUTHOR

Leon Timmermans <fawaka@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2024 by Leon Timmermans.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
