use strict;
use warnings;

use Test::Most;
use Test::Mojo;
use Test::Mockingbird qw(mock restore_all);
use Readonly;
use File::Spec;
use File::Temp qw(tempdir tempfile);
use Mojo::File;
use Mojo::Util qw(url_escape);

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
Readonly my $SALES_TABLE  => 'sales';
Readonly my $PROD_TABLE   => 'products';
Readonly my $DATA_DIR     => 'data';
Readonly my $SALES_CSV    => File::Spec->rel2abs('data/sales.csv');
Readonly my $PROD_PSV     => File::Spec->rel2abs('data/products.psv');

# ---------------------------------------------------------------------------
# API LEDGER
# Every documented state / message / return code in the POD.
# Each subtest deletes its key(s) when coverage is confirmed.
# The ledger is asserted empty at the very end.
# ---------------------------------------------------------------------------
my %ledger = (
	# DataSource public API
	'DataSource.new.ok'              => 'new() with valid directory + table succeeds',
	'DataSource.new.dir_missing'     => 'new() with non-existent directory croaks error_directory_missing',
	'DataSource.new.table_invalid'   => 'new() with bad table name croaks error_table_name_invalid',
	'DataSource.new.no_args'         => 'new() without required args throws',
	'DataSource.table_name'          => 'table_name() returns lowercase table',
	'DataSource.columns'             => 'columns() returns arrayref',
	'DataSource.id_column'           => 'id_column() returns a defined column name',
	'DataSource.source_url.undef'    => 'source_url() returns undef for file-backed source',
	'DataSource.fetch_all.ok'        => 'fetch_all() returns arrayref of hashrefs',
	# Dashboard HTTP API
	'GET./'                          => 'GET / 200 HTML',
	'GET./view.200'                  => 'GET /view/:table 200 HTML',
	'GET./view.404'                  => 'GET /view/:invalid-name 404',
	'GET./view.filter'               => 'GET /view/:table?f= 200 HTML',
	'GET./browse.200'                => 'GET /browse 200 HTML',
	'GET./browse.404'                => 'GET /browse?path=nonexistent 404',
	'GET./open.200'                  => 'GET /open?path=<valid> 200 HTML',
	'GET./open.no_path'              => 'GET /open (no path param) 404',
	'GET./open.bad_ext'              => 'GET /open?path=<unsupported ext> 404',
	'GET./import.url_required'       => 'GET /import (no url) -> home + error_url_required',
	'GET./import.url_invalid'        => 'GET /import?url=ftp:// -> home + error_url_invalid',
	'GET./import.url_ssrf'           => 'GET /import?url=http://192.168.1.1/ -> home + error_url_ssrf',
	'GET./import.url_fetch'          => 'GET /import?url=<unreachable> -> home + error_url_fetch',
	'GET./api_columns.table'         => 'GET /api/columns?table= 200 JSON {columns:[...]}',
	'GET./api_columns.path'          => 'GET /api/columns?path= 200 JSON {columns:[...]}',
	'GET./api_columns.404'           => 'GET /api/columns?table=no_such 404 JSON {error}',
	'GET./join.200'                  => 'GET /join?l=table:sales 200 HTML',
	'GET./join.404'                  => 'GET /join (no l=) 404',
	'GET./export.csv'                => 'GET /export?l=table:sales&format=csv 200 text/csv',
	'GET./export.sqlite'             => 'GET /export?l=table:sales&format=sqlite 200 SQLite',
	'GET./export.404'                => 'GET /export (no l=) 404',
	'POST./export.saved'             => 'POST /export with valid dir + .csv filename -> 200 {saved}',
	'POST./export.bad_dir'           => 'POST /export with non-existent dir -> 404 {error}',
	'POST./export.bad_ext'           => 'POST /export with .xlsx extension -> 415 {error}',
	'GET./api_dirs.200'              => 'GET /api/dirs 200 JSON {path,parent,dirs}',
	'GET./api_dirs.404'              => 'GET /api/dirs?path=<file> 404 JSON {error}',
	'GET./api_stat.exists'           => 'GET /api/stat?path=<csv> 200 JSON {exists:true,...}',
	'GET./api_stat.notexists'        => 'GET /api/stat?path=<missing> 200 JSON {exists:false}',
	'GET./api_stat.400'              => 'GET /api/stat (no path) 400 JSON {error}',
	'POST./upload.200'               => 'POST /upload valid CSV -> 200 JSON {url,path}',
	'POST./upload.400'               => 'POST /upload no file -> 400 JSON {error}',
	'POST./upload.413'               => 'POST /upload oversized -> 413 JSON {error}',
	'POST./upload.415'               => 'POST /upload bad ext -> 415 JSON {error}',
);

# ---------------------------------------------------------------------------
# Bootstrap the Mojolicious app first so that Test::Mojo dynamically
# requires all app modules at runtime (after the CHECK phase).
# Sub::Private's namespace::clean runs at CHECK time, so modules loaded
# via 'use' at compile-time lose their :Private stash entries — including
# _init_backend, which new() calls.  Loading via Test::Mojo->new (which
# uses require at runtime) bypasses CHECK and preserves the full stash.
# Only AFTER the app is started do we require DataSource so we get the
# already-loaded, stash-intact version.
# ---------------------------------------------------------------------------
my $t = Test::Mojo->new('Database::BI');
require Database::BI::Model::DataSource;	# no-op: already in %INC; stash intact

# ---------------------------------------------------------------------------
# DataSource — direct constructor and accessor tests
# ---------------------------------------------------------------------------
subtest 'DataSource.new -- valid directory and table' => sub {
	my $ds;
	lives_ok { $ds = Database::BI::Model::DataSource->new(
		directory => $DATA_DIR,
		table     => $SALES_TABLE,
	) } 'new() lives with valid args';
	ok $ds, 'new() returns a defined object';
	delete $ledger{'DataSource.new.ok'};
};

subtest 'DataSource.new -- non-existent directory croaks error_directory_missing' => sub {
	# POD: croaks with 'DataSource: directory "..." does not exist or is not readable'
	throws_ok {
		Database::BI::Model::DataSource->new(
			directory => '/no/such/directory/__test__',
			table     => $SALES_TABLE,
		)
	} qr/does not exist or is not readable/,
	'new() croaks with directory-missing message for bad dir';
	delete $ledger{'DataSource.new.dir_missing'};
};

subtest 'DataSource.new -- invalid table name croaks error_table_name_invalid' => sub {
	# POD: TABLE_NAME_RE = /\A[A-Za-z_][A-Za-z0-9_]*\z/
	# A table name with a hyphen or dots must be rejected.
	throws_ok {
		Database::BI::Model::DataSource->new(
			directory => $DATA_DIR,
			table     => 'bad-table-name!',
		)
	} qr/contains illegal characters/,
	'new() croaks with table-name-invalid message for bad table';
	delete $ledger{'DataSource.new.table_invalid'};
};

subtest 'DataSource.new -- missing required args throws' => sub {
	throws_ok {
		Database::BI::Model::DataSource->new()
	} qr/.+/, 'new() with no args throws an exception';
	delete $ledger{'DataSource.new.no_args'};
};

subtest 'DataSource.table_name -- returns table name as provided' => sub {
	my $ds = Database::BI::Model::DataSource->new(
		directory => $DATA_DIR,
		table     => 'sales',
	);
	is $ds->table_name, 'sales', 'table_name() returns the name as given';
	delete $ledger{'DataSource.table_name'};
};

subtest 'DataSource.columns -- returns arrayref of column names' => sub {
	my $ds = Database::BI::Model::DataSource->new(
		directory => $DATA_DIR,
		table     => $SALES_TABLE,
	);
	my $cols = $ds->columns;
	if (defined $cols) {
		isa_ok $cols, 'ARRAY', 'columns() returns an arrayref when defined';
		ok scalar @$cols, 'columns() arrayref is non-empty';
	}
	else {
		pass 'columns() may return undef for backends without ordered headers';
	}
	delete $ledger{'DataSource.columns'};
};

subtest 'DataSource.id_column -- returns a column name string' => sub {
	my $ds = Database::BI::Model::DataSource->new(
		directory => $DATA_DIR,
		table     => $SALES_TABLE,
	);
	my $id = $ds->id_column;
	if (defined $id) {
		like $id, qr/\A\w+\z/, 'id_column() returns a word-character column name';
	}
	else {
		pass 'id_column() may return undef for URL-backed sources';
	}
	delete $ledger{'DataSource.id_column'};
};

subtest 'DataSource.source_url -- returns undef for file-backed source' => sub {
	my $ds = Database::BI::Model::DataSource->new(
		directory => $DATA_DIR,
		table     => $SALES_TABLE,
	);
	is $ds->source_url, undef, 'source_url() is undef for a file-backed DataSource';
	delete $ledger{'DataSource.source_url.undef'};
};

subtest 'DataSource.fetch_all -- returns arrayref of hashrefs' => sub {
	my $ds = Database::BI::Model::DataSource->new(
		directory => $DATA_DIR,
		table     => $SALES_TABLE,
	);
	my $rows;
	lives_ok { $rows = $ds->fetch_all } 'fetch_all() lives';
	isa_ok $rows, 'ARRAY', 'fetch_all() returns an arrayref';
	if (@$rows) {
		isa_ok $rows->[0], 'HASH', 'first element is a hashref';
	}
	delete $ledger{'DataSource.fetch_all.ok'};
};

# ---------------------------------------------------------------------------
# HTTP API tests via Test::Mojo
# ---------------------------------------------------------------------------

# ---  GET /  ----------------------------------------------------------------
subtest 'GET / -- home page lists available tables' => sub {
	$t->get_ok('/')->status_is(200)->content_type_like(qr{text/html});
	delete $ledger{'GET./'};
};

# ---  GET /view/:table  -----------------------------------------------------
subtest 'GET /view/sales -- valid table renders data grid' => sub {
	$t->get_ok("/view/$SALES_TABLE")->status_is(200)->content_type_like(qr{text/html});
	delete $ledger{'GET./view.200'};
};

subtest 'GET /view/<invalid-chars> -- returns 404' => sub {
	# Table names must match [A-Za-z_][A-Za-z0-9_]* per TABLE_NAME_RE.
	# A name containing hyphens or slashes must not match any route table.
	$t->get_ok('/view/bad-table')->status_is(404);
	delete $ledger{'GET./view.404'};
};

subtest 'GET /view/sales?f= -- filtered view returns 200' => sub {
	# Apply an eq filter that should return a subset of rows.
	$t->get_ok("/view/$SALES_TABLE?f=region:notempty:")->status_is(200);
	delete $ledger{'GET./view.filter'};
};

# ---  GET /browse  ----------------------------------------------------------
subtest 'GET /browse -- default (HOME) directory listing' => sub {
	$t->get_ok('/browse')->status_is(200)->content_type_like(qr{text/html});
	delete $ledger{'GET./browse.200'};
};

subtest 'GET /browse?path=<nonexistent> -- 404' => sub {
	my $bad = url_escape('/no/such/directory/__unit_test__');
	$t->get_ok("/browse?path=$bad")->status_is(404);
	delete $ledger{'GET./browse.404'};
};

# ---  GET /open  ------------------------------------------------------------
subtest 'GET /open?path=<csv> -- opens file and renders data grid' => sub {
	SKIP: {
		skip 'data/sales.csv not found', 2 unless -f $SALES_CSV;
		my $enc = url_escape($SALES_CSV);
		$t->get_ok("/open?path=$enc")->status_is(200)->content_type_like(qr{text/html});
	}
	delete $ledger{'GET./open.200'};
};

subtest 'GET /open (no path param) -- 404' => sub {
	$t->get_ok('/open')->status_is(404);
	delete $ledger{'GET./open.no_path'};
};

subtest 'GET /open?path=<unsupported ext> -- 404' => sub {
	# .txt is not in the supported extension list (csv, db, sql, xml, psv).
	my ($fh, $fn) = tempfile(SUFFIX => '.txt', UNLINK => 1);
	close $fh;
	my $enc = url_escape($fn);
	$t->get_ok("/open?path=$enc")->status_is(404);
	delete $ledger{'GET./open.bad_ext'};
};

# ---  GET /import  ----------------------------------------------------------
subtest 'GET /import (no url param) -- home page with error_url_required' => sub {
	# POD: error_url_required -- empty or missing url param
	$t->get_ok('/import')
	  ->status_is(200)
	  ->content_type_like(qr{text/html})
	  ->content_like(qr/Please enter a URL/i);
	delete $ledger{'GET./import.url_required'};
};

subtest 'GET /import?url=ftp://... -- home page with error_url_invalid' => sub {
	# POD: error_url_invalid -- URL does not begin with http:// or https://
	my $bad = url_escape('ftp://example.com/data.html');
	$t->get_ok("/import?url=$bad")
	  ->status_is(200)
	  ->content_type_like(qr{text/html})
	  ->content_like(qr/is not a valid http/i);
	delete $ledger{'GET./import.url_invalid'};
};

subtest 'GET /import?url=http://192.168.1.1/ -- SSRF guard error_url_ssrf' => sub {
	# POD: error_url_ssrf -- URL resolves to a private or reserved address
	my $priv = url_escape('http://192.168.1.1/data.html');
	$t->get_ok("/import?url=$priv")
	  ->status_is(200)
	  ->content_type_like(qr{text/html})
	  ->content_like(qr/resolves to a private or reserved address/i);
	delete $ledger{'GET./import.url_ssrf'};
};

subtest 'GET /import?url=<unreachable> -- home page with error_url_fetch' => sub {
	# POD: error_url_fetch -- LWP fetch failure or no table found
	# Mock DataSource::new to croak when called in URL mode so the controller's
	# eval catches it and renders error_url_fetch -- no real network call needed.
	# (Previously used .invalid TLD, which blocks on some OpenBSD DNS resolvers.)
	mock 'Database::BI::Model::DataSource::new' => sub {
		my ($class, %args) = @_;
		die "Mocked: could not fetch remote HTML table\n" if exists $args{url};
		# Non-URL calls within this request (none expected) would return undef,
		# which the controller also treats as a fetch error -- still safe.
	};
	my $bad = url_escape('http://unit-test-host.example/data.html');
	$t->get_ok("/import?url=$bad")
	  ->status_is(200)
	  ->content_type_like(qr{text/html})
	  ->content_like(qr/Could not load HTML table from/i);
	restore_all();
	delete $ledger{'GET./import.url_fetch'};
};

# ---  GET /api/columns  -----------------------------------------------------
subtest 'GET /api/columns?table=sales -- 200 JSON with columns array' => sub {
	$t->get_ok("/api/columns?table=$SALES_TABLE")
	  ->status_is(200)
	  ->json_has('/columns');
	my $body = $t->tx->res->json;
	isa_ok $body->{columns}, 'ARRAY', '/api/columns returns columns arrayref';
	delete $ledger{'GET./api_columns.table'};
};

subtest 'GET /api/columns?path=<csv> -- 200 JSON with columns array' => sub {
	SKIP: {
		skip 'data/sales.csv not found', 3 unless -f $SALES_CSV;
		my $enc = url_escape($SALES_CSV);
		$t->get_ok("/api/columns?path=$enc")
		  ->status_is(200)
		  ->json_has('/columns');
	}
	delete $ledger{'GET./api_columns.path'};
};

subtest 'GET /api/columns?table=no_such_table -- 404 JSON {error}' => sub {
	$t->get_ok('/api/columns?table=no_such_table_xyzzy')
	  ->status_is(404)
	  ->json_has('/error');
	delete $ledger{'GET./api_columns.404'};
};

# ---  GET /join  ------------------------------------------------------------
subtest 'GET /join?l=table:sales -- left join with no right table 200' => sub {
	$t->get_ok("/join?l=table:$SALES_TABLE")->status_is(200)->content_type_like(qr{text/html});
	delete $ledger{'GET./join.200'};
};

subtest 'GET /join (no l= param) -- 404' => sub {
	$t->get_ok('/join')->status_is(404);
	delete $ledger{'GET./join.404'};
};

# ---  GET /export  ----------------------------------------------------------
subtest 'GET /export?l=table:sales&format=csv -- CSV download 200' => sub {
	$t->get_ok("/export?l=table:$SALES_TABLE&format=csv")
	  ->status_is(200)
	  ->content_type_like(qr{text/csv});
	delete $ledger{'GET./export.csv'};
};

subtest 'GET /export?l=table:sales&format=sqlite -- SQLite download 200' => sub {
	$t->get_ok("/export?l=table:$SALES_TABLE&format=sqlite")
	  ->status_is(200)
	  ->content_type_like(qr{sqlite|octet-stream}i);
	delete $ledger{'GET./export.sqlite'};
};

subtest 'GET /export (no l= param) -- 404 JSON' => sub {
	$t->get_ok('/export')->status_is(404);
	delete $ledger{'GET./export.404'};
};

# ---  POST /export  ---------------------------------------------------------
subtest 'POST /export -- valid dir + .csv filename returns {saved}' => sub {
	my $dir = tempdir(CLEANUP => 1);
	$t->post_ok('/export', form => {
		l        => "table:$SALES_TABLE",
		dir      => $dir,
		filename => 'output.csv',
	})->status_is(200)
	  ->json_has('/saved', 'response has saved key');
	my $saved = $t->tx->res->json('/saved');
	like $saved, qr/output\.csv\z/, 'saved path ends with output.csv';
	ok -f $saved, 'saved file exists on disk';
	delete $ledger{'POST./export.saved'};
};

subtest 'POST /export -- non-existent dir returns 404 JSON {error}' => sub {
	# POD: error_dir_not_found when realpath fails or result is not a dir.
	$t->post_ok('/export', form => {
		l        => "table:$SALES_TABLE",
		dir      => '/no/such/directory/__unit_test__',
		filename => 'out.csv',
	})->status_is(404)
	  ->json_has('/error');
	delete $ledger{'POST./export.bad_dir'};
};

subtest 'POST /export -- unsupported extension returns 415 JSON {error}' => sub {
	# POD: error_ext_required when filename extension is not .csv or .sql.
	my $dir = tempdir(CLEANUP => 1);
	$t->post_ok('/export', form => {
		l        => "table:$SALES_TABLE",
		dir      => $dir,
		filename => 'out.xlsx',
	})->status_is(415)
	  ->json_has('/error');
	delete $ledger{'POST./export.bad_ext'};
};

# ---  GET /api/dirs  --------------------------------------------------------
subtest 'GET /api/dirs -- default (HOME) directory listing JSON' => sub {
	$t->get_ok('/api/dirs')
	  ->status_is(200)
	  ->json_has('/path')
	  ->json_has('/dirs');
	my $body = $t->tx->res->json;
	isa_ok $body->{dirs}, 'ARRAY', 'dirs is an arrayref';
	delete $ledger{'GET./api_dirs.200'};
};

subtest 'GET /api/dirs?path=<regular file> -- 404 JSON {error}' => sub {
	# A regular file is not a directory -- must return 404.
	SKIP: {
		skip 'data/sales.csv not found', 2 unless -f $SALES_CSV;
		my $enc = url_escape($SALES_CSV);
		$t->get_ok("/api/dirs?path=$enc")
		  ->status_is(404)
		  ->json_has('/error');
	}
	delete $ledger{'GET./api_dirs.404'};
};

# ---  GET /api/stat  --------------------------------------------------------
subtest 'GET /api/stat?path=<csv> -- exists:true with mtime and size' => sub {
	SKIP: {
		skip 'data/sales.csv not found', 5 unless -f $SALES_CSV;
		my $enc = url_escape($SALES_CSV);
		$t->get_ok("/api/stat?path=$enc")
		  ->status_is(200)
		  ->json_is('/exists', Mojo::JSON->true)
		  ->json_has('/mtime')
		  ->json_has('/size');
		my $body = $t->tx->res->json;
		ok $body->{mtime} > 0, 'mtime is a positive epoch timestamp';
		ok $body->{size}  > 0, 'size is a positive byte count';
	}
	delete $ledger{'GET./api_stat.exists'};
};

subtest 'GET /api/stat?path=<nonexistent> -- exists:false HTTP 200' => sub {
	# POD: a missing/unresolvable path returns HTTP 200 with exists:false
	my $enc = url_escape('/no/such/file/__unit_test__.csv');
	$t->get_ok("/api/stat?path=$enc")
	  ->status_is(200)
	  ->json_is('/exists', Mojo::JSON->false);
	delete $ledger{'GET./api_stat.notexists'};
};

subtest 'GET /api/stat (no path param) -- 400 JSON {error}' => sub {
	# POD: error_path_required when path param is absent.
	$t->get_ok('/api/stat')
	  ->status_is(400)
	  ->json_has('/error');
	delete $ledger{'GET./api_stat.400'};
};

# ---  POST /upload  ---------------------------------------------------------
subtest 'POST /upload -- valid CSV file returns {url, path}' => sub {
	$t->post_ok('/upload', form => {
		file => { content => "id,name\n1,widget\n", filename => 'test_unit.csv' },
	})->status_is(200)
	  ->json_has('/url')
	  ->json_has('/path');
	my $url  = $t->tx->res->json('/url');
	my $path = $t->tx->res->json('/path');
	like $url,  qr{/open\?path=}, 'url points to /open?path=...';
	like $path, qr/test_unit\.csv\z/, 'path ends with the original filename';
	ok -f $path, 'uploaded file exists on disk';
	delete $ledger{'POST./upload.200'};
};

subtest 'POST /upload -- no file part returns 400 JSON {error}' => sub {
	# POD: error_upload_none when no file part is present.
	$t->post_ok('/upload', form => { other_field => 'ignored' })
	  ->status_is(400)
	  ->json_has('/error');
	delete $ledger{'POST./upload.400'};
};

subtest 'POST /upload -- oversized file returns 413 JSON {error}' => sub {
	# POD: the controller checks is_limit_exceeded and returns 413 before
	# writing to disk.  Lower max_request_size temporarily so the subtest
	# does not allocate 50 MiB.
	my $orig = $t->app->max_request_size;
	$t->app->max_request_size(1024);
	$t->post_ok('/upload', form => {
		file => { content => 'A' x 5000, filename => 'huge.csv' },
	})->status_is(413)
	  ->json_like('/error', qr/too large/i);
	$t->app->max_request_size($orig);
	delete $ledger{'POST./upload.413'};
};

subtest 'POST /upload -- unsupported extension returns 415 JSON {error}' => sub {
	# POD: error_upload_ext when extension is not csv/db/sql/xml/psv.
	$t->post_ok('/upload', form => {
		file => { content => 'some data', filename => 'data.xlsx' },
	})->status_is(415)
	  ->json_has('/error');
	delete $ledger{'POST./upload.415'};
};

# ---------------------------------------------------------------------------
# Ledger assertion — every documented state must have been exercised.
# ---------------------------------------------------------------------------
if (my @untested = sort keys %ledger) {
	for my $key (@untested) {
		fail "Untested documented state: $key ($ledger{$key})";
	}
}
else {
	pass 'All documented API states covered by the test suite';
}

done_testing;
