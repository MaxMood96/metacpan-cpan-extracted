# [[[ PREPROCESSOR ]]]
# <<< TYPE_CHECKING: TRACE >>>

# [[[ HEADER ]]]

package Perl::Types::Test::Subclass::MySubclassersFG_Good;
use strict;
use warnings;
use types;
our $VERSION = 0.001_000;

# [[[ OO INHERITANCE ]]]
use parent qw(Perl::Types::Test);
use Perl::Types::Test;

# [[[ CRITICS ]]]
## no critic qw(ProhibitUselessNoCritic ProhibitMagicNumbers RequireCheckedSyscalls)  # USER DEFAULT 1: allow numeric values & print operator
## no critic qw(Capitalization ProhibitMultiplePackages ProhibitReusedNames)  # SYSTEM DEFAULT 3: allow multiple & lower case package names

# [[[ OO PROPERTIES ]]]
our hashref $properties = { bax => my integer $TYPED_bax = 123 };

# [[[ SUBROUTINES & OO METHODS ]]]

sub multiply_bax_FG {
    { my void $RETURN_TYPE };
    ( my Perl::Types::Test::Subclass::MySubclassersFG_Good $self, my integer $multiplier ) = @ARG;
    $self->{bax} = $self->{bax} * $multiplier;
    return;
}

sub multiply_return_FG { { my number $RETURN_TYPE }; ( my integer $multiplicand, my number $multiplier ) = @ARG; return $multiplicand * $multiplier; }

1;    # end of class


package Perl::Types::Test::Subclass::MySubclasserF_Good;
use strict;
use warnings;
use types;
our $VERSION = 0.001_000;

# [[[ OO INHERITANCE ]]]
use parent -norequire, qw(Perl::Types::Test::Subclass::MySubclassersFG_Good);
INIT { Perl::Types::Test::Subclass::MySubclassersFG_Good->import(); }

# [[[ OO PROPERTIES ]]]
our hashref $properties = { xab => my integer $TYPED_xab = 321 };

# [[[ SUBROUTINES & OO METHODS ]]]

sub multiply_bax_F {
    { my void $RETURN_TYPE };
    ( my Perl::Types::Test::Subclass::MySubclasserF_Good $self, my integer $multiplier ) = @ARG;
    $self->{bax} = $self->{bax} * $multiplier;
    return;
}

sub multiply_return_F { { my number $RETURN_TYPE }; ( my integer $multiplicand, my number $multiplier ) = @ARG; return $multiplicand * $multiplier; }

1;    # end of class


package Perl::Types::Test::Subclass::MySubclasserG_Good;
use strict;
use warnings;
use types;
our $VERSION = 0.001_000;

# [[[ OO INHERITANCE ]]]
use parent -norequire, qw(Perl::Types::Test::Subclass::MySubclasserF_Good);
INIT { Perl::Types::Test::Subclass::MySubclasserF_Good->import(); }

# [[[ OO PROPERTIES ]]]
our hashref $properties = { xba => my integer $TYPED_xba = 312 };

# [[[ SUBROUTINES & OO METHODS ]]]

sub multiply_bax_G {
    { my void $RETURN_TYPE };
    ( my Perl::Types::Test::Subclass::MySubclasserG_Good $self, my integer $multiplier ) = @ARG;
    $self->{bax} = $self->{bax} * $multiplier;
    return;
}

sub multiply_return_G { { my number $RETURN_TYPE }; ( my integer $multiplicand, my number $multiplier ) = @ARG; return $multiplicand * $multiplier; }

1;    # end of class
