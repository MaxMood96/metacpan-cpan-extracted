use v5.36;
use Test::More;
use Linux::Event::Loop;
use IO::Handle;

pipe(my $r1, my $w1) or die $!;
pipe(my $r2, my $w2) or die $!;
$_->blocking(0) for ($r1, $w1, $r2, $w2);

my $loop = Linux::Event::Loop->new;
my @seen;
my @watchers;

for my $pair ([$r1, $w1, 'one'], [$r2, $w2, 'two']) {
    my ($r, $w, $name) = @$pair;
    my $watcher;
    $watcher = $loop->watch_fd(
        fileno($r),
        fh => $r,
        read => sub ($self) {
            my $tmp = join(':', $name, map { $_ * 2 } 1 .. 4);
            push @seen, $tmp;
            sysread($self->fh, my $buf, 16);
            $self->cancel;
        },
        error => sub ($self) { $self->cancel },
    );
    push @watchers, $watcher;
    syswrite($w, 'x');
}

$loop->run_once(1000);

is_deeply([sort @seen], ['one:2:4:6:8', 'two:2:4:6:8'], 'multiple callbacks preserve Perl temporary semantics');
my $stats = $loop->stats;
ok($stats->{callback_calls} >= 2, 'multiple callbacks executed');
ok($stats->{callback_batch_scope_enters} >= 1, 'callbacks ran inside a batch scope');

close $_ for ($w1, $w2);
done_testing;
