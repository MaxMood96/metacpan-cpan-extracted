# [[[ PREPROCESSOR ]]]
# <<< PARSE_ERROR: 'ERROR ECOPARP00' >>>
# <<< PARSE_ERROR: 'Unexpected Token:  $RETURN_VALUE' >>>

# [[[ HEADER ]]]
package Perl::Types::Test::SubroutineArguments::Package_10_Bad_00;
use strict;
use warnings;
use types;
our $VERSION = 0.001_000;

# [[[ SUBROUTINES ]]]
sub empty_sub { { my void $RETURN_VALUE }; ( my number $foo ) = @ARG; return; }

1;    # end of package
