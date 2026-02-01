use strict;
use warnings;
use Test::More tests => 13;

# Integration test using all modules together

use slot qw(app_cache app_config);
use lru;
use const;
use doubly;
use object;
use util qw(memo is_hash);

# Setup: Create an application-like structure using multiple modules

# 1. Global cache via slot
app_cache(lru::new(100));
ok(defined app_cache(), 'global cache created via slot');

# 2. Immutable config via const stored in slot
app_config(const::c({
    app_name => 'TestApp',
    version => '1.0.0',
    max_items => 50
}));

is(app_config()->{app_name}, 'TestApp', 'config accessible via slot');
ok(is_hash(app_config()) ? 1 : 0, 'config is a hash');

# 3. Define an object type
BEGIN {
    object::define('Item', qw(id value));
}

# 4. Create items and cache them
for my $i (1..5) {
    my $item = new Item $i, "value_$i";
    app_cache()->set("item:$i", $item);
}

is(app_cache()->size, 5, 'items cached');

# 5. Use doubly linked list to track access order
my $access_log = doubly->new();

sub get_item {
    my $id = shift;
    my $item = app_cache()->get("item:$id");
    if ($item) {
        $access_log->add($id);
    }
    return $item;
}

my $item1 = get_item(1);
my $item3 = get_item(3);
my $item1_again = get_item(1);

is($access_log->length, 3, 'access log has 3 entries');

# 6. Memoized computation using cached data
my $compute_calls = 0;
my $expensive_compute = memo(sub {
    my $item = shift;
    $compute_calls++;
    return $item->value . '_processed';
});

my $result1 = $expensive_compute->($item1);
my $result2 = $expensive_compute->($item1);  # Should use memo cache

is($result1, 'value_1_processed', 'computation result correct');
is($compute_calls, 1, 'memoization works across modules');

# 7. Verify all modules still work correctly together
is(app_cache()->get('item:2')->id, 2, 'cache still works');
is(app_config()->{version}, '1.0.0', 'config unchanged');
ok($access_log->start->data == 1, 'access log first entry correct');

# 8. Test const with object
my $const_item = new Item 99, const::c('immutable_value');
app_cache()->set('const_item', $const_item);

my $retrieved = app_cache()->get('const_item');
is($retrieved->value, 'immutable_value', 'const value in object in cache');

# 9. Use util to check types
ok(is_hash(app_config()) ? 1 : 0, 'util works with slot value');

# 10. Cleanup cache - verify no crashes
app_cache()->clear;
is(app_cache()->size, 0, 'cache cleared');
