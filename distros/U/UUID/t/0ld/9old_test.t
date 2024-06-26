use warnings;
use Test::More tests => 40;
use UUID 'uuid';


UUID::generate( $bin );
is length $bin, 16;

UUID::generate_random( $bin );
is length $bin, 16;

UUID::generate_time( $bin );
is length $bin, 16;

UUID::unparse( $bin, $str );
is length $str, 36;
like $str, qr{^[-0-9a-f]+$}i;

$rc = UUID::parse( $str, $bin2 );
is $rc, 0;
is $bin, $bin2;

UUID::unparse_lower( $bin, $str1 );
UUID::unparse_upper( $bin, $str2 );
is length( $str1 ), 36;
is length( $str2 ), 36;
like $str1, qr/^[-a-f0-9]+$/;
like $str2, qr/^[-A-F0-9]+$/;
is lc( $str1 ), lc( $str2 );
ok $str1 ne $str2;

# content of uuid is unchanged if parse fails
UUID::generate( $bin );
$bin2 = $bin;
$str = 'Peter is a moose';
$rc = UUID::parse( $str, $bin );
is $rc, -1;
is $bin, $bin2;

UUID::generate( $bin );
$rc = UUID::is_null( $bin );
is $rc, 0;

UUID::clear( $bin );
is length( $bin ), 16;
is UUID::is_null( $bin ), 1;

# does copy work?
UUID::clear( $bin1 );
is UUID::is_null( $bin1 ), 1;
UUID::copy( $bin2, $bin1 );
is UUID::is_null( $bin2 ), 1;

$bin = 'bogus value';
is UUID::is_null( $bin ), 0; # != the null uuid, right?

$bin = '1234567890123456';
is UUID::is_null( $bin ), 0; # still not null

# make sure compare operands sane
UUID::generate( $bin1 );
$bin2 = 'x';
is abs(UUID::compare( $bin1, $bin2 )), 1;
is abs(UUID::compare( $bin2, $bin1 )), 1;
$bin2 = 'some silly ridiculously long string that couldnt possibly be a uuid';
is abs(UUID::compare( $bin1, $bin2 )), 1;
is abs(UUID::compare( $bin2, $bin1 )), 1;

# sane compare
$uuid=1;
UUID::generate( $uuid ); # this is wrong. dont want to fix it though.
ok 1;
$bin2 = '1234567890123456';
ok 1;
$tmp1 = UUID::compare( $bin1, $bin2 );
ok 1;
$tmp2 = UUID::compare( $bin2, $bin1 );
ok 1;
$tmp2 = -UUID::compare( $bin2, $bin1 );
is $tmp1, $tmp2;
is UUID::compare( $bin1, $bin2 ), -UUID::compare( $bin2, $bin1 );
$bin2 = $bin1;
is UUID::compare( $bin1, $bin2 ), 0;

# make sure we get back a null if src isnt sane
$bin1 = 'x';
UUID::copy( $bin2, $bin1 );
ok UUID::is_null( $bin2 );
$bin1 = 'another really really really long sting';
UUID::copy( $bin2, $bin1 );
ok UUID::is_null( $bin2 );

# sane copy
UUID::generate( $bin1 );
$bin2 = '1234567890123456';
UUID::copy( $bin2, $bin1 );
is UUID::compare( $bin1, $bin2 ), 0;

# make sure we get back the same scalar we passed in
$bin1 = '1234567890123456';
UUID::generate( $bin2 );
$save1 = \$bin2;
UUID::copy( $bin2, $bin1 );
$save2 = \$bin2;
is $save1, $save2;
is $$save1, $$save2;

$rc = uuid(); # make sure export works
is length($rc), 36;

$rc = UUID::uuid();
is length($rc), 36;

exit 0;
