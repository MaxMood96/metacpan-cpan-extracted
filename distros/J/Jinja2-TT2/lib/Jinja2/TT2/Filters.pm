package Jinja2::TT2::Filters;

use strict;
use warnings;
use v5.20;

# Jinja2 filter to TT2 mapping
# Types:
#   vmethod  - TT2 virtual method (e.g., list.join)
#   filter   - TT2 filter (e.g., | html)
#   custom   - Custom code transformation
#   none     - No direct equivalent (passthrough or comment)

my %FILTER_MAP = (
    # String filters
    upper => {
        type => 'vmethod',
        name => 'upper',
    },
    lower => {
        type => 'vmethod',
        name => 'lower',
    },
    capitalize => {
        type => 'vmethod',
        name => 'ucfirst',  # Close approximation
    },
    title => {
        type => 'filter',
        name => 'title',  # TT2 doesn't have this; needs plugin
    },
    trim => {
        type => 'vmethod',
        name => 'trim',
    },
    striptags => {
        type => 'filter',
        name => 'html_strip',  # Needs Template::Plugin::HTML
    },
    escape => {
        type => 'filter',
        name => 'html_entity',
    },
    e => {
        type => 'filter',
        name => 'html_entity',
    },
    safe => {
        type => 'none',  # TT2 doesn't auto-escape
        name => '',
    },
    forceescape => {
        type => 'filter',
        name => 'html_entity',
    },

    # Numeric filters
    abs => {
        type => 'custom',
        code => sub {
            my ($base) = @_;
            return "($base >= 0 ? $base : -$base)";
        },
    },
    int => {
        type => 'vmethod',
        name => 'int',
    },
    float => {
        type => 'none',  # TT2 numbers are already floats
        name => '',
    },
    round => {
        type => 'custom',
        code => sub {
            my ($base, @args) = @_;
            my $precision = $args[0] // 0;
            return "format($base, '%." . $precision . "f')";
        },
    },
    filesizeformat => {
        type => 'none',  # Needs custom implementation
        name => 'filesizeformat',
    },

    # List filters
    first => {
        type => 'vmethod',
        name => 'first',
    },
    last => {
        type => 'vmethod',
        name => 'last',
    },
    length => {
        type => 'vmethod',
        name => 'size',
    },
    count => {
        type => 'vmethod',
        name => 'size',
    },
    reverse => {
        type => 'vmethod',
        name => 'reverse',
    },
    sort => {
        type => 'vmethod',
        name => 'sort',
    },
    join => {
        type => 'vmethod',
        name => 'join',
    },
    sum => {
        type => 'custom',
        code => sub {
            my ($base) = @_;
            # TT2 needs a loop for sum
            return "$base.join('+')";  # Simplified; needs proper handling
        },
    },
    min => {
        type => 'custom',
        code => sub {
            my ($base) = @_;
            return "$base.sort.first";
        },
    },
    max => {
        type => 'custom',
        code => sub {
            my ($base) = @_;
            return "$base.sort.last";
        },
    },
    random => {
        type => 'custom',
        code => sub {
            my ($base) = @_;
            return "$base.pick";  # TT2 List plugin
        },
    },
    unique => {
        type => 'vmethod',
        name => 'unique',
    },
    list => {
        type => 'none',  # Already a list in TT2
        name => '',
    },
    batch => {
        type => 'vmethod',
        name => 'batch',
    },
    slice => {
        type => 'vmethod',
        name => 'slice',
    },

    # Dict filters
    dictsort => {
        type => 'vmethod',
        name => 'sort',
    },
    items => {
        type => 'vmethod',
        name => 'pairs',
    },

    # String manipulation
    replace => {
        type => 'vmethod',
        name => 'replace',
    },
    truncate => {
        type => 'filter',
        name => 'truncate',
    },
    wordwrap => {
        type => 'filter',
        name => 'wrap',
    },
    wordcount => {
        type => 'custom',
        code => sub {
            my ($base) = @_;
            return "$base.split.size";
        },
    },
    center => {
        type => 'filter',
        name => 'center',
    },
    indent => {
        type => 'filter',
        name => 'indent',
    },
    format => {
        type => 'filter',
        name => 'format',
    },

    # URL filters
    urlencode => {
        type => 'filter',
        name => 'uri',
    },
    urlize => {
        type => 'none',  # Needs custom plugin
        name => 'urlize',
    },

    # JSON
    tojson => {
        type => 'filter',
        name => 'json',  # Needs Template::Plugin::JSON
    },

    # Misc
    default => {
        type => 'custom',
        code => sub {
            my ($base, @args) = @_;
            my $default = $args[0] // "''";
            return "($base || $default)";
        },
    },
    d => {  # Alias for default
        type => 'custom',
        code => sub {
            my ($base, @args) = @_;
            my $default = $args[0] // "''";
            return "($base || $default)";
        },
    },
    string => {
        type => 'none',  # TT2 auto-stringifies
        name => '',
    },
    pprint => {
        type => 'filter',
        name => 'dumper',  # Template::Plugin::Dumper
    },

    # Selection filters
    select => {
        type => 'vmethod',
        name => 'grep',  # Approximate
    },
    reject => {
        type => 'custom',
        code => sub {
            my ($base, @args) = @_;
            return "$base.reject(@args)";  # Needs custom vmethod
        },
    },
    selectattr => {
        type => 'none',
        name => 'selectattr',
    },
    rejectattr => {
        type => 'none',
        name => 'rejectattr',
    },
    groupby => {
        type => 'none',
        name => 'groupby',
    },
    map => {
        type => 'none',  # Complex in TT2
        name => 'map',
    },
    attr => {
        type => 'custom',
        code => sub {
            my ($base, @args) = @_;
            my $attr = $args[0] // '';
            $attr =~ s/^['"]|['"]$//g;
            return "$base.$attr";
        },
    },

    # XML
    xmlattr => {
        type => 'none',
        name => 'xmlattr',
    },
);

sub new {
    my ($class, %opts) = @_;
    return bless {
        custom_filters => $opts{custom_filters} // {},
    }, $class;
}

sub map_filter {
    my ($self, $name, $args) = @_;

    # Check custom filters first
    if (exists $self->{custom_filters}{$name}) {
        return $self->{custom_filters}{$name};
    }

    # Check built-in mapping
    if (exists $FILTER_MAP{$name}) {
        my $mapping = $FILTER_MAP{$name};

        if ($mapping->{type} eq 'custom') {
            return {
                type => 'custom',
                code => $mapping->{code},
            };
        }

        my $result = {
            type => $mapping->{type},
            name => $mapping->{name},
        };

        # Pass through arguments for vmethods/filters that need them
        if ($args && @$args) {
            $result->{args} = join(', ', @$args);
        }

        return $result;
    }

    # Unknown filter - pass through as-is
    return {
        type => 'filter',
        name => $name,
    };
}

sub register_filter {
    my ($self, $name, $mapping) = @_;
    $self->{custom_filters}{$name} = $mapping;
}

# Get list of all known filters
sub list_filters {
    my ($self) = @_;
    return sort keys %FILTER_MAP;
}

# Check if a filter has a TT2 equivalent
sub has_equivalent {
    my ($self, $name) = @_;
    return exists $FILTER_MAP{$name} && $FILTER_MAP{$name}{type} ne 'none';
}

1;

__END__

=head1 NAME

Jinja2::TT2::Filters - Map Jinja2 filters to TT2 equivalents

=head1 SYNOPSIS

    use Jinja2::TT2::Filters;

    my $filters = Jinja2::TT2::Filters->new();
    my $tt2 = $filters->map_filter('upper', []);
    # Returns: { type => 'vmethod', name => 'upper' }

=head1 DESCRIPTION

Maps Jinja2 filter names to their Template Toolkit 2 equivalents. Handles
vmethods, filters, and custom transformations.

=head1 FILTER MAPPING TABLE

=head2 Direct Equivalents

    Jinja2          TT2 Equivalent
    ------          --------------
    upper           .upper (vmethod)
    lower           .lower (vmethod)
    trim            .trim (vmethod)
    first           .first (vmethod)
    last            .last (vmethod)
    length          .size (vmethod)
    reverse         .reverse (vmethod)
    sort            .sort (vmethod)
    join            .join (vmethod)
    escape/e        | html_entity
    urlencode       | uri

=head2 Requires Plugins

    Jinja2          TT2 Plugin
    ------          ----------
    tojson          Template::Plugin::JSON
    pprint          Template::Plugin::Dumper
    striptags       Template::Plugin::HTML

=head2 No Direct Equivalent

    filesizeformat, urlize, selectattr, rejectattr, groupby, map, xmlattr

These should be implemented as custom vmethods or plugins.

=head1 METHODS

=head2 map_filter($name, \@args)

Returns a hashref describing how to emit the filter in TT2.

=head2 register_filter($name, \%mapping)

Add a custom filter mapping.

=head2 list_filters()

Returns a list of all known filter names.

=head2 has_equivalent($name)

Returns true if the filter has a working TT2 equivalent.

=cut
