package HTTP::Request::Diff;
use 5.020;
use Moo 2;

our $VERSION = '0.07';

use experimental 'signatures'; # actually, they are stable but stable.pm doesn't know
use stable 'postderef';
no warnings 'experimental::signatures';
use Algorithm::Diff;
use Carp 'croak', 'cluck';
use List::Util 'pairs', 'uniq', 'max';
use CGI::Tiny::Multipart 'parse_multipart_form_data';
use HTTP::Request;
use URI::QueryParam; # old versions of URI don't load the functionality automatically
require overload; # for checking whether inputs are overloaded

=encoding utf-8

=head1 NAME

HTTP::Request::Diff - create diffs between HTTP requests

=head1 SYNOPSIS

  use HTTP::Request::Common 'GET';

  my $diff = HTTP::Request::Diff->new(
      reference => GET('https://example.com/?foo=bar' ),
      #actual    => $req2,
      skip_headers => \@skip,
      ignore_headers => \@skip2,
      mode => 'exact', # default is 'semantic'
  );

  my @differences = $diff->diff( GET('https://example.com/' ));
  say Dumper $differences[0];
  # {
  #   'kind' => 'value',
  #   'type' => 'query.foo',
  #   'reference' => [
  #                    'bar'
  #                  ],
  #   'actual' => [
  #                 undef
  #               ]
  # }
  #

  say $diff->as_table(@differences);
  # +-----------+-----------+-----------+
  # | Type      | Reference | Actual    |
  # +-----------+-----------+-----------+
  # | query.foo | bar       | <missing> |
  # +-----------+-----------+-----------+


=head1 METHODS

=head2 C<< ->new >>

  my $diff = HTTP::Request::Diff->new(
      mode => 'semantic',
  );

=head3 Options

=over 4

=item * C<mode>

  mode => 'strict',

The comparison mode. The default is semantic comparison, which considers some
differences insignificant:

=over 4

=item * The order of HTTP headers

=item * The boundary strings of multipart POST requests

=item * The order of query parameters

=item * The order of form parameters

=item * A C<Content-Length: 0> header is equivalent to a missing C<Content-Length> header

=back

C<strict> mode wants the requests to be as identical as possible.
C<lax> mode considers query parameters in the POST body as equivalent.

=cut

# lax      -> parameters may be query or post-parameters
# semantic -> many things in requests are equivalent
# strict   -> requests must be string-identical
has 'mode' => (
    is => 'ro',
    default => 'semantic',
);

=item * C<reference>

(optional) The reference request to compare against. Alternatively pass in
the request in the call to C<< ->diff >>.

=cut

has 'reference' => (
    is => 'ro',
);

=item * C<skip_headers>

  skip_headers => ['X-Proxied-For'],

List of headers to skip when comparing. Missing headers are not significant.

=cut

has 'skip_headers' => (
    is => 'ro',
    default => sub { [] },
);

=item * C<ignore_headers>

  ignore_headers => ['Accept-Encoding'],

List of headers to ignore when comparing. Missing headers are significant.

=cut

has 'ignore_headers' => (
    is => 'ro',
    default => sub { [] },
);

=item * C<canonicalize>

Callback to canonicalize a request. The request will be passed in unmodified
either as a string or a L<HTTP::Request>.

=cut

has 'canonicalize' => (
    is => 'ro',
);

=item * C<compare>

Arrayref of things to compare.

=cut

has 'compare' => (
    is => 'ro',
    default => sub {
        return [
            request => 'method',
            uri     => 'host',
            uri     => 'port',
            uri     => 'path',
        ];
    },
);

=item * C<warn_on_newlines>

(optional) If we should output warnings when we receive C< \n > delimited input
instead of C< \r\n >. This mostly happens when input is read from text files
for regression test.

Default is true.

=back

=cut

has 'warn_on_newlines' => (
    is => 'rw',
    default => 1
);

sub fetch_value($self, $req, $item, $req_params=undef) {
    my $obj;
    if( $item->key eq 'request' ) {
        my $v = $item->value;
        return $req->$v;

    } elsif( $item->key eq 'headers' ) {
        return $req->headers->header( $item->value );

    } elsif( $item->key eq 'query' ) {
        return [ $req->uri->query_param( $item->value )];

    } elsif( $item->key eq 'uri' ) {
        my $u = $req->uri;
        if( my $c = $u->can( $item->value )) {
            return $c->($u)
        } else {
            return
        }

    } elsif( $item->key eq 'form' ) {
        return $req_params->{ $item->value };

    } else {
        croak sprintf "Unknown key '%s'", $item->key;
    }

}

sub get_form_parameters( $self, $req ) {
    my(undef, $boundary) = $req->headers->content_type;
    my $str = $req->content;
    $boundary =~ s!^boundary=!!;

    my %res;
    my $res = parse_multipart_form_data( \$str, length($str), $boundary);
    if( ! $res ) {
        croak "Malformed form data";
    }
    for my $p ($res->@*) {
        $res{ $p->{name} } //= [];
        push $res{ $p->{name}}->@*, $p->{content};
    };
    return \%res;
}

sub get_request_header_names( $self, $req ) {
    if( $req =~ /\n/ ) {
        my( $header ) = $req =~ m/^(.*?)\r?\n\r?\n/ms
            or croak "No header in request <$req>";
        my @headers = ($header =~ /^([A-Za-z][A-Za-z\d-]+):/mg);
        return @headers;
    } else {
        return
    }
}

=head2 C<< ->diff >>

  my @diff = $diff->diff( $reference, $actual, %options );
  my @diff = $diff->diff( $actual, %options );

Performs the diff and returns an array of hashrefs with differences.

=cut

sub diff( $self, $actual_or_reference, $actual=undef, %options ) {
    $options{ warn_on_newlines } //= $self->warn_on_newlines;
    $options{ mode } //= $self->mode;

    # Downconvert things to strings, unless we have strings already
    # reparse into HTTP::Request for easy structural checks

    my $ref;
    if( $actual ) {
        $ref = $actual_or_reference
            or croak "Need a reference request";
    } elsif( $actual_or_reference ) {
        $ref = $self->reference
            or croak "Need a reference request";
        $actual = $actual_or_reference // $self->actual
            or croak "Need an actual request to diff";
    } else {
        $ref = $self->reference
            or croak "Need a reference request";
        $actual = $self->actual
            or croak "Need an actual request to diff";
    }

    if( my $c = $self->canonicalize ) {
        $ref = $c->( $ref )
            or croak "Request canonicalizer returned no request";
        $actual = $c->( $actual )
            or croak "Request canonicalizer returned no request";
    };

    # maybe cache that in our builder?!
    my %ignore_diff = map {; "headers.$_" => 1 } $self->ignore_headers->@*;

    # maybe cache that in our builder?!
    my %skip_header = map { $_ => 1 } $self->skip_headers->@*;

    for ($ref, $actual) {
        if( ref $_ ) {
            if( $_->can( 'as_string' )) {
                $_ = $_->as_string("\r\n");

            } elsif( $_->can('to_string' )) {
                $_ = $_->to_string("\r\n");

            } elsif( overload::Method($_, '""')) {
                $_ = "$_";
            } else {
                croak "Don't know how to convert $_ to a string";
            }
        }
    };

    if( $options{ warn_on_newlines }) {
        cluck 'Reference input has bare newlines in header, not crlf'
            if $ref =~ /\A(.*?)[\r]?\n[\r]?\n/ and $1 =~ /[^\r]\n/;
        cluck 'Actual input has bare newlines in header, not crlf'
            if $actual =~ /\A(.*?)[\r]?\n[\r]?\n/ and $1 =~ /[^\r]\n/;
    };

    my $r_ref = HTTP::Request->parse( $ref );
    my $r_actual = HTTP::Request->parse( $actual );

    my @diff;

    # get query parameter separator, and check these (strict)
    if( $options{ mode } eq 'strict' and my $q = $r_ref->uri->query ) {
        if( $q =~ /([&;])/ ) {
            my $query_separator = $1;
            if( my $q2 = $r_actual->uri->query ) {
                if( $q2 =~ /([&;])/ ) {
                    if( $1 ne $query_separator ) {
                        push @diff, {
                            reference => $q,
                            actual => $q2,
                            type => 'meta.query_separator',
                            kind => 'value',
                        };
                    }
                }
            }
        }
    };

    my @ref_header_order = $self->get_request_header_names( $ref );
    my @actual_header_order = $self->get_request_header_names( $actual );

    my @headers = map {; ("headers", $_) }
                  grep { ! $skip_header{ $_ } }
                  uniq( @ref_header_order,
                        @actual_header_order
                  );

    my @query_params = map {; ("query", $_) }
                  uniq( $r_ref->uri->query_param,
                        $r_actual->uri->query_param,
                  );
    my @form_params;
    my ($ref_params, $actual_params);
    if(    $self->mode eq 'semantic'
        or $self->mode eq 'lax' ) {

        if(     $r_ref->headers->content_type eq 'multipart/form-data'
            and $r_actual->headers->content_type eq 'multipart/form-data'
        ) {
            # We've checked the content type already, we can ignore the boundary
            # value for semantic checks
            $ignore_diff{ 'headers.Content-Type' } = 1;

            # The content length will likely also differ, as we use different
            # sizes for the boundary
            $ignore_diff{ 'headers.Content-Length' } = 1;

            $ref_params = $self->get_form_parameters( $r_ref );
            $actual_params = $self->get_form_parameters( $r_actual );

            @form_params = map {; ("form", $_) }
                    uniq( keys( $ref_params->%* ),
                          keys( $actual_params->%*),
                    );

        } elsif( $r_actual->headers->content_type eq 'application/x-www-form-urlencoded'
             and $r_actual->headers->content_type eq 'application/x-www-form-urlencoded'
        ) {
            # We've checked the content type already, we can ignore the boundary
            # value for semantic checks
            $ignore_diff{ 'headers.Content-Type' } = 1;

            # Handle %20 vs +
            my $force_percent_encoding = ($r_ref->headers->content_length != $r_actual->headers->content_length);

            if( $force_percent_encoding ) {
                for my $req ($r_ref, $r_actual) {
                    my $body = $req->content();
                    if( $body =~ s!\+!%20!g ) {
                        $ignore_diff{ 'header.Content-Length' } = 1;
                        $req->content( $body );
                    }
                };
            };

        }
    };
    my @check = ($self->compare->@*, @headers, @query_params, @form_params);

    if( !@form_params ) {
        push @check, 'request' => 'content';
    };

    if( $self->mode eq 'strict' ) {
        push @check, 'request' => 'header_order';
    }

    # also, we should check for cookies

    for my $p (pairs @check) {

        my $ref_v;
        my $actual_v;

        if( $p->value eq 'header_order' ) {
            $ref_v = \@ref_header_order;
            $actual_v = \@actual_header_order;

        } else {
            $ref_v = $self->fetch_value( $r_ref, $p, $ref_params );
            $actual_v = $self->fetch_value( $r_actual, $p, $actual_params );
        }

        my $type = sprintf( '%s.%s', @$p );

        if( (defined $ref_v xor defined $actual_v)) {
            # One is missing

            # semantic/lax: If Content-Length is missing, it is equivalent
            #               to Content-Length: 0

            if(     ($self->mode eq 'lax' or $self->mode eq 'semantic')
                and $type eq 'headers.Content-Length'
                and ($ref_v // 0 )== 0 and ($actual_v // 0) == 0) {
                    # ignore
            } else {

                push @diff, {
                    reference => $ref_v,
                    actual => $actual_v,
                    type => $type,
                    kind => 'missing',
                };
            };

        } elsif( ref $ref_v ) {
            # Here we have a list of values, let's check if the lists
            # of values match
            my $diff = Algorithm::Diff->new( $ref_v, $actual_v );
            my $diff_type;
            my @ref;
            my @act;

            while( $diff->Next() ) {
                if( $diff->Same() ) {
                    push @ref, $diff->Items(1);
                    push @act, $diff->Items(2);

                } elsif( !$diff->Items(2) ) {
                    push @ref, $diff->Items(1);
                    push @act, (undef) x scalar($diff->Items(1));
                    $diff_type //= 'missing';

                } elsif( !$diff->Items(1) ) {
                    push @ref, (undef) x scalar($diff->Items(2));
                    push @act, $diff->Items(2);
                    $diff_type //= 'missing';

                } else {
                    my $count = max( scalar $diff->Items(1), scalar $diff->Items(2));
                    push @ref, $diff->Items(1);
                    push @ref, (undef) x (scalar($diff->Items(2)) - $count);
                    push @act, $diff->Items(2);
                    push @act, (undef) x (scalar($diff->Items(1)) - $count);

                    $diff_type = 'value';
                }
            };

            if( $diff_type ) {
                # Do we really want to downconvert to strings?!
                #my $ref_diff = join "\n", @ref;
                #my $actual_diff = join "\n", @act;
                my $ref_diff = \@ref;
                my $actual_diff = \@act;
                push @diff, {
                    reference => $ref_diff,
                    actual => $actual_diff,
                    type => sprintf( '%s.%s', @$p ),
                    kind => $diff_type,
                };
            };

        } elsif( !defined $ref_v and !defined $actual_v ) {
            # neither value exists

        } elsif( $ref_v ne $actual_v ) {
            my $type = sprintf( '%s.%s', @$p );
            if( ! $ignore_diff{ $type }) {
                push @diff, {
                    reference => $ref_v,
                    actual => $actual_v,
                    type => $type,
                    kind => 'value',
                };
            }
        };
    }
    # parameters switching between body and query string
    # if( $ref->headers->content_type eq '' ) {
    # compare form values
    # } else {
    # compare request body
    # }

    return @diff;
}

=head2 C<< ->as_table( @diff ) >>

  my @diff = $diff->diff( $request1, $request2 );
  print $diff->as_table( @diff );
  # +-----------------+-----------+--------+
  # | Type            | Reference | Actual |
  # +-----------------+-----------+--------+
  # | request.content | Ümloud    | Umloud |
  # +-----------------+-----------+--------+

Renders a diff as a table, using L<Term::Table>.

=cut

sub as_table($self,@diff) {
    require Term::Table;

    if( @diff ) {
        my $t = Term::Table->new(
            allow_overflow => 1,
            header => ['Type', 'Reference', 'Actual'],
            rows => [
                map {[ $_->{type},
                       ref $_->{reference} ? join "\n", map { $_ // '<missing>' } $_->{reference}->@* : $_->{reference} // '<missing>',
                       ref $_->{actual} ? join "\n", map { $_ // '<missing>' } $_->{actual}->@* : $_->{actual} // '<missing>',
                    ]} @diff
            ],
        );
        return join "\n", $t->render;
    };
}

1;

__END__

=head1 REPOSITORY

The public repository of this module is
L<https://github.com/Corion/HTTP-Request-Diff>.

=head1 SUPPORT

The public support forum of this module is L<https://perlmonks.org/>.

=head1 BUG TRACKER

Please report bugs in this module via the Github bug queue at
L<https://github.com/Corion/HTTP-Request-Diff/issues>

=head1 AUTHOR

Max Maischein C<corion@cpan.org>

=head1 COPYRIGHT (c)

Copyright 2023- by Max Maischein C<corion@cpan.org>.

=head1 LICENSE

This module is released under the Artistic License 2.0.

=cut
