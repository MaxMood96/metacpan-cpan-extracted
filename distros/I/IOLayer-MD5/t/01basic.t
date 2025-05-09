BEGIN {				# Magic Perl CORE pragma
    if ($ENV{PERL_CORE}) {
        chdir 't' if -d 't';
        @INC = '../lib';
    }
    unless (find PerlIO::Layer 'perlio') {
        print "1..0 # Skip: PerlIO not used\n";
        exit 0;
    }
    if (ord("A") == 193) {
        print "1..0 # Skip: EBCDIC\n";
    }
}

use strict;
use warnings;
use Test::More tests => 10;

my $file = $ENV{PERL_CORE} ? 'test.md5' : 't/test.md5';

BEGIN { use_ok('IOLayer::MD5') }

is( IOLayer::MD5->method,'hexdigest',	'check default method' );

ok( open( my $in,'<:via(IOLayer::MD5)', $file ), "opening '$file' (hex)" );
is(
 scalar(<$in>),'d3410314beaba3aad299c3448f6e7ad1',
 'check digest in scalar context'
);
ok( close( $in ),			'close handle (hex)' );

is( IOLayer::MD5->method('b64digest'),'b64digest','check setting method' );
ok( open( $in,'<:via(IOLayer::MD5)', $file ),"opening '$file' (base64)");
is( IOLayer::MD5->method('digest'),'digest','check setting method' );

is( <$in>,'00EDFL6ro6rSmcNEj2560Q',	'check digest in list context' );
ok( close( $in ),			'close handle (base64)' );

