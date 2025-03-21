package Poz::Types::object;
use 5.032;
use strict;
use warnings;
use Carp ();
use Try::Tiny;
use parent 'Poz::Types';

sub new {
    my ($class, $struct) = @_;
    my $self = bless {
        __struct__ => {},
        __as__     => undef,
        __is__     => undef,
    }, $class;
    for my $key (keys %$struct) {
        my $v = $struct->{$key};
        if ($v->isa('Poz::Types')) {
            $self->{__struct__}{$key} = $v;
        }
    }
    return $self;
}

sub as {
    my ($self, $typename) = @_;
    $self->{__as__} = $typename;
    return $self;
}

sub is {
    my ($self, $typename) = @_;
    $self->{__is__} = $typename;
    return $self;
}

sub constructor {
    my ($self) = @_;
    my $caller_class = caller();
    no strict 'refs';
    *{"$caller_class\::new"} = sub {
        my ($class, %args) = @_;
        return $self
            ->as($caller_class)
            ->parse({%args});
    }
}

sub parse {
    my ($self, $data) = @_;
    my ($valid, $errors) = $self->safe_parse($data);
    if ($errors) {
        my $error_message = _errors_to_string($errors);
        Carp::croak($error_message);
    }
    return $valid;
}

sub safe_parse {
    Carp::croak "Must handle error" unless wantarray;

    my ($self, $data) = @_;
    my @errors = ();
    my $valid = {};
    if (!_is_hashref_or_object($data)) {
        push @errors, {
            key   => '(root)',
            error => "Invalid data: is not hashref"
        };
    } else {
        if ($self->{__is__}) {
            my $is = $self->{__is__};
            if (!$data->isa($is)) {
                push @errors, {
                    key   => '(root)',
                    error => "Invalid data: is not $is"
                };
            }
        }
        for my $key (sort keys %{$self->{__struct__}}) {
            my $v = $self->{__struct__}{$key};
            my $val = $data->{$key};
            
            # if the value is not defined, try to transform it
            if (!defined $val && scalar(@{$v->{transform}}) > 0) {
                for my $transformer (@{$v->{transform}}) {
                    $val = $transformer->($v, $val);
                }
            }

            try {
                my $_parsed = $v->parse($val);
                $valid->{$key} = $_parsed;
            } catch {
                my $error_message = $_;
                $error_message =~ s/ at .+ line [0-9]+\.\n//;
                push @errors, {
                    key   => $key,
                    error => $error_message,
                };
            };
        }
    }
    if (scalar(@errors) > 0) {
        return (undef, [@errors])
    }
    my $classname = $self->{__as__} || $self->{__is__};
    $valid = bless $valid, $classname if $classname;
    return ($valid, undef);
}

sub _is_hashref_or_object {
    my $data = shift;
    return defined $data && (ref($data) eq 'HASH' || $data->isa('HASH'));
}

sub _errors_to_string {
    my $errors = shift;
    my @error_strings = ();
    for my $error (@$errors) {
        push @error_strings, sprintf("%s on key `%s`", $error->{error}, $error->{key});
    }
    return join(", and ", @error_strings);
}

1;

=head1 NAME

Poz::Types::object - A module for handling structured data with type validation

=head1 SYNOPSIS

    use Poz qw/z/;

    # Schema for a person, cast to Some::Class when valid
    my $object = z->object({
        name => z->string,
        age => z->number,
    })->as('Some::Class');
    my $data = {
        name => 'John Doe',
        age => 30,
    };
    my $parsed_data = $object->parse($data); # isa Some::Class

    # Schema for a person, validate that the data is an instance of Some::Class
    my $another_object = z->object({
        name => z->string,
        age => z->number,
    })->is('Another::Class');
    my $other = bless {
        name => 'John Doe',
        age => 30,
    }, 'Another::Class';
    my $someone = bless {
        name => 'Jane Doe',
        age => 25,
    }, 'Some::Class';
    my $parsed_data = $another_object->parse($other); # isa Another::Class
    my $someone_else = $another_object->parse($someone); # throws an exception, because not an instance of Another::Class

    # or use Poz as your class constructor
    {
        package My::Class;
        use Poz qw/z/;
        z->object({
            name => z->string,
            age => z->number,
        })->constructor;
    }
    my $instance = My::Class->new(
        name => 'Alice',
        age => 20,
    );


=head1 DESCRIPTION

Poz::Types::object is a module for handling structured data with type validation. It allows you to define a structure with specific types and validate data against this structure.

=head1 METHODS

=head2 as

    $object->as($typename);

Sets the class name to bless the parsed data into. The C<$typename> parameter should be a string representing the class name.

=head2 is

    $object->is($typename);

Validates that the parsed data is an instance of the given class. The C<$typename> parameter should be a string representing the class name.

=head2 constructor

    $object->constructor;

Creates a constructor method into your class.

=head2 parse

    my $parsed_data = $object->parse($data);

Parses and validates the given data against the structure. If the data is valid, it returns the parsed data. If the data is invalid, it throws an exception with the validation errors.

=head2 safe_parse

    my ($valid, $errors) = $object->safe_parse($data);

Parses and validates the given data against the structure. If the data is valid, it returns the parsed data and undef for errors. If the data is invalid, it returns undef for valid data and an array reference of errors.

=head1 LICENSE

Copyright (C) ytnobody.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

ytnobody E<lt>ytnobody@gmail.comE<gt>

=cut
