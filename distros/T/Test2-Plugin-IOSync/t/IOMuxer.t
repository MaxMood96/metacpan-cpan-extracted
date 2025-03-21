use Test2::Bundle::Extended -target => 'Test2::Plugin::IOMuxer';
use File::Temp qw/tempfile/;
use IPC::Open3 qw/open3/;
use List::Util qw/first/;

BEGIN { *JSON = Test2::Plugin::IOMuxer::Layer->can('JSON') }

ok($INC{'Test2/Plugin/OpenFixPerlIO.pm'}, "Loaded OpenFixPerlIO");

subtest mux_handle => sub {
    Test2::Plugin::IOMuxer->import(qw/mux_handle/);
    imported_ok('mux_handle');
    my ($fh, $name)  = tempfile("$$-XXXXXXXX", TMPDIR => 1);
    my ($mh, $muxed) = tempfile("$$-XXXXXXXX", TMPDIR => 1);
    close($mh) or die "$!";

    mux_handle($fh, $muxed);

    print $fh "This is a test\n";
    print $fh "This is a\nmulti-line test\n";
    print $fh "This is a no line-end test 1";
    print $fh "This is a no line-end test 2";
    print $fh "\n";
    print $fh "This is the final test\n";
    close($fh) or die "$!";

    open($fh, '<', $name) or die "$!";

    is(
        [<$fh>],
        [
            "This is a test\n",
            "This is a\n",
            "multi-line test\n",
            "This is a no line-end test 1This is a no line-end test 2\n",
            "This is the final test\n",
        ],
        "Got all lines as expected in main handle"
    );

    close($Test2::Plugin::IOMuxer::Layer::MUX_FILES{$muxed}) or die "$!";
    $Test2::Plugin::IOMuxer::Layer::MUX_FILES{$muxed} = undef;

    open($mh, '<', $muxed) or die "$!";

    like(
        [map { JSON->new->decode($_) } <$mh>],
        [
            {buffer => "This is a test\n"},
            {buffer => "This is a\n"},
            {buffer => "multi-line test\n"},
            {buffer => "This is a no line-end test 1This is a no line-end test 2\n"},
            {buffer => "This is the final test\n"},
        ],
        "Got all lines as expected"
    );

    unlink($name);
    unlink($muxed);
};

subtest mux_test_io => sub {
    my ($out_fh, $out_file) = tempfile("$$-XXXXXXXX", TMPDIR => 1);
    my ($err_fh, $err_file) = tempfile("$$-XXXXXXXX", TMPDIR => 1);
    my ($mux_fh, $mux_file) = tempfile("$$-XXXXXXXX", TMPDIR => 1);
    close($mux_fh);

    {
        local $ENV{T2_FORMATTER}       = 'TAP';
        local $ENV{T2_HARNESS_VERBOSE} = 0;
        local $ENV{T2_HARNESS_ACTIVE}  = 0;
        local $ENV{HARNESS_VERBOSE}    = 0;
        local $ENV{HARNESS_ACTIVE}     = 0;
        local $ENV{PERL5LIB}           = join ':' => @INC;

        my $file = first { -e $_ } './t/iotest.pl', './iotest.pl';
        my $pid = open3(undef, '>&' . fileno($out_fh), '>&' . fileno($err_fh), $^X, '-Ilib', "-M$CLASS=$mux_file", $file);

        waitpid($pid, 0);
        is($?, 0, "subprocess exited fine");
    }

    close($out_fh);
    close($err_fh);

    open($out_fh, '<', $out_file) or die "$!";
    open($err_fh, '<', $err_file) or die "$!";
    open($mux_fh, '<', $mux_file) or die "$!";

    like(
        [<$out_fh>],
        array {
            item "STDOUT BEFORE TESTING\n";
            item qr/^# Seeded/;
            item "ok 1 - pass 1\n";
            item "STDOUT IN TESTING\n";
            item "ok 2 - pass 2\n";
            item "1..2\n";
            item "STDOUT AFTER TESTING\n";
            end;
        },
        "Got standard output"
    );

    is(
        [<$err_fh>],
        array {
            item "STDERR BEFORE TESTING\n";
            item "# a diag message 1\n";
            item "STDERR IN TESTING\n";
            item "# a diag message 2\n";
            item "STDERR AFTER TESTING\n";
            end;
        },
        "Got standard error"
    );

    like(
        [map { JSON->new->decode($_) } <$mux_fh>],
        [
            {buffer => "STDOUT BEFORE TESTING\n"},
            {buffer => "STDERR BEFORE TESTING\n"},
            {buffer => qr/# Seeded srand with seed/},
            {buffer => "ok 1 - pass 1\n"},
            {buffer => "STDOUT IN TESTING\n"},
            {buffer => "ok 2 - pass 2\n"},
            {buffer => "# a diag message 1\n"},
            {buffer => "STDERR IN TESTING\n"},
            {buffer => "# a diag message 2\n"},
            {buffer => "1..2\n"},
            {buffer => "STDOUT AFTER TESTING\n"},
            {buffer => "STDERR AFTER TESTING\n"}
        ],
        "Got muxed output"
    );

    unlink($out_file);
    unlink($err_file);
    unlink($mux_file);
};

done_testing;
