use Test2::V0 -no_srand => 1;
use 5.042;
use IO::Async::Loop;
use IO::Async::Open3::Simple;
use File::Temp qw( tempdir );
use File::Spec;

plan skip_all => 'on_signal not supported on MSWin32' if $^O eq 'MSWin32';

my $dir = tempdir( CLEANUP => 1 );
{
    open my $fh, '>', File::Spec->catfile( $dir, 'child_sig9.pl' ) or die $!;
    print $fh "#!$^X\nkill 9, \$\$\n";
    close $fh;
    open $fh, '>', File::Spec->catfile( $dir, 'child_normal.pl' ) or die $!;
    print $fh "#!$^X\n";
    close $fh;
}

my $loop = IO::Async::Loop->new;

my ( $proc, $signal1, $signal2, $exit_value, $done );

my $ipc = IO::Async::Open3::Simple->new(
    on_signal => sub { ( $proc, $signal1 ) = @_ },
    on_exit   => sub { ( $proc, $exit_value, $signal2 ) = @_; $done->done },
    on_error  => sub { $done->fail("on_error: $_[0]") },
);

subtest 'normal exit does not fire on_signal' => sub {
    $done = $loop->new_future;
    undef $signal1;
    $ipc->run( $^X, File::Spec->catfile( $dir, 'child_normal.pl' ) );
    Future->wait_any( $done, $loop->timeout_future( after => 15 ) )->get;
    is $signal1, undef, 'on_signal not called';
    is $signal2, 0,     'on_exit signal 0';
};

subtest 'killed by signal fires on_signal' => sub {
    $done = $loop->new_future;
    undef $signal1;
    $ipc->run( $^X, File::Spec->catfile( $dir, 'child_sig9.pl' ) );
    Future->wait_any( $done, $loop->timeout_future( after => 15 ) )->get;
    is $signal1, 9, 'on_signal signal 9';
    is $signal2, 9, 'on_exit signal 9';
};

done_testing;
