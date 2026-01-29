package Jinja2::TT2::Emitter;

use strict;
use warnings;
use v5.20;

use Jinja2::TT2::Filters;

sub new {
    my ($class, %opts) = @_;
    return bless {
        indent_level => 0,
        indent_str   => $opts{indent_str} // '    ',
        filters      => Jinja2::TT2::Filters->new(),
    }, $class;
}

sub emit {
    my ($self, $ast) = @_;

    if ($ast->{type} eq 'ROOT') {
        return join('', map { $self->emit($_) } @{$ast->{body}});
    }

    my $method = '_emit_' . lc($ast->{type});
    if ($self->can($method)) {
        return $self->$method($ast);
    }

    die "Unknown AST node type: $ast->{type}";
}

sub _emit_text {
    my ($self, $node) = @_;
    return $node->{value};
}

sub _emit_comment {
    my ($self, $node) = @_;
    return "[%# $node->{value} %]";
}

sub _emit_output {
    my ($self, $node) = @_;

    my $strip_before = $node->{strip_before} ? '-' : '';
    my $strip_after  = $node->{strip_after}  ? '-' : '';

    my $expr = $self->_emit_expr($node->{expr});
    return "[%$strip_before $expr $strip_after%]";
}

sub _emit_if {
    my ($self, $node) = @_;

    my $strip_before = $node->{strip_before} ? '-' : '';
    my $strip_after  = $node->{strip_after}  ? '-' : '';

    my $condition = $self->_emit_expr($node->{condition});
    my $output = "[%$strip_before IF $condition $strip_after%]";

    for my $child (@{$node->{body}}) {
        $output .= $self->emit($child);
    }

    for my $branch (@{$node->{branches}}) {
        if ($branch->{type} eq 'ELIF') {
            my $elif_cond = $self->_emit_expr($branch->{condition});
            $output .= "[% ELSIF $elif_cond %]";
            for my $child (@{$branch->{body}}) {
                $output .= $self->emit($child);
            }
        } elsif ($branch->{type} eq 'ELSE') {
            $output .= "[% ELSE %]";
            for my $child (@{$branch->{body}}) {
                $output .= $self->emit($child);
            }
        }
    }

    $output .= "[% END %]";
    return $output;
}

sub _emit_for {
    my ($self, $node) = @_;

    my $loop_var = join(', ', @{$node->{loop_vars}});
    my $iterable = $self->_emit_expr($node->{iterable});

    my $output = "[% FOREACH $loop_var IN $iterable %]";

    for my $child (@{$node->{body}}) {
        $output .= $self->emit($child);
    }

    # Handle else clause (TT2 doesn't have for/else, need WRAPPER or conditional)
    if (@{$node->{else_body}}) {
        # TT2 workaround: use IF for empty check
        $output = "[% IF $iterable.size %]" . $output . "[% ELSE %]";
        for my $child (@{$node->{else_body}}) {
            $output .= $self->emit($child);
        }
        $output .= "[% END %]";
    }

    $output .= "[% END %]" unless @{$node->{else_body}};

    return $output;
}

sub _emit_block {
    my ($self, $node) = @_;

    my $output = "[% BLOCK $node->{name} %]";

    for my $child (@{$node->{body}}) {
        $output .= $self->emit($child);
    }

    $output .= "[% END %]";
    return $output;
}

sub _emit_extends {
    my ($self, $node) = @_;

    my $template = $self->_emit_expr($node->{template});
    # Remove quotes for TT2 PROCESS/WRAPPER
    $template =~ s/^['"]|['"]$//g;

    # TT2 doesn't have direct extends; use WRAPPER or PROCESS
    # For now, emit as a comment + PROCESS
    return "[%# EXTENDS: $template - use WRAPPER in TT2 %]\n[% PROCESS $template %]";
}

sub _emit_include {
    my ($self, $node) = @_;

    my $strip_before = $node->{strip_before} ? '-' : '';
    my $strip_after  = $node->{strip_after}  ? '-' : '';

    my $template = $self->_emit_expr($node->{template});
    $template =~ s/^['"]|['"]$//g;

    return "[%$strip_before INCLUDE $template $strip_after%]";
}

sub _emit_import {
    my ($self, $node) = @_;

    my $template = $self->_emit_expr($node->{template});
    $template =~ s/^['"]|['"]$//g;

    # TT2 uses PROCESS for imports; macros become available
    return "[%# IMPORT $template AS $node->{alias} %]\n[% USE $node->{alias} = $template %]";
}

sub _emit_from {
    my ($self, $node) = @_;

    my $template = $self->_emit_expr($node->{template});
    $template =~ s/^['"]|['"]$//g;

    my @imports = map { $_->{name} . ($_->{alias} ne $_->{name} ? " AS $_->{alias}" : '') }
                  @{$node->{imports}};

    return "[%# FROM $template IMPORT " . join(', ', @imports) . " %]";
}

sub _emit_set {
    my ($self, $node) = @_;

    my $names = join(', ', @{$node->{names}});

    if ($node->{value}) {
        # Inline set
        my $value = $self->_emit_expr($node->{value});
        return "[% $names = $value %]";
    } else {
        # Block set - use FILTER to capture content
        my $output = "[% FILTER \$set_$names %]";
        for my $child (@{$node->{body}}) {
            $output .= $self->emit($child);
        }
        $output .= "[% END %][% $names = set_$names %]";
        return $output;
    }
}

sub _emit_macro {
    my ($self, $node) = @_;

    my @args = map {
        my $arg = $_->{name};
        if (defined $_->{default}) {
            $arg .= " = " . $self->_emit_expr($_->{default});
        }
        $arg;
    } @{$node->{args}};

    my $output = "[% MACRO $node->{name}(" . join(', ', @args) . ") BLOCK %]";

    for my $child (@{$node->{body}}) {
        $output .= $self->emit($child);
    }

    $output .= "[% END %]";
    return $output;
}

sub _emit_call {
    my ($self, $node) = @_;

    my $call = $self->_emit_expr($node->{call});

    # TT2 doesn't have direct call blocks; emit as WRAPPER
    my $output = "[%# CALL $call %]\n[% WRAPPER $call %]";

    for my $child (@{$node->{body}}) {
        $output .= $self->emit($child);
    }

    $output .= "[% END %]";
    return $output;
}

sub _emit_filter {
    my ($self, $node) = @_;

    my $filter = $self->_emit_filter_single($node->{filter});

    my $output = "[% FILTER $filter %]";

    for my $child (@{$node->{body}}) {
        $output .= $self->emit($child);
    }

    $output .= "[% END %]";
    return $output;
}

sub _emit_raw {
    my ($self, $node) = @_;
    # TT2 has no raw tag; content is already literal
    # Could use [% RAWPERL %] but that's different
    return $node->{value};
}

sub _emit_with {
    my ($self, $node) = @_;

    # TT2 doesn't have 'with'; simulate with SET in a wrapper
    my $output = "[%# WITH scope %]";

    for my $assign (@{$node->{assignments}}) {
        $output .= "[% SET $assign->{name} = " . $self->_emit_expr($assign->{value}) . " %]";
    }

    for my $child (@{$node->{body}}) {
        $output .= $self->emit($child);
    }

    return $output;
}

sub _emit_autoescape {
    my ($self, $node) = @_;

    # TT2 handles escaping differently; emit as comment
    my $output = "[%# AUTOESCAPE " . $self->_emit_expr($node->{enabled}) . " %]";

    for my $child (@{$node->{body}}) {
        $output .= $self->emit($child);
    }

    $output .= "[%# END AUTOESCAPE %]";
    return $output;
}

# Expression emitters
sub _emit_expr {
    my ($self, $node) = @_;

    return '' unless $node;

    my $type = $node->{type};

    if ($type eq 'NAME') {
        my $name = $node->{value};
        # Map Jinja2 loop variables to TT2
        if ($name eq 'loop') {
            return 'loop';
        }
        return $name;
    }

    if ($type eq 'LITERAL') {
        if ($node->{subtype} eq 'STRING') {
            my $val = $node->{value};
            $val =~ s/'/\\'/g;
            return "'$val'";
        } elsif ($node->{subtype} eq 'BOOL') {
            return $node->{value} ? '1' : '0';
        } elsif ($node->{subtype} eq 'NONE') {
            return 'undef';
        } else {
            return $node->{value};
        }
    }

    if ($type eq 'BINOP') {
        my $left  = $self->_emit_expr($node->{left});
        my $right = $self->_emit_expr($node->{right});
        my $op    = $node->{op};

        # Map operators
        my %op_map = (
            'and'    => 'AND',
            'or'     => 'OR',
            '~'      => '_',  # String concatenation
            'in'     => 'IN',
            'not in' => 'NOT IN',
            '=='     => '==',
            '!='     => '!=',
            '//'     => 'div',  # Integer division
        );

        $op = $op_map{$op} // $op;

        return "($left $op $right)";
    }

    if ($type eq 'UNARYOP') {
        my $operand = $self->_emit_expr($node->{operand});
        my $op      = $node->{op};

        if ($op eq 'not') {
            return "NOT $operand";
        }

        return "$op$operand";
    }

    if ($type eq 'TERNARY') {
        my $true_val  = $self->_emit_expr($node->{true_val});
        my $condition = $self->_emit_expr($node->{condition});
        my $false_val = $node->{false_val} ? $self->_emit_expr($node->{false_val}) : "''";

        return "($condition ? $true_val : $false_val)";
    }

    if ($type eq 'GETATTR') {
        my $expr = $self->_emit_expr($node->{expr});
        my $attr = $node->{attr};

        # Map loop attributes
        if ($expr eq 'loop') {
            my %loop_map = (
                'index'    => 'count',
                'index0'   => 'index',
                'revindex' => 'max - loop.index + 1',
                'first'    => 'first',
                'last'     => 'last',
                'length'   => 'size',
                'cycle'    => 'cycle',
            );
            return 'loop.' . ($loop_map{$attr} // $attr);
        }

        return "$expr.$attr";
    }

    if ($type eq 'GETITEM') {
        my $expr  = $self->_emit_expr($node->{expr});
        my $index = $self->_emit_expr($node->{index});

        return "$expr.\$index" if $index =~ /^[a-zA-Z]/;
        return "$expr.$index";
    }

    if ($type eq 'CALL') {
        my $expr = $self->_emit_expr($node->{expr});
        my @args = map { $self->_emit_expr($_) } @{$node->{args}};

        for my $kwarg (@{$node->{kwargs}}) {
            push @args, "$kwarg->{name} = " . $self->_emit_expr($kwarg->{value});
        }

        # Handle built-in functions
        if ($expr eq 'range') {
            if (@args == 1) {
                return "[0 .. $args[0] - 1]";
            } elsif (@args == 2) {
                return "[$args[0] .. $args[1] - 1]";
            } elsif (@args == 3) {
                # range with step - complex in TT2
                return "[% # range($args[0], $args[1], $args[2]) %]";
            }
        }

        if ($expr eq 'super') {
            return 'content'; # TT2's WRAPPER content
        }

        return "$expr(" . join(', ', @args) . ")";
    }

    if ($type eq 'FILTER') {
        my $base = $self->_emit_expr($node->{expr});
        return $self->_emit_filter_application($base, $node);
    }

    if ($type eq 'LIST') {
        my @elements = map { $self->_emit_expr($_) } @{$node->{elements}};
        return '[' . join(', ', @elements) . ']';
    }

    if ($type eq 'TUPLE') {
        my @elements = map { $self->_emit_expr($_) } @{$node->{elements}};
        return '[' . join(', ', @elements) . ']';  # TT2 uses arrays
    }

    if ($type eq 'DICT') {
        my @pairs = map {
            my $key = $self->_emit_expr($_->{key});
            my $val = $self->_emit_expr($_->{value});
            "$key => $val";
        } @{$node->{pairs}};
        return '{ ' . join(', ', @pairs) . ' }';
    }

    if ($type eq 'NAMED_ARG') {
        my $value = $self->_emit_expr($node->{value});
        return "$node->{name} = $value";
    }

    die "Unknown expression type: $type";
}

sub _emit_filter_application {
    my ($self, $base, $node) = @_;

    my $filter_name = $node->{name};
    my @args = map { $self->_emit_expr($_) } @{$node->{args}};

    # Get the TT2 equivalent
    my $tt2_filter = $self->{filters}->map_filter($filter_name, \@args);

    if ($tt2_filter->{type} eq 'vmethod') {
        if ($tt2_filter->{args}) {
            return "$base.$tt2_filter->{name}($tt2_filter->{args})";
        } else {
            return "$base.$tt2_filter->{name}";
        }
    } elsif ($tt2_filter->{type} eq 'filter') {
        if ($tt2_filter->{args}) {
            return "$base | $tt2_filter->{name}($tt2_filter->{args})";
        } else {
            return "$base | $tt2_filter->{name}";
        }
    } elsif ($tt2_filter->{type} eq 'custom') {
        return $tt2_filter->{code}->($base, @args);
    } else {
        # Passthrough - keep original name
        my $args_str = @args ? '(' . join(', ', @args) . ')' : '';
        return "$base | $filter_name$args_str";
    }
}

sub _emit_filter_single {
    my ($self, $node) = @_;

    if ($node->{type} eq 'FILTER') {
        my $inner = $node->{expr} ? $self->_emit_filter_single($node->{expr}) : '';
        my $filter_name = $node->{name};
        my @args = map { $self->_emit_expr($_) } @{$node->{args}};

        my $args_str = @args ? '(' . join(', ', @args) . ')' : '';
        my $this_filter = "$filter_name$args_str";

        return $inner ? "$inner | $this_filter" : $this_filter;
    } elsif ($node->{type} eq 'NAME') {
        return $node->{value};
    }

    die "Unexpected filter node type: $node->{type}";
}

1;

__END__

=head1 NAME

Jinja2::TT2::Emitter - Emit TT2 code from Jinja2 AST

=head1 DESCRIPTION

Walks the AST produced by the parser and generates equivalent Template Toolkit 2
code.

=cut
