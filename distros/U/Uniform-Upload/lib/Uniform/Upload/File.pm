package Uniform::Upload::File;

use strict;
use warnings;
use File::Copy qw(copy move);
use File::Basename qw(basename);
use Uniform::Exceptions;
use Carp qw(croak);

our $VERSION = '0.02';

sub new {
    my ($class, %args) = @_;

    my $self = {
        name          => $args{name},
        filename      => $args{filename},
        tmp_path      => $args{tmp_path},
        size          => $args{size} || 0,
        type          => $args{type} || 'application/octet-stream',
        max_size      => $args{max_size},
        allowed_types => $args{allowed_types} || [],
        error         => undef,
    };

    bless $self, $class;
    $self->_validate;

    return $self;
}

sub name               { $_[0]->{name} }
sub filename           { $_[0]->{filename} }
sub tmp_path           { $_[0]->{tmp_path} }
sub size               { $_[0]->{size} }
sub type               { $_[0]->{type} }
sub error              { $_[0]->{error} }
sub is_valid           { !defined $_[0]->{error} }

sub sanitized_filename {
    my ($self) = @_;
    return '' unless defined $self->{filename};

    my $clean = basename($self->{filename});
    $clean =~ s/[^\w\.\-]/_/g;
    return $clean;
}

sub _validate {
    my ($self) = @_;

    if (defined $self->{max_size} && $self->{size} > $self->{max_size}) {
        $self->{error} = sprintf("File size (%d bytes) exceeds maximum limit (%d bytes)", $self->{size}, $self->{max_size});
        return;
    }

    if (@{ $self->{allowed_types} }) {
        my %allowed = map { $_ => 1 } @{ $self->{allowed_types} };
        unless ($allowed{ $self->{type} }) {
            $self->{error} = sprintf("MIME type '%s' is not allowed", $self->{type});
            return;
        }
    }
}

sub copy_to {
    my ($self, $dest) = @_;

    croak "Cannot copy invalid file: " . $self->{error}
        unless $self->is_valid;

    copy($self->{tmp_path}, $dest)
        or Uniform::Exceptions->throw("Failed to copy upload file to $dest: $!");
}

sub move_to {
    my ($self, $dest) = @_;

    croak "Cannot move invalid file: " . $self->{error}
        unless $self->is_valid;

    move($self->{tmp_path}, $dest)
        or Uniform::Exceptions->throw("Failed to move upload file to $dest: $!");
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Uniform::Upload::File - Encapsulated file upload wrapper with validation and file management

=head1 SYNOPSIS

    use Uniform::Upload::File;

    my $file = Uniform::Upload::File->new(
        name          => 'attachment',
        filename      => '../../../etc/passwd.jpg',
        tmp_path      => '/tmp/upload_tmp_8812',
        size          => 10240,
        type          => 'image/jpeg',
        max_size      => 1048576,
        allowed_types => ['image/jpeg'],
    );

    if ($file->is_valid) {
        print $file->sanitized_filename; # Output: passwd.jpg
        $file->copy_to('/var/data/uploads/' . $file->sanitized_filename);
    } else {
        warn $file->error;
    }

=head1 DESCRIPTION

C<Uniform::Upload::File> encapsulates individual file payloads. It executes automated size and MIME type checks upon instantiation, sanitizes user-supplied filenames to prevent path traversal attacks, and handles file movement operations safely.

=head1 METHODS

=head2 new

    my $file = Uniform::Upload::File->new(%args);

Constructs and validates the file wrapper. Populates C<error> if C<size> exceeds C<max_size> or if C<type> does not match C<allowed_types>.

=head2 is_valid

Returns C<1> if the file passed all validation checks, or C<0> if invalid.

=head2 error

Returns the validation error message string if invalid, or C<undef> if valid.

=head2 name

Returns the form parameter field name associated with the upload.

=head2 filename

Returns the raw original filename supplied by the client.

=head2 sanitized_filename

    my $clean_name = $file->sanitized_filename;

Strips leading directory path structures and replaces unsafe characters (excluding letters, numbers, dots, hyphens, and underscores) with underscores to eliminate path traversal threats.

=head2 tmp_path

Returns the path to the buffered temporary file on disk.

=head2 size

Returns the file payload size in bytes.

=head2 type

Returns the declared MIME type string.

=head2 copy_to

    $file->copy_to($destination_path);

Copies the temporary file to the destination path. Croaks if called on an invalid file or throws a L<Uniform::Exceptions> exception on filesystem failure.

=head2 move_to

    $file->move_to($destination_path);

Moves the temporary file to the destination path. Croaks if called on an invalid file or throws a L<Uniform::Exceptions> exception on filesystem failure.

=head1 SEE ALSO

=over 4

=item * L<Uniform::Upload>

=item * L<Uniform::Exceptions>

=back

=head1 AUTHOR

Joshua S. Day E<lt>HAX@cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by Joshua S. Day[cite: 9].

This is free software, licensed under:

  The MIT (X11) License

=cut
