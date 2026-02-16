# Linux::Event::Fork examples

This directory contains both **usage examples** and **stress tests**.

The stress tests are intentionally small and self-contained so you can run them
under `strace`, `perf`, `valgrind`, or with different loop backends.

## Stress tests

### 90_stress_timeout_churn.pl

**What it stresses**

- fork/exit churn (many short-lived children)
- timer scheduling + cancellation (`timeout`)
- drain-first teardown stability under load

**Controls**

- `N` (default 200): number of children
- `TIMEOUT` (default 0.02): timeout seconds

**Expected**

- The loop stops cleanly after all children complete.
- Some jobs are marked `timedout` (timeout callback fired).
- Because the child installs a TERM handler that exits 0, a timed-out job can
  still count as `exit_ok`.

Run:

```bash
perl -Ilib examples/90_stress_timeout_churn.pl
N=1000 TIMEOUT=0.01 perl -Ilib examples/90_stress_timeout_churn.pl
```

### 91_stress_stdin_with_timeout.pl

**What it stresses**

- backpressure-aware stdin streaming (`stdin_write` / write watcher)
- timeout firing while stdin is still being written
- teardown stability after EPIPE (child exit closes stdin pipe)

**Controls**

- `TIMEOUT` (default 0.05): timeout seconds
- `MB` (default 5): payload size in MiB written to stdin

**Expected**

- Prints `START`, then `[timeout]`, then `DONE` summary.
- Does not hang, and does not die from SIGPIPE.

Run:

```bash
perl -Ilib examples/91_stress_stdin_with_timeout.pl
TIMEOUT=0.03 perl -Ilib examples/91_stress_stdin_with_timeout.pl
MB=20 TIMEOUT=0.05 perl -Ilib examples/91_stress_stdin_with_timeout.pl
```
