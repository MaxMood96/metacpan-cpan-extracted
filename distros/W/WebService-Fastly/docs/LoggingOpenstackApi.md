# WebService::Fastly::LoggingOpenstackApi

## Load the API package
```perl
use WebService::Fastly::Object::LoggingOpenstackApi;
```

> [!NOTE]
> All URIs are relative to `https://api.fastly.com`

Method | HTTP request | Description
------ | ------------ | -----------
[**create_log_openstack**](LoggingOpenstackApi.md#create_log_openstack) | **POST** /service/{service_id}/version/{version_id}/logging/openstack | Create an OpenStack log endpoint
[**delete_log_openstack**](LoggingOpenstackApi.md#delete_log_openstack) | **DELETE** /service/{service_id}/version/{version_id}/logging/openstack/{logging_openstack_name} | Delete an OpenStack log endpoint
[**get_log_openstack**](LoggingOpenstackApi.md#get_log_openstack) | **GET** /service/{service_id}/version/{version_id}/logging/openstack/{logging_openstack_name} | Get an OpenStack log endpoint
[**list_log_openstack**](LoggingOpenstackApi.md#list_log_openstack) | **GET** /service/{service_id}/version/{version_id}/logging/openstack | List OpenStack log endpoints
[**update_log_openstack**](LoggingOpenstackApi.md#update_log_openstack) | **PUT** /service/{service_id}/version/{version_id}/logging/openstack/{logging_openstack_name} | Update an OpenStack log endpoint


# **create_log_openstack**
> LoggingOpenstackResponse create_log_openstack(service_id => $service_id, version_id => $version_id, name => $name, placement => $placement, response_condition => $response_condition, format => $format, log_processing_region => $log_processing_region, format_version => $format_version, message_type => $message_type, timestamp_format => $timestamp_format, compression_codec => $compression_codec, period => $period, gzip_level => $gzip_level, access_key => $access_key, bucket_name => $bucket_name, path => $path, public_key => $public_key, url => $url, user => $user)

Create an OpenStack log endpoint

Create a openstack for a particular service and version.

### Example
```perl
use Data::Dumper;
use WebService::Fastly::LoggingOpenstackApi;
my $api_instance = WebService::Fastly::LoggingOpenstackApi->new(

    # Configure API key authorization: token
    api_key => {'Fastly-Key' => 'YOUR_API_KEY'},
    # uncomment below to setup prefix (e.g. Bearer) for API key, if needed
    #api_key_prefix => {'Fastly-Key' => 'Bearer'},
);

my $service_id = "service_id_example"; # string | Alphanumeric string identifying the service.
my $version_id = 56; # int | Integer identifying a service version.
my $name = "name_example"; # string | The name for the real-time logging configuration.
my $placement = "placement_example"; # string | Where in the generated VCL the logging call should be placed. If not set, endpoints with `format_version` of 2 are placed in `vcl_log` and those with `format_version` of 1 are placed in `vcl_deliver`. 
my $response_condition = "response_condition_example"; # string | The name of an existing condition in the configured endpoint, or leave blank to always execute.
my $format = '%h %l %u %t "%r" %&gt;s %b'; # string | A Fastly [log format string](https://www.fastly.com/documentation/guides/integrations/streaming-logs/custom-log-formats/).
my $log_processing_region = 'none'; # string | The geographic region where the logs will be processed before streaming. Valid values are `us`, `eu`, and `none` for global.
my $format_version = 2; # int | The version of the custom logging format used for the configured endpoint. The logging call gets placed by default in `vcl_log` if `format_version` is set to `2` and in `vcl_deliver` if `format_version` is set to `1`. 
my $message_type = 'classic'; # string | How the message should be formatted.
my $timestamp_format = "timestamp_format_example"; # string | A timestamp format
my $compression_codec = "compression_codec_example"; # string | The codec used for compressing your logs. Valid values are `zstd`, `snappy`, and `gzip`. Specifying both `compression_codec` and `gzip_level` in the same API request will result in an error.
my $period = 3600; # int | How frequently log files are finalized so they can be available for reading (in seconds).
my $gzip_level = 0; # int | The level of gzip encoding when sending logs (default `0`, no compression). Specifying both `compression_codec` and `gzip_level` in the same API request will result in an error.
my $access_key = "access_key_example"; # string | Your OpenStack account access key.
my $bucket_name = "bucket_name_example"; # string | The name of your OpenStack container.
my $path = 'null'; # string | The path to upload logs to.
my $public_key = 'null'; # string | A PGP public key that Fastly will use to encrypt your log files before writing them to disk.
my $url = "url_example"; # string | Your OpenStack auth url.
my $user = "user_example"; # string | The username for your OpenStack account.

eval {
    my $result = $api_instance->create_log_openstack(service_id => $service_id, version_id => $version_id, name => $name, placement => $placement, response_condition => $response_condition, format => $format, log_processing_region => $log_processing_region, format_version => $format_version, message_type => $message_type, timestamp_format => $timestamp_format, compression_codec => $compression_codec, period => $period, gzip_level => $gzip_level, access_key => $access_key, bucket_name => $bucket_name, path => $path, public_key => $public_key, url => $url, user => $user);
    print Dumper($result);
};
if ($@) {
    warn "Exception when calling LoggingOpenstackApi->create_log_openstack: $@\n";
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **service_id** | **string**| Alphanumeric string identifying the service. | 
 **version_id** | **int**| Integer identifying a service version. | 
 **name** | **string**| The name for the real-time logging configuration. | [optional] 
 **placement** | **string**| Where in the generated VCL the logging call should be placed. If not set, endpoints with `format_version` of 2 are placed in `vcl_log` and those with `format_version` of 1 are placed in `vcl_deliver`.  | [optional] 
 **response_condition** | **string**| The name of an existing condition in the configured endpoint, or leave blank to always execute. | [optional] 
 **format** | **string**| A Fastly [log format string](https://www.fastly.com/documentation/guides/integrations/streaming-logs/custom-log-formats/). | [optional] [default to &#39;%h %l %u %t &quot;%r&quot; %&amp;gt;s %b&#39;]
 **log_processing_region** | **string**| The geographic region where the logs will be processed before streaming. Valid values are `us`, `eu`, and `none` for global. | [optional] [default to &#39;none&#39;]
 **format_version** | **int**| The version of the custom logging format used for the configured endpoint. The logging call gets placed by default in `vcl_log` if `format_version` is set to `2` and in `vcl_deliver` if `format_version` is set to `1`.  | [optional] [default to 2]
 **message_type** | **string**| How the message should be formatted. | [optional] [default to &#39;classic&#39;]
 **timestamp_format** | **string**| A timestamp format | [optional] 
 **compression_codec** | **string**| The codec used for compressing your logs. Valid values are `zstd`, `snappy`, and `gzip`. Specifying both `compression_codec` and `gzip_level` in the same API request will result in an error. | [optional] 
 **period** | **int**| How frequently log files are finalized so they can be available for reading (in seconds). | [optional] [default to 3600]
 **gzip_level** | **int**| The level of gzip encoding when sending logs (default `0`, no compression). Specifying both `compression_codec` and `gzip_level` in the same API request will result in an error. | [optional] [default to 0]
 **access_key** | **string**| Your OpenStack account access key. | [optional] 
 **bucket_name** | **string**| The name of your OpenStack container. | [optional] 
 **path** | **string**| The path to upload logs to. | [optional] [default to &#39;null&#39;]
 **public_key** | **string**| A PGP public key that Fastly will use to encrypt your log files before writing them to disk. | [optional] [default to &#39;null&#39;]
 **url** | **string**| Your OpenStack auth url. | [optional] 
 **user** | **string**| The username for your OpenStack account. | [optional] 

### Return type

[**LoggingOpenstackResponse**](LoggingOpenstackResponse.md)

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: application/x-www-form-urlencoded
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **delete_log_openstack**
> InlineResponse200 delete_log_openstack(service_id => $service_id, version_id => $version_id, logging_openstack_name => $logging_openstack_name)

Delete an OpenStack log endpoint

Delete the openstack for a particular service and version.

### Example
```perl
use Data::Dumper;
use WebService::Fastly::LoggingOpenstackApi;
my $api_instance = WebService::Fastly::LoggingOpenstackApi->new(

    # Configure API key authorization: token
    api_key => {'Fastly-Key' => 'YOUR_API_KEY'},
    # uncomment below to setup prefix (e.g. Bearer) for API key, if needed
    #api_key_prefix => {'Fastly-Key' => 'Bearer'},
);

my $service_id = "service_id_example"; # string | Alphanumeric string identifying the service.
my $version_id = 56; # int | Integer identifying a service version.
my $logging_openstack_name = "logging_openstack_name_example"; # string | The name for the real-time logging configuration.

eval {
    my $result = $api_instance->delete_log_openstack(service_id => $service_id, version_id => $version_id, logging_openstack_name => $logging_openstack_name);
    print Dumper($result);
};
if ($@) {
    warn "Exception when calling LoggingOpenstackApi->delete_log_openstack: $@\n";
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **service_id** | **string**| Alphanumeric string identifying the service. | 
 **version_id** | **int**| Integer identifying a service version. | 
 **logging_openstack_name** | **string**| The name for the real-time logging configuration. | 

### Return type

[**InlineResponse200**](InlineResponse200.md)

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **get_log_openstack**
> LoggingOpenstackResponse get_log_openstack(service_id => $service_id, version_id => $version_id, logging_openstack_name => $logging_openstack_name)

Get an OpenStack log endpoint

Get the openstack for a particular service and version.

### Example
```perl
use Data::Dumper;
use WebService::Fastly::LoggingOpenstackApi;
my $api_instance = WebService::Fastly::LoggingOpenstackApi->new(

    # Configure API key authorization: token
    api_key => {'Fastly-Key' => 'YOUR_API_KEY'},
    # uncomment below to setup prefix (e.g. Bearer) for API key, if needed
    #api_key_prefix => {'Fastly-Key' => 'Bearer'},
);

my $service_id = "service_id_example"; # string | Alphanumeric string identifying the service.
my $version_id = 56; # int | Integer identifying a service version.
my $logging_openstack_name = "logging_openstack_name_example"; # string | The name for the real-time logging configuration.

eval {
    my $result = $api_instance->get_log_openstack(service_id => $service_id, version_id => $version_id, logging_openstack_name => $logging_openstack_name);
    print Dumper($result);
};
if ($@) {
    warn "Exception when calling LoggingOpenstackApi->get_log_openstack: $@\n";
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **service_id** | **string**| Alphanumeric string identifying the service. | 
 **version_id** | **int**| Integer identifying a service version. | 
 **logging_openstack_name** | **string**| The name for the real-time logging configuration. | 

### Return type

[**LoggingOpenstackResponse**](LoggingOpenstackResponse.md)

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **list_log_openstack**
> ARRAY[LoggingOpenstackResponse] list_log_openstack(service_id => $service_id, version_id => $version_id)

List OpenStack log endpoints

List all of the openstacks for a particular service and version.

### Example
```perl
use Data::Dumper;
use WebService::Fastly::LoggingOpenstackApi;
my $api_instance = WebService::Fastly::LoggingOpenstackApi->new(

    # Configure API key authorization: token
    api_key => {'Fastly-Key' => 'YOUR_API_KEY'},
    # uncomment below to setup prefix (e.g. Bearer) for API key, if needed
    #api_key_prefix => {'Fastly-Key' => 'Bearer'},
);

my $service_id = "service_id_example"; # string | Alphanumeric string identifying the service.
my $version_id = 56; # int | Integer identifying a service version.

eval {
    my $result = $api_instance->list_log_openstack(service_id => $service_id, version_id => $version_id);
    print Dumper($result);
};
if ($@) {
    warn "Exception when calling LoggingOpenstackApi->list_log_openstack: $@\n";
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **service_id** | **string**| Alphanumeric string identifying the service. | 
 **version_id** | **int**| Integer identifying a service version. | 

### Return type

[**ARRAY[LoggingOpenstackResponse]**](LoggingOpenstackResponse.md)

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **update_log_openstack**
> LoggingOpenstackResponse update_log_openstack(service_id => $service_id, version_id => $version_id, logging_openstack_name => $logging_openstack_name, name => $name, placement => $placement, response_condition => $response_condition, format => $format, log_processing_region => $log_processing_region, format_version => $format_version, message_type => $message_type, timestamp_format => $timestamp_format, compression_codec => $compression_codec, period => $period, gzip_level => $gzip_level, access_key => $access_key, bucket_name => $bucket_name, path => $path, public_key => $public_key, url => $url, user => $user)

Update an OpenStack log endpoint

Update the openstack for a particular service and version.

### Example
```perl
use Data::Dumper;
use WebService::Fastly::LoggingOpenstackApi;
my $api_instance = WebService::Fastly::LoggingOpenstackApi->new(

    # Configure API key authorization: token
    api_key => {'Fastly-Key' => 'YOUR_API_KEY'},
    # uncomment below to setup prefix (e.g. Bearer) for API key, if needed
    #api_key_prefix => {'Fastly-Key' => 'Bearer'},
);

my $service_id = "service_id_example"; # string | Alphanumeric string identifying the service.
my $version_id = 56; # int | Integer identifying a service version.
my $logging_openstack_name = "logging_openstack_name_example"; # string | The name for the real-time logging configuration.
my $name = "name_example"; # string | The name for the real-time logging configuration.
my $placement = "placement_example"; # string | Where in the generated VCL the logging call should be placed. If not set, endpoints with `format_version` of 2 are placed in `vcl_log` and those with `format_version` of 1 are placed in `vcl_deliver`. 
my $response_condition = "response_condition_example"; # string | The name of an existing condition in the configured endpoint, or leave blank to always execute.
my $format = '%h %l %u %t "%r" %&gt;s %b'; # string | A Fastly [log format string](https://www.fastly.com/documentation/guides/integrations/streaming-logs/custom-log-formats/).
my $log_processing_region = 'none'; # string | The geographic region where the logs will be processed before streaming. Valid values are `us`, `eu`, and `none` for global.
my $format_version = 2; # int | The version of the custom logging format used for the configured endpoint. The logging call gets placed by default in `vcl_log` if `format_version` is set to `2` and in `vcl_deliver` if `format_version` is set to `1`. 
my $message_type = 'classic'; # string | How the message should be formatted.
my $timestamp_format = "timestamp_format_example"; # string | A timestamp format
my $compression_codec = "compression_codec_example"; # string | The codec used for compressing your logs. Valid values are `zstd`, `snappy`, and `gzip`. Specifying both `compression_codec` and `gzip_level` in the same API request will result in an error.
my $period = 3600; # int | How frequently log files are finalized so they can be available for reading (in seconds).
my $gzip_level = 0; # int | The level of gzip encoding when sending logs (default `0`, no compression). Specifying both `compression_codec` and `gzip_level` in the same API request will result in an error.
my $access_key = "access_key_example"; # string | Your OpenStack account access key.
my $bucket_name = "bucket_name_example"; # string | The name of your OpenStack container.
my $path = 'null'; # string | The path to upload logs to.
my $public_key = 'null'; # string | A PGP public key that Fastly will use to encrypt your log files before writing them to disk.
my $url = "url_example"; # string | Your OpenStack auth url.
my $user = "user_example"; # string | The username for your OpenStack account.

eval {
    my $result = $api_instance->update_log_openstack(service_id => $service_id, version_id => $version_id, logging_openstack_name => $logging_openstack_name, name => $name, placement => $placement, response_condition => $response_condition, format => $format, log_processing_region => $log_processing_region, format_version => $format_version, message_type => $message_type, timestamp_format => $timestamp_format, compression_codec => $compression_codec, period => $period, gzip_level => $gzip_level, access_key => $access_key, bucket_name => $bucket_name, path => $path, public_key => $public_key, url => $url, user => $user);
    print Dumper($result);
};
if ($@) {
    warn "Exception when calling LoggingOpenstackApi->update_log_openstack: $@\n";
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **service_id** | **string**| Alphanumeric string identifying the service. | 
 **version_id** | **int**| Integer identifying a service version. | 
 **logging_openstack_name** | **string**| The name for the real-time logging configuration. | 
 **name** | **string**| The name for the real-time logging configuration. | [optional] 
 **placement** | **string**| Where in the generated VCL the logging call should be placed. If not set, endpoints with `format_version` of 2 are placed in `vcl_log` and those with `format_version` of 1 are placed in `vcl_deliver`.  | [optional] 
 **response_condition** | **string**| The name of an existing condition in the configured endpoint, or leave blank to always execute. | [optional] 
 **format** | **string**| A Fastly [log format string](https://www.fastly.com/documentation/guides/integrations/streaming-logs/custom-log-formats/). | [optional] [default to &#39;%h %l %u %t &quot;%r&quot; %&amp;gt;s %b&#39;]
 **log_processing_region** | **string**| The geographic region where the logs will be processed before streaming. Valid values are `us`, `eu`, and `none` for global. | [optional] [default to &#39;none&#39;]
 **format_version** | **int**| The version of the custom logging format used for the configured endpoint. The logging call gets placed by default in `vcl_log` if `format_version` is set to `2` and in `vcl_deliver` if `format_version` is set to `1`.  | [optional] [default to 2]
 **message_type** | **string**| How the message should be formatted. | [optional] [default to &#39;classic&#39;]
 **timestamp_format** | **string**| A timestamp format | [optional] 
 **compression_codec** | **string**| The codec used for compressing your logs. Valid values are `zstd`, `snappy`, and `gzip`. Specifying both `compression_codec` and `gzip_level` in the same API request will result in an error. | [optional] 
 **period** | **int**| How frequently log files are finalized so they can be available for reading (in seconds). | [optional] [default to 3600]
 **gzip_level** | **int**| The level of gzip encoding when sending logs (default `0`, no compression). Specifying both `compression_codec` and `gzip_level` in the same API request will result in an error. | [optional] [default to 0]
 **access_key** | **string**| Your OpenStack account access key. | [optional] 
 **bucket_name** | **string**| The name of your OpenStack container. | [optional] 
 **path** | **string**| The path to upload logs to. | [optional] [default to &#39;null&#39;]
 **public_key** | **string**| A PGP public key that Fastly will use to encrypt your log files before writing them to disk. | [optional] [default to &#39;null&#39;]
 **url** | **string**| Your OpenStack auth url. | [optional] 
 **user** | **string**| The username for your OpenStack account. | [optional] 

### Return type

[**LoggingOpenstackResponse**](LoggingOpenstackResponse.md)

### Authorization

[token](../README.md#token)

### HTTP request headers

 - **Content-Type**: application/x-www-form-urlencoded
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

