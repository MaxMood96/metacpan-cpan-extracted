# NAME

Flat::Profile - Streaming-first profiling for CSV/TSV flat files

# SYNOPSIS

    use Flat::Profile;

    my $p = Flat::Profile->new();

    my $it = $p->iter_rows(
        path       => "data.csv",
        has_header => 1,
        delimiter  => ",",
        encoding   => "UTF-8",
    );

    while (my $row = $it->next_row) {
        # $row is an arrayref
    }

    my $report = $p->profile_file(
        path        => "data.csv",
        has_header  => 1,
        delimiter   => ",",
        null_empty  => 1,
        null_tokens => ["NULL", "NA"],
        example_cap => 10,
        max_errors  => 1000,
    );

# DESCRIPTION

Flat::Profile is part of the Flat::\* series. It provides streaming-first profiling
for CSV/TSV inputs for practical ETL and legacy data workflows.

Design goals:

- Streaming-first (single pass, predictable memory)
- Practical diagnostics (ragged rows, null policy, examples)
- Stable report format intended to feed Flat::Schema / Flat::Validate

# METHODS

## new

    my $p = Flat::Profile->new();

Constructor. Takes named arguments (currently reserved for future configuration).

## iter\_rows

    my $it = $p->iter_rows(%args);

Returns an iterator object ([Flat::Profile::Iterator](https://metacpan.org/pod/Flat%3A%3AProfile%3A%3AIterator)).

Required named arguments:

- path

Common named arguments:

- has\_header (boolean)
- delimiter ("," or "\\t")
- encoding (default "UTF-8")

## profile\_file

    my $report = $p->profile_file(%args);

Profiles a CSV/TSV file in a streaming pass and returns a hashref report.

Key named arguments include:

- path (required)
- has\_header
- delimiter
- encoding
- null\_empty (default true)
- null\_tokens (arrayref; default empty)
- example\_cap (default 10)
- max\_errors (threshold stop; default 1000)

# NULL SEMANTICS

By default, empty string is treated as null:

    null_empty => 1   # default

To treat empty string as a value:

    null_empty => 0

You can also treat specific exact tokens as null:

    null_tokens => ["NULL", "N/A"]

Notes:

- Token matching is exact (no trimming, case-sensitive) in v1.
- undef is always treated as null.

# RAGGED ROWS

Flat::Profile tracks width mismatches relative to an expected width:

- If has\_header is true, expected width is the header width.
- Otherwise, expected width is the first data row width.

Row numbers in ragged examples use **data-row numbering** (header excluded):
the first data row is row\_number 1.

# REPORT FORMAT

profile\_file() returns a hashref with stable top-level metadata including:

- report\_version
- generated\_at (UTC timestamp string)
- perl\_version
- module\_version
- header (arrayref or undef)
- rows (data rows processed; header excluded)
- ragged (counts + capped examples)
- columns (arrayref of per-column stats)

# AUTHOR

Sergio de Sousa

Issues: https://github.com/sergio-desousa/Flat-Profile/issues

# LICENSE

Perl 5 (Artistic/GPL dual).
