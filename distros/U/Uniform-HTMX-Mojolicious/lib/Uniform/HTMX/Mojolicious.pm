package Uniform::HTMX::Mojolicious;

use strict;
use warnings;
use Carp qw(croak);
use parent 'Uniform::HTMX';

our $VERSION = '1.01';

# Constructor: Explicitly expects a Mojolicious Controller object ($c)
sub new {
    my ($class, $c) = @_;

    croak "Mojolicious context must be a blessed object reference" unless ref($c);
    croak "Not a valid Mojolicious controller execution context"
        unless $c->can('req') && $c->req->can('headers');

    my $self = bless {
        in   => {},
        out  => {},
        _ctx => $c,
    }, $class;

    # Extract headers out of Mojo::Headers
    my %raw;
    my $headers = $c->req->headers;
    foreach my $name (@{ $headers->names }) {
        $raw{$name} = $headers->header($name);
    }

    # Execute your core baseline normalization utility inherited from Uniform::HTMX
    $self->{in} = $self->_normalize_headers(\%raw);
    return $self;
}

# Flushes outbound HTMX modifications directly onto Mojolicious's active response stream
sub apply {
    my ($self) = @_;
    return $self unless ref($self->{out}) eq 'HASH';

    my %outbound = %{ $self->{out} };
    my $res_headers = $self->{_ctx}->res->headers;

    while (my ($k, $v) = each %outbound) {
        $res_headers->header($k => "$v");
    }

    return $self;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Uniform::HTMX::Mojolicious - Explicit htmx adapter connector for the Mojolicious ecosystem

=head1 SYNOPSIS

    package MyApp::Controller::Example;
    use Mojo::Base 'Mojolicious::Controller';
    use Uniform::HTMX::Mojolicious;

    sub update_widget ($self) {
        # Explicit instantiation with zero auto-detection overhead
        my $hx = Uniform::HTMX::Mojolicious->new($self);

        if ($hx->is_htmx) {
            # Chain your core operations seamlessly
            $hx->res_retarget('#realtime-status')
               ->res_trigger('widgetRefreshed')
               ->apply; # Modifies $self->res->headers immediately

            return $self->render(text => '<p>Updated content fragment!</p>');
        }

        return $self->render(template => 'full_page');
    }

=head1 DESCRIPTION

C<Uniform::HTMX::Mojolicious> provides an explicit integration binding bridge that
enables the L<Uniform::HTMX> specification layer to interact natively inside
L<Mojolicious::Controller> routing loops.

=head1 METHODS

=head2 new( $c )

Validates and instantiates the client context mapper. Requires a valid, active
L<Mojolicious::Controller> reference. Automatically normalizes inbound request
headers via the core parent class utilities.

=head2 apply()

Flushes and commits your accumulated state modifications down into the target transaction.
Injects compiled htmx configuration strings directly onto the outbound response header stack.

Returns C<$self> to support method chaining.

=head1 SEE ALSO

L<Uniform>

L<Uniform::HTMX>

L<Uniform::HTMX::PSGI>


=head1 AUTHOR

Joshua S. Day E<lt>HAX@cpan.orgE<gt>

=head1 LICENSE

Licensed under the same terms as Uniform::HTMX.

=cut
