package DBIx::Class::Helper::Row::ProxyResultSetMethod;
$DBIx::Class::Helper::Row::ProxyResultSetMethod::VERSION = '2.037000';
# ABSTRACT: Efficiently reuse ResultSet methods from results with fallback

use strict;
use warnings;

use parent 'DBIx::Class::Helper::Row::SelfResultSet', 'DBIx::Class::Row';

use Sub::Name ();

use DBIx::Class::Candy::Exports;

export_methods [qw( proxy_resultset_method )];

__PACKAGE__->mk_group_accessors(inherited => '_proxy_slots');

sub proxy_resultset_method {
   my ($self, $name, $attr) = @_;

   my $rs_method   = $attr->{resultset_method} || "with_$name";
   my $slot        = $attr->{slot} || $name;

   $self->_proxy_slots([]) unless $self->_proxy_slots;
   push @{$self->_proxy_slots}, $slot;

   no strict 'refs';
   my $method = $self . '::' . $name;
   *{$method} = Sub::Name::subname $method, sub {
      my ($self) = @_;
      use strict 'refs';

      unless ($self->has_column_loaded($slot)) {
         # boo.  The accessor checks that there's an actual column defined, so we
         # skip it so we can cache results.
         $self->{_column_data}{$slot} = undef;
         $self->set_column(
            $slot,
            $self->self_rs
               ->search(undef, { columns => [] })
               ->$rs_method
               ->get_column($slot)
               ->next,
         );
      }

      return $self->get_column($slot)
   }
}

sub copy {
   delete local @{$_[0]->{_column_data}}{@{$_[0]->_proxy_slots||[]}};

   shift->next::method(@_);
}

sub update {
   delete local @{$_[0]->{_dirty_columns}}{@{$_[0]->_proxy_slots||[]}};

   shift->next::method(@_);
}

1;

__END__

=pod

=head1 NAME

DBIx::Class::Helper::Row::ProxyResultSetMethod - Efficiently reuse ResultSet methods from results with fallback

=head1 SYNOPSIS

ResultSet:

 package MyApp::Schema::ResultSet::Foo;

 use parent 'DBIx::Class::ResultSet';

 __PACKAGE__->load_components(qw(
    Helper::ResultSet::CorrelateRelationship
 ));

 ...;

 sub with_friend_count {
    shift->search(undef, {
       '+columns' => {
          'friend_count' => $self->correlate('friends')->count_rs->as_query,
       },
    })
 }

Result:

 package MyApp::Schema::Result::Foo;

 use parent 'DBIx::Class::Core';

 __PACKAGE__->load_components(qw( Helper::Row::ProxyResultSetMethod ));

 __PACKAGE__->proxy_resultset_method('friend_count');

or with L<DBIx::Class::Candy>:

 package MyApp::Schema::Result::Foo;

 use DBIx::Class::Candy -components => ['Helper::Row::ProxyResultSetMethod'];

 proxy_resultset_method 'friend_count';

Elsewhere:

 my $row = $foo_rs->first;
 say $row->friend_count . ' friends';

=head1 DESCRIPTION

This module makes reusing resultset methods from a result trivially easy.  You
should be using it.

=head1 METHODS

=head2 proxy_resultset_method

 __PACKAGE__->proxy_resultset_method( $name => {
    slot             => $slot,
    resultset_method => $rs_method
 });

C<proxy_resultset_method>'s first argument is the name of the method to
generate and is required.  The other two arguments, C<$slot>, and
C<$resultset_method> are optional.  If unspecified C<$slot> will default to
C<$name> and C<$resultset_method> will default to C<"with_$name">.  C<$slot>
is the column that the data being retrieved is stored as in the ResultSet
method being proxied to.  C<$resultset_method> is (duh) the ResultSet method
being proxied to.

If you did not call the C<with_*> method on your ResultSet, and call the
proxy method, it will transparently B<fallback> and do the call and fetch
the needed data. E.g.:

 my $foo = $schema->resultset('Foo')->first; ## did not call with_friend_count
 print $foo->friend_count; ## will produce desired result magically

=head1 CANDY EXPORTS

If used in conjunction with L<DBIx::Class::Candy> this component will export:

=over

=item proxy_resultset_method

=back

=head1 DEDICATION

This module is dedicated to Ray Bradbury, who wrote Something Wicked This Way
Comes, Dandelion Wine, and numerous short stories, plays, etc etc.  Read this
author's books.

=head1 AUTHOR

Arthur Axel "fREW" Schmidt <frioux+cpan@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2024 by Arthur Axel "fREW" Schmidt.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
