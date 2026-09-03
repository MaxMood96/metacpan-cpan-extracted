package Catalyst::Seal::Middleware;

use strict;
use warnings;

use Carp ();
use Plack::Util ();
use Plack::Middleware ();
use Scalar::Util ();

use Catalyst::Seal ();
use Catalyst::Seal::Guard ();

our $VERSION = '0.01';

# Plack::Middleware::ContentLength 1.0051.
sub _content_length_call {
    my $self = shift;
    my $res  = $self->app->(@_);

    return $self->response_cb($res, sub {
        my $r = shift;

        # Plack::Util::status_with_no_entity_body, inline.
        my $status = $r->[0];
        return if $status < 200 || $status == 204 || $status == 304;

        my $h = $r->[1];
        for (my $i = 0; $i < @$h; $i += 2) {
            my $k = lc $h->[$i];
            return if $k eq 'content-length' || $k eq 'transfer-encoding';
        }

        my $body = $r->[2];
        my $len;
        if (ref $body eq 'ARRAY') {
            $len = 0;
            $len += length $_ for @$body;
        }
        else {
            # A real filehandle, or nothing at all. Plack knows the rules for
            # both and they are not on the hot path.
            $len = Plack::Util::content_length($body);
        }

        push @$h, 'Content-Length' => $len if defined $len;
        return;
    });
}

# Plack::Middleware::HTTPExceptions 1.0051.
sub _http_exceptions_call {
    my ($self, $env) = @_;

    my $res;
    unless (eval { $res = $self->app->($env); 1 }) {
        # transform_error is called outside the eval on purpose: it rethrows
        # for an unrecognised code or when rethrow is set, and that die has to
        # propagate exactly as it did through Try::Tiny's catch.
        $res = $self->transform_error($@, $env);
    }

    return $res if ref $res eq 'ARRAY';

    my $delayed = $res;
    return sub {
        my $respond = shift;

        my $writer;
        unless (eval { $delayed->(sub { return $writer = $respond->(@_) }); 1 }) {
            my $err = $@;
            if ($writer) {
                Carp::cluck $err;
                $writer->close;
            }
            else {
                $respond->($self->transform_error($err, $env));
            }
        }
        return;
    };
}

sub _rrb_filter {
    my ($r) = @_;
    return unless @$r == 3;
    my $status = $r->[0];
    return if !($status < 200 || $status == 204 || $status == 304);
    $r->[2] = [];
    Plack::Util::header_remove($r->[1], 'Content-Length');
    return;
}

# Plack::Middleware::FixMissingBodyInRedirect 0.12.
sub _fix_filter {
    my ($r) = @_;
    return unless $r->[0] >= 300 && $r->[0] < 400;

    my $headers = Plack::Util::headers($r->[1]);
    return unless $headers->exists('Location');
    my $location = $headers->get('Location');

    my $class = 'Plack::Middleware::FixMissingBodyInRedirect';
    if (@$r == 3 && !$class->can('_is_body_set')->($r->[2])) {
        my $body = $class->_default_html_body($location);
        $r->[2] = [$body];
        $headers->set('Content-Length' => Plack::Util::content_length([$body]));
        $headers->set('Content-Type' => 'text/html; charset=utf-8');
        return;
    }
    elsif (@$r == 2 || Scalar::Util::blessed($r->[2])) {
        $headers->set('Content-Type' => 'text/html; charset=utf-8')
            unless $headers->exists('Content-Type');
        my $done;
        return sub {
            my $chunk = shift;
            return $chunk if $done;
            if (!defined $chunk) { $done = 1; return $class->_default_html_body($location) }
            elsif (length $chunk) { $done = 1 }
            return $chunk;
        };
    }
    return;
}

# Plack::Middleware::ContentLength 1.0051, the lean body from above.
sub _cl_filter {
    my ($r) = @_;
    my $status = $r->[0];
    return if $status < 200 || $status == 204 || $status == 304;

    my $h = $r->[1];
    for (my $i = 0; $i < @$h; $i += 2) {
        my $k = lc $h->[$i];
        return if $k eq 'content-length' || $k eq 'transfer-encoding';
    }

    my $body = $r->[2];
    my $len;
    if (ref $body eq 'ARRAY') { $len = 0; $len += length $_ for @$body }
    else                      { $len = Plack::Util::content_length($body) }

    push @$h, 'Content-Length' => $len if defined $len;
    return;
}

sub _apply_filter {
    my ($r, $filter) = @_;

    if (ref $r->[2] eq 'ARRAY') {
        for my $line (@{ $r->[2] }) { $line = $filter->($line) }
        my $eof = $filter->(undef);
        push @{ $r->[2] }, $eof if defined $eof;
    }
    else {
        my $body    = $r->[2];
        my $getline = sub { $body->getline };
        $r->[2] = Plack::Util::inline_object(
            getline => sub { $filter->($getline->()) },
            close   => sub { $body->close },
        );
    }
    return;
}

sub _fused_call {
    my $self = shift;
    my $res  = $self->app->(@_);

    return $self->response_cb($res, sub {
        my $r = shift;

        _rrb_filter($r);

        my $filter = _fix_filter($r);
        if (ref $filter eq 'CODE') {
            Plack::Util::header_remove($r->[1], 'Content-Length');
            if (defined $r->[2]) {
                _apply_filter($r, $filter);
                $filter = undef;
            }
        }

        _cl_filter($r);

        return $filter;
    });
}

{
    package Catalyst::Seal::Middleware::Response;
    our @ISA = ('Plack::Middleware');
    sub call { goto &Catalyst::Seal::Middleware::_fused_call }
}


sub _default_middleware {
    my $class = shift;

    my $stock = $Catalyst::Seal::Guard::ORIGINAL{'Catalyst::default_middleware'};
    my @mw = $stock ? $stock->($class, @_) : ();

    my @want = qw(
        Plack::Middleware::RemoveRedundantBody
        Plack::Middleware::FixMissingBodyInRedirect
        Plack::Middleware::ContentLength
    );

    for my $i (0 .. $#mw - 2) {
        next unless join('|', map { ref $mw[$i + $_] } 0 .. 2) eq join('|', @want);
        splice @mw, $i, 3, Catalyst::Seal::Middleware::Response->new;
        last;
    }

    return @mw;
}

sub _looks_like {
    my ($class, $method, @want) = @_;

    my $cv = $class->can($method) or return 0;
    my $text = eval {
        require B::Deparse;
        B::Deparse->new->coderef2text($cv);
    };
    return 0 unless defined $text;

    for my $want (@want) {
        return 0 unless index($text, $want) >= 0;
    }
    return 1;
}

my %PATCH = (
    'Plack::Middleware::ContentLength' => {
        code  => \&_content_length_call,
        want  => ['response_cb', 'content_length', 'Content-Length'],
    },
    'Plack::Middleware::HTTPExceptions' => {
        code  => \&_http_exceptions_call,
        want  => ['transform_error', '&try(', '&catch(', 'respond'],
    },
);

my $PATCHED = 0;

Catalyst::Seal::register_step('middleware' => sub {
    return if $PATCHED++;

    my $done = 0;
    for my $class (sort keys %PATCH) {
        my $p = $PATCH{$class};

        unless (eval { Plack::Util::load_class($class); 1 }) {
            Catalyst::Seal::note("$class is not installed, not patched");
            next;
        }
        unless (_looks_like($class, 'call', @{ $p->{want} })) {
            Catalyst::Seal::note("$class\::call is not the shape we replace, left alone");
            next;
        }

        $done += Catalyst::Seal::Guard::replace("${class}::call" => $p->{code});
    }

    my $fused = 0;
    if (_looks_like('Catalyst', 'default_middleware',
                    'RemoveRedundantBody', 'FixMissingBodyInRedirect',
                    'ContentLength', 'HTTPExceptions')) {
        $fused = Catalyst::Seal::Guard::replace(
            'Catalyst::default_middleware' => \&_default_middleware);
    }
    else {
        Catalyst::Seal::note(
            'Catalyst::default_middleware is not the shape we replace, left alone');
    }

    Catalyst::Seal::note("middleware: patched $done of " . scalar(keys %PATCH)
        . ", fused=$fused") if $Catalyst::Seal::DEBUG;
    return;
});

1;

__END__

=head1 NAME

Catalyst::Seal::Middleware - leaner bodies for the two costly default middlewares

=head1 DESCRIPTION

C<Catalyst::default_middleware> puts seven wrappers around every application.
Measured by leave-one-out, each rebuilt with its own instances because
C<Plack::Middleware::wrap> mutates the instance it is called on:

    ContentLength              9.51 us/req
    HTTPExceptions             7.44
    FixMissingBodyInRedirect   3.32
    RemoveRedundantBody        1.67
    MethodOverride             1.27
    Head                       0.53

23.74 us together, a fifth of the request. Two of them are worth rewriting and
the rest are close to the floor cost of a C<response_cb> layer, which is what
you pay for having a middleware at all.

Both replacements go in as the C<call> method of the stock class, so the stack
is still built by Catalyst in the stock order with the stock instances. Nothing
here fuses or reorders anything: the order those response callbacks run in is
load bearing, and C<Plack::Util::response_cb> strips C<Content-Length> once per
nesting level.

=head2 ContentLength

The stock filter builds a C<Plack::Util::headers> object, which is a blessed
closure set, to ask two questions about the header list and sometimes push one
entry. One pass over the arrayref answers the same questions.

=head2 HTTPExceptions

Two C<Try::Tiny> blocks per request, one around the application call and one
around the streaming responder, each building two closures. Plain C<eval> does
the same job. This is the same change phase 0 made to Catalyst's own two
C<try> blocks, in the one place outside Catalyst that is on the request path.

=cut

=head1 AUTHOR

LNATION <email@lnation.org>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by LNATION <email@lnation.org>.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut

