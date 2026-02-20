# Examples

These examples are intentionally small and focus on demonstrating specific behaviors of `Linux::Event::Fork`.

All examples use the object-based API:

```perl
my $fork = Linux::Event::Fork->new($loop, max_children => N);
```

---

## 20_bounded_parallelism_with_drain.pl

Demonstrates controlled parallelism using `max_children` and `drain()` to stop the loop when all queued work has finished.

Configured with:

```perl
my $fork = Linux::Event::Fork->new($loop, max_children => N);
```

---

## 21_web_fetch_pool.pl

Runs one child per URL with bounded concurrency (set via `max_children`).

Uses:

- `cmd => [...]`
- `drain()` to detect completion

---

## 22_timeout_kill.pl

Shows:

- `timeout => ...`
- `on_timeout`
- `timeout_kill => ...`
- Relationship between `on_timeout` and `on_exit`

Demonstrates TERM → optional KILL escalation behavior.

---

## 23_cancel_queued_by_tag.pl

Shows `cancel_queued()` (predicate-based) to remove queued work without affecting running children.

Demonstrates safe cancellation of queued `Request` objects.

---

## 24_child_callback_exec.pl

Shows the `child => sub { ... }` form.

Demonstrates the recommended explicit `exec` pattern:

```perl
exec { $cmd->[0] } @$cmd;
```

---

## 25_chunking_notes.pl

Demonstrates that `on_stdout` and `on_stderr` receive arbitrary-sized chunks (not line-buffered).

Includes notes about buffering and assembling line-based output safely.
