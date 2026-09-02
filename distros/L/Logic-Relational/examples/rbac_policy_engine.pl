#!/usr/bin/env perl

use v5.38;
use lib ( '../lib', 'lib' );
use Logic::Relational::Syntax;

# ==============================================================================
# HIERARCHICAL SECURITY & RBAC POLICY ENGINE
# ==============================================================================

logic RBAC {
    # 1. Transitive Team Hierarchy (Child -> Parent -> Grandparent)
    rule team_ancestor($team, $ancestor) {
        team_parent($team, $ancestor);
    }
    rule team_ancestor($team, $ancestor) {
        fresh my $mid;
        team_parent($team, $mid);
        team_ancestor($mid, $ancestor);
    }

    # User in user_team has access to resource_team if resource_team is user_team or a sub-team
    rule user_can_access_team($user, $resource_team) {
        user_in_team($user, $resource_team);
    }
    rule user_can_access_team($user, $resource_team) {
        fresh my $user_team;
        user_in_team($user, $user_team);
        team_ancestor($resource_team, $user_team);
    }

    # 2. Transitive Role Inheritance (Role includes Parent Role)
    rule role_inherits($role, $inherited_role) {
        $role := $inherited_role;
    }
    rule role_inherits($role, $inherited_role) {
        role_includes($role, $inherited_role);
    }
    rule role_inherits($role, $inherited_role) {
        fresh my $mid;
        role_includes($role, $mid);
        role_inherits($mid, $inherited_role);
    }

    # 3. User Role Resolution (Direct user role OR team role)
    rule user_has_role($user, $role) {
        user_role($user, $role);
    }
    rule user_has_role($user, $role) {
        fresh my $team;
        user_in_team($user, $team);
        team_role($team, $role);
    }

    # 4. User Permission Resolution
    rule user_has_permission($user, $perm) {
        fresh my ($base_role, $effective_role);
        user_has_role($user, $base_role);
        role_inherits($base_role, $effective_role);
        role_permits($effective_role, $perm);
    }

    # 5. Security Clearance Resolution
    rule clearance_ok($clearance, $req_clearance) {
        $req_clearance := 'Standard';
    }
    rule clearance_ok($clearance, $req_clearance) {
        $clearance := $req_clearance;
    }
    rule clearance_ok($clearance, $req_clearance) {
        $clearance := 'Top Secret';
    }

    rule user_clearance_or_standard($user, $c) {
        user_clearance($user, $c);
    }
    rule user_clearance_or_standard($user, $c) {
        $c := 'Standard';
    }

    # 6. Policy Rule A: Resource Owner Override
    rule permit_access($user, $action, $doc) {
        doc_owner($doc, $user);
    }

    # 7. Policy Rule B: Organizational RBAC with Security Clearance
    rule permit_access($user, $action, $doc) {
        fresh my ($doc_team, $doc_clearance, $user_clearance);
        doc_team($doc, $doc_team);
        user_can_access_team($user, $doc_team);
        user_has_permission($user, $action);

        doc_clearance($doc, $doc_clearance);
        user_clearance_or_standard($user, $user_clearance);
        clearance_ok($user_clearance, $doc_clearance);
    }
}

# 1. Perl Data Input: Organizational Structure, Roles, Clearances, and Resources
# Note: In Relational Logic (unlike Prolog), constants are standard Perl strings.

my %team_hierarchy = (
    'Frontend Team'    => 'Engineering Dept',
    'Backend Team'     => 'Engineering Dept',
    'Engineering Dept' => 'Tech Division',
    'Tech Division'    => 'ACME Corp',
);

my %user_teams = (
    'Alice Smith'   => 'Frontend Team',
    'Bob Jones'     => 'Backend Team',
    'Charlie Davis' => 'Engineering Dept',
    'Diana Prince'  => 'Tech Division',
    'Eve Adams'     => 'ACME Corp',
);

my %team_roles = (
    'Frontend Team'    => 'Code Contributor',
    'Backend Team'     => 'Code Contributor',
    'Engineering Dept' => 'System Operator',
    'Tech Division'    => 'Tech Lead',
);

my %user_roles = ( 'Eve Adams' => 'Super Admin' );

my %role_includes = (
    'Super Admin'      => 'Admin',
    'Admin'            => 'Editor',
    'Tech Lead'        => 'Editor',
    'System Operator'  => 'Editor',
    'Code Contributor' => 'Viewer',
    'Editor'           => 'Viewer',
);

my %role_permissions = (
    'Viewer'           => ['Read'],
    'Code Contributor' => ['Commit'],
    'Editor'           => [ 'Read',   'Edit' ],
    'System Operator'  => [ 'Deploy', 'Restart' ],
    'Admin'            => [ 'Read',   'Edit', 'Delete' ],
    'Super Admin'      => [ 'Read',   'Edit', 'Delete', 'Purge' ],
);

my %documents = (
    'Project Blueprint #101' => {
        owner     => 'Alice Smith',
        team      => 'Frontend Team',
        clearance => 'Standard'
    },
    'Financial Report #202' => {
        owner     => 'Bob Jones',
        team      => 'Backend Team',
        clearance => 'Confidential'
    },
    'Executive Strategy #303' =>
      { owner => 'Eve Adams', team => 'ACME Corp', clearance => 'Top Secret' },
);

my %user_clearances = (
    'Bob Jones'     => 'Confidential',
    'Charlie Davis' => 'Confidential',
    'Diana Prince'  => 'Confidential',
    'Eve Adams'     => 'Top Secret',
);

# 2. Ingest Data into Logic Engine Facts
for my $c ( keys %team_hierarchy ) {
    $RBAC::PROGRAM->fact( team_parent => $c, $team_hierarchy{$c} );
}
for my $u ( keys %user_teams ) {
    $RBAC::PROGRAM->fact( user_in_team => $u, $user_teams{$u} );
}
for my $t ( keys %team_roles ) {
    $RBAC::PROGRAM->fact( team_role => $t, $team_roles{$t} );
}
for my $u ( keys %user_roles ) {
    $RBAC::PROGRAM->fact( user_role => $u, $user_roles{$u} );
}
for my $r ( keys %role_includes ) {
    $RBAC::PROGRAM->fact( role_includes => $r, $role_includes{$r} );
}
for my $r ( keys %role_permissions ) {
    for my $p ( @{ $role_permissions{$r} } ) {
        $RBAC::PROGRAM->fact( role_permits => $r, $p );
    }
}
for my $doc ( keys %documents ) {
    $RBAC::PROGRAM->fact( doc_owner     => $doc, $documents{$doc}{owner} );
    $RBAC::PROGRAM->fact( doc_team      => $doc, $documents{$doc}{team} );
    $RBAC::PROGRAM->fact( doc_clearance => $doc, $documents{$doc}{clearance} );
}
for my $u ( keys %user_clearances ) {
    $RBAC::PROGRAM->fact( user_clearance => $u, $user_clearances{$u} );
}

say "=" x 65;
say "   HIERARCHICAL SECURITY & RBAC POLICY ENGINE";
say "=" x 65;

# Demo 1: Direct Access Decisions
say "\n--- 1. Individual Access Decisions ---";

my @test_cases = (
    [ 'Alice Smith', 'Edit', 'Project Blueprint #101', 'Alice owns document' ],
    [
        'Charlie Davis',
        'Edit',
        'Project Blueprint #101',
        'Charlie in parent Eng Dept with System Operator role (includes Editor)'
    ],
    [
        'Diana Prince', 'Read',
        'Financial Report #202',
        'Diana in Tech Division with Confidential clearance'
    ],
    [
        'Alice Smith', 'Read',
        'Financial Report #202',
        'Alice lacks Confidential clearance for Report #202'
    ],
    [
        'Bob Jones',
        'Purge',
        'Executive Strategy #303',
        'Bob lacks Super Admin role'
    ],
);

for my $tc (@test_cases) {
    my ( $user, $action, $doc, $reason ) = @$tc;
    query RBAC::permit_access( $user, $action, $doc )->my $q;
    my $res = $q->next ? "PERMITTED" : "DENIED";
    say sprintf(
        "  %-46s -> %-10s (%s)",
        "$user | $action | $doc",
        $res, $reason
    );
}

# Demo 2: Audit Trail Queries (Backtracking over engine)
say
"\n--- 2. Audit Trail: Users Permitted to 'Read' Financial Report #202 (Confidential) ---";
query RBAC::permit_access( fresh my $u1, 'Read', 'Financial Report #202' )
  ->my $q_audit1;
my %seen1;
while ( my $sol = $q_audit1->next ) {
    my $usr = $sol->value($u1);
    next if $seen1{$usr}++;
    say "  [AUDIT MATCH] User '$usr' has Read access to Financial Report #202";
}

say
"\n--- 3. Audit Trail: Users Permitted to 'Purge' Top Secret Executive Strategy #303 ---";
query RBAC::permit_access( fresh my $u2, 'Purge', 'Executive Strategy #303' )
  ->my $q_audit2;
my %seen2;
while ( my $sol = $q_audit2->next ) {
    my $usr = $sol->value($u2);
    next if $seen2{$usr}++;
    say
      "  [AUDIT MATCH] User '$usr' has Purge access to Executive Strategy #303";
}
say "";

