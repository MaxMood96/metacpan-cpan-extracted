package Uniform::Exceptions;

use strict;
use warnings;
use overload '""' => \&to_string; # Automatically stringifies when printed or used in regex

our $VERSION = '1.02';

# Class Factory Constructor
sub throw {
    my ($class, %args) = @_;

    my $self = {
        message    => $args{message}    || 'An unhandled framework exception occurred',
        type       => $args{type}       || 'Generic',
        attribute  => $args{attribute}  || undef,
        trace      => [ caller(1) ], # Captures the exact line of code that triggered the failure
    };

    bless $self, $class;
    die $self; # Throws the object reference immediately
}

# Accessor methods
sub message   { $_[0]->{message} }
sub type      { $_[0]->{type} }
sub attribute { $_[0]->{attribute} }
sub line      { $_[0]->{trace}->[2] }
sub file      { $_[0]->{trace}->[1] }

# Stringification string conversion layout
sub to_string {
    my ($self) = @_;
    my $str = sprintf "[Uniform::Exception::%s] %s", $self->type, $self->message;
    if (defined $self->attribute) {
        $str .= sprintf " (failed on attribute: '%s')", $self->attribute;
    }
    $str .= sprintf " at %s line %d.\n", $self->file, $self->line;
    return $str;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Uniform::Exceptions - Standardized object-oriented error platform for the Uniform ecosystem

=head1 SYNOPSIS

    use Uniform::Exceptions;

    # Throw a structured validation error
    Uniform::Exceptions->throw(
        type      => 'ValidationError',
        message   => 'Header argument must be a HASH reference',
        attribute => $input_data,
    );

=head1 DESCRIPTION

C<Uniform::Exceptions> provides unified, object-oriented error handling across all
distributions in the C<Uniform::*> framework stack. Instead of utilizing plain strings,
it bundles rich context tracking elements (file paths, lines, and bad parameters)
into structured exception payloads.

=cut
