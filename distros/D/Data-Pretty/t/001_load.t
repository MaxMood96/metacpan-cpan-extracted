# -*- perl -*-
BEGIN
{
    use strict;
    use lib './lib';
    use Test::More qw( no_plan );
};

# To build the list of modules:
# find ./lib -type f -name "*.pm" -print | xargs perl -lE 'my @f=sort(@ARGV); for(@f) { s,./lib/,,; s,\.pm$,,; s,/,::,g; substr( $_, 0, 0, q{use ok( ''} ); $_ .= q{'' );}; say $_; }'
BEGIN
{
    use ok( 'Data::Pretty' );
    use ok( 'Data::Pretty::FilterContext' );
    use ok( 'Data::Pretty::Filtered' );
};

done_testing();

__END__

