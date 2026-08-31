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

my ( $proc, $prog, @args );
my $on_start_called = 0;
my $done;

my $ipc = IO::Async::Open3::Simple->new(
    on_start => sub {
        ( $proc, $prog, @args ) = @_;
        $on_start_called++;
    },
    on_exit  => sub { $done->done },
    on_error => sub { $done->fail("on_error: $_[0]") },
);

my $child = File::Spec->catfile( $dir, 'child.pl' );

foreach my $iteration ( 1 .. 2 ) {
    subtest "iteration $iteration" => sub {
        $done            = $loop->new_future;
        $on_start_called = 0;

        my $foo = 0;
        my @cb_args;

        my $ret = $ipc->run( $^X, $child, 'arg1', 'arg2', sub { $foo = $iteration; @cb_args = @_ } );
        isa_ok $ret, ['IO::Async::Open3::Simple'], 'run returns the ipc object';

        Future->wait_any( $done, $loop->timeout_future( after => 15 ) )->get;

        is $on_start_called,         1,                                     'on_start fired once';
        is $prog,                    $^X,                                   'program passed to on_start';
        is \@args,                   [ $child, 'arg1', 'arg2' ],            'arguments passed to on_start';
        is [ map { ref } @cb_args ], ['IO::Async::Open3::Simple::Process'], 'run callback gets a single process object';
        is $foo,                     $iteration,                            "run callback ran (foo == $iteration)";
    };
}

done_testing;
