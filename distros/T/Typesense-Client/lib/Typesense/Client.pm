package Typesense::Client;
$Typesense::Client::VERSION = '0.001';
use v5.38;
use warnings;

use Object::Pad;

use Mojo::UserAgent;
use Mojo::Parameters;
use Mojo::JSON qw(encode_json);

use Typesense::Client::Error;
use Typesense::Client::Version;
use Typesense::Client::Collections;
use Typesense::Client::Documents;
use Typesense::Client::Aliases;
use Typesense::Client::Synonyms;
use Typesense::Client::Overrides;
use Typesense::Client::Analytics;
use Typesense::Client::Keys;

class Typesense::Client {

    field $url             :reader :param;
    field $api_key                 :param;

    ## Two timing profiles: a search that takes more than a second and a half
    ## is already useless for rendering a page, but a batch import needs
    ## minutes. Each one gets its own agent, so nothing is reconfigured hot.
    field $connect_timeout :param = 0.3;
    field $request_timeout :param = 1.5;
    field $bulk_timeout    :param = 120;

    ## fail_open: instead of throwing, return undef and leave the error object
    ## in ->last_error. Meant for the search path of a web site, where the right
    ## answer to "the engine is down" is to serve something else, not a 500.
    field $fail_open       :reader :param = 0;

    field $ua              :param = undef;
    field $bulk_ua         :param = undef;

    field $last_error :reader = undef;

    ADJUST {
        $url =~ s{/+$}{};
        $ua      //= Mojo::UserAgent->new(
            connect_timeout => $connect_timeout,
            request_timeout => $request_timeout,
        );
        $bulk_ua //= Mojo::UserAgent->new(
            connect_timeout => 2,
            request_timeout => $bulk_timeout,
        );
    }

    ## ---- resource delegates ----------------------------------------------

    field $_collections; method collections { $_collections //= Typesense::Client::Collections->new(client => $self) }
    field $_documents;   method documents   { $_documents   //= Typesense::Client::Documents->new(client => $self) }
    field $_aliases;     method aliases     { $_aliases     //= Typesense::Client::Aliases->new(client => $self) }
    field $_synonyms;    method synonyms    { $_synonyms    //= Typesense::Client::Synonyms->new(client => $self) }
    field $_overrides;   method overrides   { $_overrides   //= Typesense::Client::Overrides->new(client => $self) }
    field $_analytics;   method analytics   { $_analytics   //= Typesense::Client::Analytics->new(client => $self) }
    field $_keys;        method keys        { $_keys        //= Typesense::Client::Keys->new(client => $self) }

    ## ---- HTTP core -------------------------------------------------------

    ## %opt: json (body to encode), raw (body sent verbatim, for JSONL),
    ##       bulk (use the long-timeout agent), raw_response (return the body
    ##       undecoded), ok_404 (a 404 is not an error: return a clean undef),
    ##       headers (extra request headers).
    ##
    ## The caller's headers are merged last, so they win. That is deliberate:
    ## it is what lets one client send a per-request scoped key instead of
    ## building a second client for every tenant.
    method request ($method, $path, %opt) {
        $last_error = undef;
        my $agent = $opt{bulk} ? $bulk_ua : $ua;

        my %headers = ( 'X-TYPESENSE-API-KEY' => $api_key, %{ $opt{headers} // {} } );
        my @args = ("$url$path", \%headers);
        push @args, $opt{raw}          if defined $opt{raw};
        push @args, json => $opt{json} if defined $opt{json};

        my $res = eval { $agent->start($agent->build_tx($method, @args))->result };
        unless ($res) {
            my $why = $@ || 'no response';
            $why =~ s/\s+\z//;
            return $self->_fail(message => $why, code => 0, endpoint => "$method $path");
        }

        if ($res->is_error) {
            my $body = eval { $res->json };
            ## A DELETE of something already gone achieved what it asked for.
            return undef if $opt{ok_404} && $res->code == 404;
            return $self->_fail(
                message  => ($body->{message} // $res->message // 'error'),
                code     => $res->code,
                endpoint => "$method $path",
                body     => $body,
            );
        }

        return $res->body if $opt{raw_response};
        return eval { $res->json } // {};
    }

    method _fail (%args) {
        my $err = Typesense::Client::Error->new(%args);
        $last_error = $err;
        die $err unless $fail_open;
        return undef;
    }

    ## Query string with the keys SORTED: two equivalent calls produce the same
    ## URL, which is what makes the response cacheable upstream.
    method _qs ($params) {
        my $qs = Mojo::Parameters->new;
        $qs->append($_ => $params->{$_}) for sort keys %$params;
        return $qs->to_string;
    }

    ## ---- health and diagnostics ------------------------------------------

    method health  { $self->request(GET => '/health') }
    method stats   { $self->request(GET => '/stats.json') }
    method metrics { $self->request(GET => '/metrics.json') }
    method debug   { $self->request(GET => '/debug') }

    ## The server version as a comparable object. Worth having: the analytics
    ## API in particular changed shape between server releases, so a caller
    ## that supports more than one Typesense needs to ask before it assumes.
    method server_version {
        my $debug = $self->debug or return undef;    ## fail_open
        return Typesense::Client::Version->new(version_string => $debug->{version} // '');
    }

    ## ---- search ----------------------------------------------------------

    ## %opt goes straight to request(). In practice that means headers, and in
    ## practice that means x-typesense-user-id: without it Typesense attributes
    ## analytics events by IP, and behind a proxy every visitor is one person.
    method search ($collection, $params, %opt) {
        $self->request(GET => "/collections/$collection/documents/search?" . $self->_qs($params), %opt);
    }

    ## Several searches in a single round trip.
    ##
    ## WARNING: the parameters in $common travel in the query string and
    ## OVERRIDE the per-search ones. A parameter that must differ between
    ## branches (drop_tokens_threshold is the usual case) has to go inside each
    ## element of $searches and NOT in $common, or it has no effect at all.
    method multi_search ($searches, $common = {}, %opt) {
        my $qs   = $self->_qs($common);
        my $path = '/multi_search' . ($qs ? "?$qs" : '');
        $self->request(POST => $path, json => { searches => $searches }, %opt);
    }
}

1;

__END__

=head1 NAME

Typesense::Client - Perl client for the Typesense search engine

=head1 SYNOPSIS

    use Typesense::Client;

    my $ts = Typesense::Client->new(
        url     => 'http://localhost:8108',
        api_key => $ENV{TYPESENSE_API_KEY},
    );

    $ts->collections->create({
        name   => 'products',
        fields => [
            { name => 'name',  type => 'string' },
            { name => 'brand', type => 'string', facet => \1 },   # JSON boolean
            { name => 'price', type => 'float'  },
        ],
        default_sorting_field => 'price',
    });

    $ts->documents->import_docs('products', \@docs);       # JSONL bulk load

    my $r = $ts->search('products', {
        q        => 'aple',                                # typo tolerated
        query_by => 'name,brand',
        filter_by => 'price:[100..500]',
    });
    say $r->{found};

=head1 DESCRIPTION

A complete, dependency-light client for L<Typesense|https://typesense.org>
v28 and later. It covers collections, documents (including JSONL bulk import
and export), aliases, single and federated search, synonyms, curation
overrides, the analytics API, and scoped API keys.

The client is a thin layer over the REST API: it builds requests, applies the
API key, decodes JSON and turns failures into exceptions. It does not model
schemas or validate documents - Typesense does that, and its error messages are
good.

=head2 Relationship to Search::Typesense

L<Search::Typesense> is an earlier and independent client, last released in
2021 against Typesense 0.19 and marked as alpha by its author. It covers
collections and documents. This distribution exists because several parts of
the API that production deployments depend on had no Perl binding at all:
C<multi_search>, aliases (which is how you reindex without downtime), synonyms,
curation overrides, the analytics API, and scoped keys. It also differs in two
design decisions: errors are exception objects rather than return values, and
L</fail_open> is offered for callers that must degrade instead of die.

If C<Search::Typesense> covers what you need, there is no reason to switch.

=head1 CONSTRUCTOR

    my $ts = Typesense::Client->new(url => ..., api_key => ..., %options);

=over 4

=item * C<url> (required)

Base URL of the server, e.g. C<http://localhost:8108>. A trailing slash is
stripped.

=item * C<api_key> (required)

Sent as the C<X-TYPESENSE-API-KEY> header on every request.

=item * C<connect_timeout>, C<request_timeout>

Seconds, for ordinary requests. Default C<0.3> and C<1.5> - deliberately short,
because a search that misses those deadlines is no longer useful for rendering
a page. Raise them for interactive administration.

=item * C<bulk_timeout>

Seconds, for import and export. Default C<120>.

=item * C<fail_open>

When true, failures return C<undef> and leave the exception in L</last_error>
instead of dying. See L</ERROR HANDLING>.

=item * C<ua>, C<bulk_ua>

Supply your own L<Mojo::UserAgent> instances. Mostly useful in tests, where
sharing C<< Mojo::IOLoop->singleton >> with an in-process server matters.

=back

=head1 JSON BOOLEANS

Typesense validates types strictly, and Perl has no native boolean to hand it.
A schema flag written as C<< facet => 1 >> reaches the server as the number
C<1> and is rejected:

    400 The `facet` property of the field `brand` should be a boolean.

Use a reference to a scalar, which L<Mojo::JSON> encodes as a JSON boolean:

    { name => 'brand', type => 'string', facet => \1 }   # true
    { name => 'brand', type => 'string', facet => \0 }   # false

The same applies to every other boolean the API takes - C<optional>, C<index>,
C<sort>, C<infix>, C<store>, C<enable_nested_fields>, C<expand_query> - and to
booleans inside documents you index. This client passes your data through
untouched by design, so the conversion is yours to make.

=head1 ERROR HANDLING

By default any transport or HTTP failure throws a
L<Typesense::Client::Error>, which stringifies to a full message:

    my $r = eval { $ts->search('products', { q => 'x', query_by => 'name' }) };
    if (my $err = $@) {
        die $err unless ref $err;
        warn "search failed: $err";
    }

With C<< fail_open => 1 >> nothing is thrown; the call returns C<undef> and the
error object is available afterwards:

    my $ts = Typesense::Client->new(..., fail_open => 1);
    my $r  = $ts->search('products', { q => 'x', query_by => 'name' })
        or fall_back_to_sql($ts->last_error);

That mode exists for the search path of a public site, where the right answer
to "the engine is down" is to serve something else, not to return a 500.

=head1 METHODS

=head2 collections, documents, aliases, synonyms, overrides, analytics, keys

Resource accessors. Each returns a delegate object, created on first use:
L<Typesense::Client::Collections>, L<Typesense::Client::Documents>,
L<Typesense::Client::Aliases>, L<Typesense::Client::Synonyms>,
L<Typesense::Client::Overrides>, L<Typesense::Client::Analytics>,
L<Typesense::Client::Keys>.

=head2 search

    my $r = $ts->search($collection, \%params, %opt);

C<GET /collections/{name}/documents/search>. C<%params> is passed through
unchanged, so every search parameter Typesense supports is available. Query
string keys are sorted, so equivalent calls produce byte-identical URLs - which
is what makes the response cacheable upstream.

C<%opt> goes to L</request>, which in practice means C<headers>:

    $ts->search('products', { q => 'laptop', query_by => 'name' },
                headers => { 'x-typesense-user-id' => $session_id });

That header is what makes the analytics API attribute events to a person.
Without it Typesense aggregates by IP address, and behind a reverse proxy that
is a single visitor for the whole site. Pass the same identifier here that you
pass as C<user_id> to L<Typesense::Client::Analytics/event>.

=head2 multi_search

    my $r = $ts->multi_search(\@searches, \%common, %opt);

C<POST /multi_search>. Runs several searches in one round trip.

B<Important:> C<%common> travels in the query string, and Typesense lets those
values B<override> the per-search ones in the body. A parameter that must differ
between branches - C<drop_tokens_threshold> is the usual one - has to be set
inside each element of C<@searches> and kept out of C<%common>, or it silently
has no effect.

=head2 health, stats, metrics, debug

C</health>, C</stats.json>, C</metrics.json> and C</debug>.

=head2 server_version

    my $v = $ts->server_version;
    if ( $v->is_at_least('28.0') ) { ... }

C<GET /debug>, wrapped in a L<Typesense::Client::Version> object that
stringifies to the version and compares properly. Returns C<undef> in
C<fail_open> mode when the server cannot be reached.

=head2 request

    my $data = $ts->request($method, $path, %opt);

The low-level escape hatch, for endpoints this module does not wrap yet.
C<%opt> accepts C<json> (body to encode), C<raw> (body sent verbatim, for
JSONL), C<bulk> (use the long-timeout agent), C<raw_response> (return the
undecoded body), C<ok_404> (treat 404 as success returning C<undef>) and
C<headers> (a hash reference of extra request headers).

Your headers are merged after the API key, so they win. That is what lets a
single client send a per-request key - a scoped key derived for one customer,
say - without building a second client for every tenant:

    $ts->search('products', \%params,
                headers => { 'X-TYPESENSE-API-KEY' => $scoped_key });

=head2 last_error

The L<Typesense::Client::Error> from the most recent failed call, or C<undef>.
Reset at the start of every request. Chiefly for C<fail_open> mode.

=head2 url, fail_open

Read-only accessors for the corresponding constructor arguments.

=head1 SEE ALSO

L<https://typesense.org/docs/> - the API reference this module follows.

L<Search::Typesense> - the earlier Perl client; see L</Relationship to Search::Typesense>.

=head1 AUTHOR

SeHarrys

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2026 by SeHarrys.

This is free software; you can redistribute it and/or modify it under the terms
of the Artistic License 2.0.

=cut
