use Test2::V0;
use Test2::Require::Perl 'v5.20';

use lib 'lib', 't/lib';
use Local::QuickStart::Session;

my $s = Local::QuickStart::Session->new(
  token   => 't1',
  user_id => 'u1',
  note    => 'start',
);

ok( $s->has_note, 'question-mark shortcut adds predicate' );
$s->note('changed');
is( $s->note, 'changed', 'rw accessor from == works' );

$s->_set_seen_at('now');
is( $s->seen_at, 'now', 'rwp private writer works' );

ok(
  dies {
    Local::QuickStart::Session->new(
      token     => 't2',
      user_id   => 'u2',
      cache_key => 'x',
    );
  },
  'dot shortcut blocks constructor argument',
);

done_testing;
