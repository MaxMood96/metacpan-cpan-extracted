package Catalyst::Seal::Finalize;

use strict;
use warnings;

use Scalar::Util ();

use Catalyst::Seal ();
use Catalyst::Seal::Guard ();

our $VERSION = '0.01';


my %DECISION;

our $MAX_KEYS = 512;
my $CAPPED = 0;

sub _clear { %DECISION = (); $CAPPED = 0; return }
sub capped { $CAPPED }
sub memo_size { scalar keys %DECISION }

sub _decide {
    my ($res, $cenc, $ectype, $mime) = @_;

    my $ct      = $res->content_type;
    my $charset = $res->content_type_charset;

    my $has_manual_charset = 0;
    if (defined $charset && length $charset) {
        $has_manual_charset =
            (defined $mime && uc($charset) ne uc($mime)) ? 1 : 0;
    }

    my $encodable = 0;
    if (defined $mime) {
        my $type_ok = (defined $ct && $ct =~ m/$ectype/) ? 1 : 0;
        my $enc_ok  = (!defined $cenc || !length $cenc || $cenc eq 'identity') ? 1 : 0;
        $encodable = ($type_ok && !$has_manual_charset && $enc_ok) ? 1 : 0;
    }

    return { encodable => $encodable, charset => $charset, ct => $ct };
}

# Catalyst.pm:2324 as of 5.90132.
sub _finalize_encoding {
    my $c = shift;
    my $res = $c->res || return;

    my $ctx = $res->_context;
    return _stock_finalize_encoding($c) if !$ctx || $ctx != $c;

    my $enc    = $c->encoding;
    my $mime   = $enc ? $enc->mime_name : undef;
    my $cenc   = $res->content_encoding;
    my $ectype = $res->encodable_content_type;

    my $raw = $res->headers->header('Content-Type');

    my $key = join "\0",
        (defined $raw    ? $raw    : ''),
        (defined $cenc   ? $cenc   : ''),
        (defined $ectype ? "$ectype" : ''),
        (defined $mime   ? $mime   : '');

    my $d = $DECISION{$key};
    unless ($d) {
        $d = _decide($res, $cenc, $ectype, $mime);
        if (keys %DECISION < $MAX_KEYS) {
            $DECISION{$key} = $d;
        }
        elsif (!$CAPPED++) {
            Catalyst::Seal::note(
                "encoding decision memo reached $MAX_KEYS keys, no longer caching");
        }
    }

    if ($d->{charset} && defined $mime && uc($mime) ne uc($d->{charset})) {
        my $lc = lc $d->{charset};
        $c->log->debug("Catalyst encoding config is set to encode in '" .
            $mime . "', content type is '$lc', not encoding ");
    }

    if ($d->{encodable} && defined($res->body) && ref(\$res->body) eq 'SCALAR') {
        $res->body( $enc->encode( $res->body, $c->_encode_check ) );

        $res->content_type($d->{ct} . "; charset=" . $mime)
          unless ($d->{charset} ||
                  ($ctx && $res->finalized_headers && !$res->_has_response_cb));
    }

    return;
}

sub _stock_finalize_encoding {
    my ($c) = @_;
    my $orig = $Catalyst::Seal::Guard::ORIGINAL{'Catalyst::finalize_encoding'}
        or return;
    return $orig->($c);
}

sub _response_destroy {
    my $self = shift;
    return $self->Moose::Object::DESTROY(@_)
        if Scalar::Util::blessed($self) ne 'Catalyst::Response';

    local $?;
    my $igd = Devel::GlobalDestruction::in_global_destruction();
    my $ok = eval { $self->Catalyst::Response::DEMOLISH($igd); 1 };
    die $@ unless $ok;
    return;
}

sub _destroy_is_stock {
    my $cv = Catalyst::Response->can('DESTROY') or return 0;
    return 0 unless Catalyst::Response->can('DEMOLISH');

    my $text = eval {
        require B::Deparse;
        B::Deparse->new->coderef2text($cv);
    };
    return 0 unless defined $text;

    for my $want (qw(
        Moose::Object::DESTROY
        in_global_destruction
        Try::Tiny::try
        DEMOLISH
    )) {
        return 0 unless index($text, $want) >= 0;
    }
    return 0 if index($text, 'DEMOLISHALL') >= 0;
    return 1;
}

my $PATCHED = 0;

Catalyst::Seal::register_step('finalize' => sub {
    my ($app) = @_;

    return if $PATCHED++;

    my $enc = Catalyst::Seal::Guard::replace(
        'Catalyst::finalize_encoding' => \&_finalize_encoding);

    my $destroy = 0;
    if (_destroy_is_stock()) {
        no warnings 'redefine';
        $Catalyst::Seal::Guard::ORIGINAL{'Catalyst::Response::DESTROY'}
            ||= Catalyst::Response->can('DESTROY');
        *Catalyst::Response::DESTROY = \&_response_destroy;
        $destroy = 1;
    }
    else {
        Catalyst::Seal::note(
            'Catalyst::Response::DESTROY is not the shape we replace, left alone');
    }

    Catalyst::Seal::note("finalize: encoding=$enc destroy=$destroy")
        if $Catalyst::Seal::DEBUG;
    return;
});

1;

__END__

=head1 NAME

Catalyst::Seal::Finalize - the encoding decision, decided once per content type

=head1 DESCRIPTION

=head2 The encoding decision

C<Catalyst::finalize_encoding> costs 49 us per request to decide that a
C<text/plain> body does not need encoding. It reaches that answer by calling
C<content_type> four times and C<content_type_charset> three times, each of
which re-parses the same header string, plus C<encodable_response>, which calls
both again.

Every input is a string:

    $res->content_type
    $res->content_encoding
    $res->encodable_content_type      the regex the type is matched against
    $c->encoding && $c->encoding->mime_name

so the answer is a pure function of those four, and an application emits a
handful of distinct content types in its life.

The memo is keyed on the encoding's mime name rather than on the encoding
object, because C<$c-E<gt>encoding($enc)> is a documented per-request call and
C<$c-E<gt>clear_encoding> sets it to undef. Keying on the name cannot go stale.

=head2 Response::DESTROY

Not in the plan for this phase, and found by profiling it. Moose's inlined
destructor for L<Catalyst::Response> builds two closures and enters
C<Try::Tiny::try> on every response destroyed, to call a four line C<DEMOLISH>
that usually returns immediately. 17 us per request, of which the DEMOLISH is
1.3.

The other classes in the tree with an inlined destructor, C<Catalyst::Request>,
the context class, C<Catalyst::Log> and C<Catalyst::Stats>, have no C<DEMOLISH>
at all, so theirs are already no-ops costing 0.2 us and are left alone.

=cut

=head1 AUTHOR

LNATION <email@lnation.org>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by LNATION <email@lnation.org>.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut

