#!/usr/bin/env perl

# [[[ PREPROCESSOR ]]]
# <<< PARSE_ERROR: 'ERROR ECOPAPL02' >>>
# <<< PARSE_ERROR: 'near "my   ="' >>>

# [[[ HEADER ]]]
use strict;
use warnings;
use types;
our $VERSION = 0.001_000;

# [[[ CONSTANTS ]]]
## no critic qw(ProhibitConstantPragma ProhibitMagicNumbers)  # USER DEFAULT 3: allow constants
use constant PI  => my   = 3.141_59;
use constant PIE => my string $TYPED_PIE = 'pecan';

# [[[ OPERATIONS ]]]
my integer $i = 2 + 2;