package Data::HashMap::Shared;
use strict;
use warnings;
our $VERSION = '0.19';

require XSLoader;
XSLoader::load('Data::HashMap::Shared', $VERSION);

# ithreads: blessed shared-memory handles must never be cloned into a
# child thread -- the clone would double-free the handle on thread exit.
{ no strict 'refs'; *{"${_}::CLONE_SKIP"} = sub { 1 } for qw(
  Data::HashMap::Shared::I16
  Data::HashMap::Shared::I16::Cursor
  Data::HashMap::Shared::I16S
  Data::HashMap::Shared::I16S::Cursor
  Data::HashMap::Shared::I32
  Data::HashMap::Shared::I32::Cursor
  Data::HashMap::Shared::I32S
  Data::HashMap::Shared::I32S::Cursor
  Data::HashMap::Shared::II
  Data::HashMap::Shared::II::Cursor
  Data::HashMap::Shared::IS
  Data::HashMap::Shared::IS::Cursor
  Data::HashMap::Shared::SI
  Data::HashMap::Shared::SI::Cursor
  Data::HashMap::Shared::SI16
  Data::HashMap::Shared::SI16::Cursor
  Data::HashMap::Shared::SI32
  Data::HashMap::Shared::SI32::Cursor
  Data::HashMap::Shared::SS
  Data::HashMap::Shared::SS::Cursor
); }

1;

__END__

=encoding utf-8

=head1 NAME

Data::HashMap::Shared - Multiprocess shared-memory hash maps with LRU eviction
and per-key TTL

=head1 SYNOPSIS

    use Data::HashMap::Shared::II;

    # Create or open a shared map (file-backed mmap)
    my $map = Data::HashMap::Shared::II->new('/tmp/mymap.shm', 100000);

    # Keyword API (fastest)
    shm_ii_put $map, 42, 100;
    my $val = shm_ii_get $map, 42;

    # Method API
    $map->put(42, 100);
    my $v = $map->get(42);

    # Atomic counters (under the read lock, without LRU or TTL)
    shm_ii_incr $map, 1;            # 1
    shm_ii_incr_by $map, 1, 10;     # 11
    shm_ii_max $map, 1, 50;         # monotonic: store max(current, 50) -> 50

    # Compare-and-swap (all variants; byte-compare for string values)
    shm_ii_cas $map, 1, 50, 42;     # swap to 42 only if current == 50

    # LRU cache (evicts least-recently-used when full)
    my $cache = Data::HashMap::Shared::II->new('/tmp/cache.shm', 100000, 1000);
    shm_ii_put $cache, 42, 100;    # auto-evicts LRU entry if size > 1000

    # TTL (entries expire after N seconds)
    my $ttl_map = Data::HashMap::Shared::II->new('/tmp/ttl.shm', 100000, 0, 60);
    shm_ii_put $ttl_map, 1, 10;          # expires in 60s
    shm_ii_put_ttl $ttl_map, 2, 20, 5;   # per-key: expires in 5s

    # Multiprocess
    if (fork() == 0) {
        my $child = Data::HashMap::Shared::II->new('/tmp/mymap.shm', 100000);
        shm_ii_incr $child, 1;   # atomic increment visible to parent
        exit;
    }
    wait;

=head1 DESCRIPTION

Data::HashMap::Shared provides type-specialized hash maps stored in
file-backed shared memory (C<mmap(MAP_SHARED)>), enabling efficient
multiprocess data sharing on Linux. With opt-in B<LRU eviction> and
B<per-key TTL> it doubles as a fast cross-process B<cache>; lookups take a
lock-free seqlock fast path.

B<Linux-only>. Requires 64-bit Perl.

=head2 Features

=over

=item * File-backed mmap for cross-process sharing

=item * Futex-based read-write lock (fast userspace path)

=item * Atomic counters (incr/decr under the read lock on maps without LRU or TTL)

=item * Elastic capacity (starts small, grows/shrinks automatically)

=item * Arena allocator for string storage in shared memory

=item * Keyword API via XS::Parse::Keyword for maximum speed

=item * Opt-in B<LRU eviction> -- clock/second-chance algorithm; reads stay lock-free

=item * Opt-in B<per-key TTL> expiry -- lazy removal on access; monotonic clock

=item * Stale lock recovery for both writers and readers (dead PIDs detected and drained automatically)

=back

=head2 Variants

=over

=item L<Data::HashMap::Shared::I16> - int16 to int16

=item L<Data::HashMap::Shared::I32> - int32 to int32

=item L<Data::HashMap::Shared::II> - int64 to int64

=item L<Data::HashMap::Shared::I16S> - int16 to string

=item L<Data::HashMap::Shared::I32S> - int32 to string

=item L<Data::HashMap::Shared::IS> - int64 to string

=item L<Data::HashMap::Shared::SI16> - string to int16

=item L<Data::HashMap::Shared::SI32> - string to int32

=item L<Data::HashMap::Shared::SI> - string to int64

=item L<Data::HashMap::Shared::SS> - string to string

=back

=head2 Integer Range and Wrapping

Integer keys and values are stored as fixed-width two's-complement
integers: C<I16>/C<SI16>/C<I16S> use a signed 16-bit range
(-32768 .. 32767), C<I32>/C<SI32>/C<I32S> a signed 32-bit range, and
C<II>/C<IS>/C<SI> a signed 64-bit range. A key or value outside the
variant's range is B<silently truncated> to the low bits (two's
complement), with no warning: on an C<I16> map, C<< $map->put(70000, ...) >>
stores under key C<4464> (C<70000 & 0xFFFF>), so C<get(70000)> and
C<get(4464)> address the same entry. C<incr>/C<decr> wrap the same way
(C<32767 + 1> becomes C<-32768>). Pick a variant wide enough for your data.

=head2 Constructor

    my $map = Data::HashMap::Shared::II->new($path, $max_entries);
    my $map = Data::HashMap::Shared::II->new(undef, $max_entries);    # anonymous
    my $map = Data::HashMap::Shared::II->new($path, $max_entries, $max_size);
    my $map = Data::HashMap::Shared::II->new($path, $max_entries, $max_size, $ttl);
    my $map = Data::HashMap::Shared::II->new($path, $max_entries, $max_size, $ttl, $lru_skip);
    my $map = Data::HashMap::Shared::SS->new($path, $max_entries, 0, 0, 0, $arena_cap); # explicit arena bytes
    my $map = Data::HashMap::Shared::II->new($path, $max_entries, $max_size, $ttl, $lru_skip, $arena_cap, $file_mode);
    my $map = Data::HashMap::Shared::II->new_sharded($prefix, $shards, $max_entries, $max_size, $ttl, $lru_skip, $arena_cap, $file_mode);
    my $map = Data::HashMap::Shared::II->new_memfd($name, $max_entries, ...); # memfd-backed
    my $map = Data::HashMap::Shared::II->new_from_fd($fd);            # reopen memfd
    my $fd  = $map->memfd;                                            # -1 if not memfd

Creates or opens a shared hash map backed by file C<$path>. Passing C<undef>
as the path creates an anonymous C<MAP_SHARED|MAP_ANONYMOUS> mapping that is
inherited across C<fork> but has no filesystem presence.

C<new_memfd> creates an unlinked memfd-backed map whose file descriptor can be
passed to another process (via C<SCM_RIGHTS>, C<fork>+C<exec>, or duped+open).
C<new_from_fd> reopens such a descriptor. The descriptor you pass is
duplicated (C<F_DUPFD_CLOEXEC>), so it stays yours to close and closing it
does not disturb the handle. Both require a 64-bit Perl on Linux
(C<memfd_create(2)>).

C<< $map->memfd >> goes the other way: it returns the handle's own descriptor,
not a copy. Pass it, but do not close it: the handle closes it when the map goes
away, and in between the number is handed out again to the next file the process
opens, so closing it early makes the map's eventual close hit an unrelated file.
Dup it first if it has to outlive the map.

C<$max_entries>, C<$max_size>, C<$ttl>, C<$lru_skip>, C<$arena_cap>, and
C<$file_mode> are used only when creating a new file; when opening an
existing one, all parameters are read from the stored header and the
constructor arguments are ignored -- but still range-checked, so a value the
module would never accept at creation is rejected either way.

C<$shards> is the exception: it is not recorded in any file, so every process
opening a sharded set must pass the same count.  A different count routes keys
to the wrong shard and creates the missing shard files, which loses access to
roughly the data that hashes elsewhere -- silently.  Treat it as part of the
path.
Multiple processes can open the same file simultaneously.
Dies if the file exists but was created by a different variant or is corrupt.

Optional C<$max_size> enables LRU eviction: when the map reaches C<$max_size>
entries, the least-recently-used entry is evicted on insert. Set to 0 (default)
to disable. LRU uses a clock/second-chance algorithm: C<get> sets an accessed
bit (lock-free, no write lock), and eviction gives a second chance to recently
accessed entries before evicting.

A C<$max_size> at or above the slot count -- 2048 for a map created with 1000,
not the 1536 C<max_entries> reports -- can never drive eviction: above it the
bound is never reached, and at exactly it the insert fails on the full table
first. The map then fills up and refuses further inserts, keeping its B<oldest>
keys. Every constructor that opens a map for writing warns about this (category
C<misc>), reading the bound off the map rather than its arguments, so attaching
to a sound file never warns however its arguments are written. It warns rather
than dies: the bound is merely unreachable, and LRU ordering still drives
C<pop>/C<shift>. Silence it with C<no warnings 'misc'>.

Eviction counts entries, not bytes, so on a string variant the arena can run out
while the count is still below C<$max_size>: nothing is evicted and every insert
needing arena space fails, leaving the cache stuck with its B<oldest> entries.
A single key or value may be at most 1 GB; longer ones croak.
Keys and values of 7 bytes or fewer are stored inline and keep succeeding, which
is how an exhausted arena can look like a working cache -- so size C<$arena_cap>
for what you store, and check what the insert returned. An insert at
C<$max_size> evicts before it stores, so the first failure costs one entry and
later ones cost nothing until an insert succeeds again.

Optional C<$ttl> sets a default time-to-live in seconds for all entries.
Expired entries are reclaimed lazily, by the next B<mutating> access to that key.
C<remove>, C<update>, C<take>, C<cas>, C<touch>, C<persist> and C<set_ttl> free
the slot; C<incr>, C<add> and C<get_or_set> free it and insert afresh, so the key
is live again when they return; C<put> overwrites it in place. A read --
C<get>, C<exists>, C<get_with_ttl>, C<get_multi>, C<ttl_remaining> -- reports it
absent but leaves it there, so C<size> still counts it. Set to 0 (default) to
disable.

TTLs have whole-second granularity and the deadline is truncated, so an entry
given C<$n> seconds expires somewhere between C<$n-1> and C<$n> seconds later:
a TTL of 1 can expire almost immediately. Leave at least a second of margin
over any refresh interval that has to beat it.

Any operation that stores a value resets the entry's TTL to the map default:
C<put>, C<update>, C<cas>, C<incr>/C<decr>/C<incr_by>, C<max>/C<min>,
C<get_or_set> on a hit, and C<set_multi>, as well as the documented C<touch>
and C<swap>. A permanent entry (TTL 0) stays permanent. To carry a per-key TTL
across a value change, write it with C<put_ttl>/C<update_ttl> or restore it
afterwards with C<set_ttl>.

An expired entry still occupies its slot until something reclaims it, so a TTL
map without LRU eviction can fill up with entries that every read reports as
absent: once no slot is free, inserts fail and C<incr> dies while C<keys>
returns nothing. Call C<flush_expired> (or C<flush_expired_partial>) on a timer
if keys are not revisited; C<$max_size> avoids the problem entirely because
eviction reclaims slots.
When TTL is active, C<get> and C<exists> check expiry. Expiry is measured
against a monotonic clock (C<CLOCK_MONOTONIC_COARSE>): TTLs track elapsed
running time and do not advance while the system is suspended or hibernating.

That clock is B<local to the current boot>: it restarts at zero on reboot and is
unrelated between machines, while the expiry timestamps live in the file. A map
that outlives the boot which wrote it -- or is copied to another host, a frozen
map shipped elsewhere included -- therefore carries deadlines on a timeline that
no longer exists, and the error runs whichever way the destination clock does.
Where its uptime has not yet reached the stored values, entries live B<longer>
than their TTL and correct themselves as it passes them; where its uptime
already exceeds them -- a map built on a freshly booted host and served on a
long-running one -- every TTL'd entry arrives expired while C<size> still counts
it. Nothing crashes, but do not rely on TTL across a reboot or a host move:
C<flush_expired>, C<persist> what you ship, or rebuild.

Optional C<$lru_skip> (0-99, default 0; 100 or more disables skipping, a
negative value is rejected like any out-of-range size) reduces how often LRU
promotion reorders the recency list -- higher values skip more. Promotion runs
only where an operation updates an existing entry under the write lock
(C<put>/C<incr>/C<get_or_set> on a hit, the update family); C<get> and
C<get_with_ttl> never promote, they set the lock-free accessed bit that clock
eviction consumes. Skipping cuts write-lock churn on Zipfian workloads where a
few hot keys dominate. The eviction victim itself is never skipped, so eviction
stays correct. Set to 0 for strict LRU ordering.

Optional C<$arena_cap> (bytes) sizes the string arena explicitly instead of
deriving it from C<$max_entries>. The default is roughly 128 bytes per entry
(4096 minimum), which a few large strings can exhaust while the table is nearly
empty. Clamped to C<[4096, 0xFFFFFFFF]> (arena offsets are 32-bit); integer-only
variants (C<II>/C<I16>/C<I32>) have none and ignore it; for sharded maps it is
per shard, like C<$max_entries>.

Size it from the rounded lengths, not the byte totals: blocks are powers of two
with a 16-byte minimum, so a 100-byte value takes 128 and a 1100-byte value
2048, and a total can be short by up to half. Blocks are recycled by exact size
class, so a freed large one never serves a smaller request -- a workload
alternating value sizes needs room for one block of each size it uses, not just
the largest.

Optional C<$file_mode> (octal, default C<0600>) sets the permission bits used
when the backing file is created; the exact mode is applied via C<fchmod>, so
the process umask does not narrow it. It is ignored when attaching an existing
file and for anonymous or memfd-backed maps. The default is owner-only; pass a
wider mode such as C<0666> to opt in to cross-user sharing. Before version
0.14 the default was C<0666>.

B<Zero-cost when disabled>: with both C<$max_size=0> and C<$ttl=0>, the fast
lock-free read path is used. The only overhead is a branch (predicted away).

=head2 String Keys/Values and UTF-8

String-key variants (C<SS>, C<SI>, C<SI16>, C<SI32>) compare keys as raw
bytes: two keys are the same entry if and only if they contain the same
byte sequence. The SV UTF-8 flag is stored alongside the key so retrieval
round-trips it to the returned SV, but it is B<not> part of key identity.
Consequences:

=over

=item *

ASCII keys with a toggled UTF-8 flag hash and match the same entry
(C<use utf8>, C<utf8::upgrade>, and C<utf8::downgrade> on ASCII are all
equivalent from the map's point of view).

=item *

Non-ASCII keys with different byte encodings are B<distinct>. C<"caf\xe9">
(latin-1, 4 bytes) and the same character sequence under C<use utf8>
(C<"caf\xc3\xa9">, 5 UTF-8 bytes) are two different keys. If your input
comes in mixed encodings, normalize with
C<Encode::encode_utf8> before use.

=back

Because the flag is not part of key identity, the stored key keeps the flag it
had when the entry was first inserted: a later C<put> with the same bytes and
the opposite flag replaces the value but not the key, so C<keys> reports the
original flag.

String-value variants (C<SS>, C<IS>, C<I16S>, C<I32S>) store the SV UTF-8
flag alongside each value and round-trip it on retrieval. The C<cas>
comparison of C<$expected> against the stored value is byte-only -- the
UTF-8 flag on C<$expected> is ignored (same rationale as string-key
equality).

=head2 Sharding

    my $map = Data::HashMap::Shared::II->new_sharded($path_prefix, $shards, $max_entries, ...);

Creates C<$shards> independent maps (files C<$path_prefix.0>, C<$path_prefix.1>,
...) behind a single handle, each with up to C<$max_entries> entries
(each sized as if it were a map of its own -- see C<max_entries> below for what
the total comes to). Per-key operations automatically
route to the correct shard via hash dispatch. Writes to different shards
proceed in parallel with independent locks. C<new_sharded> requires a
filesystem C<$path_prefix>; anonymous (C<undef>-path) sharded maps are not
supported.

The batch ops (C<set_multi>, C<get_multi>, C<remove_multi>) dispatch each key
to its shard independently rather than holding one lock for the whole call, so
on a sharded map a batch is B<not> atomic across shards (the "single lock"
note in the API below applies to non-sharded maps).

All operations work transparently on sharded maps: C<put>, C<get>, C<remove>,
C<exists>, C<add>, C<update>, C<swap>, C<take>, C<incr>, C<max>, C<min>,
C<cas>, C<cas_take>, C<get_or_set>, C<put_ttl>, C<add_ttl>, C<update_ttl>,
C<touch>, C<persist>, C<set_ttl>, C<keys>, C<values>, C<items>, C<to_hash>,
C<set_multi> (method only), C<remove_multi> (method only), C<get_multi>
(method only), C<get_with_ttl> (method only), C<each>, C<pop>, C<shift>,
C<drain>, C<clear>, C<flush_expired>, C<flush_expired_partial>, C<size>,
C<stats> (method only), C<reserve>, and all diagnostic keywords.

Diagnostic counters and capacities reported for a sharded handle are
aggregate totals across all shards: C<size>, C<capacity>, C<max_entries>,
C<max_size>, C<tombstones>, C<mmap_size>, C<arena_used>, C<arena_cap>, and the
C<stats> eviction/expiry/recovery counts all sum over the shards. (C<ttl> is
the shared per-entry default, so it reports a single shard's value.)
C<reserve $n> pre-grows B<each> shard to C<$n> entries (not C<$n> in total).

Every shard file must come from the same configuration. Nothing checks this:
opening a set whose files disagree -- one left behind by an earlier run with a
different C<$ttl> or C<$max_size> -- succeeds, and each key then behaves
according to the shard it routes to. The accessors do not reveal it either:
C<ttl> and C<frozen> report shard 0's setting, while the summed ones add the
disagreeing values into a figure belonging to no shard at all (two shards
capped at 50 and 20 report C<max_size> 70).

Shard routing and slot placement both come from the same hash, so within a shard
only one home slot in C<$shards> is reachable -- that shard's own table capacity
divided by C<$shards>, and a single slot once C<$shards> reaches it. Probe runs
lengthen with the shard count and with the entries each shard holds: not
measurably at a handful of shards, around 2x at 4096 shards holding a few
entries each, and 10x or more at 4096 shards holding a thousand each. Use the
smallest shard count that relieves your lock contention, not the largest you can
afford.
C<max_entries> reports the entry count at the table's 75% design load, which is
three quarters of the maximum slot count and so is neither the constructor
argument nor the slot count -- a map created with 1000 reports 1536, over 2048
slots. It is not a hard ceiling either: the
table itself holds C<capacity> slots (the next power of two above the requested
load factor), and inserts keep succeeding until every slot is occupied. Probe
length grows sharply over the last few percent, though: a miss on a table at
99% costs roughly an order of magnitude more than at 95%, and one on a
completely full table has to walk every slot before it can report absence.
Treat C<max_entries> as the size to run at, not the size to reach. On a
TTL map C<size> counts entries that have expired but not yet been reclaimed,
which C<keys> and the iterators skip; C<flush_expired> reconciles the two.


Cursors chain across shards automatically. C<cursor_seek> routes to the
correct shard based on key hash. C<$shards> is rounded up to the next
power of 2.

=head2 API

Replace C<xx> with variant prefix: C<i16>, C<i32>, C<ii>, C<i16s>,
C<i32s>, C<is>, C<si16>, C<si32>, C<si>, C<ss>.

    my $ok = shm_xx_put $map, $key, $value;   # insert or overwrite
    my $ok = shm_xx_add $map, $key, $value;   # insert only if key absent
    my $ok = shm_xx_update $map, $key, $value; # overwrite only if key exists
    my $old = shm_xx_swap $map, $key, $value; # put + return old value (undef if new)
    my $ok = shm_xx_cas $map, $key, $expected, $desired; # compare-and-swap
    my $v  = shm_xx_cas_take $map, $key, $expected; # compare-and-remove; returns value on match, undef otherwise
    my $n  = $map->set_multi($k, $v, ...);   # batch put under single lock, returns count
    my $n  = $map->remove_multi(@keys);      # batch remove under single lock, returns count
    my @v  = $map->get_multi($k1, $k2, ...); # batch get under single lock with prefetch pipeline
    my ($v, $ttl) = $map->get_with_ttl($key); # atomic snapshot; () if missing, $ttl is undef on non-TTL map, 0 = permanent; sets LRU clock bit
    my $v  = shm_xx_get $map, $key;           # returns undef if not found
    my $ok = shm_xx_remove $map, $key;        # returns false if not found
    my $ok = shm_xx_exists $map, $key;        # returns boolean
    my $s  = shm_xx_size $map;
    my $m  = shm_xx_max_entries $map;
    my @k  = shm_xx_keys $map;
    my @v  = shm_xx_values $map;
    my @items = shm_xx_items $map;            # flat (k, v, k, v, ...)
    while (my ($k, $v) = shm_xx_each $map) { ... }  # auto-resets at end
    shm_xx_iter_reset $map;
    shm_xx_clear $map;
    my $href = shm_xx_to_hash $map;
    my $v  = shm_xx_get_or_set $map, $key, $default;  # returns value

Several calls below fail for want of room. B<No room> means the table is full
(every slot occupied -- see C<capacity>) or, on a variant with string keys or
values, the arena is.

C<get_or_set> returns the existing value, or stores and returns C<$default> when
the key is absent; C<undef> only when the key is absent and there is no room.

C<cas>, available for all variants, returns true when the stored value matched
C<$expected> and was atomically replaced with C<$desired>; false if the key is
missing or expired, the value did not match, or there is no room. See
L</"String Keys/Values and UTF-8"> for the byte-only comparison rule.

C<swap> returns the previous value, or C<undef> when the key did not exist -- and
B<also> C<undef> when there is no room, in which case an existing key keeps its
old value. It therefore cannot by itself tell a fresh insert from a failure;
check C<exists> or C<size> first if that matters. On a TTL map it refreshes an
existing entry's TTL to the default and assigns the default on insert, leaving a
permanent entry (TTL 0) permanent.

Integer-value variants also have:

    my $n = shm_xx_incr $map, $key;           # returns new value
    my $n = shm_xx_decr $map, $key;           # returns new value
    my $n = shm_xx_incr_by $map, $key, $delta;
    my $n = shm_xx_max $map, $key, $desired;  # store max(current, desired), return it
    my $n = shm_xx_min $map, $key, $desired;  # store min(current, desired), return it

A missing key is created starting from zero (Redis-style): the first
C<incr> returns 1, C<decr> returns -1, and C<incr_by> returns C<$delta>.
These die only when the key is new and there is no room for it. The result wraps
at the variant's integer width (see L</"Integer Range and Wrapping">).

C<max>/C<min> atomically store C<max($current, $desired)> /
C<min($current, $desired)> and return the resulting value; a missing key is
inserted as C<$desired>. The compare-and-set runs under a single lock
acquisition, so there is no read-modify-write gap for a concurrent
C<incr_by>/C<cas>/C<max>/C<min> on the same key: the result is monotonic
(C<max> never lowers, C<min> never raises) and never clobbers a concurrent
increment. On a map with neither LRU nor TTL the common "value already past the
bound" case completes under a shared read lock, writing nothing; with either
enabled every call takes the write lock, promotes the entry in the LRU order and
refreshes its TTL even when it stores nothing. Like C<incr_by>, they die only
when the key is new and there is no room for it, and the result wraps at the
variant's integer width.

LRU/TTL operations (C<put_ttl>, C<add_ttl>, and C<update_ttl> require a TTL-enabled map):

    my $ok = shm_xx_put_ttl $map, $key, $value, $ttl_sec;  # per-key TTL (0 = permanent); requires TTL-enabled map
    my $ok = shm_xx_add_ttl $map, $key, $value, $ttl_sec;  # insert-if-absent with per-key TTL (0 = permanent)
    my $ok = shm_xx_update_ttl $map, $key, $value, $ttl_sec; # overwrite-only with per-key TTL (0 = permanent)
    my $ms = shm_xx_max_size $map;            # LRU capacity (0 = disabled)
    my $t  = shm_xx_ttl $map;                 # default TTL in seconds
    my $r  = shm_xx_ttl_remaining $map, $key; # seconds left (0 = permanent, undef if missing/expired/no TTL)
    my $ok = shm_xx_touch $map, $key;         # refresh TTL to default (permanent entries stay permanent); promotes in LRU; false if no TTL/LRU
    my $ok = shm_xx_persist $map, $key;       # remove TTL, make key permanent; false on non-TTL maps
    my $ok = shm_xx_set_ttl $map, $key, $sec; # change TTL without changing value (0 = permanent); false on non-TTL maps
    my $n  = shm_xx_flush_expired $map;       # proactively expire all stale entries, returns count
    my ($n, $done) = shm_xx_flush_expired_partial $map, $limit;  # gradual: scan $limit slots ($limit per shard on sharded maps; $done true once every shard completes a cycle)

Atomic remove-and-return:

    my $v = shm_xx_take $map, $key;           # remove key and return value (undef if missing)
    my ($k, $v) = shm_xx_pop $map;            # remove+return from LRU tail / scan forward
    my ($k, $v) = shm_xx_shift $map;          # remove+return from LRU head / scan backward
    my @kv = shm_xx_drain $map, $n;           # remove+return up to N entries as flat (k,v,...) list

C<pop> and C<shift> remove from opposite ends: C<pop> takes the LRU tail
(oldest / least recently used) while C<shift> takes the LRU head (newest /
most recently used). On a sharded map they walk the shards in turn and take from
each shard's own end, so a sequence of C<pop>s is not in global recency order. On non-LRU maps, C<pop> scans forward and C<shift>
scans backward. C<drain> removes in C<pop> order (tail-first).
Useful for work-queue patterns and batch processing.

Cursors (independent iterators, allow nesting and removal during iteration):

    my $cur = shm_xx_cursor $map;             # create cursor
    while (my ($k, $v) = shm_xx_cursor_next $cur) { ... }
    shm_xx_cursor_reset $cur;                 # restart from beginning
    my $ok = shm_xx_cursor_seek $cur, $key;   # position at key (best-effort across resize); true if found, false if missing/expired
    # cursor auto-destroyed when out of scope

C<shm_xx_each> is also safe to use with C<remove> during iteration.

Leaving an C<each> loop early -- C<last>, C<return>, an exception -- leaves the
built-in iterator open on that handle, and tombstone compaction and shrink stay
deferred for as long as it is: a long-lived handle that keeps removing and
re-inserting keys then grows its table instead of compacting it, all the way to
its maximum slot count. Removals on their own leave tombstones without growing it.
Unlike Perl's C<each>, C<keys> does B<not> reset it. Call C<iter_reset> when you
abandon a pass, or run it to completion. The deferral is also per handle, not per
map, so another process can compact or shrink the table underneath your
iteration; that restarts it, and an abandoned pass can then yield keys it has
already returned.
Tombstone compaction and shrink are deferred until iteration ends; growth is
not -- a load-driven insert still resizes, and an iteration in progress restarts
on the resulting table-generation bump.  Compaction is likewise not deferred once
the table has reached its maximum capacity, can only be compacted in place, and
its load (live entries plus tombstones) has passed 75% of the slots --
since deferring it there would wedge a full table: an insert during an iteration
can restart it, and keys already visited are visited again.
On a sharded map a cursor restarts only
within the shard it has reached, so shards it already passed are not revisited;
take a fresh cursor after a C<clear> if you need a complete pass.

Diagnostics:

    my $cap = shm_xx_capacity $map;           # current table capacity (slots)
    my $tb  = shm_xx_tombstones $map;         # tombstone count
    my $au  = shm_xx_arena_used $map;         # arena high-water mark (0 for int-only)
    my $ac  = shm_xx_arena_cap $map;          # arena total capacity (0 for int-only)
    my $sz  = shm_xx_mmap_size $map;          # backing file size in bytes
    my $ok  = shm_xx_reserve $map, $n;        # pre-grow (false if exceeds max)
    my $ev  = shm_xx_stat_evictions $map;     # cumulative LRU eviction count
    my $ex  = shm_xx_stat_expired $map;       # cumulative TTL expiration count
    my $rc  = shm_xx_stat_recoveries $map;    # cumulative stale lock recovery count
    my $p   = $map->path;                    # backing file path (method only)
    my $s   = $map->stats;                   # hashref with all diagnostics in one call
    # stats keys: size, capacity, max_entries, tombstones, mmap_size,
    #   arena_used, arena_cap, evictions, expired, recoveries, max_size, ttl,
    #   frozen, readonly

C<set_multi>, C<get_multi>, C<remove_multi>, C<get_with_ttl>, C<stats>,
C<path>, C<sync>, and C<unlink> are method-only (no keyword form).

Keywords take their arguments as a list, so a keyword that takes more than one
argument must be written without parentheses around them:

    shm_ii_put $map, $key, $value;            # correct
    shm_ii_put($map, $key, $value);           # error, usually at compile time

A single-argument keyword accepts either form.  The method call
C<< $map->put($key, $value) >> is always available if you prefer parentheses.

C<keys>, C<values>, C<items>, C<each>, C<get_multi>, C<get_with_ttl>, C<pop>,
C<shift>, C<drain>, C<flush_expired_partial> and the cursor's C<next> return
lists. Like any Perl sub returning a list, in scalar context they yield their
B<last> element -- not a count, and not the first -- so call them in list
context and use C<size> when you want a count.

Calling C<no Data::HashMap::Shared::II;> disables that variant's keywords for
the rest of the enclosing lexical scope.

File management:

    $map->sync;                               # flush the mmap to the backing file (msync MS_SYNC)
    $map->unlink;                             # remove backing file (mmap stays valid)
    Data::HashMap::Shared::II->unlink($path); # class method form (single file)

C<sync> issues a synchronous C<msync(2)> over the whole mapping (every
shard, for sharded maps) and dies on error. Use it to force durability of
a file-backed map; it is a no-op for anonymous mappings, which have no
backing file. Changes are visible to other processes sharing the mapping
without C<sync> -- it only affects on-disk persistence.

C<unlink> reports through its return value rather than by dying: it returns
true when the file (every shard, for sharded maps) was removed and false
otherwise, including when the file was already gone and when removal was
refused -- a read-only directory, for instance. Check it if the removal
mattered; an ignored false is how a file survives a cleanup unnoticed.

=head2 Frozen (Read-Only) Mode

    $map->freeze;                                       # seal the file immutable (durable)
    my $ro = Data::HashMap::Shared::II->new_readonly($path);
    my $v  = $ro->get($key);                            # lock-free query; writes nothing
    my $is_frozen   = $map->frozen;                     # true once sealed
    my $is_readonly = $ro->readonly;                    # true for a read-only handle

C<freeze> permanently seals a map's contents so it can be shipped and served
read-only (it works on anonymous and memfd maps too, though only a file can be
shipped). It takes the write lock, sets a seal flag in the header, and
flushes it to disk (C<msync>). Afterwards every mutator on that handle croaks and
the handle itself becomes read-only. A sharded map seals every shard file.
Freezing is one-way; there is no unfreeze.

B<Quiesce your writers first.> A mutator tests the seal on entry and takes the
write lock afterwards, so another process already inside a mutating call when
C<freeze> runs completes its write after the seal: the sealed file changes once
more, and a C<new_readonly> reader -- which takes no lock precisely because a
sealed map cannot change -- can observe it. Seal a map only when nothing else is
writing to it. Stopping the writers, or a handshake that leaves them all idle, is
the caller's responsibility; C<freeze> cannot detect a writer that has passed the
check but not yet reached the lock.

On a sharded map this is not one straggling write. Whole-map and batch
operations -- C<set_multi>, C<remove_multi>, C<clear>, C<drain>, C<pop>,
C<shift>, C<flush_expired>, C<flush_expired_partial>, C<reserve> -- test the seal
once and then take each shard's lock in turn, so one that is under way when
C<freeze> lands keeps writing for the whole remainder of the call, across every
shard it has not reached yet. Quiescing matters more here, not less.

C<new_readonly> opens an already-frozen file with C<O_RDONLY> and maps it
C<PROT_READ>. Because a sealed map's contents cannot change and it can have no
new writers, queries
take B<no lock at all> -- no reader-slot bookkeeping, no LRU clock bit, no lazy
TTL cleanup -- and never write the mapping. A read-only view therefore works
from a read-only file or filesystem, and any number of processes can share one
frozen file at once. All queries and full iteration are supported: C<get>,
C<exists>, C<get_with_ttl>, C<get_multi>, C<keys>, C<values>, C<items>,
C<to_hash>, C<each>, and cursors (C<cursor> and C<cursor_next>). Every mutator
croaks (including the integer counters C<incr>/C<decr>/C<max>/C<min>, which on a
writable map update in place under the read lock). C<sync> is a silent no-op.
C<frozen> and C<readonly> report the state, and C<stats> gains matching
C<frozen> and C<readonly> keys.

The seal reuses a previously reserved header byte, so the on-disk format and
version are unchanged: a file written by an older release is simply not frozen
(the byte reads 0) and opens read-write exactly as before.

The two modes never mix: opening a frozen file read-write (C<new>,
C<new_from_fd>) is refused -- open it with C<new_readonly> instead -- and
C<new_readonly> refuses a file that has not been frozen (its lock-free readers
must never race a live writer).

C<new_readonly> is for a single backing file, and there is no read-only sharded
constructor, so C<freeze> on a sharded map seals a set that no constructor will
reopen: C<new_sharded> refuses the frozen shards, and reading it back means
opening each shard file by name and probing them. Freeze single-file maps.

B<Portability>: a frozen file is a raw memory image. Read it back on the B<same
architecture> that wrote it (same word size and endianness; the native magic and
variant id reject a mismatched or wrong-variant file at attach time). Ship it by
B<copying> the file; do not serve it over NFS or another network filesystem
while another host has it mapped.

=head2 Crash Safety

If a process dies (e.g., SIGKILL, OOM kill) while holding the write lock,
other processes detect the stale lock within 2 seconds and automatically
recover. The writer's PID is encoded in the rwlock word itself (single
atomic CAS, no crash window). On C<FUTEX_WAIT> timeout, waiters
C<kill($pid, 0)> the holder and CAS-release the lock if it's dead.

Reader-side recovery uses a 1024-slot table in the shared mmap (one slot
per B<handle>, claimed lazily on first lock -- a process holding several
handles on one map uses a slot for each; fork()'d children claim a
fresh slot via C<pthread_atfork>).  A reader's B<entire> contribution to
the lock is the C<rdepth> word in its own slot -- there is no shared
reader counter -- so a dead reader is neutralised by clearing that one
slot's PID, and a draining writer does so unconditionally as it scans.
Because no orphaned count can exist, there is no quiescent force-reset:
a worker killed mid-C<incr_by> cannot pin the lock at all.  An occupancy
bitmap (one bit per slot, published before the slot can hold a lock) lets
the writer visit only occupied slots rather than all 1024.  Beyond 1024
simultaneous handles per map, a handle that cannot claim a slot proceeds
"slotless"; see L</"Reader-slot exhaustion"> for the one case that
recovery cannot cover.

The same path validates and rebuilds the LRU doubly-linked list if a
dead writer left it inconsistent.  C<stat_recoveries> in C<stats> counts stale
B<write>-lock recoveries; a dead reader drained by a writer is not counted, so
the counter staying at zero does not mean nothing has been recovered.

Recovery uses C<kill($pid, 0)> for liveness, which cannot tell a reused PID from
the original -- and the lock word lives in the file, so it lasts as long as the
file does. Within one running system the risk is small: the holder must die in
the window it holds the lock B<and> the kernel must reissue that exact PID to a
long-lived process before the next waiter looks.

It is B<not> small once the file outlives the PID space that wrote it. A reboot,
a container restart against a persisted volume, or a copy taken while a writer
held the lock leaves a lock word naming a PID the new system may already have
reissued -- and for a low PID certainly has, those being init and kernel
threads, which never exit. If it went to a long-lived process, every writer
waits on a holder that will never release, unbounded and silent: no error, no
warning, no timeout; readers wait too when the crash was mid-publish (an odd
sequence counter). If it went to a short-lived one they stall until it exits,
and if it was never reissued the first writer recovers at once. Nothing in the
API can break such a lock -- the file has to be recreated. A killed B<reader>
strands its slot the same way, since that records a PID too, and the read lock
is held by C<each>, C<keys>, C<values>, C<items> and, without LRU or TTL, by
C<incr>, C<max> and C<min>. So carry a map across a reboot or a container
restart only if every process that used it exited cleanly, and copy one only
while nothing is using it.

B<Limitation>: PID-based recovery assumes all processes share the same
PID namespace. Cross-container sharing (different PID namespaces) is not
supported.

B<A full filesystem arrives as SIGBUS, not as an error.> The backing file is
sized once, at creation, for the map's maximum geometry, and its table and arena
are otherwise sparse: growing the table writes into pages that were never
allocated rather than extending the file. So C<mmap_size> is the space the file
will need once every page has been touched, not what it occupies now -- C<du>
reports less, and far less for a map with neither LRU nor TTL, since those two
side arrays are the part written in full at creation: a fresh LRU+TTL map is
already around 40% allocated where a plain one is well under 1% -- and
if the filesystem fills while a page is first written, the kernel raises SIGBUS
in the writing process instead of returning an error. One raised in the middle
of a table resize takes with it the entries not yet re-inserted, exactly as a
SIGKILL there would. Leave C<mmap_size> bytes of headroom on the filesystem, or
C<fallocate -l> the file after creating it to take the allocation failure up
front rather than at an arbitrary later insert. Use B<exactly> C<mmap_size>
bytes: a file longer than the size recorded in its header is refused as corrupt,
and for a sharded set C<mmap_size> is the total across shards, so use each shard
file's own size rather than the aggregate.

After recovery from a mid-mutation crash, the map data may be partially
inconsistent (e.g., one entry was being updated when the writer died).
Locks, the LRU chain and the entry counters are restored. The arena free
lists are not rebuilt, so blocks in flight at the crash may leak; the specific
entry being mutated may have stale or partial bytes; and a crash part-way
through a table resize permanently drops the entries that had not yet been
re-inserted, because they existed only in the dead writer's private buffer.
Calling
C<clear> after detecting a stale lock recovery is recommended for
safety-critical applications.

An interrupted B<create> is recovered too. A creator killed after the file is
sized but before its header is committed leaves a full-size, all-zero file,
which C<new> re-initializes -- but only when the file is exactly the size the
requested geometry needs, is owned by your effective uid, and is still entirely
zero. A file holding data is never re-initialized. If the creator got as far as
writing part of the header the file cannot be told from a corrupt one, and
C<new> croaks with C<incomplete map file left by an interrupted create; remove
it and retry>. An abandoned create never held data, so removing it is safe --
but a header corrupted after the fact reaches the same croak, so check before
deleting anything you care about.

Recovery is run by whichever process next takes a lock, readers included, and
comes from the code that touches the file -- so a map shared with a process
running anything older than 0.18 keeps that release's crash windows. Upgrade
every process sharing a map together.

=head2 Reader-slot exhaustion

Dead-process recovery attributes a
crashed lock holder's contribution through its reader-slot. The slot table holds
1024 entries, one per open handle rather than per process. If more handles than
that are open on one mapping at once, a reader that cannot claim a slot proceeds
"slotless" -- it still takes the read lock but leaves no per-process record. If
such a slotless reader is then killed while holding the read lock, its share of
the lock cannot be attributed to a dead process, so writer recovery cannot
reclaim it and writers may block until the mapping is recreated. Reaching this
needs more than 1024 handles open on one mapping at once plus a crash in
the brief read-lock window; the dead-process slot reclaim keeps the table from
filling with stale entries, so in practice it is very unlikely.

=head1 BENCHMARKS

Throughput versus other shared-memory / on-disk solutions, 25K entries,
single process, Linux x86_64.  Each benchmarked sub runs over all 25,000
entries, so the figures below are C<Benchmark> rates -- whole passes per second,
higher is better -- and not operations per second.  Multiply by 25,000 for the
rate of the operation named: C<Shared::II> LOOKUP at 383 is about 9.6 M
lookups/s.  (A pass can do more than the operation it is named for: DELETE
refills the map first, so its 25,000 removals come with 25,000 inserts.)  The
cross-process table further down is already in operations per second.
Run C<perl -Mblib bench/vs.pl 25000> to reproduce.

B<Integer key -> integer value> (Shared::II):

              BerkeleyDB   LMDB   Shared::II
    INSERT          31       46         184
    LOOKUP          35       40         383
    INCREMENT       16       18         165

B<String key -> string value, short> (inline <= 7B, Shared::SS):

              FastMmap   BerkeleyDB   LMDB   SharedMem   Shared::SS
    INSERT        11          26       40        62          130
    LOOKUP        10          32       34       146          213
    DELETE        14          18       --        32           68

B<String key -> string value, long> (~50-100B, Shared::SS):

              BerkeleyDB   LMDB   SharedMem   Shared::SS
    INSERT        25         37        61          133
    LOOKUP        30         33       125          229

B<LRU cache lookup> (25K entries, lock-free clock eviction):

              plain   LRU
    II         350    373   (lock-free, ~6% faster via clock)
    SS         159    159

B<Cross-process> (25K SS entries, 2 processes, ops/s):

                  Shared::SS   SharedMem       LMDB
    READS        3,250,000    1,986,000     728,000
    WRITES       2,801,000      826,000      95,000
    MIXED 50/50  3,691,000    1,963,000     211,000

LMDB benchmarked with MDB_WRITEMAP|MDB_NOSYNC|MDB_NOMETASYNC|MDB_NORDAHEAD.
BerkeleyDB with DB_PRIVATE|128MB cache.

Key takeaways:

=over

=item * B<10x> faster lookups than LMDB for integer keys (lock-free seqlock path)

=item * B<1.5x> faster than Hash::SharedMem for short string lookups (inline strings, no arena overhead)

=item * B<1.8x> faster than Hash::SharedMem for long string lookups

=item * B<4.5x> faster cross-process reads than LMDB; B<3.4x> faster writes than SharedMem

=item * LRU reads are lock-free (clock eviction) -- no overhead vs plain maps

=item * Atomic C<incr> is B<9x> faster than get+put on competitors

=item * Strings <= 7 bytes stored inline in node (zero arena overhead)

=back

=head1 SEE ALSO

L<Data::Buffer::Shared> - typed shared array

L<Data::Queue::Shared> - FIFO queue

L<Data::PubSub::Shared> - publish-subscribe ring

L<Data::ReqRep::Shared> - request-reply

L<Data::Sync::Shared> - synchronization primitives

L<Data::Pool::Shared> - fixed-size object pool

L<Data::Stack::Shared> - LIFO stack

L<Data::Deque::Shared> - double-ended queue

L<Data::Log::Shared> - append-only log (WAL)

L<Data::Heap::Shared> - priority queue

L<Data::Graph::Shared> - directed weighted graph

L<Data::BitSet::Shared> - shared bitset (lock-free per-bit ops)

L<Data::RingBuffer::Shared> - fixed-size overwriting ring buffer

=head1 SECURITY

Backing files are created with mode C<0600> (owner-only) by default, so only
the creating user can open and attach them. To share a backing file across
users, pass an explicit octal file mode such as C<0660> as the last argument
to C<new>; the mode is applied when the file is created, and when a file left
behind by an interrupted create is re-initialized (see L</"Crash Safety">); a
file already in use keeps its own permissions. The file is opened with
C<O_NOFOLLOW>, so a symlink planted at the path is refused, and created with
C<O_EXCL>; the on-disk header is validated when the file is attached. Any
process you grant write access to a shared mapping is trusted not to corrupt
its contents while other processes are using it.

A backing file written before 0.16 uses the previous on-disk format and is
rejected with a version-mismatch error when attached; recreate the map from
its source data. Anonymous and memfd maps are process-local and unaffected.

=head1 AUTHOR

vividsnow

=head1 LICENSE

This is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

It bundles xxHash by Yann Collet, used under the BSD 2-Clause licence; see
F<LICENSE.xxhash> in the distribution.

=cut
