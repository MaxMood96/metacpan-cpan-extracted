package ExtUtils::Typemaps::TimeSpec;
$ExtUtils::Typemaps::TimeSpec::VERSION = '0.009';
use strict;
use warnings;

use parent 'ExtUtils::Typemaps';

sub new {
	my $class = shift;
	my $self = $class->SUPER::new(@_);

	$self->add_string(string => <<'END');
TYPEMAP
	struct timespec T_TIMESPEC

INPUT
T_TIMESPEC
	if (SvROK($arg) && sv_derived_from($arg, \"Time::Spec\")) {
		$var = *(struct timespec*)SvPV_nolen(SvRV($arg));
	} else {
		NV input = SvNV($arg);
		$var.tv_sec  = (time_t) floor(input);
		$var.tv_nsec = (long) ((input - $var.tv_sec) * 1000000000);
	}

OUTPUT
T_TIMESPEC
	sv_setnv($arg, $var.tv_sec + $var.tv_nsec / 1000000000.0);
END

	return $self;
}

1;

#ABSTRACT: A typemap for dealing with struct timespec

__END__

=pod

=encoding UTF-8

=head1 NAME

ExtUtils::Typemaps::TimeSpec - A typemap for dealing with struct timespec

=head1 VERSION

version 0.009

=head1 SYNOPSIS

 use ExtUtils::Typemaps::Signal;
 # First, read my own type maps:
 my $private_map = ExtUtils::Typemaps->new(file => 'my.map');

 # Then, get the Signal set and merge it into my maps
 my $map = ExtUtils::Typemaps::Signal->new;
 $private_map->merge(typemap => $map);

 # Now, write the combined map to an output file
 $private_map->write(file => 'typemap');

=head1 DESCRIPTION

ExtUtils::Typemaps::TimeSpec is an ExtUtils::Typemaps subclass that contains a single typemap mapping C<struct timespec> from and to a Perl variable. For input it will take either a number, or a L<Time::Spec> object, as output it always returns a number.

=head1 AUTHOR

Leon Timmermans <fawaka@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2024 by Leon Timmermans.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
