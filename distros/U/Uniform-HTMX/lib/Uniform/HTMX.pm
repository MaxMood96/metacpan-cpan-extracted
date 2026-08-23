package Uniform::HTMX;

use strict;
use warnings;
use Uniform::Utils qw(normalize_http_headers);
use Carp qw(croak);
BEGIN {
    if (eval { require JSON::MaybeXS; 1 }) {
        JSON::MaybeXS->import('encode_json', 'decode_json');
    } else {
        require JSON::PP;
        JSON::PP->import('encode_json', 'decode_json');
    }
}

our $VERSION = '0.15';

# Internal normalization utility available to all independent subclasses
sub _normalize_headers {
    my ($self, $hash) = @_;
    # Delegate cleanly to your core ecosystem utility!
    return normalize_http_headers($hash);
}

sub _request_header {
    my ($self, $name) = @_;
    return unless ref($self->{in}) eq 'HASH';
    return $self->{in}->{lc $name};
}

sub _true_header {
    my ($self, $name) = @_;
    my $value = $self->_request_header($name);
    return 0 unless defined $value;
    $value =~ s/^\s+|\s+$//g;
    return lc($value) eq 'true' ? 1 : 0;
}

sub _response_header {
    my ($self, $name, $value) = @_;
    croak "$name value must be defined" unless defined $value;
    croak "$name value must be a plain scalar" if ref $value;
    croak "$name value must not contain a newline" if $value =~ /[\r\n]/;
    $self->{out} = {} unless ref($self->{out}) eq 'HASH';
    $self->{out}->{$name} = "$value";
    return $self;
}

sub _event_header {
    my ($self, $header, $event, $params) = @_;
    croak "Event name must be defined" unless defined $event;
    croak "Event name must be a plain scalar" if ref $event;
    croak "Event name must not be empty" unless length $event;
    croak "Event name must not contain a newline" if $event =~ /[\r\n]/;

    my $value = defined($params) ? encode_json({ $event => $params }) : $event;
    return $self->_response_header($header, $value);
}

# =========================================================================
# REQUEST INSPECTION METHODS
# =========================================================================

sub is_htmx {
    my ($self) = @_;
    return $self->_true_header('hx-request');
}

sub is_boosted {
    my ($self) = @_;
    return $self->_true_header('hx-boosted');
}

sub is_history_restore {
    my ($self) = @_;
    return $self->_true_header('hx-history-restore-request');
}

sub current_url {
    my ($self) = @_;
    return $self->_request_header('hx-current-url');
}

sub prompt {
    my ($self) = @_;
    return $self->_request_header('hx-prompt');
}

sub target {
    my ($self) = @_;
    return $self->_request_header('hx-target');
}

sub trigger_id {
    my ($self) = @_;
    return $self->_request_header('hx-trigger');
}

sub trigger_name {
    my ($self) = @_;
    return $self->_request_header('hx-trigger-name');
}

sub trigger_event {
    my ($self) = @_;
    my $val = $self->_request_header('hx-trigger');
    return unless defined $val;

    # If it looks like a JSON string sent from an htmx event trigger, decode it safely
    if ($val =~ /^\s*[\{\[]/) {
        return eval { decode_json($val) };
    }
    return $val;
}

# =========================================================================
# RESPONSE MANIPULATION METHODS
# =========================================================================

sub res_retarget {
    my ($self, $selector) = @_;
    return $self->_response_header('HX-Retarget', $selector);
}

sub res_reswap {
    my ($self, $strategy) = @_;
    return $self->_response_header('HX-Reswap', $strategy);
}

sub res_reselect {
    my ($self, $selector) = @_;
    return $self->_response_header('HX-Reselect', $selector);
}

sub res_location {
    my ($self, $location) = @_;
    if (ref($location) eq 'HASH') {
        return $self->_response_header('HX-Location', encode_json($location));
    }
    return $self->_response_header('HX-Location', $location);
}

sub res_push_url {
    my ($self, $url) = @_;
    return $self->_response_header('HX-Push-Url', $url);
}

sub res_replace_url {
    my ($self, $url) = @_;
    return $self->_response_header('HX-Replace-Url', $url);
}

sub res_redirect {
    my ($self, $url) = @_;
    return $self->_response_header('HX-Redirect', $url);
}

sub res_refresh {
    my ($self, $refresh) = @_;
    $refresh = 1 unless @_ > 1;
    return $self->_response_header('HX-Refresh', $refresh ? 'true' : 'false');
}

sub res_trigger_name {
    my ($self, $name) = @_;
    return $self->_response_header('HX-Trigger-Name', $name);
}

sub res_trigger {
    my ($self, $event, $params) = @_;
    return $self->_event_header('HX-Trigger', $event, $params);
}

sub res_trigger_after_settle {
    my ($self, $event, $params) = @_;
    return $self->_event_header('HX-Trigger-After-Settle', $event, $params);
}

sub res_trigger_after_swap {
    my ($self, $event, $params) = @_;
    return $self->_event_header('HX-Trigger-After-Swap', $event, $params);
}



1;

__END__

=pod

=encoding utf-8

=head1 NAME

Uniform::HTMX - Extensible, framework-agnostic base layer for htmx communication

=head1 SYNOPSIS

This is an abstract base module. It should not be used directly. Instead, implement
or install a framework-specific driver subclass:

    # Inside a subclass (e.g. Uniform::HTMX::PAGI)
    package Uniform::HTMX::PAGI;
    use parent 'Uniform::HTMX';

    sub new {
        my ($class, $scope) = @_;
        my %raw_headers = ...; # Framework specific extraction

        my $self = bless { in => {}, out => {}, _ctx => $scope }, $class;
        $self->{in} = $self->_normalize_headers(\%raw_headers);
        return $self;
    }

    sub apply {
        my ($self) = @_;
        # Framework specific response injection using $self->{out}
    }

=head1 DESCRIPTION

C<Uniform::HTMX> provides a strict, unified interface for interacting with the
L<htmx client-side library|https://htmx.org>. By decoupling the htmx spec protocol
from core web frameworks, it prevents backend platform locking and standardizes
frontend interactions.

=head1 METHODS

=head2 Request Inspection

=over 4

=item is_htmx()

Returns C<1> if the incoming request was triggered by htmx (checks C<HX-Request> header),
otherwise returns C<0>.

=item is_boosted()

Returns C<1> when C<HX-Boosted> is true.

=item is_history_restore()

Returns C<1> when C<HX-History-Restore-Request> is true.

=item current_url()

Returns the browser URL supplied in C<HX-Current-URL>, or C<undef>.

=item prompt()

Returns the response to C<hx-prompt>, including an intentionally empty string, or
C<undef> when C<HX-Prompt> was not sent.

=item target()

Returns the string ID or CSS selector of the target element sent by the browser via the
C<HX-Target> header, if present.

=item trigger_id()

Returns the ID of the specific frontend DOM element that triggered the request via the
C<HX-Trigger> request header.

=item trigger_name()

Returns the name of the triggering element from C<HX-Trigger-Name>, or C<undef>.

=item trigger_event()

Inspects the incoming C<HX-Trigger> request header and evaluates its contents.

Under the htmx specification, if a request is launched due to a client-side JavaScript
event, the browser may send a JSON string containing the event name and its parameters
instead of a simple element ID string.

This method checks the structural layout of the payload. If it detects a JSON string,
it automatically decodes it and returns a native Perl data structure (hash reference
or array reference). If it is a normal text string, it returns the raw scalar ID unchanged.

Returns C<undef> if the header was not sent.

=back

=head2 Response Manipulation

All modification methods return C<$self> to support fluent method chaining.

=over 4

=item res_retarget( $css_selector )

Overrides the client-side element target target for the incoming HTML swap. Maps to
the outbound C<HX-Retarget> HTTP header.

=item res_reswap( $strategy )

Overrides the layout swap strategy (e.g., C<'outerHTML'>, C<'innerHTML'>, C<'none'>).
Maps to the outbound C<HX-Reswap> HTTP header.

=item res_reselect( $css_selector )

Selects the portion of the response to swap via C<HX-Reselect>.

=item res_location( $url_or_hashref )

Performs an htmx client-side navigation without a full reload. A scalar sets a URL;
a hash reference is JSON encoded for the extended C<HX-Location> form.

=item res_push_url( $url_or_false )

Sets C<HX-Push-Url>. Pass a URL, or the literal string C<false> to prevent a history
entry.

=item res_replace_url( $url_or_false )

Sets C<HX-Replace-Url>. Pass a URL, or the literal string C<false> to prevent URL
replacement.

=item res_redirect( $url )

Requests a full client-side redirect using C<HX-Redirect>.

=item res_refresh( [$boolean] )

Sets C<HX-Refresh> to C<true> by default. Passing a false Perl value sets it to
C<false>.

=item res_trigger_name( $element_name )

Sets the C<HX-Trigger-Name> outbound response header to specify the name of the
target element to trigger client-side, if overriding standard target patterns.

=item res_trigger( $event_name [, $params_hashref_or_arrayref ] )

Instructs htmx to launch a custom client-side JavaScript event upon receiving the
response fragment. If params are provided, they will be automatically serialized to
valid JSON format as required by the htmx specification. Maps to the outbound C<HX-Trigger>
HTTP header.

=item res_trigger_after_settle( $event_name [, $params ] )

Like C<res_trigger>, but emits C<HX-Trigger-After-Settle>.

=item res_trigger_after_swap( $event_name [, $params ] )

Like C<res_trigger>, but emits C<HX-Trigger-After-Swap>.

=back

=head1 EXTENDING UNIFORM::HTMX

To author a brand-new framework bridge distribution, construct your module namespace under
the C<Uniform::HTMX::*> hierarchy and declare C<Uniform::HTMX> as your parent.

Subclasses gain access to C<_normalize_headers( \%hash )>, which accepts normal HTTP
names and common CGI/PSGI environment spellings such as C<HX-Target>,
C<hx_target>, and C<HTTP_HX_TARGET>. Names are matched case-insensitively. Malformed
names and reference-valued fields are ignored; for array-valued duplicate fields,
the last defined scalar is used. If both direct and environment forms are present,
the direct HTTP spelling takes precedence.

Outbound values reject references and CR/LF characters to avoid accidental invalid
headers and response-splitting vulnerabilities. JSON-capable methods serialize their
structured values with C<JSON::MaybeXS>, falling back to the core C<JSON::PP>
module when C<JSON::MaybeXS> is unavailable.

=head1 SEE ALSO

L<Uniform>

L<Uniform::HTMX::PSGI>

L<Uniform::HTMX::Mojolicious>

=head1 AUTHOR

Joshua S. Day E<lt>HAX@cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by Joshua S. Day.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut
