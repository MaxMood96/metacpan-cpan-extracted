package TestApp;

use strict;
use warnings;

# Sealing is controlled with CATALYST_SEAL so that one application source can
# be driven both ways, which is what t/20-parity.t compares.
use Catalyst::Seal;

use Catalyst::Runtime 5.80;
use Catalyst;

__PACKAGE__->config(
    name                                        => 'TestApp',
    disable_component_resolution_regex_fallback => 1,
    enable_catalyst_header                      => 0,
);

__PACKAGE__->setup();

1;
