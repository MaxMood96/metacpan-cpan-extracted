use Test2::V0;
use Test2::Require::Perl 'v5.20';

use lib 'lib', 't/lib';
use Local::QuickStart::Job;

my $j = Local::QuickStart::Job->new(
  id   => 10,
  name => 'sync',
);

is( $j->run, 'ok', 'run method works' );
is( $j->status, 'pending', 'default status works' );
ok( $j->has_status, 'question-mark creates predicate' );

$j->add_warning('late');
is( $j->warnings, ['late'], 'delegated array method works' );

$j->_set_retries(2);
is( $j->retries, 2, 'private writer from equals works' );

my $h = $j->as_hashref;
is( $h->{status}, 'PENDING', 'around modifier changed status' );
is( $j->logs, ['starting run'], 'before modifier logged event' );

done_testing;
