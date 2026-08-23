# EV / AnyEvent code study for strict reactor comparison

This note records the implementation details used to design
`run-reactor-ceiling-comparison.pl`.

## EV

Studied against EV 4.37 documentation/current distribution metadata.

Relevant behavior:

- `EV::io($fh, EV::READ, $cb)` is the direct public I/O watcher API.
- Public EV callbacks receive the watcher object and revents mask.
- `EV::run()` owns the loop until a break condition or lack of active watchers.
- `EV::run(EV::RUN_ONCE)` performs at most one blocking loop iteration.
- `EV::break(EV::BREAK_ALL)` causes active `EV::run` calls to return.
- `EV::iteration()` reports the number of event-loop polls and is recorded as
  the EV reactor-iteration metric.
- `EV::backend()` reports the selected libev backend. The benchmark records it
  and expects epoll on the Linux comparison host rather than assuming it.

The direct EV benchmark therefore registers every preaccepted socket with
`EV::io`, runs the identical shared Perl echo callback, and enters `EV::run`.
Watcher creation is outside the timed interval.

## AnyEvent with EV

Studied from `AnyEvent::Impl::EV` and `AE.pm` (AnyEvent 7.17).

The EV adaptor contains two different I/O construction paths:

```perl
*AE::io = defined &EV::_ae_io
       ? \&EV::_ae_io
       : sub($$$) { EV::io $_[0], $_[1] ? EV::WRITE : EV::READ, $_[2] };
```

while the method API is implemented as:

```perl
sub io {
    my ($class, %arg) = @_;
    EV::io
        $arg{fh},
        $arg{poll} eq "r" ? EV::READ : EV::WRITE,
        $arg{cb}
}
```

The same adaptor implements blocking AnyEvent condition-variable waits as:

```perl
sub AnyEvent::CondVar::Base::_wait {
    EV::run EV::RUN_ONCE until exists $_[0]{_ae_sent};
}
```

AnyEvent's AE documentation describes the function-call API as the shorter,
faster API and specifically notes that it makes a material difference with the
EV backend.

Consequences for this benchmark:

1. `anyevent-ae` is the primary fast AnyEvent comparison. It uses `AE::io` and
   a normal AnyEvent condition variable.
2. `anyevent-method` is reported separately. It uses `AnyEvent->io`; watcher
   construction itself is not timed, but it can still select a different EV
   callback path than `AE::io`.
3. `anyevent-ae-evrun` is diagnostic only. It uses the same `AE::io` watchers
   but calls `EV::run` directly so a difference from `anyevent-ae` isolates
   loop-driving/condvar behavior rather than application work.
4. `PERL_ANYEVENT_MODEL=EV` is set before AnyEvent detection, and the benchmark
   refuses to rank the case unless `$AnyEvent::MODEL` is exactly
   `AnyEvent::Impl::EV`.
5. The benchmark records whether `AE::io` is actually a direct alias to
   `EV::_ae_io` at runtime rather than assuming the optimization exists.

## Fairness decision

The benchmark does not try to make the framework internals identical. Callback
argument construction, watcher dispatch, loop ownership, and backend adaptor
cost are exactly the differences being measured.

It does make the application and network work identical:

- same already-connected TCP sockets;
- same watcher count;
- same 64-byte payload by default;
- same serial one-request/one-reply client protocol;
- same exact Perl `echo_read()` implementation;
- same `sysread(..., 8192)` loop;
- same `syswrite` loop;
- same Perl counters;
- same true warmup outside timing;
- same no-close measured interval;
- same external catastrophic timeout.

A result is non-rankable if measured bytes do not match exactly, a client
fails, a client closes during measurement, or the simple echo write path sees
partial/EAGAIN writes that would require buffering not present in the shared
benchmark body.

## Sources studied

- EV 4.37 POD / source browser on MetaCPAN
- libev documentation accompanying EV
- AnyEvent 7.17 POD on MetaCPAN
- `lib/AnyEvent/Impl/EV.pm`
- `lib/AE.pm`

The benchmark intentionally records runtime module versions and selected
backend/model in its JSON so later results can be tied to the exact installed
software.
