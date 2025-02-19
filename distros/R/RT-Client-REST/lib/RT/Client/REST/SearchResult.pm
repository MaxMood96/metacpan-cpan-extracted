#!perl
# vim: softtabstop=4 tabstop=4 shiftwidth=4 ft=perl expandtab smarttab
# PODNAME: RT::Client::REST::SearchResult
# ABSTRACT: search results object.

use strict;
use warnings;

package RT::Client::REST::SearchResult;
$RT::Client::REST::SearchResult::VERSION = '0.72';
sub new {
    my $class = shift;

    my %opts = @_;

    my $self = bless {}, ref($class) || $class;

    # FIXME: add validation.
    $self->{_object} = $opts{object};
    $self->{_ids}    = $opts{ids} || [];

    return $self;
}

sub count { scalar( @{ shift->{_ids} } ) }

sub _retrieve {
    my ( $self, $obj ) = @_;

    unless ( $obj->autoget ) {
        $obj->retrieve;
    }

    return $obj;
}

sub get_iterator {
    my $self   = shift;
    my @ids    = @{ $self->{_ids} };
    my $object = $self->{_object};

    return sub {
        if (wantarray) {
            my @tomap = @ids;
            @ids = ();

            return map { $self->_retrieve( $object->($_) ) } @tomap;
        }
        elsif (@ids) {
            return $self->_retrieve( $object->( shift(@ids) ) );
        }
        else {
            return;    # This signifies the end of the iterations
        }
    };
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

RT::Client::REST::SearchResult - search results object.

=head1 VERSION

version 0.72

=head1 SYNOPSIS

  my $iterator = $search->get_iterator;
  my $count = $iterator->count;

  while (defined(my $obj = &$iterator)) {
    # do something with the $obj
  }

=head1 DESCRIPTION

This class is a representation of a search result.  This is the type
of the object you get back when you call method C<search()> on
L<RT::Client::REST::Object>-derived objects.  It makes it easy to
iterate over results and find out just how many there are.

=head1 METHODS

=over 4

=item B<count>

Returns the number of search results.  This number will always be the
same unless you stick your fat dirty fingers into the object and abuse
it.  This number is not affected by calls to C<get_iterator()>.

=item B<get_iterator>

Returns a reference to a subroutine which is used to iterate over the
results.

Evaluating it in scalar context, returns the next object
or C<undef> if all the results have already been iterated over.  Note
that for each object to be instantiated with correct values,
B<retrieve()> method is called on the object before returning it
to the caller.

Evaluating the subroutine reference in list context returns a list
of all results fully instantiated.  WARNING: this may be expensive,
as each object is issued B<retrieve()> method.  Subsequent calls to
the iterator result in empty list.

You may safely mix calling the iterator in scalar and list context.  For
example:

  $iterator = $search->get_iterator;

  $first = &$iterator;
  $second = &$iterator;
  @the_rest = &$iterator;

You can get as many iterators as you want -- they will not step on
each other's toes.

=item B<new>

You should not have to call it yourself, but just for the sake of
completeness, here are the arguments:

  my $search = RT::Client::REST::SearchResult->new(
    ids => [1 .. 10],
    object => sub {       # Yup, that's a closure.
      RT::Client::REST::Ticket->new(
        id => shift,
        rt => $rt,
      );
    },
  );

=back

=head1 SEE ALSO

L<RT::Client::REST::Object>, L<RT::Client::REST>.

=head1 AUTHOR

Dean Hamstead <dean@fragfest.com.au>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2023, 2020 by Dmitri Tikhonov.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
