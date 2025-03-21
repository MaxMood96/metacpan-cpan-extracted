use strict;
use warnings;
package Data::InputMonster 0.011;
# ABSTRACT: consume data from multiple sources, best first; om nom nom!

#pod =head1 DESCRIPTION
#pod
#pod This module lets you describe a bunch of input fields you expect.  For each
#pod field, you can specify validation, a default, and multiple places to look for a
#pod value.  The first valid value found is accepted and returned in the results.
#pod
#pod =cut

use Carp ();

#pod =method new
#pod
#pod   my $monster = Data::InputMonster->new({
#pod     fields => {
#pod       field_name => \%field_spec,
#pod       ...
#pod     },
#pod   });
#pod
#pod This builds a new monster.  For more information on the C<%field_spec>
#pod parameters, see below.
#pod
#pod =cut

sub new {
  my ($class, $arg) = @_;
  
  Carp::confess("illegal parameters to Data::InputMonster constructor")
    unless $arg and (keys %$arg == 1) and exists $arg->{fields};

  my $fields = $arg->{fields};

  $class->_assert_field_spec_ok($_) for values %$fields;

  bless { fields => $fields } => $class;
}

sub _assert_field_spec_ok {
  my ($self, $spec) = @_;

  Carp::confess("illegal or missing sources")
    unless $spec->{sources} and ref $spec->{sources} eq 'ARRAY';

  Carp::confess("if given, filter must be a coderef")
    if $spec->{filter} and ref $spec->{filter} ne 'CODE';

  Carp::confess("if given, check must be a coderef")
    if $spec->{check} and ref $spec->{check} ne 'CODE';

  Carp::confess("if given, store must be a coderef")
    if $spec->{store} and ref $spec->{store} ne 'CODE';

  Carp::confess("defaults that are references must be wrapped in code")
    if ((ref $spec->{default})||'CODE') ne 'CODE';
}

#pod =method consume
#pod
#pod   my $result = $monster->consume($input, \%arg);
#pod
#pod This method processes the given input and returns a hashref of the finally
#pod accepted values.  C<$input> can be anything; it is up to the field definitions
#pod to expect and handle the data you plan to feed the monster.
#pod
#pod Valid arguments are:
#pod
#pod   no_default_for - a field name or arrayref of field names for which to NOT
#pod                    fall back to default values
#pod
#pod =cut

sub consume {
  my ($self, $input, $arg) = @_;
  $arg ||= {};

  my %no_default_for
    = (! $arg->{no_default_for})   ? ()
    : (ref $arg->{no_default_for}) ? (map {$_=>1} @{$arg->{no_default_for}})
    : ($arg->{no_default_for} => 1);

  my $field  = $self->{fields};
  my %output;

  FIELD: for my $field_name (keys %$field) {
    my $spec = $field->{$field_name};

    my $checker = $spec->{check};
    my $filter  = $spec->{filter};
    my $storer  = $spec->{store};

    my @sources = @{ $spec->{sources} };

    if (ref $sources[0]) {
      my $i = 1;
      @sources = map { ("source_" . $i++) => $_ } @sources;
    }

    my $input_arg = { field_name => $field_name };

    SOURCE: for (my $i = 0; $i < @sources; $i += 2) {
      my ($name, $getter) = @sources[ $i, $i + 1 ];
      my $value = $getter->($self, $input, $input_arg);
      next unless defined $value;
      if ($filter)  { $filter->()  for $value; }
      if ($checker) { $checker->() or next SOURCE for $value; }
      
      $output{ $field_name } = $value;
      if ($storer) {
        $storer->(
          $self,
          {
            input  => $input,
            source => $name,
            value  => $value,
            field_name => $field_name,
          },
        );
      }

      next FIELD;
    }

    my $default = $no_default_for{ $field_name } ? undef : $spec->{default};
    $output{ $field_name } = ref $default ? $default->() : $default;
  }

  return \%output;
}

#pod =head1 FIELD DEFINITIONS
#pod
#pod Each field is defined by a hashref with the following entries:
#pod
#pod   sources - an arrayref of sources; see below; required
#pod   filter  - a coderef to preprocess candidate values
#pod   check   - a coderef to validate candidate values
#pod   store   - a coderef to store accepted values
#pod   default - a value to use if no source provides an acceptable value
#pod
#pod Sources may be given in one of two formats:
#pod
#pod   [ source_name => $source, ... ]
#pod   [ $source_1, $source_2, ... ]
#pod
#pod In the second form, sources will be assigned unique names.
#pod
#pod The source value is a coderef which, handed the C<$input> argument to the
#pod C<consume> method, returns a candidate value (or undef).  It is also handed a
#pod hashref of relevant information, most importantly C<field_name>.
#pod
#pod A filter is a coderef that works by altering C<$_>.
#pod
#pod If given, check must be a coderef that inspects C<$_> and returns a true if the
#pod value is acceptable.
#pod
#pod Store is called if a value is accepted.  It is passed the monster and a hashref
#pod with the following entries:
#pod
#pod   value  - the value accepted
#pod   source - the name of the source from which the value was accepted
#pod   input  - the input given to the consume method
#pod   field_name - the field name
#pod
#pod If default is given, it must be a simple scalar (in which case that is the
#pod default) or a coderef that will be called to provide a default value as needed.
#pod
#pod =cut

"OM NOM NOM I EAT DATA";

__END__

=pod

=encoding UTF-8

=head1 NAME

Data::InputMonster - consume data from multiple sources, best first; om nom nom!

=head1 VERSION

version 0.011

=head1 DESCRIPTION

This module lets you describe a bunch of input fields you expect.  For each
field, you can specify validation, a default, and multiple places to look for a
value.  The first valid value found is accepted and returned in the results.

=head1 PERL VERSION SUPPORT

This code is effectively abandonware.  Although releases will sometimes be made
to update contact info or to fix packaging flaws, bug reports will mostly be
ignored.  Feature requests are even more likely to be ignored.  (If someone
takes up maintenance of this code, they will presumably remove this notice.)

=head1 METHODS

=head2 new

  my $monster = Data::InputMonster->new({
    fields => {
      field_name => \%field_spec,
      ...
    },
  });

This builds a new monster.  For more information on the C<%field_spec>
parameters, see below.

=head2 consume

  my $result = $monster->consume($input, \%arg);

This method processes the given input and returns a hashref of the finally
accepted values.  C<$input> can be anything; it is up to the field definitions
to expect and handle the data you plan to feed the monster.

Valid arguments are:

  no_default_for - a field name or arrayref of field names for which to NOT
                   fall back to default values

=head1 FIELD DEFINITIONS

Each field is defined by a hashref with the following entries:

  sources - an arrayref of sources; see below; required
  filter  - a coderef to preprocess candidate values
  check   - a coderef to validate candidate values
  store   - a coderef to store accepted values
  default - a value to use if no source provides an acceptable value

Sources may be given in one of two formats:

  [ source_name => $source, ... ]
  [ $source_1, $source_2, ... ]

In the second form, sources will be assigned unique names.

The source value is a coderef which, handed the C<$input> argument to the
C<consume> method, returns a candidate value (or undef).  It is also handed a
hashref of relevant information, most importantly C<field_name>.

A filter is a coderef that works by altering C<$_>.

If given, check must be a coderef that inspects C<$_> and returns a true if the
value is acceptable.

Store is called if a value is accepted.  It is passed the monster and a hashref
with the following entries:

  value  - the value accepted
  source - the name of the source from which the value was accepted
  input  - the input given to the consume method
  field_name - the field name

If default is given, it must be a simple scalar (in which case that is the
default) or a coderef that will be called to provide a default value as needed.

=head1 AUTHOR

Ricardo SIGNES <rjbs@semiotic.systems>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2021 by Ricardo SIGNES.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
