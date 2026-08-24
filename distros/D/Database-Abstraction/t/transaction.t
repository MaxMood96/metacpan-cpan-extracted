#!perl -w

# Transaction-flow tests for Database::Abstraction.
#
# Since Database::Abstraction is a read-only ORM, "transactions" here cover:
#   1. Object lifecycle    — lazy-open → query → DESTROY sequencing
#   2. Query idempotency   — repeated reads return identical state
#   3. Multi-instance isolation — concurrent objects on the same data are independent
#   4. CHI cache lifecycle — MISS → SET → HIT → new-key sequence
#   5. Gzip resource lifecycle — temp-file born, used, and unlinked on DESTROY
#   6. Query-builder chain — multi-step chains produce consistent results
#
# Tests use sequences, not isolated function calls — each section walks through
# a multi-step flow and asserts state at every boundary.

use strict;
use warnings;

use FindBin   qw($Bin);
use File::Spec;
use File::Temp ();
use IO::Compress::Gzip qw(gzip $GzipError);
use Readonly;
use Test::Most  tests => 31;
use Test::NoWarnings;

use lib 't/lib';
use Database::test1;

Readonly my $DATA_DIR     => File::Spec->catfile($Bin, File::Spec->updir(), 't', 'data');
Readonly my $ENTRY_ONE    => 'one';
Readonly my $ENTRY_TWO    => 'two';
Readonly my $ENTRY_THREE  => 'three';
Readonly my $NUMBER_ONE   => 1;
Readonly my $NUMBER_TWO   => 2;
Readonly my $NUMBER_THREE => 3;
Readonly my $EXPECTED_ROW_COUNT => 4;    # one, two, three, empty

# ---------------------------------------------------------------------------
# Section 1: Object lifecycle — lazy-open → query → DESTROY
# ---------------------------------------------------------------------------
note('Section 1: object lifecycle');

{
	# T1-1: object created but _table_name not yet set — lazy open
	my $db = Database::test1->new($DATA_DIR);
	ok(!defined $db->{'_table_name'}, 'T1-1: _table_name is undef before first query (lazy open)');

	# T1-2: first query triggers _open; _table_name now populated
	my $n = $db->count();
	ok(defined $db->{'_table_name'}, 'T1-2: _table_name set after first query');

	# T1-3: slurp path — $self->{'data'} is a hashref after _open
	ok(ref($db->{'data'}) eq 'HASH', 'T1-3: slurped data stored as HASH ref');

	# T1-4: count() is consistent with selectall_arrayref() row count
	my $rows = $db->selectall_arrayref();
	cmp_ok($n, '==', scalar @{$rows}, 'T1-4: count() == scalar(@{ selectall_arrayref() })');

	# T1-5: fetchrow_hashref returns data consistent with selectall result
	my $row = $db->fetchrow_hashref(entry => $ENTRY_TWO);
	cmp_ok($row->{'number'}, '==', $NUMBER_TWO, 'T1-5: fetchrow_hashref(entry=two) → number=2');

	# T1-6: DESTROY on a live, fully-opened object does not croak
	lives_ok { $db->DESTROY() } 'T1-6: explicit DESTROY on a live object does not croak';
}

# ---------------------------------------------------------------------------
# Section 2: Query idempotency — repeated reads return identical state
# ---------------------------------------------------------------------------
note('Section 2: query idempotency');

{
	my $db = Database::test1->new($DATA_DIR);

	# T2-1: count() returns the same value across three consecutive calls
	my $c1 = $db->count();
	my $c2 = $db->count();
	my $c3 = $db->count();
	ok($c1 == $c2 && $c2 == $c3 && $c1 == $EXPECTED_ROW_COUNT,
	    'T2-1: count() is idempotent across three consecutive calls');

	# T2-2: selectall_arrayref() called twice returns a deeply equal structure
	my $r1 = $db->selectall_arrayref();
	my $r2 = $db->selectall_arrayref();
	is_deeply($r1, $r2, 'T2-2: selectall_arrayref() is idempotent (deep equality)');

	# T2-3: fetchrow_hashref for the same key is deeply equal across two calls
	my $h1 = $db->fetchrow_hashref(entry => $ENTRY_ONE);
	my $h2 = $db->fetchrow_hashref(entry => $ENTRY_ONE);
	is_deeply($h1, $h2, 'T2-3: fetchrow_hashref() is idempotent for same key');

	# T2-4: AUTOLOAD column lookup returns the same scalar across three calls
	my $v1 = $db->number(entry => $ENTRY_THREE);
	my $v2 = $db->number(entry => $ENTRY_THREE);
	my $v3 = $db->number(entry => $ENTRY_THREE);
	ok($v1 == $NUMBER_THREE && $v2 == $NUMBER_THREE && $v3 == $NUMBER_THREE,
	    'T2-4: AUTOLOAD number(entry=three) is idempotent across three calls');
}

# ---------------------------------------------------------------------------
# Section 3: Multi-instance isolation — concurrent objects on the same data
# ---------------------------------------------------------------------------
note('Section 3: multi-instance isolation');

{
	my $db1 = Database::test1->new($DATA_DIR);
	my $db2 = Database::test1->new($DATA_DIR);

	# T3-1: both objects return the same row count
	my $c1 = $db1->count();
	my $c2 = $db2->count();
	cmp_ok($c1, '==', $c2, 'T3-1: two independent objects agree on row count');

	# T3-2: both objects have separate in-memory data refs — NOT the same reference
	my $d1 = $db1->{'data'};
	my $d2 = $db2->{'data'};
	isnt("$d1", "$d2", 'T3-2: db1 and db2 have independent data refs (no shared memory)');

	# T3-3 / T3-4: destroying $db2 mid-flight does not break $db1
	$db2->DESTROY();
	lives_ok { $db1->count() }    'T3-3: db1->count() succeeds after db2 is destroyed';
	my $row = $db1->fetchrow_hashref(entry => $ENTRY_TWO);
	cmp_ok($row->{'number'}, '==', $NUMBER_TWO,
	    'T3-4: db1 returns correct data after db2 destruction (no Data::Reuse cross-contamination)');

	# T3-5: a new object created after db1+db2 cycle sees the same data
	my $db3 = Database::test1->new($DATA_DIR);
	cmp_ok($db3->count(), '==', $c1,
	    'T3-5: newly created db3 sees same row count after db1+db2 lifecycle');
}

# ---------------------------------------------------------------------------
# Section 4: CHI cache lifecycle — MISS → SET → HIT → new-key
# ---------------------------------------------------------------------------
note('Section 4: CHI cache lifecycle');

SKIP: {
	eval { require CHI };
	skip 'CHI not installed', 6 if $@;

	my $cache = CHI->new(driver => 'RawMemory', global => 1);
	$cache->on_set_error('die');
	$cache->on_get_error('die');

	# T4-1: cache is empty before the first SQL query
	cmp_ok(scalar $cache->get_keys(), '==', 0,
	    'T4-1: cache starts empty before any query');

	# Force SQL path with max_slurp_size=>0 so cache is actually consulted.
	my $db_sql = Database::test1->new(
		directory      => $DATA_DIR,
		cache          => $cache,
		cache_duration => '1 hour',
		max_slurp_size => 0,
	);

	# T4-2: first selectall_arrayref() is a MISS and populates one cache entry
	my $fresh = $db_sql->selectall_arrayref();
	cmp_ok(scalar $cache->get_keys(), '==', 1,
	    'T4-2: after first selectall_arrayref(), cache has 1 key (MISS → SET)');

	# T4-3: second identical query is a HIT — cache key count unchanged
	$db_sql->selectall_arrayref();
	cmp_ok(scalar $cache->get_keys(), '==', 1,
	    'T4-3: second identical query is a cache HIT (key count unchanged)');

	# T4-4: a parameterised selectall_arrayref produces a second cache key
	# (count() reads but never writes the cache, so we use selectall_arrayref)
	$db_sql->selectall_arrayref(entry => $ENTRY_ONE);
	cmp_ok(scalar $cache->get_keys(), '>=', 2,
	    'T4-4: parameterised selectall_arrayref produces a new cache key (MISS → SET)');

	# T4-5: cached result is structurally identical to a repeat fresh call result
	my $cached = $db_sql->selectall_arrayref();
	is_deeply($fresh, $cached,
	    'T4-5: cache HIT returns data deeply equal to the original MISS result');

	# T4-6: a second object sharing the same cache gets a HIT for a key the first populated
	my $db_sql2 = Database::test1->new(
		directory      => $DATA_DIR,
		cache          => $cache,
		cache_duration => '1 hour',
		max_slurp_size => 0,
	);
	my $pre_keys = scalar $cache->get_keys();
	$db_sql2->selectall_arrayref();
	cmp_ok(scalar $cache->get_keys(), '==', $pre_keys,
	    'T4-6: second object sharing cache gets HIT from first object\'s entry (no new key added)');
}

# ---------------------------------------------------------------------------
# Section 5: Gzip resource lifecycle — temp file born, used, and unlinked
# ---------------------------------------------------------------------------
note('Section 5: gzip temp file resource lifecycle');

{
	# Build a gzip CSV in a temp directory.
	# test1 uses '!' as sep_char and has an 'entry' key column.
	my $tmpdir = File::Temp->newdir(CLEANUP => 1);
	my $csv_plain = "entry!number\n\"one\"!1\n\"two\"!2\n\"three\"!3\n";
	my $gz_path   = File::Spec->catfile("$tmpdir", 'test1.csv.gz');
	gzip \$csv_plain => $gz_path or die "gzip failed: $GzipError";

	# T5-1: gzip CSV opens and returns the correct row count
	my $db_gz = Database::test1->new("$tmpdir");
	cmp_ok($db_gz->count(), '==', 3, 'T5-1: gzip CSV opens and count() == 3');

	# T5-2: during lifetime, _temp_fh holds a File::Temp object (decompressed copy)
	ok(defined $db_gz->{'_temp_fh'}, 'T5-2: _temp_fh is set while gzip object is alive');

	# T5-3: the temp file actually exists on disk during object lifetime
	my $tmpfile_path = $db_gz->{'_temp_fh'}->filename();
	ok(-e $tmpfile_path, 'T5-3: decompressed temp file exists on disk during object lifetime');

	# T5-4: multiple queries use the same temp file (no re-extraction between calls)
	my $path_after_q2 = do { $db_gz->selectall_arrayref(); $db_gz->{'_temp_fh'}->filename() };
	is($path_after_q2, $tmpfile_path,
	    'T5-4: same temp file path after second query (no re-extraction)');

	# T5-5: after DESTROY, _temp_fh is cleared (File::Temp auto-unlinks it)
	$db_gz->DESTROY();
	ok(!defined $db_gz->{'_temp_fh'},
	    'T5-5: _temp_fh cleared after DESTROY (temp file auto-unlinked)');
}

# ---------------------------------------------------------------------------
# Section 6: Query-builder chain idempotency
# ---------------------------------------------------------------------------
note('Section 6: query-builder chain idempotency');

{
	my $db = Database::test1->new($DATA_DIR);

	# T6-1: where→limit→all delivers the expected filtered, limited result
	my $r1 = $db->query()
	            ->where(entry => $ENTRY_ONE)
	            ->limit(5)
	            ->all();
	ok(ref $r1 eq 'ARRAY' && scalar @{$r1} == 1 && $r1->[0]{'entry'} eq $ENTRY_ONE,
	    'T6-1: where(entry=one)->limit(5)->all() returns exactly 1 matching row');

	# T6-2: executing the identical chain a second time returns a deeply equal result
	my $r2 = $db->query()
	            ->where(entry => $ENTRY_ONE)
	            ->limit(5)
	            ->all();
	is_deeply($r1, $r2, 'T6-2: identical builder chain executed twice gives deeply equal results');

	# T6-3: query-builder count() is consistent with direct count() for same params
	my $qb_count     = $db->query()->where(entry => $ENTRY_TWO)->count();
	my $direct_count = $db->count(entry => $ENTRY_TWO);
	cmp_ok($qb_count, '==', $direct_count,
	    'T6-3: query-builder count() == direct count() for identical criteria');

	# T6-4: two independent chains on the same object return independent results
	my $chain_a = $db->query()->where(entry => $ENTRY_ONE)->all();
	my $chain_b = $db->query()->where(entry => $ENTRY_TWO)->all();
	isnt($chain_a->[0]{'entry'}, $chain_b->[0]{'entry'},
	    'T6-4: two independent builder chains return distinct result sets');
}
