use strict;
use warnings;
package Rubric::EntryTag 0.157;
# ABSTRACT: a tag on an entry

use String::TagString;

#pod =head1 DESCRIPTION
#pod
#pod This class provides an interface to tags on Rubric entries.  It inherits from
#pod Rubric::DBI, which is a Class::DBI class.
#pod
#pod =cut

use base qw(Rubric::DBI);

__PACKAGE__->table('entrytags');

#pod =head1 COLUMNS
#pod
#pod  id        - a unique identifier
#pod  entry     - the tagged entry
#pod  tag       - the tag itself
#pod  tag_value - the value of the tag (for tags in "tag:value" form)
#pod
#pod =cut

__PACKAGE__->columns(All => qw(id entry tag tag_value));

#pod =head1 RELATIONSHIPS
#pod
#pod =head2 entry
#pod
#pod The entry attribute returns a Rubric::Entry.
#pod
#pod =cut

__PACKAGE__->has_a(entry => 'Rubric::Entry');

#pod =head1 TRIGGERS
#pod
#pod =cut

__PACKAGE__->add_trigger(before_create => \&_nullify_values);
__PACKAGE__->add_trigger(before_update => \&_nullify_values);

sub _nullify_values {
	my $self = shift;
  $self->tag_value(undef)
    unless defined $self->{tag_value} and length $self->{tag_value};
}

#pod =head1 METHODS
#pod
#pod =head2 related_tags(\@tags)
#pod
#pod This method returns a reference to an array of tags related to all the given
#pod tags.  Tags are related if they occur together on entries.  
#pod
#pod =cut

sub related_tags {
	my ($self, $tags) = @_;
	return unless $tags and my @tags = @$tags;

  # or maybe we should throw an exception? -- rjbs, 2006-02-13
  return [] if grep { $_ eq '@private' } @tags;

	my $query = q|
	SELECT DISTINCT tag FROM entrytags
	WHERE
    tag NOT IN (| . join(',',map { $self->db_Main->quote($_) } @tags) . q|)
    AND tag NOT LIKE '@%'
	  AND | .
		join ' AND ',
      map { "entry IN (SELECT entry FROM entrytags WHERE tag=$_)" }
      map { $self->db_Main->quote($_) }
      @tags;

	$self->db_Main->selectcol_arrayref($query, undef);
}

#pod =head3 related_tags_counted(\@tags)
#pod
#pod This is the obvious conjunction of C<related_tags> and C<tags_counted>.  It
#pod returns an arrayref of arrayrefs, each a pair of tag/occurance values.
#pod
#pod =cut

sub related_tags_counted {
	my ($self, $tags) = @_;
  return unless $tags;
  $tags = [ keys %$tags ] if ref $tags eq 'HASH';
	return unless my @tags = @$tags;

  # or maybe we should throw an exception? -- rjbs, 2006-02-13
  return [] if grep { $_ eq '@private' } @tags;

	my $query = q|
		SELECT DISTINCT tag, COUNT(*) AS count
		FROM entrytags
		WHERE tag NOT IN (|
      . join(',',map { $self->db_Main->quote($_) } @tags) . q|)
		AND tag NOT LIKE '@%'
    AND | .
		join ' AND ',
		map { "entry IN (SELECT entry FROM entrytags WHERE tag=$_)" }
		map { $self->db_Main->quote($_) }
		@tags;

	$query .= " GROUP BY tag";

	$self->db_Main->selectall_arrayref($query, undef);
}

#pod =head2 stringify_self
#pod
#pod =cut

sub stringify_self {
  my ($self) = @_;
  String::TagString->string_from_tags({
    $self->tag => $self->tag_value
  });
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Rubric::EntryTag - a tag on an entry

=head1 VERSION

version 0.157

=head1 DESCRIPTION

This class provides an interface to tags on Rubric entries.  It inherits from
Rubric::DBI, which is a Class::DBI class.

=head1 PERL VERSION

This code is effectively abandonware.  Although releases will sometimes be made
to update contact info or to fix packaging flaws, bug reports will mostly be
ignored.  Feature requests are even more likely to be ignored.  (If someone
takes up maintenance of this code, they will presumably remove this notice.)
This means that whatever version of perl is currently required is unlikely to
change -- but also that it might change at any new maintainer's whim.

=head1 COLUMNS

 id        - a unique identifier
 entry     - the tagged entry
 tag       - the tag itself
 tag_value - the value of the tag (for tags in "tag:value" form)

=head1 RELATIONSHIPS

=head2 entry

The entry attribute returns a Rubric::Entry.

=head1 TRIGGERS

=head1 METHODS

=head2 related_tags(\@tags)

This method returns a reference to an array of tags related to all the given
tags.  Tags are related if they occur together on entries.  

=head3 related_tags_counted(\@tags)

This is the obvious conjunction of C<related_tags> and C<tags_counted>.  It
returns an arrayref of arrayrefs, each a pair of tag/occurance values.

=head2 stringify_self

=head1 AUTHOR

Ricardo SIGNES <rjbs@semiotic.systems>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2004 by Ricardo SIGNES.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
