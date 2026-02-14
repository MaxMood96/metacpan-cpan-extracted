use Test2::V0;
use Test2::Require::Perl 'v5.20';

use lib 'lib', 't/lib';
use Local::QuickStart::User;

my $u = Local::QuickStart::User->new( username => 'alice' );
is( $u->username, 'alice', 'username reader works' );
ok( !$u->has_email, 'predicate for optional email works' );
ok( $u->active, 'default value is true' );

ok(
  dies { Local::QuickStart::User->new() },
  'required username enforced',
);

done_testing;
