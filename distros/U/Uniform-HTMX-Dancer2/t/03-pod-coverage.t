use strict;
use warnings;
use Test::More;

eval "use Test::Pod::Coverage 1.04";
plan skip_all => "Test::Pod::Coverage 1.04 required for testing POD coverage" if $@;

# Dancer2::Plugin injects a number of internal methods (BUILD, register,
# register_plugin, on_plugin_import, hook, dsl, app, config, etc.) into
# every plugin package. These are documented by Dancer2::Plugin itself,
# not by us, so they're excluded here per the pattern recommended in
# Dancer2::Plugin's own POD.
pod_coverage_ok(
    'Uniform::HTMX::Dancer2', {
        also_private => [
            qw/
              BUILD BUILDARGS ClassHooks PluginKeyword dancer_app
              execute_plugin_hook hook keywords on_plugin_import plugin_args
              plugin_setting realms realm realm_providers register register_hook
              register_plugin request var
              /
        ],
    },
);

done_testing();
