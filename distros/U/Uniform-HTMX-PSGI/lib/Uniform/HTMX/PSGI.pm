package Uniform::HTMX::PSGI;

use strict;
use warnings;
use Carp qw(croak);
use parent 'Uniform::HTMX';

our $VERSION = '1.01';

# Constructor: Expects a standard PSGI %env Hash reference
sub new {
    my ($class, $env) = @_;

    croak "PSGI environment context must be a HASH reference"
        unless ref($env) eq 'HASH';

    my $self = bless {
        in   => {},
        out  => {},
        _ctx => $env,
    }, $class;

    # Pass the raw %env directly to your core version 1.01 normalization engine.
    # Your core automatically strips "HTTP_" prefixes and maps underscores to dashes!
    $self->{in} = $self->_normalize_headers($env);

    return $self;
}

# Flushes outbound HTMX instructions securely back into the PSGI lifecycle environment
sub apply {
    my ($self, $response_object) = @_;
    return $self unless ref($self->{out}) eq 'HASH';

    my %outbound = %{ $self->{out} };

    # Strategy A: If a Plack::Response object is explicitly passed, map headers directly
    if (eval { $response_object && $response_object->can('headers') }) {
        while (my ($k, $v) = each %outbound) {
            $response_object->headers->header($k => $v);
        }
    }
    # Strategy B: Fall back to stashing them inside the standard $env hash slot
    else {
        $self->{_ctx}->{'htmx.outbound'} = \%outbound;
    }

    return $self;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Uniform::HTMX::PSGI - Explicit framework-agnostic htmx adapter for the PSGI/Plack ecosystem

=head1 SYNOPSIS

=head2 Pattern A: Implicit Environment Injection (Middleware Friendly)

    use Uniform::HTMX::PSGI;

    my $app = sub {
        my $env = shift;
        my $hx  = Uniform::HTMX::PSGI->new($env);

        if ($hx->is_htmx) {
            $hx->res_retarget('#status-banner')->apply;

            my $htmx_headers = $env->{'htmx.outbound'} || {};
            return [ 200, [ 'Content-Type' => 'text/html', %$htmx_headers ], [ '<p>Updated!</p>' ] ];
        }
        return [ 200, [ 'Content-Type' => 'text/html' ], [ '<h1>Home</h1>' ] ];
    };

=head2 Pattern B: Explicit Plack::Response Target Mapping

    use Plack::Request;
    use Plack::Response;
    use Uniform::HTMX::PSGI;

    my $app = sub {
        my $env = shift;
        my $req = Plack::Request->new($env);
        my $res = $req->new_response(200);

        my $hx  = Uniform::HTMX::PSGI->new($env);

        if ($hx->is_htmx) {
            $res->content_type('text/html');
            $res->body('<p>Updated Fragment!</p>');

            # Directly updates the $res object headers!
            $hx->res_retarget('#status-banner')->apply($res);
        }

        return $res->finalize;
    };

=head1 DESCRIPTION

C<Uniform::HTMX::PSGI> maps the core L<Uniform::HTMX> specification layer directly to
raw web execution environments built on the L<PSGI/Plack specification|https://plackperl.org>.

=head1 METHODS

=head2 new( $env )

Validates and instantiates the client context mapper. Requires a valid, active PSGI
environment hash reference (C<$env>). Automatically normalizes inbound environment keys
via the core parent class.

=head2 apply( [ $plack_response ] )

Flushes accumulated response modifiers. If passed an explicit L<Plack::Response> object,
it modifies its header stack directly. Otherwise, it stashes compiled headers inside
an isolated reference token located at C<$env-E<gt>{'htmx.outbound'}>.

Returns C<$self> to support method chaining.

=head1 SEE ALSO

L<Uniform>

L<Uniform::HTMX>

L<Uniform::HTMX::Mojolicious>



=head1 AUTHOR

Joshua S. Day E<lt>HAX@cpan.orgE<gt>

=head1 LICENSE

Licensed under the same terms as Uniform::HTMX.

=cut
