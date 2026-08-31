use Test2::V0 -no_srand => 1;
use 5.042;
use IO::Async::Loop;
use IO::Async::Open3::Simple;
use File::Temp qw( tempdir );
use File::Spec;

my $dir = tempdir( CLEANUP => 1 );
{
    open my $fh, '>', File::Spec->catfile( $dir, 'child.pl' ) or die $!;
    print $fh join "\n", "#!$^X", '$| = 1;', 'print "message1\n";', 'print "message2\n";', 'print STDERR "message3\n";';
    close $fh;
}

my $loop = IO::Async::Loop->new;
my $done = $loop->new_future;

my ( @out, @err );

my $ipc = IO::Async::Open3::Simple->new(
    on_stdout => \@out,
    on_stderr => \@err,
    on_exit   => sub { $done->done },
    on_error  => sub { $done->fail("on_error: $_[0]") },
);

my $ret = $ipc->run( $^X, File::Spec->catfile( $dir, 'child.pl' ) );
isa_ok $ret, ['IO::Async::Open3::Simple'], 'run returns the ipc object';

Future->wait_any( $done, $loop->timeout_future( after => 15 ) )->get;

is \@out, [ 'message1', 'message2' ], 'stdout lines pushed onto array ref';
is \@err, ['message3'],               'stderr lines pushed onto array ref';

done_testing;
