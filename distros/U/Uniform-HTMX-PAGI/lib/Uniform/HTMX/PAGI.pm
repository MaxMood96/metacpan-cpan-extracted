package Uniform::HTMX::PAGI;

use strict;
use warnings;
use parent 'Uniform::HTMX';
use Scalar::Util qw(blessed);
use Carp qw(croak);

our $VERSION = '1.02';

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
        my $headers = $res->[1];

        # If headers array uses 2-element sub-arrays [ [k1, v1], [k2, v2] ]
        if (@$headers && ref($headers->[0]) eq 'ARRAY') {
            for my $key (keys %$out) {
                push @$headers, [ $key => $out->{$key} ];
            }
        }
        # Flat key-value array backup [ k1, v1, k2, v2 ]
        else {
            for my $key (keys %$out) {
                push @$headers, $key, $out->{$key};
            }
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

=pod

=encoding utf-8

=head1 NAME

Uniform::HTMX::PAGI - Explicit htmx adapter connector for the PAGI ecosystem

=head1 SYNOPSIS

    package MyApp::Controller::Example;
    use Uniform::HTMX::PAGI;

    sub update_widget ($pagi_ctx) {
        # Explicit instantiation with zero auto-detection overhead
        my $hx = Uniform::HTMX::PAGI->new($pagi_ctx);

        if ($hx->is_htmx) {
            # Chain your core operations seamlessly
            $hx->res_retarget('#realtime-status')
               ->res_trigger('widgetRefreshed')
               ->apply; # Modifies response headers immediately

            return $pagi_ctx->render_pagi('<p>Updated content fragment!</p>');
        }

        return $pagi_ctx->render_pagi('full_page');
    }

=head1 DESCRIPTION

L<Uniform::HTMX::PAGI> bridges L<Uniform::HTMX> into native PAGI web context routines using direct object-oriented inheritance.

=head1 METHODS

=head2 new( $pagi_ctx )

Validates and instantiates the client context mapper. Requires an active PAGI application request execution context object. Automatically extracts raw headers and forwards them up to C<SUPER::new> for full normalization tracking.

=head2 apply()

Flushes and commits your accumulated state modifications down into the target transaction. Injects compiled htmx configuration strings straight into the PAGI context response headers structure.

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
