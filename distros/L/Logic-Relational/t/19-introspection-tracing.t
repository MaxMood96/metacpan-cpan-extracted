#!/usr/bin/env perl
use v5.38;
use lib ('../lib', 'lib');
use Test2::V0 '!call';
use Logic::Relational qw(variable call all);
no warnings 'redefine';
no warnings 'prototype';
use Logic::Relational::Program;

# 1. Test clauses_for introspection
my $p = Logic::Relational::Program->new;
$p->fact( parent => 'alice', 'bob' );
$p->fact( parent => 'bob',   'carol' );

my @clauses = $p->clauses_for( 'parent', 2 );
is( scalar(@clauses), 2, 'clauses_for returns 2 clauses' );
is( $clauses[0]->head->arg(1),
    'bob', 'First parent fact has second argument bob' );

# 2. Test Program Change Events
my @events;
$p->on_change(
    sub ($event) {
        push @events, $event;
    }
);

my $c_id = $p->fact( parent => 'david', 'eve' );
is( scalar(@events),        1,        'Change event fired on assert fact' );
is( $events[0]->operation,  'assert', 'Operation is assert' );
is( $events[0]->clause->id, $c_id,    'Clause ID matches asserted ID' );

@events = ();
$p->retract_clause($c_id);
is( scalar(@events),       1,         'Change event fired on retract_clause' );
is( $events[0]->operation, 'retract', 'Operation is retract' );

@events = ();
$p->retract( parent => 'alice', 'bob' );
is( scalar(@events),       1,         'Change event fired on retract pattern' );
is( $events[0]->operation, 'retract', 'Operation is retract' );

# 3. Test Query Tracing
my $p2 = Logic::Relational::Program->new;
$p2->fact( thief => 'badguy' );
$p2->fact( thief => 'villain' );
$p2->fact( owns  => 'alice', 'gold' );
$p2->fact( owns  => 'bob',   'rubies' );

# Rule: steals(X, Y) :- thief(X), owns(Z, Y).
my $x = variable('X');
my $y = variable('Y');
my $z = variable('Z');
$p2->rule(
    head => call( steals => $x, $y ),
    body => all( call( thief => $x ), call( owns => $z, $y ) )
);

my $perp   = variable('perp');
my $target = variable('target');
my $query  = $p2->query( call( steals => $perp, $target ) );

my @trace_events;
$query->trace(
    sub ($event) {
        push @trace_events, $event;
    }
);

my $sol = $query->next;
ok( $sol, 'Query found solution' );

# Verify trace events sequence
my @types = map { $_->type } @trace_events;

my %type_map = map { $_ => 1 } @types;
ok( $type_map{call},     'trace contains call events' );
ok( $type_map{success},  'trace contains success events' );
ok( $type_map{choice},   'trace contains choice events' );
ok( $type_map{solution}, 'trace contains solution events' );

# 4. Test Fail and Backtrack Tracing
my $query_fail =
  $p2->query( all( call( thief => $perp ), call( owns => $perp, 'rubies' ) ) );
my @trace_events2;
$query_fail->trace(
    sub ($event) {
        push @trace_events2, $event;
    }
);

my $sol_fail = $query_fail->next;
ok( !$sol_fail, 'Query failed' );

my @types2    = map { $_->type } @trace_events2;
my %type_map2 = map { $_ => 1 } @types2;
ok( $type_map2{fail},      'trace contains fail events' );
ok( $type_map2{backtrack}, 'trace contains backtrack events' );

done_testing;
