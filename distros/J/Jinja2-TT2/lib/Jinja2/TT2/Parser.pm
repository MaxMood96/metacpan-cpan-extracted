package Jinja2::TT2::Parser;

use strict;
use warnings;
use v5.20;

# AST Node types
use constant {
    NODE_ROOT       => 'ROOT',
    NODE_TEXT       => 'TEXT',
    NODE_OUTPUT     => 'OUTPUT',
    NODE_COMMENT    => 'COMMENT',
    NODE_IF         => 'IF',
    NODE_ELIF       => 'ELIF',
    NODE_ELSE       => 'ELSE',
    NODE_FOR        => 'FOR',
    NODE_BLOCK      => 'BLOCK',
    NODE_EXTENDS    => 'EXTENDS',
    NODE_INCLUDE    => 'INCLUDE',
    NODE_IMPORT     => 'IMPORT',
    NODE_FROM       => 'FROM',
    NODE_SET        => 'SET',
    NODE_MACRO      => 'MACRO',
    NODE_CALL       => 'CALL',
    NODE_FILTER     => 'FILTER',
    NODE_RAW        => 'RAW',
    NODE_WITH       => 'WITH',
    NODE_AUTOESCAPE => 'AUTOESCAPE',
    NODE_EXPR       => 'EXPR',
};

sub new {
    my ($class, %opts) = @_;
    return bless {
        tokens => [],
        pos    => 0,
    }, $class;
}

sub parse {
    my ($self, $tokens) = @_;

    $self->{tokens} = $tokens;
    $self->{pos} = 0;

    my @body;
    while (!$self->_at_end()) {
        my $node = $self->_parse_node();
        push @body, $node if $node;
    }

    return { type => NODE_ROOT, body => \@body };
}

sub _parse_node {
    my ($self) = @_;

    my $token = $self->_current();
    return undef unless $token;

    if ($token->{type} eq 'TEXT') {
        $self->_advance();
        return { type => NODE_TEXT, value => $token->{value} };
    }

    if ($token->{type} eq 'COMMENT') {
        $self->_advance();
        return { type => NODE_COMMENT, value => $token->{value} };
    }

    if ($token->{type} eq 'VAR_START') {
        return $self->_parse_output();
    }

    if ($token->{type} eq 'STMT_START') {
        return $self->_parse_statement();
    }

    # Skip unknown tokens
    $self->_advance();
    return undef;
}

sub _parse_output {
    my ($self) = @_;

    my $start = $self->_expect('VAR_START');
    my $expr = $self->_parse_expression();
    my $end = $self->_expect('VAR_END');

    return {
        type         => NODE_OUTPUT,
        expr         => $expr,
        strip_before => $start->{strip_before},
        strip_after  => $end->{strip_after},
    };
}

sub _parse_statement {
    my ($self) = @_;

    my $start = $self->_expect('STMT_START');
    my $strip_before = $start->{strip_before};

    my $keyword = $self->_current();

    unless ($keyword && $keyword->{type} eq 'NAME') {
        die "Expected statement keyword at position " . ($keyword->{pos} // 'unknown');
    }

    my $kw = $keyword->{value};

    if ($kw eq 'if') {
        return $self->_parse_if($strip_before);
    } elsif ($kw eq 'for') {
        return $self->_parse_for($strip_before);
    } elsif ($kw eq 'block') {
        return $self->_parse_block($strip_before);
    } elsif ($kw eq 'extends') {
        return $self->_parse_extends($strip_before);
    } elsif ($kw eq 'include') {
        return $self->_parse_include($strip_before);
    } elsif ($kw eq 'import') {
        return $self->_parse_import($strip_before);
    } elsif ($kw eq 'from') {
        return $self->_parse_from($strip_before);
    } elsif ($kw eq 'set') {
        return $self->_parse_set($strip_before);
    } elsif ($kw eq 'macro') {
        return $self->_parse_macro($strip_before);
    } elsif ($kw eq 'call') {
        return $self->_parse_call_block($strip_before);
    } elsif ($kw eq 'filter') {
        return $self->_parse_filter_block($strip_before);
    } elsif ($kw eq 'raw') {
        return $self->_parse_raw($strip_before);
    } elsif ($kw eq 'with') {
        return $self->_parse_with($strip_before);
    } elsif ($kw eq 'autoescape') {
        return $self->_parse_autoescape($strip_before);
    } elsif ($kw =~ /^(endif|endfor|endblock|endmacro|endcall|endfilter|endraw|endwith|endautoescape|elif|else)$/) {
        # These are handled by their parent parsers
        die "Unexpected '$kw' without matching opening tag";
    } else {
        die "Unknown statement keyword '$kw'";
    }
}

sub _parse_if {
    my ($self, $strip_before) = @_;

    $self->_advance(); # consume 'if'
    my $condition = $self->_parse_expression();
    my $end = $self->_expect('STMT_END');

    my @body;
    my @branches;  # For elif/else

    while (!$self->_at_end()) {
        # Check for elif, else, endif
        if ($self->_is_stmt_keyword('elif')) {
            my $elif_start = $self->_expect('STMT_START');
            $self->_advance(); # consume 'elif'
            my $elif_cond = $self->_parse_expression();
            $self->_expect('STMT_END');

            push @branches, {
                type      => NODE_ELIF,
                condition => $elif_cond,
                body      => [],
            };
            next;
        }

        if ($self->_is_stmt_keyword('else')) {
            my $else_start = $self->_expect('STMT_START');
            $self->_advance(); # consume 'else'
            $self->_expect('STMT_END');

            push @branches, {
                type => NODE_ELSE,
                body => [],
            };
            next;
        }

        if ($self->_is_stmt_keyword('endif')) {
            my $endif_start = $self->_expect('STMT_START');
            $self->_advance(); # consume 'endif'
            my $endif_end = $self->_expect('STMT_END');
            last;
        }

        # Parse body content
        my $node = $self->_parse_node();
        if ($node) {
            if (@branches) {
                push @{$branches[-1]{body}}, $node;
            } else {
                push @body, $node;
            }
        }
    }

    return {
        type         => NODE_IF,
        condition    => $condition,
        body         => \@body,
        branches     => \@branches,
        strip_before => $strip_before,
        strip_after  => $end->{strip_after},
    };
}

sub _parse_for {
    my ($self, $strip_before) = @_;

    $self->_advance(); # consume 'for'

    # Parse loop variable(s)
    my @loop_vars;
    push @loop_vars, $self->_expect('NAME')->{value};

    while ($self->_check('COMMA')) {
        $self->_advance();
        push @loop_vars, $self->_expect('NAME')->{value};
    }

    # Expect 'in' (tokenized as OPERATOR)
    my $in_token = $self->_current();
    if (!$in_token || ($in_token->{type} ne 'OPERATOR' && $in_token->{type} ne 'NAME') || $in_token->{value} ne 'in') {
        die "Expected 'in' in for loop, got " . ($in_token->{type} // 'EOF') . " '$in_token->{value}'";
    }
    $self->_advance();

    # Parse iterable expression
    my $iterable = $self->_parse_expression();

    # Check for optional 'if' filter
    my $filter_cond;
    if ($self->_check('NAME') && $self->_current()->{value} eq 'if') {
        $self->_advance();
        $filter_cond = $self->_parse_expression();
    }

    # Check for 'recursive'
    my $recursive = 0;
    if ($self->_check('NAME') && $self->_current()->{value} eq 'recursive') {
        $self->_advance();
        $recursive = 1;
    }

    my $end = $self->_expect('STMT_END');

    my @body;
    my @else_body;
    my $in_else = 0;

    while (!$self->_at_end()) {
        if ($self->_is_stmt_keyword('else')) {
            $self->_expect('STMT_START');
            $self->_advance(); # consume 'else'
            $self->_expect('STMT_END');
            $in_else = 1;
            next;
        }

        if ($self->_is_stmt_keyword('endfor')) {
            $self->_expect('STMT_START');
            $self->_advance(); # consume 'endfor'
            $self->_expect('STMT_END');
            last;
        }

        my $node = $self->_parse_node();
        if ($node) {
            if ($in_else) {
                push @else_body, $node;
            } else {
                push @body, $node;
            }
        }
    }

    return {
        type         => NODE_FOR,
        loop_vars    => \@loop_vars,
        iterable     => $iterable,
        filter       => $filter_cond,
        recursive    => $recursive,
        body         => \@body,
        else_body    => \@else_body,
        strip_before => $strip_before,
    };
}

sub _parse_block {
    my ($self, $strip_before) = @_;

    $self->_advance(); # consume 'block'
    my $name = $self->_expect('NAME')->{value};

    # Check for 'scoped'
    my $scoped = 0;
    if ($self->_check('NAME') && $self->_current()->{value} eq 'scoped') {
        $self->_advance();
        $scoped = 1;
    }

    $self->_expect('STMT_END');

    my @body;
    while (!$self->_at_end()) {
        if ($self->_is_stmt_keyword('endblock')) {
            $self->_expect('STMT_START');
            $self->_advance(); # consume 'endblock'
            # Optional block name after endblock
            if ($self->_check('NAME')) {
                $self->_advance();
            }
            $self->_expect('STMT_END');
            last;
        }

        my $node = $self->_parse_node();
        push @body, $node if $node;
    }

    return {
        type         => NODE_BLOCK,
        name         => $name,
        scoped       => $scoped,
        body         => \@body,
        strip_before => $strip_before,
    };
}

sub _parse_extends {
    my ($self, $strip_before) = @_;

    $self->_advance(); # consume 'extends'
    my $template = $self->_parse_expression();
    my $end = $self->_expect('STMT_END');

    return {
        type         => NODE_EXTENDS,
        template     => $template,
        strip_before => $strip_before,
        strip_after  => $end->{strip_after},
    };
}

sub _parse_include {
    my ($self, $strip_before) = @_;

    $self->_advance(); # consume 'include'
    my $template = $self->_parse_expression();

    # Check for 'ignore missing'
    my $ignore_missing = 0;
    if ($self->_check('NAME') && $self->_current()->{value} eq 'ignore') {
        $self->_advance();
        if ($self->_check('NAME') && $self->_current()->{value} eq 'missing') {
            $self->_advance();
            $ignore_missing = 1;
        }
    }

    # Check for 'with context' or 'without context'
    my $with_context = 1; # default
    if ($self->_check('NAME')) {
        my $ctx = $self->_current()->{value};
        if ($ctx eq 'with' || $ctx eq 'without') {
            $self->_advance();
            if ($self->_check('NAME') && $self->_current()->{value} eq 'context') {
                $self->_advance();
                $with_context = ($ctx eq 'with') ? 1 : 0;
            }
        }
    }

    my $end = $self->_expect('STMT_END');

    return {
        type           => NODE_INCLUDE,
        template       => $template,
        ignore_missing => $ignore_missing,
        with_context   => $with_context,
        strip_before   => $strip_before,
        strip_after    => $end->{strip_after},
    };
}

sub _parse_import {
    my ($self, $strip_before) = @_;

    $self->_advance(); # consume 'import'
    my $template = $self->_parse_expression();

    # Expect 'as'
    $self->_expect_keyword('as');
    my $alias = $self->_expect('NAME')->{value};

    # Check for 'with context' or 'without context'
    my $with_context = 0; # default for import
    if ($self->_check('NAME')) {
        my $ctx = $self->_current()->{value};
        if ($ctx eq 'with' || $ctx eq 'without') {
            $self->_advance();
            if ($self->_check('NAME') && $self->_current()->{value} eq 'context') {
                $self->_advance();
                $with_context = ($ctx eq 'with') ? 1 : 0;
            }
        }
    }

    my $end = $self->_expect('STMT_END');

    return {
        type         => NODE_IMPORT,
        template     => $template,
        alias        => $alias,
        with_context => $with_context,
        strip_before => $strip_before,
        strip_after  => $end->{strip_after},
    };
}

sub _parse_from {
    my ($self, $strip_before) = @_;

    $self->_advance(); # consume 'from'
    my $template = $self->_parse_expression();

    # Expect 'import'
    $self->_expect_keyword('import');

    # Parse imported names
    my @imports;
    do {
        my $name = $self->_expect('NAME')->{value};
        my $alias = $name;
        if ($self->_check('NAME') && $self->_current()->{value} eq 'as') {
            $self->_advance();
            $alias = $self->_expect('NAME')->{value};
        }
        push @imports, { name => $name, alias => $alias };
    } while ($self->_check('COMMA') && $self->_advance());

    # Check for 'with context' or 'without context'
    my $with_context = 0;
    if ($self->_check('NAME')) {
        my $ctx = $self->_current()->{value};
        if ($ctx eq 'with' || $ctx eq 'without') {
            $self->_advance();
            if ($self->_check('NAME') && $self->_current()->{value} eq 'context') {
                $self->_advance();
                $with_context = ($ctx eq 'with') ? 1 : 0;
            }
        }
    }

    my $end = $self->_expect('STMT_END');

    return {
        type         => NODE_FROM,
        template     => $template,
        imports      => \@imports,
        with_context => $with_context,
        strip_before => $strip_before,
        strip_after  => $end->{strip_after},
    };
}

sub _parse_set {
    my ($self, $strip_before) = @_;

    $self->_advance(); # consume 'set'

    # Parse variable name(s)
    my @names;
    push @names, $self->_expect('NAME')->{value};

    while ($self->_check('COMMA')) {
        $self->_advance();
        push @names, $self->_expect('NAME')->{value};
    }

    # Check if it's a block set or inline set
    if ($self->_check('ASSIGN')) {
        $self->_advance();
        my $value = $self->_parse_expression();
        my $end = $self->_expect('STMT_END');

        return {
            type         => NODE_SET,
            names        => \@names,
            value        => $value,
            strip_before => $strip_before,
            strip_after  => $end->{strip_after},
        };
    } else {
        # Block set
        my $end = $self->_expect('STMT_END');

        my @body;
        while (!$self->_at_end()) {
            if ($self->_is_stmt_keyword('endset')) {
                $self->_expect('STMT_START');
                $self->_advance(); # consume 'endset'
                $self->_expect('STMT_END');
                last;
            }

            my $node = $self->_parse_node();
            push @body, $node if $node;
        }

        return {
            type         => NODE_SET,
            names        => \@names,
            body         => \@body,
            strip_before => $strip_before,
        };
    }
}

sub _parse_macro {
    my ($self, $strip_before) = @_;

    $self->_advance(); # consume 'macro'
    my $name = $self->_expect('NAME')->{value};

    # Parse arguments
    $self->_expect('LPAREN');
    my @args;
    unless ($self->_check('RPAREN')) {
        do {
            my $arg_name = $self->_expect('NAME')->{value};
            my $default;
            if ($self->_check('ASSIGN')) {
                $self->_advance();
                $default = $self->_parse_expression();
            }
            push @args, { name => $arg_name, default => $default };
        } while ($self->_check('COMMA') && $self->_advance());
    }
    $self->_expect('RPAREN');
    $self->_expect('STMT_END');

    my @body;
    while (!$self->_at_end()) {
        if ($self->_is_stmt_keyword('endmacro')) {
            $self->_expect('STMT_START');
            $self->_advance(); # consume 'endmacro'
            $self->_expect('STMT_END');
            last;
        }

        my $node = $self->_parse_node();
        push @body, $node if $node;
    }

    return {
        type         => NODE_MACRO,
        name         => $name,
        args         => \@args,
        body         => \@body,
        strip_before => $strip_before,
    };
}

sub _parse_call_block {
    my ($self, $strip_before) = @_;

    $self->_advance(); # consume 'call'

    # Optional arguments
    my @args;
    if ($self->_check('LPAREN')) {
        $self->_advance();
        unless ($self->_check('RPAREN')) {
            do {
                push @args, $self->_expect('NAME')->{value};
            } while ($self->_check('COMMA') && $self->_advance());
        }
        $self->_expect('RPAREN');
    }

    # Parse the macro call
    my $call = $self->_parse_expression();
    $self->_expect('STMT_END');

    my @body;
    while (!$self->_at_end()) {
        if ($self->_is_stmt_keyword('endcall')) {
            $self->_expect('STMT_START');
            $self->_advance(); # consume 'endcall'
            $self->_expect('STMT_END');
            last;
        }

        my $node = $self->_parse_node();
        push @body, $node if $node;
    }

    return {
        type         => NODE_CALL,
        args         => \@args,
        call         => $call,
        body         => \@body,
        strip_before => $strip_before,
    };
}

sub _parse_filter_block {
    my ($self, $strip_before) = @_;

    $self->_advance(); # consume 'filter'
    my $filter = $self->_parse_filter_chain();
    $self->_expect('STMT_END');

    my @body;
    while (!$self->_at_end()) {
        if ($self->_is_stmt_keyword('endfilter')) {
            $self->_expect('STMT_START');
            $self->_advance(); # consume 'endfilter'
            $self->_expect('STMT_END');
            last;
        }

        my $node = $self->_parse_node();
        push @body, $node if $node;
    }

    return {
        type         => NODE_FILTER,
        filter       => $filter,
        body         => \@body,
        strip_before => $strip_before,
    };
}

sub _parse_raw {
    my ($self, $strip_before) = @_;

    $self->_advance(); # consume 'raw'
    $self->_expect('STMT_END');

    # Collect everything until {% endraw %}
    my $raw_text = '';

    while (!$self->_at_end()) {
        if ($self->_is_stmt_keyword('endraw')) {
            $self->_expect('STMT_START');
            $self->_advance(); # consume 'endraw'
            $self->_expect('STMT_END');
            last;
        }

        my $token = $self->_current();
        $raw_text .= $token->{value} // '';
        $self->_advance();
    }

    return {
        type         => NODE_RAW,
        value        => $raw_text,
        strip_before => $strip_before,
    };
}

sub _parse_with {
    my ($self, $strip_before) = @_;

    $self->_advance(); # consume 'with'

    # Parse variable assignments
    my @assignments;
    unless ($self->_check('STMT_END')) {
        do {
            my $name = $self->_expect('NAME')->{value};
            $self->_expect('ASSIGN');
            my $value = $self->_parse_expression();
            push @assignments, { name => $name, value => $value };
        } while ($self->_check('COMMA') && $self->_advance());
    }

    $self->_expect('STMT_END');

    my @body;
    while (!$self->_at_end()) {
        if ($self->_is_stmt_keyword('endwith')) {
            $self->_expect('STMT_START');
            $self->_advance(); # consume 'endwith'
            $self->_expect('STMT_END');
            last;
        }

        my $node = $self->_parse_node();
        push @body, $node if $node;
    }

    return {
        type         => NODE_WITH,
        assignments  => \@assignments,
        body         => \@body,
        strip_before => $strip_before,
    };
}

sub _parse_autoescape {
    my ($self, $strip_before) = @_;

    $self->_advance(); # consume 'autoescape'
    my $enabled = $self->_parse_expression();
    $self->_expect('STMT_END');

    my @body;
    while (!$self->_at_end()) {
        if ($self->_is_stmt_keyword('endautoescape')) {
            $self->_expect('STMT_START');
            $self->_advance(); # consume 'endautoescape'
            $self->_expect('STMT_END');
            last;
        }

        my $node = $self->_parse_node();
        push @body, $node if $node;
    }

    return {
        type         => NODE_AUTOESCAPE,
        enabled      => $enabled,
        body         => \@body,
        strip_before => $strip_before,
    };
}

# Expression parsing with precedence
sub _parse_expression {
    my ($self) = @_;
    return $self->_parse_ternary();
}

sub _parse_ternary {
    my ($self) = @_;

    my $expr = $self->_parse_or();

    # Check for ternary: expr if condition else other
    if ($self->_check('NAME') && $self->_current()->{value} eq 'if') {
        $self->_advance();
        my $condition = $self->_parse_or();

        if ($self->_check('NAME') && $self->_current()->{value} eq 'else') {
            $self->_advance();
            my $else_expr = $self->_parse_ternary();
            return {
                type      => 'TERNARY',
                true_val  => $expr,
                condition => $condition,
                false_val => $else_expr,
            };
        } else {
            # Short form: value if condition (no else)
            return {
                type      => 'TERNARY',
                true_val  => $expr,
                condition => $condition,
                false_val => undef,
            };
        }
    }

    return $expr;
}

sub _parse_or {
    my ($self) = @_;

    my $left = $self->_parse_and();

    while ($self->_check('OPERATOR') && $self->_current()->{value} eq 'or') {
        $self->_advance();
        my $right = $self->_parse_and();
        $left = { type => 'BINOP', op => 'or', left => $left, right => $right };
    }

    return $left;
}

sub _parse_and {
    my ($self) = @_;

    my $left = $self->_parse_not();

    while ($self->_check('OPERATOR') && $self->_current()->{value} eq 'and') {
        $self->_advance();
        my $right = $self->_parse_not();
        $left = { type => 'BINOP', op => 'and', left => $left, right => $right };
    }

    return $left;
}

sub _parse_not {
    my ($self) = @_;

    if ($self->_check('OPERATOR') && $self->_current()->{value} eq 'not') {
        $self->_advance();
        my $operand = $self->_parse_not();
        return { type => 'UNARYOP', op => 'not', operand => $operand };
    }

    return $self->_parse_comparison();
}

sub _parse_comparison {
    my ($self) = @_;

    my $left = $self->_parse_additive();

    while ($self->_check('OPERATOR')) {
        my $op = $self->_current()->{value};
        if ($op =~ /^(==|!=|<|>|<=|>=|in|is)$/) {
            $self->_advance();

            # Handle 'is not' and 'not in'
            if ($op eq 'is' && $self->_check('OPERATOR') && $self->_current()->{value} eq 'not') {
                $self->_advance();
                $op = 'is not';
            } elsif ($op eq 'not' && $self->_check('OPERATOR') && $self->_current()->{value} eq 'in') {
                $self->_advance();
                $op = 'not in';
            }

            my $right = $self->_parse_additive();
            $left = { type => 'BINOP', op => $op, left => $left, right => $right };
        } else {
            last;
        }
    }

    return $left;
}

sub _parse_additive {
    my ($self) = @_;

    my $left = $self->_parse_multiplicative();

    while ($self->_check('OPERATOR') || $self->_check('TILDE')) {
        my $op = $self->_current()->{value};
        if ($op =~ /^[+\-~]$/) {
            $self->_advance();
            my $right = $self->_parse_multiplicative();
            $left = { type => 'BINOP', op => $op, left => $left, right => $right };
        } else {
            last;
        }
    }

    return $left;
}

sub _parse_multiplicative {
    my ($self) = @_;

    my $left = $self->_parse_unary();

    while ($self->_check('OPERATOR')) {
        my $op = $self->_current()->{value};
        if ($op =~ /^[*\/%]$/ || $op eq '//' || $op eq '**') {
            $self->_advance();
            my $right = $self->_parse_unary();
            $left = { type => 'BINOP', op => $op, left => $left, right => $right };
        } else {
            last;
        }
    }

    return $left;
}

sub _parse_unary {
    my ($self) = @_;

    if ($self->_check('OPERATOR') && $self->_current()->{value} =~ /^[+\-]$/) {
        my $op = $self->_current()->{value};
        $self->_advance();
        my $operand = $self->_parse_unary();
        return { type => 'UNARYOP', op => $op, operand => $operand };
    }

    return $self->_parse_filter_chain();
}

sub _parse_filter_chain {
    my ($self) = @_;

    my $expr = $self->_parse_postfix();

    while ($self->_check('PIPE')) {
        $self->_advance();
        my $filter_name = $self->_expect('NAME')->{value};
        my @args;

        if ($self->_check('LPAREN')) {
            $self->_advance();
            unless ($self->_check('RPAREN')) {
                do {
                    # Named argument?
                    if ($self->_check('NAME') && $self->_peek() && $self->_peek()->{type} eq 'ASSIGN') {
                        my $name = $self->_expect('NAME')->{value};
                        $self->_advance(); # consume =
                        my $value = $self->_parse_expression();
                        push @args, { type => 'NAMED_ARG', name => $name, value => $value };
                    } else {
                        push @args, $self->_parse_expression();
                    }
                } while ($self->_check('COMMA') && $self->_advance());
            }
            $self->_expect('RPAREN');
        }

        $expr = { type => 'FILTER', name => $filter_name, expr => $expr, args => \@args };
    }

    return $expr;
}

sub _parse_postfix {
    my ($self) = @_;

    my $expr = $self->_parse_primary();

    while (1) {
        if ($self->_check('DOT')) {
            $self->_advance();
            my $attr = $self->_expect('NAME')->{value};
            $expr = { type => 'GETATTR', expr => $expr, attr => $attr };
        } elsif ($self->_check('LBRACKET')) {
            $self->_advance();
            my $index = $self->_parse_expression();
            $self->_expect('RBRACKET');
            $expr = { type => 'GETITEM', expr => $expr, index => $index };
        } elsif ($self->_check('LPAREN')) {
            $self->_advance();
            my @args;
            my @kwargs;
            unless ($self->_check('RPAREN')) {
                do {
                    # Named argument?
                    if ($self->_check('NAME') && $self->_peek() && $self->_peek()->{type} eq 'ASSIGN') {
                        my $name = $self->_expect('NAME')->{value};
                        $self->_advance(); # consume =
                        my $value = $self->_parse_expression();
                        push @kwargs, { name => $name, value => $value };
                    } else {
                        push @args, $self->_parse_expression();
                    }
                } while ($self->_check('COMMA') && $self->_advance());
            }
            $self->_expect('RPAREN');
            $expr = { type => 'CALL', expr => $expr, args => \@args, kwargs => \@kwargs };
        } else {
            last;
        }
    }

    return $expr;
}

sub _parse_primary {
    my ($self) = @_;

    my $token = $self->_current();

    # Name/identifier
    if ($token->{type} eq 'NAME') {
        my $name = $token->{value};
        $self->_advance();

        # Handle boolean/none literals
        if ($name =~ /^(true|True)$/) {
            return { type => 'LITERAL', value => 1, subtype => 'BOOL' };
        } elsif ($name =~ /^(false|False)$/) {
            return { type => 'LITERAL', value => 0, subtype => 'BOOL' };
        } elsif ($name =~ /^(none|None)$/) {
            return { type => 'LITERAL', value => undef, subtype => 'NONE' };
        }

        return { type => 'NAME', value => $name };
    }

    # Number
    if ($token->{type} eq 'NUMBER') {
        $self->_advance();
        my $val = $token->{value};
        $val =~ s/_//g; # Remove underscores
        return { type => 'LITERAL', value => $val, subtype => 'NUMBER' };
    }

    # String
    if ($token->{type} eq 'STRING') {
        $self->_advance();
        my $val = $token->{value};
        # Remove quotes and handle escapes
        $val =~ s/^['"]|['"]$//g;
        $val =~ s/\\(['"])/$1/g;
        $val =~ s/\\n/\n/g;
        $val =~ s/\\t/\t/g;
        $val =~ s/\\\\/\\/g;
        return { type => 'LITERAL', value => $val, subtype => 'STRING' };
    }

    # Parenthesized expression or tuple
    if ($token->{type} eq 'LPAREN') {
        $self->_advance();
        if ($self->_check('RPAREN')) {
            $self->_advance();
            return { type => 'TUPLE', elements => [] };
        }

        my $expr = $self->_parse_expression();

        if ($self->_check('COMMA')) {
            # It's a tuple
            my @elements = ($expr);
            while ($self->_check('COMMA')) {
                $self->_advance();
                last if $self->_check('RPAREN');
                push @elements, $self->_parse_expression();
            }
            $self->_expect('RPAREN');
            return { type => 'TUPLE', elements => \@elements };
        }

        $self->_expect('RPAREN');
        return $expr;
    }

    # List
    if ($token->{type} eq 'LBRACKET') {
        $self->_advance();
        my @elements;
        unless ($self->_check('RBRACKET')) {
            do {
                push @elements, $self->_parse_expression();
            } while ($self->_check('COMMA') && $self->_advance());
        }
        $self->_expect('RBRACKET');
        return { type => 'LIST', elements => \@elements };
    }

    # Dict
    if ($token->{type} eq 'LBRACE') {
        $self->_advance();
        my @pairs;
        unless ($self->_check('RBRACE')) {
            do {
                my $key = $self->_parse_expression();
                $self->_expect('COLON');
                my $val = $self->_parse_expression();
                push @pairs, { key => $key, value => $val };
            } while ($self->_check('COMMA') && $self->_advance());
        }
        $self->_expect('RBRACE');
        return { type => 'DICT', pairs => \@pairs };
    }

    die "Unexpected token: " . ($token->{type} // 'undef') . " at position " . ($token->{pos} // 'unknown');
}

# Helper methods
sub _current {
    my ($self) = @_;
    return $self->{tokens}[$self->{pos}];
}

sub _peek {
    my ($self) = @_;
    return $self->{tokens}[$self->{pos} + 1];
}

sub _advance {
    my ($self) = @_;
    my $token = $self->{tokens}[$self->{pos}];
    $self->{pos}++ if $self->{pos} < @{$self->{tokens}};
    return $token;
}

sub _check {
    my ($self, $type) = @_;
    my $token = $self->_current();
    return $token && $token->{type} eq $type;
}

sub _expect {
    my ($self, $type) = @_;
    my $token = $self->_current();
    if (!$token || $token->{type} ne $type) {
        die "Expected $type but got " . ($token->{type} // 'EOF') .
            " at position " . ($token->{pos} // 'unknown');
    }
    return $self->_advance();
}

sub _expect_keyword {
    my ($self, $keyword) = @_;
    my $token = $self->_current();
    if (!$token || $token->{type} ne 'NAME' || $token->{value} ne $keyword) {
        die "Expected keyword '$keyword' but got " .
            ($token->{value} // $token->{type} // 'EOF');
    }
    return $self->_advance();
}

sub _at_end {
    my ($self) = @_;
    my $token = $self->_current();
    return !$token || $token->{type} eq 'EOF';
}

sub _is_stmt_keyword {
    my ($self, $keyword) = @_;

    my $token = $self->_current();
    return 0 unless $token && $token->{type} eq 'STMT_START';

    my $next = $self->{tokens}[$self->{pos} + 1];
    return $next && $next->{type} eq 'NAME' && $next->{value} eq $keyword;
}

1;

__END__

=head1 NAME

Jinja2::TT2::Parser - Parse Jinja2 token stream into AST

=head1 DESCRIPTION

Parses the token stream from the tokenizer into an Abstract Syntax Tree (AST)
that can be processed by the emitter.

=cut
