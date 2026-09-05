package Archive::HAR::Writer;

# ABSTRACT: Interface for writing HTTP Archive (HAR) files.
our $VERSION = '0.01'; # VERSION

use 5.042;
use warnings;
use Path::Tiny    ();
use JSON::MaybeXS ();
use Carp          ();
use POSIX         ();
use MIME::Base64  ();
use Ref::Util     qw( is_plain_arrayref is_plain_scalarref );


use Class::Tiny {
    api      => sub { 1 },
    _entries => sub { [] },
};


sub add_http_transaction ( $self, $transaction ) {
    my $entry;

    if ( $transaction isa Mojo::Transaction::HTTP ) {
        $entry = $self->_entry_from_mojo( $transaction->req, $transaction->res );
    } elsif ( is_plain_arrayref $transaction ) {
        my ( $request, $response ) = @$transaction;

        Carp::croak('request must be an HTTP::Request')
          unless $request isa HTTP::Request;
        Carp::croak('response must be an HTTP::Response')
          unless $response isa HTTP::Response;

        $entry = $self->_entry_from_http( $request, $response );
    } else {
        Carp::croak( 'unsupported transaction type: ' . ( ref($transaction) || $transaction ) );
    }

    push $self->_entries->@*, $entry;

    return $self;
}


sub write_file ( $self, $path ) {
    $path = Path::Tiny->new($path) unless $path isa Path::Tiny;

    my $fh = $path->openw_raw;
    $self->write($fh);
    close $fh or Carp::croak("error closing $path: $!");

    return;
}


sub write ( $self, $fh ) {
    my $json = $self->_encode_har;

    if ( is_plain_scalarref $fh ) {
        $$fh .= $json;
    } else {
        print {$fh} $json or Carp::croak("error writing HAR: $!");
    }

    return;
}

sub _encode_har ($self) {
    return JSON::MaybeXS->new( utf8 => 1, pretty => 1, canonical => 1 )->encode(
        {
            log => {
                version => '1.2',
                creator => {
                    name    => 'Archive::HAR::Writer',
                    version => __PACKAGE__->VERSION // 'dev',
                },
                entries => $self->_entries,
            },
        }
    );
}

sub _entry_from_mojo ( $self, $req, $res ) {
    return $self->_build_entry(
        method           => $req->method,
        url              => $req->url->to_string,
        request_version  => 'HTTP/' . ( $req->version // '1.1' ),
        request_headers  => [ _mojo_header_pairs( $req->headers ) ],
        request_body     => $req->body,
        query_pairs      => [ _flat_to_pairs( $req->url->query->pairs->@* ) ],
        status           => $res->code,
        status_text      => $res->message,
        response_version => 'HTTP/' . ( $res->version // '1.1' ),
        response_headers => [ _mojo_header_pairs( $res->headers ) ],
        response_body    => $res->body,
    );
}

sub _entry_from_http ( $self, $req, $res ) {
    return $self->_build_entry(
        method           => $req->method,
        url              => $req->uri->as_string,
        request_version  => $req->protocol // 'HTTP/1.1',
        request_headers  => [ _http_header_pairs( $req->headers ) ],
        request_body     => scalar $req->content,
        query_pairs      => [ _flat_to_pairs( $req->uri->query_form ) ],
        status           => $res->code,
        status_text      => $res->message,
        response_version => $res->protocol // 'HTTP/1.1',
        response_headers => [ _http_header_pairs( $res->headers ) ],
        response_body    => scalar $res->content,
    );
}

sub _build_entry ( $self, %args ) {
    my $req_headers = $args{request_headers};
    my $res_headers = $args{response_headers};

    my $request_body = $args{request_body} // '';

    my $request = {
        method      => $args{method},
        url         => $args{url},
        httpVersion => $args{request_version},
        cookies     => _request_cookies($req_headers),
        headers     => _headers_array($req_headers),
        queryString => [ map { { name => $_->[0], value => $_->[1] } } $args{query_pairs}->@* ],
        headersSize => -1,
        bodySize    => length($request_body),
    };

    if ( length $request_body ) {
        $request->{postData} = {
            mimeType => _header_value( $req_headers, 'Content-Type' ) // '',
            text     => $request_body,
        };
    }

    my $response_body = $args{response_body}                          // '';
    my $mime_type     = _header_value( $res_headers, 'Content-Type' ) // '';

    my $content = {
        size     => length($response_body),
        mimeType => $mime_type,
    };

    if ( length $response_body ) {
        if ( _mime_is_text($mime_type) ) {
            $content->{text} = $response_body;
        } else {
            $content->{text}     = MIME::Base64::encode_base64( $response_body, '' );
            $content->{encoding} = 'base64';
        }
    }

    my $response = {
        status      => $args{status},
        statusText  => $args{status_text} // '',
        httpVersion => $args{response_version},
        cookies     => _response_cookies($res_headers),
        headers     => _headers_array($res_headers),
        content     => $content,
        redirectURL => _header_value( $res_headers, 'Location' ) // '',
        headersSize => -1,
        bodySize    => length($response_body),
    };

    return {
        startedDateTime => _now_iso8601(),
        time            => 0,
        request         => $request,
        response        => $response,
        cache           => {},
        timings         => { send => 0, wait => 0, receive => 0 },
    };
}

sub _mojo_header_pairs ($headers) {
    my @pairs;
    for my $name ( $headers->names->@* ) {
        push @pairs, [ $name, $_ ] for $headers->every_header($name)->@*;
    }
    return @pairs;
}

sub _http_header_pairs ($headers) {
    my @pairs;
    $headers->scan( sub { push @pairs, [ $_[0], $_[1] ] } );
    return @pairs;
}

sub _flat_to_pairs (@flat) {
    my @pairs;
    while (@flat) {
        my $name  = shift @flat;
        my $value = shift @flat;
        push @pairs, [ $name, $value ];
    }
    return @pairs;
}

sub _header_value ( $pairs, $name ) {
    for my $pair (@$pairs) {
        return $pair->[1] if lc( $pair->[0] ) eq lc($name);
    }
    return undef;
}

sub _headers_array ($pairs) {
    return [ map { { name => $_->[0], value => $_->[1] } } @$pairs ];
}

sub _request_cookies ($pairs) {
    my @cookies;

    for my $pair (@$pairs) {
        next unless lc( $pair->[0] ) eq 'cookie';

        for my $part ( split /;\s*/, $pair->[1] ) {
            next unless length $part;
            my ( $name, $value ) = split /=/, $part, 2;
            push @cookies, { name => $name, value => $value // '' };
        }
    }

    return \@cookies;
}

sub _response_cookies ($pairs) {
    my @cookies;

    for my $pair (@$pairs) {
        next unless lc( $pair->[0] ) eq 'set-cookie';

        my @parts      = split /;\s*/, $pair->[1];
        my $name_value = shift @parts;
        next unless defined $name_value;

        my ( $name, $value ) = split /=/, $name_value, 2;
        my $cookie = { name => $name, value => $value // '' };

        for my $attr (@parts) {
            my ( $key, $val ) = split /=/, $attr, 2;
            my $lkey = lc($key);

            if ( $lkey eq 'path' ) {
                $cookie->{path} = $val;
            } elsif ( $lkey eq 'domain' ) {
                $cookie->{domain} = $val;
            } elsif ( $lkey eq 'expires' ) {
                $cookie->{expires} = $val;
            } elsif ( $lkey eq 'httponly' ) {
                $cookie->{httpOnly} = JSON::MaybeXS::true();
            } elsif ( $lkey eq 'secure' ) {
                $cookie->{secure} = JSON::MaybeXS::true();
            }
        }

        push @cookies, $cookie;
    }

    return \@cookies;
}

sub _mime_is_text ($mime) {
    return 1 if $mime =~ m{^text/}i;
    return 1 if $mime =~ m{^application/(?:json|xml|javascript|x-www-form-urlencoded)}i;
    return 1 if $mime =~ m{[+](?:json|xml)}i;
    return 0;
}

sub _now_iso8601 () {
    return POSIX::strftime( '%Y-%m-%dT%H:%M:%S.000Z', gmtime );
}

__END__

=pod

=encoding UTF-8

=head1 NAME

Archive::HAR::Writer - Interface for writing HTTP Archive (HAR) files.

=head1 VERSION

version 0.01

=head1 SYNOPSIS

 use Archive::HAR::Writer;

 my $har = Archive::HAR::Writer->new;
 $har->add_http_transaction([$request, $response]);
 $har->write_file('archive.har');

=head1 DESCRIPTION

This class builds a HTTP Archive (HAR) 1.2 document out of a series of HTTP
transactions, and writes it out as JSON to a file, file handle, or string.

=head1 PROPERTIES

=head2 C<api>

API level to use.  Defaults to 1.  If breaking changes are made to the API,
this value can be used to control which version is used.

=head1 METHODS

=head2 add_http_transaction

 $har->add_http_transaction($transaction);
 $har->add_http_transaction([$request, $response]);

Add the HTTP transaction to the archive.  C<$transaction> should be one of:

=over 4

=item L<Mojo::Transaction::HTTP>

A Mojolicious HTTP transaction object.

=item C<[$request, $response]>

An array reference containing a request and response object.

The C<$request> must be a L<HTTP::Request> and the C<$response>
must be a L<HTTP::Response>.

=back

Other classes may be supported in the future.

=head2 write_file

 $har->write_file($filename);

Write the HAR archive to a file.

=head2 write

 $har->write($fh);
 $har->write(\$string);

Write the HAR archive to a file handle or string reference.

=head1 SEE ALSO

L<Archive::HAR>

=head1 AUTHOR

Graham Ollis <plicease@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2026 by Graham Ollis.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
