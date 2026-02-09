package Flat::Profile::Iterator;

use strict;
use warnings;

use Carp qw(croak);
use Text::CSV;

sub new {
    my ($class, %opts) = @_;

    for my $required (qw(fh delimiter has_header)) {
        if (!exists $opts{$required}) {
            croak "Iterator->new missing required argument: $required";
        }
    }

    my $csv = Text::CSV->new({
        binary    => 1,
        sep_char  => $opts{delimiter},
        auto_diag => 0,
    });

    if (!$csv) {
        croak "Failed to initialize Text::CSV";
    }

    my $self = bless {
        _fh         => $opts{fh},
        _csv        => $csv,
        _has_header => $opts{has_header} ? 1 : 0,

        # Row index counts *data rows returned* (header excluded).
        _row_index  => 0,

        # Header row (arrayref) if has_header enabled and header consumed.
        _header     => undef,

        # Internal: whether we've processed header (if any).
        _started    => 0,
    }, $class;

    return $self;
}

sub next_row {
    my ($self) = @_;

    # Lazily consume header if configured
    if (!$self->{_started}) {
        $self->{_started} = 1;

        if ($self->{_has_header}) {
            my $header_row = $self->_read_row_raw();
            if (!defined $header_row) {
                return undef; # empty file
            }
            $self->{_header} = $header_row;
        }
    }

    my $row = $self->_read_row_raw();
    if (defined $row) {
        $self->{_row_index}++;
    }

    return $row;
}

sub _read_row_raw {
    my ($self) = @_;

    my $fh  = $self->{_fh};
    my $csv = $self->{_csv};

    while (1) {
        my $row = $csv->getline($fh);

        if ($row) {
            my @fields = @{$row};
            return \@fields;
        }

        if ($csv->eof) {
            return undef;
        }

        my $err = $csv->error_diag;
        croak "CSV parse error: $err";
    }
}

sub get_Row_Index {
    my ($self) = @_;
    return $self->{_row_index};
}

sub get_Header {
    my ($self) = @_;
    return $self->{_header};
}

1;
