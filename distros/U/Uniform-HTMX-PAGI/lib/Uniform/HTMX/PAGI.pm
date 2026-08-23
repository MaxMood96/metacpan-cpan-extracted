package Uniform::HTMX::PAGI;

use strict;
use warnings;
use Carp qw(croak);
use parent 'Uniform::HTMX';

our $VERSION = '1.00';

# Constructor: Explicitly expects an asynchronous PAGI HTTP connection scope hash reference
sub new {
    my ($class, $scope) = @_;

    croak "PAGI scope must be a HASH reference" unless ref($scope) eq 'HASH';
    croak "Not a valid PAGI HTTP connection scope"
        unless (defined $scope->{type} && $scope->{type} eq 'http');

    my $self = bless {
        in   => {},
        out  => {},
        _ctx => $scope,
    }, $class;

    # Extract PAGI nested array of array headers: [ ['hx-request', 'true'], ['hx-target', 'grid'] ]
    my %raw;
    if ($scope->{headers} && ref($scope->{headers}) eq 'ARRAY') {
        foreach my $pair (@{ $scope->{headers} }) {
            next unless ref($pair) eq 'ARRAY' && defined $pair->[0];

            # Group identical keys inside array references so your core engine's
            # multi-value reduction filter can safely isolate the winning scalar
            push @{ $raw{$pair->[0]} }, $pair->[1];
        }
    }

    # Pass the isolated dataset directly to your central Uniform normalization routine
    $self->{in} = $self->_normalize_headers(\%raw);
    return $self;
}

# Flushes outbound changes asynchronously back down into the target scope reference block
sub apply {
    my ($self) = @_;
    return $self unless ref($self->{out}) eq 'HASH';

    my %outbound = %{ $self->{out} };

    # Transform flat outbound instructions into the explicit PAGI array-of-arrays context format
    $self->{_ctx}->{'htmx.outbound'} = [
        map { [ $_ => "$outbound{$_}" ] } keys %outbound
    ];

    return $self;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Uniform::HTMX::PAGI - Explicit asynchronous htmx driver adapter for the PAGI gateway ecosystem

=head1 SYNOPSIS

    use Future::AsyncAwait;
    use Uniform::HTMX::PAGI;

    async sub handle_pagi_stream ($scope, $receive, $send) {
        # Explicit instantiation with zero implicit guessing overhead
        my $hx = Uniform::HTMX::PAGI->new($scope);

        my @response_headers = (['content-type', 'text/html']);

        if ($hx->is_htmx) {
            $hx->res_retarget('#realtime-status-container')
               ->res_trigger('asyncProcessingStarted')
               ->apply; # Stashes parameters securely inside $scope

            # Append stashed array fields directly to your response stream packet
            push @response_headers, @{ $scope->{'htmx.outbound'} || [] };
        }

        await $send->({
            type    => 'http.response.start',
            status  => 200,
            headers => \@response_headers,
        });

        await $send->({
            type => 'http.response.body',
            body => '<p>Live async fragment stream payload updated natively!</p>',
            more => 0,
        });
    }

=head1 DESCRIPTION

C<Uniform::HTMX::PAGI> provides a non-blocking integration bridge linking the
L<Uniform::HTMX> base layer directly into the event-driven L<PAGI stream pipeline specification|https://metacpan.org>.

=head1 METHODS

=head2 new( $scope )

Validates and instantiates the asynchronous client context driver. Requires an active PAGI
HTTP connection scope hash reference. Automatically flattens and normalizes inbound header arrays.

=head2 apply()

Flushes and commits your accumulated state modifications down into the target scope data payload.
Stashes compiled headers inside an isolated array reference token located at
C<$scope-E<gt>{'htmx.outbound'}>.

Returns C<$self> to support method chaining


=head1 SEE ALSO

L<Uniform>

L<Uniform::HTMX>

L<Uniform::HTMX::PSGI>

L<Uniform::HTMX::Mojolicious>



=head1 AUTHOR

Joshua S. Day E<lt>HAX@cpan.orgE<gt>

=head1 LICENSE

Licensed under the same terms as Uniform::HTMX.

=cut
