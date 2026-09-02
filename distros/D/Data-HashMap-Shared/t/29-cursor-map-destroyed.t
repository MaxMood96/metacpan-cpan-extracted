use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use POSIX ();

# Regression (0.18): a cursor keeps raw handle pointers and only a refcount on
# the map's referent SV.  An explicit $map->DESTROY frees the handle anyway, so
# the cursor was left pointing at freed memory: calling a cursor method
# segfaulted, and merely dropping the cursor was a silent heap use-after-free
# (shm_cursor_destroy decrements handle->iterating; DESTROY then read
# handle->deferred).  Both now detect the zeroed owner IV.
#
# The risky sequences run in a forked child so a regression reports as a failed
# test rather than taking the whole harness down with SIGSEGV.

my @variants = qw(II IS SI SS I16 I16S I32 I32S SI16 SI32);
my $dir = tempdir(CLEANUP => 1);

sub in_child {
    my ($body) = @_;
    my $pid = fork // die "fork: $!";
    unless ($pid) { $body->(); POSIX::_exit(0) }
    waitpid $pid, 0;
    return $?;
}

sub make_key { my ($v, $i) = @_; $v =~ /^I/ ? $i : "cursor-key-longer-than-inline-$i" }
sub make_val { my ($v, $i) = @_; $v =~ /S$/ ? "value-longer-than-inline-$i" : $i }

for my $v (@variants) {
    my $class = "Data::HashMap::Shared::$v";
    unless (eval "require $class; 1") { fail("load $class: $@"); next }

    my $status = in_child(sub {
        my $m = $class->new("$dir/$v.hm", 1024);
        $m->put(make_key($v, $_), make_val($v, $_)) for 1 .. 8;
        my $c = $m->cursor;
        $c->next;
        $m->DESTROY;
        # Must croak, not segfault.
        eval { $c->next; 1 } and POSIX::_exit(20);       # no croak at all
        POSIX::_exit($@ =~ /destroyed/ ? 0 : 21);
    });
    is $status, 0, "$class: cursor method after explicit map DESTROY croaks cleanly"
        or diag sprintf('child status 0x%04x (signal %d, exit %d)',
                        $status, $status & 127, $status >> 8);

    my $drop = in_child(sub {
        my $m = $class->new("$dir/$v-drop.hm", 1024);
        $m->put(make_key($v, $_), make_val($v, $_)) for 1 .. 8;
        my $c = $m->cursor;
        $c->next;
        $m->DESTROY;
        undef $c;                                        # cursor DESTROY on a freed handle
    });
    is $drop, 0, "$class: dropping a cursor after explicit map DESTROY is safe"
        or diag sprintf('child status 0x%04x (signal %d, exit %d)',
                        $drop, $drop & 127, $drop >> 8);
}

done_testing;
