# Examples

These examples are intentionally small and focus on demonstrating specific behaviors.

## 20_bounded_parallelism_with_drain.pl

Demonstrates controlled parallelism and `drain()` to stop the loop when all queued work has finished.
(Configure with: `my $fork = $loop->fork_helper(max_children => N)`.)

## 21_web_fetch_pool.pl

Runs one child per URL with bounded concurrency (set via `fork_helper(max_children => ...)`). Uses `cmd => [...]` and `drain()`.

## 22_timeout_kill.pl

Shows `timeout => ...`, `on_timeout`, and the relationship to `on_exit`.

## 23_cancel_queued_by_tag.pl

Shows `cancel_queued()` (predicate-based) to remove queued work without touching running children.

## 24_child_callback_exec.pl

Shows the `child => sub { ... }` form and the recommended explicit `exec`.

## 25_chunking_notes.pl

Shows that stdout/stderr callbacks receive chunks (not lines) and includes buffering notes.
