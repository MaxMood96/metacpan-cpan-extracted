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

my ( $proc, $signal, $success, $exit_value, $done );

my $ipc = IO::Async::Open3::Simple->new(
    on_success => sub { $success = 1 },
    on_exit    => sub { ( $proc, $exit_value, $signal ) = @_; $done->done },
    on_error   => sub { $done->fail("on_error: $_[0]") },
);

subtest 'zero exit fires on_success' => sub {
    $done = $loop->new_future;
    undef $success;
    $ipc->run( $^X, File::Spec->catfile( $dir, 'child_normal.pl' ) );
    Future->wait_any( $done, $loop->timeout_future( after => 15 ) )->get;
    is $success,    1, 'on_success called';
    is $exit_value, 0, 'exit value 0';
};

subtest 'non-zero exit does not fire on_success' => sub {
    $done = $loop->new_future;
    undef $success;
    $ipc->run( $^X, File::Spec->catfile( $dir, 'child_exit3.pl' ) );
    Future->wait_any( $done, $loop->timeout_future( after => 15 ) )->get;
    is $success,    undef, 'on_success not called';
    is $exit_value, 3,     'exit value 3';
};

done_testing;
