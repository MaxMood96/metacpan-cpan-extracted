#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";

use Yote::Spiderpup::SFC qw(parse_sfc);

#----------------------------------------------------------------------
# Block extraction tests
#----------------------------------------------------------------------

subtest 'extract style block as css' => sub {
    my $result = parse_sfc(<<'SFC');
<style>
button { background: blue; }
</style>
SFC
    is($result->{css}, 'button { background: blue; }', 'css extracted from style block');
};

subtest 'extract style lang="less" as less' => sub {
    my $result = parse_sfc(<<'SFC');
<style lang="less">
@primary: #3498db;
.btn { color: @primary; }
</style>
SFC
    like($result->{less}, qr/\@primary/, 'less content extracted');
    ok(!exists $result->{css}, 'no css key when lang=less');
};

subtest 'extract template as html' => sub {
    my $result = parse_sfc(<<'SFC');
<template>
<div><p>hello</p></div>
</template>
SFC
    is($result->{html}, '<div><p>hello</p></div>', 'html extracted from template');
};

subtest 'extract named template as html_variant' => sub {
    my $result = parse_sfc(<<'SFC');
<template name="compact">
<span>compact view</span>
</template>
SFC
    is($result->{html_compact}, '<span>compact view</span>', 'variant html extracted');
    ok(!exists $result->{html}, 'no default html key');
};

subtest 'extract recipe template' => sub {
    my $result = parse_sfc(<<'SFC');
<template recipe="button">
<button>click</button>
</template>
SFC
    ok(exists $result->{recipes}{button}, 'recipe created');
    is($result->{recipes}{button}{html}, '<button>click</button>', 'recipe html set');
};

subtest 'multiple blocks combined' => sub {
    my $result = parse_sfc(<<'SFC');
<script>
{
  title: 'My Page',
  vars: { count: 0 }
}
</script>

<style>
p { color: red; }
</style>

<template>
<p>hello</p>
</template>
SFC
    is($result->{title}, 'My Page', 'title from script');
    is($result->{vars}{count}, 0, 'vars from script');
    is($result->{css}, 'p { color: red; }', 'css from style');
    is($result->{html}, '<p>hello</p>', 'html from template');
};

#----------------------------------------------------------------------
# Script parser: data context
#----------------------------------------------------------------------

subtest 'parse vars - simple object' => sub {
    my $result = parse_sfc(<<'SFC');
<script>
{
  vars: { count: 0, name: 'World', isActive: true }
}
</script>
SFC
    is($result->{vars}{count}, 0, 'numeric var');
    is($result->{vars}{name}, 'World', 'string var');
    is($result->{vars}{isActive}, 1, 'boolean true becomes 1');
};

subtest 'parse vars - arrays' => sub {
    my $result = parse_sfc(<<'SFC');
<script>
{
  vars: { items: ["Apple", "Banana", "Cherry"] }
}
</script>
SFC
    is(ref($result->{vars}{items}), 'ARRAY', 'items is array');
    is(scalar @{$result->{vars}{items}}, 3, '3 items');
    is($result->{vars}{items}[0], 'Apple', 'first item');
};

subtest 'parse import - path strings' => sub {
    my $result = parse_sfc(<<'SFC');
<script>
{
  import: {
    card: '/recipes/card.yaml',
    layout: '/recipes/layout.yaml'
  }
}
</script>
SFC
    is($result->{import}{card}, '/recipes/card.yaml', 'card import path');
    is($result->{import}{layout}, '/recipes/layout.yaml', 'layout import path');
};

subtest 'parse routes' => sub {
    my $result = parse_sfc(<<'SFC');
<script>
{
  routes: {
    '/': 'home',
    '/about': 'about'
  }
}
</script>
SFC
    is($result->{routes}{'/'}, 'home', 'root route');
    is($result->{routes}{'/about'}, 'about', 'about route');
};

subtest 'parse initial_store' => sub {
    my $result = parse_sfc(<<'SFC');
<script>
{
  initial_store: { theme: 'dark', count: 42 }
}
</script>
SFC
    is($result->{initial_store}{theme}, 'dark', 'store string value');
    is($result->{initial_store}{count}, 42, 'store numeric value');
};

subtest 'parse import-css array' => sub {
    my $result = parse_sfc(<<'SFC');
<script>
{
  'import-css': ['/css/reset.css', '/css/app.css']
}
</script>
SFC
    is(ref($result->{'import-css'}), 'ARRAY', 'import-css is array');
    is($result->{'import-css'}[0], '/css/reset.css', 'first css import');
};

#----------------------------------------------------------------------
# Script parser: function context
#----------------------------------------------------------------------

subtest 'parse methods - arrow functions' => sub {
    my $result = parse_sfc(<<'SFC');
<script>
{
  methods: {
    inc: () => { $count = $count + 1 },
    getName: () => $name
  }
}
</script>
SFC
    is($result->{methods}{inc}, '() => { $count = $count + 1 }', 'arrow function with body');
    is($result->{methods}{getName}, '() => $name', 'arrow expression');
};

subtest 'parse methods - nested braces' => sub {
    my $result = parse_sfc(<<'SFC');
<script>
{
  methods: {
    complex: () => { if (true) { $x = 1 } else { $x = 2 } }
  }
}
</script>
SFC
    like($result->{methods}{complex}, qr/if \(true\)/, 'nested braces preserved');
    like($result->{methods}{complex}, qr/else/, 'else branch preserved');
};

subtest 'parse methods - strings containing braces' => sub {
    my $result = parse_sfc(<<'SFC');
<script>
{
  methods: {
    greet: () => { console.log("{hello}"); $x = 1 }
  }
}
</script>
SFC
    like($result->{methods}{greet}, qr/\{hello\}/, 'braces in string preserved');
};

subtest 'parse computed' => sub {
    my $result = parse_sfc(<<'SFC');
<script>
{
  computed: {
    greeting: () => `Hello, ${$name}!`,
    doubled: () => $count * 2
  }
}
</script>
SFC
    like($result->{computed}{greeting}, qr/Hello/, 'computed with template literal');
    is($result->{computed}{doubled}, '() => $count * 2', 'simple computed');
};

subtest 'parse lifecycle' => sub {
    my $result = parse_sfc(<<'SFC');
<script>
{
  lifecycle: {
    onMount: () => console.log('mounted'),
    onDestroy: () => console.log('destroyed')
  }
}
</script>
SFC
    like($result->{lifecycle}{onMount}, qr/mounted/, 'onMount lifecycle hook');
    like($result->{lifecycle}{onDestroy}, qr/destroyed/, 'onDestroy lifecycle hook');
};

subtest 'parse watch' => sub {
    my $result = parse_sfc(<<'SFC');
<script>
{
  watch: {
    count: (newVal, oldVal) => console.log('changed', oldVal, newVal)
  }
}
</script>
SFC
    like($result->{watch}{count}, qr/newVal.*oldVal/, 'watch handler with params');
};

#----------------------------------------------------------------------
# Scalar keys
#----------------------------------------------------------------------

subtest 'parse title as scalar' => sub {
    my $result = parse_sfc(<<'SFC');
<script>
{
  title: 'My Page Title'
}
</script>
SFC
    is($result->{title}, 'My Page Title', 'title is a simple scalar');
};

#----------------------------------------------------------------------
# Recipes in script block
#----------------------------------------------------------------------

subtest 'parse recipes in script' => sub {
    my $result = parse_sfc(<<'SFC');
<script>
{
  recipes: {
    button: {
      vars: { label: 'Click' },
      methods: {
        click: () => console.log('clicked')
      }
    }
  }
}
</script>
SFC
    ok(exists $result->{recipes}{button}, 'recipe exists');
    is($result->{recipes}{button}{vars}{label}, 'Click', 'recipe vars');
    like($result->{recipes}{button}{methods}{click}, qr/clicked/, 'recipe methods');
};

#----------------------------------------------------------------------
# Recipe script+template blocks
#----------------------------------------------------------------------

subtest 'recipe from script and template blocks' => sub {
    my $result = parse_sfc(<<'SFC');
<script recipe="counter">
{
  vars: { count: 0 },
  methods: {
    inc: () => { $count = $count + 1 }
  }
}
</script>

<template recipe="counter">
<button @click="inc()">*{count}</button>
</template>
SFC
    ok(exists $result->{recipes}{counter}, 'recipe created');
    is($result->{recipes}{counter}{vars}{count}, 0, 'recipe vars from script');
    ok(exists $result->{recipes}{counter}{methods}{inc}, 'recipe methods from script');
    like($result->{recipes}{counter}{html}, qr/button/, 'recipe html from template');
};

#----------------------------------------------------------------------
# Edge cases
#----------------------------------------------------------------------

subtest 'trailing commas' => sub {
    my $result = parse_sfc(<<'SFC');
<script>
{
  vars: {
    a: 1,
    b: 2,
  },
  methods: {
    foo: () => 1,
  },
}
</script>
SFC
    is($result->{vars}{a}, 1, 'var a with trailing comma');
    is($result->{vars}{b}, 2, 'var b with trailing comma');
    ok(exists $result->{methods}{foo}, 'method with trailing comma');
};

subtest 'comments in script' => sub {
    my $result = parse_sfc(<<'SFC');
<script>
{
  // this is a title
  title: 'Test',
  /* vars section */
  vars: { x: 10 }
}
</script>
SFC
    is($result->{title}, 'Test', 'title after line comment');
    is($result->{vars}{x}, 10, 'var after block comment');
};

subtest 'script without braces' => sub {
    my $result = parse_sfc(<<'SFC');
<script>
title: 'No Braces',
vars: { count: 0 }
</script>
SFC
    is($result->{title}, 'No Braces', 'title parsed without outer braces');
    is($result->{vars}{count}, 0, 'vars parsed without outer braces');
};

subtest 'multi-line method body' => sub {
    my $result = parse_sfc(<<'SFC');
<script>
{
  methods: {
    doStuff: () => {
      const x = 1;
      const y = 2;
      $result = x + y;
    }
  }
}
</script>
SFC
    like($result->{methods}{doStuff}, qr/const x = 1/, 'multi-line body first line');
    like($result->{methods}{doStuff}, qr/\$result = x \+ y/, 'multi-line body last line');
};

subtest 'async method' => sub {
    my $result = parse_sfc(<<'SFC');
<script>
{
  methods: {
    fetchData: async () => {
      const res = await fetch('/api/data');
      $data = await res.json();
    }
  }
}
</script>
SFC
    like($result->{methods}{fetchData}, qr/^async/, 'async preserved');
    like($result->{methods}{fetchData}, qr/await fetch/, 'await preserved');
};

subtest 'method with template literal containing braces' => sub {
    my $result = parse_sfc(<<'SFC');
<script>
{
  methods: {
    format: (item, idx) => `${idx + 1}. ${item}`
  }
}
</script>
SFC
    like($result->{methods}{format}, qr/\$\{idx \+ 1\}/, 'template literal with expression');
};

#----------------------------------------------------------------------
# Round-trip: .pup equivalent of clicker.yaml
#----------------------------------------------------------------------

subtest 'clicker round-trip' => sub {
    my $result = parse_sfc(<<'SFC');
<script>
{
  vars: { count: 0, title: 'clicked' },
  methods: {
    inc: () => { $count = $count + 1; this.broadcast("clicker", $count ); this.emit("bloop", $count ) }
  }
}
</script>

<template>
<button type="button" @click="inc()" value="click">${title} ${count} times</button>
</template>
SFC

    is($result->{vars}{count}, 0, 'clicker: count var');
    is($result->{vars}{title}, 'clicked', 'clicker: title var');
    like($result->{methods}{inc}, qr/\$count = \$count \+ 1/, 'clicker: inc method');
    like($result->{methods}{inc}, qr/broadcast/, 'clicker: broadcast call');
    like($result->{html}, qr/button/, 'clicker: html has button');
    like($result->{html}, qr/\@click="inc\(\)"/, 'clicker: html has click handler');
};

done_testing();
