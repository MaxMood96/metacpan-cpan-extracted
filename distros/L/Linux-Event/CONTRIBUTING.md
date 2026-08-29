# Contributing to Linux::Event

Bug reports and focused pull requests are welcome at
<https://github.com/haxmeister/perl-linux-event>.

Linux::Event is Linux-only and requires Perl 5.36 or newer. Before submitting a
change, build and run the distribution tests:

```sh
perl Makefile.PL
make
make test
make disttest
```

Keep public API changes deliberate and documented in the affected module POD,
README, and `Changes`. Add regression coverage for behavioral fixes. Benchmark
changes to callback hot paths should include before-and-after measurements using
the scripts under `bench/`.

