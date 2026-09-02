package Logic::Relational::Goal::ConstraintFD;

use v5.38;
use experimental 'signatures';
use parent 'Logic::Relational::Goal';
use Carp qw(croak);
use Logic::Relational::Domain;

=head1 NAME

Logic::Relational::Goal::ConstraintFD - Declarative CLP(FD) arithmetic constraint goal.

=cut

my %OP_CHECK = (
    '#='  => sub ( $l, $r ) { $l == $r },
    '=='  => sub ( $l, $r ) { $l == $r },
    '#/=' => sub ( $l, $r ) { $l != $r },
    '#!=' => sub ( $l, $r ) { $l != $r },
    '#\=' => sub ( $l, $r ) { $l != $r },
    '!='  => sub ( $l, $r ) { $l != $r },
    '#<'  => sub ( $l, $r ) { $l < $r },
    '<'   => sub ( $l, $r ) { $l < $r },
    '#<=' => sub ( $l, $r ) { $l <= $r },
    '#=<' => sub ( $l, $r ) { $l <= $r },
    '<='  => sub ( $l, $r ) { $l <= $r },
    '#>'  => sub ( $l, $r ) { $l > $r },
    '>'   => sub ( $l, $r ) { $l > $r },
    '#>=' => sub ( $l, $r ) { $l >= $r },
    '>='  => sub ( $l, $r ) { $l >= $r },
);

sub _compare ( $op, $left, $right ) {
    my $code = $OP_CHECK{$op} // croak "Unknown CLP(FD) operator: $op";
    return $code->( $left, $right ) ? 1 : 0;
}

sub new ( $class, $op, $vars, $eval_sub ) {
    return bless {
        op       => $op,
        vars     => $vars,    # Arrayref of Logic::Relational::Variable objects
        eval_sub =>
          $eval_sub,    # Closure: sub ($vals_hash) { returns ($left, $right) }
    }, $class;
}

sub expand ( $self, %args ) {
    my $subst     = $args{substitution};
    my $remaining = $args{remaining};
    my $state     = $args{state};

    my $propagator = $self->_make_propagator();
    my $new_subst  = $propagator->($subst);
    if ($new_subst) {
        my $new_state = $state->add_propagator($propagator);
        my $succ      = $new_state->derive(
            substitution => $new_subst,
            goals        => $remaining,
        );
        return $succ // ();
    }

    return ();
}

sub _make_propagator ($self) {
    my @vars     = @{ $self->{vars} };
    my $op       = $self->{op};
    my $eval_sub = $self->{eval_sub};

    return sub ($curr_subst) {
        my %var_states;
        my @unbound_ids;

        for my $var (@vars) {
            my $val = $curr_subst->walk($var);
            my $id =
              ref($var) eq 'Logic::Relational::Variable' ? $var->id : undef;

            if ( ref($val) eq 'Logic::Relational::Variable' ) {
                my $d = $curr_subst->{bindings}{ $val->id };
                if ( ref($d) eq 'Logic::Relational::Domain' ) {
                    $var_states{ $val->id } = { var => $val, domain => $d };
                    push @unbound_ids, $val->id
                      unless grep { $_ eq $val->id } @unbound_ids;
                }
                else {
                    return $curr_subst;
                }
            }
            elsif ( ref($val) eq 'Logic::Relational::Domain' ) {
                croak "Walk returned domain object directly";
            }
        }

        if ( !@unbound_ids ) {
            my %vals_map;
            for my $var (@vars) {
                my $vname =
                  ref($var) eq 'Logic::Relational::Variable'
                  ? $var->name
                  : $var;
                $vname =~ s/^\$//;
                $vals_map{$vname} = $curr_subst->walk($var);
            }
            my ( $left, $right ) = $eval_sub->( \%vals_map );
            return unless _compare( $op, $left, $right );
            return $curr_subst;
        }

        return $curr_subst;
    };
}

sub _prune_unbound_domains ( $unbound_ids_ref, $var_states_ref, $curr_subst,
    $eval_sub, $op, $vars_ref )
{
    for my $target_id (@$unbound_ids_ref) {
        my $target_domain = $var_states_ref->{$target_id}{domain};
        my @valid_vals;

        for my $candidate ( $target_domain->values ) {
            if (
                _is_candidate_feasible(
                    $target_id,      $candidate,  $unbound_ids_ref,
                    $var_states_ref, $curr_subst, $eval_sub,
                    $op,             $vars_ref
                )
              )
            {
                push @valid_vals, $candidate;
            }
        }

        return unless @valid_vals;

        if ( @valid_vals < $target_domain->size ) {
            my %new_set = map { $_ => 1 } @valid_vals;
            my $new_d   = Logic::Relational::Domain->new( \%new_set );
            if ( $new_d->is_bound ) {
                $curr_subst =
                  $curr_subst->bind( $target_id, $new_d->bound_value );
            }
            else {
                $curr_subst = $curr_subst->bind( $target_id, $new_d );
            }
        }
    }

    return $curr_subst;
}

sub _is_candidate_feasible ( $target_id, $candidate, $unbound_ids_ref,
    $var_states_ref, $curr_subst, $eval_sub, $op, $vars_ref )
{
    my @other_ids = grep { $_ ne $target_id } @$unbound_ids_ref;

    my $search;
    $search = sub ( $idx, $assignments ) {
        if ( $idx > $#other_ids ) {
            my %vals_map;
            for my $var (@$vars_ref) {
                my $vname = ref($var) eq 'Logic::Relational::Variable' ? $var->name : $var;
                $vname =~ s/^\$//;
                my $v = $curr_subst->walk($var);
                if ( ref($v) eq 'Logic::Relational::Variable' ) {
                    $vals_map{$vname} = $assignments->{ $v->id };
                }
                else {
                    $vals_map{$vname} = $v;
                }
            }
            my ( $left, $right ) = $eval_sub->( \%vals_map );
            return _compare( $op, $left, $right );
        }

        my $id = $other_ids[$idx];
        my $d  = $var_states_ref->{$id}{domain};
        for my $v ( $d->values ) {
            $assignments->{$id} = $v;
            return 1 if $search->( $idx + 1, $assignments );
        }
        return 0;
    };

    my %initial_assignments = ( $target_id => $candidate );
    return $search->( 0, \%initial_assignments );
}

sub freshen ( $self, $var_map ) {
    require Logic::Relational::DSL;
    my @fresh_vars = map { $_->freshen($var_map) } @{ $self->{vars} };
    return ref($self)->new( $self->{op}, \@fresh_vars, $self->{eval_sub} );
}

sub is_ground ( $self, $subst ) {
    for my $var ( @{ $self->{vars} } ) {
        return 0 unless $self->term_is_ground( $var, $subst );
    }
    return 1;
}

1;
