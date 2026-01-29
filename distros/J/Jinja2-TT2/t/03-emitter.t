#!/usr/bin/env perl

use strict;
use warnings;
use v5.20;

use Test::More;
use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use Jinja2::TT2;

my $transpiler = Jinja2::TT2->new();

sub transpile {
    return $transpiler->transpile(shift);
}

subtest 'Plain text passthrough' => sub {
    is(transpile('Hello World'), 'Hello World', 'Plain text unchanged');
};

subtest 'Variable' => sub {
    is(transpile('{{ name }}'), '[% name %]', 'Simple variable');
    is(transpile('{{ user.name }}'), '[% user.name %]', 'Attribute access');
    is(transpile('{{ items[0] }}'), '[% items.0 %]', 'Index access');
};

subtest 'Filters' => sub {
    is(transpile('{{ name|upper }}'), '[% name.upper %]', 'Upper filter');
    is(transpile('{{ name|lower }}'), '[% name.lower %]', 'Lower filter');
    is(transpile('{{ name|trim }}'), '[% name.trim %]', 'Trim filter');
    is(transpile('{{ items|first }}'), '[% items.first %]', 'First filter');
    is(transpile('{{ items|last }}'), '[% items.last %]', 'Last filter');
    is(transpile('{{ items|length }}'), '[% items.size %]', 'Length filter');
    is(transpile('{{ items|join(",") }}'), '[% items.join(\',\') %]', 'Join filter');
};

subtest 'Filter chain' => sub {
    is(transpile('{{ name|lower|trim }}'), '[% name.lower.trim %]', 'Chained filters');
};

subtest 'Comments' => sub {
    is(transpile('{# comment #}'), '[%# comment %]', 'Comment');
};

subtest 'If statement' => sub {
    is(
        transpile('{% if user %}Hello{% endif %}'),
        '[% IF user %]Hello[% END %]',
        'Simple if'
    );
};

subtest 'If-else statement' => sub {
    is(
        transpile('{% if user %}Hi{% else %}Bye{% endif %}'),
        '[% IF user %]Hi[% ELSE %]Bye[% END %]',
        'If-else'
    );
};

subtest 'If-elif-else' => sub {
    my $result = transpile('{% if a %}A{% elif b %}B{% else %}C{% endif %}');
    like($result, qr/\[% IF a %\]A/, 'If part');
    like($result, qr/\[% ELSIF b %\]B/, 'Elif becomes ELSIF');
    like($result, qr/\[% ELSE %\]C/, 'Else part');
    like($result, qr/\[% END %\]/, 'End tag');
};

subtest 'For loop' => sub {
    is(
        transpile('{% for x in items %}{{ x }}{% endfor %}'),
        '[% FOREACH x IN items %][% x %][% END %]',
        'For loop'
    );
};

subtest 'For with unpacking' => sub {
    like(
        transpile('{% for k, v in items %}{{ k }}{% endfor %}'),
        qr/FOREACH k, v IN items/,
        'Tuple unpacking'
    );
};

subtest 'Block' => sub {
    is(
        transpile('{% block content %}Hello{% endblock %}'),
        '[% BLOCK content %]Hello[% END %]',
        'Block'
    );
};

subtest 'Include' => sub {
    is(
        transpile('{% include "header.html" %}'),
        '[% INCLUDE header.html %]',
        'Include'
    );
};

subtest 'Set statement' => sub {
    is(
        transpile('{% set x = 42 %}'),
        '[% x = 42 %]',
        'Set variable'
    );
};

subtest 'Macro' => sub {
    my $result = transpile('{% macro greet(name) %}Hello {{ name }}{% endmacro %}');
    like($result, qr/MACRO greet\(name\) BLOCK/, 'Macro definition');
    like($result, qr/\[% name %\]/, 'Macro body');
};

subtest 'Whitespace control' => sub {
    like(transpile('{{- name -}}'), qr/\[%-.*-%\]/, 'Whitespace control markers');
};

subtest 'String concatenation' => sub {
    like(transpile('{{ a ~ b }}'), qr/\(a _ b\)/, 'Tilde becomes underscore');
};

subtest 'Logical operators' => sub {
    like(transpile('{% if a and b %}{% endif %}'), qr/IF \(a AND b\)/, 'And operator');
    like(transpile('{% if a or b %}{% endif %}'), qr/IF \(a OR b\)/, 'Or operator');
    like(transpile('{% if not a %}{% endif %}'), qr/IF NOT a/, 'Not operator');
};

subtest 'Comparison operators' => sub {
    like(transpile('{% if a == b %}{% endif %}'), qr/IF \(a == b\)/, 'Equals');
    like(transpile('{% if a != b %}{% endif %}'), qr/IF \(a != b\)/, 'Not equals');
    like(transpile('{% if a > b %}{% endif %}'), qr/IF \(a > b\)/, 'Greater than');
};

subtest 'Ternary expression' => sub {
    like(
        transpile('{{ x if condition else y }}'),
        qr/\(condition \? x : y\)/,
        'Ternary'
    );
};

subtest 'Loop variables' => sub {
    like(
        transpile('{{ loop.index }}'),
        qr/loop\.count/,
        'loop.index -> loop.count'
    );
    like(
        transpile('{{ loop.first }}'),
        qr/loop\.first/,
        'loop.first unchanged'
    );
    like(
        transpile('{{ loop.last }}'),
        qr/loop\.last/,
        'loop.last unchanged'
    );
    like(
        transpile('{{ loop.length }}'),
        qr/loop\.size/,
        'loop.length -> loop.size'
    );
};

subtest 'Boolean literals' => sub {
    like(transpile('{{ true }}'), qr/\[% 1 %\]/, 'true becomes 1');
    like(transpile('{{ false }}'), qr/\[% 0 %\]/, 'false becomes 0');
    like(transpile('{{ True }}'), qr/\[% 1 %\]/, 'True becomes 1');
    like(transpile('{{ False }}'), qr/\[% 0 %\]/, 'False becomes 0');
};

subtest 'List literal' => sub {
    like(transpile('{{ [1, 2, 3] }}'), qr/\[1, 2, 3\]/, 'List');
};

subtest 'Dict literal' => sub {
    like(transpile("{{ {'a': 1} }}"), qr/\{ 'a' => 1 \}/, 'Dict');
};

subtest 'Function calls' => sub {
    like(transpile('{{ range(10) }}'), qr/\[0 .. 10 - 1\]/, 'range(n)');
};

subtest 'Complex template' => sub {
    my $jinja = <<'JINJA';
<!DOCTYPE html>
<html>
<head><title>{{ title }}</title></head>
<body>
{% if user %}
<h1>Hello, {{ user.name|upper }}!</h1>
{% else %}
<h1>Hello, Guest!</h1>
{% endif %}
<ul>
{% for item in items %}
<li>{{ loop.index }}. {{ item }}</li>
{% endfor %}
</ul>
</body>
</html>
JINJA

    my $tt2 = transpile($jinja);

    like($tt2, qr/\[% title %\]/, 'Title variable');
    like($tt2, qr/\[% IF user %\]/, 'If user');
    like($tt2, qr/\[% user\.name\.upper %\]/, 'Filtered variable');
    like($tt2, qr/\[% FOREACH item IN items %\]/, 'For loop');
    like($tt2, qr/\[% loop\.count %\]/, 'Loop index');
    like($tt2, qr/\[% END %\]/, 'End tags');
};

done_testing();
