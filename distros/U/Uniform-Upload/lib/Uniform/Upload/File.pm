package Uniform::Upload::File;

use strict;
use warnings;
use File::Copy qw(copy);
use File::Basename qw(basename);
use Uniform::Exceptions;
use Uniform::Utils qw(parse_size_limit);

our $VERSION = '0.01';

# Constructor wraps the raw hash attributes
sub new {
    my ($class, $meta) = @_;

    my $self = {
        tempname => $meta->{tempname} || undef,
        filename => $meta->{filename} || undef,
        size     => $meta->{size}     || 0,
        type     => $meta->{type}     || undef,
    };

    return bless $self, $class;
}

sub size     { my $self = shift; return $self->{size} }
sub type     { my $self = shift; return $self->{type} }
sub filename { my $self = shift; return $self->{filename} }

# Validates the file's size against a human-readable max, e.g. '2M', '500K', '1G', or a plain byte count.
# Delegates the string parsing to Uniform::Utils::parse_size_limit, shared across the
# Uniform ecosystem. Throws a ValidationError if the file exceeds the limit (parse_size_limit
# throws its own ValidationError for a missing/unparsable limit string). Returns $self on success.
sub max_size {
    my ($self, $limit) = @_;

    my $bytes = parse_size_limit($limit);

    if (($self->{size} || 0) > $bytes) {
        Uniform::Exceptions->throw(
            type      => 'ValidationError',
            message   => "File size $self->{size} exceeds maximum allowed size of $limit",
            attribute => 'size',
        );
    }

    return $self;
}

# Validates the file's MIME type against a whitelist of allowed types.
# Throws a ValidationError if the type is not permitted. Returns $self on success for chaining.
sub allowed_types {
    my ($self, $types) = @_;

    unless (defined $types && ref($types) eq 'ARRAY' && @$types) {
        Uniform::Exceptions->throw(
            type    => 'ValidationError',
            message => 'allowed_types requires a non-empty arrayref of MIME type strings',
        );
    }

    my $type = defined $self->{type} ? $self->{type} : '';
    unless (grep { $_ eq $type } @$types) {
        Uniform::Exceptions->throw(
            type      => 'ValidationError',
            message   => "File type '$type' is not among the allowed types: " . join(', ', @$types),
            attribute => 'type',
        );
    }

    return $self;
}

# Defensive security guard scrubbing malicious directory path mutations or null-byte hacks
sub sanitize_filename {
    my ($self) = @_;
    return $self unless defined $self->{filename} && length $self->{filename};

    my $raw_name = $self->{filename};

    # 1. Standardize cross-platform separators
    $raw_name =~ s{\\}{/}g;

    # 2. Strip directory segments completely to isolate the true file tail node
    my $clean = basename($raw_name);

    # 3. Purge dangerous language boundary markers (null bytes)
    $clean =~ s/\x00//g;

    # 4. Whitelist safe alphanumeric boundaries, converting illegal parameters to hyphens
    $clean =~ s/[^a-zA-Z0-9._-]/-/g;

    # 5. Collapse duplicate or trailing hyphen strings
    $clean =~ s/-+/-/g;
    $clean =~ s/^-+|-+$//g;

    # 6. Safety fallback: If string filtering reduces the name to nothing, provide a safe default string
    if (!defined $clean || length($clean) == 0 || $clean eq '.') {
        $clean = 'uploaded_file';
    }

    $self->{filename} = $clean;
    return $self;
}

# Output execution boundary: Copies the file from temporary cache storage to live system storage destinations.
# Always sanitizes the filename first so callers can't accidentally skip that step and reopen a
# path-traversal hole by passing an unsanitized $self->{filename} straight into the target path.
sub save_to {
    my ($self, $destination) = @_;

    unless (defined $destination && length $destination) {
        Uniform::Exceptions->throw(type => 'ValidationError', message => 'save_to requires an absolute folder or string path target destination');
    }

    my $source = $self->{tempname};
    unless (defined $source && -e $source) {
        Uniform::Exceptions->throw(type => 'IOError', message => 'Temporary source cache file does not exist or has expired from system paths');
    }

    $self->sanitize_filename;

    my $target = $destination;
    if ($destination =~ m{[\\/]$} || -d $destination) {
        $destination =~ s{[\\/]$}{};
        $target = "$destination/" . $self->{filename};
    }

    copy($source, $target) or Uniform::Exceptions->throw(
        type    => 'IOError',
        message => "Failed to copy file from '$source' to '$target': $!",
    );

    return $self;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Uniform::Upload::File - Value object wrapping a single uploaded file's metadata and operations

=head1 SYNOPSIS

Instances of this class are not normally constructed directly. They are returned by
L<Uniform::Upload/file>, which lazily wraps the raw upload metadata a driver subclass
collected:

    my $file = $upload->file('avatar_field');

    $file->max_size('2M');
    $file->allowed_types(['image/jpeg', 'image/png']);

    $file->sanitize_filename;
    $file->save_to('/var/www/uploads/');

=head1 DESCRIPTION

C<Uniform::Upload::File> wraps the raw C<tempname>/C<filename>/C<size>/C<type> tuple
produced by a framework's upload handling and provides a uniform, chainable interface
for validating, sanitizing, and persisting the file. All validation and I/O methods
throw L<Uniform::Exceptions> on failure rather than returning false, and return
C<$self> on success so calls can be chained.

=head1 METHODS

=head2 new( \%meta )

Constructs a new instance from a hashref of raw metadata. Recognized keys are
C<tempname>, C<filename>, C<size>, and C<type>; any that are missing default to
C<undef> (or C<0> for C<size>). This is normally called for you by
L<Uniform::Upload/file>, not directly by application code.

=head2 size

Returns the file's size in bytes, as reported by the upload metadata.

=head2 type

Returns the file's MIME type, as reported by the upload metadata.

=head2 filename

Returns the file's current filename. This reflects whatever was passed in at
construction time, unless it has since been overwritten by L</sanitize_filename>
(which C<save_to> also calls internally).

=head2 max_size( $limit )

Validates that L</size> does not exceed C<$limit>. Size string parsing is delegated
to L<Uniform::Utils/parse_size_limit>: C<$limit> may be a human-readable size string
such as C<'2M'>, C<'500K'>, or C<'1G'> (kilobytes/megabytes/gigabytes, 1024-based),
or a plain number of bytes. Throws a C<ValidationError> if C<$limit> is missing or
unparsable (raised by L<Uniform::Utils/parse_size_limit>), or if the limit is
exceeded (raised here). Returns C<$self> on success.

=head2 allowed_types( \@mime_types )

Validates that L</type> exactly matches one of the strings in C<\@mime_types>.
Throws a C<ValidationError> if the arrayref is missing/empty, or if the file's
type is not in the list. Returns C<$self> on success.

=head2 sanitize_filename

Rewrites L</filename> in place to a safe, flat filename: cross-platform path
separators are normalized, any directory component is stripped (via
L<File::Basename>), null bytes are removed, and remaining characters outside
C<[a-zA-Z0-9._-]> are collapsed to hyphens. If sanitization would produce an
empty or meaningless name, it falls back to C<'uploaded_file'>. Returns C<$self>.
Safe to call on a file with no filename set (a no-op in that case).

=head2 save_to( $destination )

Copies the file from its temporary source path to C<$destination>. Always calls
L</sanitize_filename> first, so the copied file is written under a safe name
regardless of whether the caller sanitized it beforehand — note this means
L</filename> may be mutated as a side effect of calling C<save_to>.

If C<$destination> ends in a path separator, or is an existing directory, the
file is written inside it under its (now-sanitized) filename; otherwise
C<$destination> is treated as the full target path. Throws a C<ValidationError>
if C<$destination> is missing, an C<IOError> if the temporary source file no
longer exists, and an C<IOError> if the copy itself fails. Returns C<$self> on
success.

=head1 SEE ALSO

L<Uniform::Upload>, L<Uniform::Exceptions>, L<Uniform::Utils>

=head1 AUTHOR

Joshua S. Day E<lt>HAX@cpan.orgE<gt>

=head1 LICENSE

MIT License. Copyright (c) 2026 Joshua S. Day.

=cut
