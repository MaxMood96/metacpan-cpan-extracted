# -*- perl -*-
BEGIN
{
    use strict;
    use warnings;
    use Cwd qw( abs_path );
    use lib abs_path( './lib' );
    use vars qw( $DEBUG @modules );
    use Test::More qw( no_plan );
    use File::Find;
    our @modules;
    File::Find::find(sub
    {
        return unless( /\.pm$/ );
        # print( "Checking file '$_' ($File::Find::name)\n" );
        $_ = $File::Find::name;
        s,^./lib/,,;
        s,\.pm$,,;
        s,/,::,g;
        push( @modules, $_ );
    }, qw( ./lib ) );
    our $DEBUG = exists( $ENV{AUTHOR_TESTING} ) ? $ENV{AUTHOR_TESTING} : 0;
};

use strict;
use warnings;

BEGIN
{
    use strict;
    use warnings;
    for( sort( @modules ) )
    {
        diag( "Checking module $_" ) if( $DEBUG );
        use_ok( $_ );
    }
};

done_testing();

# To generate the list of modules:
# find ./lib -type f -name "*.pm" -print | xargs perl -lE 'my @f=sort(@ARGV); for(@f) { s,./lib/,,; s,\.pm$,,; s,/,::,g; substr( $_, 0, 0, q{use_ok( ''} ); $_ .= q{'' );}; say $_; }'
