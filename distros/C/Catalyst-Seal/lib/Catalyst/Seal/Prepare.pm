package Catalyst::Seal::Prepare;

use strict;
use warnings;

use Scalar::Util ();

use Catalyst::Seal ();
use Catalyst::Seal::Guard ();

our $VERSION = '0.01';

my $DONE = 0;

# Catalyst.pm:3685 as of 5.90132
sub _handle_param_unicode_decoding {
    my ( $self, $value, $check ) = @_;
    return unless defined $value;
    return $value if Scalar::Util::blessed($value);

    my $enc = $self->encoding;

    return $value unless $enc;

    $check ||= $self->_encode_check;

    local $@;
    my @out = eval { $enc->decode( $value, $check ) };
    my $err = $@;
    return wantarray ? @out : $out[0] unless $err;

    return $self->handle_unicode_encoding_exception({
        param_value   => $value,
        error_msg     => $err,
        encoding_step => 'params',
    });
}

use constant _FIELD_MAX => 256;

# env key => 0 to skip, 1 to use the stock path, or [ $lc_field, $std_case ]
#
# Nothing a remembered answer depends on can change while the process runs.
# HTTP::Headers' list of known spellings is a lexical fixed at compile time,
# and C<$HTTP::Headers::TRANSLATE_UNDERSCORE>, which anyone may set at any
# point, cannot reach this: Catalyst translates the underscores itself before
# calling C<header>, so the field name HTTP::Headers is given never has one
# left to translate. That was written as a reset of the memo first, and the
# reset was removed when no test could tell it from its absence.
my %FIELD;

sub _learn_field {
    my ($key) = @_;

    return 0 unless $key =~ /^(HTTP|CONTENT|COOKIE)/i;

    (my $field = $key) =~ s/^HTTPS?_//;
    $field =~ tr/_/-/;

    require HTTP::Headers;
    my $probe = HTTP::Headers->new;
    my $ok = eval { $probe->header($field => 'probe'); 1 };
    return 1 unless $ok;

    my $std = delete $probe->{'::std_case'};
    my @keys = keys %$probe;
    return 1 unless @keys == 1;

    # One plain string, stored under one key. Anything else is a version of
    # HTTP::Headers that keeps its state differently and this cannot write it.
    my $stored = $probe->{ $keys[0] };
    return 1 if ref $stored;
    return 1 unless defined $stored && $stored eq 'probe';

    return 1 if $std && keys %$std != 1;
    return [ $keys[0], $std ? $std->{ $keys[0] } : undef ];
}

# Catalyst/Request.pm:78 as of 5.90132
sub _prepare_headers {
    my ($self) = @_;

    my $env = $self->env;
    my $headers = HTTP::Headers->new();
    my %std;

    for my $key (keys %$env) {
        my $field = $FIELD{$key};
        unless (defined $field) {
            # Past the cap an unrecognised key is not learned at all, because
            # learning is itself the expensive path and a client choosing the
            # key must not be able to ask for it.
            if (keys(%FIELD) >= _FIELD_MAX) {
                next unless $key =~ /^(HTTP|CONTENT|COOKIE)/i;
                $field = 1;
            }
            else {
                $field = $FIELD{$key} = _learn_field($key);
            }
        }
        next unless $field;

        my $value = $env->{$key};

        # An undefined value is a delete rather than a store, and it still
        # leaves the ::std_case entry behind. An arrayref is flattened, and a
        # one element one is stored as its element rather than as itself. PSGI
        # says these are strings, so both are handed back rather than handled.
        if (!ref $field || !defined $value || ref $value) {
            (my $name = $key) =~ s/^HTTPS?_//;
            $name =~ tr/_/-/;
            $headers->header($name => $value);
            next;
        }

        $headers->{ $field->[0] } = $value;
        $std{ $field->[0] } = $field->[1] if defined $field->[1];
    }

    if (%std) {
        # header() may have created some of its own on the slow path above.
        my $existing = $headers->{'::std_case'};
        @std{ keys %$existing } = values %$existing if $existing;
        $headers->{'::std_case'} = \%std;
    }

    return $headers;
}

my $FAST_CANONICAL = 0;

sub _probe_canonical {
    require URI;
    require URI::http;

    # Already canonical: canonical must hand back the very same object.
    for my $str ('http://127.0.0.1/', 'http://example.com:8080/a/b?x=Y',
                 'https://example.com/') {
        my $uri = $str;
        my $obj = bless \$uri, 'URI::http';
        my $out = eval { $obj->canonical };
        return 0 unless $out && Scalar::Util::refaddr($out) == Scalar::Util::refaddr($obj);
    }

    # Not canonical: it must not, or the check above proves nothing.
    for my $str ('http://EXAMPLE.com/', 'http://example.com:80/', 'http://example.com/%2f') {
        my $uri = $str;
        my $obj = bless \$uri, 'URI::http';
        my $out = eval { $obj->canonical };
        return 0 unless $out && Scalar::Util::refaddr($out) != Scalar::Util::refaddr($obj);
    }

    return 1;
}

# Catalyst/Engine.pm:511 as of 5.90132
sub _prepare_path {
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

    my $uri_class = "URI::$scheme";

    # HTTP_HOST will include the port even if it's 80/443
    $host =~ s/:(?:80|443)$//;

    if ($port !~ /^(?:80|443)$/ && $host !~ /:/) {
        $host .= ":$port";
    }

    my $query = $env->{QUERY_STRING} ? '?' . $env->{QUERY_STRING} : '';
    my $uri   = $scheme . '://' . $host . '/' . $path . $query;
    my $obj   = bless \$uri, $uri_class;

    $ctx->request->uri(
        (        $uri !~ /%[0-9A-Fa-f]{2}/
              && $uri =~ m{\A[a-z][a-z0-9+.\-]*://([^/?\#]*)}
              && $1 !~ /[A-Z:]/ )
            ? $obj
            : $obj->canonical
    );

    # set the base URI
    # base must end in a slash
    $base_path .= '/' unless $base_path =~ m{/$};

    my $base_uri = $scheme . '://' . $host . $base_path;

    $ctx->request->base( bless \$base_uri, $uri_class );

    return;
}

# Every site here lives in a module shared by every application in the process,
# so the patches are global and idempotent rather than per application.
Catalyst::Seal::register_step('prepare' => sub {
    return if $DONE++;

    require HTTP::Headers;
    require URI;
    require URI::Escape;

    Catalyst::Seal::Guard::replace(
        'Catalyst::_handle_param_unicode_decoding' => \&_handle_param_unicode_decoding);

    Catalyst::Seal::Guard::replace(
        'Catalyst::Request::prepare_headers' => \&_prepare_headers);

    if (_probe_canonical()) {
        $FAST_CANONICAL = 1;
        Catalyst::Seal::Guard::replace(
            'Catalyst::Engine::prepare_path' => \&_prepare_path);
    }
    else {
        Catalyst::Seal::note(
            'URI::canonical does not behave the way prepare_path relies on, path not patched');
    }

    return;
});

sub fast_canonical { $FAST_CANONICAL }

1;

__END__

=head1 NAME

Catalyst::Seal::Prepare - the request preparation path

=head1 DESCRIPTION

C<Catalyst::prepare> turns a PSGI environment into a request object. What that
costs, measured by replacing each part with a stub that answers from a constant
and timing the whole request, on a hello world application with phases 0 to 3
already applied:

    prepare_query_parameters   4.3 us on an empty query string
                              34.0 us on "a=1&b=two&c=caf%C3%A9&d=one+two"
    prepare_path               8.0 us
    prepare_headers            7.3 us

A stub is the ceiling: no implementation of a subroutine beats not running it.
Splitting the first of those again says where it goes, and it is not where the
plan for this phase expected:

    the whole unicode decoding step   23.7 us
      of which Try::Tiny              15.0 us
    percent and plus unescaping        2.7 us

So the largest single item in request preparation is not parsing. It is that
L<Catalyst> decodes every parameter name and every parameter value inside a
L<Try::Tiny> block, which builds two closures and names them, per string.

=head2 What this module does

=over 4

=item * C<Catalyst::_handle_param_unicode_decoding>, C<try> rewritten as
C<eval>. Query parameters, body parameters and path arguments all decode
through it, so it is paid once per string in the request.

=item * C<Catalyst::Request::prepare_headers>, building the
L<HTTP::Headers> hash directly instead of through 29 C<header> calls.

=item * C<Catalyst::Engine::prepare_path>, skipping C<URI::canonical> when the
URI it just built is already canonical, which is decidable with one regex and
costs three authority parses to ask L<URI>.

=back

=cut

=head2 The parameter decoder

C<Catalyst::_handle_param_unicode_decoding> is phase 0.4 applied to a third
site, with the same three things to preserve:

C<$@> is read immediately after the C<eval>, and C<local $@> restores the
caller's, which is what L<Try::Tiny> does and a bare C<eval> does not.

C<eval { ...; 1 }> is not used here because the value of the block is the
return value. C<@out> distinguishes a failed decode from one that returned
false, which testing C<$@> alone would not.

C<return unless defined $value> returns the empty list in list context, and
this subroutine is called from inside a C<map>. It stays exactly as it is.

=cut

=head2 The headers

L<HTTP::Headers> stores a header as C<$self-E<gt>{lc $field}>, plus an entry in
C<$self-E<gt>{'::std_case'}> naming the spelling to use on the way out for any
field it does not already know. Building that hash directly is a third of
C<prepare_headers>.

The spelling is not copied out of L<HTTP::Headers>. Its list of known headers
is a lexical, and a copy of it here would be wrong the day a header is added to
it, in a way that only shows up in the C<as_string> of a response. Instead the
first request that carries a given environment key sets that one header on a
throwaway L<HTTP::Headers> the ordinary way and remembers what came out. The
answer is HTTP::Headers' own, so there is nothing to keep in step, and the
probe is also the check: a field whose result is not one plain string under one
key is left to the stock path forever.

The memo is bounded. A client that sends a thousand distinct header names must
not be able to grow it, so past the cap an unrecognised key takes the stock
path and is not remembered.

=cut

=head2 The path

C<prepare_path> builds the request URI as a string, blesses a reference to it
into C<URI::http>, and calls C<canonical>. C<URI::_server::canonical> parses the
authority three times to decide whether anything needs canonicalising, and on a
URI that is already canonical it returns the object it was given.

That decision is one regex here: a lower case scheme, no percent escape
anywhere in the string, and an authority with no upper case and no port. Under
those three conditions L<URI> cannot find anything to change, and returns the
same object this would.

The conditions are checked against L<URI> itself at seal time rather than
against its source, because what matters is the behaviour and not the spelling.
A negative control is part of that: a probe that only ever confirms is a probe
that would pass against a C<canonical> that had stopped working.

=cut

=head2 fast_canonical

    my $bool = Catalyst::Seal::Prepare::fast_canonical();

Whether the C<prepare_path> patch was installed. For the test suite.

=cut

=head1 AUTHOR

LNATION <email@lnation.org>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by LNATION <email@lnation.org>.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut

