# [[[ HEADER ]]]
package Perl::Structure::Hash;
use strict;
use warnings;
use Perl::Config;  # don't use Perl::Types inside itself, in order to avoid circular includes
our $VERSION = 0.009_000;

# [[[ OO INHERITANCE ]]]
use parent qw(Perl::Structure);
use Perl::Structure;

# [[[ SUB-TYPES BEFORE INCLUDES ]]]
use Perl::Structure::Hash::SubTypes;
use Perl::Structure::Hash::SubTypes1D;
use Perl::Structure::Hash::SubTypes2D;
use Perl::Structure::Hash::SubTypes3D;

# [[[ INCLUDES ]]]
# for type-checking via SvIOKp(), SvNOKp(), and SvPOKp(); inside INIT to delay until after 'use MyConfig'
#INIT { Perl::diag("in Hash.pm, loading C++ helper functions for type-checking...\n"); }
INIT {
    use Perl::HelperFunctions_cpp;
    Perl::HelperFunctions_cpp::cpp_load();
}

use Perl::Type::Void;
use Perl::Type::Boolean;
use Perl::Type::NonsignedInteger;
use Perl::Type::Integer;
use Perl::Type::Number;
use Perl::Type::Character;
use Perl::Type::String;
use Perl::Type::Scalar;
use Perl::Type::Unknown;
use Perl::Structure::Array;

# [[[ EXPORTS ]]]
# DEV NOTE: avoid "Undefined subroutine &main::integer_to_string called"
use Exporter 'import';
our @EXPORT = ( @Perl::Type::Void::EXPORT, 
                @Perl::Type::Boolean::EXPORT, 
                @Perl::Type::NonsignedInteger::EXPORT, 
                @Perl::Type::Integer::EXPORT, 
                @Perl::Type::Number::EXPORT, 
                @Perl::Type::Character::EXPORT, 
                @Perl::Type::String::EXPORT, 
                @Perl::Type::Scalar::EXPORT, 
                @Perl::Type::Unknown::EXPORT, 
                @Perl::Structure::Array::EXPORT);

# DEV NOTE, CORRELATION #rp018: Perl::Structure::Array & Hash can not 'use RPerl;' so *__MODE_ID() subroutines are hard-coded here
package main;
use strict;
use warnings;
sub Perl__Structure__Hash__MODE_ID { return 0; }

1;  # end of class
