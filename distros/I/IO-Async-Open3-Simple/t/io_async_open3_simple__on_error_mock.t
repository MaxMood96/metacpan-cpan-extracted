use Test2::V0 -no_srand => 1;
use 5.042;

package IPC::Open3;

BEGIN { $INC{'IPC/Open3.pm'} = __FILE__ }
use parent -norequire, 'Exporter';
BEGIN { our @EXPORT_OK = 'open3' }

sub open3 { die "open3: this is an error" }

package main;

use IO::Async::Loop;
use IO::Async::Open3::Simple;

my $loop = IO::Async::Loop->new;
my $done = $loop->new_future;

my $called_on_error = 0;
my $message         = '';

my $ipc = IO::Async::Open3::Simple->new(
    on_error => sub {
        $message         = shift;
        $called_on_error = 1;
        $done->done;
    },
    on_exit => sub { $done->done },
);

$ipc->run( 'foo', 'bar' );

Future->wait_any( $done, $loop->timeout_future( after => 15 ) )->get;

is $called_on_error, 1, 'on_error was called';
chomp $message;
like $message, qr/^open3: /, "message begins with open3: ($message)";

done_testing;
