package Uniform::Upload::PAGI;

use strict;
use warnings;
use parent 'Uniform::Upload';
use Future;
use Carp qw(croak);

our $VERSION = '1.02';

sub new {
    my ($class, @args) = @_;

    my ($scope, %opts);
    if (@args % 2 != 0) {
        $scope = shift @args;
        %opts  = @args;
    } else {
        %opts  = @args;
        $scope = delete $opts{scope};
    }

    croak "Scope must be a HASH reference" if defined $scope && ref($scope) ne 'HASH';

    return $class->SUPER::new(in => $scope, %opts);
}

sub extract_async {
    my ($self, $receive) = @_;

    my $scope = $self->{in};
    croak "PAGI scope required to extract uploads" unless defined $scope;

    return $self->_read_pagi_body($receive)->then(sub {
        my ($body) = @_;

        # Find Content-Type header from PAGI scope
        my $content_type = '';
        for my $h (@{ $scope->{headers} || [] }) {
            if (lc($h->[0]) eq 'content-type') {
                $content_type = $h->[1];
                last;
            }
        }

        # Delegate parsing to base class method
        my $raw_files = $self->parse_multipart_stream($content_type, $body);

        return Future->done([ map { $self->wrap(%$_) } @$raw_files ]);
    });
}

sub _read_pagi_body {
    my ($self, $receive) = @_;

    my $body = '';
    my $read_loop;
    $read_loop = sub {
        return $receive->()->then(sub {
            my ($event) = @_;
            if (($event->{type} || '') eq 'http.request') {
                $body .= $event->{body} if defined $event->{body};
                return $read_loop->() if $event->{more_body};
            }
            return Future->done($body);
        });
    };

    return $read_loop->();
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Uniform::Upload::PAGI - Async PAGI framework adapter for Uniform::Upload

=head1 SYNOPSIS

    use Uniform::Upload::PAGI;

    # Initialize driver with a PAGI scope and upload constraints
    my $uploader = Uniform::Upload::PAGI->new(
        $scope,
        max_size      => '10MB',
        allowed_types => [qw( image/png image/jpeg application/pdf )],
    );

    # Parse PAGI stream asynchronously
    $uploader->extract_async($receive)->then(sub {
        my ($files) = @_; # Arrayref of Uniform::Upload::File objects

        for my $file (@$files) {
            if ($file->is_valid) {
                $file->copy_to('/var/uploads/' . $file->sanitized_filename);
            } else {
                warn "Invalid upload: " . $file->error;
            }
        }
    });

=head1 DESCRIPTION

C<Uniform::Upload::PAGI> inherits directly from L<Uniform::Upload>. It bridges asynchronous PAGI application streams with the C<Uniform::Upload> file validation engine and wraps extracted files into L<Uniform::Upload::File> instances.

=head1 METHODS

=head2 new

    my $uploader = Uniform::Upload::PAGI->new($scope, %options);
    # or
    my $uploader = Uniform::Upload::PAGI->new(scope => $scope, %options);

Constructs a new PAGI driver instance. Delegates configuration parsing and state setup to L<Uniform::Upload/new> via C<SUPER::new>.

=head2 extract_async

    my $future = $uploader->extract_async($receive);

Asynchronously parses the incoming PAGI multi-part body stream from the configured scope. Returns a L<Future> that resolves to an array reference of validated L<Uniform::Upload::File> instances.

=head1 INHERITED METHODS

This package inherits directly from L<Uniform::Upload>. The following base methods are available:

=over 4

=item * C<wrap(%file_args)>

=item * C<max_size>

=item * C<allowed_types>

=item * C<file_class>

=back

=head1 SEE ALSO

=over 4

=item * L<Uniform::Upload>

=item * L<Uniform::Upload::File>

=item * L<Uniform::Utils>

=back

=head1 AUTHOR

Joshua S. Day E<lt>HAX@cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by Joshua S. Day.

This is free software, licensed under:

  The MIT (X11) License

=cut
