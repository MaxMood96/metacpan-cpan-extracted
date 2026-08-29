package Typesense::Client::Documents;
$Typesense::Client::Documents::VERSION = '0.001';
use v5.38;
use warnings;
use Object::Pad;

use Mojo::JSON qw(encode_json decode_json);

class Typesense::Client::Documents {
    field $client :param;

    ## Import batch size. 2,000 documents fit comfortably inside Typesense's
    ## default body limit and keep memory use flat on the Perl side.
    field $batch_size :param = 2000;

    method create ($collection, $doc) {
        $client->request(POST => "/collections/$collection/documents", json => $doc);
    }

    method upsert ($collection, $doc) {
        $client->request(POST => "/collections/$collection/documents?action=upsert", json => $doc);
    }

    method get ($collection, $id) {
        $client->request(GET => "/collections/$collection/documents/$id");
    }

    ## PARTIAL update of a document: only the fields that are sent.
    method update ($collection, $id, $doc) {
        $client->request(PATCH => "/collections/$collection/documents/$id", json => $doc);
    }

    method delete ($collection, $id) {
        $client->request(DELETE => "/collections/$collection/documents/$id", ok_404 => 1);
    }

    ## Delete by filter. Returns { num_deleted => N }.
    method delete_by_filter ($collection, $filter_by) {
        my $qs = $client->_qs({ filter_by => $filter_by });
        $client->request(DELETE => "/collections/$collection/documents?$qs");
    }

    ## Bulk load in JSONL.
    ##
    ## It is called import_docs and not import because `import` is the method
    ## Perl calls by itself on every `use`: a sub with that name would fire
    ## without anyone calling it.
    ##
    ## Typesense answers 200 even when documents are rejected - one JSON line
    ## per document, each with its own {success}. That is why the aggregated
    ## result matters more than the HTTP status.
    ##
    ## Returns { total, ok, failed, errors => [ up to max_errors ] }.
    method import_docs ($collection, $docs, %opt) {
        my $action     = $opt{action}     // 'upsert';
        my $max_errors = $opt{max_errors} // 10;
        my $batch      = $opt{batch_size} // $batch_size;

        my %sum = (total => scalar @$docs, ok => 0, failed => 0, errors => []);
        return \%sum unless @$docs;

        for (my $i = 0; $i < @$docs; $i += $batch) {
            my $end   = $i + $batch - 1;
            $end      = $#$docs if $end > $#$docs;
            my $jsonl = join "\n", map { encode_json($_) } @{$docs}[$i .. $end];

            my $body = $client->request(
                POST         => "/collections/$collection/documents/import?action=$action",
                raw          => $jsonl,
                bulk         => 1,
                raw_response => 1,
            );
            ## fail_open: the caller decides, but we do not fake a good summary.
            return undef unless defined $body;

            for my $line (split /\n/, $body) {
                if ($line =~ /"success"\s*:\s*true/) { $sum{ok}++ }
                else {
                    $sum{failed}++;
                    push @{ $sum{errors} }, $line if @{ $sum{errors} } < $max_errors;
                }
            }
        }
        return \%sum;
    }

    ## Full dump in JSONL. Returns an array reference of hash references, or
    ## the raw text with raw => 1 (the sensible choice for large collections:
    ## it avoids holding the whole catalogue decoded in memory).
    method export ($collection, %opt) {
        my $raw    = delete $opt{raw};
        my $qs     = $client->_qs(\%opt);
        my $body   = $client->request(
            GET => "/collections/$collection/documents/export" . ($qs ? "?$qs" : ''),
            bulk => 1, raw_response => 1,
        );
        return undef unless defined $body;
        return $body if $raw;
        return [ map { decode_json($_) } grep { /\S/ } split /\n/, $body ];
    }
}

1;

__END__

=head1 NAME

Typesense::Client::Documents - indexing, updating and bulk loading documents

=head1 SYNOPSIS

    my $d = $ts->documents;

    $d->upsert('products', { id => '42', name => 'Laptop 14', price => 999.0 });
    $d->update('products', '42', { price => 899.0 });       # partial
    $d->delete('products', '42');
    $d->delete_by_filter('products', 'stock:=0');

    my $r = $d->import_docs('products', \@docs);            # JSONL, batched
    warn "@{$r->{errors}}" if $r->{failed};

    my $all = $d->export('products');

=head1 METHODS

=head2 create

C<POST /collections/{c}/documents>. Fails if the id already exists; use
L</upsert> unless you want that.

=head2 upsert

Same endpoint with C<action=upsert>. Creates or replaces.

=head2 get

C<GET /collections/{c}/documents/{id}>.

=head2 update

C<PATCH /collections/{c}/documents/{id}>. B<Partial>: only the fields you send
are touched. This is the cheap way to move one number - a stock count, a price
- without rebuilding the document.

=head2 delete

C<DELETE /collections/{c}/documents/{id}>. Deleting something that is already
gone is not an error.

=head2 delete_by_filter

C<DELETE /collections/{c}/documents?filter_by=...>. Returns
C<< { num_deleted => N } >>.

=head2 import_docs

    my $r = $d->import_docs($collection, \@docs, %opt);

Bulk load over C<POST .../documents/import>, in JSONL. C<%opt> takes C<action>
(C<upsert> by default, also C<create>, C<update>, C<emplace>), C<batch_size>
and C<max_errors>.

Returns C<< { total, ok, failed, errors } >>. B<Check C<failed>>: Typesense
answers 200 for the batch even when individual documents are rejected - it
returns one JSON line per document, each with its own C<success> flag. The HTTP
status tells you the batch arrived, not that it was indexed.

The name is C<import_docs> and not C<import> because C<import> is the method
Perl calls by itself on every C<use>: a sub with that name would fire without
anyone calling it.

=head2 export

    my $docs = $d->export($collection, %opt);
    my $text = $d->export($collection, raw => 1);

C<GET /collections/{c}/documents/export>. Returns an array reference of
decoded documents, or with C<< raw => 1 >> the JSONL text as it arrived -
which is what you want for a large collection, since it keeps you from holding
the whole catalogue decoded in memory.

C<%opt> also passes through Typesense's own C<filter_by>, C<include_fields> and
C<exclude_fields>.

=head1 SEE ALSO

L<Typesense::Client>

=head1 AUTHOR

SeHarrys

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2026 by SeHarrys.

This is free software; you can redistribute it and/or modify it under the terms
of the Artistic License 2.0.

=cut
