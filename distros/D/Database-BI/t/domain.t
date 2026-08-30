use strict;
use warnings;
use Test::Most;
use Test::Mojo;
use Test::Mockingbird	qw(mock restore_all);
use Readonly;
use File::Spec		();
use File::Temp		qw(tempdir);
use Mojo::File		();
use Mojo::Util		qw(url_escape);

# ------------------------------------------------------------------
# Bootstrap the app first so :Private stash entries survive.
# ------------------------------------------------------------------
my $t = Test::Mojo->new('Database::BI');
require Database::BI::Model::DataSource;
require Database::BI::Controller::Dashboard;

my $FILTER = \&Database::BI::Controller::Dashboard::_apply_filter_spec;

Readonly my $TMPDIR	=> tempdir(CLEANUP => 1);
Readonly my $DATA_DIR	=> $t->app->home->child('data')->to_string;
Readonly my $SALES_ABS	=> $t->app->home->child('data/sales.csv')->to_string;
Readonly my $PSV_ABS	=> $t->app->home->child('data/products.psv')->to_string;

# ------------------------------------------------------------------
# Representative records from data/sales.csv (id, product, region,
# sales_rep, amount, sale_date).  Used for direct filter EP/BVA tests.
# amounts: 1250.00, 875.50, 2100.00, 950.00, 1875.00, 725.25
# ------------------------------------------------------------------
Readonly my @RECS => (
	{ id => '1', product => 'Widget A',   region => 'North', sales_rep => 'Alice Smith', amount => '1250.00', sale_date => '2025-01-15' },
	{ id => '2', product => 'Widget B',   region => 'South', sales_rep => 'Bob Jones',   amount => '875.50',  sale_date => '2025-01-16' },
	{ id => '3', product => 'Gadget Pro', region => 'East',  sales_rep => 'Carol White', amount => '2100.00', sale_date => '2025-01-17' },
	{ id => '4', product => 'Widget A',   region => 'West',  sales_rep => 'David Lee',   amount => '950.00',  sale_date => '2025-01-18' },
	{ id => '5', product => 'Gadget Pro', region => 'North', sales_rep => 'Alice Smith', amount => '1875.00', sale_date => '2025-01-19' },
	{ id => '6', product => 'Widget B',   region => 'East',  sales_rep => 'Carol White', amount => '725.25',  sale_date => '2025-01-20' },
);

# ======================================================================
# DOMAIN 1: Table name domain -- GET /view/:table
#
# TABLE_NAME_RE = \A[A-Za-z_][A-Za-z0-9_]*\z
#
# Equivalence Partitions:
#   VP-Alpha   : letter-start, letters only          (e.g. "sales")
#   VP-Under   : underscore-start                    (e.g. "_data")
#   VP-Mixed   : letter-start with digits/underscore (e.g. "sales_2024")
#   IP-Digit   : digit at position 0                 -> 404
#   IP-Dot     : contains dot                        -> 404
#   IP-Hyphen  : contains hyphen                     -> 404
#   IP-NonASCII: non-ASCII characters                -> 404
#
# Boundary Values:
#   BV-min-letter    : single letter "a"             -> valid (200)
#   BV-min-underscore: single underscore "_"         -> valid (200)
#   BV-min-digit     : single digit "1"              -> 404
#   BV-len2-valid    : "a1" (letter + digit)         -> valid (200)
#   BV-len2-invalid  : "1a" (digit + letter)         -> 404
# ======================================================================

subtest 'table name EP-Alpha: letter-start word accepted (200, not 404)' => sub {
	$t->get_ok('/view/sales')->status_is(200);
};

subtest 'table name EP-Under: underscore-start accepted (200)' => sub {
	# "_data" has no backing file; controller renders error on home page (still 200).
	$t->get_ok('/view/_data')->status_is(200);
};

subtest 'table name EP-Mixed: letter+digits+underscore accepted (200)' => sub {
	$t->get_ok('/view/sales_2024')->status_is(200);
};

subtest 'table name IP-Digit: digit-start rejected (404)' => sub {
	$t->get_ok('/view/1sales')->status_is(404);
};

subtest 'table name IP-Dot: dot in name rejected (404)' => sub {
	$t->get_ok('/view/sales.data')->status_is(404);
};

subtest 'table name IP-Hyphen: hyphen in name rejected (404)' => sub {
	$t->get_ok('/view/my-data')->status_is(404);
};

subtest 'table name IP-NonASCII: non-ASCII characters rejected (404)' => sub {
	# URL-encoded UTF-8 for "caf\xc3\xa9"
	$t->get_ok('/view/caf%C3%A9')->status_is(404);
};

subtest 'table name BV-min-letter: single letter "a" is valid (shortest VP)' => sub {
	$t->get_ok('/view/a')->status_is(200);
};

subtest 'table name BV-min-underscore: single underscore "_" is valid' => sub {
	$t->get_ok('/view/_')->status_is(200);
};

subtest 'table name BV-min-digit: single digit "1" is invalid -- 404' => sub {
	$t->get_ok('/view/1')->status_is(404);
};

subtest 'table name BV-len2-valid: letter+digit "a1" is valid' => sub {
	$t->get_ok('/view/a1')->status_is(200);
};

subtest 'table name BV-len2-invalid: digit+letter "1a" is invalid -- 404' => sub {
	$t->get_ok('/view/1a')->status_is(404);
};

# ======================================================================
# DOMAIN 2: Open-file path domain -- GET /open?path=
#
# EXT_RE = qr/\.(?:csv|db|sql|xml|psv)\z/i  -- \z prevents trailing \n bypass
#
# Equivalence Partitions:
#   VP-CSV  : existing .csv regular file   -> 200
#   VP-PSV  : existing .psv regular file   -> 200
#   IP-Miss : missing ?path= param         -> 404
#   IP-None : non-existent file            -> 404
#   IP-Dir  : directory instead of file   -> 404
#   IP-Ext  : unsupported extension (.txt) -> 404
#
# Boundary Values:
#   BV-case   : .CSV (uppercase extension) -> 200  (EXT_RE has /i flag)
#   BV-newline: .csv\n embedded newline    -> 404  (\z anchor blocks this)
#   BV-double : file.php.csv              -> 200 with friendly error (caught eval)
#   BV-empty  : ?path= (empty string)     -> 404
# ======================================================================

subtest 'open path EP-CSV: existing CSV file opens (200)' => sub {
	$t->get_ok('/open?path=' . url_escape($SALES_ABS))->status_is(200);
};

subtest 'open path EP-PSV: existing PSV file opens (200)' => sub {
	SKIP: {
		skip 'data/products.psv not found', 1 unless -f $PSV_ABS;
		$t->get_ok('/open?path=' . url_escape($PSV_ABS))->status_is(200);
	}
};

subtest 'open path IP-Miss: missing path param yields 404' => sub {
	$t->get_ok('/open')->status_is(404);
};

subtest 'open path IP-None: non-existent file yields 404' => sub {
	my $fake = url_escape("$TMPDIR/does_not_exist.csv");
	$t->get_ok("/open?path=$fake")->status_is(404);
};

subtest 'open path IP-Dir: directory path yields 404 (not a regular file)' => sub {
	$t->get_ok('/open?path=' . url_escape($TMPDIR))->status_is(404);
};

subtest 'open path IP-Ext: unsupported extension .txt yields 404' => sub {
	Mojo::File->new("$TMPDIR/data.txt")->spew("hello\n");
	$t->get_ok('/open?path=' . url_escape("$TMPDIR/data.txt"))->status_is(404);
};

subtest 'open path BV-case: uppercase extension .CSV accepted (EXT_RE /i)' => sub {
	Mojo::File->new("$TMPDIR/report.CSV")->spew("id,name\n1,Alice\n");
	$t->get_ok('/open?path=' . url_escape("$TMPDIR/report.CSV"))->status_is(200);
};

subtest 'open path BV-newline: path with embedded newline rejected (EXT_RE \\z)' => sub {
	# ?path= contains URL-encoded newline after .csv; the \\z anchor in EXT_RE
	# means the extension check sees ".csv\n" which does not match.
	my $path = url_escape("$TMPDIR/report.csv") . '%0A';
	$t->get_ok("/open?path=$path")->status_is(404);
};

subtest 'open path BV-double-ext: file.php.csv passes EXT_RE but triggers eval-caught croak' => sub {
	# .csv matches EXT_RE; table stem "file.php" fails TABLE_NAME_RE inside DataSource::new.
	# open_file wraps open_table in eval -> friendly error rendered as 200, not 500.
	Mojo::File->new("$TMPDIR/file.php.csv")->spew("id,val\n1,x\n");
	$t->get_ok('/open?path=' . url_escape("$TMPDIR/file.php.csv"))->status_is(200);
};

subtest 'open path BV-empty: empty path param yields 404' => sub {
	$t->get_ok('/open?path=')->status_is(404);
};

# ======================================================================
# DOMAIN 2b: /open with bank-export CSV shapes (bug-regression)
#
# Three production bugs triggered when opening a real bank-export CSV:
#
#  Bug 1 (case):  table stem was lowercased before file lookup.  On a
#                 case-sensitive Linux filesystem "MyData.csv" was not found
#                 when the derived table name was "mydata".
#  Bug 2 (space): first column "Account Number" (contains a space) is not a
#                 valid identifier; Database::Abstraction croaked at new().
#  Bug 3 (empty): first safe-name column "Check" was always empty; D::A's
#                 empty_is_undef => 1 made it undef, so the row-sentinel
#                 grep silently dropped every row that had no check number.
# ======================================================================

subtest 'open path BV-mixed-case-stem: MixedCase.csv opens all rows (bug 1)' => sub {
	# The file stem has mixed case; the controller must NOT lowercase it
	# before calling open_table or DataSource will look for "mixedcase.csv".
	Mojo::File->new("$TMPDIR/MixedCase.csv")->spew("id,label\n1,Alpha\n2,Beta\n");
	$t->get_ok('/open?path=' . url_escape("$TMPDIR/MixedCase.csv"))
		->status_is(200, 'bug 1: mixed-case stem opens without error')
		->content_like(qr/Alpha/, 'bug 1: first row data visible')
		->content_like(qr/Beta/,  'bug 1: second row data visible');
	$t->content_unlike(qr/Could not open &quot;MixedCase/, 'bug 1: no server-side error message');
};

subtest 'open path BV-spaced-header: "Account Number" first col opens all rows (bug 2)' => sub {
	# "Account Number" is not a valid SQL identifier; _detect_file_info must
	# fall through to the first safe column ("Date") so D::A construction succeeds.
	Mojo::File->new("$TMPDIR/spending.csv")->spew(
		"Account Number,Date,Amount\nXX1234,2026-01-01,42.00\nXX1234,2026-01-02,13.50\n"
	);
	$t->get_ok('/open?path=' . url_escape("$TMPDIR/spending.csv"))
		->status_is(200, 'bug 2: CSV with spaced first-col header opens without error')
		->content_like(qr/42\.00/, 'bug 2: first row data visible')
		->content_like(qr/13\.50/, 'bug 2: second row data visible');
	$t->content_unlike(qr/unsafe id column name|Could not open &quot;spending/, 'bug 2: no D::A identifier error');
};

subtest 'open path BV-empty-safe-col: empty sentinel col shows all rows (bug 3)' => sub {
	# "ref" is the first safe-identifier column but is empty in every row.
	# D::A uses empty_is_undef; picking "ref" as id would drop every row.
	# _detect_file_info must scan the data row and pick "description" instead.
	Mojo::File->new("$TMPDIR/bankstmt.csv")->spew(
		"Account Number,ref,description,amount\n" .
		"XX1234,,Coffee,4.50\n" .
		"XX1234,,Groceries,23.10\n" .
		"XX1234,,Salary,1500.00\n"
	);
	$t->get_ok('/open?path=' . url_escape("$TMPDIR/bankstmt.csv"))
		->status_is(200, 'bug 3: CSV with empty safe-col sentinel opens without error')
		->content_like(qr/Coffee/,    'bug 3: row 1 visible')
		->content_like(qr/Groceries/, 'bug 3: row 2 visible')
		->content_like(qr/Salary/,    'bug 3: row 3 visible -- not filtered out');
};

subtest 'open path BV-large-spaced-header: spaced col names survive > 16 KB file (bug 4)' => sub {
	# DBD::CSV (used by Database::Abstraction for files > 16 KB) sanitizes column
	# names: "Account Number" -> "account_number".  The slurp path
	# (Text::xSV::Slurp) preserves original names.  DataSource now passes the
	# actual file size as max_slurp_size to force the slurp path and prevent the
	# restricted-hash "disallowed key" crash at render time.
	my $header = "Account Number,Date,Description,Amount\n";
	my @rows;
	for my $i (1 .. 400) {
		push @rows, sprintf("ACC%05d,2024-%02d-%02d,Transaction %d,%.2f\n",
			$i, ($i % 12) + 1, ($i % 28) + 1, $i, $i * 1.5);
	}
	my $content = $header . join('', @rows);
	# Verify the generated file actually exceeds the 16 KB slurp threshold.
	ok length($content) > 16 * 1024, "bug 4: test file is > 16 KB (" . length($content) . " bytes)";

	Mojo::File->new("$TMPDIR/largebankstmt.csv")->spew($content);
	$t->get_ok('/open?path=' . url_escape("$TMPDIR/largebankstmt.csv"))
		->status_is(200, 'bug 4: large CSV with spaced header opens without crash')
		->content_like(qr/Account Number/, 'bug 4: original column header preserved in table')
		->content_like(qr/ACC00001/,       'bug 4: first row data visible')
		->content_like(qr/ACC00400/,       'bug 4: last row data visible');
	$t->content_unlike(qr/disallowed key|restricted hash|internal server error/i,
		'bug 4: no restricted-hash crash or server error');
};

# ======================================================================
# DOMAIN 3: Browse path domain -- GET /browse?path=
#
# Default: $ENV{HOME} // '/' when ?path= is absent.
# realpath must succeed and result must pass -d (is directory).
#
# Equivalence Partitions:
#   VP-Absent : no ?path= -> 200 (defaults to $HOME or /)
#   VP-Dir    : existing directory -> 200
#   IP-None   : non-existent path -> 404
#   IP-File   : regular file path -> 404 (fails -d check)
# ======================================================================

subtest 'browse path VP-Absent: no path param defaults to home/root -- 200' => sub {
	$t->get_ok('/browse')->status_is(200);
};

subtest 'browse path VP-Dir: valid existing directory -- 200' => sub {
	$t->get_ok('/browse?path=' . url_escape($TMPDIR))->status_is(200);
};

subtest 'browse path IP-None: non-existent path -- 404' => sub {
	$t->get_ok('/browse?path=' . url_escape("$TMPDIR/no_such_dir_xyz"))->status_is(404);
};

subtest 'browse path IP-File: regular file path fails -d check -- 404' => sub {
	$t->get_ok('/browse?path=' . url_escape($SALES_ABS))->status_is(404);
};

# ======================================================================
# DOMAIN 4: Filter spec operator domain -- _apply_filter_spec
#
# Spec format: "col:op:val" (split limit 3, so val may contain colons).
# Operator names are CASE-SENSITIVE; only lowercase forms are recognised.
# String ops (eq, ne, contains, starts): VALUE comparison is case-insensitive
#   (both cell and val are lowercased before comparison).
# Numeric ops (lt, le, gt, ge): Perl numeric coercion (<, <=, >, >=).
# Unary ops (empty, notempty): ignore val entirely.
# Unknown / uppercase operators: default case 1 -> all rows pass (no-op).
#
# Boundary Values using sales amounts: 725.25, 875.50, 950.00, 1250.00, 1875.00, 2100.00
#   lt 875.50  -> strict less than  -> [725.25]                         (1 row)
#   le 875.50  -> inclusive         -> [875.50, 725.25]                 (2 rows)
#   gt 1875.00 -> strict greater    -> [2100.00]                        (1 row)
#   ge 1875.00 -> inclusive         -> [1875.00, 2100.00]               (2 rows)
# ======================================================================

# --- Equivalence Partitions: one test per valid operator ---

subtest 'filter EP-eq: case-insensitive value match filters rows' => sub {
	my $result = $FILTER->(\@RECS, 'region:eq:north');
	is scalar(@$result), 2, 'eq: 2 North records (case-insensitive)';
	ok !(grep { lc($_->{region}) ne 'north' } @$result),
		'eq: all returned rows have matching region';
};

subtest 'filter EP-ne: case-insensitive value exclusion filters rows' => sub {
	my $result = $FILTER->(\@RECS, 'region:ne:north');
	is scalar(@$result), 4, 'ne: 4 non-North records';
	ok !(grep { lc($_->{region}) eq 'north' } @$result),
		'ne: no returned row has excluded region';
};

subtest 'filter EP-contains: substring match is case-insensitive' => sub {
	my $result = $FILTER->(\@RECS, 'product:contains:widget');
	is scalar(@$result), 4, 'contains: 4 Widget A/B records';
};

subtest 'filter EP-starts: prefix match is case-insensitive' => sub {
	my $result = $FILTER->(\@RECS, 'product:starts:gadget');
	is scalar(@$result), 2, 'starts: 2 Gadget Pro records';
};

subtest 'filter EP-lt: numeric strict less-than' => sub {
	my $result = $FILTER->(\@RECS, 'amount:lt:1000');
	is scalar(@$result), 3, 'lt 1000: 875.50, 950.00, 725.25 (3 records)';
};

subtest 'filter EP-le: numeric inclusive less-or-equal' => sub {
	my $result = $FILTER->(\@RECS, 'amount:le:950.00');
	is scalar(@$result), 3, 'le 950: 875.50, 950.00, 725.25 (3 records)';
};

subtest 'filter EP-gt: numeric strict greater-than' => sub {
	my $result = $FILTER->(\@RECS, 'amount:gt:1875.00');
	is scalar(@$result), 1, 'gt 1875.00: only 2100.00 (1 record)';
	is $result->[0]{amount}, '2100.00', 'gt: correct record returned';
};

subtest 'filter EP-ge: numeric inclusive greater-or-equal' => sub {
	my $result = $FILTER->(\@RECS, 'amount:ge:1875.00');
	is scalar(@$result), 2, 'ge 1875.00: 1875.00 and 2100.00 (2 records)';
};

subtest 'filter EP-empty: unary operator matches empty/undef cells' => sub {
	my @with_gap = (@RECS, { id => '7', product => '', region => undef, amount => '99' });
	my $result = $FILTER->(\@with_gap, 'region:empty:ignored_val');
	is scalar(@$result), 1, 'empty: only the row with undef/blank region matches';
};

subtest 'filter EP-notempty: unary operator matches non-empty cells' => sub {
	my @with_gap = (@RECS, { id => '7', product => '', region => '', amount => '99' });
	my $result = $FILTER->(\@with_gap, 'region:notempty:ignored_val');
	is scalar(@$result), 6, 'notempty: all 6 original records (non-empty region)';
};

subtest 'filter EP-UnknownOp: unknown operator passes all rows (no-op)' => sub {
	my $result = $FILTER->(\@RECS, 'region:regex:North');
	is scalar(@$result), 6, 'unknown op "regex": all 6 rows returned unchanged';
};

# --- Equivalence Partitions: invalid/malformed specs ---

subtest 'filter EP-EmptySpec: empty spec string is a no-op' => sub {
	my $result = $FILTER->(\@RECS, '');
	is scalar(@$result), 6, 'empty spec: all 6 rows returned';
};

subtest 'filter EP-NoSep: spec with no colon separator is a no-op' => sub {
	my $result = $FILTER->(\@RECS, 'regionNorth');
	is scalar(@$result), 6, 'no-colon spec: all 6 rows returned';
};

subtest 'filter EP-EmptyCol: empty column name is a no-op' => sub {
	my $result = $FILTER->(\@RECS, ':eq:North');
	is scalar(@$result), 6, 'empty col: all 6 rows returned';
};

# --- Case-sensitivity of operator names ---

subtest 'filter domain: operator names ARE case-sensitive -- EQ is not eq' => sub {
	# "EQ" is not a recognised operator; falls through to default 1 -> all rows pass.
	my $result = $FILTER->(\@RECS, 'region:EQ:North');
	is scalar(@$result), 6, '"EQ" (uppercase) is not a valid op -- all rows pass';
};

subtest 'filter domain: operator names ARE case-sensitive -- Lt is not lt' => sub {
	my $result = $FILTER->(\@RECS, 'amount:Lt:1000');
	is scalar(@$result), 6, '"Lt" (mixed case) is not a valid op -- all rows pass';
};

# --- Boundary Value Analysis: numeric operators at exact boundary ---

subtest 'filter BVA-lt-at-boundary: lt excludes the boundary value (strict)' => sub {
	# Boundary is 875.50; lt should exclude it.
	my $result = $FILTER->(\@RECS, 'amount:lt:875.50');
	is scalar(@$result), 1, 'lt 875.50: only 725.25 qualifies (875.50 excluded)';
	is $result->[0]{amount}, '725.25', 'lt at boundary: correct sole record';
};

subtest 'filter BVA-le-at-boundary: le includes the boundary value (inclusive)' => sub {
	my $result = $FILTER->(\@RECS, 'amount:le:875.50');
	is scalar(@$result), 2, 'le 875.50: 725.25 and 875.50 qualify (inclusive)';
	ok +(grep { $_->{amount} eq '875.50' } @$result), 'le: boundary value 875.50 is included';
};

subtest 'filter BVA-gt-at-boundary: gt excludes the boundary value (strict)' => sub {
	my $result = $FILTER->(\@RECS, 'amount:gt:1875.00');
	is scalar(@$result), 1, 'gt 1875.00: only 2100.00 qualifies (1875.00 excluded)';
	ok !(grep { $_->{amount} eq '1875.00' } @$result), 'gt: boundary value 1875.00 excluded';
};

subtest 'filter BVA-ge-at-boundary: ge includes the boundary value (inclusive)' => sub {
	my $result = $FILTER->(\@RECS, 'amount:ge:1875.00');
	is scalar(@$result), 2, 'ge 1875.00: 1875.00 and 2100.00 qualify (inclusive)';
	ok +(grep { $_->{amount} eq '1875.00' } @$result), 'ge: boundary value 1875.00 included';
};

subtest 'filter BVA-contains-empty-val: contains "" matches every record' => sub {
	# index(str, '') always returns 0 (found), so all rows pass.
	my $result = $FILTER->(\@RECS, 'product:contains:');
	is scalar(@$result), 6, 'contains "": all 6 rows match (empty substring is always found)';
};

subtest 'filter BVA-starts-empty-val: starts "" matches every record' => sub {
	my $result = $FILTER->(\@RECS, 'region:starts:');
	is scalar(@$result), 6, 'starts "": all 6 rows match (every string starts with empty)';
};

subtest 'filter BVA-colon-in-value: split limit 3 preserves colons in val' => sub {
	# Spec "sale_date:starts:2025:01" -> col="sale_date", op="starts", val="2025:01".
	# All 6 dates start with "2025-" but not "2025:01", so 0 rows.
	my $result = $FILTER->(\@RECS, 'sale_date:starts:2025:01');
	is scalar(@$result), 0,
		'colon in val: "2025:01" is the full val (not a 4th field); no date matches';
	# Verify the val is the full colon-containing string, not a truncation.
	my $all = $FILTER->(\@RECS, 'sale_date:starts:2025');
	is scalar(@$all), 6, 'sanity: starts "2025" (no inner colon) matches all 6 dates';
};

# ======================================================================
# DOMAIN 5: Export format domain -- GET /export?l=...&format=
#
# Code: $format = 'csv' unless $format eq 'sqlite';
# Comparison is exact and case-SENSITIVE.
#
# Equivalence Partitions:
#   VP-csv    : format=csv     -> text/csv download
#   VP-sqlite : format=sqlite  -> application/octet-stream
#   VP-json   : format=json    -> application/json download
#   VP-absent : no format=     -> csv (default)
#
# Boundary Values:
#   BV-SQLITE : format=SQLITE  -> csv (uppercase != 'sqlite')
#   BV-sqlit  : format=sqlit   -> csv (truncated, not exact 'sqlite')
#   BV-sqlite1: format=sqlite1 -> csv (extra char, not exact)
# ======================================================================

subtest 'export format VP-csv: format=csv returns text/csv' => sub {
	$t->get_ok('/export?l=table:sales&format=csv')
	  ->status_is(200)
	  ->content_type_like(qr{text/csv}i);
};

subtest 'export format VP-sqlite: format=sqlite returns SQLite binary' => sub {
	SKIP: {
		eval { require DBI; DBI->install_driver('SQLite') }
			or skip 'DBD::SQLite not available', 2;
		$t->get_ok('/export?l=table:sales&format=sqlite')
		  ->status_is(200)
		  ->content_type_like(qr{octet-stream|sqlite}i);
	}
};

subtest 'export format VP-absent: missing format defaults to csv' => sub {
	$t->get_ok('/export?l=table:sales')
	  ->status_is(200)
	  ->content_type_like(qr{text/csv}i);
};

subtest 'export format VP-json: format=json returns application/json' => sub {
	$t->get_ok('/export?l=table:sales&format=json')
	  ->status_is(200)
	  ->content_type_like(qr{application/json}i);
};

subtest 'export format BV-SQLITE: uppercase "SQLITE" does NOT match -- csv returned' => sub {
	$t->get_ok('/export?l=table:sales&format=SQLITE')
	  ->status_is(200)
	  ->content_type_like(qr{text/csv}i);
};

subtest 'export format BV-truncated: "sqlit" (one char short) does not match' => sub {
	$t->get_ok('/export?l=table:sales&format=sqlit')
	  ->status_is(200)
	  ->content_type_like(qr{text/csv}i);
};

# ======================================================================
# DOMAIN 6: Export write filename domain -- POST /export (body)
#
# Code: $filename =~ /\.csv\z/i  OR  $filename =~ /\.sql\z/i
# Case-INSENSITIVE via /i flag.  Everything else -> 415.
# Path separators in filename are stripped first.
#
# Equivalence Partitions:
#   VP-csv    : report.csv        -> 200
#   VP-sql    : report.sql        -> 200
#   VP-CSV    : REPORT.CSV        -> 200 (case-insensitive)
#   IP-txt    : report.txt        -> 415 error_ext_required
#   IP-noext  : report            -> 415
#   IP-empty  : (empty filename)  -> 415
#
# Boundary Values:
#   BV-minstem: a.csv (1-char stem) -> 200
#   BV-sep    : dir/report.csv     -> stem "report.csv" after path-strip -> 200
# ======================================================================

subtest 'export write EP-csv: filename ending .csv produces 200' => sub {
	$t->post_ok('/export', form => {
		l        => 'table:sales',
		dir      => $TMPDIR,
		filename => 'report.csv',
	})->status_is(200)->json_has('/saved');
};

subtest 'export write EP-sql: filename ending .sql produces 200' => sub {
	SKIP: {
		eval { require DBI; DBI->install_driver('SQLite') }
			or skip 'DBD::SQLite not available', 1;
		$t->post_ok('/export', form => {
			l        => 'table:sales',
			dir      => $TMPDIR,
			filename => 'report.sql',
		})->status_is(200)->json_has('/saved');
	}
};

subtest 'export write EP-CSV: uppercase .CSV extension is accepted (case-insensitive)' => sub {
	$t->post_ok('/export', form => {
		l        => 'table:sales',
		dir      => $TMPDIR,
		filename => 'REPORT.CSV',
	})->status_is(200)->json_has('/saved');
};

subtest 'export write IP-txt: unsupported extension returns 415' => sub {
	$t->post_ok('/export', form => {
		l        => 'table:sales',
		dir      => $TMPDIR,
		filename => 'report.txt',
	})->status_is(415)->json_has('/error');
};

subtest 'export write IP-noext: filename with no extension returns 415' => sub {
	$t->post_ok('/export', form => {
		l        => 'table:sales',
		dir      => $TMPDIR,
		filename => 'report',
	})->status_is(415)->json_has('/error');
};

subtest 'export write IP-empty: empty filename returns 415' => sub {
	$t->post_ok('/export', form => {
		l        => 'table:sales',
		dir      => $TMPDIR,
		filename => '',
	})->status_is(415)->json_has('/error');
};

subtest 'export write BV-minstem: single-char stem "a.csv" is valid' => sub {
	$t->post_ok('/export', form => {
		l        => 'table:sales',
		dir      => $TMPDIR,
		filename => 'a.csv',
	})->status_is(200)->json_has('/saved');
};

subtest 'export write BV-sep: path separator in filename stripped to basename' => sub {
	# The controller strips everything up to and including the last / or \.
	# "dir/report.csv" -> "report.csv" (safe against directory traversal).
	$t->post_ok('/export', form => {
		l        => 'table:sales',
		dir      => $TMPDIR,
		filename => 'subdir/safe.csv',
	})->status_is(200)->json_has('/saved');
};

subtest 'export write IP-baddir: non-existent directory returns 404' => sub {
	$t->post_ok('/export', form => {
		l        => 'table:sales',
		dir      => "$TMPDIR/no_such_dir_xyz",
		filename => 'report.csv',
	})->status_is(404)->json_has('/error');
};

# ======================================================================
# DOMAIN 7: DataSource::new parameter domain
#
# directory:
#   Valid:   existing directory path (-d returns true)
#   Invalid: non-existent path       -> croak error_directory_missing
#   Invalid: regular file path       -> croak error_directory_missing
#   Invalid: empty string ""         -> croak error_directory_missing
#
# table (TABLE_NAME_RE = \A[A-Za-z_][A-Za-z0-9_]*\z):
#   Valid:   any letter/underscore-start identifier
#   Invalid: digit-start, dot, hyphen, empty -> croak error_table_name_invalid
#
# Boundary Values:
#   BV-table-len1-letter:     "a"  -> valid
#   BV-table-len1-underscore: "_"  -> valid
#   BV-table-len1-digit:      "1"  -> croak error_table_name_invalid
# ======================================================================

{
	# Write a CSV so the backend actually initialises without error.
	Mojo::File->new("$TMPDIR/sample.csv")->spew("id,name\n1,Alice\n");
	Mojo::File->new("$TMPDIR/a.csv")->spew("id\n1\n");
	Mojo::File->new("$TMPDIR/_.csv")->spew("id\n1\n");

	subtest 'DataSource VP-valid: valid dir + valid table name -> success' => sub {
		my $ds;
		lives_ok { $ds = Database::BI::Model::DataSource->new(directory => $TMPDIR, table => 'sample') }
			'valid dir + valid table: no exception';
		isa_ok $ds, 'Database::BI::Model::DataSource', 'returned object';
	};

	subtest 'DataSource IP-dir-nonexistent: non-existent directory -> croak' => sub {
		throws_ok {
			Database::BI::Model::DataSource->new(
				directory => "$TMPDIR/no_such_dir",
				table     => 'sample',
			)
		} qr/does not exist or is not readable/,
			'non-existent directory: croak error_directory_missing';
	};

	subtest 'DataSource IP-dir-file: file path instead of directory -> croak' => sub {
		throws_ok {
			Database::BI::Model::DataSource->new(
				directory => "$TMPDIR/sample.csv",
				table     => 'sample',
			)
		} qr/does not exist or is not readable/,
			'file used as directory: croak error_directory_missing';
	};

	subtest 'DataSource IP-dir-empty: empty string directory -> croak' => sub {
		throws_ok {
			Database::BI::Model::DataSource->new(directory => '', table => 'sample')
		} qr/does not exist or is not readable/,
			'empty directory string: croak error_directory_missing';
	};

	subtest 'DataSource IP-table-digit: digit-start table name -> croak' => sub {
		throws_ok {
			Database::BI::Model::DataSource->new(directory => $TMPDIR, table => '1data')
		} qr/contains illegal characters/,
			'digit-start table: croak error_table_name_invalid';
	};

	subtest 'DataSource IP-table-dot: table name with dot -> croak' => sub {
		throws_ok {
			Database::BI::Model::DataSource->new(directory => $TMPDIR, table => 'my.data')
		} qr/contains illegal characters/,
			'dot in table name: croak error_table_name_invalid';
	};

	subtest 'DataSource IP-table-hyphen: table name with hyphen -> croak' => sub {
		throws_ok {
			Database::BI::Model::DataSource->new(directory => $TMPDIR, table => 'my-data')
		} qr/contains illegal characters/,
			'hyphen in table name: croak error_table_name_invalid';
	};

	subtest 'DataSource IP-table-empty: empty table name -> croak' => sub {
		throws_ok {
			Database::BI::Model::DataSource->new(directory => $TMPDIR, table => '')
		} qr/contains illegal characters/,
			'empty table name: croak error_table_name_invalid';
	};

	subtest 'DataSource BV-table-len1-letter: single letter "a" is valid (shortest VP)' => sub {
		my $ds;
		lives_ok { $ds = Database::BI::Model::DataSource->new(directory => $TMPDIR, table => 'a') }
			'single letter "a": valid table name';
	};

	subtest 'DataSource BV-table-len1-underscore: single underscore "_" is valid' => sub {
		my $ds;
		lives_ok { $ds = Database::BI::Model::DataSource->new(directory => $TMPDIR, table => '_') }
			'single underscore "_": valid table name';
	};

	subtest 'DataSource BV-table-len1-digit: single digit "1" is invalid' => sub {
		throws_ok {
			Database::BI::Model::DataSource->new(directory => $TMPDIR, table => '1')
		} qr/contains illegal characters/,
			'single digit "1": croak error_table_name_invalid';
	};

	subtest 'DataSource Combinatorial: longest valid name with every char class' => sub {
		# Max-length valid name: starts with underscore, body has letters+digits+underscores.
		my $long = '_' . ('a1_' x 30);  # 91 chars
		Mojo::File->new("$TMPDIR/${long}.csv")->spew("id\n1\n");
		my $ds;
		lives_ok { $ds = Database::BI::Model::DataSource->new(directory => $TMPDIR, table => $long) }
			'91-char valid name accepted';
	};
}

# ======================================================================
# DOMAIN 8: Upload file domain -- POST /upload
#
# Extension validated via EXT_RE (csv|db|sql|xml|psv, case-insensitive).
# Size guard: is_limit_exceeded || upload->size > MAX_UPLOAD_BYTES -> 413.
# Missing file -> 400. Unsupported ext -> 415.
#
# Equivalence Partitions:
#   VP-csv   : .csv upload -> 200
#   VP-psv   : .psv upload -> 200
#   VP-xml   : .xml upload -> 200
#   VP-sql   : .sql upload -> 200
#   IP-php   : .php upload -> 415 error_upload_ext
#   IP-none  : no file field -> 400 error_upload_none
#   IP-size  : file > limit -> 413 error_upload_too_large
#
# Boundary Value:
#   BV-case  : .CSV (uppercase) -> 200 (EXT_RE /i)
# ======================================================================

subtest 'upload EP-csv: CSV file upload succeeds (200, JSON url/path)' => sub {
	$t->post_ok('/upload', form => {
		file => { content => "id,name\n1,Alice\n", filename => 'up.csv' },
	})->status_is(200)->json_has('/url')->json_has('/path');
};

subtest 'upload EP-psv: PSV file upload succeeds' => sub {
	$t->post_ok('/upload', form => {
		file => { content => "id|name\n1|Alice\n", filename => 'up.psv' },
	})->status_is(200)->json_has('/url');
};

subtest 'upload EP-xml: XML file upload succeeds' => sub {
	$t->post_ok('/upload', form => {
		file => { content => '<r><row><id>1</id></row></r>', filename => 'up.xml' },
	})->status_is(200)->json_has('/url');
};

subtest 'upload EP-sql: SQLite file upload accepted' => sub {
	$t->post_ok('/upload', form => {
		file => { content => 'SQLite format 3', filename => 'up.sql' },
	})->status_is(200)->json_has('/url');
};

subtest 'upload IP-php: .php extension rejected -- 415 error_upload_ext' => sub {
	$t->post_ok('/upload', form => {
		file => { content => '<?php phpinfo(); ?>', filename => 'evil.php' },
	})->status_is(415)->json_like('/error', qr/Unsupported file type/i);
};

subtest 'upload IP-none: missing file field -- 400 error_upload_none' => sub {
	$t->post_ok('/upload', form => { note => 'no file here' })
	  ->status_is(400)->json_like('/error', qr/No file received/i);
};

subtest 'upload BV-case: uppercase .CSV extension accepted (EXT_RE /i)' => sub {
	$t->post_ok('/upload', form => {
		file => { content => "ID,NAME\n1,Alice\n", filename => 'UP.CSV' },
	})->status_is(200)->json_has('/url');
};

subtest 'upload IP-size: file exceeding limit returns 413' => sub {
	# Lower the transport cap to 512 bytes, then upload 600 bytes.
	# The guard: is_limit_exceeded || upload->size > MAX_UPLOAD_BYTES.
	my $orig_limit = $t->app->max_request_size;
	$t->app->max_request_size(512);
	$t->post_ok('/upload', form => {
		file => { content => 'x' x 600, filename => 'big.csv' },
	})->status_is(413)->json_like('/error', qr/too large/i);
	$t->app->max_request_size($orig_limit);
};

# ======================================================================
# DOMAIN 9: stat_api path domain -- GET /api/stat
#
# stat_api restricts results to EXT_RE files (security: not a filesystem oracle).
# A non-data-extension path returns 200 with exists:false, not 404.
# A missing path param returns 400.
#
# Equivalence Partitions:
#   VP-exists  : existing CSV file      -> 200, exists:true
#   VP-missing : non-existent CSV path  -> 200, exists:false
#   IP-noparam : no ?path=             -> 400 error_path_required
#   IP-security: /etc/passwd (no EXT)  -> 200, exists:false (not an oracle)
# ======================================================================

subtest 'stat_api VP-exists: existing data file returns exists:true' => sub {
	$t->get_ok('/api/stat?path=' . url_escape($SALES_ABS))
	  ->status_is(200)
	  ->json_is('/exists', 1);
};

subtest 'stat_api VP-missing: non-existent CSV path returns exists:false (not 404)' => sub {
	$t->get_ok('/api/stat?path=' . url_escape("$TMPDIR/ghost.csv"))
	  ->status_is(200)
	  ->json_is('/exists', 0);
};

subtest 'stat_api IP-noparam: missing path parameter returns 400' => sub {
	$t->get_ok('/api/stat')
	  ->status_is(400)
	  ->json_has('/error');
};

subtest 'stat_api IP-security: non-data file /etc/passwd returns exists:false' => sub {
	# stat_api must not be a filesystem oracle; unsupported extensions always
	# return exists:false regardless of whether the file actually exists.
	$t->get_ok('/api/stat?path=' . url_escape('/etc/passwd'))
	  ->status_is(200)
	  ->json_is('/exists', 0);
};

done_testing;
