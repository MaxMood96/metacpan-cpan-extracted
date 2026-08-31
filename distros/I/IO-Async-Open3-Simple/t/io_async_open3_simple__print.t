use Test2::V0 -no_srand => 1;
use 5.042;
use IO::Async::Loop;
use IO::Async::Open3::Simple;
use File::Temp qw( tempdir );
use File::Spec;

plan skip_all => 'print not supported on MSWin32' if $^O eq 'MSWin32';

my $dir = tempdir( CLEANUP => 1 );
{
    open my $fh, '>', File::Spec->catfile( $dir, 'child.pl' ) or die $!;
    print $fh join "\n", "#!$^X",
      'use File::Spec;',
      "open(my \$out, '>', File::Spec->catfile('$dir', 'child.out'));",
      'while(<STDIN>) { print $out $_ }';
    close $fh;
}

my $loop = IO::Async::Loop->new;
my $done = $loop->new_future;

my $ipc = IO::Async::Open3::Simple->new(
    on_start => sub {
        my ($proc) = @_;
        $proc->say('message1');
        $proc->say('message2');
        $proc->close;
    },
    on_exit  => sub { $done->done },
    on_error => sub { $done->fail("on_error: $_[0]") },
);

my $ret = $ipc->run( $^X, File::Spec->catfile( $dir, 'child.pl' ) );
isa_ok $ret, ['IO::Async::Open3::Simple'], 'run returns the ipc object';

Future->wait_any( $done, $loop->timeout_future( after => 15 ) )->get;

open my $fh, '<', File::Spec->catfile( $dir, 'child.out' ) or die $!;
chomp( my @list = <$fh> );
close $fh;

is \@list, [ 'message1', 'message2' ], 'child received data written via $proc->say';

done_testing;
