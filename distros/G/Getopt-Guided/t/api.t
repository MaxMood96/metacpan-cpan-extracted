use strict;
use warnings;

use Test::More import => [ qw( BAIL_OUT like require_ok ) ], tests => 3;
use Test::Fatal qw( exception );

my $module;

BEGIN {
  $module = 'Getopt::Guided';
  require_ok $module or BAIL_OUT "Cannot load module '$module'!";
  no strict 'refs'; ## no critic ( ProhibitNoStrict )
  $module->import( @{ "$module\::EXPORT_OK" } );
}

like exception { $module->can( 'croakf' )->( 'message only' ) }, qr/message only/, 'croakf() without "f"';

like exception { $module->import( 'private' ) }, qr/not exported/, 'Export error'
