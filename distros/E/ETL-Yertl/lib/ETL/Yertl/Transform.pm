package ETL::Yertl::Transform;
our $VERSION = '0.044';
# ABSTRACT: Transform a stream of documents

#pod =head1 SYNOPSIS
#pod
#pod     ### Simple transform callback
#pod     use ETL::Yertl;
#pod     use ETL::Yertl::Transform;
#pod     my $xform = ETL::Yertl::Transform->new(
#pod         transform_doc => sub {
#pod             # Document is in $_
#pod         },
#pod         source => ETL::Yertl::FormatStream->new_for_stdin,
#pod         destination => ETL::Yertl::FormatStream->new_for_stdout,
#pod     );
#pod
#pod     ### Transform class
#pod     package Local::Transform::Dump;
#pod     use ETL::Yertl;
#pod     use Data::Dumper;
#pod     use base 'ETL::Yertl::Transform';
#pod     sub transform_doc {
#pod         my ( $self, $doc ) = @_;
#pod         say Dumper $doc;
#pod         return $doc;
#pod     }
#pod
#pod     package main;
#pod     use ETL::Yertl;
#pod     my $xform = Local::Transform::Dump->new(
#pod         source => ETL::Yertl::FormatStream->new_for_stdin,
#pod         destination => ETL::Yertl::FormatStream->new_for_stdout,
#pod     );
#pod
#pod =head1 DESCRIPTION
#pod
#pod This class holds a transformation routine in a Yertl stream. Transforms
#pod read documents from L<ETL::Yertl::FormatStream> objects and optionally
#pod write them to another L<ETL::Yertl::FormatStream> object. Transforms can
#pod chain to other transforms, creating a pipeline of transformations.
#pod
#pod Transformations can be simple subroutines or full classes (inheriting
#pod from this class).
#pod
#pod =head2 Transform Object
#pod
#pod Create ad-hoc transform objects by passing in a C<transform_doc>
#pod callback. The callback receives two arguments: The transform object, and
#pod the document to transform.  The callback should return the transformed
#pod document (whether or not it is the same document modified in-place).
#pod
#pod =head2 Transform Class
#pod
#pod Create transform classes by inheriting from C<ETL::Yertl::Transform>.
#pod Subclasses can override the C<transform_doc> method to transform
#pod documents. This method receives the same arguments, returns the same
#pod values, sets C<$_>, and behaves exactly like the C<transform_doc>
#pod callback.
#pod
#pod =head2 Overloaded Operators
#pod
#pod Transforms can be chained together using the pipe (C<|>) operator. The
#pod result of the expression is the transform on the right side, for
#pod continued chaining.
#pod
#pod     my $xform1 = ETL::Yertl::Transform->new(
#pod         transform_doc => sub { ... },
#pod     );
#pod     my $xform2 = ETL::Yertl::Transform->new(
#pod         transform_doc => sub { ... },
#pod     );
#pod     my $xform3 = $xform1 | $xform2 | ETL::Yertl::Transform->new(
#pod         transform_doc => sub { ... },
#pod     );
#pod
#pod Transforms can receive sources using the C<< << >> operator with
#pod a L<ETL::Yertl::FormatStream> object. The result of the expression is
#pod the transform object, for continued chaining.
#pod
#pod     my $input = ETL::Yertl::FormatStream->new_for_stdin;
#pod     my $xform = ETL::Yertl::Transform->new(
#pod         transform_doc => sub { ... },
#pod     ) << $input;
#pod
#pod Transforms can receive destinations using the C<< >> >> operator with
#pod a L<ETL::Yertl::FormatStream> object. The result of the expression is
#pod the transform object, for continued chaining.
#pod
#pod     my $output = ETL::Yertl::FormatStream->new_for_stdout;
#pod     my $xform = ETL::Yertl::Transform->new(
#pod         transform_doc => sub { ... },
#pod     ) >> $output;
#pod
#pod =head1 SEE ALSO
#pod
#pod L<ETL::Yertl>, L<ETL::Yertl::FormatStream>
#pod
#pod =cut

use ETL::Yertl;
use Scalar::Util qw( weaken );
use Carp qw( croak );

use base 'IO::Async::Notifier';

# override pipe, <<, and >> to set on_read_doc and on_write_doc
# handlers appropriately
use overload
    '>>' => \&_set_output,
    '<<' => \&_set_input,
    '|' => \&_pipe,
    'fallback' => 1,
    ;

sub _set_output {
    my ( $self, $output ) = @_;
    # TODO: Allow Path::Tiny objects as output
    # TODO: Allow arrayrefs as output
    $self->configure( destination => $output );
    return $self;
}

sub _set_input {
    my ( $self, $input ) = @_;
    # TODO: Allow Path::Tiny objects as input
    # TODO: Allow arrayrefs as input
    $self->configure( source => $input );
    return $self;
}

sub _pipe {
    my ( $self, $other, $swap ) = @_;
    if ( $swap ) {
        ( $self, $other ) = ( $other, $self );
    }
    # TODO: Allow CODE ref as pipe to make up transform
    $other->configure( source => $self );
    return $other;
}

#pod =method new
#pod
#pod     my $xform = ETL::Yertl::Transform->new( %args );
#pod
#pod Create a new transform object. C<%args> is a hash with the following keys:
#pod
#pod =over
#pod
#pod =item source
#pod
#pod The source for documents. Can be a L<ETL::Yertl::FormatStream> or
#pod a L<ETL::Yertl::Transform> object. You do not need to specify this right
#pod away, but it is required for the transform to do useful work.
#pod
#pod =item destination
#pod
#pod (optional) A L<ETL::Yertl::FormatStream> object to write the documents
#pod to.  This can be an intermediate destination or the ultimate
#pod destination.  The last transform in a stream should have a destination.
#pod
#pod =item transform_doc
#pod
#pod A subref to transform the documents read from the source. The subref
#pod will receive two arguments: The transform object and the document to
#pod transform. It should return the transformed document.  The document to
#pod transform is also set as C<$_> for simpler transforms.
#pod
#pod =back
#pod
#pod =method configure
#pod
#pod     $xform->configure( %args );
#pod
#pod Configure this object. Takes the same arguments as the constructor,
#pod L</new>. This method allows updating any of the transform attributes
#pod later, so that transforms can be given new sources/destinations.
#pod
#pod =cut

sub configure {
    my ( $self, %args ) = @_;

    if ( $args{source} ) {
        # Register ourselves with the source
        my $source = $self->{source} = delete $args{source};
        weaken $self;
        $source->configure(
            on_doc => sub {
                my ( $source, $doc, $eof ) = @_;
                local $_ = $doc;
                my @docs = $self->invoke_event( transform_doc => $doc );
                # ; say "Writing docs from return: " . join ", ", @docs;
                # ; use Data::Dumper;
                # ; say STDERR Dumper( \@docs );
                $self->write( $_ ) for grep { $_ } @docs;
                return;
            },
            # XXX This probably needs to be done better:
            # * Users can't add their own handler to this event at all,
            #   making it more difficult to add Yertl streams to larger
            #   programs
            # * This requires on_read_eof to be called after all
            #   transforms are complete, which prevents cooperative
            #   multitasking by using `$self->loop->later` to defer
            #   execution of the transform_doc method/callback
            on_read_eof => sub {
                if ( my $dest = $self->{destination} ) {
                    if ( $dest->{write_handle} != \*STDOUT ) {
                        # Gracefully close the destination and then let
                        # anyone using us as a source know we're finished
                        $dest->configure( on_closed => sub {
                            $self->maybe_invoke_event( 'on_read_eof' );
                        } );
                        $dest->close_when_empty;
                        return;
                    }
                }
                # We emit our own on_read_eof event so downstream things
                # can clean up
                $self->maybe_invoke_event( 'on_read_eof' );
            },
        );
    }
    elsif ( !$self->{source} ) {
        # If we remove this requirement, we can configure objects and
        # add sources to them later, which could enable a bunch of fun
        # things like a pipe-based stream.
        # Without a source, this thing does nothing useful anyway, so
        # it'll be pretty obvious that something is broken.
        # croak "Expected a source";
    }

    if ( $args{destination} ) {
        $self->{destination} = delete $args{destination};
    }

    for my $event ( qw( transform_doc on_doc on_read_eof ) ) {
        $self->{ $event } = delete $args{ $event } if exists $args{ $event };
    }
    croak "Expected either a transform_doc callback or to be able to ->transform_doc"
        unless $self->can_event( 'transform_doc' );
    $self->{on_doc} ||= sub { }; # Default on_doc does nothing

    $self->SUPER::configure( %args );
}

#pod =method write
#pod
#pod     $xform->write( $doc );
#pod
#pod Write a document explicitly. This can be used by the C<transform_doc> callback to
#pod write documents without needing to return them from the callback.
#pod
#pod =cut

sub write {
    my ( $self, $doc ) = @_;
    if ( my $dest = $self->{destination} ) {
        # ; say "Writing to output $dest";
        $dest->write( $doc );
    }
    $self->invoke_event( on_doc => $doc );
}

#pod =method run
#pod
#pod     $xform->run;
#pod
#pod Run the transform, returning when all data is read from the source, and all data
#pod written to the destination (if any).
#pod
#pod =cut

sub run {
    my ( $self ) = @_;

    if ( !$self->loop ) {
        croak "Can't run(): Transform not added to loop";
    }

    # Run the transforms until this point
    # Default on_read_eof exits the loop. This gets replaced by a new
    # on_read_eof when transforms are added as a source for another
    # transform
    my $on_read_eof = $self->{on_read_eof} || $self->can( 'on_read_eof' ) || sub { };
    $self->configure(
        on_read_eof => sub {
            $on_read_eof->( @_ );
            $self->loop->stop;
        },
    );
    $self->loop->run;
}

1;

__END__

=pod

=head1 NAME

ETL::Yertl::Transform - Transform a stream of documents

=head1 VERSION

version 0.044

=head1 SYNOPSIS

    ### Simple transform callback
    use ETL::Yertl;
    use ETL::Yertl::Transform;
    my $xform = ETL::Yertl::Transform->new(
        transform_doc => sub {
            # Document is in $_
        },
        source => ETL::Yertl::FormatStream->new_for_stdin,
        destination => ETL::Yertl::FormatStream->new_for_stdout,
    );

    ### Transform class
    package Local::Transform::Dump;
    use ETL::Yertl;
    use Data::Dumper;
    use base 'ETL::Yertl::Transform';
    sub transform_doc {
        my ( $self, $doc ) = @_;
        say Dumper $doc;
        return $doc;
    }

    package main;
    use ETL::Yertl;
    my $xform = Local::Transform::Dump->new(
        source => ETL::Yertl::FormatStream->new_for_stdin,
        destination => ETL::Yertl::FormatStream->new_for_stdout,
    );

=head1 DESCRIPTION

This class holds a transformation routine in a Yertl stream. Transforms
read documents from L<ETL::Yertl::FormatStream> objects and optionally
write them to another L<ETL::Yertl::FormatStream> object. Transforms can
chain to other transforms, creating a pipeline of transformations.

Transformations can be simple subroutines or full classes (inheriting
from this class).

=head2 Transform Object

Create ad-hoc transform objects by passing in a C<transform_doc>
callback. The callback receives two arguments: The transform object, and
the document to transform.  The callback should return the transformed
document (whether or not it is the same document modified in-place).

=head2 Transform Class

Create transform classes by inheriting from C<ETL::Yertl::Transform>.
Subclasses can override the C<transform_doc> method to transform
documents. This method receives the same arguments, returns the same
values, sets C<$_>, and behaves exactly like the C<transform_doc>
callback.

=head2 Overloaded Operators

Transforms can be chained together using the pipe (C<|>) operator. The
result of the expression is the transform on the right side, for
continued chaining.

    my $xform1 = ETL::Yertl::Transform->new(
        transform_doc => sub { ... },
    );
    my $xform2 = ETL::Yertl::Transform->new(
        transform_doc => sub { ... },
    );
    my $xform3 = $xform1 | $xform2 | ETL::Yertl::Transform->new(
        transform_doc => sub { ... },
    );

Transforms can receive sources using the C<< << >> operator with
a L<ETL::Yertl::FormatStream> object. The result of the expression is
the transform object, for continued chaining.

    my $input = ETL::Yertl::FormatStream->new_for_stdin;
    my $xform = ETL::Yertl::Transform->new(
        transform_doc => sub { ... },
    ) << $input;

Transforms can receive destinations using the C<< >> >> operator with
a L<ETL::Yertl::FormatStream> object. The result of the expression is
the transform object, for continued chaining.

    my $output = ETL::Yertl::FormatStream->new_for_stdout;
    my $xform = ETL::Yertl::Transform->new(
        transform_doc => sub { ... },
    ) >> $output;

=head1 METHODS

=head2 new

    my $xform = ETL::Yertl::Transform->new( %args );

Create a new transform object. C<%args> is a hash with the following keys:

=over

=item source

The source for documents. Can be a L<ETL::Yertl::FormatStream> or
a L<ETL::Yertl::Transform> object. You do not need to specify this right
away, but it is required for the transform to do useful work.

=item destination

(optional) A L<ETL::Yertl::FormatStream> object to write the documents
to.  This can be an intermediate destination or the ultimate
destination.  The last transform in a stream should have a destination.

=item transform_doc

A subref to transform the documents read from the source. The subref
will receive two arguments: The transform object and the document to
transform. It should return the transformed document.  The document to
transform is also set as C<$_> for simpler transforms.

=back

=head2 configure

    $xform->configure( %args );

Configure this object. Takes the same arguments as the constructor,
L</new>. This method allows updating any of the transform attributes
later, so that transforms can be given new sources/destinations.

=head2 write

    $xform->write( $doc );

Write a document explicitly. This can be used by the C<transform_doc> callback to
write documents without needing to return them from the callback.

=head2 run

    $xform->run;

Run the transform, returning when all data is read from the source, and all data
written to the destination (if any).

=head1 SEE ALSO

L<ETL::Yertl>, L<ETL::Yertl::FormatStream>

=head1 AUTHOR

Doug Bell <preaction@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2018 by Doug Bell.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
