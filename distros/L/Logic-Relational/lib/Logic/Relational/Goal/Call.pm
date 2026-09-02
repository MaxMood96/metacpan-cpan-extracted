package Logic::Relational::Goal::Call;

use v5.38;
use experimental 'signatures';
use parent 'Logic::Relational::Goal';

=head1 NAME

Logic::Relational::Goal::Call - Goal representing a predicate call.

=cut

sub new ( $class, $name, $args ) {
    return bless { name => $name, args => $args }, $class;
}

sub name  ($self) { return $self->{name}; }
sub args  ($self) { return $self->{args}; }
sub arity ($self) { return scalar @{ $self->{args} }; }

sub as_term ($self) {
    require Logic::Relational::Term;
    return Logic::Relational::Term->new(
        functor => $self->{name},
        args    => $self->{args}
    );
}

use Carp qw(croak);

sub expand ( $self, %args ) {
    my $predicates = $args{predicates} // croak "predicates is required";
    my $generators = $args{generators} // {};
    my $subst      = $args{substitution};
    my $remaining  = $args{remaining};

    my $key = $self->{name} . '/' . $self->arity;

    if ( !exists $predicates->{$key} && !exists $generators->{$key} ) {

        # Check if same name exists with different arity
        my @alts = grep { $_ =~ /^\Q$self->{name}\E\//x }
          ( keys %$predicates, keys %$generators );
        if (@alts) {
            my ( $alt_name, $alt_arity ) = split( '/', $alts[0] );
            croak "Predicate "
              . $self->{name} . "/"
              . $self->arity
              . " is undefined; available predicate is $alt_name/$alt_arity\n";
        }
        croak "Predicate "
          . $self->{name} . "/"
          . $self->arity
          . " is undefined\n";
    }

    require Logic::Relational::Unifier;
    require Logic::Relational::State;

    if ( my $gen_code = $generators->{$key} ) {
        my @reified_args = map { $subst->reify($_) } @{ $self->{args} };
        my $iterator     = $gen_code->(@reified_args);
        croak "Generator $key did not return a coderef iterator"
          unless ref($iterator) eq 'CODE';

        require Logic::Relational::Goal::GeneratorStep;
        my $step_goal = Logic::Relational::Goal::GeneratorStep->new(
            iterator  => $iterator,
            call_args => $self->{args},
            key       => $key,
            arity     => $self->arity,
        );

        my $succ = $args{state}->derive(
            substitution => $subst,
            goals        => [ $step_goal, @$remaining ],
        );
        return $succ // ();
    }

    my $clauses = $predicates->{$key} // [];
    my @successors;

    my $now = time;
    for my $clause (@$clauses) {
        my $meta = $clause->metadata;
        if (   exists $meta->{expires_at}
            && defined $meta->{expires_at}
            && $now >= $meta->{expires_at} )
        {
            next;
        }

        my $fresh_clause = $clause->freshen;
        my $new_subst    = Logic::Relational::Unifier::unify( $self->as_term,
            $fresh_clause->head, $subst );
        if ($new_subst) {
            my $succ = $args{state}->derive(
                substitution => $new_subst,
                goals        => [ $fresh_clause->body, @$remaining ],
            );
            push @successors, $succ if $succ;
        }
    }
    return @successors;
}

sub freshen ( $self, $var_map ) {
    require Logic::Relational::DSL;
    my @fresh_args =
      map { Logic::Relational::DSL::freshen_val( $_, $var_map ) }
      @{ $self->{args} };
    return ref($self)->new( $self->{name}, \@fresh_args );
}

sub is_ground ( $self, $subst ) {
    for my $arg ( @{ $self->{args} } ) {
        return 0 unless $self->term_is_ground( $arg, $subst );
    }
    return 1;
}

1;
