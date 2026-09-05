use v5.36;
use strict;
use warnings;

use File::Temp qw(tempdir tempfile);
use Fcntl qw(F_SETFD);
use POSIX qw(SIGTERM);
use Scalar::Util qw(blessed);
use Test::More;

use Linux::Event::Loop;
use Linux::Event::Kernel::Process;

our ($OUTPUT, @ERRORS);
$OUTPUT = '';

{
    package T::MergedProcess;
    use parent 'Linux::Event::Kernel::Process';
    sub on_stdout ($self, $bytes) { $main::OUTPUT .= $bytes }
    sub on_exit ($self) { $self->loop->stop }
}

my $directory = tempdir(CLEANUP => 1);
my $loop = Linux::Event::Loop->new;
my $merged = $loop->add(T::MergedProcess->spawn(
    command => [
        $^X, '-MCwd=getcwd', '-e',
        'print "$ENV{ONLY}|" . (exists $ENV{PATH} ? "path" : "clean")'
            . ' . "|" . getcwd() . "\n"; warn "merged\n";',
    ],                  # required
    cwd    => $directory,         # optional
    env    => { ONLY => 'set' },  # optional: replacement environment
    stdout => 'pipe',             # optional
    stderr => 'stdout',           # optional
));
$loop->run;
is($merged->exit_code, 0, 'process with cwd and replacement env exits normally');
like($OUTPUT, qr/^set\|clean\|\Q$directory\E\n/m,
    'cwd and replacement environment reach the child');
like($OUTPUT, qr/merged/, 'stderr can be merged into asynchronous stdout');

{
    package T::FileProcess;
    use parent 'Linux::Event::Kernel::Process';
    sub on_exit ($self) { $self->loop->stop }
}

my ($file, $filename) = tempfile();
my $file_loop = Linux::Event::Loop->new;
my $file_process = $file_loop->add(T::FileProcess->spawn(
    command => [$^X, '-e', 'print "file-output\n"'], # required
    stdin   => 'null', # optional
    stdout  => $file,  # optional existing handle
    stderr  => 'null', # optional
));
$file_loop->run;
ok(defined fileno($file), 'Process does not close caller-owned stdio handle');
seek($file, 0, 0) or die "seek $filename: $!";
is(do { local $/; <$file> }, "file-output\n",
    'existing stdout filehandle receives child output');
close $file;

my ($descriptor_file, $descriptor_filename) = tempfile();
my $descriptor_fd = fileno($descriptor_file);
fcntl($descriptor_file, F_SETFD, 0)
    or die "clear close-on-exec for descriptor leak test: $!";
my $descriptor_loop = Linux::Event::Loop->new;
my $descriptor_process = $descriptor_loop->add(T::FileProcess->spawn(
    command => [
        $^X, '-e',
        'my ($fd, $path) = @ARGV; my $target = readlink("/proc/self/fd/$fd");'
            . ' exit(defined($target) && $target eq $path ? 41 : 0)',
        $descriptor_fd, $descriptor_filename,
    ],
    stdout => $descriptor_file,
    stderr => $descriptor_file,
));
$descriptor_loop->run;
is($descriptor_process->exit_code, 0,
    'caller stdio source descriptor is closed in the spawned child');
ok(defined(fileno($descriptor_file)),
    'caller stdio handle remains open in the parent');
close $descriptor_file;

{
    package T::BrokenPipeProcess;
    use parent 'Linux::Event::Kernel::Process';
    sub on_error ($self, $error) { push @main::ERRORS, $error }
    sub on_exit ($self) { $self->loop->stop }
}

@ERRORS = ();
my $pipe_loop = Linux::Event::Loop->new;
my $pipe_process = T::BrokenPipeProcess->spawn(
    command => [$^X, '-e', 'close STDIN; select undef, undef, undef, 0.2'],
    stdin   => 'pipe', # optional
);
$pipe_process->write_stdin('x' x (2 * 1024 * 1024));
$pipe_loop->add($pipe_process);
$pipe_loop->run;
ok((grep { $_->type eq 'process_io' && $_->operation eq 'write_stdin' }
        @ERRORS),
    'closed child stdin reports process_io without delivering SIGPIPE');
ok($pipe_process->exited, 'parent remains alive and observes child exit');

{
    package T::ThrowingExit;
    use parent 'Linux::Event::Kernel::Process';
    sub on_exit ($self) { die "exit callback failed\n" }
}

my $throw_loop = Linux::Event::Loop->new;
my $throwing = $throw_loop->add(T::ThrowingExit->spawn(
    command => [$^X, '-e', 'exit 0'], # required
));
my $callback_error = eval { $throw_loop->run; '' } // $@;
like("$callback_error", qr/exit callback failed/,
    'on_exit exceptions propagate from Loop dispatch');
is($throwing->loop, undef,
    'Process releases Loop even when on_exit throws');

our $THROWING_OUTPUT_EXIT = 0;
{
    package T::ThrowingOutput;
    use parent 'Linux::Event::Kernel::Process';
    sub on_stdout ($self, $bytes) { die "stdout callback failed\n" }
    sub on_exit ($self) { $main::THROWING_OUTPUT_EXIT++ }
}

my $output_loop = Linux::Event::Loop->new;
my $throwing_output = $output_loop->add(T::ThrowingOutput->spawn(
    command => [$^X, '-e', 'print "complete output\n"'], # required
    stdout  => 'pipe',                                  # optional
));
my $output_error = '';
for (1 .. 200) {
    my $ok = eval { $throwing_output->_pid_ready; 1 };
    $output_error = "$@" if !$ok;
    last if $throwing_output->is_terminal;
    select undef, undef, undef, 0.005;
}
like($output_error, qr/stdout callback failed/,
    'final output callback exceptions propagate');
ok($throwing_output->exited,
    'output callback failure does not prevent exit finalization');
is($THROWING_OUTPUT_EXIT, 1,
    'on_exit still runs after a final output callback exception');
is($throwing_output->loop, undef,
    'final output callback failure releases Process Loop ownership');

my $signal_loop = Linux::Event::Loop->new;
my $running = $signal_loop->add(T::FileProcess->spawn(
    command => [$^X, '-e', 'sleep 30'], # required
));
my $signal_error = eval { $running->signal(999_999); '' } // $@;
ok(blessed($signal_error) && $signal_error->isa('Linux::Event::Error'),
    'pidfd signal syscall failures throw structured Error values');
is($signal_error->type, 'process', 'signal failure has process type');
is($signal_error->operation, 'signal', 'signal failure names operation');
my $overflow_signal = eval {
    $running->signal('18446744073709551631');
    '';
} // $@;
ok(blessed($overflow_signal)
    && $overflow_signal->isa('Linux::Event::Error'),
    'oversized signal number cannot wrap into a different native signal');
is($overflow_signal->operation, 'signal',
    'oversized signal validation remains a structured signal failure');
$running->signal(SIGTERM);
$signal_loop->run;

done_testing;
