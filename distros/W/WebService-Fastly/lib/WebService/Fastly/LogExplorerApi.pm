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
package WebService::Fastly::LogExplorerApi;

require 5.6.0;
use strict;
use warnings;
use utf8;
use Exporter;
use Carp qw( croak );
use Log::Any qw($log);

use WebService::Fastly::ApiClient;

use base "Class::Data::Inheritable";

__PACKAGE__->mk_classdata('method_documentation' => {});

sub new {
    my $class = shift;
    my $api_client;

    if ($_[0] && ref $_[0] && ref $_[0] eq 'WebService::Fastly::ApiClient' ) {
        $api_client = $_[0];
    } else {
        $api_client = WebService::Fastly::ApiClient->new(@_);
    }

    bless { api_client => $api_client }, $class;

}


#
# get_log_records
#
# Retrieve log records
#
# @param string $service_id  (required)
# @param string $start  (required)
# @param string $end  (required)
# @param double $limit  (optional)
# @param string $next_cursor  (optional)
# @param string $filter  (optional)
{
    my $params = {
    'service_id' => {
        data_type => 'string',
        description => '',
        required => '1',
    },
    'start' => {
        data_type => 'string',
        description => '',
        required => '1',
    },
    'end' => {
        data_type => 'string',
        description => '',
        required => '1',
    },
    'limit' => {
        data_type => 'double',
        description => '',
        required => '0',
    },
    'next_cursor' => {
        data_type => 'string',
        description => '',
        required => '0',
    },
    'filter' => {
        data_type => 'string',
        description => '',
        required => '0',
    },
    };
    __PACKAGE__->method_documentation->{ 'get_log_records' } = {
        summary => 'Retrieve log records',
        params => $params,
        returns => 'GetLogRecordsResponse',
        };
}
# @return GetLogRecordsResponse
#
sub get_log_records {
    my ($self, %args) = @_;

    # verify the required parameter 'service_id' is set
    unless (exists $args{'service_id'}) {
      croak("Missing the required parameter 'service_id' when calling get_log_records");
    }

    # verify the required parameter 'start' is set
    unless (exists $args{'start'}) {
      croak("Missing the required parameter 'start' when calling get_log_records");
    }

    # verify the required parameter 'end' is set
    unless (exists $args{'end'}) {
      croak("Missing the required parameter 'end' when calling get_log_records");
    }

    # parse inputs
    my $_resource_path = '/observability/log-explorer';

    my $_method = 'GET';
    my $query_params = {};
    my $header_params = {};
    my $form_params = {};

    # 'Accept' and 'Content-Type' header
    my $_header_accept = $self->{api_client}->select_header_accept('application/json');
    if ($_header_accept) {
        $header_params->{'Accept'} = $_header_accept;
    }
    $header_params->{'Content-Type'} = $self->{api_client}->select_header_content_type();

    # query params
    if ( exists $args{'service_id'}) {
        $query_params->{'service_id'} = $self->{api_client}->to_query_value($args{'service_id'});
    }

    # query params
    if ( exists $args{'start'}) {
        $query_params->{'start'} = $self->{api_client}->to_query_value($args{'start'});
    }

    # query params
    if ( exists $args{'end'}) {
        $query_params->{'end'} = $self->{api_client}->to_query_value($args{'end'});
    }

    # query params
    if ( exists $args{'limit'}) {
        $query_params->{'limit'} = $self->{api_client}->to_query_value($args{'limit'});
    }

    # query params
    if ( exists $args{'next_cursor'}) {
        $query_params->{'next_cursor'} = $self->{api_client}->to_query_value($args{'next_cursor'});
    }

    # query params
    if ( exists $args{'filter'}) {
        $query_params->{'filter'} = $self->{api_client}->to_query_value($args{'filter'});
    }

    my $_body_data;
    # authentication setting, if any
    my $auth_settings = [qw(token )];

    # make the API Call
    my $response = $self->{api_client}->call_api($_resource_path, $_method,
                                           $query_params, $form_params,
                                           $header_params, $_body_data, $auth_settings);
    if (!$response) {
        return;
    }
    my $_response_object = $self->{api_client}->deserialize('GetLogRecordsResponse', $response);
    return $_response_object;
}

1;
