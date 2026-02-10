# IO::Divert - AI Agent Notes

## Module Purpose

IO::Divert temporarily diverts STDOUT to an internal buffer using Perl's
`select()` function. When the object goes out of scope (DESTROY), the
captured output is optionally processed and printed to the original STDOUT.

## Origin

Extracted from `App::sdif::Divert` used in sdif/cdif tools. Released as
independent module for general use. sdif-tools now depends on IO::Divert.

## Key Design Decisions

### RAII Pattern
- Object creation starts capture
- DESTROY automatically restores STDOUT and prints
- No explicit close/restore needed

### DESTROY Order
- `select` runs before `close` to ensure STDOUT restoration
- Even if `close` fails, STDOUT is already restored
- `close` flushes the encoding layer's buffered data to the buffer scalar

### Encoding Handling
- Internal buffer uses `:encoding($encoding)` layer
- DESTROY decodes buffer before printing to original STDOUT
- Default encoding: utf-8

### FINAL Callback
- Operates on `$_` (localized copy of buffer)
- Applied before autoprint
- Common use: add prefixes, filter lines, transform text

### cancel Method
- Sets `autoprint => 0` and deletes `FINAL`
- Reuses existing fields; no extra flag needed
- Buffer content remains accessible via `content` after cancel

### In-memory FH Flush Behavior
- `close` on an in-memory FH with encoding layer flushes buffered data
  back to the scalar variable, overwriting any value set after the last write
- This is why cancel uses `autoprint`/`FINAL` fields instead of setting
  BUFFER to undef (close would overwrite undef with flushed data)

## API

```perl
# Constructor options
IO::Divert->new(
    encoding  => 'utf-8',  # buffer encoding
    autoprint => 1,        # print on destroy
    FINAL     => sub {},   # post-process callback
);

# Methods
$obj->content;   # get captured text (with flush)
$obj->buffer;    # get reference to buffer
$obj->fh;        # get filehandle
$obj->flush;     # flush buffer
$obj->clear;     # clear buffer
$obj->cancel;    # suppress FINAL and autoprint
```

## Test Notes

UTF-8 test requires `Encode::decode()` on output scalar because:
1. Test's STDOUT opened with `:encoding(utf-8)` to scalar
2. Scalar receives UTF-8 encoded bytes
3. Comparison with character string needs decode

## Build Notes

- Uses Minilla (minil) for build/release
- `minil build` regenerates README.md, META.json from POD
- Changes file: never commit (minil release uses uncommitted diff)
- META.json x_contributors: auto-generated from git log, contains email - acceptable
- No email address in POD AUTHOR section or LICENSE
- Run sdif-tools tests from its own directory: `cd /path/to/sdif-tools && prove -l t/`

## Related Work

- Capture::Tiny - heavier, captures process-wide
- IO::Capture::Stdout - not RAII pattern
- App::sdif::Divert - original implementation (removed from sdif-tools)

## Failed Experiments (Context)

Attempted fork-less function execution combining IO::Divert with
Command::Run. Failed because Perl's `<>` operator has global state
that cannot be localized with `local *STDIN`.
