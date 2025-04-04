package Search::Typesense::Document;

# ABSTRACT: CRUD for Typesense documents

use v5.16.0;

use Moo;
with qw(Search::Typesense::Role::Request);

use Mojo::JSON qw(decode_json encode_json);
use Search::Typesense::Types qw(
  ArrayRef
  Enum
  HashRef
  InstanceOf
  NonEmptyStr
  Str
  compile
);


our $VERSION = '0.08';


sub create {
    my ( $self, $collection, $document ) = @_;
    state $check = compile( NonEmptyStr, HashRef );
    ( $collection, $document ) = $check->( $collection, $document );
    return $self->_POST(
        path => [ 'collections', $collection, 'documents' ],
        body => $document
    );
}


sub upsert {
    my ( $self, $collection, $document ) = @_;
    state $check = compile( NonEmptyStr, HashRef );
    ( $collection, $document ) = $check->( $collection, $document );

    return $self->_POST(
        path  => [ 'collections', $collection, 'documents' ],
        body  => $document,
        query => { action => 'upsert' },
    );
}


sub update {
    my ( $self, $collection, $document_id, $updates ) = @_;
    state $check = compile( NonEmptyStr, NonEmptyStr, HashRef );
    ( $collection, $document_id, $updates )
      = $check->( $collection, $document_id, $updates );
    return $self->_PATCH(
        path => [ 'collections', $collection, 'documents', $document_id ],
        body => $updates
    );
}


sub delete {
    my ( $self, $collection, $document_id ) = @_;
    state $check = compile( NonEmptyStr, NonEmptyStr );
    ( $collection, $document_id ) = $check->( $collection, $document_id );
    return $self->_DELETE(
        path => [ 'collections', $collection, 'documents', $document_id ] );
}


sub export {
    my ( $self, $collection ) = @_;
    state $check = compile(NonEmptyStr);
    ($collection) = $check->($collection);
    my $tx = $self->_GET(
        path => [ 'collections', $collection, 'documents', 'export' ],
        return_transaction => 1
    ) or return;    # 404
    return [ map { decode_json($_) } split /\n/ => $tx->res->body ];
}


sub import {
    my $self = shift;
    state $check = compile(
        NonEmptyStr,
        Enum [qw/create upsert update/],
        ArrayRef [HashRef],
    );
    my ( $collection, $action, $documents ) = $check->(@_);
    my $body = join "\n" => map { encode_json($_) } @$documents;

    my $tx = $self->_POST(
        path  => [ 'collections', $collection, 'documents', "import" ],
        body  => $body,
        query => { action => $action },
        return_transaction => 1,
    );
    my $response = $tx->res->json;
    if ( exists $response->{success} ) {
        $response->{success} += 0;
    }
    return $response;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Search::Typesense::Document - CRUD for Typesense documents

=head1 VERSION

version 0.08

=head1 SYNOPSIS

    my $typesense = Search::Typesense->new(
        host    => $host,
        api_key => $key,
    );
    my $documents = $typesense->documents;

The instantiation of this module is for internal use only. The methods are
public.

=head2 C<create>

    my $document = $typesense->documents->create($collection, \%data);

Arguments and response as shown at L<https://typesense.org/docs/0.19.0/api/#index-document>

=head2 C<upsert>

    my $document = $typesense->documents->upsert($collection, \%data);

Arguments and response as shown at L<https://typesense.org/docs/0.19.0/api/#upsert>

=head2 C<update>

    my $document = $typesense->documents->update($collection, $document_id, \%data);

Arguments and response as shown at L<https://typesense.org/docs/0.19.0/api/#update-document>

=head2 C<delete>

    my $document = $typesense->documents->delete($collection_name, $document_id);

Arguments and response as shown at L<https://typesense.org/docs/0.19.0/api/#delete-document>

=head2 C<export>

    my $export = $typesense->documents->export($collection_name);

Response as shown at L<https://typesense.org/docs/0.19.0/api/#export-documents>

(An arrayref of hashrefs)

=head2 C<import>

    my $response = $typesense->documents->import(
      $collection_name,
      $action,
      \@documents,
   );

Response as shown at L<https://typesense.org/docs/0.19.0/api/#import-documents>

C<$action> must be one of C<create>, C<update>, or C<upsert>.

=head1 AUTHOR

Curtis "Ovid" Poe <ovid@allaroundtheworld.fr>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2021 by Curtis "Ovid" Poe.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
