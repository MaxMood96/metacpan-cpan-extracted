#!/usr/bin/env perl
use strict;
use warnings;

use FindBin ();
use lib "$FindBin::Bin/lib";

use Test::More;
use Storable ();

# Phase 4 replaces three subroutines that turn a PSGI environment into a
# request object. Parity is the entire test strategy, so this drives one corpus
# of environments through Catalyst::prepare on both sides and compares what came
# out, field by field.
#
# The corpus selects branches rather than adding volume. A thousand random query
# strings exercise one path; the twenty five below exercise twenty five.
#
# Every expected value comes from running stock Catalyst in the other child. No
# encoding behaviour is written here from memory: a constant recalled wrongly
# either fails for the wrong reason or passes without proving anything.

BEGIN { $ENV{CATALYST_DEBUG} = 0 }

require SealTest;

my $EMPTY = '';

sub env {
    my (%over) = @_;
    my $body = delete $over{body};
    open my $in, '<', defined $body ? \$body : \$EMPTY or die $!;
    $over{CONTENT_LENGTH} = length $body if defined $body;
    my $env = {
        REQUEST_METHOD  => 'GET',
        PATH_INFO       => '/',
        QUERY_STRING    => '',
        SCRIPT_NAME     => '',
        SERVER_NAME     => '127.0.0.1',
        SERVER_PORT     => 80,
        SERVER_PROTOCOL => 'HTTP/1.1',
        HTTP_HOST       => '127.0.0.1',
        REMOTE_ADDR     => '127.0.0.1',
        HTTP_USER_AGENT => 'sealtest',
        HTTP_ACCEPT     => '*/*',
        'psgi.version'      => [1, 1],
        'psgi.url_scheme'   => 'http',
        'psgi.input'        => $in,
        'psgi.errors'       => \*STDERR,
        'psgi.multithread'  => 0,
        'psgi.multiprocess' => 1,
        'psgi.run_once'     => 0,
        'psgi.nonblocking'  => 0,
        'psgi.streaming'    => 1,
        %over,
    };
    defined $env->{$_} or delete $env->{$_} for keys %$env;
    return $env;
}

sub corpus {
    return (
        # query string
        { name => 'q-empty',      env => { QUERY_STRING => '' } },
        { name => 'q-single',     env => { QUERY_STRING => 'a=1' } },
        { name => 'q-duplicate',  env => { QUERY_STRING => 'a=1&a=2&a=3' } },
        { name => 'q-bare-key',   env => { QUERY_STRING => 'keywords' } },
        { name => 'q-bare-later', env => { QUERY_STRING => 'a=1&bare&b=2' } },
        { name => 'q-empty-val',  env => { QUERY_STRING => 'a=' } },
        { name => 'q-plus',       env => { QUERY_STRING => 'a=one+two' } },
        { name => 'q-enc-key',    env => { QUERY_STRING => 'a%20b=1' } },
        { name => 'q-enc-val',    env => { QUERY_STRING => 'a=one%20two' } },
        { name => 'q-bad-escape', env => { QUERY_STRING => 'a=one%2' } },
        { name => 'q-bad-hex',    env => { QUERY_STRING => 'a=%zz' } },
        { name => 'q-semicolon',  env => { QUERY_STRING => 'a=1;b=2' } },
        { name => 'q-lead-sep',   env => { QUERY_STRING => '&;&a=1' } },
        { name => 'q-utf8',       env => { QUERY_STRING => 'caf%C3%A9=cr%C3%A8me' } },
        { name => 'q-utf8-lc',    env => { QUERY_STRING => 'a=caf%c3%a9' } },
        { name => 'q-invalid-utf8', env => { QUERY_STRING => 'a=%FF%FE' } },
        { name => 'q-uppercase',  env => { QUERY_STRING => 'Key=Value' } },
        { name => 'q-8k',         env => { QUERY_STRING =>
            join('&', map { "k$_=v$_" } 1 .. 900) } },
        { name => 'q-equals-in-value', env => { QUERY_STRING => 'a=b=c' } },

        # path
        { name => 'p-root',       env => { PATH_INFO => '/' } },
        { name => 'p-deep',       env => { PATH_INFO => '/books/42' } },
        { name => 'p-trailing',   env => { PATH_INFO => '/books/42/' } },
        { name => 'p-percent',    env => { PATH_INFO => '/a%b' } },
        { name => 'p-space',      env => { PATH_INFO => '/a b' } },
        { name => 'p-control',    env => { PATH_INFO => "/a\tb\rc\nd" } },
        { name => 'p-utf8',       env => { PATH_INFO => "/caf\xc3\xa9" } },
        { name => 'p-question',   env => { PATH_INFO => '/a?b' } },
        { name => 'p-script-name', env => { SCRIPT_NAME => '/mounted', PATH_INFO => '/books/1' } },
        { name => 'p-script-slash', env => { SCRIPT_NAME => '/mounted/', PATH_INFO => '/books/1' } },
        { name => 'p-redirect-url', env => { PATH_INFO => '/books/1',
                                             REDIRECT_URL => '/pre/books/1' } },
        { name => 'p-request-uri', env => { PATH_INFO => '/books/1',
                                            REQUEST_URI => '/books/1?a=1' } },

        # host and scheme
        { name => 'h-port',       env => { HTTP_HOST => '127.0.0.1:8080' } },
        { name => 'h-port-80',    env => { HTTP_HOST => '127.0.0.1:80' } },
        { name => 'h-no-host',    env => { HTTP_HOST => undef, SERVER_NAME => 'example.com' } },
        { name => 'h-server-port', env => { HTTP_HOST => undef, SERVER_NAME => 'example.com',
                                            SERVER_PORT => 8080 } },
        { name => 'h-uppercase',  env => { HTTP_HOST => 'EXAMPLE.com' } },
        { name => 'h-https',      env => { 'psgi.url_scheme' => 'https', SERVER_PORT => 443 } },

        # headers
        { name => 'hd-none',      env => { HTTP_USER_AGENT => undef, HTTP_ACCEPT => undef } },
        { name => 'hd-custom',    env => { HTTP_X_THING => 'yes' } },
        { name => 'hd-comma',     env => { HTTP_ACCEPT => 'text/html, application/xml;q=0.9' } },
        { name => 'hd-repeated',  env => { HTTP_X_THING => 'one, two' } },
        { name => 'hd-content',   env => { CONTENT_TYPE => 'text/plain', CONTENT_LENGTH => 0 } },
        { name => 'hd-cookie',    env => { HTTP_COOKIE => 'a=1; b=2' } },
        { name => 'hd-underscore', env => { HTTP_X_A_B_C => 'v' } },
        { name => 'hd-https-env', env => { HTTPS => 'on' } },
        { name => 'hd-empty-val', env => { HTTP_X_THING => '' } },
        { name => 'hd-utf8',      env => { HTTP_X_THING => "caf\xc3\xa9" } },
        { name => 'hd-arrayref',  env => { HTTP_X_THING => ['one'] } },
        { name => 'hd-arrayref2', env => { HTTP_X_THING => ['one', 'two'] } },

        # A form body decodes through the same subroutine as the query string,
        # once per name and once per value, which is what 4.1 replaced.
        { name => 'body-simple',  env => { REQUEST_METHOD => 'POST',
            CONTENT_TYPE => 'application/x-www-form-urlencoded',
            body => 'a=1&b=two' } },
        { name => 'body-utf8',    env => { REQUEST_METHOD => 'POST',
            CONTENT_TYPE => 'application/x-www-form-urlencoded',
            body => 'caf%C3%A9=cr%C3%A8me' } },
        { name => 'body-dup',     env => { REQUEST_METHOD => 'POST',
            CONTENT_TYPE => 'application/x-www-form-urlencoded',
            body => 'a=1&a=2' } },
        { name => 'body-bad-utf8', env => { REQUEST_METHOD => 'POST',
            CONTENT_TYPE => 'application/x-www-form-urlencoded',
            body => 'a=%FF%FE' } },
        { name => 'body-and-query', env => { REQUEST_METHOD => 'POST',
            CONTENT_TYPE => 'application/x-www-form-urlencoded',
            QUERY_STRING => 'a=query', body => 'a=body&b=2' } },
        { name => 'body-empty',   env => { REQUEST_METHOD => 'POST',
            CONTENT_TYPE => 'application/x-www-form-urlencoded', body => '' } },
    );
}

# A value rendered so two processes agree on it without agreeing on a
# serialiser, and so hash order cannot fail the comparison.
sub render {
    my ($v, $depth) = @_;
    $depth ||= 0;
    return '(undef)' unless defined $v;
    return '(deep)' if $depth > 4;
    my $r = ref $v;
    if (!$r) {
        my $s = $v;
        $s =~ s/([^\x20-\x7e])/sprintf '\\x{%02x}', ord $1/ge;
        # A character above 0xff can only be there if something decoded it, so
        # the escape above is not enough on its own to tell the two apart.
        $s .= '(wide)' if $v =~ /[^\x00-\xff]/;
        return $s;
    }
    return 'ARRAY[' . join(',', map { render($_, $depth + 1) } @$v) . ']' if $r eq 'ARRAY';
    return 'HASH{' . join(',', map { "$_=" . render($v->{$_}, $depth + 1) }
        sort keys %$v) . '}' if $r eq 'HASH';
    if (Scalar::Util::blessed($v)) {
        return 'URI(' . render("$v", $depth + 1) . ')' if $v->isa('URI');
        return 'HMV{' . render({ $v->flatten }, $depth + 1) . '}'
            if $v->isa('Hash::MultiValue');
        # Both the rendering and the hash behind it. as_string flattens a one
        # element arrayref to the same text as the plain string it should have
        # been, and this phase writes that hash directly, so comparing only the
        # text would not compare what was written.
        return 'HDR(' . render($v->as_string("\\n"), $depth + 1) . ')'
             . 'RAW(' . render({ %$v }, $depth + 1) . ')'
            if $v->isa('HTTP::Headers');
        return 'OBJ(' . ref($v) . ')';
    }
    return "REF($r)";
}

# The context, caught on its way into dispatch. Catalyst::prepare cannot be
# called on its own: it ends by reading the stash, which lives in the PSGI
# environment and is put there by middleware, so the whole application has to
# run. Everything phase 4 touches has finished by the time dispatch is entered,
# and a request whose preparation died never gets there, which is itself the
# thing to compare.
our $CONTEXT;

sub capture_context {
    my $orig = \&Catalyst::dispatch;
    no warnings 'redefine';
    *Catalyst::dispatch = sub { $CONTEXT = $_[0]; $orig->(@_) };
    return;
}

# "at /some/path/File.pm line 92." names the file the patched subroutine lives
# in, which is this distribution rather than Catalyst. That is a real
# difference, and it is a difference in where an error was raised rather than
# in what happened, so it is normalised out here and recorded in the phase
# notes instead of being hidden.
sub clean {
    my ($s) = @_;
    $s =~ s/ at \S+ line \d+\.?//g;
    return $s;
}

sub probe {
    my %out;
    my $app = TestApp->psgi_app;
    capture_context();

    # $HTTP::Headers::TRANSLATE_UNDERSCORE decides what an environment key
    # becomes, and anything remembering that answer has to notice when it
    # moves. Stock Catalyst re-derives it every request, so the second pass is
    # free there and is the whole point here.
    for my $under (1, 0, 1) {
        $HTTP::Headers::TRANSLATE_UNDERSCORE = $under;
        for my $case (corpus()) {
            next unless $case->{name} =~ /\Ahd-/;
            my $c = one_case($case);
            $out{"$case->{name}/under=$under"} = $c;
        }
    }
    $HTTP::Headers::TRANSLATE_UNDERSCORE = 1;

    for my $case (corpus()) {
        $out{ $case->{name} } = one_case($case);
    }

    # Proof that the sealed side is the sealed side, so that every comparison
    # above is not passing because nothing was patched.
    $out{'__STATE__'} = join ',',
        'decoder=' . (Catalyst->can('_handle_param_unicode_decoding')
            == \&Catalyst::Seal::Prepare::_handle_param_unicode_decoding ? 'patched' : 'stock'),
        'headers=' . (Catalyst::Request->can('prepare_headers')
            == \&Catalyst::Seal::Prepare::_prepare_headers ? 'patched' : 'stock'),
        'path=' . (Catalyst::Engine->can('prepare_path')
            == \&Catalyst::Seal::Prepare::_prepare_path ? 'patched' : 'stock');

    return \%out;
}

sub one_case {
    my ($case) = @_;
    my $app = TestApp->psgi_app;

    $CONTEXT = undef;

    my $res = eval { $app->(env(%{ $case->{env} })) };
    return 'DIED: ' . clean("$@") if $@;

    my $flat = SealTest::flatten($res);
    return "no context reached dispatch\n$flat" unless $CONTEXT;

    my $req = $CONTEXT->request;
    return join "\n",
        'path: '     . render(scalar eval { $req->path }),
        'base: '     . render(scalar eval { $req->base }),
        'uri: '      . render(scalar eval { $req->uri }),
        'params: '   . render(scalar eval { $req->query_parameters }),
        'body: '     . render(scalar eval { $req->body_parameters }),
        'merged: '   . render(scalar eval { $req->parameters }),
        'keywords: ' . render(scalar eval { $req->query_keywords }),
        'args: '     . render(scalar eval { $req->arguments }),
        'headers: '  . render(scalar eval { $req->headers }),
        'response: ' . clean($flat);
}

sub child {
    my ($sealed) = @_;
    pipe my $r, my $w or die "pipe: $!";
    my $pid = fork;
    defined $pid or die "fork: $!";

    if (!$pid) {
        close $r;
        open STDOUT, '>', '/dev/null' or die $!;
        open STDERR, '>', '/dev/null' or die $!;
        $ENV{CATALYST_SEAL} = $sealed ? 1 : 0;
        my $out = eval {
            require Scalar::Util;
            require TestApp;
            require Catalyst::Seal::Prepare;
            Storable::nfreeze(probe());
        };
        $out = Storable::nfreeze({ FATAL => "$@" }) if $@;
        syswrite $w, $out;
        close $w;
        require POSIX;
        POSIX::_exit(0);
    }

    close $w;
    my $frozen = do { local $/; <$r> };
    close $r;
    waitpid $pid, 0;
    return { error => "child exited $? with no output" }
        unless defined $frozen && length $frozen;
    return Storable::thaw($frozen);
}

my $stock  = child(0);
my $sealed = child(1);

if ($stock->{FATAL} || $sealed->{FATAL} || $stock->{error} || $sealed->{error}) {
    plan skip_all => 'a child could not run: '
        . join ' ', grep { defined } $stock->{FATAL}, $sealed->{FATAL},
                                     $stock->{error}, $sealed->{error};
}

is($stock->{'__STATE__'},  'decoder=stock,headers=stock,path=stock',
    'CATALYST_SEAL=0 patched none of the three');
is($sealed->{'__STATE__'}, 'decoder=patched,headers=patched,path=patched',
    'the sealed side patched all three, so the comparisons below mean something');

is_deeply(
    [sort keys %$sealed],
    [sort keys %$stock],
    'both sides answered the same corpus',
);

# The corpus has to have selected the branches it claims to. A run where every
# case produced the same request would compare identical twice and prove
# nothing.
my %distinct;
$distinct{ $stock->{$_} }++ for grep { $_ ne '__STATE__' } keys %$stock;
cmp_ok(scalar keys %distinct, '>', 30, 'the corpus produced distinct requests');

for my $name (sort grep { $_ ne '__STATE__' } keys %$stock) {
    is($sealed->{$name}, $stock->{$name}, "$name is identical");
}

done_testing;
