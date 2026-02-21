package Yote::Spiderpup::SFC;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(parse_sfc);

# Keys whose values are function expressions (kept as raw strings)
my %FUNCTION_KEYS = map { $_ => 1 } qw(methods computed lifecycle watch);

# Keys whose values are parsed as Perl data structures
my %DATA_KEYS = map { $_ => 1 } qw(vars import routes initial_store);

# Keys whose values are arrays of strings
my %ARRAY_KEYS = map { $_ => 1 } ('import-css', 'import-js', 'include-js');

#----------------------------------------------------------------------
# Public API
#----------------------------------------------------------------------

sub parse_sfc {
    my ($content) = @_;
    my $result = {};

    # Extract <style> blocks
    while ($content =~ /<style([^>]*)>(.*?)<\/style>/gs) {
        my ($attrs, $body) = ($1, $2);
        $body =~ s/^\n//;
        $body =~ s/\n$//;
        if ($attrs =~ /lang\s*=\s*["']less["']/) {
            $result->{less} = ($result->{less} // '') . $body;
        } else {
            $result->{css} = ($result->{css} // '') . $body;
        }
    }

    # Extract <template> blocks
    while ($content =~ /<template([^>]*)>(.*?)<\/template>/gs) {
        my ($attrs, $body) = ($1, $2);
        $body =~ s/^\n//;
        $body =~ s/\n$//;
        if ($attrs =~ /recipe\s*=\s*["']([^"']+)["']/) {
            my $recipe_name = $1;
            $result->{recipes} //= {};
            $result->{recipes}{$recipe_name} //= {};
            $result->{recipes}{$recipe_name}{html} = $body;
        } elsif ($attrs =~ /name\s*=\s*["']([^"']+)["']/) {
            my $variant = $1;
            $result->{"html_$variant"} = $body;
        } else {
            $result->{html} = $body;
        }
    }

    # Extract <script> blocks
    while ($content =~ /<script([^>]*)>(.*?)<\/script>/gs) {
        my ($attrs, $body) = ($1, $2);
        if ($attrs =~ /recipe\s*=\s*["']([^"']+)["']/) {
            my $recipe_name = $1;
            $result->{recipes} //= {};
            $result->{recipes}{$recipe_name} //= {};
            my $parsed = _parse_top_object($body);
            for my $key (keys %$parsed) {
                $result->{recipes}{$recipe_name}{$key} = $parsed->{$key};
            }
        } else {
            my $parsed = _parse_top_object($body);
            for my $key (keys %$parsed) {
                $result->{$key} = $parsed->{$key};
            }
        }
    }

    return $result;
}

#----------------------------------------------------------------------
# Whitespace and comment skipping
#----------------------------------------------------------------------

sub _skip_ws {
    my ($text, $pos) = @_;
    my $len = length($text);
    while ($$pos < $len) {
        # Skip whitespace
        if (substr($text, $$pos, 1) =~ /\s/) {
            $$pos++;
            next;
        }
        # Skip // line comments
        if (substr($text, $$pos, 2) eq '//') {
            $$pos += 2;
            while ($$pos < $len && substr($text, $$pos, 1) ne "\n") {
                $$pos++;
            }
            next;
        }
        # Skip /* block comments */
        if (substr($text, $$pos, 2) eq '/*') {
            $$pos += 2;
            while ($$pos < $len - 1 && substr($text, $$pos, 2) ne '*/') {
                $$pos++;
            }
            $$pos += 2 if $$pos < $len - 1;
            next;
        }
        last;
    }
}

#----------------------------------------------------------------------
# String reading
#----------------------------------------------------------------------

sub _read_string {
    my ($text, $pos) = @_;
    my $quote = substr($text, $$pos, 1);
    $$pos++;  # skip opening quote
    my $result = '';
    my $len = length($text);
    while ($$pos < $len) {
        my $ch = substr($text, $$pos, 1);
        if ($ch eq '\\') {
            # Escape sequence
            $result .= $ch;
            $$pos++;
            if ($$pos < $len) {
                $result .= substr($text, $$pos, 1);
                $$pos++;
            }
            next;
        }
        if ($ch eq $quote) {
            $$pos++;  # skip closing quote
            return $result;
        }
        $result .= $ch;
        $$pos++;
    }
    return $result;
}

#----------------------------------------------------------------------
# Key reading (bare identifier or quoted string)
#----------------------------------------------------------------------

sub _read_key {
    my ($text, $pos) = @_;
    my $ch = substr($text, $$pos, 1);
    if ($ch eq '"' || $ch eq "'") {
        return _read_string($text, $pos);
    }
    # Bare identifier: letters, digits, underscore, dash
    my $start = $$pos;
    my $len = length($text);
    while ($$pos < $len && substr($text, $$pos, 1) =~ /[\w\-]/) {
        $$pos++;
    }
    return substr($text, $start, $$pos - $start);
}

#----------------------------------------------------------------------
# Read balanced expression (for function context values)
# Scans until we hit , or } at depth 0, respecting strings and brackets
#----------------------------------------------------------------------

sub _read_balanced {
    my ($text, $pos) = @_;
    my $start = $$pos;
    my $depth = 0;
    my $len = length($text);

    while ($$pos < $len) {
        my $ch = substr($text, $$pos, 1);

        # Handle strings
        if ($ch eq '"' || $ch eq "'" || $ch eq '`') {
            _skip_string($text, $pos);
            next;
        }

        # Handle line comments
        if ($ch eq '/' && $$pos + 1 < $len && substr($text, $$pos + 1, 1) eq '/') {
            $$pos += 2;
            while ($$pos < $len && substr($text, $$pos, 1) ne "\n") {
                $$pos++;
            }
            next;
        }

        # Handle block comments
        if ($ch eq '/' && $$pos + 1 < $len && substr($text, $$pos + 1, 1) eq '*') {
            $$pos += 2;
            while ($$pos < $len - 1 && substr($text, $$pos, 2) ne '*/') {
                $$pos++;
            }
            $$pos += 2 if $$pos < $len - 1;
            next;
        }

        if ($ch eq '{' || $ch eq '[' || $ch eq '(') {
            $depth++;
            $$pos++;
            next;
        }
        if ($ch eq '}' || $ch eq ']' || $ch eq ')') {
            if ($depth == 0) {
                last;  # end of enclosing object/array
            }
            $depth--;
            $$pos++;
            next;
        }
        if ($ch eq ',' && $depth == 0) {
            last;
        }
        $$pos++;
    }

    my $val = substr($text, $start, $$pos - $start);
    $val =~ s/^\s+//;
    $val =~ s/\s+$//;
    return $val;
}

# Skip over a string without returning its content (for balanced scanning)
sub _skip_string {
    my ($text, $pos) = @_;
    my $quote = substr($text, $$pos, 1);
    $$pos++;
    my $len = length($text);
    while ($$pos < $len) {
        my $ch = substr($text, $$pos, 1);
        if ($ch eq '\\') {
            $$pos += 2;
            next;
        }
        if ($ch eq $quote) {
            $$pos++;
            return;
        }
        $$pos++;
    }
}

#----------------------------------------------------------------------
# Read data value (parse JS literal to Perl scalar/hashref/arrayref)
#----------------------------------------------------------------------

sub _read_data_value {
    my ($text, $pos) = @_;
    _skip_ws($text, $pos);
    my $len = length($text);
    return undef if $$pos >= $len;

    my $ch = substr($text, $$pos, 1);

    # String
    if ($ch eq '"' || $ch eq "'") {
        return _read_string($text, $pos);
    }

    # Backtick template literal - read as string
    if ($ch eq '`') {
        return _read_string($text, $pos);
    }

    # Array
    if ($ch eq '[') {
        return _read_data_array($text, $pos);
    }

    # Object
    if ($ch eq '{') {
        return _read_data_object($text, $pos);
    }

    # Boolean / null / undefined / number / bare value
    my $start = $$pos;
    while ($$pos < $len) {
        my $c = substr($text, $$pos, 1);
        last if $c eq ',' || $c eq '}' || $c eq ']' || $c =~ /\s/;
        $$pos++;
    }
    my $raw = substr($text, $start, $$pos - $start);
    # Convert JS types to Perl
    return 1 if $raw eq 'true';
    return 0 if $raw eq 'false';
    return undef if $raw eq 'null' || $raw eq 'undefined';
    # Numbers
    if ($raw =~ /^-?\d+\.?\d*$/) {
        return $raw + 0;
    }
    return $raw;
}

sub _read_data_array {
    my ($text, $pos) = @_;
    $$pos++;  # skip [
    my @items;
    my $len = length($text);
    while ($$pos < $len) {
        _skip_ws($text, $pos);
        last if $$pos >= $len;
        last if substr($text, $$pos, 1) eq ']';

        push @items, _read_data_value($text, $pos);

        _skip_ws($text, $pos);
        if ($$pos < $len && substr($text, $$pos, 1) eq ',') {
            $$pos++;  # skip comma
        }
    }
    $$pos++ if $$pos < $len;  # skip ]
    return \@items;
}

sub _read_data_object {
    my ($text, $pos) = @_;
    $$pos++;  # skip {
    my %obj;
    my $len = length($text);
    while ($$pos < $len) {
        _skip_ws($text, $pos);
        last if $$pos >= $len;
        last if substr($text, $$pos, 1) eq '}';

        my $key = _read_key($text, $pos);
        _skip_ws($text, $pos);

        # skip colon
        if ($$pos < $len && substr($text, $$pos, 1) eq ':') {
            $$pos++;
        }

        _skip_ws($text, $pos);
        $obj{$key} = _read_data_value($text, $pos);

        _skip_ws($text, $pos);
        if ($$pos < $len && substr($text, $$pos, 1) eq ',') {
            $$pos++;  # skip comma
        }
    }
    $$pos++ if $$pos < $len;  # skip }
    return \%obj;
}

#----------------------------------------------------------------------
# Parse function map: { key: funcExpr, ... } keeping values as raw strings
#----------------------------------------------------------------------

sub _parse_function_map {
    my ($text, $pos) = @_;
    $$pos++;  # skip opening {
    my %map;
    my $len = length($text);
    while ($$pos < $len) {
        _skip_ws($text, $pos);
        last if $$pos >= $len;
        last if substr($text, $$pos, 1) eq '}';

        my $key = _read_key($text, $pos);
        _skip_ws($text, $pos);

        # skip colon
        if ($$pos < $len && substr($text, $$pos, 1) eq ':') {
            $$pos++;
        }

        _skip_ws($text, $pos);
        $map{$key} = _read_balanced($text, $pos);

        _skip_ws($text, $pos);
        if ($$pos < $len && substr($text, $$pos, 1) eq ',') {
            $$pos++;
        }
    }
    $$pos++ if $$pos < $len;  # skip closing }
    return \%map;
}

#----------------------------------------------------------------------
# Parse recipes map: { name: { ... }, ... } where each value is like a
# top-level script block but parsed at the object level
#----------------------------------------------------------------------

sub _parse_recipes_map {
    my ($text, $pos) = @_;
    $$pos++;  # skip opening {
    my %recipes;
    my $len = length($text);
    while ($$pos < $len) {
        _skip_ws($text, $pos);
        last if $$pos >= $len;
        last if substr($text, $$pos, 1) eq '}';

        my $recipe_name = _read_key($text, $pos);
        _skip_ws($text, $pos);

        # skip colon
        if ($$pos < $len && substr($text, $$pos, 1) eq ':') {
            $$pos++;
        }

        _skip_ws($text, $pos);

        if (substr($text, $$pos, 1) eq '{') {
            $recipes{$recipe_name} = _parse_recipe_object($text, $pos);
        }

        _skip_ws($text, $pos);
        if ($$pos < $len && substr($text, $$pos, 1) eq ',') {
            $$pos++;
        }
    }
    $$pos++ if $$pos < $len;  # skip closing }
    return \%recipes;
}

# Parse a single recipe object (same dispatch as top-level)
sub _parse_recipe_object {
    my ($text, $pos) = @_;
    $$pos++;  # skip opening {
    my %result;
    my $len = length($text);
    while ($$pos < $len) {
        _skip_ws($text, $pos);
        last if $$pos >= $len;
        last if substr($text, $$pos, 1) eq '}';

        my $key = _read_key($text, $pos);
        _skip_ws($text, $pos);

        # skip colon
        if ($$pos < $len && substr($text, $$pos, 1) eq ':') {
            $$pos++;
        }
        _skip_ws($text, $pos);

        $result{$key} = _parse_value_for_key($key, $text, $pos);

        _skip_ws($text, $pos);
        if ($$pos < $len && substr($text, $$pos, 1) eq ',') {
            $$pos++;
        }
    }
    $$pos++ if $$pos < $len;  # skip closing }
    return \%result;
}

#----------------------------------------------------------------------
# Value dispatch based on key name
#----------------------------------------------------------------------

sub _parse_value_for_key {
    my ($key, $text, $pos) = @_;

    if ($FUNCTION_KEYS{$key}) {
        if (substr($text, $$pos, 1) eq '{') {
            return _parse_function_map($text, $pos);
        }
        return _read_balanced($text, $pos);
    }
    if ($DATA_KEYS{$key}) {
        return _read_data_value($text, $pos);
    }
    if ($ARRAY_KEYS{$key}) {
        return _read_data_value($text, $pos);
    }
    if ($key eq 'recipes') {
        if (substr($text, $$pos, 1) eq '{') {
            return _parse_recipes_map($text, $pos);
        }
        return _read_data_value($text, $pos);
    }
    # Default: scalar (string, number, etc)
    return _read_data_value($text, $pos);
}

#----------------------------------------------------------------------
# Top-level script parser
#----------------------------------------------------------------------

sub _parse_top_object {
    my ($text) = @_;
    my $pos = 0;
    my $len = length($text);
    my %result;

    _skip_ws($text, \$pos);

    # Skip opening { if present
    my $has_braces = 0;
    if ($pos < $len && substr($text, $pos, 1) eq '{') {
        $has_braces = 1;
        $pos++;
    }

    while ($pos < $len) {
        _skip_ws($text, \$pos);
        last if $pos >= $len;
        last if $has_braces && substr($text, $pos, 1) eq '}';

        my $key = _read_key($text, \$pos);
        last unless length($key);

        _skip_ws($text, \$pos);

        # skip colon
        if ($pos < $len && substr($text, $pos, 1) eq ':') {
            $pos++;
        }
        _skip_ws($text, \$pos);

        $result{$key} = _parse_value_for_key($key, $text, \$pos);

        _skip_ws($text, \$pos);
        if ($pos < $len && substr($text, $pos, 1) eq ',') {
            $pos++;
        }
    }

    return \%result;
}

1;
