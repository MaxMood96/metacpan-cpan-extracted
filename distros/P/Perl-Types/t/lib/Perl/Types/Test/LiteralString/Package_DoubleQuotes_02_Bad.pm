# [[[ PREPROCESSOR ]]]
# <<< PARSE_ERROR: 'ERROR ECOPAPL02' >>>
# <<< PARSE_ERROR: 'Global symbol "$bar" requires explicit "use types;"
package name' >>>

# [[[ HEADER ]]]
package Perl::Types::Test::LiteralString::Package_DoubleQuotes_02_Bad;
use strict;
use warnings;
our $VERSION = 0.001_000;

# [[[ SUBROUTINES ]]]
sub empty_sub { { my string $RETURN_TYPE }; return "$bar"; }

1;    # end of package
