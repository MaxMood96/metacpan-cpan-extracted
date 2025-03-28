package Catalyst::Engine;

use Moose;
with 'MooseX::Emulate::Class::Accessor::Fast';

use CGI::Simple::Cookie;
use Data::Dump qw/dump/;
use Errno 'EWOULDBLOCK';
use HTML::Entities;
use HTTP::Headers;
use Plack::Loader;
use Catalyst::EngineLoader;
use Encode 2.21 'decode_utf8', 'encode', 'decode';
use Plack::Request::Upload;
use Hash::MultiValue;
use namespace::clean -except => 'meta';
use utf8;

# Amount of data to read from input on each pass
our $CHUNKSIZE = 64 * 1024;

# XXX - this is only here for compat, do not use!
has env => ( is => 'rw', writer => '_set_env' , weak_ref=>1);
my $WARN_ABOUT_ENV = 0;
around env => sub {
  my ($orig, $self, @args) = @_;
  if(@args) {
    warn "env as a writer is deprecated, you probably need to upgrade Catalyst::Engine::PSGI"
      unless $WARN_ABOUT_ENV++;
    return $self->_set_env(@args);
  }
  return $self->$orig;
};

# XXX - Only here for Engine::PSGI compat
sub prepare_connection {
    my ($self, $ctx) = @_;
    $ctx->request->prepare_connection;
}

=head1 NAME

Catalyst::Engine - The Catalyst Engine

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

=head1 METHODS


=head2 $self->finalize_body($c)

Finalize body.  Prints the response output as blocking stream if it looks like
a filehandle, otherwise write it out all in one go.  If there is no body in
the response, we assume you are handling it 'manually', such as for nonblocking
style or asynchronous streaming responses.  You do this by calling L</write>
several times (which sends HTTP headers if needed) or you close over
C<< $response->write_fh >>.

See L<Catalyst::Response/write> and L<Catalyst::Response/write_fh> for more.

=cut

sub finalize_body {
    my ( $self, $c ) = @_;
    my $res = $c->response; # We use this all over

    ## If we've asked for the write 'filehandle' that means the application is
    ## doing something custom and is expected to close the response
    return if $res->_has_write_fh;

    my $body = $res->body; # save some typing
    if($res->_has_response_cb) {
        ## we have not called the response callback yet, so we are safe to send
        ## the whole body to PSGI

        my @headers;
        $res->headers->scan(sub { push @headers, @_ });

        # We need to figure out what kind of body we have and normalize it to something
        # PSGI can deal with
        if(defined $body) {
            # Handle objects first
            if(blessed($body)) {
                if($body->can('getline')) {
                    # Body is an IO handle that meets the PSGI spec.  Nothing to normalize
                } elsif($body->can('read')) {

                    # In the past, Catalyst only looked for ->read not ->getline.  It is very possible
                    # that one might have an object that respected read but did not have getline.
                    # As a result, we need to handle this case for backcompat.

                    # We will just do the old loop for now.  In a future version of Catalyst this support
                    # will be removed and one will have to rewrite their custom object or use
                    # Plack::Middleware::AdaptFilehandleRead.  In anycase support for this is officially
                    # deprecated and described as such as of 5.90060

                    my $got;
                    do {
                        $got = read $body, my ($buffer), $CHUNKSIZE;
                        $got = 0 unless $self->write($c, $buffer );
                    } while $got > 0;

                    close $body;
                    return;
                } else {
                    # Looks like for  backcompat reasons we need to be able to deal
                    # with stringyfiable objects.
                    $body = ["$body"];
                }
            } elsif(ref $body) {
                if( (ref($body) eq 'GLOB') or (ref($body) eq 'ARRAY')) {
                  # Again, PSGI can just accept this, no transform needed.  We don't officially
                  # document the body as arrayref at this time (and there's not specific test
                  # cases.  we support it because it simplifies some plack compatibility logic
                  # and we might make it official at some point.
                } else {
                   $c->log->error("${\ref($body)} is not a valid value for Response->body");
                   return;
                }
            } else {
                # Body is defined and not an object or reference.  We assume a simple value
                # and wrap it in an array for PSGI
                $body = [$body];
            }
        } else {
            # There's no body...
            $body = [];
        }
        $res->_response_cb->([ $res->status, \@headers, $body]);
        $res->_clear_response_cb;

    } else {
        ## Now, if there's no response callback anymore, that means someone has
        ## called ->write in order to stream 'some stuff along the way'.  I think
        ## for backcompat we still need to handle a ->body.  I guess I could see
        ## someone calling ->write to presend some stuff, and then doing the rest
        ## via ->body, like in a template.

        ## We'll just use the old, existing code for this (or most of it)

        if(my $body = $res->body) {

          if ( blessed($body) && $body->can('read') or ref($body) eq 'GLOB' ) {

              ## In this case we have no choice and will fall back on the old
              ## manual streaming stuff.  Not optimal.  This is deprecated as of 5.900560+

              my $got;
              do {
                  $got = read $body, my ($buffer), $CHUNKSIZE;
                  $got = 0 unless $self->write($c, $buffer );
              } while $got > 0;

              close $body;
          }
          else {

              # Case where body was set after calling ->write.  We'd prefer not to
              # support this, but I can see some use cases with the way most of the
              # views work. Since body has already been encoded, we need to do
              # an 'unencoded_write' here.
              $self->unencoded_write( $c, $body );
          }
        }

        $res->_writer->close;
        $res->_clear_writer;
    }

    return;
}

=head2 $self->finalize_cookies($c)

Create CGI::Simple::Cookie objects from $c->res->cookies, and set them as
response headers.

=cut

sub finalize_cookies {
    my ( $self, $c ) = @_;

    my @cookies;
    my $response = $c->response;

    foreach my $name (keys %{ $response->cookies }) {

        my $val = $response->cookies->{$name};

        my $cookie = (
            blessed($val)
            ? $val
            : CGI::Simple::Cookie->new(
                -name    => $name,
                -value   => $val->{value},
                -expires => $val->{expires},
                -domain  => $val->{domain},
                -path    => $val->{path},
                -secure  => $val->{secure} || 0,
                -httponly => $val->{httponly} || 0,
                -samesite => $val->{samesite},
            )
        );
        if (!defined $cookie) {
            $c->log->warn("undef passed in '$name' cookie value - not setting cookie")
                if $c->debug;
            next;
        }

        push @cookies, $cookie->as_string;
    }

    for my $cookie (@cookies) {
        $response->headers->push_header( 'Set-Cookie' => $cookie );
    }
}

=head2 $self->finalize_error($c)

Output an appropriate error message. Called if there's an error in $c
after the dispatch has finished. Will output debug messages if Catalyst
is in debug mode, or a `please come back later` message otherwise.

=cut

sub _dump_error_page_element {
    my ($self, $i, $element) = @_;
    my ($name, $val)  = @{ $element };

    # This is fugly, but the metaclass is _HUGE_ and demands waaay too much
    # scrolling. Suggestions for more pleasant ways to do this welcome.
    local $val->{'__MOP__'} = "Stringified: "
        . $val->{'__MOP__'} if ref $val eq 'HASH' && exists $val->{'__MOP__'};

    my $text = encode_entities( dump( $val ));
    sprintf <<"EOF", $name, $text;
<h2><a href="#" onclick="toggleDump('dump_$i'); return false">%s</a></h2>
<div id="dump_$i">
    <pre wrap="">%s</pre>
</div>
EOF
}

sub finalize_error {
    my ( $self, $c ) = @_;

    $c->res->content_type('text/html; charset=utf-8');
    my $name = ref($c)->config->{name} || join(' ', split('::', ref $c));

    # Prevent Catalyst::Plugin::Unicode::Encoding from running.
    # This is a little nasty, but it's the best way to be clean whether or
    # not the user has an encoding plugin.

    if ($c->can('encoding')) {
      $c->{encoding} = '';
    }

    my ( $title, $error, $infos );
    if ( $c->debug ) {

        # For pretty dumps
        $error = join '', map {
                '<p><code class="error">'
              . encode_entities($_)
              . '</code></p>'
        } @{ $c->error };
        $error ||= 'No output';
        $error = qq{<pre wrap="">$error</pre>};
        $title = $name = "$name on Catalyst $Catalyst::VERSION";
        $name  = "<h1>$name</h1>";

        # Don't show context in the dump
        $c->res->_clear_context;

        # Don't show body parser in the dump
        $c->req->_clear_body;

        my @infos;
        my $i = 0;
        for my $dump ( $c->dump_these ) {
            push @infos, $self->_dump_error_page_element($i, $dump);
            $i++;
        }
        $infos = join "\n", @infos;
    }
    else {
        $title = $name;
        $error = '';
        $infos = <<"";
<pre>
(en) Please come back later
(fr) SVP veuillez revenir plus tard
(de) Bitte versuchen sie es spaeter nocheinmal
(at) Konnten's bitt'schoen spaeter nochmal reinschauen
(no) Vennligst prov igjen senere
(dk) Venligst prov igen senere
(pl) Prosze sprobowac pozniej
(pt) Por favor volte mais tarde
(ru) Попробуйте еще раз позже
(ua) Спробуйте ще раз пізніше
(it) Per favore riprova più tardi
(cs) Vraťte se prosím později
</pre>

        $name = '';
    }
    $c->res->body( <<"" );
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
    <meta http-equiv="Content-Language" content="en" />
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <title>$title</title>
    <script type="text/javascript">
        <!--
        function toggleDump (dumpElement) {
            var e = document.getElementById( dumpElement );
            if (e.style.display == "none") {
                e.style.display = "";
            }
            else {
                e.style.display = "none";
            }
        }
        -->
    </script>
    <style type="text/css">
        body {
            font-family: "Bitstream Vera Sans", "Trebuchet MS", Verdana,
                         Tahoma, Arial, helvetica, sans-serif;
            color: #333;
            background-color: #eee;
            margin: 0px;
            padding: 0px;
        }
        :link, :link:hover, :visited, :visited:hover {
            color: #000;
        }
        div.box {
            position: relative;
            background-color: #ccc;
            border: 1px solid #aaa;
            padding: 4px;
            margin: 10px;
        }
        div.error {
            background-color: #cce;
            border: 1px solid #755;
            padding: 8px;
            margin: 4px;
            margin-bottom: 10px;
        }
        div.infos {
            background-color: #eee;
            border: 1px solid #575;
            padding: 8px;
            margin: 4px;
            margin-bottom: 10px;
        }
        div.name {
            background-color: #cce;
            border: 1px solid #557;
            padding: 8px;
            margin: 4px;
        }
        code.error {
            display: block;
            margin: 1em 0;
            overflow: auto;
        }
        div.name h1, div.error p {
            margin: 0;
        }
        h2 {
            margin-top: 0;
            margin-bottom: 10px;
            font-size: medium;
            font-weight: bold;
            text-decoration: underline;
        }
        h1 {
            font-size: medium;
            font-weight: normal;
        }
        /* from http://users.tkk.fi/~tkarvine/linux/doc/pre-wrap/pre-wrap-css3-mozilla-opera-ie.html */
        /* Browser specific (not valid) styles to make preformatted text wrap */
        pre {
            white-space: pre-wrap;       /* css-3 */
            white-space: -moz-pre-wrap;  /* Mozilla, since 1999 */
            white-space: -pre-wrap;      /* Opera 4-6 */
            white-space: -o-pre-wrap;    /* Opera 7 */
            word-wrap: break-word;       /* Internet Explorer 5.5+ */
        }
    </style>
</head>
<body>
    <div class="box">
        <div class="error">$error</div>
        <div class="infos">$infos</div>
        <div class="name">$name</div>
    </div>
</body>
</html>

    # Trick IE. Old versions of IE would display their own error page instead
    # of ours if we'd give it less than 512 bytes.
    $c->res->{body} .= ( ' ' x 512 );

    $c->res->{body} = Encode::encode("UTF-8", $c->res->{body});

    # Return 500
    $c->res->status(500);
}

=head2 $self->finalize_headers($c)

Allows engines to write headers to response

=cut

sub finalize_headers {
    my ($self, $ctx) = @_;

    $ctx->finalize_headers unless $ctx->response->finalized_headers;
    return;
}

=head2 $self->finalize_uploads($c)

Clean up after uploads, deleting temp files.

=cut

sub finalize_uploads {
    my ( $self, $c ) = @_;

    # N.B. This code is theoretically entirely unneeded due to ->cleanup(1)
    #      on the HTTP::Body object.
    my $request = $c->request;
    foreach my $key (keys %{ $request->uploads }) {
        my $upload = $request->uploads->{$key};
        unlink grep { -e $_ } map { $_->tempname }
          (ref $upload eq 'ARRAY' ? @{$upload} : ($upload));
    }

}

=head2 $self->prepare_body($c)

sets up the L<Catalyst::Request> object body using L<HTTP::Body>

=cut

sub prepare_body {
    my ( $self, $c ) = @_;

    $c->request->prepare_body;
}

=head2 $self->prepare_body_chunk($c)

Add a chunk to the request body.

=cut

# XXX - Can this be deleted?
sub prepare_body_chunk {
    my ( $self, $c, $chunk ) = @_;

    $c->request->prepare_body_chunk($chunk);
}

=head2 $self->prepare_body_parameters($c)

Sets up parameters from body.

=cut

sub prepare_body_parameters {
    my ( $self, $c ) = @_;

    $c->request->prepare_body_parameters;
}

=head2 $self->prepare_parameters($c)

Sets up parameters from query and post parameters.
If parameters have already been set up will clear
existing parameters and set up again.

=cut

sub prepare_parameters {
    my ( $self, $c ) = @_;

    $c->request->_clear_parameters;
    return $c->request->parameters;
}

=head2 $self->prepare_path($c)

abstract method, implemented by engines.

=cut

sub prepare_path {
    my ($self, $ctx) = @_;

    my $env = $ctx->request->env;

    my $scheme    = $ctx->request->secure ? 'https' : 'http';
    my $host      = $env->{HTTP_HOST} || $env->{SERVER_NAME};
    my $port      = $env->{SERVER_PORT} || 80;
    my $base_path = $env->{SCRIPT_NAME} || "/";

    # set the request URI
    my $path;
    if (!$ctx->config->{use_request_uri_for_path}) {
        my $path_info = $env->{PATH_INFO};
        if ( exists $env->{REDIRECT_URL} ) {
            $base_path = $env->{REDIRECT_URL};
            $base_path =~ s/\Q$path_info\E$//;
        }
        $path = $base_path . $path_info;
        $path =~ s{^/+}{};
        $path =~ s/([^$URI::uric])/$URI::Escape::escapes{$1}/go;
        $path =~ s/\?/%3F/g; # STUPID STUPID SPECIAL CASE
    }
    else {
        my $req_uri = $env->{REQUEST_URI};
        $req_uri =~ s/\?.*$//;
        $path = $req_uri;
        $path =~ s{^/+}{};
    }

    # Using URI directly is way too slow, so we construct the URLs manually
    my $uri_class = "URI::$scheme";

    # HTTP_HOST will include the port even if it's 80/443
    $host =~ s/:(?:80|443)$//;

    if ($port !~ /^(?:80|443)$/ && $host !~ /:/) {
        $host .= ":$port";
    }

    my $query = $env->{QUERY_STRING} ? '?' . $env->{QUERY_STRING} : '';
    my $uri   = $scheme . '://' . $host . '/' . $path . $query;

    $ctx->request->uri( (bless \$uri, $uri_class)->canonical );

    # set the base URI
    # base must end in a slash
    $base_path .= '/' unless $base_path =~ m{/$};

    my $base_uri = $scheme . '://' . $host . $base_path;

    $ctx->request->base( bless \$base_uri, $uri_class );

    return;
}

=head2 $self->prepare_request($c)

=head2 $self->prepare_query_parameters($c)

process the query string and extract query parameters.

=cut

sub prepare_query_parameters {
    my ($self, $c) = @_;
    my $env = $c->request->env;
    my $do_not_decode_query = $c->config->{do_not_decode_query};

    my $old_encoding;
    if(my $new = $c->config->{default_query_encoding}) {
      $old_encoding = $c->encoding;
      $c->encoding($new);
    }

    my $check = $c->config->{do_not_check_query_encoding} ? undef :$c->_encode_check;
    my $decoder = sub {
      my $str = shift;
      return $str if $do_not_decode_query;
      return $c->_handle_param_unicode_decoding($str, $check);
    };

    my $query_string = exists $env->{QUERY_STRING}
        ? $env->{QUERY_STRING}
        : '';

    $query_string =~ s/\A[&;]+//;

    my @unsplit_pairs = split /[&;]+/, $query_string;
    my $p = Hash::MultiValue->new();

    my $is_first_pair = 1;
    for my $pair (@unsplit_pairs) {
        my ($name, $value)
          = map { defined $_ ? $decoder->($self->unescape_uri($_)) : $_ }
            ( split /=/, $pair, 2 )[0,1]; # slice forces two elements

        if ($is_first_pair) {
            # If the first pair has no equal sign, then it means the isindex
            # flag is set.
            $c->request->query_keywords($name) unless defined $value;

            $is_first_pair = 0;
        }

        $p->add( $name => $value );
    }


    $c->encoding($old_encoding) if $old_encoding;
    $c->request->query_parameters( $c->request->_use_hash_multivalue ? $p : $p->mixed );
}

=head2 $self->prepare_read($c)

Prepare to read by initializing the Content-Length from headers.

=cut

sub prepare_read {
    my ( $self, $c ) = @_;

    # Initialize the amount of data we think we need to read
    $c->request->_read_length;
}

=head2 $self->prepare_request(@arguments)

Populate the context object from the request object.

=cut

sub prepare_request {
    my ($self, $ctx, %args) = @_;
    $ctx->log->psgienv($args{env}) if $ctx->log->can('psgienv');
    $ctx->request->_set_env($args{env});
    $self->_set_env($args{env}); # Nasty back compat!
    $ctx->response->_set_response_cb($args{response_cb});
}

=head2 $self->prepare_uploads($c)

=cut

sub prepare_uploads {
    my ( $self, $c ) = @_;

    my $request = $c->request;
    return unless $request->_body;

    my $enc = $c->encoding;
    my $uploads = $request->_body->upload;
    my $parameters = $request->parameters;
    foreach my $name (keys %$uploads) {
        my $files = $uploads->{$name};
        $name = $c->_handle_unicode_decoding($name) if $enc;
        my @uploads;
        for my $upload (ref $files eq 'ARRAY' ? @$files : ($files)) {
            my $headers = HTTP::Headers->new( %{ $upload->{headers} } );
            my $filename = $upload->{filename};
            $filename = $c->_handle_unicode_decoding($filename) if $enc;

            my $u = Catalyst::Request::Upload->new
              (
               size => $upload->{size},
               type => scalar $headers->content_type,
               charset => scalar $headers->content_type_charset,
               headers => $headers,
               tempname => $upload->{tempname},
               filename => $filename,
              );
            push @uploads, $u;
        }
        $request->uploads->{$name} = @uploads > 1 ? \@uploads : $uploads[0];

        # support access to the filename as a normal param
        my @filenames = map { $_->{filename} } @uploads;
        # append, if there's already params with this name
        if (exists $parameters->{$name}) {
            if (ref $parameters->{$name} eq 'ARRAY') {
                push @{ $parameters->{$name} }, @filenames;
            }
            else {
                $parameters->{$name} = [ $parameters->{$name}, @filenames ];
            }
        }
        else {
            $parameters->{$name} = @filenames > 1 ? \@filenames : $filenames[0];
        }
    }
}

=head2 $self->write($c, $buffer)

Writes the buffer to the client.

=cut

sub write {
    my ( $self, $c, $buffer ) = @_;

    $c->response->write($buffer);
}

=head2 $self->unencoded_write($c, $buffer)

Writes the buffer to the client without encoding. Necessary for
already encoded buffers. Used when a $c->write has been done
followed by $c->res->body.

=cut

sub unencoded_write {
    my ( $self, $c, $buffer ) = @_;

    $c->response->unencoded_write($buffer);
}

=head2 $self->read($c, [$maxlength])

Reads from the input stream by calling C<< $self->read_chunk >>.

Maintains the read_length and read_position counters as data is read.

=cut

sub read {
    my ( $self, $c, $maxlength ) = @_;

    $c->request->read($maxlength);
}

=head2 $self->read_chunk($c, \$buffer, $length)

Each engine implements read_chunk as its preferred way of reading a chunk
of data. Returns the number of bytes read. A return of 0 indicates that
there is no more data to be read.

=cut

sub read_chunk {
    my ($self, $ctx) = (shift, shift);
    return $ctx->request->read_chunk(@_);
}

=head2 $self->run($app, $server)

Start the engine. Builds a PSGI application and calls the
run method on the server passed in, which then causes the
engine to loop, handling requests..

=cut

sub run {
    my ($self, $app, $psgi, @args) = @_;
    # @args left here rather than just a $options, $server for back compat with the
    # old style scripts which send a few args, then a hashref

    # They should never actually be used in the normal case as the Plack engine is
    # passed in got all the 'standard' args via the loader in the script already.

    # FIXME - we should stash the options in an attribute so that custom args
    # like Gitalist's --git_dir are possible to get from the app without stupid tricks.
    my $server = pop @args if (scalar @args && blessed $args[-1]);
    my $options = pop @args if (scalar @args && ref($args[-1]) eq 'HASH');
    # Back compat hack for applications with old (non Catalyst::Script) scripts to work in FCGI.
    if (scalar @args && !ref($args[0])) {
        if (my $listen = shift @args) {
            $options->{listen} ||= [$listen];
        }
    }
    if (! $server ) {
        $server = Catalyst::EngineLoader->new(application_name => ref($self))->auto(%$options);
        # We're not being called from a script, so auto detect what backend to
        # run on.  This should never happen, as mod_perl never calls ->run,
        # instead the $app->handle method is called per request.
        $app->log->warn("Not supplied a Plack engine, falling back to engine auto-loader (are your scripts ancient?)")
    }
    $app->run_options($options);
    $server->run($psgi, $options);
}

=head2 build_psgi_app ($app, @args)

Builds and returns a PSGI application closure. (Raw, not wrapped in middleware)

=cut

sub build_psgi_app {
    my ($self, $app, @args) = @_;

    return sub {
        my ($env) = @_;

        return sub {
            my ($respond) = @_;
            confess("Did not get a response callback for writer, cannot continue") unless $respond;
            $app->handle_request(env => $env, response_cb => $respond);
        };
    };
}

=head2 $self->unescape_uri($uri)

Unescapes a given URI using the most efficient method available.  Engines such
as Apache may implement this using Apache's C-based modules, for example.

=cut

sub unescape_uri {
    my ( $self, $str ) = @_;

    $str =~ s/(?:%([0-9A-Fa-f]{2})|\+)/defined $1 ? chr(hex($1)) : ' '/eg;

    return $str;
}

=head2 $self->finalize_output

<obsolete>, see finalize_body

=head2 $self->env

Hash containing environment variables including many special variables inserted
by WWW server - like SERVER_*, REMOTE_*, HTTP_* ...

Before accessing environment variables consider whether the same information is
not directly available via Catalyst objects $c->request, $c->engine ...

BEWARE: If you really need to access some environment variable from your Catalyst
application you should use $c->engine->env->{VARNAME} instead of $ENV{VARNAME},
as in some environments the %ENV hash does not contain what you would expect.

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
