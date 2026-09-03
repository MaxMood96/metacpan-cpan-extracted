A tiny workflow manager and logger for Perl, like SnakeMake or NextFlow, but in pure Perl and aimed at making long, error-prone shell pipelines easy to **debug** and **reproduce**.

Every step is a single `task()` call. SimpleFlow checks the inputs before a
command runs and the outputs after, times the command, captures its `stdout`,
`stderr`, exit code and signal, optionally logs a full structured record, and
skips work that has already been done. It can also bound a step with a
[timeout](#timeouts) and rebuild [out-of-date outputs](#out-of-date-outputs).

Two subroutines are exported by default: [`task`](#task) and [`say2`](#say2).

# Install

With a CPAN client:

    cpanm SimpleFlow

Or from a checkout:

    perl Makefile.PL
    make
    make test
    make install

# Synopsis

The simplest useful case: run a command and confirm it produced its output:

    use SimpleFlow qw(task say2);

    my $t = task(
        cmd            => 'which ls',
        'output.files' => '/tmp/AFK3mnEK8L.log',
    );

`task` returns a hash reference describing exactly what happened:

    {
        cmd            "which ls",
        die            1,
        dir            "/home/con/Scripts/SimpleFlow",
        done           "now",
        dry.run        0,
        duration       0.00191903114318848,
        exit           0,
        note           "",
        output.files   [
            [0] "/tmp/AFK3mnEK8L.log"
        ],
        overwrite      1,
        signal         0,
        source.file    "t/01.t",
        source.line    29,
        stderr         "",
        stdout         "/usr/bin/ls",
        will.do        "done"
    }

> **Portability note.** SimpleFlow runs whatever shell command you give it via
> `system()`, so the *commands themselves* are your responsibility to keep
> cross-platform (e.g. `which ls` is Unix-only). SimpleFlow's own behaviour
> exit/signal decoding and coloured output is cross-platform; see the
> [change log](#change-log).

# `task`

    my $result = task(%args);      # or task(\%args)

Runs one command with checking, timing, capture and logging. Takes either a
flat key/value list or a single hash reference; the only required key is `cmd`.

## Arguments

| Key            | Type             | Default | Description |
|----------------|------------------|---------|-------------|
| `cmd`          | scalar or array  | `undef` | **Required.** The command to run. A string is handed to the shell; an array ref is run [without a shell](#running-without-a-shell). |
| `die`          | bool (`0`/`1`)   | `1`     | Die if the command fails (non-zero exit, timeout, or a missing output file). Set to `0` to warn and continue instead. |
| `dry.run`      | bool             | `0`     | Print the command (and log it) but do not execute it. |
| `input.files`  | scalar or array  | `undef` | File(s) that must exist and be readable **before** running; otherwise `task` dies. |
| `input.file`   | scalar           | `undef` | Convenience form of `input.files` for a **single** file. Must be a plain filename (not a reference). Cannot be combined with `input.files`. |
| `output.files` | scalar or array  | `undef` | File(s) expected to exist **after** running; used both for the missing-output check and for [skip detection](#skipping-completed-work). |
| `output.file`  | scalar           | `undef` | Convenience form of `output.files` for a **single** file. Must be a plain filename (not a reference). Cannot be combined with `output.files`. |
| `log.fh`       | open filehandle  | `undef` | If given, the full result record is also written here. Must be a real, open filehandle; `task` switches it to autoflush. |
| `note`         | scalar           | `''`    | Free-text note copied into the result and the log. |
| `overwrite`    | bool             | `0`     | If false and all `output.files` already exist, the command is skipped. Set true to always run. |
| `quiet`        | bool             | `0`     | Suppress the record printed to the terminal. The log and error messages on `STDERR` are unaffected. See [Quiet runs](#quiet-runs). |
| `stale`        | bool             | `0`     | Also re-run when an input file is newer than an output file. See [Out-of-date outputs](#out-of-date-outputs). |
| `timeout`      | whole seconds    | `0`     | Kill the command if it runs longer than this. `0` means no limit. See [Timeouts](#timeouts). |

Passing an unrecognised key, an undefined or empty filename, a `cmd` that is
neither a string nor an array ref, or a non-filehandle `log.fh` causes `task`
to die: these are usually mistakes worth catching early. Giving both
`output.file` and `output.files` (or both `input.file` and `input.files`), or a
reference where a single filename is expected, dies for the same reason.

## Return value

`task` always returns a hash reference. Every field below except the two
`input.*` ones is present on **every** path, so a caller running under
`use warnings FATAL => 'all'` can read the record after a skip or a dry run
without an uninitialized-value warning turning fatal. On those paths the
execution-only fields simply hold their empty values (`exit` and `signal` are
`0`, `stdout` and `stderr` are `''`, `duration` is `0`).

| Field              | Meaning |
|--------------------|---------|
| `cmd`              | The command that was run. An array-ref `cmd` is recorded space-joined for readability; that is not a shell-quoted round trip, since it never went near a shell. |
| `dir`              | Working directory at execution time. |
| `done`             | `"now"` (just ran), `"before"` (skipped, outputs already existed), or `"not yet"` (dry run). |
| `will.do`          | `"done"`, `"no"` (skipped), `"no: dry run"`, or `"FAILED"`. `"FAILED"` is set whenever the command exited non-zero, timed out, or left a declared output file missing — **whether or not `die` is set**. |
| `duration`         | Wall-clock seconds the command took (`0` for skips/dry runs). |
| `exit`             | Exit code of the command (`-1` if it could not be launched). |
| `signal`           | Signal number if the command process was killed by a signal, else `0`. Always `0` on Windows (no POSIX signals). |
| `timed.out`        | `1` if the command was killed for exceeding its `timeout`, else `0`. |
| `out.of.date`      | `1` if `stale` was set and an input was newer than an output, else `0`. |
| `stdout`, `stderr` | Captured output, with trailing whitespace stripped. |
| `die`, `dry.run`, `overwrite`, `note`, `quiet`, `stale`, `timeout` | The (defaulted) argument values used. |
| `output.files`     | Array ref of the output files (a scalar argument, or an `output.file`, is normalised to a one-element array). |
| `output.file.size` | Hash of `filename => size in bytes` for the outputs. |
| `input.files`      | Array ref of the input files, normalised the same way (present only if you passed `input.files` or `input.file`). |
| `input.file.size`  | Hash of `filename => size in bytes` for the inputs (present only if you passed `input.files` or `input.file`). |
| `source.file`, `source.line` | Where in *your* code the `task` was called: handy when debugging a long pipeline. |

## Skipping completed work

If `overwrite` is false (the default) and every file in `output.files` already
exists, `task` does **not** re-run the command. This makes pipelines
restartable: re-running the script picks up where it left off.

    open my $log, '>', 'logfile.txt';
    my $t = task(
        cmd            => 'gmx grompp -f em.mdp -c box.gro -p topol.top -o em.tpr',
        'input.files'  => ['em.mdp', 'box.gro', 'topol.top'],
        'output.files' => 'em.tpr',
        'log.fh'       => $log,
    );
    close $log;

On the first run `done` is `"now"`; on a re-run (with `em.tpr` present) `done`
is `"before"` and `will.do` is `"no"`. Pass `overwrite => 1` to force it.

An output file that exists but cannot be **read** does not count as done: it is
not a usable result, and treating it as one would skip the very step that could
replace it.

## Out-of-date outputs

Existence alone is a weak test. If an input file has been edited since the
output was built, the output is stale even though it is present — and by
default `task` will still skip the step, exactly as earlier versions did.

Pass `stale => 1` to get the rule `make` and `snakemake` use: re-run whenever
the newest `input.files` mtime is later than the oldest `output.files` mtime.

    my $t = task(
        cmd            => 'gmx grompp -f em.mdp -c box.gro -p topol.top -o em.tpr',
        'input.files'  => ['em.mdp', 'box.gro', 'topol.top'],
        'output.files' => 'em.tpr',
        stale          => 1,
    );

Editing `em.mdp` now rebuilds `em.tpr`; leaving it alone still skips. The
result's `out.of.date` field says which of the two happened. This is off by
default so that upgrading does not silently start re-running steps in pipelines
written against 0.15 and earlier.

## Timeouts

`timeout` gives a step a wall-clock budget in whole seconds:

    my $t = task(
        cmd     => 'a command that sometimes wedges',
        timeout => 600,
        die     => 0,
    );

The command is run in its own process group and, if the budget is exceeded, the
**whole group** is killed — a shell command is usually a pipeline, not a single
process, and killing only the shell would leave its children running. The
result then has `timed.out => 1` and `will.do => "FAILED"`; with the default
`die => 1` the pipeline stops there instead.

`timeout` needs `fork()` and POSIX process groups, so it is refused on
`MSWin32`. Leaving it at `0` (the default) changes nothing anywhere.

## Running without a shell

Giving `cmd` an array ref runs the command directly, with no shell in between:

    my $t = task(
        cmd           => ['gzip', '-9', $file],   # $file needs no quoting
        'output.file' => "$file.gz",
    );

This is the form to reach for when an argument comes from data — a filename
with a space, a quote, or a `$` in it is passed through untouched instead of
being re-parsed by the shell. You lose shell features (`>`, `|`, `*`, `&&`) in
exchange; use the string form when you want them.

## Quiet runs

Every `task` prints its record to the terminal. Over a hundred-step pipeline
that is a lot of scrollback, so `quiet => 1` suppresses it:

    my $t = task(
        cmd      => 'one of very many steps',
        'log.fh' => $log,
        quiet    => 1,
    );

The log filehandle still receives the full record, and error messages still go
to `STDERR`: asking for less noise is not the same as asking to be kept in the
dark about a failure.

## Dry runs

Useful for inspecting a pipeline without executing anything expensive:

    my $t = task(
        cmd       => 'a long-running, time-consuming command',
        'dry.run' => 1,
        'log.fh'  => $fh,
    );

The command is printed (and logged) but not run; `will.do` is `"no: dry run"`.

## Failure behaviour

By default (`die => 1`) `task` dies if the command exits non-zero, exceeds its
`timeout`, or leaves any declared `output.files` missing afterwards, so a broken
step stops the pipeline immediately.

With `die => 0`, `task` instead warns and returns its result hash with
`will.do => "FAILED"`, letting you decide what to do:

    my $t = task(cmd => 'a step that may fail', die => 0);
    if ($t->{'will.do'} eq 'FAILED') {
        ...   # $t->{'exit'}, $t->{stderr} and $t->{'timed.out'} say why
    }

## `say2`

    say2($message, $filehandle);

"Say to two places": prints `$message` to standard output **and** to the given
log filehandle, prefixed with the calling file and line number so log entries
are traceable. The filehandle must be open, or `say2` dies.

    open my $log, '>', 'run.log';
    say2('starting equilibration', $log);   # -> STDOUT and run.log
    close $log;

# Dependencies

Core/runtime modules used by SimpleFlow:

- [`Capture::Tiny`](https://metacpan.org/pod/Capture::Tiny) captures `stdout`/`stderr`
- [`Data::Printer`](https://metacpan.org/pod/Data::Printer) (`DDP`) pretty result/record printing
- [`Devel::Confess`](https://metacpan.org/pod/Devel::Confess) better backtraces on death
- `List::Util`, `Scalar::Util`, `Time::HiRes`, `Cwd`, `POSIX` core utilities

The test suite additionally uses `Test::More` and
[`Test::Exception`](https://metacpan.org/pod/Test::Exception).

# Changes

## 0.16 2026-08-28 (Claude Opus 5 helped)

### Fixed

- **`die => 0` never reported a failure.** The `will.do => "FAILED"` assignment
    sat inside the `if ($r{die})` branch, so it could only run on the path that
    immediately died. Under `die => 0` — the mode in which the caller is meant
    to read `will.do` — a command that exited non-zero was reported as `"done"`,
    and nothing warned. `will.do` is now `"FAILED"` for a non-zero exit, a
    timeout, or a missing output file regardless of `die`, and `die => 0` emits
    a warning naming the exit code.
- **The log lost the record of the task that killed the run.** The log
    filehandle was never autoflushed. Measured with a `SIGKILL` part-way through
    a pipeline (the shape of an OOM kill or a scheduler eviction), a log holding
    862 bytes on a clean exit held 139 bytes after the kill: everything written
    after the last command started — its exit code, duration and captured output
    — was still in stdio's buffer. `task` and `say2` now switch the handle to
    autoflush.
- **An undefined filename still crashed.** 0.14 added a `defined` guard to the
    0-length check, but the `-f -r` filetest ran first, so an `undef` element of
    an `input.files` array died as `Use of uninitialized value $_ in -r` under
    `warnings FATAL => 'all'`. Names are now validated before anything is
    filetested.
- **The 0-length `input.files` check was unreachable.** `''` fails `-f`, so an
    empty input filename was reported as `"missing or unreadable"` and the
    0-length check below it could never fire. Both undefined and 0-length names
    are now reported as what they are, and the message names the offending index.
- **`cmd` was not type-checked.** Only definedness was checked, so any reference
    was stringified straight into the shell: `task(cmd => ['echo','hi'])` ran the
    literal command `ARRAY(0x5ed9d076e618)`. `cmd` must now be a non-empty string
    or a non-empty array ref of defined values.
- **Skip detection and the post-run check disagreed.** Skipping tested a bare
    `-f` while the post-run check tested `-f -r`, so an output file that existed
    but could not be read counted as already done. Both use `-f -r` now.
- **The result record changed shape between paths.** `exit`, `signal`, `stdout`
    and `stderr` were absent after a skip or a dry run, so a caller running under
    the `warnings FATAL => 'all'` this module recommends died just by reading
    `$t->{'exit'}`. They are now always present, holding their empty values.
- **`string_max` was uncapped**, so a chatty command had its whole capture echoed
    to the terminal and written to the log — a measured 3 MB stdout wrote
    3,002,832 bytes to each. It is now capped at 4096 characters; Data::Printer
    marks what it drops. The full capture is still on the result hash.
- **Loading SimpleFlow polluted `main::`.** `use DDP` and `use Cwd 'getcwd'` sat
    above the `package` statement, so `p`, `np` and `getcwd` were imported into
    every program that loaded the module. The `package` statement now comes
    first, and the duplicated `use` lines are gone.
- **Unbalanced parenthesis** in the 0-length `output.files` error message.

### Added

- **`stale`**: also re-run when an input file is newer than an output file, the
    rule `make` and `snakemake` use. Off by default, so existing pipelines are
    unaffected. The result carries `out.of.date`.
- **`timeout`**: a wall-clock budget in whole seconds. The command runs in its
    own process group and the whole group is killed if the budget is exceeded,
    so a wedged pipeline does not leave orphans behind. The result carries
    `timed.out`. POSIX only.
- **An array-ref `cmd`** runs the command without a shell, so arguments coming
    from data need no quoting.
- **`quiet`**: suppress the record printed to the terminal without silencing the
    log or `STDERR`.
- **`input.file`**, the single-file convenience form of `input.files`, matching
    `output.file`.

### Changed

- `$VERSION` is now a quoted string. As a bare number it was stringified through
    `%g`, so a future `0.20` would have become `"0.2"` and compared as older than
    `"0.15"` on CPAN.
- **Incompatible:** `input.files` on the result is now always an array ref, as
    `output.files` always was. A scalar argument used to be stored raw.
- `POSIX` (core) is now a dependency, for `_exit` in the timeout child.

## 0.15 2026-07-17 (Claude Opus 4.8 helped)

addition of `output.file`, a single-file convenience form of `output.files`. It
takes one plain filename, cannot be combined with `output.files`, and dies if
given a reference or an empty name.

removal of Term::ANSIColor dependency

improved coverage testing

## 0.14 2026-06-29 (Claude Opus 4.8 helped)

### `task`
- **New:** accepts a flat key/value list as well as a hash ref —
  `task(cmd => ...)` and `task( cmd => ... )` are now equivalent. A lone
  non-hashref scalar or any odd-length argument list is fatal.
- **Bug fix:** the default `die => 1` was ignored when checking for missing
  `output.files`. The block tested the raw `$args->{'die'}` (undef when the
  caller omitted it) instead of the resolved `$r{'die'}`, so a command that
  failed to produce its declared outputs only warned instead of dying. Now
  consistent with the exit-code check.
- **Bug fix:** removed a stray `)` (and an extraneous leading space) from the
  "command is" line written to the log file; it now matches the on-screen form.
- **Bug fix:** `length $_ == 0` could throw a fatal uninitialized-value warning
  (under `warnings FATAL => 'all'`) on an undef element of the `input.files`
  array branch and the `output.files` empty-name check. Both now guard with
  `(defined $_) && (length $_ == 0)`, matching the `input.files` scalar branch.

## 0.13 2026-06-11

### Fixed (Claude Opus 4.8 helped)

- **Exit status and signal are now decoded correctly.** `task()` previously
  computed the exit code (`$status >> 8`) and *then* derived the signal as
  `$exit & 127`. Because the signal lives in the low byte of the raw wait
  status, which `>> 8` discards the `signal` field was always wrong: a clean
  `exit 42` was reported as `signal 42`, and a process actually killed by a
  signal reported `signal 0`. The signal is now read from the raw status before
  shifting, so `exit` and `signal` are independent and accurate.

- **No longer dies on a missing output file when `die => 0`.** The zero-size
  check did `(-s $file) == 0`, which is `undef == 0` when a declared output file
  is absent. Under `use warnings FATAL => 'all'` that "uninitialized value"
  warning was fatal, so a task that was meant to *warn* about missing output
  (with `die => 0`) crashed instead. Missing sizes are now treated as `0`, so
  the task warns and returns its result hash as intended.

- **The "already done" result is now logged with its `duration`.** In the
  short-circuit path (output files already exist), `duration` was set *after*
  the record was written to the log, so the logged hash was missing it; the
  duplicate `done => 'before'` assignment was also removed.

### Changed / Windows support

- **Portable exit-status handling.** Decoding now branches on `$^O`: Windows has
  no POSIX signals (`signal` is reported as `0` there), and a `system()` that
  fails to launch the command (`-1`) yields `exit => -1` instead of a garbage
  value from shifting `-1`.

- **ANSI colour is disabled on the legacy Windows console.** `Term::ANSIColor`
  output is suppressed on `MSWin32` unless an ANSI-capable terminal is detected
  (Windows Terminal, ConEmu, or ANSICON), so `cmd.exe` no longer prints raw
  escape sequences and redirected logs stay clean. Unix and modern Windows
  terminals are unaffected.

### Tests

- Rewrote `t/01.t` to be cross-platform: shell commands now invoke the running
  Perl interpreter (`"$^X" -e ...`) instead of Unix-only tools (`which`, `ls`,
  `ln`, `cp`), and temp files use the system temp directory instead of a
  hard-coded `/tmp`.
- Added regression tests for both fixed bugs (exit/signal decoding; surviving a
  missing output file with `die => 0`).
- Added coverage for the `note` field, the `input.file.size` / `output.file.size`
  hashes, scalar-vs-array normalisation of `input.files` / `output.files`, the
  `dir` / `source.file` / `source.line` metadata, captured `stdout` / `stderr`
  (including trailing-whitespace stripping), and argument validation (missing
  `cmd`, unknown keys, bad `log.fh`, missing input files).

## 0.12 2026-02-14

exit code now matches what shell would show it as; signal now appears

## 0.11 2026-01-13

max string length now corresponds to max of output strings, no more truncated output
added List::Util dependency for string length maxes
memory size now shows when output
directory is now output during dry runs

# COPYRIGHT AND LICENSE

This software is free.  It is licensed under the same terms as Perl itself
