use v5.36;
use strict;
use warnings;

use Test::More;

use Linux::Event::Loop;
use Linux::Event::Process;

sub exception ($code) {
    local $@;
    return eval { $code->(); 1 } ? '' : "$@";
}

like(exception(sub { Linux::Event::Process->new(pid => $$) }),
    qr/abstract base class/, 'base Process class is abstract');

{
    package T::Process::Missing;
    use parent 'Linux::Event::Process';
}
like(exception(sub { T::Process::Missing->new(pid => $$) }),
    qr/must define on_exit/, 'on_exit is required');

{
    package T::Process::Basic;
    use parent 'Linux::Event::Process';
    sub on_exit ($self) { }
}

like(exception(sub { T::Process::Basic->new }), qr/pid is required/,
    'observed Process requires pid');
like(exception(sub { T::Process::Basic->new(pid => '99999999999999999999') }),
    qr/pid must be at most 2147483647/,
    'observed Process rejects a PID that cannot fit pid_t');
like(exception(sub { T::Process::Basic->spawn(command => 'echo hi') }),
    qr/nonempty array reference/, 'spawn never implies a shell');
like(exception(sub { T::Process::Basic->spawn(command => []) }),
    qr/nonempty array reference/, 'spawn rejects an empty command');
like(exception(sub { T::Process::Basic->spawn(command => ['']) }),
    qr/executable must be a non-empty string/,
    'spawn rejects an empty executable name');
like(exception(sub { T::Process::Basic->spawn(command => ["\x{100}"]) }),
    qr/command arguments must be byte strings/,
    'spawn rejects an unencoded wide-character command argument');
like(exception(sub { T::Process::Basic->spawn(
    command => [$^X, '-e', 'exit 0'], stdout => 'mystery',
) }), qr/stdout must be inherit, pipe, null, or a filehandle/,
    'unknown stdio mode is rejected');

{
    package T::Process::StdoutCallback;
    use parent 'Linux::Event::Process';
    sub on_stdout ($self, $bytes) { }
    sub on_exit ($self) { }
}
like(exception(sub { T::Process::StdoutCallback->spawn(
    command => [$^X, '-e', 'exit 0'],
) }), qr/on_stdout requires stdout => pipe/,
    'impossible output callback is rejected');

my $detached = T::Process::Basic->spawn(
    command => [$^X, '-e', 'exit 0'], # required
);
is($detached->state, 'unattached', 'spawn specification starts unattached');
is($detached->pid, undef, 'PID does not exist before Loop attachment');
ok(!$detached->is_running, 'detached Process is not running');

my $loop = Linux::Event::Loop->new;
my $spawn_error = eval { $loop->add(T::Process::Basic->spawn(
    command => ['/definitely/not/a/program'],
)); undef } // $@;
ok(ref($spawn_error) && $spawn_error->isa('Linux::Event::Error'),
    'spawn setup failure is a structured Error');
is($spawn_error->type, 'process', 'spawn setup error has process type');
is($spawn_error->operation, 'posix_spawn',
    'spawn setup error identifies posix_spawn');

done_testing;
