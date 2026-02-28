use strict;
use warnings;

use Test::More import => [ qw( BAIL_OUT is is_deeply ok require_ok ) ], tests => 12;
my $class;

BEGIN {
  $class = 'Version::Semantic';
  require_ok $class or BAIL_OUT "Cannot load class '$class'!"
}

my $input        = 'v1.2.3 2026-02-25T14:54:45Z TRIAL release';
my $input_length = length $input;
ok $input =~ m/\G ${ \( $class->semver_re ) }/gcx, 'Match version';
is_deeply \%+, { prefix => 'v', major => 1, minor => 2, patch => 3 }, 'Named capture buffers';
is pos( $input ), 6, 'Offset';
my $spaces_re = qr/ +/;
ok $input =~ m/\G ${spaces_re}/gcx, 'Match spaces';
is pos( $input ), 7, 'Offset';
ok $input =~ m/\G [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z /gcx, 'Match UTC normalized W3CDTF';
is pos( $input ), 27, 'Offset';
ok $input =~ m/\G ${spaces_re}/gcx, 'Match spaces';
is pos( $input ), 28, 'Offset';
ok $input =~ m/\G TRIAL\ release /gcx, 'Match release note';
is pos( $input ), $input_length, 'Offset'
