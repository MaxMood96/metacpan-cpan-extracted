package Locale::CA;

use warnings;
use strict;
use Carp;
use Data::Section::Simple;

=head1 NAME

Locale::CA - two letter codes for province identification in Canada and vice versa

=head1 VERSION

Version 0.08

=cut

our $VERSION = '0.08';

=head1 SYNOPSIS

    use Locale::CA;

    my $u = Locale::CA->new();

    # Returns the French names of the provinces if $LANG starts with 'fr' or
    #	the lang parameter is set to 'fr'
    print $u->{code2province}{'ON'}, "\n";	# prints ONTARIO
    print $u->{province2code}{'ONTARIO'}, "\n";	# prints ON

    my @province = $u->all_province_names();
    my @code = $u->all_province_codes();

=head1 SUBROUTINES/METHODS

=head2 new

Creates a Locale::CA object.

Can be called both as a class method (Locale::CA->new()) and as an object method ($object->new()).

=cut

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;

	# If the class is undefined, fallback to the current package name
	if(!defined($class)) {
		# Use Locale::CA->new(), not Locale::CA::new()
		# Carp::carp(__PACKAGE__, ' use ->new() not ::new() to instantiate');
		# return;

		# FIXME: this only works when no arguments are given
		$class = __PACKAGE__;
	}

	my %params;
	if(ref($_[0]) eq 'HASH') {
		# If the first argument is a hash reference, dereference it
		%params = %{$_[0]};
	} elsif(scalar(@_) % 2 == 0) {
		# If there is an even number of arguments, treat them as key-value pairs
		%params = @_;
	} elsif(scalar(@_) == 1) {
		# If there is one argument, assume the first is 'lang'
		$params{'lang'} = shift;
	} else {
		# If there is an odd number of arguments, treat it as an error
		Carp::croak(__PACKAGE__, ': Invalid arguments passed to new()');
		return;
	}

	# Determine the language and load the corresponding data
	my $data;
	if(defined(my $lang = ($params{'lang'} || _get_language()))) {
		if(($lang eq 'fr') || ($lang eq 'en')) {
			# Load data for the specified language (English or French)
			$data = Data::Section::Simple::get_data_section("provinces_$lang");
		} else {
			# Invalid language specified, throw an error
			Carp::croak("lang can only be one of 'en' or 'fr', given $lang");
		}
	} else {
		# If no language is specified, fallback to English
		$data = Data::Section::Simple::get_data_section('provinces_en');
	}

	# Parse the data into bidirectional mappings
	my $self = {};
	for(split /\n/, $data) {
		my($code, $province) = split /:/;
		# Map codes to provinces
		$self->{code2province}{$code} = $province;
		# Map provinces to codes
		$self->{province2code}{$province} = $code;
	}

	# Bless the hash reference into an object of the specified class
	return bless $self, $class;
}

# https://www.gnu.org/software/gettext/manual/html_node/Locale-Environment-Variables.html
# https://www.gnu.org/software/gettext/manual/html_node/The-LANGUAGE-variable.html
sub _get_language
{
	if(my $language = $ENV{'LANGUAGE'}) {
		foreach my $l(split/:/, $language) {
			if(($l eq 'en') || ($l eq 'fr')) {
				return $l;
			}
		}
	}
	foreach my $variable('LC_ALL', 'LC_MESSAGES', 'LANG') {
		my $val = $ENV{$variable};
		next unless(defined($val));

		$val = substr($val, 0, 2);
		if(($val eq 'en') || ($val eq 'fr')) {
			return $val;
		}
	}
	if(defined($ENV{'LANG'}) && (($ENV{'LANG'} =~ /^C\./) || ($ENV{'LANG'} eq 'C'))) {
		return 'en';
	}
	return;	# undef
}

=head2 all_province_codes

Returns an array (not arrayref) of all province codes in alphabetical form.

=cut

sub all_province_codes {
	my $self = shift;

	return(sort keys %{$self->{code2province}});
}

=head2 all_province_names

Returns an array (not arrayref) of all province names in alphabetical form

=cut

sub all_province_names {
	my $self = shift;

	return(sort keys %{$self->{province2code}});
}

=head2 $self->{code2province}

This is a hashref which has two-letter province names as the key and the long
name as the value.

=head2 $self->{province2code}

This is a hashref which has the long name as the key and the two-letter
province name as the value.

=head1 SEE ALSO

L<Locale::Country>

=head1 AUTHOR

Nigel Horne, C<< <njh at bandsman.co.uk> >>

=head1 BUGS

=over 4

=item * The province name is returned in C<uc()> format.

=item * neither hash is strict, though they should be.

=back

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Locale::CA

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Locale-CA>

=item * Search CPAN

L<http://search.cpan.org/dist/Locale-CA/>

=back

=head1 ACKNOWLEDGEMENTS

Based on L<Locale::US> - Copyright (c) 2002 - C<< $present >> Terrence Brannon.

=head1 LICENSE AND COPYRIGHT

Copyright 2012-2025 Nigel Horne.

This program is released under the following licence: GPL2

=cut

1; # End of Locale::CA

# Put the one you want to expand in code2province second
#	so it overwrites the other when it's loaded

__DATA__
@@ provinces_en
AB:ALBT.
AB:ALBERTA
BC:BRITISH COLUMBIA
MB:MANITOBA
NB:NEW BRUNSWICK
NL:NEWFOUNDLAND
NL:NEWFOUNDLAND AND LABRADOR
NT:NORTHWEST TERRITORIES
NS:NOVA SCOTIA
ON:ONTARIO
PE:PRINCE EDWARD ISLAND
QC:QUEBEC
SK:SASKATCHEWAN
YT:YUKON
@@ provinces_fr
AB:ALBT.
AB:ALTA.
AB:ALBERTA
BC:COLOMBIE-BRITANNIQUE
MB:MANITOBA
NB:NOUVEAU-BRUNSWICK
NL:TERRE-NEUVE
NL:TERRE-NEUVE-ET-LABRADOR
NT:TERRITOIRES DU NORD-OUEST
NS:NOUVELLE-ÉCOSSE
ON:ONTARIO
PE:ÎLE-DU-PRINCE-ÉDOUARD
QC:QUÉBEC
SK:SASKATCHEWAN
YT:YUKON
__END__
