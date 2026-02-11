package ExtUtils::Typemaps::SigSet;
$ExtUtils::Typemaps::SigSet::VERSION = '0.009';
use strict;
use warnings;

use parent 'ExtUtils::Typemaps';

sub new {
	my $class = shift;
	my $self = $class->SUPER::new(@_);

	$self->add_string(string => <<'END');
TYPEMAP
	sigset_t*	T_SIGSET

INPUT
T_SIGSET
	if (SvROK($arg)) {
		if (!sv_derived_from($arg, \"POSIX::SigSet\")) {
			Perl_croak(aTHX_ \"$var is not of type POSIX::SigSet\");
		} else {
	\x{23}if PERL_VERSION > 15 || PERL_VERSION == 15 && PERL_SUBVERSION > 2
			$var = (sigset_t *) SvPV_nolen(SvRV($arg));
	\x{23}else
			IV tmp = SvIV((SV*)SvRV($arg));
			$var = INT2PTR(sigset_t*, tmp);
	\x{23}endif
		}
	} else if (SvOK($arg)) {
		int signo = (SvIOK($arg) || looks_like_number($arg)) && SvIV($arg) ? SvIV($arg) : whichsig(SvPV_nolen($arg));
		SV* buffer = sv_2mortal(newSVpvn(\"\", 0));
		sv_grow(buffer, sizeof(sigset_t));
		$var = (sigset_t*)SvPV_nolen(buffer);
		sigemptyset($var);
		sigaddset($var, signo);
	} else {
		$var = NULL;
	}
END

	return $self;
}

#ABSTRACT: A typemap for dealing with POSIX::SigSet

__END__

=pod

=encoding UTF-8

=head1 NAME

ExtUtils::Typemaps::SigSet - A typemap for dealing with POSIX::SigSet

=head1 VERSION

version 0.009

=head1 SYNOPSIS

 use ExtUtils::Typemaps::SigSet;
 # First, read my own type maps:
 my $private_map = ExtUtils::Typemaps->new(file => 'my.map');

 # Then, get the SigSet typemap and merge it into my maps
 my $map = ExtUtils::Typemaps::SigSet->new;
 $private_map->merge(typemap => $map);

 # Now, write the combined map to an output file
 $private_map->write(file => 'typemap');

=head1 DESCRIPTION

ExtUtils::Typemaps::SigSet is an ExtUtils::Typemaps subclass maps a C<POSIX::SigSet> object into a C<sigset_t*>. Alternatively, it will convert a signal name/number into a signal set.

=head1 AUTHOR

Leon Timmermans <fawaka@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2024 by Leon Timmermans.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
