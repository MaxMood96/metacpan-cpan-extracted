package Uniform::HTMX::Mojolicious;

use strict;
use warnings;
use parent 'Uniform::HTMX';
use Scalar::Util qw(blessed);
use Carp qw(croak);

our $VERSION = '1.02';

sub new {
    my ($class, $c) = @_;

    croak "Constructor requires a Mojolicious controller object"
        unless blessed($c) && $c->isa('Mojolicious::Controller');

    # Extract HTTP headers from Mojo::Headers object into CGI-style key hash
    my $headers = $c->req->headers;
    my %env;

    for my $name (@{ $headers->names }) {
        my $key = uc($name);
        $key =~ s/-/_/g;
        $env{"HTTP_$key"} = $headers->header($name);
    }

    return $class->SUPER::new(in => \%env, env => \%env);
}

sub apply {
    my ($self, $c) = @_;

    croak "apply() requires a Mojolicious controller object"
        unless blessed($c) && $c->isa('Mojolicious::Controller');

    my $out = $self->_out;
    return $c unless %$out;

    my $res_headers = $c->res->headers;
    for my $key (keys %$out) {
        $res_headers->header($key => $out->{$key});
    }

    return $c;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Uniform::HTMX::Mojolicious - Framework-agnostic htmx adapter for Mojolicious

=head1 SYNOPSIS

    use Mojolicious::Lite;
    use Uniform::HTMX::Mojolicious;

    get '/time' => sub {
        my $c    = shift;
        my $htmx = Uniform::HTMX::Mojolicious->new($c);

        if ($htmx->is_htmx) {
            $htmx->res_reswap('innerHTML')
                 ->res_trigger('timeUpdated', { time => scalar localtime });

            $htmx->apply($c);
            return $c->render(text => '<div>Time updated!</div>');
        }

        $c->render(text => 'Standard non-htmx request');
    };

    app->start;

=head1 DESCRIPTION

C<Uniform::HTMX::Mojolicious> bridges the C<Uniform::HTMX> base protocol engine with the L<Mojolicious> web framework. It automatically extracts incoming C<HX-*> HTTP request headers from L<Mojolicious::Controller> objects and provides a clean pipeline for queuing and applying outbound htmx response headers directly to the controller's response object.

=head1 METHODS

=head2 new

    my $htmx = Uniform::HTMX::Mojolicious->new($c);

Constructs a new instance. Requires a valid L<Mojolicious::Controller> object. Inbound headers are normalized and passed directly to the C<Uniform::HTMX> base constructor.

=head2 apply

    $htmx->apply($c);

Injects all accumulated outbound htmx response headers (such as C<HX-Trigger>, C<HX-Reswap>, C<HX-Redirect>, etc.) into the controller's L<Mojo::Headers> response object via C<< $c->res->headers >>. Returns the controller object.

=head1 INHERITED METHODS

This package inherits directly from L<Uniform::HTMX>. All request inspection and response manipulation methods provided by C<Uniform::HTMX> are fully available:

=over 4

=item * C<is_htmx>

=item * C<target>

=item * C<trigger_name>

=item * C<current_url>

=item * C<res_trigger($event, $payload)>

=item * C<res_reswap($swap_mode)>

=item * C<res_redirect($url)>

=back

=head1 SEE ALSO

=over 4

=item * L<Uniform::HTMX>

=item * L<Mojolicious>

=item * L<https://htmx.org/reference/#request_headers>

=back

=head1 AUTHOR

Joshua S. Day E<lt>HAX@cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by Joshua S. Day.

This is free software, licensed under:

  The MIT (X11) License

=cut
