package Geo::Coder::CA;

# See also https://geocoding.geo.census.gov/geocoder/Geocoding_Services_API.html for the US for the future

use strict;
use warnings;

use Carp;
use Encode;
use JSON::MaybeXS;
use LWP::UserAgent;
use URI;

=head1 NAME

Geo::Coder::CA - Provides a Geo-Coding functionality using L<https://geocoder.ca> for both Canada and the US.

=head1 VERSION

Version 0.15

=cut

our $VERSION = '0.15';

=head1 SYNOPSIS

      use Geo::Coder::CA;

      my $geo_coder = Geo::Coder::CA->new();
      my $location = $geo_coder->geocode(location => '9235 Main St, Richibucto, New Brunswick, Canada');

=head1 DESCRIPTION

Geo::Coder::CA provides an interface to geocoder.ca.
L<Geo::Coder::Canada> no longer seems to work.

=head1 METHODS

=head2 new

    $geo_coder = Geo::Coder::CA->new();
    my $ua = LWP::UserAgent->new();
    $ua->env_proxy(1);
    $geo_coder = Geo::Coder::CA->new(ua => $ua);

=cut

sub new {
	my($class, %args) = @_;

	if(!defined($class)) {
		# Geo::Coder::CA::new() used rather than Geo::Coder::CA->new()
		$class = __PACKAGE__;
	} elsif(ref($class)) {
		# clone the given object
		return bless { %{$class}, %args }, ref($class);
	}

	my $ua = $args{ua};
	if(!defined($ua)) {
		$ua = LWP::UserAgent->new(agent => __PACKAGE__ . "/$VERSION");
		$ua->default_header(accept_encoding => 'gzip,deflate');
	}
	my $host = $args{host} || 'geocoder.ca';

	return bless { ua => $ua, host => $host }, $class;
}

=head2 geocode

    $location = $geo_coder->geocode(location => $location);
    # @location = $geo_coder->geocode(location => $location);

    print 'Latitude: ', $location->{'latt'}, "\n";
    print 'Longitude: ', $location->{'longt'}, "\n";

=cut

sub geocode {
	my $self = shift;
	my $params = $self->_get_params('location', @_);

	my $location = $params->{location};
	if((!defined($location)) || (length($location) == 0)) {
		Carp::croak('Usage: geocode(location => $location)');
		return;
	}

	# Fail when the input is just a set of numbers
	if($params->{'location'} !~ /\D/) {
		Carp::croak('Usage: ', __PACKAGE__, ': invalid input to geocode(), ', $params->{location});
		return;
	}

	if (Encode::is_utf8($location)) {
		$location = Encode::encode_utf8($location);
	}

	my $uri = URI->new("https://$self->{host}/some_location");
	$location =~ s/\s/+/g;
	my %query_parameters = ('locate' => $location, 'json' => 1, 'strictmode' => 1);
	$uri->query_form(%query_parameters);
	my $url = $uri->as_string();

	my $res = $self->{ua}->get($url);

	if($res->is_error()) {
		Carp::carp("$url API returned error: ", $res->status_line());
		return;
	}
	# $res->content_type('text/plain');	# May be needed to decode correctly

	my $json = JSON::MaybeXS->new()->utf8();
	if(my $rc = $json->decode($res->decoded_content())) {
		if($rc->{'error'}) {
			# Sorry - you lose the error code, but HTML::GoogleMaps::V3 relies on this
			# TODO - send patch to the H:G:V3 author
			return;
		}
		if(defined($rc->{'latt'}) && defined($rc->{'longt'})) {
			return $rc;	# No support for list context, yet
		}

		# if($location =~ /^(\w+),\+*(\w+),\+*(USA|US|United States)$/i) {
			# $query_parameters{'locate'} = "$1 County, $2, $3";
			# $uri->query_form(%query_parameters);
			# $url = $uri->as_string();
			#
			# $res = $self->{ua}->get($url);
			#
			# if($res->is_error()) {
				# Carp::croak("geocoder.ca API returned error: " . $res->status_line());
				# return;
			# }
			# return $json->decode($res->content());
		# }
	}

	# my @results = @{ $data || [] };
	# wantarray ? @results : $results[0];
}

=head2 ua

Accessor method to get and set UserAgent object used internally. You
can call I<env_proxy> for example, to get the proxy information from
environment variables:

    $geo_coder->ua()->env_proxy(1);

You can also set your own User-Agent object:

    my $ua = LWP::UserAgent::Throttled->new();
    $ua->throttle('geocoder.ca' => 1);
    $geo_coder->ua($ua);

=cut

sub ua {
	my $self = shift;
	if (@_) {
		$self->{ua} = shift;
	}
	$self->{ua};
}

=head2 reverse_geocode

    $location = $geo_coder->reverse_geocode(latlng => '37.778907,-122.39732');

Similar to geocode except it expects a latitude/longitude parameter.

=cut

sub reverse_geocode {
	my $self = shift;
	my $params = $self->_get_params('latlng', @_);

	my $latlng = $params->{latlng}
		or Carp::croak('Usage: reverse_geocode(latlng => $latlng)');

	return $self->geocode(location => $latlng, reverse => 1);
}

=head2 run

You can also run this module from the command line:

    perl CA.pm 1600 Pennsylvania Avenue NW, Washington DC

=cut

__PACKAGE__->run(@ARGV) unless caller();

sub run {
	require Data::Dumper;

	my $class = shift;

	my $location = join(' ', @_);

	my @rc = $class->new()->geocode($location);

	if(scalar(@rc)) {
		print Data::Dumper->new([\@rc])->Dump();
	} else {
		die "$0: geo-coding failed";
	}
}

# Helper routine to parse the arguments given to a function.
# Processes arguments passed to methods and ensures they are in a usable format,
#	allowing the caller to call the function in anyway that they want
#	e.g. foo('bar'), foo(arg => 'bar'), foo({ arg => 'bar' }) all mean the same
#	when called _get_params('arg', @_);
sub _get_params
{
	shift;  # Discard the first argument (typically $self)
	my $default = shift;

	# Directly return hash reference if the first parameter is a hash reference
	return $_[0] if(ref $_[0] eq 'HASH');

	my %rc;
	my $num_args = scalar @_;

	# Populate %rc based on the number and type of arguments
	if(($num_args == 1) && (defined $default)) {
		# %rc = ($default => shift);
		return { $default => shift };
	} elsif($num_args == 1) {
		Carp::croak('Usage: ', __PACKAGE__, '->', (caller(1))[3], '()');
	} elsif(($num_args == 0) && (defined($default))) {
		Carp::croak('Usage: ', __PACKAGE__, '->', (caller(1))[3], "($default => \$val)");
	} elsif(($num_args % 2) == 0) {
		%rc = @_;
	} elsif($num_args == 0) {
		return;
	} else {
		Carp::croak('Usage: ', __PACKAGE__, '->', (caller(1))[3], '()');
	}

	return \%rc;
}
=head1 AUTHOR

Nigel Horne, C<< <njh@bandsman.co.uk> >>

Based on L<Geo::Coder::Googleplaces>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

Lots of thanks to the folks at geocoder.ca.

=head1 BUGS

Please report any bugs or feature requests to the author.
This module is provided as-is without any warranty.

Should be called Geo::Coder::NA for North America.

=head1 SEE ALSO

L<Geo::Coder::GooglePlaces>, L<HTML::GoogleMaps::V3>

=head1 LICENSE AND COPYRIGHT

Copyright 2017-2025 Nigel Horne.

This program is released under the following licence: GPL2

=cut

1;
