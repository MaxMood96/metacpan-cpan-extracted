use Test2::V0 -no_srand => 1;
use 5.042;
use IO::Async::Loop;
use IO::Async::Open3::Simple;
use File::Temp qw( tempdir );
use File::Spec;

my $dir = tempdir( CLEANUP => 1 );
{
    open my $fh, '>', File::Spec->catfile( $dir, 'child.pl' ) or die $!;
    print $fh "#!$^X\n";
    close $fh;
}

my $loop = IO::Async::Loop->new;
my $done = $loop->new_future;

my ( $start_proc, $exit_proc, $child_pid, $old_user, $new_user );

my $ipc = IO::Async::Open3::Simple->new(
    on_start => sub { ($start_proc) = @_ },
    on_exit  => sub {
        ($exit_proc) = @_;
        $child_pid = $exit_proc->pid;
        $old_user  = $exit_proc->user;
        $exit_proc->user('some user data');
        $done->done;
    },
    on_error => sub { $done->fail("on_error: $_[0]") },
);

my $ret = $ipc->run( $^X, File::Spec->catfile( $dir, 'child.pl' ) );
isa_ok $ret, ['IO::Async::Open3::Simple'], 'run returns the ipc object';

Future->wait_any( $done, $loop->timeout_future( after => 15 ) )->get;

like $child_pid, qr/^[0-9]+$/, "proc->pid is numeric ($child_pid)";
is $start_proc->pid, $child_pid, 'on_start and on_exit see the same process';
ref_is $start_proc, $exit_proc, 'on_start and on_exit get the same object';
is $old_user,                    '',               'user starts empty';
is $new_user = $exit_proc->user, 'some user data', 'user was updated';

done_testing;
