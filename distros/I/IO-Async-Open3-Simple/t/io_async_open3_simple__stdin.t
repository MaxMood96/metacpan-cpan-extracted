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
    print $fh 'use File::Spec;',                                                "\n";
    print $fh "open(my \$out, '>', File::Spec->catfile('$dir', 'child.out'));", "\n";
    print $fh 'while(<STDIN>) { print $out $_ }',                               "\n";
    close $fh;
}

my $loop    = IO::Async::Loop->new;
my $child   = File::Spec->catfile( $dir, 'child.pl' );
my $outfile = File::Spec->catfile( $dir, 'child.out' );

foreach my $stdin ( [qw( message1 message2 )], join( "\n", qw( message1 message2 ) ) ) {
    subtest 'stdin as ' . ( ref $stdin ? 'array ref' : 'scalar ref' ) => sub {
        unlink $outfile;
        my $done = $loop->new_future;

        my $ipc = IO::Async::Open3::Simple->new(
            on_exit  => sub { $done->done },
            on_error => sub { $done->fail("on_error: $_[0]") },
        );

        my $ret = $ipc->run( $^X, $child, ref $stdin ? $stdin : \$stdin );
        isa_ok $ret, ['IO::Async::Open3::Simple'], 'run returns the ipc object';

        Future->wait_any( $done, $loop->timeout_future( after => 15 ) )->get;

        open my $fh, '<', $outfile or die $!;
        chomp( my @list = <$fh> );
        close $fh;

        is \@list, [ 'message1', 'message2' ], 'child received stdin';
    };
}

done_testing;
