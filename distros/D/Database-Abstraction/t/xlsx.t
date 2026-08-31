#!perl -w

use strict;
use warnings;

use FindBin qw($Bin);
use File::Spec;
use File::Temp qw(tempdir);
use Test::Most;
use Test::Needs 'DBD::Excel', 'Spreadsheet::WriteExcel';
use Test::NoWarnings;

# Pre-load lazily-required modules before any Database::test1 object is
# constructed, so that a later require inside _open() is a no-op.
Test::Needs->import('DBD::Excel');
Test::Needs->import('Spreadsheet::WriteExcel');

use lib 't/lib';
use Database::test1;

plan tests => 19;

pass('DBD::Excel and Spreadsheet::WriteExcel available');

# ---------------------------------------------------------------------------
# Build fixture: test1.xlsx with two worksheets.
# test1  — entry / number  (mimics t/data/test1.csv, three data rows)
# sheet2 — entry / score   (used for the constructor-level table override)
# ---------------------------------------------------------------------------
my $tmpdir = tempdir(CLEANUP => 1);
my $xlsx   = File::Spec->catfile($tmpdir, 'test1.xlsx');

{
	my $wb = Spreadsheet::WriteExcel->new($xlsx);

	# Primary worksheet — name matches the class-derived table name 'test1'
	my $ws1 = $wb->add_worksheet('test1');
	$ws1->write(0, 0, 'entry');  $ws1->write(0, 1, 'number');
	$ws1->write(1, 0, 'one');    $ws1->write(1, 1, 1);
	$ws1->write(2, 0, 'two');    $ws1->write(2, 1, 2);
	$ws1->write(3, 0, 'three');  $ws1->write(3, 1, 3);

	# Second worksheet — used for the constructor-level table override test
	my $ws2 = $wb->add_worksheet('sheet2');
	$ws2->write(0, 0, 'entry');  $ws2->write(0, 1, 'score');
	$ws2->write(1, 0, 'alpha');  $ws2->write(1, 1, 90);
	$ws2->write(2, 0, 'beta');   $ws2->write(2, 1, 75);

	$wb->close();
}

ok(-r $xlsx, 'fixture test1.xlsx written');

# ---------------------------------------------------------------------------
# Section 1: basic keyed-mode queries
# type is set lazily inside _open(), which fires on the first query, so all
# is()-type assertions on type must come AFTER the first query call.
# ---------------------------------------------------------------------------
my $db = new_ok('Database::test1' => [$tmpdir], 'Database::test1 on XLSX directory');

is($db->count(), 3, 'count() returns 3 rows');

# type is now set (count() triggered _open())
is($db->{'type'}, 'Excel', 'type is Excel after first query');

is($db->number('two'), 2, 'AUTOLOAD: number(two) == 2');
is($db->number('four'), undef, 'AUTOLOAD: number(four) is undef (miss)');

my $row = $db->fetchrow_hashref(entry => 'one');
is($row->{'entry'},  'one', 'fetchrow_hashref: entry == one');
is($row->{'number'}, 1,     'fetchrow_hashref: number == 1');

my $all = $db->selectall_arrayref();
is(scalar(@{$all}), 3, 'selectall_arrayref: 3 rows');

# ---------------------------------------------------------------------------
# Section 2: no_entry mode
# ---------------------------------------------------------------------------
my $db_ne = Database::test1->new(directory => $tmpdir, no_entry => 1, max_slurp_size => 0);
isa_ok($db_ne, 'Database::test1', 'no_entry instance');
cmp_ok($db_ne->count(), '>', 0, 'no_entry: count > 0');
is($db_ne->{'type'}, 'Excel', 'no_entry: type is Excel after first query');

# ---------------------------------------------------------------------------
# Section 3: constructor-level table override (queries 'sheet2' worksheet)
# 'dbname' falls back to the class name ('test1'), so the file is still
# test1.xlsx; only the active worksheet changes.
# ---------------------------------------------------------------------------
my $db2 = Database::test1->new(directory => $tmpdir, table => 'sheet2');
isa_ok($db2, 'Database::test1', 'table-override instance');
is($db2->count(), 2, 'table override: sheet2 has 2 rows');
is($db2->{'type'}, 'Excel', 'table override: type is Excel after first query');
is($db2->score('alpha'), 90, 'table override: AUTOLOAD score(alpha) == 90');

# ---------------------------------------------------------------------------
# Section 4: unsafe table name is rejected at construction (before any I/O)
# ---------------------------------------------------------------------------
throws_ok {
	Database::test1->new(directory => $tmpdir, table => 'bad; DROP TABLE x--');
} qr/unsafe table name/, 'unsafe table name rejected at new()';
