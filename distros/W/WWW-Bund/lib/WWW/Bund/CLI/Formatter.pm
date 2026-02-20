package WWW::Bund::CLI::Formatter;
our $VERSION = '0.002';
# ABSTRACT: Template-based output formatter for bund CLI

use Moo;
use WWW::Bund::CLI::Strings;
use YAML::PP qw(Dump LoadFile);
use JSON::MaybeXS ();
use Scalar::Util qw(blessed);
use List::Util qw(max sum);
use namespace::clean;


has templates_dir => (is => 'ro', required => 1);


has strings_dir => (is => 'ro', required => 1);


has lang => (is => 'ro', default => 'de');


has template_override => (
    is        => 'rw',
    predicate => 'has_template_override',
);


has strings => (
    is      => 'lazy',
    builder => sub {
        my ($self) = @_;
        WWW::Bund::CLI::Strings->new(
            lang        => $self->lang,
            strings_dir => $self->strings_dir,
        );
    },
);


sub format_output {
    my ($self, $data, $endpoint_name, $mode) = @_;
    $mode //= 'template';

    unless (defined $data) {
        return $self->strings->get('fmt_no_data') . "\n";
    }

    if ($mode eq 'json') {
        my $json = JSON::MaybeXS->new(pretty => 1, canonical => 1, utf8 => 0);
        return $json->encode($data);
    }

    if ($mode eq 'yaml') {
        return Dump(_deref_booleans($data));
    }

    # Template mode
    my $template = $self->_load_template($endpoint_name);

    unless ($template) {
        # YAML fallback
        return Dump(_deref_booleans($data));
    }

    # Extract data if template specifies extraction path
    if ($template->{extract}) {
        $data = $self->_extract($data, $template->{extract});
        unless (defined $data) {
            return $self->strings->get('fmt_no_data_path', $template->{extract}) . "\n";
        }
    }

    my $type = $template->{type} // 'table';

    if ($type eq 'table') {
        return $self->_render_table($data, $template);
    } elsif ($type eq 'list') {
        return $self->_render_list($data, $template);
    } elsif ($type eq 'record') {
        return $self->_render_record($data, $template);
    } else {
        return Dump(_deref_booleans($data));
    }
}


sub _load_template {
    my ($self, $endpoint_name) = @_;

    # Override path takes priority
    if ($self->has_template_override) {
        my $path = $self->template_override;
        return eval { LoadFile($path) };
    }

    # Look in share/templates/{lang}/
    return unless $endpoint_name;
    my $path = "$self->{templates_dir}/$self->{lang}/$endpoint_name.yml";
    return unless -f $path;
    return eval { LoadFile($path) };
}

sub _extract {
    my ($self, $data, $path) = @_;

    for my $key (split /\./, $path) {
        if (ref $data eq 'HASH') {
            $data = $data->{$key};
        } elsif (ref $data eq 'ARRAY' && $key =~ /^\d+$/) {
            $data = $data->[$key];
        } else {
            return undef;
        }
        return undef unless defined $data;
    }
    return $data;
}

sub _resolve_field {
    my ($self, $item, $field) = @_;

    my $val = $item;
    for my $key (split /\./, $field) {
        if (ref $val eq 'HASH') {
            $val = $val->{$key};
        } else {
            return undef;
        }
        return undef unless defined $val;
    }

    # Translate booleans to localized strings
    if (JSON::MaybeXS::is_bool($val)) {
        return $val ? $self->strings->get('bool_true') : $self->strings->get('bool_false');
    }
    if (!ref $val && $val eq 'true')  { return $self->strings->get('bool_true') }
    if (!ref $val && $val eq 'false') { return $self->strings->get('bool_false') }

    return ref $val ? undef : $val;
}

sub _empty_message {
    my ($self, $template) = @_;
    return ($template->{empty} // $self->strings->get('fmt_empty')) . "\n";
}

sub _render_table {
    my ($self, $data, $template) = @_;

    # Data must be an array
    unless (ref $data eq 'ARRAY') {
        return Dump(_deref_booleans($data));
    }

    unless (@$data) {
        return $self->_empty_message($template);
    }

    my $columns = $template->{columns};

    # If no columns defined, auto-detect from first row
    unless ($columns && @$columns) {
        if (ref $data->[0] eq 'HASH') {
            my @keys = sort grep { !ref($data->[0]{$_}) } keys %{$data->[0]};
            $columns = [map { { field => $_, header => uc($_) } } @keys];
        } else {
            # Simple array of scalars
            return join('', map { (defined $_ ? $_ : '') . "\n" } @$data);
        }
    }

    return $self->strings->get('fmt_no_columns') . "\n" unless @$columns;

    # Resolve column headers and max widths (never narrower than header)
    my @headers = map { $_->{header} // uc($_->{field}) } @$columns;
    my @max_widths = map {
        my $w = $_->{width} // 50;
        my $h = length($_->{header} // uc($_->{field}));
        $w < $h ? $h : $w;
    } @$columns;
    my @widths = map { length($headers[$_]) } 0 .. $#headers;

    # Calculate actual widths from data
    my $max_rows = @$data > 100 ? 100 : scalar @$data;
    for my $i (0 .. $max_rows - 1) {
        my $row = $data->[$i];
        for my $c (0 .. $#$columns) {
            my $val = $self->_resolve_field($row, $columns->[$c]{field}) // '';
            my $len = length("$val");
            $widths[$c] = $len if $len > $widths[$c];
        }
    }

    # Cap widths
    for my $c (0 .. $#$columns) {
        $widths[$c] = $max_widths[$c] if $widths[$c] > $max_widths[$c];
    }

    # Grid mode
    my $grid = $template->{full_grid} ? 1 : 0;
    my $sep  = $grid ? ' | ' : '  ';

    # Build format string
    my $fmt = ($grid ? '| ' : '')
            . join($sep, map { "%-${_}s" } @widths)
            . ($grid ? ' |' : '')
            . "\n";

    # Build horizontal rule
    my $rule;
    if ($grid) {
        $rule = '+-' . join('-+-', map { '-' x $_ } @widths) . "-+\n";
    } else {
        $rule = '-' x (sum(@widths) + 2 * $#widths) . "\n";
    }

    my $out = '';
    $out .= $rule if $grid;
    $out .= sprintf $fmt, @headers;
    $out .= $rule;

    # Check which columns have wrap enabled
    my @wrap = map { $_->{wrap} ? 1 : 0 } @$columns;

    for my $i (0 .. $max_rows - 1) {
        my $row = $data->[$i];
        my @vals = map {
            my $v = $self->_resolve_field($row, $_->{field}) // '';
            $v;
        } @$columns;

        # Word-wrap or truncate per column
        my @wrapped;  # array of arrays: wrapped lines per column
        my $max_lines = 1;
        for my $c (0 .. $#vals) {
            if ($wrap[$c] && length($vals[$c]) > $widths[$c]) {
                my @lines = _word_wrap($vals[$c], $widths[$c]);
                $wrapped[$c] = \@lines;
                $max_lines = scalar @lines if @lines > $max_lines;
            } else {
                if (length($vals[$c]) > $widths[$c]) {
                    $vals[$c] = substr($vals[$c], 0, $widths[$c]);
                }
                $wrapped[$c] = [$vals[$c]];
            }
        }

        for my $line (0 .. $max_lines - 1) {
            my @line_vals = map { $wrapped[$_][$line] // '' } 0 .. $#vals;
            $out .= sprintf $fmt, @line_vals;
        }
        $out .= $rule if $grid;
    }

    if (@$data > 100) {
        $out .= $self->strings->get('fmt_more_rows', scalar(@$data) - 100) . "\n";
    }

    return $out;
}

sub _render_list {
    my ($self, $data, $template) = @_;

    unless (ref $data eq 'ARRAY') {
        return Dump(_deref_booleans($data));
    }

    unless (@$data) {
        return $self->_empty_message($template);
    }

    my $field = $template->{field};
    my @values;

    for my $item (@$data) {
        if ($field) {
            push @values, $self->_resolve_field($item, $field) // '';
        } elsif (ref $item) {
            push @values, $self->_resolve_field($item, 'name')
                       // $self->_resolve_field($item, 'shortname')
                       // $self->_resolve_field($item, 'title')
                       // $self->_resolve_field($item, 'id')
                       // '';
        } else {
            push @values, defined $item ? $item : '';
        }
    }

    my $cols = $template->{columns};
    if ($cols && $cols > 1) {
        my $max_len = max(map { length $_ } @values) // 0;
        my $out = '';
        for my $i (0 .. $#values) {
            if ($i > 0 && $i % $cols == 0) {
                $out .= "\n";
            } elsif ($i > 0) {
                $out .= '  ';
            }
            $out .= sprintf "%-${max_len}s", $values[$i];
        }
        $out .= "\n" if length $out;
        return $out;
    }

    return join('', map { "$_\n" } @values);
}

sub _word_wrap {
    my ($text, $width) = @_;
    return ($text) if length($text) <= $width;

    my @lines;
    while (length($text) > $width) {
        # Find last space within width
        my $pos = rindex($text, ' ', $width);
        if ($pos <= 0) {
            # No space found, hard break
            $pos = $width;
            push @lines, substr($text, 0, $pos);
            $text = substr($text, $pos);
        } else {
            push @lines, substr($text, 0, $pos);
            $text = substr($text, $pos + 1);  # skip the space
        }
    }
    push @lines, $text if length $text;
    return @lines;
}

sub _render_record {
    my ($self, $data, $template) = @_;

    unless (ref $data eq 'HASH') {
        return Dump(_deref_booleans($data));
    }

    my $fields = $template->{fields};

    # If no fields defined, show all scalar keys
    unless ($fields && @$fields) {
        $fields = [
            map  { { field => $_, label => $_ } }
            sort grep { !ref($data->{$_}) }
            keys %$data
        ];
    }

    return $self->strings->get('fmt_empty') . "\n" unless @$fields;

    my $max_label = max(map { length($_->{label} // $_->{field}) } @$fields) // 0;

    my $out = '';
    for my $f (@$fields) {
        my $label = $f->{label} // $f->{field};
        my $val = $self->_resolve_field($data, $f->{field});

        if (!defined $val && $f->{field} =~ /\./) {
            # Try the full dotted path
            $val = $self->_extract($data, $f->{field});
        }

        if (ref $val) {
            my $json = JSON::MaybeXS->new(pretty => 0, canonical => 1, utf8 => 0);
            $val = $json->encode($val);
        }

        $val //= '';
        $out .= sprintf "%-${max_label}s  %s\n", $label, $val;
    }

    return $out;
}

sub _deref_booleans {
    my ($d) = @_;
    if (JSON::MaybeXS::is_bool($d)) {
        return $d ? 1 : 0;
    }
    if (ref $d eq 'HASH') {
        return { map { $_ => _deref_booleans($d->{$_}) } keys %$d };
    }
    if (ref $d eq 'ARRAY') {
        return [ map { _deref_booleans($_) } @$d ];
    }
    return $d;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WWW::Bund::CLI::Formatter - Template-based output formatter for bund CLI

=head1 VERSION

version 0.002

=head1 SYNOPSIS

    use WWW::Bund::CLI::Formatter;

    my $formatter = WWW::Bund::CLI::Formatter->new(
        templates_dir => 'share/templates',
        strings_dir   => 'share/strings',
        lang          => 'de',
    );

    # Format with template
    my $output = $formatter->format_output($data, 'autobahn_roads', 'template');

    # JSON output
    my $json = $formatter->format_output($data, undef, 'json');

    # YAML output
    my $yaml = $formatter->format_output($data, undef, 'yaml');

=head1 DESCRIPTION

Template-based formatter for CLI output. Supports three modes:

=over

=item * C<template> - Use YAML templates from C<share/templates/{lang}/> to format as tables, lists, or records

=item * C<json> - Pretty-print JSON

=item * C<yaml> - YAML output

=back

=head2 Template Types

Templates define how data should be displayed:

=over

=item * B<table> - Columnar display with headers, auto-sizing, optional wrapping and grid borders

=item * B<list> - Simple vertical list or multi-column list

=item * B<record> - Key-value pairs (single record)

=back

Template files are YAML with structure:

    type: table
    extract: path.to.data.array  # optional
    empty: "No data available."  # optional
    columns:
      - field: id
        header: ID
        width: 10
      - field: name
        header: Name
        width: 40
        wrap: true

See C<share/templates/> for 497 templates across 7 languages.

=head2 templates_dir

Directory containing template subdirectories by language. Required.

Structure: C<{templates_dir}/{lang}/{endpoint_name}.yml>

=head2 strings_dir

Directory containing localized string files. Required.

=head2 lang

Language code for templates and strings. Defaults to C<de>.

=head2 template_override

Override path to custom template file. Optional.

When set, this template is used instead of the default endpoint-based lookup.

=head2 strings

L<WWW::Bund::CLI::Strings> instance for localized messages.

=head2 format_output

    my $output = $formatter->format_output($data, $endpoint_name, $mode);

Format data for output. Returns formatted string.

Arguments:

=over

=item * C<$data> - Data structure to format

=item * C<$endpoint_name> - Endpoint name for template lookup (optional for json/yaml)

=item * C<$mode> - Output mode: 'template', 'json', or 'yaml' (default: 'template')

=back

For template mode, looks up template file based on endpoint name and language.
Falls back to YAML if template not found.

=head1 SUPPORT

=head2 Issues

Please report bugs and feature requests on GitHub at
L<https://github.com/Getty/p5-www-bund/issues>.

=head1 CONTRIBUTING

Contributions are welcome! Please fork the repository and submit a pull request.

=head1 AUTHOR

Torsten Raudssus <torsten@raudssus.de>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2026 by Torsten Raudssus.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
