package Telegram::Bot::Object::Base;
$Telegram::Bot::Object::Base::VERSION = '0.027';
# ABSTRACT: The base class for all Telegram::Bot::Object objects.


use Mojo::Base -base;

has '_brain'; # a reference to our brain


sub arrays { qw// }  # override if needed
sub _field_is_array {
  my $self = shift;
  my $field = shift;
  if (grep /^$field$/, $self->arrays) {
    return 1;
  }
  return;
}


sub array_of_arrays { qw// } #override if needed
sub _field_is_array_of_arrays {
  my $self = shift;
  my $field = shift;
  if (grep /^$field$/, $self->array_of_arrays) {
    return 1;
  }
  return;
}


# create an object from a hash. Needs to deal with the nested types, and
# arrays
sub create_from_hash {
  my $class = shift;
  my $hash  = shift;
  my $brain = shift || die "no brain supplied";
  my $obj   = $class->new(_brain => $brain);

  return if ref($hash) ne 'HASH';
  # deal with each type of field
  foreach my $type (keys %{ $class->fields }) {
    my @fields_of_this_type = @{ $class->fields->{$type} };

    foreach my $field (@fields_of_this_type) {

      # ignore fields for which we have no value in the hash
      next if (! defined $hash->{$field} );

      if ($type eq 'scalar') {
        if ($obj->_field_is_array($field)) {
          # simple scalar array ref, so just copy it
          my $val = $hash->{$field};
          # deal with boolean stuff so we don't pollute our object
          # with JSON
          if (ref($val) eq 'JSON::PP::Boolean') {
            $val = !!$val;
          }
          $obj->$field($val);
        }
        elsif ($obj->_field_is_array_of_arrays) {
          die "not yet implemented for scalars";
        }
        else {
          my $val = $hash->{$field};
          if (ref($val) eq 'JSON::PP::Boolean') {
            $val = 0+$val;

          }
          $obj->$field($val);
        }
      }

      else {
        if ($obj->_field_is_array($field)) {
          my @sub_array;
          foreach my $data ( @{ $hash->{$field} } ) {
            push @sub_array, $type->create_from_hash($data, $brain);
          }
          $obj->$field(\@sub_array);
        }
        elsif ($obj->_field_is_array_of_arrays($field)) {
          # Need to skip over this for CallbackQueries (or implement!)
          $obj->$field([]);
          warn "not yet implemented for objects";
        }
        else {
          $obj->$field($type->create_from_hash($hash->{$field}, $brain));
        }

      }
    }
  }

  return $obj;
}


sub as_hashref {
  my $self = shift;
  my $hash = {};

  foreach my $type ( keys %{ $self->fields }) {
    my @fields = @{ $self->fields->{$type} };
    foreach my $field (@fields) {

      # add the simple scalar values
      if ($type eq 'scalar') {

        # TODO support scalar arrays?
        $hash->{$field} = $self->$field
          if defined $self->$field;
      }
      else {
        if ($self->_field_is_array($field)) {

          # skip if it's not defined, though I'm not sure if there are cases
          # where we should be sending an empty array instead?
          next if (! defined $self->$field);

          $hash->{$field} = [
            map { $_->as_hashref } @{ $self->$field }
          ];
        }
        elsif ($self->_field_is_array_of_arrays($field)) {

          next if (! defined $self->$field);

          # lets not nest maps
          my $a_of_a = [];
          foreach my $outer ( @{ $self->$field } ) {
            my $inner = [ map { $_->as_hashref } @$outer ];
            push @$a_of_a, $inner;
          }
          $hash->{$field} = $a_of_a;
        }
        else {

          # non array, non scalar
          if (defined $self->$field) {
            my $hashref = $self->$field->as_hashref;
            $hash->{$field} = $hashref
              unless ! $hashref;
          }
        }
      }
    }
  }
  return $hash;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Telegram::Bot::Object::Base - The base class for all Telegram::Bot::Object objects.

=head1 VERSION

version 0.027

=head1 DESCRIPTION

This class should not be instantiated itself. Instead, instantiate a sub-class.

You should generally not need to instantiate objects of sub-classes of L<Telegram::Bot::Object::Base>,
instead the appropriate objects will be created from an incoming request via
L<Telegram::Bot::Brain>.

You can then use the methods referenced below on those objects.

=head1 METHODS

=head2 arrays

Should be overridden by subclasses, returning an array listing of which fields
for the object are arrays.

=head2 array_of_arrays

Should be overridden by subclasses, returning an array listing od which fields
for the object are arrays of arrays.

=head2 create_from_hash

Create an object of the appropriate class, including any sub-objects of
other types, as needed.

=head2 as_hashref

Return this object as a hashref.

=head1 AUTHORS

=over 4

=item *

Justin Hawkins <justin@eatmorecode.com>

=item *

James Green <jkg@earth.li>

=item *

Julien Fiegehenn <simbabque@cpan.org>

=item *

Jess Robinson <jrobinson@cpan.org>

=item *

Albert Cester <albert.cester@web.de>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2024 by James Green.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
