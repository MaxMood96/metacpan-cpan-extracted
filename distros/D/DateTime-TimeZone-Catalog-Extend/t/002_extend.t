#!perl
BEGIN
{
    use strict;
    use warnings;
    use lib './lib';
    use vars qw( $DEBUG );
    use Test::More qw( no_plan );
    use DateTime::TimeZone;
    our $DEBUG = exists( $ENV{AUTHOR_TESTING} ) ? $ENV{AUTHOR_TESTING} : 0;
};

BEGIN
{
    use_ok( 'DateTime::TimeZone::Catalog::Extend' ) || 
        BAIL_OUT( "Failed to load DateTime::TimeZone::Catalog::Extend" );;
};

use strict;
use warnings;

local $@;
foreach my $alias ( sort( keys( %$DateTime::TimeZone::Catalog::Extend::ALIAS_CATALOG ) ) )
{
    # try-catch
    eval
    {
        my $tz = DateTime::TimeZone->new( name => $alias );
        isa_ok( $tz => 'DateTime::TimeZone', $alias );
    };
    if( $@ )
    {
        fail( "Failed to instantiate a DateTime::TimeZone object for alias \"$alias\": $@" );
    }
}

my $ref = DateTime::TimeZone::Catalog::Extend->aliases;
is( scalar( @$ref ), scalar( keys( %$DateTime::TimeZone::Catalog::Extend::ALIAS_CATALOG ) ), 'aliases' );

done_testing();

__END__

