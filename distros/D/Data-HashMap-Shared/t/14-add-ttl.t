use strict;
use warnings;
use Test::More;
use File::Temp ();
use File::Spec ();

use Data::HashMap::Shared::I16;
use Data::HashMap::Shared::I32;
use Data::HashMap::Shared::II;
use Data::HashMap::Shared::I16S;
use Data::HashMap::Shared::I32S;
use Data::HashMap::Shared::IS;
use Data::HashMap::Shared::SI16;
use Data::HashMap::Shared::SI32;
use Data::HashMap::Shared::SI;
use Data::HashMap::Shared::SS;

sub tmpfile { File::Temp::tempnam(File::Spec->tmpdir, 'shm_addttl') . '.shm' }

# II: add_ttl on TTL-enabled map (keyword form + method form)
{
    my $path = tmpfile();
    my $map = Data::HashMap::Shared::II->new($path, 1000, 0, 30);  # default TTL 30s

    # Keyword form: insert with explicit TTL larger than default
    ok(shm_ii_add_ttl $map, 1, 100, 120, 'II add_ttl kw: succeeds on new key');
    is($map->get(1), 100, 'II add_ttl: value stored');
    my $rem = shm_ii_ttl_remaining $map, 1;
    ok($rem > 30, "II add_ttl: TTL > default (rem=$rem)");
    ok($rem <= 120, "II add_ttl: TTL within explicit value (rem=$rem)");

    # Existing key: add_ttl fails, value/TTL unchanged
    ok(!(shm_ii_add_ttl $map, 1, 999, 5), 'II add_ttl: fails on existing key');
    is($map->get(1), 100, 'II add_ttl: existing value unchanged on collision');
    my $rem2 = shm_ii_ttl_remaining $map, 1;
    ok($rem2 > 30, "II add_ttl collision: TTL unchanged (rem=$rem2)");

    # Permanent (ttl=0)
    ok(shm_ii_add_ttl $map, 2, 200, 0, 'II add_ttl: succeeds with ttl=0');
    my $perm = shm_ii_ttl_remaining $map, 2;
    is($perm, 0, 'II add_ttl: ttl=0 → permanent');

    # Method form
    ok($map->add_ttl(3, 300, 90), 'II add_ttl: method form');
    is($map->get(3), 300, 'II add_ttl method: value stored');

    unlink $path;
}

# SI: string key
{
    my $path = tmpfile();
    my $map = Data::HashMap::Shared::SI->new($path, 1000, 0, 30);
    ok(shm_si_add_ttl $map, "k", 10, 60, 'SI add_ttl: succeeds');
    ok(!(shm_si_add_ttl $map, "k", 20, 60), 'SI add_ttl: fails on existing');
    is($map->get("k"), 10, 'SI add_ttl: value unchanged on collision');
    my $rem = shm_si_ttl_remaining $map, "k";
    ok($rem > 30 && $rem <= 60, "SI add_ttl: TTL applied (rem=$rem)");
    unlink $path;
}

# IS: int key, string value
{
    my $path = tmpfile();
    my $map = Data::HashMap::Shared::IS->new($path, 1000, 0, 30);
    ok(shm_is_add_ttl $map, 1, "hello", 60, 'IS add_ttl: succeeds');
    is($map->get(1), "hello", 'IS add_ttl: value stored');
    ok(!(shm_is_add_ttl $map, 1, "world", 60), 'IS add_ttl: fails on existing');
    is($map->get(1), "hello", 'IS add_ttl: value unchanged on collision');
    unlink $path;
}

# SS: string key, string value
{
    my $path = tmpfile();
    my $map = Data::HashMap::Shared::SS->new($path, 1000, 0, 30);
    ok(shm_ss_add_ttl $map, "k", "v1", 60, 'SS add_ttl: succeeds');
    is($map->get("k"), "v1", 'SS add_ttl: value stored');
    ok(!(shm_ss_add_ttl $map, "k", "v2", 60), 'SS add_ttl: fails on existing');
    is($map->get("k"), "v1", 'SS add_ttl: value unchanged on collision');
    my $rem = shm_ss_ttl_remaining $map, "k";
    ok($rem > 30 && $rem <= 60, "SS add_ttl: per-key TTL applied (rem=$rem)");
    unlink $path;
}

# Smoke tests for the remaining six variants — verify each XS binding
# routes correctly and TTL is honored. Logic is shared via templated C.
{
    my $path = tmpfile();
    my $map = Data::HashMap::Shared::I16->new($path, 1000, 0, 30);
    ok($map->add_ttl(1, 10, 90), 'I16 add_ttl: succeeds');
    ok(!$map->add_ttl(1, 20, 90), 'I16 add_ttl: fails on existing');
    is($map->get(1), 10, 'I16 add_ttl: value unchanged on collision');
    my $rem = shm_i16_ttl_remaining $map, 1;
    ok($rem > 30 && $rem <= 90, "I16 add_ttl: per-key TTL applied (rem=$rem)");
    unlink $path;
}
{
    my $path = tmpfile();
    my $map = Data::HashMap::Shared::I32->new($path, 1000, 0, 30);
    ok($map->add_ttl(1, 100, 90), 'I32 add_ttl: succeeds');
    ok(!$map->add_ttl(1, 200, 90), 'I32 add_ttl: fails on existing');
    is($map->get(1), 100, 'I32 add_ttl: value unchanged');
    unlink $path;
}
{
    my $path = tmpfile();
    my $map = Data::HashMap::Shared::SI16->new($path, 1000, 0, 30);
    ok($map->add_ttl("k", 10, 90), 'SI16 add_ttl: succeeds');
    ok(!$map->add_ttl("k", 20, 90), 'SI16 add_ttl: fails on existing');
    is($map->get("k"), 10, 'SI16 add_ttl: value unchanged');
    unlink $path;
}
{
    my $path = tmpfile();
    my $map = Data::HashMap::Shared::SI32->new($path, 1000, 0, 30);
    ok($map->add_ttl("k", 100, 90), 'SI32 add_ttl: succeeds');
    ok(!$map->add_ttl("k", 200, 90), 'SI32 add_ttl: fails on existing');
    is($map->get("k"), 100, 'SI32 add_ttl: value unchanged');
    unlink $path;
}
{
    my $path = tmpfile();
    my $map = Data::HashMap::Shared::I16S->new($path, 1000, 0, 30);
    ok($map->add_ttl(1, "hello", 90), 'I16S add_ttl: succeeds');
    ok(!$map->add_ttl(1, "world", 90), 'I16S add_ttl: fails on existing');
    is($map->get(1), "hello", 'I16S add_ttl: value unchanged');
    unlink $path;
}
{
    my $path = tmpfile();
    my $map = Data::HashMap::Shared::I32S->new($path, 1000, 0, 30);
    ok($map->add_ttl(1, "hello", 90), 'I32S add_ttl: succeeds');
    ok(!$map->add_ttl(1, "world", 90), 'I32S add_ttl: fails on existing');
    is($map->get(1), "hello", 'I32S add_ttl: value unchanged');
    unlink $path;
}

# add_ttl on map without TTL → croak
{
    my $path = tmpfile();
    my $map = Data::HashMap::Shared::II->new($path, 100);  # no TTL
    eval { $map->add_ttl(1, 1, 60) };
    like($@, qr/TTL-enabled/, 'add_ttl croaks on non-TTL map');
    unlink $path;
}

# add_ttl on expired entry should succeed (expired treated as absent)
{
    my $path = tmpfile();
    my $map = Data::HashMap::Shared::II->new($path, 100, 0, 30);
    shm_ii_put_ttl $map, 1, 100, 1;   # expires in 1s
    sleep 2;
    ok(shm_ii_add_ttl $map, 1, 200, 60, 'II add_ttl: succeeds when prior entry expired');
    is($map->get(1), 200, 'II add_ttl: re-added value visible');
    unlink $path;
}

# Regression (0.19): the per-key TTL arguments were cast straight to uint32,
# so a value at or above 2**32 wrapped -- put_ttl($k,$v,2**32) silently made the
# entry PERMANENT rather than failing.  The constructor's ttl and reserve()
# already rejected out-of-range values; these four now match.
{
    my $path = tmpfile();
    my $map  = Data::HashMap::Shared::II->new($path, 100, 0, 30);
    $map->put(1, 1);

    for my $method (qw(put_ttl add_ttl update_ttl)) {
        my $ok = eval { $map->$method(2, 2, 2**32); 1 };
        ok !$ok, "$method rejects a ttl of 2**32 instead of truncating it";
        like $@, qr/ttl .* exceeds the maximum/, "  ...with a range error";
    }
    my $ok = eval { $map->set_ttl(1, 2**32); 1 };
    ok !$ok, 'set_ttl rejects a ttl of 2**32';

    ok !eval { $map->flush_expired_partial(2**32); 1 },
        'flush_expired_partial rejects a limit of 2**32 instead of scanning one slot';

    ok eval { $map->put_ttl(3, 3, 120); 1 }, 'an in-range ttl still works';
    cmp_ok $map->ttl_remaining(3), '>=', 119, '  ...and is stored (allowing one coarse-clock tick)';
    cmp_ok $map->ttl_remaining(3), '<=', 120, '  ...and not rounded up';
    unlink $path;
}

done_testing;
