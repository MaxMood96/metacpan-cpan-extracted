use strict;
use warnings;
use Test::More tests => 7;

use object;
use const;

# Test object with const values

BEGIN {
    object::define('AppConfig', qw(name settings));
    object::define('Container', qw(items));
}

# Create object with const settings
my $immutable_settings = const::c({
    timeout => 30,
    retries => 3,
    debug => 0
});

my $config = new AppConfig 'production', $immutable_settings;

is($config->name, 'production', 'object name set');
is_deeply($config->settings, { timeout => 30, retries => 3, debug => 0 }, 'const settings stored');

# Object name can be changed (object is mutable)
$config->name('staging');
is($config->name, 'staging', 'object property changed');

# But the const value inside cannot be modified
my $settings = $config->settings;
eval { $settings->{timeout} = 60 };
like($@, qr/read-?only|Modification/i, 'cannot modify const value in object');

# Create multiple configs with same const
my $config2 = new AppConfig 'development', $immutable_settings;
is($config2->settings->{timeout}, 30, 'second object shares const');

# Object with const array
my $const_list = const::c([qw(a b c d)]);
my $container = new Container $const_list;

is_deeply($container->items, [qw(a b c d)], 'const array in object');

# Frozen object behavior
object::freeze($config);
ok(object::is_frozen($config), 'object is frozen');
