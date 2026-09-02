#!/usr/bin/env perl

use v5.38;
use lib ( '../lib', 'lib' );
use DBI;
use Logic::Relational::Syntax;

# ==============================================================================
# FEDERATED CROSS-DATABASE JOIN WITH PERL DBI GENERATORS
# Demonstrates cross-database JOINs across two separate, heterogeneous DBI 
# database handles.
#
# Standard SQL Limitations:
# Standard SQL databases (e.g. PostgreSQL vs MySQL vs SQLite) cannot natively
# execute a single SQL 'JOIN' query across two separate DBI connection handles.
#
# Relational Logic Solution:
# By attaching a generator to each distinct DBI connection handle, Relational Logic
# acts as a federated query engine.
# ==============================================================================

my $driver = eval { require DBD::SQLite; 'SQLite' } ? 'SQLite' : 'Mem';

# 1. Setup Database Handle #1: User & Employee Accounts DB
my $dbh_users = DBI->connect( "dbi:$driver:", "", "",
    { RaiseError => 1, AutoCommit => 1, PrintError => 0 } );
$dbh_users->do(
"CREATE TABLE employees (id INT, name VARCHAR(50), dept_code VARCHAR(10), salary INT, title VARCHAR(50))"
);

$dbh_users->do(
"INSERT INTO employees VALUES (101, 'Alice Smith', 'ENG', 95000, 'Principal Architect')"
);
$dbh_users->do(
"INSERT INTO employees VALUES (102, 'Bob Jones', 'ENG', 75000, 'Senior Developer')"
);
$dbh_users->do(
"INSERT INTO employees VALUES (201, 'Charlie Davis', 'RD', 120000, 'Chief Scientist')"
);
$dbh_users->do(
"INSERT INTO employees VALUES (202, 'Diana Prince', 'RD', 110000, 'Research Lead')"
);
$dbh_users->do(
"INSERT INTO employees VALUES (301, 'Eve Adams', 'LOG', 85000, 'Logistics Director')"
);
$dbh_users->do(
"INSERT INTO employees VALUES (401, 'Frank Miller', 'EXEC', 150000, 'VP Operations')"
);

# 2. Setup Database Handle #2: SEPARATE Department & Budget Metadata DB
my $dbh_depts = DBI->connect( "dbi:$driver:", "", "",
    { RaiseError => 1, AutoCommit => 1, PrintError => 0 } );
$dbh_depts->do(
"CREATE TABLE departments (code VARCHAR(10), name VARCHAR(50), location VARCHAR(50), budget INT)"
);

$dbh_depts->do(
"INSERT INTO departments VALUES ('ENG', 'Engineering Dept', 'London', 500000)"
);
$dbh_depts->do(
"INSERT INTO departments VALUES ('RD', 'Research & Development', 'London', 750000)"
);
$dbh_depts->do(
"INSERT INTO departments VALUES ('LOG', 'Global Logistics', 'Paris', 300000)"
);
$dbh_depts->do(
"INSERT INTO departments VALUES ('EXEC', 'Executive Operations', 'New York', 1000000)"
);

# 3. Define Declarative Federated Logic Rules

logic CrossDBRel {
    # Rule A: High Earning Staff (Cross-Database Join + CLP(FD) Constraint)
    rule high_earner_info($emp_name, $dept_name, $location, $salary, $title) {
        fresh my ($emp_id, $dept_code, $budget);
        # Step 1: Stream Employee from Database Handle #1 ($dbh_users)
        db_employee($emp_id, $emp_name, $dept_code, $salary, $title);
        $salary #>= 90000;

        # Step 2: Query Department from SEPARATE Database Handle #2 ($dbh_depts)
        db_department($dept_code, $dept_name, $location, $budget);
    }

    # Rule B: Staff Headcount Audit by Location across Heterogeneous Databases
    rule location_staff_audit($target_loc, $emp_name, $dept_name, $salary, $title) {
        fresh my ($emp_id, $dept_code, $budget, $location);
        db_department($dept_code, $dept_name, $location, $budget);
        $location := $target_loc;
        db_employee($emp_id, $emp_name, $dept_code, $salary, $title);
    }
}

# 4. Register Generators for Each Distinct DBI Handle
# Generator 1: Bound to Database Handle #1 ($dbh_users)
# db_employee(EmpID, EmpName, DeptCode, Salary, Title)
$CrossDBRel::PROGRAM->generator(
    db_employee => 5,
    sub ( $emp_id, $name, $code, $salary, $title ) {
        my $sth = $dbh_users->prepare(
            "SELECT id, name, dept_code, salary, title FROM employees");
        $sth->execute();
        return sub {
            my $row = $sth->fetchrow_hashref // return ();
            return [
                $row->{id},     $row->{name}, $row->{dept_code},
                $row->{salary}, $row->{title}
            ];
        };
    }
);

# Generator 2: Bound to SEPARATE Database Handle #2 ($dbh_depts)
# db_department(DeptCode, DeptName, Location, Budget)
$CrossDBRel::PROGRAM->generator(
    db_department => 4,
    sub ( $code, $name, $loc, $budget ) {
        my $sth;
        if ( defined $code && !ref($code) ) {
            $sth = $dbh_depts->prepare(
"SELECT code, name, location, budget FROM departments WHERE code = ?"
            );
            $sth->execute($code);
        }
        else {
            $sth = $dbh_depts->prepare(
                "SELECT code, name, location, budget FROM departments");
            $sth->execute();
        }
        return sub {
            my $row = $sth->fetchrow_hashref // return ();
            return [
                $row->{code},     $row->{name},
                $row->{location}, $row->{budget}
            ];
        };
    }
);

say "=" x 65;
say "   FEDERATED CROSS-DATABASE JOIN ENGINE (DBD::$driver)";
say "=" x 65;

# Demo 1: Federated Join across Database #1 ($dbh_users) and Database #2 ($dbh_depts)
say "\n--- 1. High Earners (\$90,000+) via Federated Cross-DB Join ---";
query CrossDBRel::high_earner_info(
    fresh my $emp1,
    fresh my $dept1,
    fresh my $loc1,
    fresh my $sal1,
    fresh my $title1
)->my $q1;

while ( my $sol = $q1->next ) {
    say sprintf(
"  [FEDERATED JOIN] %-15s | Dept: %-22s (%s) | Salary: \$%d | Title: %s",
        $sol->value($emp1), $sol->value($dept1), $sol->value($loc1),
        $sol->value($sal1), $sol->value($title1)
    );
}

# Demo 2: Staff Headcount Audit for London Locations
say "\n--- 2. Staff Audit for London Locations (Federated Cross-DB Query) ---";
query CrossDBRel::location_staff_audit(
    'London',
    fresh my $emp2,
    fresh my $dept2,
    fresh my $sal2,
    fresh my $title2
)->my $q2;

while ( my $sol = $q2->next ) {
    say sprintf(
        "  [LONDON STAFF] %-15s | Dept: %-22s | Salary: \$%d | Title: %s",
        $sol->value($emp2), $sol->value($dept2),
        $sol->value($sal2), $sol->value($title2)
    );
}
say "";

