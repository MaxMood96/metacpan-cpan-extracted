package Uniform::HTMX::PSGI;

use strict;
use warnings;
use parent 'Uniform::HTMX';
use Scalar::Util qw(blessed);
use Carp qw(croak);

our $VERSION = '1.03';

sub new {
    my ($class, $env) = @_;

    croak "Environment must be a hash reference"
        unless ref($env) eq 'HASH';

    return $class->SUPER::new(in => $env, env => $env);
}

sub apply {
    my ($self, $res) = @_;
    my $out = $self->_out;

    return $res unless keys %$out;

    if (ref($res) eq 'ARRAY' && ref($res->[1]) eq 'ARRAY') {
        for my $key (keys %$out) {
            push @{ $res->[1] }, $key, $out->{$key};
        }
    }
    elsif (blessed($res) && $res->can('headers')) {
        for my $key (keys %$out) {
            $res->headers->header($key => $out->{$key});
        }
    }
    elsif (blessed($res) && $res->can('header')) {
        for my $key (keys %$out) {
            $res->header($key => $out->{$key});
        }
    }

    return $res;
}
1;

__END__

=head1 NAME

Uniform::HTMX::PSGI - Explicit framework-agnostic htmx adapter for the PSGI/Plack ecosystem

=head1 SYNOPSIS

    use Uniform::HTMX::PSGI;

    my $app = sub {
        my $env  = shift;
        my $htmx = Uniform::HTMX::PSGI->new($env);

        # Inspect incoming htmx request attributes
        if ($htmx->is_htmx) {
            my $target = $htmx->target;

            # Queue outbound htmx response headers
            $htmx->res_trigger('itemSaved', { id => 42 })
                ->res_reswap('innerHTML');
        }

        my $res = [ 200, [ 'Content-Type' => 'text/html' ], [ '<div>Saved!</div>' ] ];

        # Inject queued headers into the PSGI response
        return $htmx->apply($res);
    };

=head1 DESCRIPTION

C<Uniform::HTMX::PSGI> provides a seamless integration between the L<Uniform::HTMX> base class and
the L<PSGI specification|https://plackperl.org/> (and by extension, the Plack middleware ecosystem).

It automatically translates PSGI C<$env> variables (like C<HTTP_HX_REQUEST>) into
the standard htmx request headers, and provides an C<apply> method capable of injecting
htmx response headers into standard PSGI array references or response objects.

=head1 METHODS

=head2 new( $env )

Constructs a new C<Uniform::HTMX::PSGI> object. Accepts the standard PSGI C<$env> hashref.

=head2 apply( $res )

Injects any queued htmx outbound headers into the given response. C<$res> can be:

=over 4

=item * A standard PSGI array reference: C<[ $status, \@headers, \@body ]>

=item * An object with a C<headers> method.

=item * An object with a C<header> method.

=back

Returns the modified C<$res> for easy chaining.

=head1 SEE ALSO

L<Uniform::HTMX>

L<PSGI>

=cut
