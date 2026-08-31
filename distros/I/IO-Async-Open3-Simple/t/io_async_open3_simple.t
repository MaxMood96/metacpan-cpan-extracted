use Test2::V0 -no_srand => 1;
use 5.042;
use IO::Async::Open3::Simple;

subtest 'create with list' => sub {
    my $ipc = IO::Async::Open3::Simple->new( on_stdout => sub { }, );
    isa_ok $ipc, ['IO::Async::Open3::Simple'], 'isa IO::Async::Open3::Simple';
};

subtest 'create with hashref' => sub {
    my $ipc = IO::Async::Open3::Simple->new(
        {
            on_stdout => sub { },
        }
    );
    isa_ok $ipc, ['IO::Async::Open3::Simple'], 'isa IO::Async::Open3::Simple';
};

subtest 'stdin/raw no longer supported' => sub {
    my $in = '';
    like(
        dies { IO::Async::Open3::Simple->new( stdin => \$in ) },
        qr/stdin passed into IO::Async::Open3::Simple->new no longer supported/,
        'stdin dies',
    );
    like(
        dies { IO::Async::Open3::Simple->new( raw => 1 ) },
        qr/raw passed into IO::Async::Open3::Simple->new no longer supported/,
        'raw dies',
    );
};

done_testing;
