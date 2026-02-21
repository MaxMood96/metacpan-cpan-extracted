#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";

use Yote::Spiderpup::Transform qw(
    transform_dollar_vars
    transform_expression
    extract_arrow_params
    parse_html
);

#
# Tests for transform_dollar_vars
#

subtest 'transform_dollar_vars - simple reads' => sub {
    is(
        transform_dollar_vars('$count'),
        'this.get_count()',
        'simple variable read'
    );
    is(
        transform_dollar_vars('$count + 1'),
        'this.get_count() + 1',
        'variable in expression'
    );
    is(
        transform_dollar_vars('$foo + $bar'),
        'this.get_foo() + this.get_bar()',
        'multiple variables'
    );
};

subtest 'transform_dollar_vars - assignments' => sub {
    is(
        transform_dollar_vars('$count = 5'),
        'this.set_count(5)',
        'simple assignment'
    );
    is(
        transform_dollar_vars('$count = $count + 1'),
        'this.set_count(this.get_count() + 1)',
        'increment pattern'
    );
    is(
        transform_dollar_vars('$x = 0; $y = 1'),
        'this.set_x(0); this.set_y(1)',
        'multiple assignments'
    );
};

subtest 'transform_dollar_vars - comparison operators preserved' => sub {
    is(
        transform_dollar_vars('$count == 5'),
        'this.get_count() == 5',
        'equality check not treated as assignment'
    );
    is(
        transform_dollar_vars('$count === 5'),
        'this.get_count() === 5',
        'strict equality check preserved'
    );
    is(
        transform_dollar_vars('$x >= $y'),
        'this.get_x() >= this.get_y()',
        'greater-than-or-equal preserved'
    );
};

subtest 'transform_dollar_vars - strings not transformed' => sub {
    is(
        transform_dollar_vars('"$count"'),
        '"$count"',
        'double-quoted string preserved'
    );
    is(
        transform_dollar_vars("'\$count'"),
        "'\$count'",
        'single-quoted string preserved'
    );
    is(
        transform_dollar_vars('`$count`'),
        '`$count`',
        'template literal preserved'
    );
};

subtest 'transform_dollar_vars - escaped quotes in strings' => sub {
    # Escaped quotes should not end the string early
    is(
        transform_dollar_vars('"hello \\"world\\" $count"'),
        '"hello \\"world\\" $count"',
        'escaped double quotes inside double-quoted string'
    );
    is(
        transform_dollar_vars("'it\\'s a \\' test \$count'"),
        "'it\\'s a \\' test \$count'",
        'escaped single quotes inside single-quoted string'
    );
    is(
        transform_dollar_vars('`template with \\` backtick $count`'),
        '`template with \\` backtick $count`',
        'escaped backtick inside template literal'
    );
};

subtest 'transform_dollar_vars - mixed strings and code' => sub {
    is(
        transform_dollar_vars('console.log("value: " + $count)'),
        'console.log("value: " + this.get_count())',
        'string preserved, variable outside transformed'
    );
    is(
        transform_dollar_vars('"prefix" + $x + "suffix"'),
        '"prefix" + this.get_x() + "suffix"',
        'variables between strings transformed'
    );
    is(
        transform_dollar_vars('$msg = "hello \\"$name\\""'),
        'this.set_msg("hello \\"$name\\"")',
        'assignment with escaped quotes in value'
    );
};

subtest 'transform_dollar_vars - trailing escaped quote edge case' => sub {
    # This is a tricky case: string ending with escaped backslash before quote
    is(
        transform_dollar_vars('"path\\\\"; $count'),
        '"path\\\\"; this.get_count()',
        'string ending with escaped backslash, followed by variable'
    );
    is(
        transform_dollar_vars('"test\\\\" + $x'),
        '"test\\\\" + this.get_x()',
        'escaped backslash at end of string does not escape the closing quote'
    );
};

#
# Tests for transform_expression
#

subtest 'transform_expression - adds arrow wrapper' => sub {
    my $result = transform_expression('$count + 1', {});
    like($result, qr/^function\(\)\{return /, 'wraps bare expression in function');

    my $result2 = transform_expression('() => $count', {});
    like($result2, qr/^\(\)/, 'preserves existing arrow function');
};

subtest 'transform_expression - method calls with known methods' => sub {
    my $known = { increment => 1, reset => 1 };

    my $result = transform_expression('increment()', $known);
    like($result, qr/this\.increment\(\)/, 'adds this. to known method');

    my $result2 = transform_expression('unknownFn()', $known);
    unlike($result2, qr/this\.unknownFn/, 'does not add this. to unknown function');
};

#
# Tests for extract_arrow_params
#

subtest 'extract_arrow_params' => sub {
    my $params = extract_arrow_params('(x, y) => x + y');
    ok($params->{x}, 'extracts first param');
    ok($params->{y}, 'extracts second param');

    my $params2 = extract_arrow_params('item => item.name');
    ok($params2->{item}, 'extracts single param without parens');

    my $params3 = extract_arrow_params('(mod, item, idx) => item');
    ok($params3->{mod}, 'extracts mod param');
    ok($params3->{item}, 'extracts item param');
    ok($params3->{idx}, 'extracts idx param');
};

#
# Tests for parse_html
#

subtest 'parse_html - basic structure' => sub {
    my $result = parse_html('<div><span>hello</span></div>', {});

    is(ref($result), 'HASH', 'returns hash');
    is(ref($result->{children}), 'ARRAY', 'has children array');
    is($result->{children}[0]{tag}, 'div', 'parses div tag');
    is($result->{children}[0]{children}[0]{tag}, 'span', 'parses nested span');
};

subtest 'parse_html - text content' => sub {
    my $result = parse_html('<p>Hello World</p>', {});

    my $p = $result->{children}[0];
    is($p->{tag}, 'p', 'parses p tag');
    is($p->{children}[0]{content}, 'Hello World', 'extracts text content');
};

subtest 'parse_html - attributes' => sub {
    my $result = parse_html('<div class="foo" id="bar"></div>', {});

    my $div = $result->{children}[0];
    is($div->{attributes}{class}, 'foo', 'parses class attribute');
    is($div->{attributes}{id}, 'bar', 'parses id attribute');
};

subtest 'parse_html - dynamic attributes with $var' => sub {
    my $result = parse_html('<div title="$name"></div>', {});

    my $div = $result->{children}[0];
    ok(exists $div->{attributes}{'*title'}, 'dynamic attr has * prefix');
    like($div->{attributes}{'*title'}, qr/get_name/, 'transforms $var to getter');
};

subtest 'parse_html - @event shorthand' => sub {
    my $known = { handleClick => 1 };
    my $result = parse_html('<button @click="handleClick()"></button>', $known);

    my $button = $result->{children}[0];
    ok(exists $button->{attributes}{'*onclick'}, '@click becomes *onclick');
};

subtest 'parse_html - if/elseif/else' => sub {
    my $result = parse_html('<if condition="() => true"><p>yes</p></if>', {});

    my $if = $result->{children}[0];
    is($if->{tag}, 'if', 'parses if tag');
    ok(exists $if->{attributes}{'*condition'}, 'condition attribute exists');
};

subtest 'parse_html - for loop' => sub {
    my $result = parse_html('<ul for="$items"><li>item</li></ul>', {});

    my $ul = $result->{children}[0];
    is($ul->{tag}, 'ul', 'parses ul tag');
    ok(exists $ul->{attributes}{'*for'}, 'for attribute has * prefix');
};

subtest 'parse_html - self-closing tags' => sub {
    my $result = parse_html('<div><br/><input type="text"/></div>', {});

    my $div = $result->{children}[0];
    is(scalar @{$div->{children}}, 2, 'self-closing tags parsed correctly');
    is($div->{children}[0]{tag}, 'br', 'br tag parsed');
    is($div->{children}[1]{tag}, 'input', 'input tag parsed');
};

#
# Additional parse_html tests for recently added features
#

subtest 'parse_html - !name attribute' => sub {
    my $result = parse_html('<foo !name="bar"></foo>', {});

    my $foo = $result->{children}[0];
    is($foo->{tag}, 'foo', 'tag parsed');
    is($foo->{attributes}{'!name'}, 'bar', '!name attribute preserved as-is');
};

subtest 'parse_html - variant syntax (tag!variant)' => sub {
    my $result = parse_html('<foo!smol class="x"></foo!smol>', {});

    my $foo = $result->{children}[0];
    is($foo->{tag}, 'foo', 'tag is base name without variant');
    is($foo->{variant}, 'smol', 'variant split from tag');
    is($foo->{attributes}{class}, 'x', 'attributes still parsed');
};

subtest 'parse_html - self-closing slot' => sub {
    my $result = parse_html('<div><slot/></div>', {});

    my $div = $result->{children}[0];
    my $slot = $div->{children}[0];
    is($slot->{tag}, 'slot', 'slot tag parsed');
    is(scalar @{$slot->{children}}, 0, 'self-closing slot has no children');
};

subtest 'parse_html - link tag with to attribute' => sub {
    my $result = parse_html('<link to="/about">About Us</link>', {});

    my $link = $result->{children}[0];
    is($link->{tag}, 'link', 'link tag parsed');
    is($link->{attributes}{to}, '/about', 'to attribute preserved');
    is($link->{children}[0]{content}, 'About Us', 'text child parsed');
};

done_testing();
