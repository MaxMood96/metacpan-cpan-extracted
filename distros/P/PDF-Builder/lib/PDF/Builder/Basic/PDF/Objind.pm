#=======================================================================
#
#   THIS IS A REUSED PERL MODULE, FOR PROPER LICENCING TERMS SEE BELOW:
#
#   Copyright Martin Hosken <Martin_Hosken@sil.org>
#
#   No warranty or expression of effectiveness, least of all regarding
#   anyone's safety, is implied in this software or documentation.
#
#   This specific module is licensed under the Perl Artistic License.
#   Effective 28 January 2021, the original author and copyright holder, 
#   Martin Hosken, has given permission to use and redistribute this module 
#   under the MIT license.
#
#=======================================================================
package PDF::Builder::Basic::PDF::Objind;

use strict;
use warnings;
use Scalar::Util 'isweak';

our $VERSION = '3.027'; # VERSION
our $LAST_UPDATE = '3.027'; # manually update whenever code is changed

=head1 NAME

PDF::Builder::Basic::PDF::Objind - PDF indirect object reference

Also acts as an abstract superclass for all elements in a PDF file

=head1 INSTANCE VARIABLES

Instance variables differ from content variables in that they all start with
a space.

=over

=item ' parent'

For an object which is a reference to an object in some source, this holds the
reference to the source object, so that should the reference have to be
de-referenced, then we know where to go and get the info.

=item ' objnum' (R)

The object number in the source (only for object references)

=item ' objgen' (R)

The object generation in the source

There are other instance variables which are used by the parent for file control.

=item ' isfree'

This marks whether the object is in the free list and available for re-use as
another object elsewhere in the file.

=item ' nextfree'

Holds a direct reference to the next free object in the free list.

=back

=head1 METHODS

=cut

use Scalar::Util qw(blessed reftype weaken);

use vars qw($uidc @inst %inst);
$uidc = "pdfuid000";

# protected keys during emptying and copying, etc.
@inst = qw(parent objnum objgen isfree nextfree uid realised);
$inst{" $_"} = 1 for @inst;

=head2 new

    PDF::Builder::Basic::PDF::Objind->new()

=over

Creates a new indirect object

=back

=cut

sub new {
    my ($class) = @_;

    return bless {}, ref $class || $class;
}

=head2 uid

    $UID = $r->uid()

=over

Returns a Unique id for this object, creating one if it didn't have one before

=back

=cut

sub uid {
    $_[0]->{' uid'} || ($_[0]->{' uid'} = $uidc++);
    return $_[0]->{' uid'};
}

=head2 release

    $r->release()

=over

Releases ALL of the memory used by this indirect object, and all of
its component/child objects.  This method is called automatically by
'C<PDF::Builder::Basic::PDF::File-E<gt>release>' (so you don't have to
call it yourself).

B<Note:> it is important that this method get called at some point
prior to the actual destruction of the object.  Internally, PDF files
have an enormous amount of cross-references and this causes circular
references within our own internal data structures.  Calling
'C<release()>' forces these circular references to be cleaned up and
the entire internal data structure purged.

=back

=cut

# Maintainer's Question: Couldn't this be handled by a DESTROY method
# instead of requiring an explicit call to release()?
sub release {
    my ($self) = @_;

    my @tofree = grep { !isweak $_ } values %$self;
    %$self = ();

    # PDFs with highly-interconnected page trees or outlines can hit Perl's
    # recursion limit pretty easily, so disable the warning for this specific
    # loop.
    no warnings 'recursion'; ## no critic

    while (my $item = shift @tofree) {
        # common case: value is not reference
        my $ref = ref($item) || next;

        if      (blessed($item) and $item->can('release')) {
            $item->release();
        } elsif ($ref eq 'ARRAY') {
            push @tofree, @$item;
        } elsif (defined(reftype($ref)) and reftype($ref) eq 'HASH') {
            release($item);
        }
    }
    return;
}

=head2 val

    $value = $r->val()

=over

Returns the value of this object or reads the object and then returns
its value.

Note that all direct subclasses *must* make their own versions of this
subroutine otherwise we could be in for a very deep loop!

=back

=cut

sub val {
    my ($self) = @_;

   # this original code is very confusing. is this a
   # recursive call to this val(), or another? what is
   # supposed to be returned when self->realised is True?
   # perlcritic doesn't like this...
   #$self->{' parent'}->read_obj(@_)->val() 
   #   unless $self->{' realised'}; ## no critic

    if ($self->{' realised'}) {
        return $self->{' realised'}; # return undef in any cases?
    } else {
        return $self->{' parent'}->read_obj(@_)->val();
    }
}

=head2 realise

    $r->realise()

=over

Makes sure that the object is fully read in, etc.

=back

=cut

sub realise {
    my $self = shift();

    return $self if $self->{' realised'}; 
    return $self->{' parent'}->read_obj($self, @_) if $self->{' objnum'};
    return $self;
}

=head2 outobjdeep

    $v = $r->outobjdeep($fh, $pdf)

=over

If you really want to output this object, then you need to read it first.
This also means that all direct subclasses must subclass this method, or they 
will loop forever!

=back

=cut

sub outobjdeep {
    my ($self, $fh, $pdf) = @_;

   # this original code is very confusing. is this a
   # recursive call to this outobjdeep(), or another? what is
   # supposed to be returned when self->realised is True?
   # perlcritic doesn't like the lack of explicit return...
   #$self->{' parent'}->read_obj($self)->outobjdeep($fh, $pdf) 
   #    unless $self->{' realised'}; ## no critic

    if ($self->{' realised'}) {
        return $self->{' realised'};  # return undef in any cases?
    } else {
        return $self->{' parent'}->read_obj($self)->outobjdeep($fh, $pdf);
    }
}

=head2 outobj

    $r->outobj($fh, $pdf)

=over

If this is a full object then outputs a reference to the object, otherwise calls
outobjdeep to output the contents of the object at this point.

=back

=cut

sub outobj {
    my ($self, $fh, $pdf) = @_;

    if (defined $pdf->{' objects'}{$self->uid()}) {
        $fh->printf("%d %d R", @{$pdf->{' objects'}{$self->uid()}}[0..1]);
    } else {
        $self->outobjdeep($fh, $pdf);
    }
    return;
}

=head2 elements

    $s = $r->elements()

=over

Abstract superclass function filler. Returns self here but should return
something more useful if an array.

=back

=cut

sub elements {
    my ($self) = @_;

    if ($self->{' realised'}) {
        return $self;
    } else {
        return $self->{' parent'}->read_obj($self)->elements();
    }
}

=head2 empty

    $s = $r->empty()

=over

Empties all content from this object to free up memory or to be read to pass
the object into the free list. Simplistically undefs all instance variables
other than object number and generation.

=back

=cut

sub empty {
    my ($self) = @_;

    for my $k (keys %$self) {
        undef $self->{$k} unless $inst{$k};
    }

    return $self;
}

=head2 merge

    $o = $r->merge($objind)

=over

This merges content information into an object reference placeholder.
This occurs when an object reference is read before the object definition
and the information in the read data needs to be merged into the object
placeholder.

=back

=cut

sub merge {
    my ($self, $other) = @_;

    for my $k (keys %$other) {
        next if $inst{$k};
        $self->{$k} = $other->{$k};

        # This doesn't seem like the right place to do this, but I haven't
        # yet found all of the places where Parent is being set
        weaken $self->{$k} if $k eq 'Parent';
    }
    $self->{' realised'} = 1;
    return bless $self, ref($other);
}

=head2 is_obj

    $r->is_obj($pdf)

=over

Returns whether this object is a full object with its own object number or
whether it is purely a sub-object. C<$pdf> indicates which output file we are
concerned that the object is an object in.

=back

=cut

sub is_obj {
    return defined $_[1]->{' objects'}{$_[0]->uid()};
}

=head2 copy

    $r->copy($pdf, $res)

=over

Returns a new copy of this object. The object is assumed to be some kind
of associative array and the copy is a deep copy for elements which are
not PDF objects, according to C<$pdf>, and shallow copy for those that are.
Notice that calling C<copy> on an object forces at least a one level
copy even if it is a PDF object. The returned object loses its PDF
object status though.

If C<$res> is defined then the copy goes into that object rather than creating a
new one. It is up to the caller to bless C<$res>, etc. Notice that elements from
C<$self> are not copied into C<$res> if there is already an entry for them 
existing in C<$res>.

=back

=cut

sub copy {
    my ($self, $pdf, $res) = @_;

    unless (defined $res) {
        $res = {};
        bless $res, ref($self);
    }
    foreach my $k (keys %$self) {
        next if $inst{$k};
        next if defined $res->{$k};
        if (blessed($self->{$k}) and $self->{$k}->can('is_obj') and not $self->{$k}->is_obj($pdf)) {
            $res->{$k} = $self->{$k}->copy($pdf);
        } else {
            $res->{$k} = $self->{$k};
        }
    }
    return $res;
}

1;
