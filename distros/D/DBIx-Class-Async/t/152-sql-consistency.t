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
my ($fh, $db_file) = File::Temp::tempfile(SUFFIX => '.db', UNLINK => 1);

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
    ok(length($columns) > 0,
        'SQL contains column list');
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
    like($sql, qr/ORDER BY/i,
        'SQL contains ORDER BY clause');

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
                    ->search({}, { '+columns' => ['id'] });  # Duplicate

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

$schema->disconnect;

done_testing;
