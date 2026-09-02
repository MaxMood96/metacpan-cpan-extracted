package Logic::Relational::Domain;

use v5.38;
use experimental 'signatures';
use Carp qw(croak);

=head1 NAME

Logic::Relational::Domain - Represents a finite domain of allowed integer values.

=cut

sub new ( $class, $args ) {
    my %values;
    if ( exists $args->{min} && exists $args->{max} ) {
        my $min = $args->{min};
        my $max = $args->{max};
        croak "Invalid range: min $min > max $max" if $min > $max;
        for my $i ( $min .. $max ) {
            $values{$i} = 1;
        }
    }
    elsif ( exists $args->{values} ) {
        my $vals = $args->{values};
        croak "values must be an array reference" unless ref($vals) eq 'ARRAY';
        for my $v (@$vals) {
            croak "Domain values must be integers: $v" unless $v =~ /^-?\d+$/x;
            $values{$v} = 1;
        }
    }
    elsif ( ref($args) eq 'HASH' ) {
        %values = %$args;
    }
    else {
        croak "Invalid arguments to Domain->new";
    }

    return bless { values => \%values }, $class;
}

sub values ($self) {
    my @sorted = sort { $a <=> $b } keys %{ $self->{values} };
    return @sorted;
}

sub size ($self) {
    return scalar keys %{ $self->{values} };
}

sub contains ( $self, $val ) {
    return exists $self->{values}{$val} ? 1 : 0;
}

sub is_bound ($self) {
    return $self->size == 1 ? 1 : 0;
}

sub bound_value ($self) {
    return unless $self->is_bound;
    my ($val) = keys %{ $self->{values} };
    return $val;
}

sub intersect ( $self, $other ) {
    my %new_values;
    if ( ref($other) eq 'Logic::Relational::Domain' ) {
        for my $v ( keys %{ $self->{values} } ) {
            if ( exists $other->{values}{$v} ) {
                $new_values{$v} = 1;
            }
        }
    }
    else {
        if ( exists $self->{values}{$other} ) {
            $new_values{$other} = 1;
        }
    }

    return unless keys %new_values;
    return ref($self)->new( \%new_values );
}

sub as_string ($self) {
    my @vals = $self->values;
    if ( @vals > 5 ) {
        return
            "domain("
          . $vals[0] . ".."
          . $vals[-1]
          . ", size="
          . $self->size . ")";
    }
    return "domain(" . join( ",", @vals ) . ")";
}

1;
