package Uniform::Upload::PAGI;

use strict;
use warnings;
use Carp qw(croak);
use parent 'Uniform::Upload';

our $VERSION = '1.01';

# Constructor: Explicitly expects an asynchronous PAGI HTTP connection scope hash reference
sub new {
    my ($class, $scope) = @_;

    unless (defined $scope && ref($scope) eq 'HASH') {
        require Uniform::Exceptions;
        Uniform::Exceptions->throw(
            type    => 'TypeError',
            message => 'PAGI scope context must be a strict HASH reference',
        );
    }

    unless (defined $scope->{type} && $scope->{type} eq 'http') {
        require Uniform::Exceptions;
        Uniform::Exceptions->throw(
            type    => 'ValidationError',
            message => 'Not a valid PAGI HTTP connection scope',
        );
    }

    my $self = bless { files => {}, _ctx => $scope }, $class;

    # Extract PAGI multipart attachments if parsed by the gateway pipeline.
    # The PAGI spec exposes uploaded files inside an array reference block: $scope->{uploads}
    # where each element is a hash containing: field, tempname, filename, size, and type.
    my $uploads = $scope->{uploads} || [];
    if (ref($uploads) eq 'ARRAY') {
        foreach my $upload_payload (@$uploads) {
            next unless ref($upload_payload) eq 'HASH';

            my $field = $upload_payload->{field};
            next unless defined $field && length $field;

            # Map values explicitly to match your core layout specification expectations.
            # If duplicate field keys are passed, the trailing definition overrides prior entries,
            # respecting the strict last-scalar-wins policy standard of your ecosystem.
            $self->{files}->{$field} = {
                tempname => $upload_payload->{tempname},
                filename => $upload_payload->{filename},
                size     => $upload_payload->{size} || 0,
                type     => $upload_payload->{type},
            };
        }
    }

    return $self;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Uniform::Upload::PAGI - Explicit asynchronous multi-part file upload driver for PAGI

=head1 SYNOPSIS

    use Future::AsyncAwait;
    use Uniform::Upload::PAGI;

    async sub handle_async_upload ($scope, $receive, $send) {
        # Explicit instantiation with zero implicit guessing overhead
        my $upload = Uniform::Upload::PAGI->new($scope);

        if ($upload->has_file('document_payload')) {
            # Execute your core, chainable validation profiles natively
            $upload->file('document_payload')
                   ->max_size('10M')
                   ->allowed_types(['application/pdf'])
                   ->save_to('/var/secure/storage/');
        }

        await $send->({
            type    => 'http.response.start',
            status  => 200,
            headers => [['content-type', 'text/plain']],
        });
    }

=head1 DESCRIPTION

C<Uniform::Upload::PAGI> provides an explicit integration bridge connecting the
L<Uniform::Upload> specification layer to asynchronous, non-blocking multi-part
file upload environments built on the L<PAGI stream pipeline specification|https://metacpan.org>.

=head1 METHODS

=head2 new( $scope )

Validates and instantiates the asynchronous multi-part upload driver context. Requires a valid, active
PAGI connection scope hash reference (C<$scope>). Automatically maps and normalizes raw
inbound stream payload keys into core file object mutators.

=head1 AUTHOR

Joshua S. Day E<lt>HAX@cpan.orgE<gt>

=head1 LICENSE

MIT License. Copyright (c) 2026 Joshua S. Day.

=cut
