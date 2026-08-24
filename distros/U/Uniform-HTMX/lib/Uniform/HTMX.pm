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

our $VERSION = '0.16';

# =========================================================================
# CONSTRUCTOR (optional — subclasses may use, extend via SUPER::new, or
# ignore entirely and bless their own hashref; see EXTENDING UNIFORM::HTMX)
# =========================================================================

sub new {
    my ($class, %args) = @_;
    my $self = bless { %args, in => {}, out => {} }, $class;
    $self->{in} = $self->_normalize_headers(delete($args{in}) || {});
    return $self;
}

# =========================================================================
# DRIVER SHORTCUT — build a framework integration without writing a
# subclass at all. See EXTENDING UNIFORM::HTMX for the full walkthrough.
# =========================================================================

my $ANON_SEQ = 0;

sub driver {
    my ($class, %spec) = @_;

    for my $required (qw(extract apply)) {
        croak "Uniform::HTMX->driver() requires a '$required' coderef"
            unless ref($spec{$required}) eq 'CODE';
    }

    # Generate a private, anonymous subclass so the two closures have a
    # real home as ->new / ->apply, and so nothing here pollutes the
    # Uniform::HTMX namespace itself or collides with a real driver
    # distribution the caller may also have loaded.
    my $anon_class = sprintf('Uniform::HTMX::_Anon%04d', ++$ANON_SEQ);

    {
        no strict 'refs';
        push @{"${anon_class}::ISA"}, $class;

        my $base_new = $class->can('new');

        *{"${anon_class}::new"} = sub {
            my ($inner_class, $scope) = @_;
            my %raw_headers = $spec{extract}->($scope);
            # Resolved via can() rather than SUPER:: — a closure installed
            # via typeglob is compiled in Uniform::HTMX's package, so
            # SUPER:: would incorrectly resolve against *its* @ISA rather
            # than $anon_class's.
            return $base_new->($inner_class, in => \%raw_headers, _scope => $scope);
        };

        *{"${anon_class}::apply"} = sub {
            my ($self, @rest) = @_;
            return $spec{apply}->($self, $self->{_scope}, $self->_out, @rest);
        };
    }

    # Return a plain constructor closure — the author never needs to know
    # $anon_class exists, or that this is a subclass at all.
    return sub {
        my ($scope) = @_;
        return $anon_class->new($scope);
    };
}

# =========================================================================
# OVERRIDABLE HOOKS
#
# These exist so a driver subclass can customize storage/serialization
# behavior WITHOUT needing to reimplement any request/response method
# above. Everything in this file reads/writes state exclusively through
# these hooks rather than touching $self->{in}/{out} or JSON functions
# directly, so overriding a hook here changes behavior everywhere.
# =========================================================================

# Storage for normalized inbound headers. Override if headers should be
# read lazily (e.g. pulled from a framework context object on demand)
# instead of eagerly normalized in new().
sub _in  { $_[0]->{in}  ||= {} }

# Storage for outbound headers to be applied by the driver's apply().
sub _out { $_[0]->{out} ||= {} }

# JSON encode/decode hooks. Override to swap serializer, force canonical
# key order, pretty-print for debugging, etc.
sub _encode_json { my ($self, $data) = @_; return encode_json($data) }
sub _decode_json { my ($self, $json) = @_; return decode_json($json) }

# Internal normalization utility available to all independent subclasses
sub _normalize_headers {
    my ($self, $hash) = @_;
    # Delegate cleanly to your core ecosystem utility!
    return normalize_http_headers($hash);
}

sub _request_header {
    my ($self, $name) = @_;
    my $in = $self->_in;
    return unless ref($in) eq 'HASH';
    return $in->{lc $name};
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
    $self->_out->{$name} = "$value";
    return $self;
}

sub _event_header {
    my ($self, $header, $event, $params) = @_;
    croak "Event name must be defined" unless defined $event;
    croak "Event name must be a plain scalar" if ref $event;
    croak "Event name must not be empty" unless length $event;
    croak "Event name must not contain a newline" if $event =~ /[\r\n]/;

    my $value = defined($params) ? $self->_encode_json({ $event => $params }) : $event;
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
        return eval { $self->_decode_json($val) };
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
        return $self->_response_header('HX-Location', $self->_encode_json($location));
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

This is an abstract base module. It is not used directly for a request — instead,
build a small integration for your framework with C<driver()>:

    my $htmx_driver = Uniform::HTMX->driver(
        extract => sub {
            my ($scope) = @_;          # whatever your framework hands you
            return %{ $scope->{headers} };   # raw header name/value pairs
        },
        apply => sub {
            my ($self, $scope, $out_headers) = @_;
            $scope->{res}->header($_ => $out_headers->{$_})
                for keys %$out_headers;
        },
    );

    # Per request:
    my $htmx = $htmx_driver->($scope);
    $htmx->is_htmx;
    $htmx->res_trigger('saved');
    $htmx->apply;

C<driver()> takes two plain subs — C<extract> turns your framework's request into a
flat header hash, C<apply> takes the accumulated outbound headers and writes them
back however your framework expects. No package declaration, C<use parent>, or
constructor is required; every request/response method documented below works
immediately once C<extract> and C<apply> are in place.

If you're publishing a reusable, distributable integration (e.g. C<Uniform::HTMX::PSGI>),
subclassing directly is the better fit and gives you a normal, discoverable CPAN
namespace:

    # Inside a subclass (e.g. Uniform::HTMX::PAGI)
    package Uniform::HTMX::PAGI;
    use parent 'Uniform::HTMX';

    sub new {
        my ($class, $scope) = @_;
        my %raw_headers = ...; # Framework specific extraction

        # SUPER::new() normalizes %raw_headers for you and stores
        # everything else you pass it (here, the framework's scope object).
        my $self = $class->SUPER::new(in => \%raw_headers, _ctx => $scope);
        return $self;
    }

    sub apply {
        my ($self) = @_;
        # Framework specific response injection using $self->_out
    }

In fact, C<driver()> is implemented in terms of exactly this pattern — it generates
an anonymous subclass on your behalf and wires your two subs in as C<new> and
C<apply>, so the two approaches are fully interchangeable and can even be mixed:
call C<< YourExistingSubclass->driver(...) >> to get the closure shortcut while
still inheriting any hooks C<YourExistingSubclass> overrides.

=head1 DESCRIPTION

C<Uniform::HTMX> provides a strict, unified interface for interacting with the
L<htmx client-side library|https://htmx.org>. By decoupling the htmx spec protocol
from core web frameworks, it prevents backend platform locking and standardizes
frontend interactions.

=head1 METHODS

=head2 driver( extract => \&extract, apply => \&apply )

Class method. Returns a coderef that builds a ready-to-use C<Uniform::HTMX> object
per request, without requiring a named subclass. See L</SYNOPSIS> for a full example.

C<extract> is called as C<< extract->($scope) >>, where C<$scope> is whatever value
you pass to the returned coderef (a PSGI C<$env>, a Mojolicious controller, etc.). It
must return a flat list of header name/value pairs, which is normalized the same way
C<_normalize_headers> normalizes any other input.

C<apply> is called as C<< apply->($self, $scope, $out_headers, @extra) >>, where
C<$out_headers> is the hashref accumulated by C<res_*> method calls (i.e. what
C<_out> returns) and C<@extra> is whatever extra arguments you pass to
C<< $self->apply(...) >> at call time — useful for passing a status code and body,
as in the PSGI example above.

Calling C<driver()> on a subclass (rather than C<Uniform::HTMX> itself) inherits
that subclass's hook overrides (C<_encode_json>, C<_in>, etc.), so the two extension
mechanisms compose rather than compete.

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

Every request-inspection and response-manipulation method above is implemented in
terms of a small set of hooks. Override a hook and every public method that depends
on it changes behavior automatically — you should never need to reimplement
C<is_htmx>, C<res_trigger>, etc. yourself.

=head2 Step 1: Extract your framework's headers

Your driver's only required job is turning framework-specific request data into a
plain hash of header-name/value pairs, and handing it to the constructor.

=head2 Step 2: Call C<SUPER::new>

    sub new {
        my ($class, $scope) = @_;
        my %raw_headers = ...;  # your framework-specific extraction
        return $class->SUPER::new(in => \%raw_headers, _ctx => $scope);
    }

C<SUPER::new(%args)> blesses the object, runs C<%args>'s C<in> value through
C<_normalize_headers>, and stores every other key you pass verbatim (so you can
stash a framework context, request object, etc. right on C<$self>). Using
C<SUPER::new> is optional — if your driver needs a completely different
construction shape, just bless your own hashref with C<in> and C<out> keys instead.

=head2 Step 3: Implement C<apply()>

C<Uniform::HTMX> never writes to the network itself. Your driver's C<apply()> method
(called whatever makes sense for your framework) should read the accumulated
outbound headers via C<< $self->_out >> and inject them using your framework's
response API.

=head2 Hooks you may override

=over 4

=item C<_in()> / C<_out()>

Return the hashrefs backing inbound and outbound headers, respectively. Override
C<_in> if headers should be read lazily from a framework object instead of being
normalized eagerly in C<new>. Both default to auto-vivifying hashrefs on C<$self>.

=item C<_encode_json( $data )> / C<_decode_json( $json )>

Called wherever this module serializes or parses JSON (C<res_trigger>,
C<res_location>, C<trigger_event>, etc.). Override to swap the JSON backend, force
canonical key ordering, or pretty-print for debugging.

=item C<_normalize_headers( \%hash )>

Accepts normal HTTP header names and common CGI/PSGI environment spellings such as
C<HX-Target>, C<hx_target>, and C<HTTP_HX_TARGET>. Names are matched
case-insensitively. Malformed names and reference-valued fields are ignored; for
array-valued duplicate fields, the last defined scalar is used. If both direct and
environment forms are present, the direct HTTP spelling takes precedence. Override
only if your framework needs a fundamentally different normalization scheme.

=back

=head2 Methods you should leave alone

C<_request_header>, C<_true_header>, C<_response_header>, and C<_event_header> are
internal plumbing shared by every public method. C<_response_header> in particular
enforces the validation that rejects references and CR/LF characters, preventing
invalid headers and response-splitting vulnerabilities — bypassing it to write
directly to C<_out> reintroduces that risk. Compose new response methods by calling
C<_response_header> or C<_event_header>, not by writing to C<_out> directly.

=head1 SEE ALSO

L<Uniform>

L<Uniform::HTMX::PSGI>

L<Uniform::HTMX::Mojolicious>

=head1 AUTHOR

Joshua S. Day E<lt>HAX@cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by Joshua S. Day.

This is free software, licensed under:

  The MIT (X11) License

=cut
