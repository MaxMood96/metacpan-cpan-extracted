use Test2::V0 -no_srand => 1;
use 5.042;
use IO::Async::Open3::Simple::Process;

my $proc = do {
    no warnings 'once';
    IO::Async::Open3::Simple::Process->new( 42, \*foo );
};
isa_ok $proc, ['IO::Async::Open3::Simple::Process'], 'isa Process';
is $proc->pid, 42, 'pid';

is $proc->user, '', 'user defaults to empty string';
$proc->user( { answer => 42 } );
is $proc->user, { answer => 42 }, 'user round trips';

done_testing;
