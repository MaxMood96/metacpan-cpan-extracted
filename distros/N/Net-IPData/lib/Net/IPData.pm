package Net::IPData;

use strict;
use warnings;
use 5.010001;

our $VERSION = '1.0.0';

use HTTP::Tiny;
use JSON::PP qw(encode_json decode_json);
use Carp qw(croak);
use Scalar::Util qw(blessed);

# API base URLs
use constant {
    BASE_URL    => 'https://api.ipdata.co',
    EU_BASE_URL => 'https://eu-api.ipdata.co',
    MAX_BULK    => 100,
};

# Valid top-level fields for filtering
my %VALID_FIELDS = map { $_ => 1 } qw(
    ip is_eu city region region_code region_type
    country_name country_code continent_name continent_code
    latitude longitude postal calling_code flag
    emoji_flag emoji_unicode asn company carrier
    languages currency time_zone threat count status message
);

# Valid single-field path lookups (fields accessible via /{ip}/{field})
my %PATH_FIELDS = map { $_ => 1 } qw(
    ip is_eu city region region_code region_type
    country_name country_code continent_name continent_code
    latitude longitude postal calling_code flag
    emoji_flag emoji_unicode asn carrier languages
    currency time_zone threat
);

sub new {
    my ($class, %args) = @_;

    my $api_key = $args{api_key}
        or croak 'Required parameter "api_key" is missing';

    my $base_url = $args{base_url};
    if ($args{eu} && !$base_url) {
        $base_url = EU_BASE_URL;
    }
    $base_url //= BASE_URL;
    $base_url =~ s{/+$}{};  # strip trailing slashes

    my $timeout = $args{timeout} // 30;

    my $ua = HTTP::Tiny->new(
        agent           => "Net-IPData-Perl/$VERSION",
        timeout         => $timeout,
        default_headers => {
            'Accept'       => 'application/json',
            'Content-Type' => 'application/json',
        },
    );

    return bless {
        api_key  => $api_key,
        base_url => $base_url,
        ua       => $ua,
        timeout  => $timeout,
    }, $class;
}

# --- Public Methods ---

sub lookup {
    my ($self, $ip, %opts) = @_;

    my $path = defined $ip && length $ip ? "/$ip" : '';
    my @params;

    if (my $fields = $opts{fields}) {
        my @field_list = ref $fields eq 'ARRAY' ? @$fields : split(/\s*,\s*/, $fields);
        _validate_fields(\@field_list);
        push @params, 'fields=' . join(',', @field_list);
    }

    my $url = $self->_build_url($path, @params);
    return $self->_get($url);
}

sub lookup_mine {
    my ($self, %opts) = @_;
    return $self->lookup(undef, %opts);
}

sub lookup_field {
    my ($self, $ip, $field) = @_;

    croak 'Required parameter "ip" is missing'    unless defined $ip && length $ip;
    croak 'Required parameter "field" is missing'  unless defined $field && length $field;
    croak "Invalid field: $field" unless $PATH_FIELDS{$field};

    my $url = $self->_build_url("/$ip/$field");
    return $self->_get($url);
}

sub bulk {
    my ($self, $ips, %opts) = @_;

    croak 'Required parameter "ips" must be an array reference'
        unless ref $ips eq 'ARRAY';
    croak 'Bulk lookup supports a maximum of ' . MAX_BULK . ' IP addresses'
        if @$ips > MAX_BULK;
    croak 'Bulk lookup requires at least one IP address'
        if @$ips == 0;

    my @params;
    if (my $fields = $opts{fields}) {
        my @field_list = ref $fields eq 'ARRAY' ? @$fields : split(/\s*,\s*/, $fields);
        _validate_fields(\@field_list);
        push @params, 'fields=' . join(',', @field_list);
    }

    my $url = $self->_build_url('/bulk', @params);
    return $self->_post($url, $ips);
}

sub asn {
    my ($self, $ip) = @_;
    return $self->lookup_field($ip, 'asn');
}

sub threat {
    my ($self, $ip) = @_;
    return $self->lookup_field($ip, 'threat');
}

sub carrier {
    my ($self, $ip) = @_;
    return $self->lookup_field($ip, 'carrier');
}

sub currency {
    my ($self, $ip) = @_;
    return $self->lookup_field($ip, 'currency');
}

sub time_zone {
    my ($self, $ip) = @_;
    return $self->lookup_field($ip, 'time_zone');
}

sub languages {
    my ($self, $ip) = @_;
    return $self->lookup_field($ip, 'languages');
}

sub country_name {
    my ($self, $ip) = @_;
    return $self->lookup_field($ip, 'country_name');
}

sub country_code {
    my ($self, $ip) = @_;
    return $self->lookup_field($ip, 'country_code');
}

sub is_eu {
    my ($self, $ip) = @_;
    return $self->lookup_field($ip, 'is_eu');
}

# --- Accessors ---

sub api_key  { return $_[0]->{api_key} }
sub base_url { return $_[0]->{base_url} }
sub timeout  { return $_[0]->{timeout} }

# --- Private Methods ---

sub _build_url {
    my ($self, $path, @params) = @_;

    unshift @params, 'api-key=' . $self->{api_key};
    my $query = join('&', @params);

    return $self->{base_url} . ($path // '') . '?' . $query;
}

sub _get {
    my ($self, $url) = @_;

    my $response = $self->{ua}->get($url);
    return $self->_handle_response($response);
}

sub _post {
    my ($self, $url, $data) = @_;

    my $body = encode_json($data);
    my $response = $self->{ua}->post($url, { content => $body });
    return $self->_handle_response($response);
}

sub _handle_response {
    my ($self, $response) = @_;

    my $status  = $response->{status};
    my $content = $response->{content} // '';

    # Network-level failures from HTTP::Tiny (status 599)
    if ($status == 599) {
        croak "Network error: $content";
    }

    # Try to decode JSON
    my $data;
    eval { $data = decode_json($content); };
    if ($@) {
        # Non-JSON response (e.g., single field value like country_name)
        # The API returns bare strings for single-field path lookups
        $content =~ s/^\s+|\s+$//g;    # trim whitespace
        $content =~ s/^"|"$//g;        # strip surrounding quotes

        if ($status >= 200 && $status < 300) {
            return $content;
        }
        croak "HTTP $status: $content";
    }

    # API error responses include a "message" field
    if ($status >= 400) {
        my $message = $data->{message} // "HTTP $status error";
        croak "API error ($status): $message";
    }

    return $data;
}

sub _validate_fields {
    my ($fields) = @_;
    for my $f (@$fields) {
        croak "Invalid field: $f" unless $VALID_FIELDS{$f};
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

Net::IPData - Perl client for the ipdata.co IP geolocation and threat intelligence API

=head1 SYNOPSIS

    use Net::IPData;

    my $ipdata = Net::IPData->new(api_key => 'YOUR_API_KEY');

    # Look up a specific IP address
    my $result = $ipdata->lookup('8.8.8.8');
    printf "IP: %s, Country: %s, City: %s\n",
        $result->{ip}, $result->{country_name}, $result->{city};

    # Look up your own IP address
    my $me = $ipdata->lookup_mine();

    # Request only specific fields
    my $partial = $ipdata->lookup('8.8.8.8', fields => [qw(ip country_name asn)]);

    # Bulk lookup (up to 100 IPs)
    my $results = $ipdata->bulk(['8.8.8.8', '1.1.1.1']);

    # Get a single field directly
    my $asn = $ipdata->asn('8.8.8.8');
    my $threat = $ipdata->threat('8.8.8.8');
    my $country = $ipdata->country_name('8.8.8.8');

    # Use the EU endpoint for GDPR compliance
    my $eu = Net::IPData->new(api_key => 'YOUR_API_KEY', eu => 1);

=head1 DESCRIPTION

Net::IPData provides a Perl interface to the ipdata.co API, which offers
IP geolocation, ASN, company, carrier, threat intelligence, currency,
timezone, and language data for any IPv4 or IPv6 address.

This module uses only Perl core modules (L<HTTP::Tiny>, L<JSON::PP>) and
has no non-core dependencies.

=head1 CONSTRUCTOR

=head2 new

    my $ipdata = Net::IPData->new(
        api_key  => 'YOUR_API_KEY',   # required
        eu       => 0,                # use EU endpoint (default: 0)
        base_url => '...',            # custom base URL (overrides eu)
        timeout  => 30,               # HTTP timeout in seconds (default: 30)
    );

=head1 METHODS

=head2 lookup($ip, %opts)

Look up an IP address. If C<$ip> is omitted or undef, looks up the
caller's IP address.

Options:

=over 4

=item fields => \@fields | $comma_separated_string

Request only the specified fields. Reduces response size.

=back

Returns a hashref of the API response.

=head2 lookup_mine(%opts)

Look up the IP address of the machine making the request. Accepts the
same options as C<lookup>.

=head2 lookup_field($ip, $field)

Retrieve a single field for an IP address via the path-based API
(e.g., C</8.8.8.8/country_name>). Returns the field value directly,
which may be a string, number, boolean, hashref, or arrayref depending
on the field.

=head2 bulk(\@ips, %opts)

Look up multiple IP addresses in a single request (maximum 100). Sends
a POST request to the C</bulk> endpoint. Accepts the same C<fields>
option as C<lookup>.

Returns an arrayref of result hashrefs.

=head2 Convenience Methods

The following methods call C<lookup_field> for common fields:

=over 4

=item asn($ip) - ASN information (hashref)

=item threat($ip) - Threat intelligence (hashref)

=item carrier($ip) - Mobile carrier info (hashref)

=item currency($ip) - Currency data (hashref)

=item time_zone($ip) - Timezone data (hashref)

=item languages($ip) - Language list (arrayref)

=item country_name($ip) - Country name (string)

=item country_code($ip) - Country code (string)

=item is_eu($ip) - EU membership (boolean)

=back

=head1 ACCESSORS

=over 4

=item api_key - The API key

=item base_url - The base URL being used

=item timeout - The HTTP timeout value

=back

=head1 ERROR HANDLING

All methods will C<croak> on errors. Catch them with C<eval> or
L<Try::Tiny>:

    use Try::Tiny;

    try {
        my $result = $ipdata->lookup('invalid');
    } catch {
        warn "API error: $_";
    };

Error messages include the HTTP status code and the API's error message
when available.

=head1 API RESPONSE STRUCTURE

A full lookup returns a hashref with the following keys:

    ip, is_eu, city, region, region_code, region_type,
    country_name, country_code, continent_name, continent_code,
    latitude, longitude, postal, calling_code, flag,
    emoji_flag, emoji_unicode,
    asn      => { asn, name, domain, route, type },
    company  => { name, domain, network, type },
    carrier  => { name, mcc, mnc },
    languages => [{ name, native, code }],
    currency => { name, code, symbol, native, plural },
    time_zone => { name, abbr, offset, is_dst, current_time },
    threat   => { is_tor, is_icloud_relay, is_proxy, is_datacenter,
                  is_anonymous, is_known_attacker, is_known_abuser,
                  is_threat, is_bogon },
    count    => N  (for bulk lookups)

=head1 REQUIREMENTS

Perl 5.10.1 or later. Only core modules are required:

=over 4

=item * L<HTTP::Tiny> (core since Perl 5.14)

=item * L<JSON::PP> (core since Perl 5.14)

=item * L<Carp> (core)

=item * L<Scalar::Util> (core)

=back

=head1 SEE ALSO

L<https://docs.ipdata.co/> - ipdata API documentation

L<https://ipdata.co/> - ipdata website

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 AUTHOR

Net::IPData contributors

=cut
