#!/usr/bin/env perl

use strict;
use warnings;
use v5.20;

use Test::More;
use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use Jinja2::TT2::Tokenizer;
use Jinja2::TT2::Parser;

my $tokenizer = Jinja2::TT2::Tokenizer->new();
my $parser = Jinja2::TT2::Parser->new();

sub parse {
    my ($template) = @_;
    my @tokens = $tokenizer->tokenize($template);
    return $parser->parse(\@tokens);
}

subtest 'Plain text' => sub {
    my $ast = parse('Hello World');
    is($ast->{type}, 'ROOT', 'Root node');
    is($ast->{body}[0]{type}, 'TEXT', 'Text node');
    is($ast->{body}[0]{value}, 'Hello World', 'Text value');
};

subtest 'Variable output' => sub {
    my $ast = parse('{{ name }}');
    is($ast->{body}[0]{type}, 'OUTPUT', 'Output node');
    is($ast->{body}[0]{expr}{type}, 'NAME', 'Expression is name');
    is($ast->{body}[0]{expr}{value}, 'name', 'Variable name');
};

subtest 'Attribute access' => sub {
    my $ast = parse('{{ user.name }}');
    my $expr = $ast->{body}[0]{expr};
    is($expr->{type}, 'GETATTR', 'Getattr node');
    is($expr->{attr}, 'name', 'Attribute name');
    is($expr->{expr}{value}, 'user', 'Base name');
};

subtest 'Filter' => sub {
    my $ast = parse('{{ name|upper }}');
    my $expr = $ast->{body}[0]{expr};
    is($expr->{type}, 'FILTER', 'Filter node');
    is($expr->{name}, 'upper', 'Filter name');
    is($expr->{expr}{value}, 'name', 'Filtered expression');
};

subtest 'Filter chain' => sub {
    my $ast = parse('{{ name|lower|trim }}');
    my $expr = $ast->{body}[0]{expr};
    is($expr->{type}, 'FILTER', 'Outer filter');
    is($expr->{name}, 'trim', 'Outer filter name');
    is($expr->{expr}{type}, 'FILTER', 'Inner filter');
    is($expr->{expr}{name}, 'lower', 'Inner filter name');
};

subtest 'Filter with arguments' => sub {
    my $ast = parse('{{ name|default("Guest") }}');
    my $expr = $ast->{body}[0]{expr};
    is($expr->{type}, 'FILTER', 'Filter node');
    is($expr->{name}, 'default', 'Filter name');
    is(scalar @{$expr->{args}}, 1, 'One argument');
};

subtest 'If statement' => sub {
    my $ast = parse('{% if user %}Hello{% endif %}');
    my $if_node = $ast->{body}[0];
    is($if_node->{type}, 'IF', 'If node');
    is($if_node->{condition}{value}, 'user', 'Condition');
    is($if_node->{body}[0]{type}, 'TEXT', 'Body text');
};

subtest 'If-else statement' => sub {
    my $ast = parse('{% if user %}Hi{% else %}Bye{% endif %}');
    my $if_node = $ast->{body}[0];
    is($if_node->{type}, 'IF', 'If node');
    is(scalar @{$if_node->{branches}}, 1, 'One branch');
    is($if_node->{branches}[0]{type}, 'ELSE', 'Else branch');
};

subtest 'If-elif-else statement' => sub {
    my $ast = parse('{% if a %}A{% elif b %}B{% else %}C{% endif %}');
    my $if_node = $ast->{body}[0];
    is(scalar @{$if_node->{branches}}, 2, 'Two branches');
    is($if_node->{branches}[0]{type}, 'ELIF', 'Elif branch');
    is($if_node->{branches}[1]{type}, 'ELSE', 'Else branch');
};

subtest 'For loop' => sub {
    my $ast = parse('{% for x in items %}{{ x }}{% endfor %}');
    my $for_node = $ast->{body}[0];
    is($for_node->{type}, 'FOR', 'For node');
    is($for_node->{loop_vars}[0], 'x', 'Loop variable');
    is($for_node->{iterable}{value}, 'items', 'Iterable');
};

subtest 'For loop with unpacking' => sub {
    my $ast = parse('{% for k, v in items %}{{ k }}{% endfor %}');
    my $for_node = $ast->{body}[0];
    is(scalar @{$for_node->{loop_vars}}, 2, 'Two loop variables');
    is($for_node->{loop_vars}[0], 'k', 'First variable');
    is($for_node->{loop_vars}[1], 'v', 'Second variable');
};

subtest 'Block' => sub {
    my $ast = parse('{% block content %}Hello{% endblock %}');
    my $block = $ast->{body}[0];
    is($block->{type}, 'BLOCK', 'Block node');
    is($block->{name}, 'content', 'Block name');
};

subtest 'Set statement' => sub {
    my $ast = parse('{% set x = 42 %}');
    my $set = $ast->{body}[0];
    is($set->{type}, 'SET', 'Set node');
    is($set->{names}[0], 'x', 'Variable name');
    is($set->{value}{value}, '42', 'Value');
};

subtest 'Include' => sub {
    my $ast = parse('{% include "header.html" %}');
    my $inc = $ast->{body}[0];
    is($inc->{type}, 'INCLUDE', 'Include node');
    is($inc->{template}{value}, 'header.html', 'Template name');
};

subtest 'Comment' => sub {
    my $ast = parse('{# this is a comment #}');
    is($ast->{body}[0]{type}, 'COMMENT', 'Comment node');
    is($ast->{body}[0]{value}, 'this is a comment', 'Comment text');
};

subtest 'Ternary expression' => sub {
    my $ast = parse('{{ x if condition else y }}');
    my $expr = $ast->{body}[0]{expr};
    is($expr->{type}, 'TERNARY', 'Ternary node');
    is($expr->{true_val}{value}, 'x', 'True value');
    is($expr->{condition}{value}, 'condition', 'Condition');
    is($expr->{false_val}{value}, 'y', 'False value');
};

subtest 'Binary operations' => sub {
    my $ast = parse('{{ a + b }}');
    my $expr = $ast->{body}[0]{expr};
    is($expr->{type}, 'BINOP', 'Binary op');
    is($expr->{op}, '+', 'Plus operator');
};

subtest 'Comparison' => sub {
    my $ast = parse('{{ a == b }}');
    my $expr = $ast->{body}[0]{expr};
    is($expr->{type}, 'BINOP', 'Binary op');
    is($expr->{op}, '==', 'Equals operator');
};

subtest 'Logical operators' => sub {
    my $ast = parse('{{ a and b or c }}');
    my $expr = $ast->{body}[0]{expr};
    is($expr->{type}, 'BINOP', 'Binary op');
    is($expr->{op}, 'or', 'Or operator');
};

subtest 'Function call' => sub {
    my $ast = parse('{{ range(10) }}');
    my $expr = $ast->{body}[0]{expr};
    is($expr->{type}, 'CALL', 'Call node');
    is($expr->{expr}{value}, 'range', 'Function name');
};

subtest 'List literal' => sub {
    my $ast = parse('{{ [1, 2, 3] }}');
    my $expr = $ast->{body}[0]{expr};
    is($expr->{type}, 'LIST', 'List node');
    is(scalar @{$expr->{elements}}, 3, 'Three elements');
};

subtest 'Dict literal' => sub {
    my $ast = parse("{{ {'a': 1} }}");
    my $expr = $ast->{body}[0]{expr};
    is($expr->{type}, 'DICT', 'Dict node');
    is(scalar @{$expr->{pairs}}, 1, 'One pair');
};

done_testing();
