package Flat::Profile;

use strict;
use warnings;

our $VERSION = '0.02';

use Carp qw(croak);

use Flat::Profile::Iterator;

sub new {
    my ($class, %opts) = @_;

    my $self = bless {
        _opts => { %opts },
    }, $class;

    return $self;
}

sub profile_file {
    my ($self, %args) = @_;

    if (!exists $args{path}) {
        croak "profile_file() requires named argument: path";
    }

    my $path = $args{path};

    my $delimiter = exists $args{delimiter} ? $args{delimiter} : ",";
    if ($delimiter ne "," && $delimiter ne "\t") {
        croak "profile_file() delimiter must be ',' or \"\\t\"";
    }

    my $has_header = $args{has_header} ? 1 : 0;

    my $encoding = exists $args{encoding} ? $args{encoding} : "UTF-8";

    my $example_cap = exists $args{example_cap} ? $args{example_cap} : 10;
    if ($example_cap !~ /^\d+$/ || $example_cap < 0) {
        croak "profile_file() example_cap must be an integer >= 0";
    }

    my $null_empty = exists $args{null_empty} ? ($args{null_empty} ? 1 : 0) : 1;

    my $null_tokens = exists $args{null_tokens} ? $args{null_tokens} : [];
    if (ref($null_tokens) ne 'ARRAY') {
        croak "profile_file() null_tokens must be an arrayref";
    }

    my %null_token_map;
    for my $tok (@{$null_tokens}) {
        if (!defined $tok) {
            croak "profile_file() null_tokens must not contain undef";
        }
        $null_token_map{$tok} = 1;
    }

    open my $fh, "<:encoding($encoding)", $path
        or croak "Failed to open '$path' for reading: $!";

    my $it = Flat::Profile::Iterator->new(
        fh         => $fh,
        delimiter  => $delimiter,
        has_header => $has_header,
    );

    my $generated_at = _format_utc_timestamp();

    my %report = (
        report_version => 1,

        generated_at   => $generated_at,
        perl_version   => $],
        module_version => $VERSION,

        path        => $path,
        delimiter   => $delimiter,
        encoding    => $encoding,
        has_header  => $has_header ? 1 : 0,
        null_empty  => $null_empty ? 1 : 0,
        null_tokens => [ @{$null_tokens} ],
        header      => undef,

        rows        => 0,
        columns     => [],

        expected_width     => undef,
        max_observed_width => 0,
        ragged => {
            short_rows => 0,
            long_rows  => 0,
            short_examples => [],
            long_examples  => [],
            example_cap    => 10,
        },
    );

    my $ragged_example_cap = 10;
    my $header_captured = 0;

    while (my $row = $it->next_row) {
        $report{rows}++;

        if ($has_header && !$header_captured) {
            $report{header} = $it->get_Header;
            $header_captured = 1;

            if (defined $report{header}) {
                $report{expected_width} = scalar @{$report{header}};
            }
        }

        my $width = scalar @{$row};
        if ($width > $report{max_observed_width}) {
            $report{max_observed_width} = $width;
        }

        if (!defined $report{expected_width}) {
            $report{expected_width} = $width;
        }

        if (defined $report{expected_width}) {
            if ($width < $report{expected_width}) {
                $report{ragged}{short_rows}++;

                if (@{$report{ragged}{short_examples}} < $ragged_example_cap) {
                    push @{$report{ragged}{short_examples}}, {
                        row_number => $report{rows},
                        width      => $width,
                    };
                }
            }
            elsif ($width > $report{expected_width}) {
                $report{ragged}{long_rows}++;

                if (@{$report{ragged}{long_examples}} < $ragged_example_cap) {
                    push @{$report{ragged}{long_examples}}, {
                        row_number => $report{rows},
                        width      => $width,
                    };
                }
            }
        }

        my $num_cols = $width;

        for (my $i = 0; $i < $num_cols; $i++) {
            my $value = $row->[$i];

            my $col = $report{columns}->[$i];
            if (!defined $col) {
                $col = {
                    index         => $i,
                    count_values  => 0,
                    count_null    => 0,
                    count_nonnull => 0,
                    min_length    => undef,
                    max_length    => undef,
                    sample_values => [],
                    _sample_seen  => {},
                };
                $report{columns}->[$i] = $col;
            }

            $col->{count_values}++;

            my $is_null =
                !defined $value
                || ($null_empty && defined $value && $value eq '')
                || (defined $value && $null_token_map{$value});

            if ($is_null) {
                $col->{count_null}++;
                next;
            }

            $col->{count_nonnull}++;

            my $len = length($value);

            if (!defined $col->{min_length} || $len < $col->{min_length}) {
                $col->{min_length} = $len;
            }
            if (!defined $col->{max_length} || $len > $col->{max_length}) {
                $col->{max_length} = $len;
            }

            if ($example_cap > 0) {
                if (@{$col->{sample_values}} < $example_cap) {
                    if (!$col->{_sample_seen}{$value}) {
                        push @{$col->{sample_values}}, $value;
                        $col->{_sample_seen}{$value} = 1;
                    }
                }
            }
        }
    }

    for my $col (@{$report{columns}}) {
        next if !defined $col;
        delete $col->{_sample_seen};
    }

    $report{ragged}{example_cap} = $ragged_example_cap;

    return \%report;
}

sub iter_rows {
    my ($self, %args) = @_;

    if (!exists $args{path}) {
        croak "iter_rows() requires named argument: path";
    }

    my $path = $args{path};

    my $delimiter = exists $args{delimiter} ? $args{delimiter} : ",";
    if ($delimiter ne "," && $delimiter ne "\t") {
        croak "iter_rows() delimiter must be ',' or \"\\t\"";
    }

    my $has_header = $args{has_header} ? 1 : 0;

    my $encoding = exists $args{encoding} ? $args{encoding} : "UTF-8";

    open my $fh, "<:encoding($encoding)", $path
        or croak "Failed to open '$path' for reading: $!";

    return Flat::Profile::Iterator->new(
        fh         => $fh,
        delimiter  => $delimiter,
        has_header => $has_header,
    );
}

sub _format_utc_timestamp {
    my @t = gmtime(time());
    my $year = $t[5] + 1900;
    my $mon  = $t[4] + 1;
    my $day  = $t[3];
    my $hour = $t[2];
    my $min  = $t[1];
    my $sec  = $t[0];

    return sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ", $year, $mon, $day, $hour, $min, $sec);
}

1;

__END__

=pod

=head1 NAME

Flat::Profile - Streaming-first profiling for CSV/TSV flat files

=head1 SYNOPSIS

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

=head1 DESCRIPTION

Flat::Profile is part of the Flat::* series. It provides streaming-first profiling
for CSV/TSV inputs for practical ETL and legacy data workflows.

Design goals:

=over 4

=item *

Streaming-first (single pass, predictable memory)

=item *

Practical diagnostics (ragged rows, null policy, examples)

=item *

Stable report format intended to feed Flat::Schema / Flat::Validate

=back

=head1 METHODS

=head2 new

    my $p = Flat::Profile->new();

Constructor. Takes named arguments (currently reserved for future configuration).

=head2 iter_rows

    my $it = $p->iter_rows(%args);

Returns an iterator object (L<Flat::Profile::Iterator>).

Required named arguments:

=over 4

=item * path

=back

Common named arguments:

=over 4

=item * has_header (boolean)

=item * delimiter ("," or "\t")

=item * encoding (default "UTF-8")

=back

=head2 profile_file

    my $report = $p->profile_file(%args);

Profiles a CSV/TSV file in a streaming pass and returns a hashref report.

Key named arguments include:

=over 4

=item * path (required)

=item * has_header

=item * delimiter

=item * encoding

=item * null_empty (default true)

=item * null_tokens (arrayref; default empty)

=item * example_cap (default 10)

=item * max_errors (threshold stop; default 1000)

=back

=head1 NULL SEMANTICS

By default, empty string is treated as null:

    null_empty => 1   # default

To treat empty string as a value:

    null_empty => 0

You can also treat specific exact tokens as null:

    null_tokens => ["NULL", "N/A"]

Notes:

=over 4

=item *

Token matching is exact (no trimming, case-sensitive) in v1.

=item *

undef is always treated as null.

=back

=head1 RAGGED ROWS

Flat::Profile tracks width mismatches relative to an expected width:

=over 4

=item *

If has_header is true, expected width is the header width.

=item *

Otherwise, expected width is the first data row width.

=back

Row numbers in ragged examples use B<data-row numbering> (header excluded):
the first data row is row_number 1.

=head1 REPORT FORMAT

profile_file() returns a hashref with stable top-level metadata including:

=over 4

=item * report_version

=item * generated_at (UTC timestamp string)

=item * perl_version

=item * module_version

=item * header (arrayref or undef)

=item * rows (data rows processed; header excluded)

=item * ragged (counts + capped examples)

=item * columns (arrayref of per-column stats)

=back

=head1 AUTHOR

Sergio de Sousa

Issues: https://github.com/sergio-desousa/Flat-Profile/issues

=head1 LICENSE

Perl 5 (Artistic/GPL dual).

=cut
