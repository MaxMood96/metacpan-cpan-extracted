package DBIx::Class::Helpers;
$DBIx::Class::Helpers::VERSION = '2.037000';
use strict;
use warnings;

# ABSTRACT: Simplify the common case stuff for DBIx::Class.

1; # this class isn't meant to be used

__END__

=pod

=head1 NAME

DBIx::Class::Helpers - Simplify the common case stuff for DBIx::Class.

=head1 SYNOPSIS

 package MyApp::Schema::Result::Foo_Bar;

 __PACKAGE__->load_components(qw{Helper::JoinTable Core});

 __PACKAGE__->join_table({
    left_class   => 'Foo',
    left_method  => 'foo',
    right_class  => 'Bar',
    right_method => 'bar',
 });

 # define parent class
 package ParentSchema::Result::Bar;

 use strict;
 use warnings;

 use parent 'DBIx::Class';

 __PACKAGE__->load_components('Core');

 __PACKAGE__->table('Bar');

 __PACKAGE__->add_columns(qw/ id foo_id /);

 __PACKAGE__->set_primary_key('id');

 __PACKAGE__->belongs_to( foo => 'ParentSchema::Result::Foo', 'foo_id' );

 # define subclass
 package MySchema::Result::Bar;

 use strict;
 use warnings;

 use parent 'ParentSchema::Result::Bar';

 __PACKAGE__->load_components(qw{Helper::SubClass Core});

 __PACKAGE__->subclass;

=head1 SEE ALSO

L<DBIx::Class::Helper::Row::JoinTable>, L<DBIx::Class::Helper::Row::SubClass>, L<DBIx::Class::Helpers::Util>

=head1 AUTHOR

Arthur Axel "fREW" Schmidt <frioux+cpan@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2024 by Arthur Axel "fREW" Schmidt.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
