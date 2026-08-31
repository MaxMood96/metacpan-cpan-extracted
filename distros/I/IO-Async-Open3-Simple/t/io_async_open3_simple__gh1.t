use Test2::V0 -no_srand => 1;
use 5.042;
use IO::Async::Loop;
use IO::Async::Open3::Simple;

my $loop = IO::Async::Loop->new;

foreach my $style (
    [ 'hashref' => sub { IO::Async::Open3::Simple->new( {@_} ) } ],
    [ 'list'    => sub { IO::Async::Open3::Simple->new(@_) } ],
  )
{
    my ( $name, $ctor ) = @$style;
    subtest $name => sub {
        my $done            = $loop->new_future;
        my $called_on_start = 0;
        my $ipc             = $ctor->(
            on_start => sub { $called_on_start = 1 },
            on_exit  => sub { $done->done },
            on_error => sub { $done->fail("on_error: $_[0]") },
        );
        $ipc->run( $^X, '-e', '42' );
        Future->wait_any( $done, $loop->timeout_future( after => 15 ) )->get;
        is $called_on_start, 1, 'on_start was called';
    };
}

done_testing;
