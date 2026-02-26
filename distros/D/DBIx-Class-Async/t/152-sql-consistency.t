#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Deep;
use File::Temp;

use lib 't/lib';

use IO::Async::Loop;
use DBIx::Class::Async::Schema;

my $loop = IO::Async::Loop->new;
my ($fh, $db_file) = File::Temp::tempfile(UNLINK => 1);

my $schema = DBIx::Class::Async::Schema->connect(
    "dbi:SQLite:dbname=$db_file", undef, undef, {},
    {
        workers      => 2,
        schema_class => 'TestSchema',
        async_loop   => $loop,
        cache_ttl    => 60,
    },
);

ok($schema, 'Schema created successfully');

$schema->await($schema->deploy({ add_drop_table => 1 }));

subtest 'SQL consistency with default columns' => sub {
    my %seen_sqls;
    my $iterations = 10;

    for my $i (1..$iterations) {
        my $rs = $schema->resultset('User')->search({});
        my $query = $rs->as_query;
        my $sql = normalise_sql(extract_sql($query));
        $seen_sqls{$sql}++;
    }

    is(scalar keys %seen_sqls, 1,
        'Default column query generates consistent SQL across all iterations');

    my ($sql) = keys %seen_sqls;
    like($sql, qr/SELECT .+ FROM users/,
        'SQL contains expected SELECT FROM structure');

    my $columns = extract_columns($sql);
    ok(length($columns) > 0, 'SQL contains column list');
};

subtest 'SQL consistency with explicit columns' => sub {
    my %seen_sqls;
    my $iterations = 10;
    my @explicit_cols = qw/id name email age active settings balance/;

    for my $i (1..$iterations) {
        my $rs = $schema->resultset('User')->search({}, {
            columns => \@explicit_cols
        });
        my $query = $rs->as_query;
        my $sql = normalise_sql(extract_sql($query));
        $seen_sqls{$sql}++;
    }

    is(scalar keys %seen_sqls, 1,
        'Explicit column query generates consistent SQL across all iterations');

    my ($sql) = keys %seen_sqls;
    like($sql, qr/SELECT .+ FROM users/,
        'SQL contains expected SELECT FROM structure');

    my $columns = extract_columns($sql);
    for my $col (@explicit_cols) {
        like($columns, qr/\b$col\b/, "SQL includes column '$col'");
    }
};

subtest 'Column order remains stable' => sub {
    my @column_orders;

    for my $i (1..5) {
        my $rs = $schema->resultset('User')->search({});
        my $query = $rs->as_query;
        my $sql = normalise_sql(extract_sql($query));
        my $columns = extract_columns($sql);
        push @column_orders, $columns;
    }

    # Check all orders are identical
    my $first_order = $column_orders[0];
    my $all_same = 1;
    for my $order (@column_orders) {
        if ($order ne $first_order) {
            $all_same = 0;
            last;
        }
    }

    ok($all_same, 'Column order is identical across multiple invocations');
    ok(length($first_order) > 0, 'Column order is non-empty');
};

subtest 'Chained search generates consistent SQL' => sub {
    my %seen_sqls;

    for my $i (1..5) {
        my $rs = $schema->resultset('User')
                        ->search({ active => 1 })
                        ->search({ age => { '>' => 18 } });
        my $query = $rs->as_query;
        my $sql = normalise_sql(extract_sql($query));
        $seen_sqls{$sql}++;
    }

    is(scalar keys %seen_sqls, 1,
        'Chained search generates consistent SQL');

    my ($sql) = keys %seen_sqls;
    like($sql, qr/active.*age|age.*active/i,
        'SQL contains both search conditions');
};

subtest 'Attribute merging is deterministic' => sub {
    my %seen_sqls;

    for my $i (1..5) {
        my $rs = $schema->resultset('User')
                        ->search({}, { order_by => 'name' })
                        ->search({}, { order_by => 'email' });
        my $query = $rs->as_query;
        my $sql = normalise_sql(extract_sql($query));
        $seen_sqls{$sql}++;
    }

    is(scalar keys %seen_sqls, 1,
        'Attribute merging generates consistent SQL');

    my ($sql) = keys %seen_sqls;
    like($sql, qr/ORDER BY/i, 'SQL contains ORDER BY clause');
};

subtest 'Empty search conditions handled consistently' => sub {
    my %seen_sqls;

    for my $i (1..5) {
        my $rs = $schema->resultset('User')->search({});
        my $query = $rs->as_query;
        my $sql = normalise_sql(extract_sql($query));
        $seen_sqls{$sql}++;
    }

    is(scalar keys %seen_sqls, 1,
        'Empty search generates consistent SQL');

    my ($sql) = keys %seen_sqls;
    unlike($sql, qr/WHERE/i,
        'SQL does not contain WHERE clause for empty conditions');
};

subtest 'as_query returns valid structure' => sub {
    my $rs = $schema->resultset('User')->search({ id => 1 });
    my $query = $rs->as_query;

    ok(defined $query, 'as_query returns defined value');
    ok(ref $query, 'as_query returns a reference');

    my $sql = extract_sql($query);
    ok(length($sql) > 0, 'Extracted SQL is non-empty');
};

subtest 'SQL changes appropriately for different queries' => sub {
    my $rs1 = $schema->resultset('User')->search({ id => 1 });
    my $rs2 = $schema->resultset('User')->search({ name => 'Alice' });

    my $sql1 = normalise_sql(extract_sql($rs1->as_query));
    my $sql2 = normalise_sql(extract_sql($rs2->as_query));

    isnt($sql1, $sql2,
        'Different search conditions produce different SQL');

    like($sql1, qr/\bid\b/i, 'First query contains id condition');
};

subtest 'Columns are deduplicated in chained searches' => sub {
    my $rs = $schema->resultset('User')
                    ->search({}, { columns => ['id', 'name'] })
                    ->search({}, { '+columns' => ['email'] })
                    ->search({}, { '+columns' => ['id'] });

    my $sql = normalise_sql(extract_sql($rs->as_query));

    like($sql, qr/SELECT/i, 'SQL contains SELECT');

    # Count occurrences of 'me.id' in the column list
    my $columns = extract_columns($sql);
    my @id_matches = $columns =~ /\bme\.id\b/g;

    is(scalar @id_matches, 1,
        'Duplicate column appears only once in SQL');
};

subtest 'Complex attributes accumulate correctly' => sub {
    my %seen_sqls;

    for my $i (1..3) {
        my $rs = $schema->resultset('User')
                        ->search({}, {
                            order_by => 'name',
                            group_by => 'active'
                        })
                        ->search({}, {
                            order_by => 'email'
                        });

        my $sql = normalise_sql(extract_sql($rs->as_query));
        $seen_sqls{$sql}++;
    }

    is(scalar keys %seen_sqls, 1,
        'Complex attribute accumulation is consistent');

    my ($sql) = keys %seen_sqls;
    like($sql, qr/ORDER BY.*GROUP BY|GROUP BY.*ORDER BY/si,
        'SQL contains both ORDER BY and GROUP BY');
};

subtest 'update_query generates preview SQL' => sub {
    my $rs = $schema->resultset('User')->search({ id => 1 });
    my ($sql, @bind) = $rs->update_query({ name => 'Updated' });

    ok(defined $sql, 'update_query returns SQL');
    ok(ref $sql eq 'SCALAR', 'SQL is a scalar reference');

    my $sql_str = $$sql;
    like($sql_str, qr/UPDATE/i, 'SQL contains UPDATE');
    like($sql_str, qr/SET/i,    'SQL contains SET');
};

subtest 'delete_query generates preview SQL' => sub {
    my $rs = $schema->resultset('User')->search({ active => 0 });
    my ($sql, @bind) = $rs->delete_query;

    ok(defined $sql, 'delete_query returns SQL');
    ok(ref $sql eq 'SCALAR', 'SQL is a scalar reference');

    my $sql_str = $$sql;
    like($sql_str, qr/DELETE/i, 'SQL contains DELETE');
    like($sql_str, qr/FROM/i,   'SQL contains FROM');
};

subtest 'Query preview methods do not execute' => sub {
    # Create a row
    my $row = $schema->resultset('User')->create({
        name  => 'Test User',
        email => 'test@example.com',
    })->get;

    my $original_name = $row->{name};

    # Preview update
    my $rs = $schema->resultset('User')->search({ id => $row->{id} });
    my ($sql, @bind) = $rs->update_query({ name => 'Changed' });

    # Verify row wasn't actually updated
    my $check = $schema->resultset('User')->find({ id => $row->{id} })->get;
    is($check->{name}, $original_name, 'update_query did not modify database');

    # Preview delete
    ($sql, @bind) = $rs->delete_query;

    # Verify row still exists
    $check = $schema->resultset('User')->find({ id => $row->{id} })->get;
    ok(defined $check, 'delete_query did not remove row from database');
};

subtest 'Empty select list generates appropriate SQL' => sub {
    my $rs = $schema->resultset('User')->search(
        { active => 1  },
        { select => [] },
    );

    my ($sql, @bind) = $rs->as_query;

    ok(defined $sql, 'empty select returns SQL');
    ok(ref $sql eq 'SCALAR', 'SQL is scalar reference');

    my $sql_str = $$sql;
    like($sql_str, qr/SELECT/i, 'Contains SELECT keyword');
    like($sql_str, qr/FROM/i,   'Contains FROM keyword');

    # Should NOT select all columns
    unlike($sql_str, qr/me\.id.*me\.name/i,
        'Does not expand to all columns');

    # Should be minimal: either "SELECT FROM" (PG) or "SELECT 1 FROM" (others)
    my $is_minimal = ($sql_str =~ /SELECT\s+FROM/i ||
                      $sql_str =~ /SELECT\s+1\s+FROM/i);
    ok($is_minimal, 'Uses minimal column selection');
};

subtest 'Empty select with conditions' => sub {
    my $rs = $schema->resultset('User')->search(
        { active => 1, age => { '>' => 18 } },
        { select => [] }
    );

    my ($sql, @bind) = $rs->as_query;
    my $sql_str = $$sql;

    like($sql_str, qr/WHERE/i,  'Contains WHERE clause');
    like($sql_str, qr/active/i, 'Contains active condition');
    ok(@bind > 0, 'Has bind values');
};

subtest 'Empty select execution works' => sub {
    # Ensure we have at least one row by creating with unique data
    my $test_email = 'empty-select-test-' . $$ . '-' . time . '@example.com';

    my $test_user = eval {
        $schema->resultset('User')->create({
            name   => 'Empty Select Test',
            email  => $test_email,
            active => 1,
        })->get;
    };

    SKIP: {
        skip "Could not create test user: $@", 2 if $@;

        my $rs = $schema->resultset('User')->search(
            { email  => $test_email },
            { select => [] },
        );

        # Should execute without error
        my $result = eval { $rs->all->get };
        ok(!$@, 'Empty select executes without error') or diag("Error: $@");
        ok(defined $result && ref $result eq 'ARRAY', 'Returns array reference');

        eval {
            $schema->resultset('User')->search({ email => $test_email })->delete->get;
        };
    }
};

subtest 'as_subselect_rs basic functionality' => sub {
    my $rs = $schema->resultset('User')->search({ active => 1 });

    ok($rs->can('as_subselect_rs'), 'as_subselect_rs method exists');

    my $subselect_rs = eval { $rs->as_subselect_rs };
    ok(!$@, 'as_subselect_rs executes without error') or diag("Error: $@");

    isa_ok($subselect_rs, 'DBIx::Class::Async::ResultSet',
        'Returns a ResultSet object');

    my ($sql, @bind) = $subselect_rs->as_query;
    my $sql_str      = extract_sql($sql);

    like($sql_str, qr/SELECT.*FROM\s*\(/i,
        'SQL contains subquery in FROM clause');
};

subtest 'as_subselect_rs preserves column list' => sub {
    # Create RS with limited columns
    my $rs = $schema->resultset('User')->search(
        { active  => 1 },
        { columns => ['id', 'name'] },
    );

    my ($sql1)   = $rs->as_query;
    my $sql1_str = extract_sql($sql1);

    # Verify original RS has limited columns
    like($sql1_str,   qr/\bid\b/i,    'Original RS includes id');
    like($sql1_str,   qr/\bname\b/i,  'Original RS includes name');
    unlike($sql1_str, qr/\bemail\b/i, 'Original RS excludes email');

    # Convert to subselect
    my $subselect_rs = $rs->as_subselect_rs;
    my ($sql2)       = $subselect_rs->as_query;
    my $sql2_str     = extract_sql($sql2);

    # The outer query should also only reference id and name
    # NOT try to select email, age, etc.
    unlike($sql2_str, qr/me\.email|me\.age|me\.balance/i,
        'Subselect does not expand to all table columns');

    # Should still have the subquery structure
    like($sql2_str, qr/FROM\s*\(/i, 'Still has subquery structure');
};

subtest 'as_subselect_rs with further filtering' => sub {
    # Create a subselect, then apply additional conditions
    my $base_rs = $schema->resultset('User')->search(
        { active  => 1 },
        { columns => ['id', 'name'] },
    );

    my $subselect_rs = $base_rs->as_subselect_rs;
    my $filtered_rs  = $subselect_rs->search({ name => { -like => 'A%' }});

    ok($filtered_rs, 'Can chain search after as_subselect_rs');

    my ($sql)   = $filtered_rs->as_query;
    my $sql_str = extract_sql($sql);

    like($sql_str, qr/FROM\s*\(/i, 'Has subquery');
    like($sql_str, qr/name.*LIKE|LIKE.*name/i, 'Has outer WHERE condition');
};

subtest 'as_subselect_rs execution' => sub {
    my $test_email = 'subselect-test-' . time . '@example.com';
    eval {
        $schema->resultset('User')->create({
            name   => 'Alice Subselect',
            email  => $test_email,
            active => 1,
            age    => 25,
        })->get;
    };

    SKIP: {
        skip "Could not create test data: $@", 2 if $@;

        # Use subselect
        my $rs = $schema->resultset('User')
                        ->search({ active => 1 }, { columns => ['id', 'name'] })
                        ->as_subselect_rs;

        my $result = eval { $rs->all->get };
        ok(!$@, 'Subselect query executes without error') or diag("Error: $@");
        ok(ref $result eq 'ARRAY', 'Returns array reference');

        eval {
            $schema->resultset('User')->search({ email => $test_email })->delete->get;
        };
    }
};

$schema->disconnect;

done_testing;

# Helper function to extract SQL from as_query result
sub extract_sql {
    my ($query_result) = @_;

    my $data = $query_result;

    # Dereference until we get to the actual data
    while (ref $data eq 'REF') {
        $data = $$data;
    }

    # Handle ARRAY ref format: [ $sql, @bind ]
    if (ref $data eq 'ARRAY') {
        my $sql = $data->[0];
        # SQL might still be a reference
        while (ref $sql) {
            if (ref $sql eq 'SCALAR') {
                $sql = $$sql;
                last;
            } elsif (ref $sql eq 'REF') {
                $sql = $$sql;
            } else {
                last;
            }
        }
        return $sql;
    } elsif (ref $data eq 'SCALAR') {
        return $$data;
    } else {
        return "$data";
    }
}

# Helper to normalize SQL for comparison
sub normalise_sql {
    my $sql = shift;
    $sql =~ s/\s+/ /g;      # Normalise whitespace
    $sql =~ s/^\s+|\s+$//g; # Trim
    return $sql;
}

# Helper to extract column list from SQL
sub extract_columns {
    my $sql = shift;
    if ($sql =~ /SELECT\s+(.+?)\s+FROM/si) {
        return $1;
    }
    return '';
}
