package Uniform::Upload;

use strict;
use warnings;
use Uniform::Exceptions;
use Uniform::Upload::File;

our $VERSION = '0.01';

# Base check method to be extended by concrete subclass constructor maps
sub has_file {
    my ($self, $field) = @_;
    return (defined $field && exists $self->{files}->{$field}) ? 1 : 0;
}

# Accessor method: Retrieves or instantiates the target Uniform::Upload::File object wrapper
sub file {
    my ($self, $field) = @_;

    unless (defined $field && length $field) {
        Uniform::Exceptions->throw(
            type    => 'ValidationError',
            message => 'File method requires a defined input field parameter name',
        );
    }

    unless ($self->has_file($field)) {
        Uniform::Exceptions->throw(
            type      => 'NotFoundError',
            message   => "No upload data payload found matching field name '$field'",
            attribute => $field,
        );
    }

    # Lazily wrap the raw file data payload inside the universal File mutator instance
    unless (ref($self->{files}->{$field}) eq 'Uniform::Upload::File') {
        $self->{files}->{$field} = Uniform::Upload::File->new($self->{files}->{$field});
    }

    return $self->{files}->{$field};
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Uniform::Upload - Extensible, framework-agnostic base specification layer for multi-part file uploads

=head1 SYNOPSIS

This is an abstract base module. It should not be used directly. Instead, implement or install
a framework-specific driver subclass (e.g. C<Uniform::Upload::PSGI>):

    package Uniform::Upload::PSGI;
    use parent 'Uniform::Upload';

    sub new {
        my ($class, $env) = @_;
        my $self = bless { files => {} }, $class;

        # ... Framework specific file metadata extraction logic ...
        # $self->{files}->{$field} = \%file_meta;

        return $self;
    }

=head1 DESCRIPTION

C<Uniform::Upload> provides a unified, object-oriented specification interface for validating
and storing incoming multi-part form file uploads. By isolating framework semantics,
application file handling logic remains completely portable.

Subclasses are responsible for populating C<< $self->{files} >>, a hashref keyed by
form field name, with the raw upload metadata their framework provides (typically a
hashref containing C<tempname>, C<filename>, C<size>, and C<type> — see
L<Uniform::Upload::File/new>). Everything else — lazy wrapping, validation, and
persistence — is handled by this class and L<Uniform::Upload::File>.

=head1 METHODS

=head2 has_file( $field_name )

Returns C<1> if an upload payload exists for the specified multi-part form key,
otherwise returns C<0>. Also returns C<0> (rather than throwing) if C<$field_name>
is undefined.

=head2 file( $field_name )

Returns a L<Uniform::Upload::File> object instance wrapping the targeted input
parameters. The underlying raw hashref is wrapped lazily on first access and the
wrapped object is cached in place, so subsequent calls for the same field return
the same instance.

Throws an exception via L<Uniform::Exceptions>, as follows:

=over 4

=item * type C<ValidationError> if C<$field_name> is undefined or an empty string.

=item * type C<NotFoundError> if no upload payload exists for C<$field_name>
(i.e. L<has_file|/"has_file( $field_name )"> would return false for it).

=back

=head1 SEE ALSO

L<Uniform::Upload::File>, L<Uniform::Exceptions>

=head1 AUTHOR

Joshua S. Day E<lt>HAX@cpan.orgE<gt>

=head1 LICENSE

MIT License. Copyright (c) 2026 Joshua S. Day.

=cut
