# Licensed to Elasticsearch B.V. under one or more contributor
# license agreements. See the NOTICE file distributed with
# this work for additional information regarding copyright
# ownership. Elasticsearch B.V. licenses this file to you under
# the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

package Search::Elasticsearch::Client::7_0::Direct::DataFrame;
$Search::Elasticsearch::Client::7_0::Direct::DataFrame::VERSION = '8.12';
use Moo;
with 'Search::Elasticsearch::Client::7_0::Role::API';
with 'Search::Elasticsearch::Role::Client::Direct';
use namespace::clean;

__PACKAGE__->_install_api('data_frame');

1;

=pod

=encoding UTF-8

=head1 NAME

Search::Elasticsearch::Client::7_0::Direct::DataFrame - Plugin providing Transform API for Search::Elasticsearch 7.x

=head1 VERSION

version 8.12

=head1 SYNOPSIS

    my $response = $es->data_frame->explore(...);

=head2 DESCRIPTION

This class extends the L<Search::Elasticsearch> client with a C<data_frame>
namespace, to support the API for the
L<Transform|https://www.elastic.co/guide/en/elasticsearch/reference/7.3/transform-apis.html> plugin for Elasticsearch.

=head1 METHODS

The full documentation for the Transform plugin is available here:
L<https://www.elastic.co/guide/en/elasticsearch/reference/7.3/transform-apis.html>

=head2 C<explore()>

    $response = $es->data_frame->put_data_frame_transform(
        transform_id => $transform_id,
        body  => {...}
    );

The C<put_data_frame_transform()> instantiates a transform.

=head1 AUTHOR

Enrico Zimuel <enrico.zimuel@elastic.co>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2024 by Elasticsearch BV.

This is free software, licensed under:

  The Apache License, Version 2.0, January 2004

=cut

__END__

# ABSTRACT: Plugin providing Transform API for Search::Elasticsearch 7.x

