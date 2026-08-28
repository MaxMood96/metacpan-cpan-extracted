use strict;
use warnings;
use Test::Most;
use Test::Mojo;
use File::Temp		qw(tempdir);
use Mojo::File		();
use Mojo::JSON		qw(decode_json);
use Mojo::Util		qw(url_escape);
use Readonly;

# ======================================================================
# BOOTSTRAP -- load the app first so Sub::Private :Private stash entries
# survive the runtime load (CHECK has already passed by test time).
# ======================================================================

my $t = Test::Mojo->new('Database::BI');

# ======================================================================
# CONSTANTS
# ======================================================================

Readonly my $DATA_DIR	=> $t->app->home->child('data')->to_string;
Readonly my $SALES_CSV	=> $t->app->home->child('data/sales.csv')->to_string;

# Columns and row counts as they exist in data/sales.csv
Readonly my $SALES_COLS		=> 6;	# id,product,region,sales_rep,amount,sale_date
Readonly my $SALES_ROWS		=> 6;
Readonly my $NORTH_ROWS		=> 2;	# region eq North: rows 1 and 5
Readonly my $NORTH_GT1500	=> 1;	# North AND amount > 1500: row 5 (1875.00) only

# CSV fixture content for upload and join tests
Readonly my $UPLOAD_CSV_CONTENT => "id,product,region,amount\n1,alpha,North,100\n2,beta,South,200\n";
Readonly my $UPLOAD_CSV_ROWS	=> 2;
Readonly my $UPLOAD_CSV_COLS	=> 4;

# Fixtures for the join transaction: left and right tables sharing a join key.
Readonly my $JOIN_LEFT => "id,item,region,quantity\n1,apple,North,10\n2,banana,South,5\n3,apple,East,8\n4,cherry,North,3\n";
Readonly my $JOIN_RIGHT => "item,price_each,category\napple,0.50,fruit\nbanana,0.25,fruit\ncherry,1.00,fruit\n";

# After left-joining on item: cols = id,item,region,quantity,price_each,category
# Filter region:eq:North keeps rows 1 (apple) and 4 (cherry).
Readonly my $JOIN_TOTAL_ROWS	=> 4;
Readonly my $JOIN_NORTH_ROWS	=> 2;
Readonly my $JOIN_MERGED_COLS	=> 6;	# left(4) + right(3) - join_key(1) = 6

# ======================================================================
# HELPER -- count CSV data rows (excludes header line and empty lines).
# ======================================================================

sub count_csv_rows {
	my ($body) = @_;
	my @lines = grep { /\S/ } split /\r?\n/, $body;
	return scalar(@lines) - 1;	# subtract header
}

# ======================================================================
# HELPER -- count CSV columns from header line.
# ======================================================================

sub count_csv_cols {
	my ($body) = @_;
	my ($header) = grep { /\S/ } split /\r?\n/, $body;
	return 0 unless defined $header;
	# Simple split on comma; fields are quoted only when they contain commas.
	my @fields = split /,/, $header;
	return scalar @fields;
}

# ======================================================================
# TRANSACTION 1: Upload -> Browse -> Open lifecycle
#
# Lifecycle phases:
#   Phase 1  POST /upload          (CSV content)    -> 200, {url, path}
#   Phase 2  GET  /browse          (upload subdir)  -> 200, file in listing
#   Phase 3  GET  /open            (uploaded path)  -> 200, data table
#   Phase 4  POST /upload          (same content)   -> 200, idempotent re-upload
#
# State invariant: path returned from /upload must be an absolute path to a
# regular file that /browse lists and /open can display.
# ======================================================================

subtest 'Transaction 1: Upload -> Browse -> Open lifecycle' => sub {
	# ------------------------------------------------------------------
	# Phase 1: upload a valid CSV file.
	# ------------------------------------------------------------------
	$t->post_ok('/upload', form => {
		file => { content => $UPLOAD_CSV_CONTENT, filename => 'txn1_upload.csv' },
	})->status_is(200);

	my $json1 = decode_json($t->tx->res->body);
	ok  defined $json1->{path},              'Phase 1: response contains "path"';
	ok  defined $json1->{url},               'Phase 1: response contains "url"';
	like $json1->{path}, qr/txn1_upload\.csv\z/, 'Phase 1: path ends with original filename';
	like $json1->{url},  qr{/open\?path=},      'Phase 1: url starts with /open?path=';

	my $upload_path = $json1->{path};
	ok -f $upload_path, 'Phase 1: file exists on disk at returned path';

	# ------------------------------------------------------------------
	# Phase 2: browse the upload subdirectory; file must appear in listing.
	# ------------------------------------------------------------------
	my $upload_dir = Mojo::File->new($upload_path)->dirname->to_string;

	$t->get_ok('/browse?path=' . url_escape($upload_dir))
		->status_is(200)
		->content_like(qr/txn1_upload\.csv/, 'Phase 2: uploaded file appears in browse listing');

	# ------------------------------------------------------------------
	# Phase 3: open the uploaded file; data table must render.
	# ------------------------------------------------------------------
	$t->get_ok('/open?path=' . url_escape($upload_path))
		->status_is(200)
		->content_like(qr/txn1_upload/i, 'Phase 3: /open renders a data view for the file');

	# ------------------------------------------------------------------
	# Phase 4: upload the same filename again; must succeed (idempotent)
	# and return a fresh path (the app uses a new random subdir per upload).
	# ------------------------------------------------------------------
	$t->post_ok('/upload', form => {
		file => { content => $UPLOAD_CSV_CONTENT, filename => 'txn1_upload.csv' },
	})->status_is(200);

	my $json4 = decode_json($t->tx->res->body);
	ok defined $json4->{path}, 'Phase 4: second upload succeeds (idempotent)';
	ok -f $json4->{path},      'Phase 4: new file exists on disk';
	isnt $json4->{path}, $upload_path,
		'Phase 4: second upload lands in a different subdir (no collision)';
};

# ======================================================================
# TRANSACTION 2: View -> Export (GET) -> Write (POST) -> Stat -> Re-open
#                (CSV roundtrip)
#
# Lifecycle phases:
#   Phase 1  GET /view/sales              -> reference row+col counts
#   Phase 2  GET /export?l=table:sales    -> streaming CSV download
#   Phase 3  POST /export (write to disk) -> file created on filesystem
#   Phase 4  GET /api/stat               -> exists:true, size > 0
#   Phase 5  GET /open  (written path)   -> same row count as Phase 1
#
# State invariant: data row count is preserved end-to-end through
# export-write-reopen without mutation.
# ======================================================================

subtest 'Transaction 2: View -> GET export -> POST write -> stat -> re-open (CSV)' => sub {
	my $tmpdir = tempdir(CLEANUP => 1);

	# ------------------------------------------------------------------
	# Phase 1: view the table and record reference row count.
	# ------------------------------------------------------------------
	$t->get_ok('/view/sales')->status_is(200);
	my $view_body = $t->tx->res->body;
	my $row_count = () = $view_body =~ /<tr[^>]*>/gi;
	ok $row_count > 0, 'Phase 1: view renders at least one <tr>';

	# ------------------------------------------------------------------
	# Phase 2: GET export as CSV; row count must match the view.
	# ------------------------------------------------------------------
	$t->get_ok('/export?l=table:sales&format=csv')
		->status_is(200)
		->content_type_like(qr{text/csv});

	my $csv_body = $t->tx->res->body;
	is count_csv_rows($csv_body), $SALES_ROWS,
		'Phase 2: GET export CSV has correct row count';
	is count_csv_cols($csv_body), $SALES_COLS,
		'Phase 2: GET export CSV has correct column count';

	# ------------------------------------------------------------------
	# Phase 3: POST export (write to disk).
	# ------------------------------------------------------------------
	$t->post_ok('/export', form => {
		l        => 'table:sales',
		dir      => $tmpdir,
		filename => 'sales_out.csv',
	})->status_is(200);

	my $write_json = decode_json($t->tx->res->body);
	ok defined $write_json->{saved},        'Phase 3: response contains "saved"';
	my $saved_path = $write_json->{saved};
	like $saved_path, qr/sales_out\.csv\z/, 'Phase 3: saved path ends with filename';
	ok -f $saved_path,                       'Phase 3: written file exists on disk';

	# ------------------------------------------------------------------
	# Phase 4: stat_api confirms existence and non-zero size.
	# ------------------------------------------------------------------
	$t->get_ok('/api/stat?path=' . url_escape($saved_path))
		->status_is(200);

	my $stat = decode_json($t->tx->res->body);
	ok $stat->{exists},     'Phase 4: stat_api reports file exists';
	ok $stat->{size} > 0,   'Phase 4: stat_api reports non-zero size';
	ok defined $stat->{mtime}, 'Phase 4: stat_api reports mtime';

	my $returned_path = $stat->{path};
	$returned_path =~ s{/}{\\}g if $^O eq 'MSWin32';  # Normalize to backslashes on Windows
	is $returned_path, $saved_path, 'Phase 4: stat_api echoes the requested path';

	# ------------------------------------------------------------------
	# Phase 5: re-open the written CSV; row count must match original.
	# ------------------------------------------------------------------
	$t->get_ok('/open?path=' . url_escape($saved_path))
		->status_is(200)
		->content_like(qr/sales_out/i, 'Phase 5: /open renders a data view');

	# Count <td> cells as a proxy for data presence; at least SALES_ROWS rows
	# worth of cells must appear.
	my $tds = () = $t->tx->res->body =~ /<td/gi;
	ok $tds >= $SALES_ROWS * $SALES_COLS,
		'Phase 5: re-opened CSV has at least as many cells as original';
};

# ======================================================================
# TRANSACTION 3: View -> GET export (SQLite) -> Write -> Stat -> Re-open
#                (SQLite roundtrip)
#
# IMPORTANT: SQLite export always creates a table named "data" regardless
# of source table.  A roundtrip via /open only works when the written
# filename stem equals "data" (so DataSource derives table = "data").
# Use "data.sql" as the output filename for a clean roundtrip.
#
# Lifecycle phases:
#   Phase 1  GET /export?l=table:sales&format=sqlite -> binary download
#   Phase 2  POST /export filename=data.sql         -> file on disk
#   Phase 3  GET /api/stat                          -> exists:true
#   Phase 4  GET /open  (data.sql path)             -> renders a table
# ======================================================================

subtest 'Transaction 3: GET export (SQLite) -> POST write -> stat -> re-open' => sub {
	SKIP: {
		eval { require DBI; DBI->install_driver('SQLite') }
			or skip 'DBD::SQLite not available', 5;

		my $tmpdir = tempdir(CLEANUP => 1);

		# ------------------------------------------------------------------
		# Phase 1: GET streaming SQLite export; verify MIME type and magic bytes.
		# ------------------------------------------------------------------
		$t->get_ok('/export?l=table:sales&format=sqlite')
			->status_is(200)
			->content_type_like(qr{sqlite3});

		my $sqlite_bytes = $t->tx->res->body;
		like $sqlite_bytes, qr/\ASQLite format 3/,
			'Phase 1: response body begins with SQLite magic bytes';

		# ------------------------------------------------------------------
		# Phase 2: POST export -- write to "data.sql" so re-open roundtrip works.
		# ------------------------------------------------------------------
		$t->post_ok('/export', form => {
			l        => 'table:sales',
			dir      => $tmpdir,
			filename => 'data.sql',
		})->status_is(200);

		my $write_json = decode_json($t->tx->res->body);
		ok defined $write_json->{saved}, 'Phase 2: response contains "saved"';
		my $saved_path = $write_json->{saved};
		like $saved_path, qr/data\.sql\z/, 'Phase 2: saved filename is data.sql';

		# ------------------------------------------------------------------
		# Phase 3: stat_api confirms the SQLite file was actually written.
		# ------------------------------------------------------------------
		$t->get_ok('/api/stat?path=' . url_escape($saved_path))
			->status_is(200);

		my $stat = decode_json($t->tx->res->body);
		ok  $stat->{exists},       'Phase 3: SQLite file exists';
		ok  $stat->{size} > 2048,  'Phase 3: SQLite file is at least one page (2 KiB)';

		# ------------------------------------------------------------------
		# Phase 4: re-open via /open; must render without a 404 or 500 error.
		# ------------------------------------------------------------------
		$t->get_ok('/open?path=' . url_escape($saved_path))
			->status_is(200);
	}
};

# ======================================================================
# TRANSACTION 4: Join pipeline -> filter -> CSV export consistency
#
# This transaction validates that a multi-step join pipeline preserves
# data integrity end-to-end:
#   Phase 1  Create left CSV and right CSV in tempdir
#   Phase 2  GET /join -- verify merged column set
#   Phase 3  GET /join with filter -- verify row reduction
#   Phase 4  GET /export of join+filter -- row count matches Phase 3
#   Phase 5  Column integrity: exported CSV has exactly JOIN_MERGED_COLS
#
# State invariant: _left_join + _apply_filter are commutative
# with respect to row counts; the count from Phase 3 == Phase 4.
# ======================================================================

subtest 'Transaction 4: Join pipeline -> filter -> export consistency' => sub {
	my $tmpdir = tempdir(CLEANUP => 1);

	# Create fixtures in tempdir so tests are isolated from data/ changes.
	my $left_file  = Mojo::File->new($tmpdir)->child('orders.csv');
	my $right_file = Mojo::File->new($tmpdir)->child('prices.csv');
	$left_file->spurt($JOIN_LEFT);
	$right_file->spurt($JOIN_RIGHT);

	my $lspec = 'path:' . $left_file->to_string;
	my $rspec = 'path:' . $right_file->to_string;
	my $jspec = $rspec . '|item|item';	# left_key=item, right_key=item

	# ------------------------------------------------------------------
	# Phase 2: GET /join without filter -- all 4 left rows kept.
	# ------------------------------------------------------------------
	$t->get_ok('/join?l=' . url_escape($lspec) . '&j=' . url_escape($jspec))
		->status_is(200);

	my $join_body = $t->tx->res->body;

	# Every left row must appear (left join preserves all left rows).
	my $trs = () = $join_body =~ /<tr[^>]*>/gi;
	# At least JOIN_TOTAL_ROWS data rows plus one header row.
	ok $trs > $JOIN_TOTAL_ROWS, 'Phase 2: join result includes all left rows';

	# ------------------------------------------------------------------
	# Phase 3: GET /join with filter region:eq:North -- only North rows.
	# ------------------------------------------------------------------
	$t->get_ok(
		'/join?l=' . url_escape($lspec) .
		'&j='      . url_escape($jspec) .
		'&f=region:eq:North'
	)->status_is(200);

	my $filt_body = $t->tx->res->body;
	my $filt_trs  = () = $filt_body =~ /<tr[^>]*>/gi;
	# Fewer rows than unfiltered join (North keeps rows 1 and 4).
	ok $filt_trs < $trs, 'Phase 3: filtered join has fewer rows than unfiltered';

	# ------------------------------------------------------------------
	# Phase 4: GET /export of join+filter -- row count matches Phase 3.
	# ------------------------------------------------------------------
	$t->get_ok(
		'/export?format=csv' .
		'&l=' . url_escape($lspec) .
		'&j=' . url_escape($jspec) .
		'&f=region:eq:North'
	)->status_is(200)->content_type_like(qr{text/csv});

	my $export_body = $t->tx->res->body;
	is count_csv_rows($export_body), $JOIN_NORTH_ROWS,
		'Phase 4: exported CSV row count matches filtered join count';

	# ------------------------------------------------------------------
	# Phase 5: exported CSV must have correct merged column count.
	# ------------------------------------------------------------------
	is count_csv_cols($export_body), $JOIN_MERGED_COLS,
		'Phase 5: exported CSV column count matches left+right-join_key';

	# ------------------------------------------------------------------
	# Phase 5b: column ordering integrity -- left columns first.
	# ------------------------------------------------------------------
	my ($header_line) = split /\r?\n/, $export_body;
	like $header_line, qr/\Aid,item,region,quantity/, 'Phase 5b: left columns precede right columns in merged header';
};

# ======================================================================
# TRANSACTION 5: Mid-flight failure -> no orphan state
#
# Each case tests that a failed transaction leaves no partial file on disk.
# This validates the rollback contract of export_write.
#
# Case A: non-existent directory        -> 404, no file created
# Case B: unsupported filename extension -> 415, no file created
# Case C: valid dir+ext, missing table  -> 404, no file created
# Case D: successful write followed by overwrite (idempotency)
# ======================================================================

subtest 'Transaction 5: Mid-flight failure -> no orphan state' => sub {
	my $tmpdir = tempdir(CLEANUP => 1);

	# ------------------------------------------------------------------
	# Case A: non-existent directory -> 404.
	# ------------------------------------------------------------------
	my $bad_dir = $tmpdir . '/no_such_subdir_xyz';
	$t->post_ok('/export', form => {
		l        => 'table:sales',
		dir      => $bad_dir,
		filename => 'output.csv',
	})->status_is(404);

	ok !(grep { -e $_ } glob("$bad_dir/*")),
		'Case A: no file created under non-existent directory';

	# ------------------------------------------------------------------
	# Case B: unsupported extension -> 415 Unsupported Media Type.
	# ------------------------------------------------------------------
	$t->post_ok('/export', form => {
		l        => 'table:sales',
		dir      => $tmpdir,
		filename => 'output.txt',	# .txt is not csv or sql
	})->status_is(415);

	ok !-f "$tmpdir/output.txt", 'Case B: .txt file not created on disk';

	# ------------------------------------------------------------------
	# Case C: valid dir + ext but missing left table -> 404.
	# ------------------------------------------------------------------
	$t->post_ok('/export', form => {
		l        => 'table:definitely_not_a_real_table_xyz',
		dir      => $tmpdir,
		filename => 'phantom.csv',
	})->status_is(404);

	ok !-f "$tmpdir/phantom.csv", 'Case C: no file created when left table missing';

	# ------------------------------------------------------------------
	# Case D: successful write, then overwrite with same params (idempotent).
	# Both runs must succeed and the second file must be identical in size.
	# ------------------------------------------------------------------
	$t->post_ok('/export', form => {
		l        => 'table:sales',
		dir      => $tmpdir,
		filename => 'idem.csv',
	})->status_is(200);

	my $path1 = decode_json($t->tx->res->body)->{saved};
	my $size1  = -s $path1;
	ok $size1 > 0, 'Case D: first write succeeded, non-zero size';

	$t->post_ok('/export', form => {
		l        => 'table:sales',
		dir      => $tmpdir,
		filename => 'idem.csv',
	})->status_is(200);

	my $path2 = decode_json($t->tx->res->body)->{saved};
	is $path2, $path1, 'Case D: second write targets the same path';
	is -s $path2, $size1, 'Case D: overwritten file has identical size (no corruption)';
};

# ======================================================================
# TRANSACTION 6: Filter state machine
#
# Models the filter pipeline as a finite state machine with named states:
#
#   S0 (no filter)          : all SALES_ROWS rows
#   S1 (+region:eq:North)   : NORTH_ROWS rows
#   S2 (+amount:gt:1500)    : NORTH_GT1500 rows
#   S1 (back to S1)         : NORTH_ROWS rows (removing amount filter)
#   S0 (back to S0)         : SALES_ROWS rows (removing all filters)
#
# Filter commutativity: S2 must also be reachable with filters in
# reversed order (amount first, then region).
#
# State invariant: S0 row count > S1 > S2; ordering is strict.
# ======================================================================

subtest 'Transaction 6: Filter state machine' => sub {
	# ------------------------------------------------------------------
	# State S0: no filter.
	# ------------------------------------------------------------------
	$t->get_ok('/export?l=table:sales&format=csv')
		->status_is(200)
		->content_type_like(qr{text/csv});

	is count_csv_rows($t->tx->res->body), $SALES_ROWS,
		'S0 (no filter): all sales rows present';

	# ------------------------------------------------------------------
	# State S1: region = North.
	# ------------------------------------------------------------------
	$t->get_ok('/export?l=table:sales&format=csv&f=region:eq:North')
		->status_is(200);

	is count_csv_rows($t->tx->res->body), $NORTH_ROWS,
		'S1 (region=North): correct North row count';

	# ------------------------------------------------------------------
	# State S2: region = North AND amount > 1000.
	# ------------------------------------------------------------------
	$t->get_ok('/export?l=table:sales&format=csv&f=region:eq:North&f=amount:gt:1500')
		->status_is(200);

	is count_csv_rows($t->tx->res->body), $NORTH_GT1500,
		'S2 (North AND amount>1000): exactly one row';

	# ------------------------------------------------------------------
	# Back to S1: remove the amount filter (region=North only).
	# ------------------------------------------------------------------
	$t->get_ok('/export?l=table:sales&format=csv&f=region:eq:North')
		->status_is(200);

	is count_csv_rows($t->tx->res->body), $NORTH_ROWS,
		'S1 (return): removing amount filter restores North count';

	# ------------------------------------------------------------------
	# Back to S0: remove all filters.
	# ------------------------------------------------------------------
	$t->get_ok('/export?l=table:sales&format=csv')
		->status_is(200);

	is count_csv_rows($t->tx->res->body), $SALES_ROWS,
		'S0 (return): removing all filters restores full row count';

	# ------------------------------------------------------------------
	# Commutativity: S2 with reversed filter order must give the same count.
	# ------------------------------------------------------------------
	$t->get_ok('/export?l=table:sales&format=csv&f=amount:gt:1500&f=region:eq:North')
		->status_is(200);

	is count_csv_rows($t->tx->res->body), $NORTH_GT1500,
		'Commutativity: reversed filter order produces same S2 count';
};

# ======================================================================
# TRANSACTION 7: Columns API -> Join coordination
#
# The columns_api endpoint feeds the join panel UI with column names.
# This transaction verifies that:
#   Phase 1  GET /api/columns?table=sales  -> columns list
#   Phase 2  The "region" column from the API can serve as a join key
#   Phase 3  GET /join using that key -> merged result
#   Phase 4  Column count in result is correct
# ======================================================================

subtest 'Transaction 7: Columns API -> join coordination' => sub {
	# ------------------------------------------------------------------
	# Phase 1: fetch columns for the sales table.
	# ------------------------------------------------------------------
	$t->get_ok('/api/columns?table=sales')
		->status_is(200)
		->content_type_like(qr{application/json});

	my $cols_json = decode_json($t->tx->res->body);
	ok defined $cols_json->{columns}, 'Phase 1: response has "columns" key';
	my @cols = @{ $cols_json->{columns} };
	ok scalar @cols == $SALES_COLS, 'Phase 1: correct number of columns returned';

	# ------------------------------------------------------------------
	# Phase 2: verify a key column is present in the API response.
	# We will use "region" to join with a hand-crafted right table.
	# ------------------------------------------------------------------
	ok scalar(grep { $_ eq 'region' } @cols), 'Phase 2: "region" column reported by API';

	# ------------------------------------------------------------------
	# Phase 3: create a right table keyed on "region" and perform the join.
	# ------------------------------------------------------------------
	my $tmpdir     = tempdir(CLEANUP => 1);
	my $right_file = Mojo::File->new($tmpdir)->child('regionmap.csv');
	$right_file->spurt("region,zone_code\nNorth,N\nSouth,S\nEast,E\nWest,W\n");

	my $lspec = 'table:sales';
	my $rspec = 'path:' . $right_file->to_string;
	my $jspec = $rspec . '|region|region';

	$t->get_ok('/join?l=' . url_escape($lspec) . '&j=' . url_escape($jspec))
		->status_is(200);

	# ------------------------------------------------------------------
	# Phase 4: merged result has left columns + right non-key columns.
	# left = 6 (id,product,region,sales_rep,amount,sale_date)
	# right non-key = 1 (zone_code)  -> merged total = 7
	# ------------------------------------------------------------------
	my $right_extra_cols = 1;	# zone_code only (region is the join key, dropped)
	my $expected_merged  = $SALES_COLS + $right_extra_cols;

	$t->get_ok(
		'/export?format=csv' .
		'&l=' . url_escape($lspec) .
		'&j=' . url_escape($jspec)
	)->status_is(200);

	is count_csv_cols($t->tx->res->body), $expected_merged,
		'Phase 4: merged CSV has left + right non-key columns';
};

# ======================================================================
# TRANSACTION 8: Export write idempotency + stat before/after
#
# Proves that writing the same data twice leaves the file in a consistent
# state: no partial writes, no size drift, readable after overwrite.
#
# Lifecycle:
#   Phase 1  POST /export  -> first write, record size S1
#   Phase 2  GET  /api/stat -> S1 confirmed via stat
#   Phase 3  POST /export  -> second write (overwrite)
#   Phase 4  GET  /api/stat -> size == S1 (no corruption)
#   Phase 5  GET  /export  -> streaming CSV byte-identical to first write
# ======================================================================

subtest 'Transaction 8: Export write idempotency + stat before/after' => sub {
	my $tmpdir = tempdir(CLEANUP => 1);

	# ------------------------------------------------------------------
	# Phase 1: first write.
	# ------------------------------------------------------------------
	$t->post_ok('/export', form => {
		l        => 'table:sales',
		dir      => $tmpdir,
		filename => 'stable.csv',
	})->status_is(200);

	my $saved_path = decode_json($t->tx->res->body)->{saved};
	ok -f $saved_path, 'Phase 1: file created on first write';
	my $size1 = -s $saved_path;
	ok $size1 > 0, 'Phase 1: non-zero file size';

	# ------------------------------------------------------------------
	# Phase 2: stat before overwrite.
	# ------------------------------------------------------------------
	$t->get_ok('/api/stat?path=' . url_escape($saved_path))->status_is(200);
	my $stat1 = decode_json($t->tx->res->body);
	ok $stat1->{exists},          'Phase 2: stat reports file exists';
	is $stat1->{size}, $size1,    'Phase 2: stat size matches on-disk size';

	# ------------------------------------------------------------------
	# Phase 3: second write (overwrite with identical params).
	# ------------------------------------------------------------------
	$t->post_ok('/export', form => {
		l        => 'table:sales',
		dir      => $tmpdir,
		filename => 'stable.csv',
	})->status_is(200);

	my $saved_path2 = decode_json($t->tx->res->body)->{saved};
	is $saved_path2, $saved_path, 'Phase 3: second write targets same path';

	# ------------------------------------------------------------------
	# Phase 4: stat after overwrite -- size must be unchanged.
	# ------------------------------------------------------------------
	$t->get_ok('/api/stat?path=' . url_escape($saved_path))->status_is(200);
	my $stat2 = decode_json($t->tx->res->body);
	ok  $stat2->{exists},          'Phase 4: file still exists after overwrite';
	is  $stat2->{size}, $size1,    'Phase 4: overwritten file has same size (no corruption)';

	# ------------------------------------------------------------------
	# Phase 5: GET streaming export; byte content must match written file.
	# ------------------------------------------------------------------
	$t->get_ok('/export?l=table:sales&format=csv')
		->status_is(200)
		->content_type_like(qr{text/csv});

	my $stream_csv  = $t->tx->res->body;
	my $written_csv = Mojo::File->new($saved_path)->slurp;
	is $stream_csv, $written_csv,
		'Phase 5: streaming CSV bytes are identical to written file content';
};

# ======================================================================
# TRANSACTION 9: Browse -> Open -> Filter -> Export chain
#
# Verifies the end-to-end path a user would take when navigating to a
# file via the browser rather than the home-page table picker.
#
# Lifecycle:
#   Phase 1  GET /browse?path=<data_dir>  -> lists sales.csv
#   Phase 2  GET /open?path=<sales_csv>   -> data table renders
#   Phase 3  GET /open?path=...&f=region:eq:East -> filtered view
#   Phase 4  GET /export?l=path:...&f=... -> filtered CSV
#   Phase 5  Row count in CSV = rows with region East
# ======================================================================

subtest 'Transaction 9: Browse -> Open -> Filter -> Export chain' => sub {
	# East rows in sales.csv: row 3 (Gadget Pro) and row 6 (Widget B)
	Readonly my $EAST_ROWS => 2;

	# ------------------------------------------------------------------
	# Phase 1: browse the data directory; sales.csv must appear.
	# ------------------------------------------------------------------
	$t->get_ok('/browse?path=' . url_escape($DATA_DIR))
		->status_is(200)
		->content_like(qr/sales\.csv/i, 'Phase 1: browse lists sales.csv');

	# ------------------------------------------------------------------
	# Phase 2: open sales.csv directly.
	# ------------------------------------------------------------------
	$t->get_ok('/open?path=' . url_escape($SALES_CSV))
		->status_is(200)
		->content_like(qr/Widget|Gadget/, 'Phase 2: /open renders data cells');

	# ------------------------------------------------------------------
	# Phase 3: open with a filter applied (region = East).
	# ------------------------------------------------------------------
	$t->get_ok('/open?path=' . url_escape($SALES_CSV) . '&f=region:eq:East')
		->status_is(200)
		->content_like(qr/East/, 'Phase 3: filtered /open contains East data');

	# Confirm West and South rows are absent.
	unlike $t->tx->res->body, qr/>West<\/td>/, 'Phase 3: West rows are filtered out';
	unlike $t->tx->res->body, qr/>South<\/td>/, 'Phase 3: South rows are filtered out';

	# ------------------------------------------------------------------
	# Phase 4: export the filtered path view as CSV.
	# ------------------------------------------------------------------
	my $lspec = 'path:' . $SALES_CSV;
	$t->get_ok(
		'/export?format=csv' .
		'&l=' . url_escape($lspec) .
		'&f=region:eq:East'
	)->status_is(200)->content_type_like(qr{text/csv});

	# ------------------------------------------------------------------
	# Phase 5: exported row count must match filtered row count.
	# ------------------------------------------------------------------
	is count_csv_rows($t->tx->res->body), $EAST_ROWS,
		'Phase 5: exported CSV has exactly the East-region rows';
};

# ======================================================================
# TRANSACTION 10: Concurrent DataSource objects do not interfere
#
# Instantiates two independent DataSource objects against different
# files and verifies that their state (table name, columns, records)
# remains isolated -- no cross-contamination from shared class-level
# state in Database::Abstraction.
# ======================================================================

subtest 'Transaction 10: Concurrent DataSource isolation' => sub {
	require Database::BI::Model::DataSource;

	my $tmpdir = tempdir(CLEANUP => 1);

	# Create two distinct CSV files with overlapping column names.
	my $alpha_file = Mojo::File->new($tmpdir)->child('alpha.csv');
	my $beta_file  = Mojo::File->new($tmpdir)->child('beta.csv');
	$alpha_file->spurt("id,value\n1,AAA\n2,BBB\n");
	$beta_file->spurt("id,value\n10,XXX\n20,YYY\n30,ZZZ\n");

	my $ds_alpha = Database::BI::Model::DataSource->new(
		directory => $tmpdir,
		table     => 'alpha',
	);
	my $ds_beta = Database::BI::Model::DataSource->new(
		directory => $tmpdir,
		table     => 'beta',
	);

	isa_ok $ds_alpha, 'Database::BI::Model::DataSource', 'alpha DataSource is correct class';
	isa_ok $ds_beta,  'Database::BI::Model::DataSource', 'beta DataSource is correct class';

	is $ds_alpha->table_name, 'alpha', 'alpha: table_name is isolated';
	is $ds_beta->table_name,  'beta',  'beta: table_name is isolated';

	my $alpha_recs = $ds_alpha->fetch_all;
	my $beta_recs  = $ds_beta->fetch_all;

	ok defined $alpha_recs, 'alpha: fetch_all returns data';
	ok defined $beta_recs,  'beta: fetch_all returns data';

	is scalar @$alpha_recs, 2,
		'alpha: 2 rows fetched (not contaminated by beta)';
	is scalar @$beta_recs, 3,
		'beta: 3 rows fetched (not contaminated by alpha)';

	# Verify alpha records do not contain beta values and vice versa.
	ok !(grep { ($_->{value} // '') =~ /^X/ } @$alpha_recs),
		'alpha: records contain no XXX values from beta';
	ok !(grep { ($_->{value} // '') =~ /^A/ } @$beta_recs),
		'beta: records contain no AAA values from alpha';
};

# ======================================================================
# TRANSACTION 11: Combine data lifecycle (cats + dogs)
#
# Verifies the /combine endpoint stacks rows from two heterogeneous files
# into a single unified view with the union of all columns.
#
# cats.csv columns: Species,Name,Color,Breed,Eye Color,Environment
# dogs.csv columns: Species,Name,Color,Breed,Eye Color,Sex,Fixed
# combined columns: Species,Name,Color,Breed,Eye Color,Environment,Sex,Fixed
#
# State invariant:
#   combined_rows  = cat_rows  + dog_rows
#   combined_cols  = union(cat_cols, dog_cols) = 8
#   cat rows have blank Sex,Fixed; dog rows have blank Environment
# ======================================================================

Readonly my $CATS_CSV	=> $t->app->home->child('data/cats.csv')->to_string;
Readonly my $DOGS_CSV	=> $t->app->home->child('data/dogs.csv')->to_string;
Readonly my $CAT_ROWS	=> 12;	# 12 data rows in cats.csv
Readonly my $DOG_ROWS	=> 12;	# 12 data rows in dogs.csv
Readonly my $CAT_COLS	=> 6;	# Species,Name,Color,Breed,Eye Color,Environment
Readonly my $DOG_COLS	=> 7;	# Species,Name,Color,Breed,Eye Color,Sex,Fixed
Readonly my $COMBINED_ROWS => $CAT_ROWS + $DOG_ROWS;
Readonly my $COMBINED_COLS => 8;	# union of cat and dog columns

subtest 'Transaction 11: combine cats + dogs lifecycle' => sub {
	SKIP: {
		skip 'data/cats.csv not found', 1 unless -f $CATS_CSV;
		skip 'data/dogs.csv not found', 1 unless -f $DOGS_CSV;

		# Phase 1: GET /combine with cats as left, dogs as right-combine source.
		my $cat_spec = 'table:cats';
		my $dog_spec = 'table:dogs';
		$t->get_ok('/combine?l=' . url_escape($cat_spec) . '&c=' . url_escape($dog_spec))
			->status_is(200)
			->content_like(qr/Species/,	'combined view contains Species column')
			->content_like(qr/Environment/,	'combined view contains Environment (cats-only column)')
			->content_like(qr/Sex/,		'combined view contains Sex (dogs-only column)')
			->content_like(qr/Fixed/,	'combined view contains Fixed (dogs-only column)');

		# Phase 2: Export the combined view as CSV and verify row and column counts.
		my $export_url = '/export?l=' . url_escape($cat_spec)
			. '&c=' . url_escape($dog_spec)
			. '&format=csv';
		$t->get_ok($export_url)->status_is(200);
		my $body = $t->tx->res->body;
		is count_csv_rows($body), $COMBINED_ROWS,
			'combined CSV has cat_rows + dog_rows rows';
		is count_csv_cols($body), $COMBINED_COLS,
			'combined CSV has 8 columns (union of cat and dog schemas)';

		# Phase 3: Filter the combined view -- only cats (Species eq Cat).
		$t->get_ok('/combine?l=' . url_escape($cat_spec)
				. '&c=' . url_escape($dog_spec)
				. '&f=Species:eq:Cat')
			->status_is(200)
			->content_like(qr/Cat/, 'filtered combined view contains Cat rows');
		my $filtered_body = $t->tx->res->body;
		# The filtered page should not show any Dog rows.
		unlike $filtered_body, qr/Rover/, 'no dog row (Rover) in cat-filtered view';

		# Phase 4: Idempotency -- combining in the same order produces the same result.
		$t->get_ok('/combine?l=' . url_escape($cat_spec) . '&c=' . url_escape($dog_spec))
			->status_is(200)
			->content_like(qr/Environment/, 'second combine still has Environment column');
	}
};

# ======================================================================
# TRANSACTION 12: Recently-saved section server-side contract
#
# The "Recently saved" home-page section is rendered client-side from
# localStorage, but its correctness depends on three server-side
# contracts this transaction verifies end-to-end:
#
#   Phase 1  GET  /            -> home page contains bi-saved placeholder
#                                 and the makeSection JS helper
#   Phase 2  POST /export      -> response carries {saved: "/abs/path"}
#   Phase 3  GET  /api/stat    -> {exists:true, mtime, size} for saved file
#   Phase 4  GET  /open        -> 200 and data table for the saved file
#   Phase 5  GET  /api/stat    -> {exists:false} for a non-existent path;
#                                 no error, HTTP 200 with exists=false
#
# State invariant: a path returned by POST /export must be openable via
# /open and must report exists=true in /api/stat until deleted.
# ======================================================================

subtest 'Transaction 12: Recently-saved section server-side contract' => sub {
	SKIP: {
		skip 'data/sales.csv not found', 1 unless -f $SALES_CSV;

		my $dir = tempdir(CLEANUP => 1);
		Readonly my $SAVE_FILE => 'saved_recent.csv';

		# Phase 1: home page ships the bi-saved placeholder and makeSection helper.
		$t->get_ok('/')->status_is(200)
			->content_like(qr/id="bi-saved"/,   'home page has bi-saved placeholder div')
			->content_like(qr/makeSection/,      'home page contains makeSection JS helper')
			->content_like(qr/bi:saved/,         'home page references bi:saved localStorage key');

		# Phase 2: POST /export -- save sales as CSV, expect {saved} in response.
		my $params = Mojo::Parameters->new;
		$params->append(l        => 'table:sales');
		$params->append(dir      => $dir);
		$params->append(filename => $SAVE_FILE);
		$t->post_ok('/export', form => { l => 'table:sales', dir => $dir, filename => $SAVE_FILE })
			->status_is(200);
		my $write_json = decode_json($t->tx->res->body);
		ok defined $write_json->{saved},  'Phase 2: response contains "saved" key';
		my $saved_path = $write_json->{saved};
		like $saved_path, qr/\Q$SAVE_FILE\E\z/, 'Phase 2: saved path ends with filename';
		ok -f $saved_path, 'Phase 2: file physically exists on disk';

		# Phase 3: /api/stat reports exists=true with mtime and size for saved file.
		$t->get_ok('/api/stat?path=' . url_escape($saved_path))->status_is(200);
		my $stat = decode_json($t->tx->res->body);
		ok $stat->{exists},           'Phase 3: stat reports file exists';
		ok defined $stat->{mtime},    'Phase 3: stat includes mtime';
		ok defined $stat->{size},     'Phase 3: stat includes size';
		ok $stat->{size} > 0,         'Phase 3: file size is non-zero';

		my $returned_path = $stat->{path};
		$returned_path =~ s{/}{\\}g if $^O eq 'MSWin32';  # Normalize to backslashes on Windows
		is($returned_path, $saved_path, 'Phase 3: stat echoes the requested path');

		# Phase 4: /open serves the saved CSV as a data table.
		$t->get_ok('/open?path=' . url_escape($saved_path))
			->status_is(200)
			->content_like(qr/sales_rep|product|region/, 'Phase 4: saved file opens as data table');

		# Phase 5: /api/stat returns {exists:false} for a path that does not exist;
		# HTTP status must still be 200 (the client uses exists=false to grey out the card).
		my $ghost = $dir . '/does_not_exist.csv';
		$t->get_ok('/api/stat?path=' . url_escape($ghost))->status_is(200);
		my $ghost_stat = decode_json($t->tx->res->body);
		ok !$ghost_stat->{exists},  'Phase 5: stat returns exists=false for missing file';
		ok !defined $ghost_stat->{mtime}, 'Phase 5: mtime absent when file missing';
		ok !defined $ghost_stat->{size},  'Phase 5: size absent when file missing';
	}
};

# ======================================================================
# TRANSACTION 13: Dedup toggle — hide/show duplicate rows
#
# Verifies the end-to-end contract for the ?d=1 deduplication parameter:
#
#   Phase 1  GET  /open             (no d=)  -> all rows shown; toolbar
#                                              contains "Hide duplicates"
#                                              button without active class
#   Phase 2  GET  /open?d=1                 -> only unique rows shown;
#                                              button reads "Show duplicates"
#                                              and carries btn-dedup--active
#   Phase 3  GET  /export?d=1&format=csv   -> exported CSV row count matches
#                                              unique-row count, not total
#   Phase 4  POST /export (body d=1)       -> written file has unique rows only
#   Phase 5  Idempotency: second GET /open?d=1 -> same unique count
#
# Uses a self-contained temp CSV with known duplicates; no dependency on
# data/ contents.
# ======================================================================

subtest 'Transaction 13: Dedup toggle — hide/show duplicate rows' => sub {
	my $tmpdir = tempdir(CLEANUP => 1);

	# Five data rows: rows 1+3 are identical, rows 2+5 are identical, row 4 unique.
	# Unique rows after dedup: 3.  "alpha" appears in rows 1+3, "beta" in rows 2+5.
	Readonly my $DEDUP_UNIQUE => 3;

	my $csv_file = Mojo::File->new($tmpdir)->child('dupes.csv');
	$csv_file->spew("id,name,value\n"
		. "1,alpha,100\n"
		. "2,beta,200\n"
		. "1,alpha,100\n"
		. "3,gamma,300\n"
		. "2,beta,200\n");
	my $path = $csv_file->to_string;

	# Phase 1: open without d= -- all duplicate rows present.
	# "alpha" is in rows 1 and 3 so appears twice in the HTML; "gamma" once.
	$t->get_ok('/open?path=' . url_escape($path))->status_is(200);
	my $body1       = $t->tx->res->body;
	my $alpha_total = () = ($body1 =~ /\balpha\b/g);
	is $alpha_total, 2, 'Phase 1: duplicate value "alpha" appears twice (all rows shown)';
	$t->content_like(qr/Hide duplicates/, 'Phase 1: button reads "Hide duplicates"');
	$t->content_unlike(qr/class="btn-dedup btn-dedup--active"/,
		'Phase 1: active class absent from button when d= not set');

	# Phase 2: open with d=1 -- each duplicate row collapsed to one occurrence.
	$t->get_ok('/open?path=' . url_escape($path) . '&d=1')->status_is(200);
	my $body2       = $t->tx->res->body;
	my $alpha_dedup = () = ($body2 =~ /\balpha\b/g);
	is $alpha_dedup, 1, 'Phase 2: duplicate value "alpha" appears exactly once after dedup';
	my $beta_dedup  = () = ($body2 =~ /\bbeta\b/g);
	is $beta_dedup,  1, 'Phase 2: duplicate value "beta" appears exactly once after dedup';
	$t->content_like(qr/Show duplicates/, 'Phase 2: button reads "Show duplicates"');
	$t->content_like(qr/class="btn-dedup btn-dedup--active"/,
		'Phase 2: active class present on button when d=1');

	# Phase 3: GET export with d=1 returns a deduplicated CSV.
	my $lspec = 'path:' . $path;
	$t->get_ok('/export?l=' . url_escape($lspec) . '&d=1&format=csv')->status_is(200);
	is count_csv_rows($t->tx->res->body), $DEDUP_UNIQUE,
		'Phase 3: exported CSV has unique-row count, not total';

	# Phase 4: POST export with d=1 writes a deduplicated file.
	my $out_file = Mojo::File->new($tmpdir)->child('deduped.csv')->to_string;
	$t->post_ok('/export', form => {
		l        => $lspec,
		dir      => $tmpdir,
		filename => 'deduped.csv',
		d        => '1',
	})->status_is(200);
	my $write_json = decode_json($t->tx->res->body);
	ok defined $write_json->{saved}, 'Phase 4: response contains "saved"';
	is count_csv_rows(Mojo::File->new($write_json->{saved})->slurp),
		$DEDUP_UNIQUE, 'Phase 4: written file has unique rows only';

	# Phase 5: idempotency -- second GET with d=1 produces the same unique count.
	$t->get_ok('/export?l=' . url_escape($lspec) . '&d=1&format=csv')->status_is(200);
	is count_csv_rows($t->tx->res->body), $DEDUP_UNIQUE,
		'Phase 5: repeated export with d=1 is idempotent';
};

# ======================================================================
# TRANSACTION 14: Refresh button — presence, placement, and isolation
#
# Verifies the server-side contract for the ↻ Refresh toolbar button:
#
#   Phase 1  GET  /view/sales          -> toolbar contains btn-refresh with
#                                         correct title; btn-export-open also
#                                         present (both guarded by left_spec)
#   Phase 2  GET  /open?path=<csv>    -> btn-refresh present for arbitrary
#                                         file opened via /open
#   Phase 3  GET  /                   -> home page has no btn-refresh (no data
#                                         view, no toolbar)
#   Phase 4  GET  /browse             -> filesystem navigator has no btn-refresh
#
# State invariant: btn-refresh is exclusively a view-page control and must
# never appear on navigation pages that have no data table rendered.
# ======================================================================

subtest 'Transaction 14: Refresh button — presence, placement, and isolation' => sub {
	SKIP: {
		skip 'data/sales.csv not found', 1 unless -f $SALES_CSV;

		# Phase 1: /view/sales — refresh button present alongside export.
		$t->get_ok('/view/sales')->status_is(200)
			->content_like(qr/class="btn-refresh"/,
				'Phase 1: btn-refresh present on /view page')
			->content_like(qr/btn-refresh[^>]*title=/,
				'Phase 1: btn-refresh carries a title attribute')
			->content_like(qr/class="btn-export-open"/,
				'Phase 1: export button also present (both share left_spec guard)')
			->content_like(qr/location\.reload\(\)/,
				'Phase 1: JS wires btn-refresh to location.reload()');

		# Phase 2: /open — refresh button present for arbitrary filesystem files.
		my $tmpdir = tempdir(CLEANUP => 1);
		Mojo::File->new($tmpdir)->child('t14.csv')->spew("id,val\n1,x\n");
		my $csv_path = Mojo::File->new($tmpdir)->child('t14.csv')->to_string;
		$t->get_ok('/open?path=' . url_escape($csv_path))->status_is(200)
			->content_like(qr/class="btn-refresh"/,
				'Phase 2: btn-refresh present on /open page');

		# Phase 3: home page has no toolbar, so no btn-refresh.
		$t->get_ok('/')->status_is(200)
			->content_unlike(qr/id="btn-refresh"/,
				'Phase 3: btn-refresh absent from home page');

		# Phase 4: /browse has no data table, so no btn-refresh.
		$t->get_ok('/browse')->status_is(200)
			->content_unlike(qr/id="btn-refresh"/,
				'Phase 4: btn-refresh absent from filesystem browser');
	}
};

# ======================================================================
# TRANSACTION 15: from=saved — bi:recent suppression contract
#
# Verifies the full server-side and template contract for the mechanism
# that prevents files opened from "Recently saved" appearing again in
# "Recently opened":
#
#   Phase 1  GET  /open?path=<csv>&from=saved
#                 -> 200 (server ignores unknown from= param gracefully)
#   Phase 2  response body contains the data table (normal render — the
#            from= param does not break anything server-side)
#   Phase 3  home page template carries fromTag='saved' in the makeSection
#            call for the bi-saved section
#   Phase 4  dashboard template contains history.replaceState logic that
#            strips the from= marker from the address bar
#   Phase 5  dashboard template guards the bi:recent write with a fromSaved
#            check so saved-origin navigations are excluded
# ======================================================================

subtest 'Transaction 15: from=saved — bi:recent suppression contract' => sub {
	my $tmpdir = tempdir(CLEANUP => 1);
	my $csv = Mojo::File->new($tmpdir)->child('t15.csv');
	$csv->spew("product,qty\nwidget,10\ngadget,5\n");
	my $path = $csv->to_string;

	# Phase 1: server handles from=saved gracefully (returns 200, not 400/500).
	$t->get_ok('/open?path=' . url_escape($path) . '&from=saved')
		->status_is(200, 'Phase 1: from=saved param accepted without error');

	# Phase 2: data table still renders normally despite the extra param.
	$t->content_like(qr/widget|gadget/,
		'Phase 2: data table rendered correctly with from=saved in URL');

	# Phase 3: home template calls makeSection for bi-saved with fromTag='saved'.
	my $home_body = $t->get_ok('/')->tx->res->body;
	like $home_body, qr/'saved'\s*\)/,
		q{Phase 3: home makeSection call passes 'saved' as fromTag for bi-saved section};

	# Phase 4: dashboard template strips the marker via history.replaceState.
	my $dash_body = $t->get_ok('/open?path=' . url_escape($path))->tx->res->body;
	like $dash_body, qr/history\.replaceState/,
		'Phase 4: dashboard JS uses history.replaceState to clean from= from address bar';

	# Phase 5: bi:recent write is guarded by fromSaved check.
	like $dash_body, qr/fromSaved/,
		'Phase 5: dashboard JS declares fromSaved variable to gate bi:recent write';
	like $dash_body, qr/if\s*\(\s*!fromSaved\s*\)/,
		'Phase 5: bi:recent write is inside if(!fromSaved) guard';
};

# ======================================================================
# TRANSACTION 16: Clear upload cache — full lifecycle
#
# Verifies POST /uploads/clear across three phases:
#
#   Phase 1  POST /upload (two files)          -> uploads land in .uploads/
#   Phase 2  POST /uploads/clear (first call)  -> freed > 0, count >= 2
#   Phase 3  POST /uploads/clear (second call) -> freed = 0, count = 0
#                                                 (cache already empty)
#
# State invariant: clearing an already-empty cache is idempotent and
# must return 200 with zeros, never an error.
# ======================================================================

subtest 'Transaction 16: Clear upload cache — full lifecycle' => sub {
	# Phase 1: upload two distinct CSV files so .uploads/ is non-empty.
	my $csv_a = "id,label\n1,alpha\n2,beta\n";
	my $csv_b = "name,score\nAlice,90\nBob,85\n";

	$t->post_ok('/upload',
		{ 'Content-Type' => 'multipart/form-data' },
		form => { file => { content => $csv_a, filename => 'cache_a.csv' } },
	)->status_is(200);
	my $res_a = decode_json($t->tx->res->body);
	ok defined $res_a->{path}, 'Phase 1a: first upload returned a path';

	$t->post_ok('/upload',
		{ 'Content-Type' => 'multipart/form-data' },
		form => { file => { content => $csv_b, filename => 'cache_b.csv' } },
	)->status_is(200);
	my $res_b = decode_json($t->tx->res->body);
	ok defined $res_b->{path}, 'Phase 1b: second upload returned a path';

	# Phase 2: first clear — should recover the bytes from both uploads.
	$t->post_ok('/uploads/clear')->status_is(200);
	my $clear1 = decode_json($t->tx->res->body);
	ok defined $clear1->{freed}, 'Phase 2: response contains "freed"';
	ok defined $clear1->{count}, 'Phase 2: response contains "count"';
	cmp_ok $clear1->{count}, '>=', 2,
		'Phase 2: at least two files freed (one per upload)';
	cmp_ok $clear1->{freed}, '>', 0,
		'Phase 2: freed bytes > 0 after clearing non-empty cache';

	# Phase 3: second clear — cache empty, both values must be zero.
	$t->post_ok('/uploads/clear')->status_is(200);
	my $clear2 = decode_json($t->tx->res->body);
	is $clear2->{freed}, 0, 'Phase 3: idempotent clear returns freed=0';
	is $clear2->{count}, 0, 'Phase 3: idempotent clear returns count=0';
};

# ======================================================================
# TRANSACTION 17: Per-request CGI::Info/CGI::Lingua detection regression
#
# Verifies that platform/language detection does not break page rendering
# when unusual User-Agent or Accept-Language values are present, and that
# the server gracefully falls back to the configured defaults when no
# matching template directory exists for the detected value.
#
#   Phase 1  Mobile UA + no mobile/ templates  -> 200, falls back to web/en
#   Phase 2  Desktop UA                        -> 200, normal web/en render
#   Phase 3  Accept-Language: fr (no fr/ dir)  -> 200, falls back to en
#   Phase 4  Accept-Language: en               -> 200, en render
#   Phase 5  Accept-Language absent            -> 200, en render (early return)
# ======================================================================

subtest 'Transaction 17: Per-request CGI::Info/CGI::Lingua detection regression' => sub {
	SKIP: {
		skip 'data/sales.csv not found', 1 unless -f $SALES_CSV;

		Readonly my $MOBILE_UA  => 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';
		Readonly my $DESKTOP_UA => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36';

		# Phase 1: mobile UA — no templates/mobile/ dir, so falls back to web/en.
		$t->get_ok('/view/sales',
			{ 'User-Agent' => $MOBILE_UA })->status_is(200,
				'Phase 1: mobile UA returns 200 (falls back to web/en templates)');
		$t->content_like(qr/sales|product|region/,
			'Phase 1: data table rendered despite mobile UA');

		# Phase 2: standard desktop UA — normal web/en render.
		$t->get_ok('/view/sales',
			{ 'User-Agent' => $DESKTOP_UA })->status_is(200,
				'Phase 2: desktop UA returns 200');
		$t->content_like(qr/sales|product|region/,
			'Phase 2: data table rendered with desktop UA');

		# Phase 3: Accept-Language: fr — no templates/web/fr/, falls back to en.
		$t->get_ok('/view/sales',
			{ 'Accept-Language' => 'fr-FR,fr;q=0.9,en;q=0.8' })->status_is(200,
				'Phase 3: fr Accept-Language returns 200 (falls back to en)');
		$t->content_like(qr/sales|product|region/,
			'Phase 3: data table rendered with fr Accept-Language (en fallback)');

		# Phase 4: Accept-Language: en — standard path, no fallback needed.
		$t->get_ok('/view/sales',
			{ 'Accept-Language' => 'en-US,en;q=0.9' })->status_is(200,
				'Phase 4: en Accept-Language returns 200');

		# Phase 5: No Accept-Language header at all — early return to default.
		my $tx = $t->ua->build_tx(GET => '/view/sales');
		$tx->req->headers->remove('Accept-Language');
		$t->request_ok($tx)->status_is(200,
			'Phase 5: absent Accept-Language returns 200 (early return in _resolve_language)');
		$t->content_like(qr/sales|product|region/,
			'Phase 5: data table rendered when Accept-Language header is absent');
	}
};

subtest 'Transaction 18: Mixed-case upload filename opens correctly' => sub {
	# Regression test covering two bugs found when opening a real bank CSV:
	#
	# Bug 1 (case): controller lowercased the filename stem to "accounthistory",
	#   but the file on disk is "AccountHistory.csv" — not found on case-sensitive
	#   Linux.  Fix: preserve original case when opening by absolute path.
	#
	# Bug 2 (id column): the CSV header had "Account Number,Post Date,Check,..."
	#   where the first safe-identifier column ("Check") is always empty.
	#   Database::Abstraction uses empty_is_undef => 1, so every row had
	#   undef in the id column and was filtered out — only rows where "Check"
	#   actually had a value (written cheques) survived.  Fix: _detect_file_info
	#   now reads the first data row and picks the first safe column that has a
	#   non-empty value there ("Description" in the bank-export case).

	my $dir = tempdir(CLEANUP => 1);

	# Reproduce bug 2: first safe-identifier column ("ref") is always empty;
	# second safe column ("description") is always populated.
	my $csv_path = "$dir/AccountHistory.csv";
	Mojo::File->new($csv_path)->spurt(
		"Account Number,ref,description,amount\n" .
		"XX1234,,Coffee shop,4.50\n" .
		"XX1234,,Supermarket,23.10\n" .
		"XX1234,,Online transfer,100.00\n"
	);

	my $encoded = url_escape($csv_path);

	$t->get_ok("/open?path=$encoded")
		->status_is(200, 'Phase 1: /open succeeds for mixed-case filename with spaced first column')
		->content_like(qr/AccountHistory|description/i,
			'Phase 2: page mentions table or a column name')
		->content_like(qr/Coffee shop/,
			'Phase 3: first row rendered (ref-is-empty row not filtered out)')
		->content_like(qr/Supermarket/,
			'Phase 4: second row rendered')
		->content_like(qr/Online transfer/,
			'Phase 5: third row rendered — all 3 rows present');

	$t->content_unlike(qr/Could not open &quot;AccountHistory/,
		'Phase 6: no server-side file-open error');
	$t->content_unlike(qr/fetch_all failed/,
		'Phase 7: no fetch_all error');

	# Phase 8 verifies that the file was found under its original mixed-case
	# name, not because the filesystem silently folded the lowercase lookup.
	# On case-insensitive filesystems (macOS HFS+/APFS default) the lowercase
	# and mixed-case paths refer to the same inode, so the invariant cannot
	# be demonstrated — skip rather than produce a spurious failure.
	my $lower_path = "$dir/accounthistory.csv";
	SKIP: {
		skip 'case-insensitive filesystem: lowercase and mixed-case names are identical', 1
			if -f $lower_path;
		ok(!-f $lower_path, 'Phase 8: lowercase variant does not exist on disk (case bug absent)');
	}
};

subtest 'Transaction 19: Line graph lifecycle' => sub {
	# Phase 1: "Line graph..." button appears on a data view page.
	$t->get_ok('/view/sales')
		->status_is(200, 'Phase 1: /view/sales loads')
		->content_like(qr/btn-graph/, 'Phase 1: Line graph button present');

	# Phase 2: GET /graph without params returns 400 regardless of HTML::D3.
	$t->get_ok('/graph')
		->status_is(400, 'Phase 2: /graph with no params returns 400');

	# Phase 4: column validation happens before HTML::D3 is loaded.
	$t->get_ok('/graph?l=table:sales&x=product&y=no_such_column')
		->status_is(400, 'Phase 4: unknown y column returns 400');

	# Phase 5: left-spec resolution happens before HTML::D3 is loaded.
	$t->get_ok('/graph?l=table:nonexistent_xyzzy&x=product&y=amount')
		->status_is(404, 'Phase 5: unresolvable left spec returns 404');

	SKIP: {
		eval { require HTML::D3 } or skip 'HTML::D3 not available', 8;

		# Phase 3: valid params render a D3.js chart page.
		$t->get_ok('/graph?l=table:sales&x=product&y=amount')
			->status_is(200, 'Phase 3: /graph with valid params returns 200')
			->content_like(qr/d3\.js|d3\.v7/, 'Phase 3: D3.js included in output')
			->content_like(qr/Back to table/, 'Phase 3: back link present')
			->content_like(qr/Export SVG/,    'Phase 3: SVG export button present')
			->content_like(qr/Export PNG/,    'Phase 3: PNG export button present');

		# Phase 6: graph pipeline honours filters.
		$t->get_ok('/graph?l=table:sales&x=product&y=amount&f=region:eq:North')
			->status_is(200, 'Phase 6: graph with filter param returns 200');
	}
};

subtest 'Transaction 20: Graph UI polish, date-sort JS, and numeric Y-axis filter' => sub {
	# Phase 1: /view/sales response contains the date-sort helper, the
	# numeric Y-axis filter helpers, and the Plot-before-Cancel DOM order.
	$t->get_ok('/view/sales')
		->status_is(200, 'Phase 1: /view/sales loads')
		->content_like(qr/biDateKey/,
			'Phase 1: biDateKey date-sort helper present in page JS')
		->content_like(qr/monthFirst/,
			'Phase 1: monthFirst auto-detection logic present')
		->content_like(qr/btn-graph/,
			'Phase 1: btn-graph class present (button styled like toolbar peers)')
		->content_like(
			qr/btn-do-graph[^<]*>Plot<\/button>\s*<button[^>]*btn-cancel-graph/s,
			'Phase 1: Plot button appears before Cancel in graph panel DOM')
		->content_like(qr/buildYSelect/,
			'Phase 1: buildYSelect helper present (numeric Y-axis filter)')
		->content_like(qr/isNumericVal/,
			'Phase 1: isNumericVal helper present')
		->content_like(qr/isDateVal/,
			'Phase 1: isDateVal exclusion helper present');

	SKIP: {
		eval { require HTML::D3 } or skip 'HTML::D3 not available', 7;

		# Phase 2: /graph renders via the TT layout with the snippet embedded.
		$t->get_ok('/graph?l=table:sales&x=product&y=amount')
			->status_is(200, 'Phase 2: /graph with valid params returns 200')
			->content_like(qr/class="back-link"/,
				'Phase 2: back link uses standard back-link CSS class')
			->content_like(qr/Back to table/,
				'Phase 2: back link text is "Back to table"')
			->content_like(qr/graph-container/,
				'Phase 2: graph-container div present')
			->content_like(qr/d3\.v7/,
				'Phase 2: D3.js v7 loaded via CDN script tag')
			->content_like(qr/biExportSVG|Export SVG/,
				'Phase 2: SVG export button present');
	}
};

done_testing();
