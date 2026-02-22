# Spiderpup HOWTO Guide

A hands-on guide to building websites and web apps with Spiderpup — a reactive web framework powered by Perl and JavaScript, with YAML and single-file component (.pup) authoring.

This guide walks you through progressively more complex examples. By the end, you'll know how to build interactive single-page applications with reusable components.

---

## Table of Contents

1. [Getting Started](#1-getting-started)
2. [Your First Page](#2-your-first-page)
3. [Adding Style](#3-adding-style)
4. [Reactive Variables](#4-reactive-variables)
5. [Methods and Event Handling](#5-methods-and-event-handling)
6. [Computed Properties](#6-computed-properties)
7. [Conditionals](#7-conditionals)
8. [Loops](#8-loops)
9. [Building Reusable Components](#9-building-reusable-components)
10. [Slots: Passing Content into Components](#10-slots-passing-content-into-components)
11. [Component Communication](#11-component-communication)
12. [Global Store](#12-global-store)
13. [Client-Side Routing (SPA)](#13-client-side-routing-spa)
14. [Lifecycle Hooks](#14-lifecycle-hooks)
15. [Working with External Assets](#15-working-with-external-assets)
16. [Shorthand Syntax Reference](#16-shorthand-syntax-reference)
17. [Single-File Components (.pup)](#17-single-file-components-pup)
18. [Compilation and Deployment](#18-compilation-and-deployment)
19. [Using an External Web Server](#19-using-an-external-web-server)

---

## 1. Getting Started

### Prerequisites

Install the required Perl modules:

```bash
cpan CSS::LESSp YAML JSON::PP
```

`IO::Socket::INET` ships with Perl by default.

### Project Layout

A Spiderpup project lives under a `www/` directory:

```
my-project/
├── bin/
│   └── pupserver            # The server (copy from spiderpup repo)
├── lib/
│   └── Yote/Spiderpup/
│       ├── SFC.pm             # Single-file component parser (copy from repo)
│       └── Transform.pm      # Expression transformer (copy from repo)
└── www/
    ├── webroot/              # Compiled js, html and static files go here
    │   └── js/
    │       └── spiderpup.js  # Client runtime (copy from repo)
    ├── pages/                # Page definitions (YAML or .pup)
    │   └── index.yaml
    └── recipes/              # Reusable components (YAML or .pup)
```

Pages live in `www/pages/`. Subdirectories create URL segments:

| URL | Page File |
|-----|-----------|
| `/` | `www/pages/index.yaml` |
| `/about` | `www/pages/about.yaml` |
| `/myapp` | `www/pages/myapp/index.yaml` |
| `/myapp/dashboard` | `www/pages/myapp/dashboard.yaml` |

Recipes in `www/recipes/` can be imported by any page but are not directly accessible via URL.

### Starting the Server

```bash
pupserver
```

Open `http://localhost:5000` in your browser. The server compiles YAML to HTML+JS on the fly and caches the results.

Useful options:

```bash
# Custom port (default 5000)
pupserver --port 3000

# Disable caching (recompile every request, useful during development)
SPIDERPUP_NO_CACHE=1 pupserver

# Custom webroot directory
pupserver --webroot /var/www/mysite

# Serve behind a reverse proxy at /myapp
pupserver --base-url-path /myapp

# Batch compile all YAML files (for static deployment)
pupserver --compile

# Watch for file changes and auto-recompile
pupserver --watch        # checks every 5 seconds
pupserver --watch 2      # checks every 2 seconds

# HTTPS with SSL certificate
pupserver --ssl-cert cert.pem --ssl-key key.pem
pupserver --port 8443 --ssl-cert /path/to/cert.pem --ssl-key /path/to/key.pem
```

---

## 2. Your First Page

Create `www/pages/index.yaml`:

```yaml
title: My First Page

html: |
  <h1>Hello, Spiderpup!</h1>
  <p>This is my first page.</p>
```

Start the server and visit `http://localhost:5000`. That's it — a YAML file became a web page.

Every page YAML can have these top-level fields:

| Field           | Purpose                          |
|-----------------|----------------------------------|
| `title`         | Browser tab title                |
| `html`          | HTML template                    |
| `css`           | Raw CSS                          |
| `less`          | LESS stylesheet (compiled to CSS)|
| `vars`          | Reactive variables               |
| `computed`      | Derived values                   |
| `methods`       | JavaScript functions             |
| `lifecycle`     | `onMount` / `onDestroy` hooks    |
| `import`        | Components to use                |
| `routes`        | SPA route definitions            |
| `initial_store` | Global store initialization      |
| `import-css`    | External CSS URLs                |
| `import-js`     | External JS URLs                 |
| `include-js`    | Local JS files to inline         |

---

## 3. Adding Style

### Raw CSS

```yaml
title: Styled Page

css: |
  h1 { color: navy; }
  .highlight { background: yellow; padding: 4px; }

html: |
  <h1>Styled Page</h1>
  <p class="highlight">This is highlighted.</p>
```

### LESS

The `less` field supports variables, nesting, mixins, color functions, and math:

```yaml
title: LESS Demo

less: |
  @brand: #e74c3c;
  @spacing: 10px;

  .border-radius(@r) {
    border-radius: @r;
  }

  .card {
    border: 1px solid @brand;
    padding: @spacing * 2;
    .border-radius(8px);

    h2 { color: @brand; }

    &:hover {
      border-color: darken(@brand, 15%);
    }

    &.featured {
      background: lighten(@brand, 40%);
    }
  }

html: |
  <div class="card featured">
    <h2>LESS-Powered Card</h2>
    <p>Styled with variables, nesting, and color functions.</p>
  </div>
```

Available LESS features:
- **Variables:** `@name: value;`
- **Nesting:** Selectors inside selectors
- **Parent selector:** `&:hover`, `&.active`, `&-icon`
- **Mixins:** `.mixin(@param) { ... }`
- **Color functions:** `darken()`, `lighten()`, `mix()`
- **Math:** `+`, `-`, `*`, `/` with unit preservation

---

## 4. Reactive Variables

Declare variables in `vars`. Use `$varName` in HTML to display them:

```yaml
title: Variables Demo

vars:
  name: World
  count: 0

html: |
  <h1>Hello, $name!</h1>
  <p>Count is: $count</p>
```

Variables update in the UI when the recipe refreshes. Event handlers (like `@click`) automatically
trigger a refresh after they run, so changes made inside a handler appear immediately. Outside of an
event handler, call `refresh()` explicitly to update the UI.

You can use `${varName}` for expressions inside template literals or when the variable name is adjacent to other text:

```yaml
html: |
  <p>${name}'s counter: ${count}</p>
```

---

## 5. Methods and Event Handling

Define JavaScript functions in `methods` and attach them to DOM events.

### With shorthand syntax

```yaml
title: Counter

vars:
  count: 0

methods:
  increment: () => { $count = $count + 1 }
  decrement: () => { $count = $count - 1 }
  reset: () => { $count = 0 }

html: |
  <p>Count: $count</p>
  <button @click="increment()">+1</button>
  <button @click="decrement()">-1</button>
  <button @click="reset()">Reset</button>
```

Key things happening here:
- `$count = $count + 1` is shorthand for `this.set_count(this.get_count() + 1)`
- `@click="increment()"` is shorthand for `onClick="() => this.increment()"`
- The UI refreshes automatically after any event handler runs

### With traditional syntax

The same example without shorthand:

```yaml
methods:
  increment: () => this.set_count(this.get_count() + 1)
  decrement: () => this.set_count(this.get_count() - 1)
  reset: () => this.set_count(0)

html: |
  <button onClick="() => this.increment()">+1</button>
  <button onClick="() => this.decrement()">-1</button>
  <button onClick="() => this.reset()">Reset</button>
```

Both styles work and can be mixed freely.

### Handling input events

```yaml
vars:
  name: ""

html: |
  <input @input="(e) => { $name = e.target.value }" placeholder="Type your name" />
  <p>Hello, $name!</p>
```

Any standard DOM event works with `@`: `@click`, `@input`, `@change`, `@mouseover`, `@keydown`, etc.

---

## 6. Computed Properties

Computed properties derive values from other variables and update automatically:

```yaml
title: Computed Demo

vars:
  firstName: John
  lastName: Doe
  items: ["apple", "banana", "cherry"]

computed:
  fullName: () => `${$firstName} ${$lastName}`
  itemCount: () => $items.length
  isEmpty: () => $items.length === 0

html: |
  <h1>Welcome, ${fullName}!</h1>
  <p>You have ${itemCount} items.</p>
```

Use computed properties for any value that can be calculated from existing variables.

---

## 7. Conditionals

Use `<if>`, `<elseif>`, and `<else>` tags to conditionally render content:

```yaml
vars:
  score: 75

methods:
  randomize: () => { $score = Math.round(Math.random() * 100) }

html: |
  <p>Score: $score</p>
  <button @click="randomize()">Randomize</button>

  <if condition="() => $score >= 90">
    <p>Grade: A</p>
  </if>
  <elseif condition="() => $score >= 80">
    <p>Grade: B</p>
  </elseif>
  <elseif condition="() => $score >= 70">
    <p>Grade: C</p>
  </elseif>
  <else>
    <p>Grade: F</p>
  </else>
```

### Transitions

Add animations when conditionals toggle:

```yaml
html: |
  <button @click="$visible = !$visible">Toggle</button>

  <if condition="() => $visible" transition="fade">
    <div>I fade in and out.</div>
  </if>
```

Built-in transitions: `fade`, `slide`.

---

## 8. Loops

Use the `for` attribute on any element to iterate over an array:

```yaml
vars:
  fruits: ["Apple", "Banana", "Cherry"]

html: |
  <h2>Fruit List</h2>
  <ul for="$fruits">
    <li textContent="(mod, item, idx) => `${idx + 1}. ${item}`"></li>
  </ul>
```

The loop callback receives three arguments:
- `mod` — the current component instance
- `item` — the current array element
- `idx` — the current index

You can also loop over inline arrays:

```yaml
html: |
  <ul for="[10, 20, 30]">
    <li textContent="(mod, item) => `Value: ${item}`"></li>
  </ul>
```

Or use a function for dynamic data:

```yaml
html: |
  <ul for="() => this.get_fruits()">
    <li textContent="(mod, item) => item.toUpperCase()"></li>
  </ul>
```

You can nest conditionals inside loops:

```yaml
html: |
  <ul for="[2, 12, 4, 9]">
    <if condition="(item, idx) => idx === 0">
      <li>(item, idx) => `First item: ${item}`</li>
    </if>
    <li textContent="(item, idx) => `${idx}: ${item}`"></li>
  </ul>
```

---

## 9. Building Reusable Components

Components (called "recipes" in Spiderpup) are YAML files you import and use as custom HTML tags.

### Creating a component

Create `www/recipes/card.yaml`:

```yaml
title: Card Component

vars:
  title: Card

css: |
  .card-wrapper {
    border: 2px solid #ddd;
    border-radius: 8px;
    padding: 15px;
    margin: 10px 0;
    background: #f9f9f9;
  }
  .card-title {
    font-weight: bold;
    margin-bottom: 10px;
  }

html: |
  <div class="card-wrapper">
    <div class="card-title">$title</div>
    <div class="card-content">
      <slot/>
    </div>
  </div>
```

### Using a component

Import it in your page and use the namespace as the tag:

```yaml
title: Cards Demo

import:
  card: /recipes/card.yaml

html: |
  <card title="First Card">
    <p>Content inside the first card.</p>
  </card>

  <card title="Second Card">
    <p>Content inside the second card.</p>
  </card>
```

Attributes passed to the component tag (like `title="First Card"`) become that component's variable values, overriding the defaults.

### Sub-recipes

A component can define nested sub-recipes using the `recipes` field:

```yaml
# www/recipes/zippy.yaml
vars:
  color: red

recipes:
  clicker:
    vars:
      count: 0
      title: clicked
    methods:
      inc: () => { $count = $count + 1 }
    html: |
      <button @click="inc()">${title} ${count} times</button>

html: |
  <h1>This is $color Zippy</h1>
  <clicker />
```

Use a sub-recipe from a parent page with dot notation:

```yaml
import:
  myzippy: /recipes/zippy.yaml

html: |
  <myzippy.clicker />
```

### Named instances

Use `!name` to register a component instance so you can reference it programmatically:

```yaml
import:
  myzippy: /recipes/zippy.yaml

lifecycle:
  onMount: |
    () => {
      // Access the named instance
      console.log(this.instances.zip.get_color());
    }

html: |
  <myzippy color="blue" !name="zip">
    <h2>Content inside zippy</h2>
  </myzippy>
```

The instance is available as `this.instances.<name>`.

### Shared named instances (reuse)

When `!name="X"` appears a second time, the existing instance is **reused** instead of creating a new one. Both DOM locations share the same vars, state, lifecycle, and child recipes — updates at one location are reflected at the other:

```yaml
import:
  myzippy: /recipes/zippy.yaml

html: |
  <myzippy color="blue" !name="zip">
    <h2>CHOWHOUND $color</h2>
  </myzippy>

  <!-- second use of !name="zip" — reuses the same instance -->
  <myzippy !name="zip"></myzippy>
```

How it works:
- The first `<myzippy !name="zip">` creates the instance and renders it
- The second `<myzippy !name="zip">` finds the existing instance and re-renders its template at the new DOM location
- Child recipes (clicker, etc.) inside the component are also shared — clicking a button at either location updates the count everywhere
- `onMount` fires only once for the shared instance
- Slot content from the first occurrence appears at both locations

---

## 10. Slots: Passing Content into Components

Slots let you inject content from the parent into specific locations within a component.

### Default slot

The component defines where child content appears with `<slot/>`:

```yaml
# www/recipes/panel.yaml
vars:
  heading: Panel

html: |
  <div class="panel">
    <h3>$heading</h3>
    <div class="panel-body">
      <slot/>
    </div>
  </div>
```

```yaml
# page using it
import:
  panel: /recipes/panel.yaml

html: |
  <panel heading="My Panel">
    <p>This paragraph goes into the slot.</p>
    <p>So does this one.</p>
  </panel>
```

### Named slots

Define multiple insertion points with named slots:

```yaml
# www/recipes/layout.yaml
html: |
  <div class="layout">
    <header><slot name="header"/></header>
    <main><slot/></main>
    <footer><slot name="footer"/></footer>
  </div>
```

Target named slots with the `slot` attribute:

```yaml
import:
  layout: /recipes/layout.yaml

html: |
  <layout>
    <h1 slot="header">Page Title</h1>
    <p>Main content goes to the default slot.</p>
    <small slot="footer">Copyright 2026</small>
  </layout>
```

### Slot scoping

Slot content is scoped to the **component**, not the parent page. This means slot content can access the component's variables and methods:

```yaml
# www/recipes/counter.yaml
vars:
  count: 0
methods:
  increment: () => { $count = $count + 1 }
html: |
  <div class="counter">
    <slot/>
  </div>
```

```yaml
# page using it
import:
  counter: /recipes/counter.yaml

html: |
  <counter>
    <p>Count: $count</p>
    <button @click="increment()">Add</button>
  </counter>
```

Here, `$count` and `increment()` refer to the counter component's scope.

To access the parent page's scope from within slot content, use `this.parentModule`:

```yaml
html: |
  <counter>
    <p textContent="() => this.parentModule.get_pageVar()"></p>
  </counter>
```

---

## 11. Component Communication

Spiderpup provides two patterns for components to talk to each other.

### Broadcast / Receive (pub/sub)

Any component can broadcast a message to all other components:

```yaml
# sender component
methods:
  notify: |
    () => {
      this.broadcast('user-updated', { name: 'Alice' });
    }

html: |
  <button @click="notify()">Notify All</button>
```

```yaml
# receiver component
lifecycle:
  onMount: |
    () => {
      this.receive('user-updated', (data, sender) => {
        console.log('User updated:', data.name);
      });
    }
```

- `broadcast(channel, data)` — sends to all other components
- `receive(channel, callback)` — listens on a channel; callback gets `(data, sender)`

### Emit / On (event bubbling)

Events propagate up the component tree, like DOM events:

```yaml
# child component
methods:
  select: |
    () => {
      this.emit('item-selected', { id: 42 });
    }

html: |
  <button @click="select()">Select</button>
```

```yaml
# parent component
import:
  child: /recipes/child.yaml

lifecycle:
  onMount: |
    () => {
      this.on('item-selected', (event) => {
        console.log('Selected:', event.data.id);
        // event.stopPropagation() to stop bubbling
      });
    }

html: |
  <child />
```

Event object properties:
- `event.name` — the event name
- `event.data` — the payload
- `event.source` — the component that emitted it
- `event.stopPropagation()` — stops the event from bubbling further

---

## 12. Global Store

The global store is a reactive key-value hash shared across all components. When a value changes, every component re-renders.

### Setup

```yaml
title: Store Demo

initial_store:
  user: null
  theme: light

html: |
  <p>Theme: ${store.get('theme')}</p>
  <button @click="store.set('theme', 'dark')">Dark Mode</button>
  <button @click="store.set('theme', 'light')">Light Mode</button>
```

### Store API

| Method | Description |
|--------|-------------|
| `store.get(key)` | Read a value |
| `store.set(key, value)` | Write a value (triggers refresh on all components) |
| `store.init({...})` | Initialize multiple values at once (no refresh) |
| `store.watch(key, fn)` | Callback when a specific key changes |

### Cross-component example

```yaml
# Login component
methods:
  login: |
    (userData) => {
      store.set('user', userData);
    }
```

```yaml
# Header component (automatically updates when store changes)
html: |
  <if condition="() => store.get('user')">
    <p>Welcome, ${store.get('user').name}!</p>
  </if>
  <else>
    <p>Please log in</p>
  </else>
```

### Debugging

The store is available in the browser console as `window.store`:

```javascript
store.get('user')
store.set('theme', 'dark')
```

---

## 13. Client-Side Routing (SPA)

Build single-page apps with client-side navigation — no full page reloads.

### Define routes

```yaml
title: My App

import:
  home: /home.yaml
  about: /about.yaml
  user: /recipes/user.yaml

routes:
  /: home
  /about: about
  /user/:id: user

html: |
  <nav>
    <link to="/">Home</link> |
    <link to="/about">About</link> |
    <link to="/user/123">User 123</link>
  </nav>
  <hr/>
  <router-view/>
```

Key elements:
- **`routes`** — maps URL paths to imported components
- **`<link to="...">`** — client-side navigation links (no page reload)
- **`<router-view/>`** — where the matched component renders

### Route parameters

URL parameters like `:id` are passed as variables to the component:

```yaml
# www/recipes/user.yaml
vars:
  id: ""

html: |
  <h1>User Profile</h1>
  <p>Viewing user ID: $id</p>
```

Navigate to `/user/456` and `$id` will be `"456"`.

---

## 14. Lifecycle Hooks

Run code when a component enters or leaves the DOM:

```yaml
vars:
  timer: null
  elapsed: 0

lifecycle:
  onMount: |
    () => {
      console.log('Component mounted');
      $timer = setInterval(() => {
        $elapsed = $elapsed + 1;
      }, 1000);
    }
  onDestroy: |
    () => {
      console.log('Component destroyed');
      clearInterval($timer);
    }

html: |
  <p>Elapsed: ${elapsed}s</p>
```

`onMount` fires after the component's DOM is built. Use it for:
- Fetching data
- Setting up timers or event listeners
- Registering `receive()` and `on()` handlers
- Initializing third-party libraries

`onDestroy` fires when the component is removed. Use it for cleanup.

---

## 15. Working with External Assets

### External CSS (`import-css`)

Load stylesheets via `<link>` tags:

```yaml
import-css:
  - https://cdn.example.com/normalize.css
  - /styles/theme.css
```

### External JavaScript (`import-js`)

Load scripts via `<script src>` tags:

```yaml
import-js:
  - https://cdn.example.com/chart.js
```

### Inline JavaScript (`include-js`)

Embed local JS file contents directly into the page `<head>`:

```yaml
include-js:
  - lib/helper.js
  - utils/data.js
```

File paths resolve relative to the `www/` directory. Use this for small utilities you want bundled into the page without extra HTTP requests.

---

## 16. Shorthand Syntax Reference

Spiderpup's shorthand is compiled at build time. All traditional syntax also works.

### Variable shorthand (`$var`)

| Shorthand | Compiles to |
|-----------|-------------|
| `$count` (read) | `this.get_count()` |
| `$count = 5` (assign) | `this.set_count(5)` |
| `$count = $count + 1` | `this.set_count(this.get_count() + 1)` |
| `$items = [...$items, x]` | `this.set_items([...this.get_items(), x])` |

### Event shorthand (`@event`)

| Shorthand | Compiles to |
|-----------|-------------|
| `@click="increment()"` | `onClick="() => this.increment()"` |
| `@input="(e) => { $name = e.target.value }"` | `onInput="(e) => { this.set_name(e.target.value) }"` |
| `@mouseover="handleHover()"` | `onMouseover="() => this.handleHover()"` |

The `@event` shorthand:
1. Converts `@click` to `onClick`, `@input` to `onInput`, etc.
2. Wraps the value in `() =>` if it isn't already an arrow function
3. Applies `$var` and implicit `this` transformations to the body

### Implicit `this`

Bare method calls in event handlers and templates get `this.` prepended automatically. JavaScript globals (`console`, `Math`, `JSON`, `Date`, `fetch`, `Promise`, `window`, `document`, `store`, etc.) and arrow function parameters are left alone:

```yaml
methods:
  log: () => console.log($count)   # console is NOT prefixed
  process: (items) => items.map(x => x * 2)  # items, x are NOT prefixed
```

### Dynamic class binding

```yaml
html: |
  <div class:active="() => $isActive"
       class:error="() => $hasError">
    Status
  </div>
```

Adds or removes the CSS class based on the function's return value.

### Dynamic style binding

```yaml
html: |
  <p style:color="textColor">Colored text</p>
  <p style:fontSize="() => $size + 'px'">Sized text</p>
```

---

## 17. Single-File Components (.pup)

As an alternative to YAML, you can write pages and recipes using the `.pup` single-file component format. It uses `<script>`, `<style>`, and `<template>` blocks — familiar to developers who have used Vue or Svelte.

### Converting YAML to .pup

Here's the clicker recipe in both formats:

**YAML (`clicker.yaml`):**

```yaml
vars:
  count: 0
  title: 'clicked'

methods:
  inc: () => { $count = $count + 1 }

html: |
  <button @click="inc()">${title} ${count} times</button>
```

**SFC (`clicker.pup`):**

```html
<script>
{
  vars: { count: 0, title: 'clicked' },
  methods: {
    inc: () => { $count = $count + 1 }
  }
}
</script>

<template>
<button @click="inc()">${title} ${count} times</button>
</template>
```

Both produce identical compiled output.

### Available blocks

| Block | YAML equivalent |
|-------|----------------|
| `<script>` | Top-level keys (`vars`, `methods`, `computed`, `lifecycle`, `import`, `routes`, etc.) |
| `<style>` | `css` |
| `<style lang="less">` | `less` |
| `<template>` | `html` |
| `<template name="variant">` | `html_variant` |
| `<script recipe="name">` | `recipes.name` fields |
| `<template recipe="name">` | `recipes.name.html` |

### Script syntax

The `<script>` block contains a JS object literal. Comments (`//`, `/* */`) and trailing commas are allowed:

```html
<script>
{
  // page title
  title: 'My Page',

  vars: {
    count: 0,
    items: ["Apple", "Banana"],
  },

  computed: {
    doubled: () => $count * 2,
  },

  methods: {
    increment: () => { $count = $count + 1 },
    /* reset counter */
    reset: () => { $count = 0 },
  },

  lifecycle: {
    onMount: () => console.log('ready'),
  },
}
</script>
```

### Styling

```html
<!-- Raw CSS -->
<style>
button { background: skyblue; }
</style>

<!-- LESS -->
<style lang="less">
@primary: #3498db;
.btn {
  background: @primary;
  &:hover { background: darken(@primary, 10%); }
}
</style>
```

### Sub-recipes

Use the `recipe` attribute on script and template blocks:

```html
<script recipe="counter">
{
  vars: { count: 0 },
  methods: { inc: () => { $count = $count + 1 } }
}
</script>

<template recipe="counter">
<button @click="inc()">*{count}</button>
</template>

<template>
<h1>Main Component</h1>
<counter/>
</template>
```

### Using .pup files

`.pup` files work everywhere `.yaml` files do. The server, compiler, and watcher handle them automatically:

```bash
# These all work with .pup files
pupserver              # serves .pup pages
pupserver --compile    # compiles .pup files
pupserver --watch      # watches for .pup changes
```

When importing, you can reference either format — Spiderpup tries `.yaml` first, then `.pup`:

```yaml
import:
  card: /recipes/card.yaml    # explicit .yaml
  clicker: /recipes/clicker   # auto-resolves to .yaml or .pup
```

---

## 18. Compilation and Deployment

### Development workflow

1. Run `SPIDERPUP_NO_CACHE=1 pupserver`
2. Edit YAML files
3. Refresh your browser to see changes

Or use watch mode to auto-compile:

```bash
pupserver --watch 2
```

### Static compilation

Compile everything for deployment behind a standard web server (Apache, Nginx):

```bash
pupserver --compile
```

This generates:
- `www/webroot/html/*.html` — compiled page files
- `www/webroot/js/pages/*.js` — compiled page JavaScript
- `www/webroot/js/*.js` — compiled module JavaScript

Serve the `www/webroot/` directory with any web server.

### Behind a reverse proxy

If your app lives at a subpath (e.g., `https://example.com/myapp`):

```bash
pupserver --base-url-path /myapp
```

This adjusts all internal URLs and import paths to work under the given prefix.

### Cache behavior

- Compiled HTML is cached in `www/webroot/html/`
- Metadata files (`.meta`) track all YAML dependencies including imports
- Cache auto-invalidates when any referenced YAML file is modified
- Set `SPIDERPUP_NO_CACHE=1` to disable caching entirely

---

## 19. Using an External Web Server

You can serve your Spiderpup project with Apache (or Nginx) instead of `pupserver`. During development, run `pupserver --watch` alongside Apache — it recompiles YAML files whenever they change, and Apache serves the compiled output from `www/webroot/`.

### Development setup

1. Point Apache's `DocumentRoot` at your project's `www/webroot/` directory.
2. Run `pupserver --watch` in a separate terminal to keep compiled files up to date:

```bash
pupserver --watch 2
```

Edit your YAML files, and within a couple of seconds the compiled HTML and JS in `webroot/` are refreshed. Reload the browser to see changes.

### Apache configuration

A minimal virtual host that serves the compiled output with clean URLs:

```apache
<VirtualHost *:80>
    ServerName myapp.local
    DocumentRoot /path/to/my-project/www/webroot

    <Directory /path/to/my-project/www/webroot>
        Options -Indexes +FollowSymLinks
        AllowOverride None
        Require all granted

        # Clean URLs: /about resolves to /about.html
        RewriteEngine On
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteCond %{REQUEST_FILENAME} !-d
        RewriteCond %{REQUEST_FILENAME}.html -f
        RewriteRule ^(.+)$ $1.html [L]
    </Directory>
</VirtualHost>
```

This lets you visit `/about` instead of `/about.html`. Static assets (JS, CSS, images) are served directly since they exist as real files.

### SPA routing

If your app uses client-side routing (section 13), all route paths need to resolve to the page's HTML file. Add a fallback rule so Apache sends unmatched requests to your SPA entry point:

```apache
        # After the clean-URL rules above:
        # SPA fallback — send unknown paths to index.html
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteCond %{REQUEST_FILENAME} !-d
        RewriteRule ^ index.html [L]
```

### Deploying to production

For production, compile once and serve the output statically — no need for `pupserver` to be running:

```bash
pupserver --compile
```

Copy or deploy the `www/webroot/` directory to your server. The Apache configuration above works the same way for production.

### Serving from a subpath

If your app lives at `https://example.com/myapp/`, compile with `--base-url-path` so internal URLs are correct:

```bash
pupserver --base-url-path /myapp --compile
```

Then configure Apache to serve from that path:

```apache
Alias /myapp /path/to/my-project/www/webroot

<Directory /path/to/my-project/www/webroot>
    Options -Indexes +FollowSymLinks
    AllowOverride None
    Require all granted

    RewriteEngine On
    RewriteBase /myapp/

    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteCond %{REQUEST_FILENAME}.html -f
    RewriteRule ^(.+)$ $1.html [L]
</Directory>
```

---

## Putting It All Together

Here's a complete mini-app that demonstrates most features — a todo list with components, styling, reactivity, and conditionals:

```yaml
# www/pages/index.yaml
title: Todo App

less: |
  @primary: #3498db;
  @danger: #e74c3c;
  @spacing: 10px;

  .border-radius(@r) { border-radius: @r; }

  .todo-app {
    max-width: 500px;
    margin: 40px auto;
    font-family: sans-serif;

    input {
      border: 2px solid @primary;
      padding: @spacing;
      width: 60%;
      .border-radius(4px);
    }

    .btn {
      padding: @spacing;
      color: white;
      border: none;
      cursor: pointer;
      .border-radius(4px);

      &.add { background: @primary; }
      &.add:hover { background: darken(@primary, 10%); }
      &.remove { background: @danger; font-size: 12px; }
      &.remove:hover { background: darken(@danger, 10%); }
    }

    .done { text-decoration: line-through; color: #999; }
  }

vars:
  todos: []
  newTodo: ""

computed:
  totalCount: () => $todos.length
  doneCount: () => $todos.filter(t => t.done).length

methods:
  addTodo: |
    () => {
      const text = $newTodo.trim();
      if (text) {
        $todos = [...$todos, { text: text, done: false }];
        $newTodo = '';
      }
    }
  toggleTodo: |
    (mod, item) => {
      item.done = !item.done;
    }
  removeTodo: |
    (mod, item) => {
      $todos = $todos.filter(t => t !== item);
    }

html: |
  <div class="todo-app">
    <h1>Todo List</h1>
    <p>${doneCount} / ${totalCount} completed</p>

    <input @input="(e) => { $newTodo = e.target.value }"
           @keydown="(e) => { if(e.key==='Enter') this.addTodo() }"
           placeholder="What needs doing?" />
    <button class="btn add" @click="addTodo()">Add</button>

    <if condition="() => $todos.length === 0">
      <p>Nothing to do yet. Add a task above.</p>
    </if>

    <div for="$todos">
      <div>
        <input type="checkbox"
               @click="(mod, item) => { item.done = !item.done }" />
        <span class:done="(mod, item) => item.done"
              textContent="(mod, item) => item.text"></span>
        <button class="btn remove"
                @click="removeTodo()">x</button>
      </div>
    </div>
  </div>
```

---

## Quick Reference

### YAML fields at a glance

These fields work in both `.yaml` and `.pup` script blocks:

```yaml
title: Page Title
css: |
  /* raw CSS */
less: |
  /* LESS with variables, nesting, mixins */
import:
  name: /path/to/component.yaml
import-css:
  - https://cdn.example.com/style.css
import-js:
  - https://cdn.example.com/lib.js
include-js:
  - local/script.js
initial_store:
  key: value
vars:
  name: default_value
computed:
  derived: () => $name + ' computed'
methods:
  doThing: () => { $name = 'new value' }
lifecycle:
  onMount: () => { /* component is in DOM */ }
  onDestroy: () => { /* cleanup */ }
routes:
  /: home
  /about: about
  /item/:id: itemView
html: |
  <!-- your template -->
recipes:
  subName:
    vars: { ... }
    html: |
      <!-- sub-recipe template -->
```

### HTML template special elements

| Element | Purpose |
|---------|---------|
| `<if condition="...">` | Conditional rendering |
| `<elseif condition="...">` | Additional condition branch |
| `<else>` | Fallback branch |
| `<slot/>` | Default content insertion point |
| `<slot name="x"/>` | Named content insertion point |
| `<router-view/>` | Route component outlet |
| `<link to="/path">` | Client-side navigation link |

### HTML template special attributes

| Attribute | Purpose |
|-----------|---------|
| `for="$array"` | Loop over array |
| `textContent="(mod, item, idx) => ..."` | Dynamic text content |
| `class:name="() => bool"` | Toggle CSS class |
| `style:prop="value"` | Dynamic inline style |
| `@event="handler"` | Event handler shorthand |
| `slot="name"` | Target a named slot |
| `transition="fade\|slide"` | Animation on conditional |
| `!name="id"` | Register component instance; second use reuses existing instance (shared state) |
