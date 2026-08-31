use Test2::V0 -no_srand => 1;
use 5.042;
use IO::Async::Loop;
use IO::Async::Open3::Simple;
use File::Temp qw( tempdir );
use File::Spec;

my $dir = tempdir( CLEANUP => 1 );
{
    open my $fh, '>', File::Spec->catfile( $dir, 'child_exit3.pl' ) or die $!;
    print $fh "#!$^X\nexit 3\n";
    close $fh;
    open $fh, '>', File::Spec->catfile( $dir, 'child_normal.pl' ) or die $!;
    print $fh "#!$^X\n";
    close $fh;
}

my $loop = IO::Async::Loop->new;

my ( $proc, $signal, $exit_value1, $exit_value2, $done );

my $ipc = IO::Async::Open3::Simple->new(
    on_fail  => sub { ( $proc, $exit_value1 ) = @_ },
    on_exit  => sub { ( $proc, $exit_value2, $signal ) = @_; $done->done },
    on_error => sub { $done->fail("on_error: $_[0]") },
);

subtest 'normal exit does not fire on_fail' => sub {
    $done = $loop->new_future;
    undef $exit_value1;
    my $ret = $ipc->run( $^X, File::Spec->catfile( $dir, 'child_normal.pl' ) );
    isa_ok $ret, ['IO::Async::Open3::Simple'], 'run returns the ipc object';
    Future->wait_any( $done, $loop->timeout_future( after => 15 ) )->get;
    is $exit_value1, undef, 'on_fail not called';
    is $exit_value2, 0,     'on_exit exit value 0';
};

subtest 'non-zero exit fires on_fail' => sub {
    $done = $loop->new_future;
    undef $exit_value1;
    my $ret = $ipc->run( $^X, File::Spec->catfile( $dir, 'child_exit3.pl' ) );
    isa_ok $ret, ['IO::Async::Open3::Simple'], 'run returns the ipc object';
    Future->wait_any( $done, $loop->timeout_future( after => 15 ) )->get;
    is $exit_value1, 3, 'on_fail exit value 3';
    is $exit_value2, 3, 'on_exit exit value 3';
};

done_testing;
