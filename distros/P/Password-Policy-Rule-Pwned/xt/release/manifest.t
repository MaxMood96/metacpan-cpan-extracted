use strict;
use warnings;

use Test::More;
use Test::DistManifest;

manifest_ok ('MANIFEST', '../MANIFEST.SKIP');
done_testing;
