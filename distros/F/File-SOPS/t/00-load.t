#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

# First, and deliberately: File::SOPS pulls this in through
# File::SOPS::Encrypted, so anywhere below here the load would be a no-op and
# could not fail. What is checked is that it stands on its own (k147).
use_ok('File::SOPS::Comment');

# Also first, and for the same reason: File::SOPS pulls this in through
# File::SOPS::Format::ENV, which is a format handler and so loaded eagerly,
# so below the next line this would be a no-op too (k153).
use_ok('File::SOPS::Metadata::Flat');

# And again for the same reason, with two handlers pulling it in rather than
# one: File::SOPS loads Format::ENV and Format::INI eagerly and both of them
# load this, so below the next line it would be a no-op as well (k158).
use_ok('File::SOPS::Format::ENV::Ordered');

use_ok('File::SOPS');
use_ok('File::SOPS::Encrypted');
use_ok('File::SOPS::Metadata');
use_ok('File::SOPS::Backend::Age');
use_ok('File::SOPS::Format::YAML');
use_ok('File::SOPS::Format::JSON');
# Both are loaded by File::SOPS above, so these are no-ops that cannot fail --
# they are here so that a handler dropped from that list is still noticed
# (k155, which was filed when Format::ENV was missing from this file).
use_ok('File::SOPS::Format::ENV');
use_ok('File::SOPS::Format::INI');

done_testing;
