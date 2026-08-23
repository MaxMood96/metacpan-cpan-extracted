use v5.36;
use Test::More;
use Linux::Event::Loop;
use IO::Handle;

# Terminal events keep error-before-read semantics: HUP/RDHUP dispatches
# the error callback first, even when EPOLLIN is also present.
pipe(my $r, my $w) or die $!;
$r->blocking(0);
$w->blocking(0);

my $loop = Linux::Event::Loop->new;
my ($read_calls, $error_calls) = (0, 0);
my $watcher;

$watcher = $loop->watch_fd(
    fileno($r),
    fh => $r,
    read => sub ($self) {
        $read_calls++;
        $self->cancel;
    },
    error => sub ($self) {
        $error_calls++;
        $self->cancel;
    },
);

close $w;
$loop->run_once(1000);

is($read_calls, 0, 'HUP does not enter the read callback');
is($error_calls, 1, 'HUP dispatches one error callback');

my $stats = $loop->stats;
is($stats->{error_callback_calls}, 1, 'XS stats count HUP error callback');
is($stats->{read_callback_calls}, 0, 'XS stats do not count HUP read callback');
ok($stats->{callback_batch_scope_enters} >= 1, 'batch callback scope was entered');
ok(exists $stats->{ready_hup_events}, 'HUP-shape counter is available');
ok(exists $stats->{ready_rdhup_events}, 'RDHUP-shape counter is available');

done_testing;
