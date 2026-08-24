package Uniform::HTMX::Dancer2;

use strict;
use warnings;
use Dancer2::Plugin;
use Dancer2::Core::Hook;
use Uniform::HTMX;

our $VERSION = '1.00';

# One driver, shared by every request. driver() hands back a coderef that
# builds a fresh Uniform::HTMX (sub)instance per call - see "extending
# Uniform::HTMX" in the Uniform::HTMX docs.
my $htmx_driver = Uniform::HTMX->driver(
    extract => sub {
        my ($app) = @_;
        my $headers = $app->request->headers;
        return map { $_ => scalar $headers->header($_) }
            $headers->header_field_names;
    },
    apply => sub {
        my ( $self, $app, $out_headers ) = @_;
        for my $name ( keys %$out_headers ) {
            $app->response->header( $name => $out_headers->{$name} );
        }
    },
);

# Flush whatever headers were accumulated on the request's Uniform::HTMX
# instance (if one was ever created) into the real response, right before
# Dancer2 sends it.
on_plugin_import {
    my $dsl = shift;
    $dsl->app->add_hook(
        Dancer2::Core::Hook->new(
            name => 'after',
            code => sub {
                my $app      = $dsl->app;
                my $instance = $app->request->var('_uniform_htmx');
                $instance->apply($app) if $instance;
            },
        )
    );
};

register htmx => sub {
    my $dsl = shift;
    my $app = $dsl->app;

    # Cache one instance per request so repeated calls to `htmx` within the
    # same route accumulate onto the same outbound headers.
    my $instance = $app->request->var('_uniform_htmx');
    unless ($instance) {
        $instance = $htmx_driver->($app);
        $app->request->var( _uniform_htmx => $instance );
    }

    return $instance;
};

register is_htmx => sub {
    my $dsl = shift;
    return $dsl->htmx->is_htmx ? 1 : 0;
};

register_plugin;

1;

__END__

=head1 NAME

Uniform::HTMX::Dancer2 - HTMX integration for Dancer2 applications

=head1 VERSION

Version 1.00

=head1 SYNOPSIS

    use Dancer2;
    use Uniform::HTMX::Dancer2;

    get '/items' => sub {
        if (is_htmx) {
            htmx->res_retarget('#item-list');
            htmx->res_trigger('itemsLoaded', { count => 10 });
            return template 'partials/items' => {}, { layout => undef };
        }

        return template 'full_page';
    };

=head1 DESCRIPTION

C<Uniform::HTMX::Dancer2> integrates the L<Uniform::HTMX> engine into Dancer2 applications. It exposes lightweight DSL keywords to inspect incoming HTMX headers and modify outgoing response headers seamlessly within route handlers.

Internally this plugin builds a per-request L<Uniform::HTMX> instance with C<< Uniform::HTMX->driver >>, extracting inbound headers from the Dancer2 request and, via an C<after> hook, writing any accumulated outbound headers back onto the Dancer2 response automatically - you never need to call C<apply> yourself.

=head1 DSL KEYWORDS

=head2 htmx

    my $htmx_obj = htmx;

Returns the L<Uniform::HTMX> instance bound to the current request/response. The same instance is returned on every call within a single request, so accumulated response headers are shared. All core C<Uniform::HTMX> methods can be invoked directly:

    htmx->target;                                 # Read HX-Target header
    htmx->prompt;                                 # Read HX-Prompt header
    htmx->res_trigger('saved', { id => 42 });     # Set HX-Trigger header with JSON
    htmx->res_retarget('#main-content');          # Set HX-Retarget header

=head2 is_htmx

    if (is_htmx) { ... }

Convenience helper that returns boolean C<1> if the current request was initiated by HTMX (i.e., C<HX-Request> is present and C<true>), or C<0> otherwise.

=head1 SEE ALSO

=over 4

=item * L<Uniform::HTMX>

=item * L<Dancer2::Plugin>

=item * L<https://htmx.org/reference/>

=item * L<Bug tracker|https://github.com/haxmeister/perl-Uniform-HTMX-Dancer2/issues>

=item * L<Source repository|https://github.com/haxmeister/perl-Uniform-HTMX-Dancer2>

=back

=head1 AUTHOR

Joshua S. Day C<< <HAX@cpan.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2026 Joshua S. Day.

This program is free software; you can redistribute it and/or modify it
under the terms of the MIT License.

=cut
