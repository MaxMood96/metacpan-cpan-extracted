package SealTest;

use strict;
use warnings;

# Shared request table and drivers for the Catalyst::Seal test suite.

my $EMPTY = '';

# An explicit undef in %over deletes the key, which is how a request with no
# HTTP_HOST is expressed.
sub env {
    my (%over) = @_;
    open my $in, '<', \$EMPTY or die $!;
    my $env = {
        REQUEST_METHOD     => 'GET',
        PATH_INFO          => '/',
        QUERY_STRING       => '',
        SCRIPT_NAME        => '',
        SERVER_NAME        => '127.0.0.1',
        SERVER_PORT        => 80,
        SERVER_PROTOCOL    => 'HTTP/1.1',
        HTTP_HOST          => '127.0.0.1',
        REMOTE_ADDR        => '127.0.0.1',
        HTTP_USER_AGENT    => 'sealtest',
        HTTP_ACCEPT        => '*/*',
        'psgi.version'     => [1, 1],
        'psgi.url_scheme'  => 'http',
        'psgi.input'       => $in,
        'psgi.errors'      => \*STDERR,
        'psgi.multithread' => 0,
        'psgi.multiprocess' => 1,
        'psgi.run_once'    => 0,
        'psgi.nonblocking' => 0,
        'psgi.streaming'   => 1,
        %over,
    };
    defined $env->{$_} or delete $env->{$_} for keys %$env;
    return $env;
}

# Every request the parity test drives. Each entry selects a different branch,
# which is the point: volume tests one path many times.
sub requests {
    return (
        { name => 'root',        env => { PATH_INFO => '/' } },
        { name => 'args',        env => { PATH_INFO => '/books/42' } },
        { name => 'query-empty', env => { PATH_INFO => '/query' } },
        { name => 'query-pair',  env => { PATH_INFO => '/query', QUERY_STRING => 'a=1' } },
        { name => 'query-dup',   env => { PATH_INFO => '/query', QUERY_STRING => 'a=1&a=2' } },
        { name => 'query-bare',  env => { PATH_INFO => '/query', QUERY_STRING => 'a' } },
        { name => 'query-plus',  env => { PATH_INFO => '/query', QUERY_STRING => 'a=one+two' } },
        { name => 'query-utf8',  env => { PATH_INFO => '/query', QUERY_STRING => 'a=caf%C3%A9' } },
        { name => 'headers',     env => { PATH_INFO => '/headers', HTTP_X_THING => 'yes' } },
        { name => 'redirect',    env => { PATH_INFO => '/redirect' } },
        { name => 'no-content',  env => { PATH_INFO => '/nobody' } },
        { name => 'redirect-fh', env => { PATH_INFO => '/redirect-fh' } },
        { name => 'redirect-io', env => { PATH_INFO => '/redirect-io' } },
        { name => 'redirect-fh-head',
          env => { PATH_INFO => '/redirect-fh', REQUEST_METHOD => 'HEAD' } },
        { name => 'wide',        env => { PATH_INFO => '/wide' } },
        { name => 'forward',     env => { PATH_INFO => '/forwarded' } },
        { name => 'not-found',   env => { PATH_INFO => '/no/such/thing' } },
        { name => 'appname',     env => { PATH_INFO => '/appname' } },
        { name => 'die',         env => { PATH_INFO => '/boom' } },
        { name => 'http-error',  env => { PATH_INFO => '/httperr' } },
        { name => 'head',        env => { PATH_INFO => '/', REQUEST_METHOD => 'HEAD' } },
        { name => 'head-args',   env => { PATH_INFO => '/books/7', REQUEST_METHOD => 'HEAD' } },
        { name => 'script-name', env => { PATH_INFO => '/', SCRIPT_NAME => '/mounted' } },
        { name => 'no-host',     env => { PATH_INFO => '/', HTTP_HOST => undef } },
        # The begin / auto / action / end chain, which is what phase 5 flattens.
        # Each of these puts the order the chain ran in into the body.
        { name => 'chain-ok',      env => { PATH_INFO => '/steps/ok' } },
        { name => 'chain-halt',    env => { PATH_INFO => '/steps/halt' } },
        { name => 'chain-die',     env => { PATH_INFO => '/steps/boom' } },
        { name => 'chain-detach',  env => { PATH_INFO => '/steps/detach' } },
        { name => 'chain-forward', env => { PATH_INFO => '/steps/forward' } },
        { name => 'chain-visit',   env => { PATH_INFO => '/steps/visit' } },
        { name => 'chain-depth',   env => { PATH_INFO => '/steps/depth' } },

        # CVE-2026-85491. A route decision is not a function of the path alone:
        # these are driven in order, so the GET in the middle is exactly the
        # request that poisoned the path in 0.02. Sealed and stock must agree
        # on every one of them.
        { name => 'guard-post-1',  env => { PATH_INFO => '/guard/post',
                                            REQUEST_METHOD => 'POST' } },
        { name => 'guard-get',     env => { PATH_INFO => '/guard/post',
                                            REQUEST_METHOD => 'GET' } },
        { name => 'guard-post-2',  env => { PATH_INFO => '/guard/post',
                                            REQUEST_METHOD => 'POST' } },
        { name => 'guard-deep-1',  env => { PATH_INFO => '/guard/thing/edit',
                                            REQUEST_METHOD => 'POST' } },
        { name => 'guard-deep-get',env => { PATH_INFO => '/guard/thing/edit',
                                            REQUEST_METHOD => 'GET' } },
        { name => 'guard-deep-2',  env => { PATH_INFO => '/guard/thing/edit',
                                            REQUEST_METHOD => 'POST' } },
        # The encoding matrix. A mistake here is silent until somebody posts
        # non-ASCII, so it is driven by the parity table rather than by a
        # hand-written expectation.
        (map {
            my $q = $_->[1];
            { name => "enc-$_->[0]", env => { PATH_INFO => '/enc', QUERY_STRING => $q } }
        }
            ['plain',          'kind=ascii'],
            ['no-type',        'kind=wide'],
            ['text',           'ct=text/plain&kind=wide'],
            ['text-utf8',      'ct=text/plain%3B%20charset=UTF-8&kind=wide'],
            ['text-latin1',    'ct=text/plain%3B%20charset=ISO-8859-1&kind=wide'],
            ['json',           'ct=application/json&kind=wide'],
            ['octet',          'ct=application/octet-stream&kind=wide'],
            ['png',            'ct=image/png&kind=bytes'],
            ['param',          'ct=text/plain%3B%20format=flowed&kind=wide'],
            ['empty-type',     'ct=&kind=wide'],
            ['gzip',           'ct=text/plain&cenc=gzip&kind=wide'],
            ['identity',       'ct=text/plain&cenc=identity&kind=wide'],
            ['bytes-body',     'ct=text/plain&kind=bytes'],
            ['array-body',     'ct=text/plain&kind=array'],
            ['empty-body',     'ct=text/plain&kind=empty'],
            ['undef-body',     'ct=text/plain&kind=undef'],
            ['fh-body',        'ct=text/plain&kind=fh'],
            ['enc-cleared',    'ct=text/plain&kind=wide&encoding=clear'],
            ['enc-latin1',     'ct=text/plain&kind=wide&encoding=ISO-8859-1'],
            ['enc-utf8',       'ct=text/plain&kind=wide&encoding=UTF-8'],
        ),
    );
}

# One response, flattened to a string so two processes can be compared without
# agreeing on a serialiser.
sub flatten {
    my ($res) = @_;

    # Catalyst returns a delayed response whenever psgi.streaming is set, which
    # every real server sets, so this is the normal shape and not an edge case.
    if (ref $res eq 'CODE') {
        my ($triplet, $written) = (undef, '');
        $res->(sub {
            $triplet = $_[0];
            return if @{ $_[0] } >= 3;
            return SealTest::Writer->new(\$written);
        });
        return 'DELAYED-WITH-NO-TRIPLET' unless $triplet;
        $res = @$triplet >= 3 ? $triplet : [ @$triplet, [$written] ];
    }

    return 'NOT-AN-ARRAYREF: ' . (ref($res) || 'undef') unless ref $res eq 'ARRAY';

    my ($status, $headers, $body) = @$res;
    my @h;
    for (my $i = 0; $i < @$headers; $i += 2) {
        my ($k, $v) = ($headers->[$i], $headers->[$i + 1]);
        # Date and any other clock-derived header would differ between the two
        # runs for reasons that are not the thing under test.
        next if lc($k) eq 'date';
        push @h, lc($k) . ': ' . (defined $v ? $v : '(undef)');
    }

    my $text = '';
    if (!defined $body) {
        $text = '(no body)';
    }
    elsif (ref $body eq 'ARRAY') {
        $text = join '', map { defined $_ ? $_ : '' } @$body;
    }
    else {
        while (defined(my $chunk = $body->getline)) { $text .= $chunk }
        $body->close if $body->can('close');
    }

    return join "\n", "status: $status", @h, 'body: ' . _escape($text);
}

sub _escape {
    my ($s) = @_;
    $s =~ s/([^\x20-\x7e])/sprintf '\\x{%02x}', ord $1/ge;
    return $s;
}

# Drive every request in the table and return name => flattened response.
sub drive {
    my ($app) = @_;
    my %out;
    for my $req (requests()) {
        my $res = eval { $app->(env(%{ $req->{env} })) };
        $out{ $req->{name} } = $@ ? "DIED: $@" : flatten($res);
    }
    return \%out;
}

{
    package SealTest::Writer;
    sub new   { bless { out => $_[1] }, $_[0] }
    sub write { ${ $_[0]{out} } .= $_[1]; return }
    sub close { return }
}

# The response as a plain arrayref, for tests that want to poke at it rather
# than compare a string.
sub response {
    my ($app, %over) = @_;
    my $res = $app->(env(%over));
    return $res if ref $res eq 'ARRAY';
    my ($triplet, $written) = (undef, '');
    $res->(sub {
        $triplet = $_[0];
        return if @{ $_[0] } >= 3;
        return SealTest::Writer->new(\$written);
    });
    # A request that died before the responder was called leaves no triplet at
    # all. Report that as a result rather than dying here, so a test asserting
    # on it says what happened instead of taking the file down.
    return [ 0, [], ['DELAYED-WITH-NO-TRIPLET'] ] unless $triplet;
    return @$triplet >= 3 ? $triplet : [ @$triplet, [$written] ];
}

1;
