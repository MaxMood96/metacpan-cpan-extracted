# ABSTRACT: Internal module with the API specification
package Arango::DB::API;
$Arango::DB::API::VERSION = '0.006';
use Arango::DB::Database;
use Arango::DB::Collection;

use strict;
use warnings;
use HTTP::Tiny;
use JSON;
use Clone 'clone';
use MIME::Base64 3.11 'encode_base64url';
use URI::Encode qw(uri_encode);
use JSON::Schema::Fit 0.02;

my %API = (
    create_document   => { method => 'post',   uri => '{database}_api/document/{collection}' },
    delete_collection => { method => 'delete', uri => '{database}_api/collection/{name}'     },
    delete_database   => { method => 'delete', uri => '_api/database/{name}'                 },
    list_collections  => { method => 'get',    uri => '{database}_api/collection'            },
    cursor_next       => { method => 'put',    uri => '{database}_api/cursor/{id}'           },
    cursor_delete     => { method => 'delete', uri => '{database}_api/cursor/{id}'           },
    list_databases    => { method => 'get',    uri => '_api/database'                        },
    status            => { method => 'get',    uri => '_admin/status'                        },
    time              => { method => 'get',    uri => '_admin/time'                          },
    statistics        => { method => 'get',    uri => '_admin/statistics'                    },
    statistics_description  => { method => 'get', uri => '_admin/statistics-description'     },
    'create_database' => {
        method  => 'post',
        uri     => '_api/database',
        params  => { name => { type => 'string' }},
        builder => sub { 
            my ($self, %params) = @_;
            return Arango::DB::Database->_new(arango => $self, 'name' => $params{name});
        },
    },
   'create_collection' => {
        method  => 'post',
        uri     => '{database}_api/collection',
        params  => { name => { type => 'string' }},
        builder => sub {
            my ($self, %params) = @_;
            return Arango::DB::Collection->_new(arango => $self, database => $params{database}, 'name' => $params{name});
        },
    },
    'all_keys' => {
        method => 'put',
        uri    => '{database}_api/simple/all-keys',
        params => { type => { type => 'string' }, collection => { type => 'string' } },
    },
    'version' => {
        method => 'get',
        uri    => '_api/version',
        params => {  details => { type => 'boolean' } } ,
    },
    'create_cursor' => {
        method => 'post',
        uri    => '{database}_api/cursor',
        params => { 
            query       => { type => 'string'  }, 
            count       => { type => 'boolean' },
            batchSize   => { type => 'integer' },
            cache       => { type => 'boolean' },
            memoryLimit => { type => 'integer' },
            ttl         => { type => 'integer' },
            bindVars => { type => 'object', additionalProperties => 1 },
            options  => { type => 'object', additionalProperties => 0, properties => {
                    failOnWarning               => { type => 'boolean' },
                    profile                     => { type => 'integer', maximum => 2, minimum => 0 }, # 0, 1, 2
                    maxTransactionSize          => { type => 'integer' },
                    stream                      => { type => 'boolean' },
                    skipInaccessibleCollections => { type => 'boolean' },
                    maxWarningCount             => { type => 'integer' },
                    intermediateCommitCount     => { type => 'integer' },
                    satelliteSyncWait           => { type => 'integer' },
                    fullCount                   => { type => 'boolean' },
                    intermediateCommitSize      => { type => 'integer' },
                    'optimizer.rules'           => { type => 'string'  },
                    maxPlans                    => { type => 'integer' },
                 }
            },
        },
      },
      delete_user => { method => 'delete', uri => '_api/user/{username}' },
      create_user => {
          method => 'post',
          uri => '_api/user',
          params => {
              password => { type => 'string' },
              active => { type => 'boolean' },
              user => { type => 'string' },
              extra => { type => 'object', additionalProperties => 1 },
          }
      },
);



sub _check_options {
    my ($params, $properties) = @_;
    my $schema = { type => 'object', additionalProperties => 0, properties => $properties };
    my $prepared_data = JSON::Schema::Fit->new()->get_adjusted($params, $schema);
    return $prepared_data;
}

sub _api {
    my ($self, $action, $params) = @_;
    
    my $uri = $API{$action}{uri};

    my $params_copy = clone $params;

    $uri =~ s!\{database\}! defined $params->{database} ? "_db/$params->{database}/" : "" !e;
    $uri =~ s/\{([^}]+)\}/$params->{$1}/g;
    
    my $url = "http://" . $self->{host} . ":" . $self->{port} . "/" . $uri;

    my $body = ref($params) eq "HASH" && exists $params->{body} ? $params->{body} : undef;
    my $opts = ref($params) eq "HASH" ? $params : {};

    $opts = exists($API{$action}{params}) ? _check_options($opts, $API{$action}{params}) : {};

    if ($API{$action}{method} eq 'get' && scalar(keys %$opts)) { 
        $url .= "?" . join("&", map { "$_=" . uri_encode($opts->{$_} )} keys %$opts);
    } else {
        if ($body && ref($body) eq "HASH") {
            $opts = { content => encode_json $body }
        }
        elsif (defined($body)) { # JSON
            $opts = { content => $body }
        }
        else {
            $opts = { content => encode_json $opts }
        }
    }
        
    #use Data::Dumper;
    # print STDERR "\n -- $API{$action}{method} | $url\n";
    #print STDERR "\n\nOPTS:\n\n", Dumper($opts);
    

    my $response = $self->{http}->request($API{$action}{method}, $url, $opts);

    if ($response->{success}) {
        my $ans = decode_json($response->{content});
        if ($ans->{error}) {
            return $ans;
        } elsif (exists($API{$action}{builder})) {
            return $API{$action}{builder}->( $self, %$params_copy );
        } else {
            return $ans;
        }
    }
    else {
        die "Arango::DB | ($response->{status}) $response->{reason}";   
    }
}



1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Arango::DB::API - Internal module with the API specification

=head1 VERSION

version 0.006

=head1 AUTHOR

Alberto Simões <ambs@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2019 by Alberto Simões.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
