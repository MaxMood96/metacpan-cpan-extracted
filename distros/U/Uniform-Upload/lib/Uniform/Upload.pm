package Uniform::Upload;

use strict;
use warnings;
use Uniform::Utils qw(parse_size_limit);
use Uniform::Exceptions;
use Uniform::Upload::File;
use Carp qw(croak);

our $VERSION = '0.02';

sub new {
    my ($class, %args) = @_;

    my $max_bytes;
    if (defined $args{max_size}) {
        my $limit = $args{max_size};
        $limit =~ s/b$//i if $limit =~ /[a-z]$/i; # Strip trailing 'B' or 'b' (e.g. '2MB' -> '2M')
        $max_bytes = parse_size_limit($limit);
    }

    my $self = {
        max_size      => $max_bytes,
        allowed_types => $args{allowed_types} || [],
        file_class    => $args{file_class}    || 'Uniform::Upload::File',
        in            => $args{in}            || undef,
    };

    return bless $self, $class;
}

sub file_class    { $_[0]->{file_class} }
sub max_size      { $_[0]->{max_size} }
sub allowed_types { $_[0]->{allowed_types} }

sub wrap {
    my ($self, %args) = @_;

    my $file_class = $self->file_class;

    return $file_class->new(
        name          => $args{name},
        filename      => $args{filename},
        tmp_path      => $args{tmp_path},
        size          => $args{size},
        type          => $args{type},
        max_size      => $self->{max_size},
        allowed_types => $self->{allowed_types},
    );
}

sub extract {
    my ($self) = @_;
    croak ref($self) . " must implement extract()";
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Uniform::Upload - Framework-agnostic upload manager and base driver engine

=head1 SYNOPSIS

    use Uniform::Upload;

    # Standalone manager setup
    my $upload = Uniform::Upload->new(
        max_size      => '5MB',
        allowed_types => [qw( image/png image/jpeg application/pdf )],
    );

    # Wrap raw upload payload hashes into validated objects
    my $file = $upload->wrap(
        name     => 'avatar',
        filename => 'user_photo.png',
        tmp_path => '/tmp/cpan_upload_12345',
        size     => 2048576,
        type     => 'image/png',
    );

    if ($file->is_valid) {
        $file->copy_to('/var/uploads/' . $file->sanitized_filename);
    } else {
        die "Upload failed validation: " . $file->error;
    }

=head1 DESCRIPTION

C<Uniform::Upload> provides a unified interface for inspecting, validating, and managing uploaded files across web applications. It acts as both a standalone file upload factory and an abstract base engine for framework-specific extension drivers (such as C<Uniform::Upload::PAGI> or C<Uniform::Upload::Plack>).

=head1 METHODS

=head2 new

    my $upload = Uniform::Upload->new(%options);

Constructs a new manager object. Supported options:

=over 4

=item * C<max_size>

Maximum file size cap. Accepts raw byte integers or human-readable strings like C<'2MB'> or C<'500KB'> (parsed via L<Uniform::Utils>).

=item * C<allowed_types>

Array reference of allowed MIME type strings (e.g., C<['image/png', 'image/jpeg']>).

=item * C<file_class>

Package name used to wrap file payloads. Defaults to L<Uniform::Upload::File>.

=back

=head2 wrap

    my $file = $upload->wrap(%file_args);

Instantiates and returns a new L<Uniform::Upload::File> (or custom C<file_class>) instance initialized with the manager's global validation parameters.

=head2 extract

    my $files = $upload->extract;

Abstract factory method intended to be overridden by subclass drivers to parse incoming framework request payloads. Croaks if invoked directly on C<Uniform::Upload>.

=head2 max_size

Returns the parsed byte cap for uploads, or C<undef> if unrestricted.

=head2 allowed_types

Returns the array reference of configured MIME type string constraints.

=head2 file_class

Returns the target file wrapper class package name.

=head1 INHERITANCE AND SUBCLASSING

Subclass drivers extend C<Uniform::Upload> using object-oriented inheritance via L<parent> and constructor delegation with C<SUPER::new>:

    package Uniform::Upload::MyFramework;

    use strict;
    use warnings;
    use parent 'Uniform::Upload';
    use Scalar::Util qw(blessed);
    use Carp qw(croak);

    sub new {
        my ($class, $req, %args) = @_;

        croak "Requires request object" unless blessed($req);

        return $class->SUPER::new(
            in => $req,
            %args,
        );
    }

    sub extract {
        my ($self) = @_;
        my $req = $self->{in};

        my @files;
        for my $raw ($req->uploads) {
            push @files, $self->wrap(%$raw);
        }
        return \@files;
    }

    1;

=head1 SEE ALSO

=over 4

=item * L<Uniform::Upload::File>

=item * L<Uniform::Utils>

=item * L<Uniform::Exceptions>

=back

=head1 AUTHOR

Joshua S. Day E<lt>HAX@cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by Joshua S. Day[cite: 9].

This is free software, licensed under:

  The MIT (X11) License

=cut
