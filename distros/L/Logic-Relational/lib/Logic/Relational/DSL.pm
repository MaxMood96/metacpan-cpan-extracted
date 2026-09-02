package Logic::Relational::DSL;

use v5.38;
use experimental 'signatures';

=head1 NAME

Logic::Relational::DSL - Domain Specific Language helpers for relational logic.

=head1 SYNOPSIS

    use Logic::Relational::DSL qw(variable call all not_goal);
    my $perp = variable('perp');

=head1 DESCRIPTION

C<Logic::Relational::DSL> exports functional constructor helpers to build
terms, variables, goals, and run unification directly in standard Perl.

=cut

our @EXPORT_OK = qw(
  variable
  atom
  term
  unify
  call
  all
  any_goal
  not_goal
  unify_goal
  true_goal
  fail_goal
  guard
  rest
  slurp
  freshen_val
  in_domain
  all_different
  label
  is_goal
  identical
  constraint_fd
  save_snapshot
  load_snapshot
);
use parent 'Exporter';

sub import ( $class, @args ) {
    no warnings 'prototype', 'redefine';
    return $class->export_to_level( 1, $class, @args );
}

require Logic::Relational::Variable;
require Logic::Relational::Atom;
require Logic::Relational::Term;
require Logic::Relational::Unifier;
require Logic::Relational::Goal::True;
require Logic::Relational::Goal::Fail;
require Logic::Relational::Goal::Unify;
require Logic::Relational::Goal::Call;
require Logic::Relational::Goal::All;
require Logic::Relational::Goal::Any;
require Logic::Relational::Goal::Not;
require Logic::Relational::Goal::Guard;
require Logic::Relational::Goal::Is;
require Logic::Relational::Goal::Identical;
require Logic::Relational::Goal::Domain;
require Logic::Relational::Goal::ConstraintFD;
require Logic::Relational::Goal::AllDifferent;
require Logic::Relational::Goal::Label;

sub variable ($name) {
    return Logic::Relational::Variable->new( name => $name );
}

sub atom ($value) {
    return Logic::Relational::Atom->new($value);
}

sub term ( $functor, @args ) {
    return Logic::Relational::Term->new( functor => $functor, args => \@args );
}

sub unify ( $left, $right, $subst = undef ) {
    if ( !$subst ) {
        require Logic::Relational::Substitution;
        $subst = Logic::Relational::Substitution->new;
    }
    return Logic::Relational::Unifier::unify( $left, $right, $subst );
}

sub call ( $name, @args ) {
    return Logic::Relational::Goal::Call->new( $name, \@args );
}

sub all (@goals) {
    return Logic::Relational::Goal::All->new( \@goals );
}

sub any_goal (@goals) {
    return Logic::Relational::Goal::Any->new( \@goals );
}

sub not_goal ($goal) {
    return Logic::Relational::Goal::Not->new($goal);
}

sub unify_goal ( $left, $right ) {
    return Logic::Relational::Goal::Unify->new( $left, $right );
}

sub true_goal () {
    return Logic::Relational::Goal::True->new;
}

sub fail_goal () {
    return Logic::Relational::Goal::Fail->new;
}

sub guard ( $vars, $code ) {
    return Logic::Relational::Goal::Guard->new( $vars, $code );
}

sub rest ($term) {
    require Logic::Relational::ArrayRest;
    return Logic::Relational::ArrayRest->new($term);
}

sub slurp ($term) {
    require Logic::Relational::ArrayRest;
    return Logic::Relational::ArrayRest->new($term);
}

use builtin 'blessed';
no warnings 'experimental::builtin';

sub freshen_val ( $val, $var_map ) {
    if ( ref($val) eq 'ARRAY' ) {    ## no critic (ProhibitCascadingIfElse)
        return [ map { freshen_val( $_, $var_map ) } @$val ];
    }
    elsif ( ref($val) eq 'HASH' ) {
        my %fresh_hash;
        for my $k ( keys %$val ) {
            $fresh_hash{$k} = freshen_val( $val->{$k}, $var_map );
        }
        return \%fresh_hash;
    }
    elsif ( ref($val) eq 'Logic::Relational::ArrayRest' ) {
        return ref($val)->new( freshen_val( $val->term, $var_map ) );
    }
    elsif ( blessed($val) && $val->can('freshen') ) {
        return $val->freshen($var_map);
    }
    return $val;
}

sub in_domain ( $var, $min, $max ) {
    return Logic::Relational::Goal::Domain->new( $var, $min, $max );
}

sub all_different (@vars) {
    if ( @vars == 1 && ref( $vars[0] ) eq 'ARRAY' ) {
        return Logic::Relational::Goal::AllDifferent->new( $vars[0] );
    }
    return Logic::Relational::Goal::AllDifferent->new( \@vars );
}

sub label (@vars) {
    if ( @vars == 1 && ref( $vars[0] ) eq 'ARRAY' ) {
        return Logic::Relational::Goal::Label->new( $vars[0] );
    }
    return Logic::Relational::Goal::Label->new( \@vars );
}

sub is_goal ( $target_var, $vars, $code ) {
    return Logic::Relational::Goal::Is->new( $target_var, $vars, $code );
}

sub identical ( $t1, $t2 ) {
    return Logic::Relational::Goal::Identical->new( $t1, $t2 );
}

sub constraint_fd ( $op, $vars, $eval_sub ) {
    return Logic::Relational::Goal::ConstraintFD->new( $op, $vars, $eval_sub );
}

sub save_snapshot ( $arg1, @rest ) {
    if ( blessed($arg1)
        && $arg1->isa('Logic::Relational::Program') )
    {
        return $arg1->save_snapshot(@rest);
    }

    my ($caller_pkg) = caller;
    no strict 'refs';    ## no critic (TestingAndDebugging::ProhibitNoStrict)
    my $prog = ${"${caller_pkg}::PROGRAM"} // $main::PROGRAM;
    Carp::croak "No active \$PROGRAM object found for save_snapshot"
      unless $prog;
    return $prog->save_snapshot( $arg1, @rest );
}

sub load_snapshot ( $arg1, @rest ) {
    if ( blessed($arg1)
        && $arg1->isa('Logic::Relational::Program') )
    {
        return $arg1->load_snapshot(@rest);
    }

    my ($caller_pkg) = caller;
    no strict 'refs';    ## no critic (TestingAndDebugging::ProhibitNoStrict)
    my $prog = ${"${caller_pkg}::PROGRAM"} // $main::PROGRAM;
    Carp::croak "No active \$PROGRAM object found for load_snapshot"
      unless $prog;
    return $prog->load_snapshot( $arg1, @rest );
}

1;
