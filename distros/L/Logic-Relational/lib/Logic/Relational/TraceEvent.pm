package Logic::Relational::TraceEvent;

use v5.38;
use experimental 'signatures';
use Carp qw(croak);

=head1 NAME

Logic::Relational::TraceEvent - Event dispatched during query execution tracing.

=head1 SYNOPSIS

    my $event = Logic::Relational::TraceEvent->new(
        type         => 'call',
        goal         => $goal,
        substitution => $subst
    );

=cut

sub new ( $class, %args ) {
    my $type  = $args{type} // croak "type is required";
    my $goal  = $args{goal};
    my $subst = $args{substitution} // croak "substitution is required";

    return bless {
        type         => $type,
        goal         => $goal,
        substitution => $subst
    }, $class;
}

sub type ($self) {
    return $self->{type};
}

sub goal ($self) {
    return $self->{goal};
}

sub substitution ($self) {
    return $self->{substitution};
}

1;
