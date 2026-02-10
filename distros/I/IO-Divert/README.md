[![Actions Status](https://github.com/tecolicom/IO-Divert/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/tecolicom/IO-Divert/actions?workflow=test) [![MetaCPAN Release](https://badge.fury.io/pl/IO-Divert.svg)](https://metacpan.org/release/IO-Divert)
# NAME

IO::Divert - Divert STDOUT to capture and process output

# SYNOPSIS

    use IO::Divert;

    {
        my $divert = IO::Divert->new(
            FINAL => sub { s/^/# /mg }
        );

        complex_output_function();
        # All output is commented, without modifying the function
    }

# VERSION

Version 0.99

# DESCRIPTION

IO::Divert temporarily redirects STDOUT to an internal buffer using
Perl's `select()` function.  When the object goes out of scope, the
captured output is optionally processed through a callback and printed
to the original STDOUT.

The key benefit is **transparent output transformation**: you can modify
all output from a block of code without changing any individual `print`
statements within it.

This is particularly useful when:

- You need to post-process output from code you don't want to modify
- Adding consistent formatting (prefixes, indentation) to complex output
- Conditionally suppressing or transforming output based on results

# CONSTRUCTOR

## new

    my $divert = IO::Divert->new(%options);

Creates a new IO::Divert object and begins capturing STDOUT.

Options:

- **FINAL** => \\&coderef

    A subroutine to process the captured output before printing.
    The captured text is available in `$_` and should be modified
    in place.

        FINAL => sub { s/foo/bar/g }

- **encoding** => $encoding

    Character encoding for the buffer.  Default is `utf-8`.

- **autoprint** => $bool

    If true (default), automatically print the captured output when
    the object is destroyed.  Set to false to capture without printing.

# METHODS

## fh

    my $fh = $divert->fh;

Returns the filehandle used for capturing.

## buffer

    my $bufref = $divert->buffer;

Returns a reference to the internal buffer string.

## content

    my $text = $divert->content;

Returns the current captured content as a string.
This method flushes the buffer before returning.

## flush

    $divert->flush;

Flushes the output buffer.  Returns the object for chaining.

## clear

    $divert->clear;

Clears the captured content.  Returns the object for chaining.

## cancel

    $divert->cancel;

Cancels the `FINAL` callback and autoprint on object destruction.
The captured content remains accessible via `content`.
Returns the object for chaining.

# EXAMPLES

## Transform output from existing code

    {
        my $divert = IO::Divert->new(
            FINAL => sub { s/^/    /mg }  # indent all lines
        );

        legacy_report_generator();  # prints many lines
        # All output is indented without touching the original code
    }

## Capture without printing

    my $output;
    {
        my $divert = IO::Divert->new(autoprint => 0);
        generate_output();
        $output = $divert->content;
    }
    # Process $output as needed

# PRACTICAL USAGE IN sdif/cdif

This module was originally extracted from [App::sdif](https://metacpan.org/pod/App%3A%3Asdif).

In **sdif** and **cdif**, `git log --graph` output has graph prefix
characters (`| `, `* `, etc.) on each line.  To process the diff
content, the prefix is stripped from input lines.  IO::Divert is then
used to recover the prefix by prepending it to every output line.
Since the diff processing code has many scattered `print` statements,
modifying each one to handle the prefix would be impractical.
IO::Divert recovers the prefix in one place, so the processing code
remains completely unaware of it, and works the same whether graph
output is present or not.

    my $divert;
    if ($prefix) {
        $divert = IO::Divert->new(
            FINAL => sub { s/^/$prefix/mg }
        );
    }

    # diff processing code -- unaware of graph prefix
    process_diff();

    # $divert goes out of scope:
    # prefix is recovered in the output by FINAL callback

# SEE ALSO

[App::sdif](https://metacpan.org/pod/App%3A%3Asdif)

[Capture::Tiny](https://metacpan.org/pod/Capture%3A%3ATiny), [IO::Capture::Stdout](https://metacpan.org/pod/IO%3A%3ACapture%3A%3AStdout)

# AUTHOR

Kazumasa Utashiro

# LICENSE

Copyright 2026 Kazumasa Utashiro.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
