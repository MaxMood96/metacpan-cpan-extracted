use Test2::V0 -no_srand => 1;
use 5.042;
use IO::Async::Loop;
use IO::Async::Open3::Simple;
use File::Temp qw( tempdir );
use File::Spec;

plan skip_all => 'open3 does not die on missing program on MSWin32' if $^O eq 'MSWin32';

my $dir = tempdir( CLEANUP => 1 );

my $loop = IO::Async::Loop->new;
my $done = $loop->new_future;

my $called_on_error = 0;
my ( $message, $cmd, @args );

my $ipc = IO::Async::Open3::Simple->new(
    on_error => sub {
        ( $message, $cmd, @args ) = @_;
        $called_on_error = 1;
        $done->done;
    },
    on_exit => sub { $done->done },
);

my $bogus = File::Spec->catfile( $dir, 'bogus.pl' );
$ipc->run( $bogus, 'arg1', 'arg2' );

Future->wait_any( $done, $loop->timeout_future( after => 15 ) )->get;

is $called_on_error, 1, 'on_error was called';
chomp $message;
like $message, qr/^open3: /, "message begins with open3: ($message)";
is $cmd,   $bogus,             'program passed to on_error';
is \@args, [ 'arg1', 'arg2' ], 'arguments passed to on_error';

done_testing;
