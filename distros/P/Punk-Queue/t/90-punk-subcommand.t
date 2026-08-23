#!perl
use 5.010;
use strict;
use warnings;
use File::Temp ();
use Test::More;

# `punk queue ...`: loading Punk::Command::Queue registers the subcommand
# with Punk's CLI registry, and arguments forward verbatim - one CLI, two
# spellings. Also pins the --app CLASS fix: a Punk application class either
# yields its plugin's queue or explains itself; the silent exit is gone.

BEGIN {
    eval { require DBD::SQLite; 1 }
        or plan skip_all => 'DBD::SQLite is required';
    eval { require Punk::Command; 1 } && Punk::Command->can('register')
        or plan skip_all => 'Punk 0.13+ (the command registry) is required';
}

require Punk::Command::Queue;

sub run_punk {
    my (@argv) = @_;
    my ($out, $err) = ('', '');
    open my $ofh, '>', \$out or die $!;
    open my $efh, '>', \$err or die $!;
    local $Punk::Command::OUT = $ofh;
    local $Punk::Command::ERR = $efh;
    my $code = Punk::Command->main(@argv);
    close $ofh; close $efh;
    return ($code, $out, $err);
}

my $dir = File::Temp::tempdir(CLEANUP => 1);
my $dsn = "dbi:SQLite:dbname=$dir/q.db";

# ---- registered and forwarding -------------------------------------------------

{
    my ($rc) = run_punk('queue', 'migrate', '--dsn', $dsn);
    is($rc, 0, 'punk queue migrate runs the punk-queue command');
}
{
    my ($rc, $out) = run_punk('queue', 'stats', '--dsn', $dsn);
    is($rc, 0, 'punk queue stats exits 0');
    like($out, qr/^inactive_jobs\s+0$/m, 'with punk-queue\'s own output');

    require Punk::Queue::Command;
    my ($qout, $qerr) = ('', '');
    open my $qo, '>', \$qout or die $!;
    {
        local *STDOUT = $qo;
        Punk::Queue::Command::main('stats', '--dsn', $dsn);
    }
    close $qo;
    is($out, $qout, 'byte-identical with punk-queue stats');
}
{
    my ($rc, $out) = run_punk('queue', 'help');
    is($rc, 0, 'punk queue help exits 0');
    like($out, qr/^Usage: punk-queue COMMAND/m,
        'and is punk-queue\'s own help - one option surface');
}
{
    my ($rc, undef, $err) = run_punk('queue', 'wat');
    is($rc, 2, 'an unknown queue verb is punk-queue\'s usage error');
}

# ---- the --app CLASS fix -------------------------------------------------------

{
    # a Punk application class whose Queue plugin never registered: the old
    # code silently exited 2; now it compiles the app and explains itself
    {
        package T90::App;
        use Punk;
        get '/' => sub { 1 };
    }
    my ($rc, undef, $err) = run_punk('queue', 'stats', '--app', 'T90::App');
    is($rc, 2, 'still exit 2');
    like($err, qr/compiled but the Queue plugin never registered a queue/,
        'but now it says what happened');
    like($err, qr/plugin 'Queue'/, 'and names the fix');
}
{
    # a class that is not a Punk app and has no queue() still explains
    my ($rc, undef, $err) = run_punk('queue', 'stats',
                                     '--app', 'File::Temp');
    is($rc, 2, 'exit 2');
    like($err, qr/has no queue\(\) method/, 'with the old clear message');
}
{
    # the file form still works: a psgi-like file returning the queue
    my $file = "$dir/queue.pl";
    open my $fh, '>', $file or die $!;
    print $fh "use Punk::Queue;\nPunk::Queue->new(dsn => '$dsn');\n";
    close $fh;
    my ($rc, $out) = run_punk('queue', 'stats', '--app', $file);
    is($rc, 0, 'the file form still reaches the queue');
    like($out, qr/^inactive_jobs\s+0$/m, 'and reports');
}

# ---- the doctor row ------------------------------------------------------------

{
    ok((grep { $_->[0] eq 'Punk::Queue' } @Punk::Command::DOCTOR),
        'a Punk::Queue doctor row is registered');
}

done_testing;
