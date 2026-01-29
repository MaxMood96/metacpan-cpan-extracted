#!/usr/bin/env perl

use strict;
use warnings;
use v5.20;

use Test::More;
use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use Jinja2::TT2::Tokenizer;

my $tokenizer = Jinja2::TT2::Tokenizer->new();

subtest 'Plain text' => sub {
    my @tokens = $tokenizer->tokenize('Hello World');
    is($tokens[0]{type}, 'TEXT', 'Text token type');
    is($tokens[0]{value}, 'Hello World', 'Text value');
    is($tokens[1]{type}, 'EOF', 'EOF at end');
};

subtest 'Variable' => sub {
    my @tokens = $tokenizer->tokenize('{{ name }}');
    is($tokens[0]{type}, 'VAR_START', 'Variable start');
    is($tokens[1]{type}, 'NAME', 'Name token');
    is($tokens[1]{value}, 'name', 'Name value');
    is($tokens[2]{type}, 'VAR_END', 'Variable end');
};

subtest 'Variable with attribute' => sub {
    my @tokens = $tokenizer->tokenize('{{ user.name }}');
    is($tokens[1]{type}, 'NAME', 'First name');
    is($tokens[1]{value}, 'user', 'User');
    is($tokens[2]{type}, 'DOT', 'Dot');
    is($tokens[3]{type}, 'NAME', 'Second name');
    is($tokens[3]{value}, 'name', 'Name');
};

subtest 'Filter' => sub {
    my @tokens = $tokenizer->tokenize('{{ name|upper }}');
    is($tokens[1]{value}, 'name', 'Variable name');
    is($tokens[2]{type}, 'PIPE', 'Pipe operator');
    is($tokens[3]{value}, 'upper', 'Filter name');
};

subtest 'Statement' => sub {
    my @tokens = $tokenizer->tokenize('{% if user %}');
    is($tokens[0]{type}, 'STMT_START', 'Statement start');
    is($tokens[1]{value}, 'if', 'If keyword');
    is($tokens[2]{value}, 'user', 'Condition');
    is($tokens[3]{type}, 'STMT_END', 'Statement end');
};

subtest 'For loop' => sub {
    my @tokens = $tokenizer->tokenize('{% for x in items %}');
    is($tokens[1]{value}, 'for', 'For keyword');
    is($tokens[2]{value}, 'x', 'Loop variable');
    is($tokens[3]{value}, 'in', 'In keyword');
    is($tokens[4]{value}, 'items', 'Iterable');
};

subtest 'Comment' => sub {
    my @tokens = $tokenizer->tokenize('{# this is a comment #}');
    is($tokens[0]{type}, 'COMMENT', 'Comment token');
    is($tokens[0]{value}, 'this is a comment', 'Comment value');
};

subtest 'Whitespace control' => sub {
    my @tokens = $tokenizer->tokenize('{{- name -}}');
    ok($tokens[0]{strip_before}, 'Strip before');
    ok($tokens[2]{strip_after}, 'Strip after');
};

subtest 'String literals' => sub {
    my @tokens = $tokenizer->tokenize('{{ "hello" }}');
    is($tokens[1]{type}, 'STRING', 'String token');
    is($tokens[1]{value}, '"hello"', 'String value');
};

subtest 'Number literals' => sub {
    my @tokens = $tokenizer->tokenize('{{ 42 }}');
    is($tokens[1]{type}, 'NUMBER', 'Number token');
    is($tokens[1]{value}, '42', 'Number value');
};

subtest 'Mixed content' => sub {
    my @tokens = $tokenizer->tokenize('Hello {{ name }}, welcome!');
    is($tokens[0]{type}, 'TEXT', 'Text before');
    is($tokens[0]{value}, 'Hello ', 'Text value');
    is($tokens[1]{type}, 'VAR_START', 'Variable start');
    is($tokens[4]{type}, 'TEXT', 'Text after');
    is($tokens[4]{value}, ', welcome!', 'Text after value');
};

subtest 'Operators' => sub {
    my @tokens = $tokenizer->tokenize('{{ a == b }}');
    is($tokens[2]{type}, 'OPERATOR', 'Operator token');
    is($tokens[2]{value}, '==', 'Equals operator');
};

done_testing();
