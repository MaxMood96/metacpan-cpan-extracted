=begin comment

Fastly API

Via the Fastly API you can perform any of the operations that are possible within the management console,  including creating services, domains, and backends, configuring rules or uploading your own application code, as well as account operations such as user administration and billing reports. The API is organized into collections of endpoints that allow manipulation of objects related to Fastly services and accounts. For the most accurate and up-to-date API reference content, visit our [Developer Hub](https://www.fastly.com/documentation/reference/api/) 

The version of the API Spec document: 1.0.0
Contact: oss@fastly.com

=end comment

=cut

#
# NOTE: This class is auto generated.
# Do not edit the class manually.
#
package WebService::Fastly::Object::PoolAdditional;

require 5.6.0;
use strict;
use warnings;
use utf8;
use JSON::MaybeXS qw(decode_json);
use Data::Dumper;
use Module::Runtime qw(use_module);
use Log::Any qw($log);
use Date::Parse;
use DateTime;


use base ("Class::Accessor", "Class::Data::Inheritable");

#
#
#
# NOTE: This class is auto generated. Do not edit the class manually.
#

=begin comment

Fastly API

Via the Fastly API you can perform any of the operations that are possible within the management console,  including creating services, domains, and backends, configuring rules or uploading your own application code, as well as account operations such as user administration and billing reports. The API is organized into collections of endpoints that allow manipulation of objects related to Fastly services and accounts. For the most accurate and up-to-date API reference content, visit our [Developer Hub](https://www.fastly.com/documentation/reference/api/) 

The version of the API Spec document: 1.0.0
Contact: oss@fastly.com

=end comment

=cut

#
# NOTE: This class is auto generated.
# Do not edit the class manually.
#
__PACKAGE__->mk_classdata('attribute_map' => {});
__PACKAGE__->mk_classdata('openapi_types' => {});
__PACKAGE__->mk_classdata('method_documentation' => {});
__PACKAGE__->mk_classdata('class_documentation' => {});
__PACKAGE__->mk_classdata('openapi_nullable' => {});

# new plain object
sub new {
    my ($class, %args) = @_;

    my $self = bless {}, $class;

    $self->init(%args);

    return $self;
}

# initialize the object
sub init
{
    my ($self, %args) = @_;

    foreach my $attribute (keys %{$self->attribute_map}) {
        my $args_key = $self->attribute_map->{$attribute};
        $self->$attribute( $args{ $args_key } );
    }
}

# return perl hash
sub to_hash {
    my $self = shift;
    my $_hash = decode_json(JSON()->new->allow_blessed->convert_blessed->encode($self));

    return $_hash;
}

# used by JSON for serialization
sub TO_JSON {
    my $self = shift;
    my $_data = {};
    foreach my $_key (keys %{$self->attribute_map}) {
        $_data->{$self->attribute_map->{$_key}} = $self->{$_key};
    }

    return $_data;
}

# from Perl hashref
sub from_hash {
    my ($self, $hash) = @_;

    # loop through attributes and use openapi_types to deserialize the data
    while ( my ($_key, $_type) = each %{$self->openapi_types} ) {
        my $_json_attribute = $self->attribute_map->{$_key};
        my $_is_nullable = ($self->openapi_nullable->{$_key} || 'false') eq 'true';
        if ($_type =~ /^array\[(.+)\]$/i) { # array
            my $_subclass = $1;
            my @_array = ();
            foreach my $_element (@{$hash->{$_json_attribute}}) {
                push @_array, $self->_deserialize($_subclass, $_element, $_is_nullable);
            }
            $self->{$_key} = \@_array;
        } elsif ($_type =~ /^hash\[string,(.+)\]$/i) { # hash
            my $_subclass = $1;
            my %_hash = ();
            while (my($_key, $_element) = each %{$hash->{$_json_attribute}}) {
                $_hash{$_key} = $self->_deserialize($_subclass, $_element, $_is_nullable);
            }
            $self->{$_key} = \%_hash;
        } elsif (exists $hash->{$_json_attribute}) { #hash(model), primitive, datetime
            $self->{$_key} = $self->_deserialize($_type, $hash->{$_json_attribute}, $_is_nullable);
        } else {
            $log->debugf("Warning: %s (%s) does not exist in input hash\n", $_key, $_json_attribute);
        }
    }

    return $self;
}

# deserialize non-array data
sub _deserialize {
    my ($self, $type, $data, $is_nullable) = @_;
    $log->debugf("deserializing %s with %s",Dumper($data), $type);

    if (!(defined $data) && $is_nullable) {
        return undef;
    }
    if ($type eq 'DateTime') {
        return DateTime->from_epoch(epoch => str2time($data));
    } elsif ( grep( /^$type$/, ('int', 'double', 'string', 'boolean'))) {
        return $data;
    } else { # hash(model)
        my $_instance = eval "WebService::Fastly::Object::$type->new()";
        return $_instance->from_hash($data);
    }
}


__PACKAGE__->class_documentation({description => '',
                                  class => 'PoolAdditional',
                                  required => [], # TODO
}                                 );

__PACKAGE__->method_documentation({
    'name' => {
        datatype => 'string',
        base_name => 'name',
        description => 'Name for the Pool.',
        format => '',
        read_only => 'false',
            },
    'shield' => {
        datatype => 'string',
        base_name => 'shield',
        description => 'Selected POP to serve as a shield for the servers. Defaults to &#x60;null&#x60; meaning no origin shielding if not set. Refer to the [POPs API endpoint](https://www.fastly.com/documentation/reference/api/utils/pops/) to get a list of available POPs used for shielding.',
        format => '',
        read_only => 'false',
            },
    'request_condition' => {
        datatype => 'string',
        base_name => 'request_condition',
        description => 'Condition which, if met, will select this configuration during a request. Optional.',
        format => '',
        read_only => 'false',
            },
    'tls_ciphers' => {
        datatype => 'string',
        base_name => 'tls_ciphers',
        description => 'List of OpenSSL ciphers (see the [openssl.org manpages](https://www.openssl.org/docs/man1.1.1/man1/ciphers.html) for details). Optional.',
        format => '',
        read_only => 'false',
            },
    'tls_sni_hostname' => {
        datatype => 'string',
        base_name => 'tls_sni_hostname',
        description => 'SNI hostname. Optional.',
        format => '',
        read_only => 'false',
            },
    'min_tls_version' => {
        datatype => 'int',
        base_name => 'min_tls_version',
        description => 'Minimum allowed TLS version on connections to this server. Optional.',
        format => '',
        read_only => 'false',
            },
    'max_tls_version' => {
        datatype => 'int',
        base_name => 'max_tls_version',
        description => 'Maximum allowed TLS version on connections to this server. Optional.',
        format => '',
        read_only => 'false',
            },
    'healthcheck' => {
        datatype => 'string',
        base_name => 'healthcheck',
        description => 'Name of the healthcheck to use with this pool. Can be empty and could be reused across multiple backend and pools.',
        format => '',
        read_only => 'false',
            },
    'comment' => {
        datatype => 'string',
        base_name => 'comment',
        description => 'A freeform descriptive note.',
        format => '',
        read_only => 'false',
            },
    'type' => {
        datatype => 'string',
        base_name => 'type',
        description => 'What type of load balance group to use.',
        format => '',
        read_only => 'false',
            },
    'override_host' => {
        datatype => 'string',
        base_name => 'override_host',
        description => 'The hostname to [override the Host header](https://www.fastly.com/documentation/guides/full-site-delivery/domains-and-origins/specifying-an-override-host/). Defaults to &#x60;null&#x60; meaning no override of the Host header will occur. This setting can also be added to a Server definition. If the field is set on a Server definition it will override the Pool setting.',
        format => '',
        read_only => 'false',
            },
});

__PACKAGE__->openapi_types( {
    'name' => 'string',
    'shield' => 'string',
    'request_condition' => 'string',
    'tls_ciphers' => 'string',
    'tls_sni_hostname' => 'string',
    'min_tls_version' => 'int',
    'max_tls_version' => 'int',
    'healthcheck' => 'string',
    'comment' => 'string',
    'type' => 'string',
    'override_host' => 'string'
} );

__PACKAGE__->attribute_map( {
    'name' => 'name',
    'shield' => 'shield',
    'request_condition' => 'request_condition',
    'tls_ciphers' => 'tls_ciphers',
    'tls_sni_hostname' => 'tls_sni_hostname',
    'min_tls_version' => 'min_tls_version',
    'max_tls_version' => 'max_tls_version',
    'healthcheck' => 'healthcheck',
    'comment' => 'comment',
    'type' => 'type',
    'override_host' => 'override_host'
} );

__PACKAGE__->mk_accessors(keys %{__PACKAGE__->attribute_map});

__PACKAGE__->openapi_nullable( {
    'shield' => 'true',
    'request_condition' => 'true',
    'tls_ciphers' => 'true',
    'tls_sni_hostname' => 'true',
    'min_tls_version' => 'true',
    'max_tls_version' => 'true',
    'healthcheck' => 'true',
    'comment' => 'true',
    'override_host' => 'true',
} );


1;
