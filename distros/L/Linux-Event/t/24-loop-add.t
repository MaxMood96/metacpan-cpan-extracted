use v5.36;
use strict;
use warnings;
use Test::More;

use Linux::Event::Loop;
my $loop = Linux::Event::Loop->new;
isa_ok($loop, 'Linux::Event::Loop');

pipe(my $reader, my $writer) or die "pipe: $!";
my $io = $loop->watch(fh => $reader, read => sub ($watcher) { });
ok(ref($io), 'watch returns an opaque registration handle');
can_ok($io, qw(fd fh data loop cancel enable_read disable_read
    enable_write disable_write));
is($io->loop, $loop, 'raw registration retains its Loop');
$io->cancel;
close $reader;
close $writer;

like(exception(sub { $loop->add(bless {}, 'T::NotAttachable') }),
    qr/support loop attachment/, 'add rejects unrelated objects');

done_testing;

sub exception ($code) {
    my $error = '';
    eval { $code->(); 1 } or $error = $@;
    return $error;
}
