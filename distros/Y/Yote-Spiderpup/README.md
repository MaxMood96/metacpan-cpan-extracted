# Spiderpup

A lightweight web framework with reactive components, written in Perl and JavaScript. Author components in YAML or single-file `.pup` format.

## Features

- **Declarative components** - Define UI with YAML or single-file `.pup` syntax
- **Reactive data binding** - Computed properties with automatic updates
- **Shorthand syntax** - `$var` for getters/setters, `@click` for events, implicit `this`
- **LESS compiler** - Variables, nesting, mixins, color functions, math (via CSS::LESSp)
- **Component composition** - Imports, slots, broadcast/receive, event bubbling
- **SPA routing** - Client-side navigation with route parameters
- **Transitions** - Animated conditional rendering (fade, slide)
- **Developer experience** - Error overlays, HTML caching, base path support

## Architecture

Spiderpup uses a two-part architecture:

1. **pupserver** - A Perl HTTP server that:
   - Loads YAML and `.pup` page definitions
   - Compiles LESS to CSS
   - Transforms shorthand syntax (`$var`, `@click`, implicit `this`)
   - Parses HTML templates into JSON structures
   - Generates JavaScript class definitions
   - Caches compiled HTML for performance
   - Serves static files (JS, CSS, raw YAML)

2. **www/webroot/js/spiderpup.js** - A client-side JavaScript runtime that:
   - Provides the `Recipe` base class for components
   - Handles reactive rendering and updates
   - Manages component lifecycle (mount/destroy)
   - Implements control flow (`if`/`elseif`/`else`, `for` loops)
   - Supports slots for component composition
   - Provides broadcast/receive messaging between components
   - Handles event bubbling via `emit`/`on`

## Getting Started

### Running the Server

```bash
pupserver
```

The server runs on `http://localhost:5000` by default.

### Project Structure

```
spiderpup/
├── bin/
│   └── pupserver         # Perl web server
├── lib/
│   └── Yote/Spiderpup/   # Server-side modules
│       ├── SFC.pm         # Single-file component (.pup) parser
│       └── Transform.pm   # Expression transformer
└── www/                   # Web root directory
    ├── webroot/           # Static assets (servable by any webserver)
    │   ├── js/            # JavaScript
    │   │   └── spiderpup.js  # Client-side runtime
    │   ├── css/           # CSS stylesheets
    │   └── *.html         # Compiled page files
    ├── pages/             # Page definitions (YAML or .pup)
    │   ├── index.yaml     # Served at /
    │   ├── about.yaml     # Served at /about
    │   └── mydir/         # Subdirectory
    │       └── index.yaml # Served at /mydir
    └── recipes/           # Reusable components
        ├── card.yaml      # Imported as /recipes/card
        ├── clicker.pup    # .pup format also works
        └── ...
```

### URL Routing

URLs map to pages as follows:

| URL | Page File |
|-----|-----------|
| `/` | `www/pages/index.yaml` (or `index.pup`) |
| `/about` | `www/pages/about.yaml` (or `about.pup`) |
| `/mydir` | `www/pages/mydir/index.yaml` (or `index.pup`) |
| `/mydir/dashboard` | `www/pages/mydir/dashboard.yaml` (or `dashboard.pup`) |

Both `.yaml` and `.pup` files are supported. When both exist, `.yaml` takes precedence.

Recipes in `www/recipes/` are not directly accessible via URL. They are only available for import by pages and other recipes.

## Single-File Components (.pup)

As an alternative to YAML, you can author pages and recipes using the `.pup` single-file component format. This uses `<script>`, `<style>`, and `<template>` blocks, similar to Vue or Svelte.

### Basic Example

```html
<script>
{
  vars: { count: 0, title: 'clicked' },
  methods: {
    inc: () => { $count = $count + 1 }
  }
}
</script>

<style>
button { background: skyblue; padding: 10px; }
</style>

<template>
<button @click="inc()">${title} ${count} times</button>
</template>
```

### Block Reference

| Block | Maps to | Notes |
|-------|---------|-------|
| `<script>` | Top-level fields (`vars`, `methods`, etc.) | JS object literal syntax |
| `<style>` | `css` | Raw CSS |
| `<style lang="less">` | `less` | LESS stylesheet |
| `<template>` | `html` | HTML template |
| `<template name="compact">` | `html_compact` | Variant template |
| `<script recipe="name">` | `recipes.name.*` | Sub-recipe fields |
| `<template recipe="name">` | `recipes.name.html` | Sub-recipe template |

### Script Block Syntax

The `<script>` block contains a JavaScript object literal (with or without outer braces). Keys are the same fields as YAML (`vars`, `methods`, `computed`, `lifecycle`, `import`, `routes`, etc.).

Function-context keys (`methods`, `computed`, `lifecycle`, `watch`) keep their values as raw expressions — the same strings you would write in YAML:

```html
<script>
{
  title: 'My Page',
  vars: { count: 0, name: 'World' },
  computed: {
    greeting: () => `Hello, ${$name}!`
  },
  methods: {
    increment: () => { $count = $count + 1 },
    reset: () => { $count = 0 }
  },
  lifecycle: {
    onMount: () => console.log('mounted')
  }
}
</script>
```

Comments (`//` and `/* */`) and trailing commas are supported.

### Sub-Recipes

Define sub-recipes using `recipe="name"` on script and template blocks:

```html
<script recipe="clicker">
{
  vars: { count: 0 },
  methods: { inc: () => { $count = $count + 1 } }
}
</script>

<template recipe="clicker">
<button @click="inc()">*{count}</button>
</template>

<script>
{
  title: 'Parent Component'
}
</script>

<template>
<h1>My Component</h1>
<clicker/>
</template>
```

### YAML vs .pup

Both formats produce identical compiled output. Choose based on preference:

| | YAML | .pup |
|---|------|------|
| Syntax | Indentation-based | Block-based (`<script>`, `<style>`, `<template>`) |
| IDE support | YAML highlighting | HTML/JS highlighting |
| Familiarity | Perl developers | Vue/Svelte developers |
| Multi-line JS | Requires YAML `\|` blocks | Natural JS syntax |

## Page Definition (YAML)

Each page is defined in a YAML file with the following fields:

### Basic Structure

```yaml
title: My Page Title
css: |
  button { background-color: blue; }
less: |
  @primary: #333;
  div {
    color: @primary;
    &:hover { color: red; }
  }
import:
  foo: /foo.yaml
  bar: /bar.yaml
vars:
  count: 0
  name: "World"
methods:
  increment: () => { $count = $count + 1 }
html: |
  <h1>Hello, $name!</h1>
  <button @click="increment()">Click me</button>
```

### Fields Reference

| Field | Description |
|-------|-------------|
| `title` | Page title (appears in browser tab) |
| `css` | Raw CSS styles (scoped to the page) |
| `less` | LESS styles (compiled to CSS, scoped to the page) |
| `import` | Map of component namespaces to YAML file paths |
| `vars` | Reactive variables with initial values |
| `computed` | Derived values that auto-update when dependencies change |
| `watch` | *(Planned)* Callbacks triggered when specific variables change |
| `methods` | JavaScript functions available to the page |
| `lifecycle` | Hooks for mount/destroy events (`onMount`, `onDestroy`) |
| `routes` | SPA route definitions (path → component mapping) |
| `initial_store` | Initialize global store values (see Global Store section) |
| `import-css` | Array of external CSS file URLs to include via `<link>` tags |
| `import-js` | Array of external JS file URLs to include via `<script src>` tags |
| `include-js` | Array of local JS files to inline directly in the page `<head>` |
| `html` | HTML template with special syntax |

## Styling

### CSS

Standard CSS in the `css` field is automatically scoped to the page namespace:

```yaml
css: |
  button { background-color: skyblue; }
  .highlight { color: red; }
```

### LESS

The `less` field supports a subset of LESS syntax:

#### Variables

Define variables with `@name: value;` and use them anywhere:

```less
@primary-color: #3498db;
@spacing: 10px;

div {
  color: @primary-color;
  padding: @spacing;
}
```

#### Nesting

Nest selectors for cleaner, more organized styles:

```less
nav {
  background: #333;

  ul {
    list-style: none;

    li {
      display: inline-block;
    }
  }
}
```

Compiles to:

```css
nav { background: #333; }
nav ul { list-style: none; }
nav ul li { display: inline-block; }
```

## External Assets

Include external CSS and JavaScript files in your pages.

### External CSS (`import-css`)

Include CSS files via `<link>` tags:

```yaml
import-css:
  - https://cdn.example.com/normalize.css
  - /styles/theme.css
```

### External JavaScript (`import-js`)

Include JavaScript files via `<script src>` tags:

```yaml
import-js:
  - https://cdn.example.com/library.js
  - /scripts/utils.js
```

### Inline JavaScript (`include-js`)

Include local JavaScript files with their contents inlined directly in the page `<head>`:

```yaml
include-js:
  - lib/helper.js
  - utils/data.js
```

This differs from `import-js` in that:
- **`import-js`**: Adds `<script src="..."></script>` tags (files loaded separately)
- **`include-js`**: Reads file contents and embeds them inline in a `<script>` tag

Use `include-js` when you want to:
- Bundle small utility libraries directly into the page
- Avoid additional HTTP requests for local scripts
- Ensure scripts are available immediately without network delays

File paths are resolved relative to the `www/` directory.

#### Parent Selector (&)

Reference the parent selector with `&`:

```less
button {
  background: blue;

  &:hover {
    background: darkblue;
  }

  &.active {
    background: green;
  }

  &-icon {
    margin-right: 5px;
  }
}
```

Compiles to:

```css
button { background: blue; }
button:hover { background: darkblue; }
button.active { background: green; }
button-icon { margin-right: 5px; }
```

#### Mixins

Define reusable style blocks with parameters:

```less
.border-radius(@r) {
  border-radius: @r;
}

.box-shadow(@x, @y, @blur, @color) {
  box-shadow: @x @y @blur @color;
}

.card {
  .border-radius(8px);
  .box-shadow(0, 2px, 4px, rgba(0,0,0,0.1));
}
```

#### Color Functions

Manipulate colors dynamically:

```less
@primary: #3498db;

.button {
  background: @primary;

  &:hover {
    background: darken(@primary, 10%);  // Darker shade
  }

  &:active {
    background: darken(@primary, 20%);
  }

  &.light {
    background: lighten(@primary, 30%);  // Lighter shade
  }

  &.blend {
    background: mix(@primary, #e74c3c, 50%);  // Blend two colors
  }
}
```

Available functions:
- `darken(@color, amount%)` - Decrease lightness
- `lighten(@color, amount%)` - Increase lightness
- `mix(@color1, @color2, weight%)` - Blend two colors

#### Math Operations

Perform calculations with units:

```less
@base: 10px;
@columns: 12;

.container {
  padding: @base * 2;        // 20px
  margin: @base + 5px;       // 15px
  width: 100% / @columns;    // 8.333...%
  font-size: @base * 1.5;    // 15px
}
```

Supports `+`, `-`, `*`, `/` with automatic unit preservation.

#### Combined Example

```less
@brand: #e74c3c;
@spacing: 10px;

.border-radius(@r) {
  border-radius: @r;
}

.card {
  border: 1px solid @brand;
  padding: @spacing * 2;
  .border-radius(8px);

  h2 {
    color: @brand;
  }

  &:hover {
    border-color: darken(@brand, 15%);
  }

  &.featured {
    background: lighten(@brand, 40%);
  }
}
```

## Reactive Variables

### Defining Variables

```yaml
vars:
  count: 0
  name: "Guest"
  items: ["apple", "banana", "cherry"]
```

### Using Variables in HTML

Interpolate variables with `$varName` or `${varName}`:

```yaml
html: |
  <p>Hello, $name!</p>
  <p>Count: $count</p>
```

### Accessing Variables in Methods

Use shorthand `$var` syntax or auto-generated getters/setters:

```yaml
methods:
  # Shorthand syntax
  increment: () => { $count = $count + 1 }
  reset: () => { $count = 0 }
  greet: () => alert('Hello, ' + $name)

  # Traditional syntax (also works)
  # increment: () => this.set_count(this.get_count() + 1)
```

### Computed Properties

Define derived values that auto-update:

```yaml
vars:
  firstName: "John"
  lastName: "Doe"
  items: []

computed:
  fullName: () => `${$firstName} ${$lastName}`
  itemCount: () => $items.length
  isEmpty: () => $items.length === 0

html: |
  <h1>Welcome, ${fullName}!</h1>
  <p>You have ${itemCount} items</p>
```

### Watchers (Planned)

> **Note:** The `watch` field is planned but not yet implemented in the current version.

React to variable changes:

```yaml
vars:
  count: 0
  searchQuery: ""

watch:
  count: (newVal, oldVal) => console.log(`Count changed: ${oldVal} → ${newVal}`)
  searchQuery: (newVal) => performSearch(newVal)

methods:
  performSearch: (query) => console.log('Searching for:', query)
```

## Global Store

A reactive global store for cross-component state sharing. The store is a global hashtable that triggers reactivity across all components when values change.

### Initializing the Store

Use the `initial_store` field in your page YAML to initialize store values:

```yaml
initial_store:
  user: null
  cart: []
  theme: light

html: |
  <p>Theme: ${store.get('theme')}</p>
  <button @click="store.set('theme', 'dark')">Dark Mode</button>
```

Store values are initialized before your `onMount` lifecycle hook runs.

### Store API

| Method | Description |
|--------|-------------|
| `store.get(key)` | Get a value from the store |
| `store.set(key, value)` | Set a value and trigger refresh on all components |
| `store.init({...})` | Initialize multiple values at once (no refresh triggered) |
| `store.watch(key, fn)` | Register a callback for when a specific key changes |

### Usage Examples

**Reading store values:**

```yaml
html: |
  <p>User: ${store.get('user')?.name || 'Guest'}</p>
  <p>Cart items: ${store.get('cart').length}</p>
```

**Writing store values:**

```yaml
methods:
  addToCart: |
    (item) => {
      const cart = store.get('cart');
      store.set('cart', [...cart, item]);
    }
  setUser: |
    (user) => {
      store.set('user', user);
    }

html: |
  <button @click="addToCart({ id: 1, name: 'Widget' })">Add to Cart</button>
```

**Watching for changes:**

```yaml
lifecycle:
  onMount: |
    () => {
      store.watch('user', (newUser, oldUser) => {
        console.log('User changed:', oldUser, '->', newUser);
      });
    }
```

**Cross-component state sharing:**

```yaml
# Component A - updates the store
methods:
  login: |
    (userData) => {
      store.set('user', userData);
    }

# Component B - reads from the store (automatically updates)
html: |
  <if condition="() => store.get('user')">
    <p>Welcome, ${store.get('user').name}!</p>
  </if>
  <else>
    <p>Please log in</p>
  </else>
```

### Console Access

The store is available globally as `window.store` for debugging:

```javascript
// In browser console
store.get('user')
store.set('theme', 'dark')
```

### Class Binding

Dynamically toggle CSS classes:

```yaml
vars:
  isActive: false
  hasError: false

html: |
  <div class:active="() => $isActive"
       class:error="() => $hasError">
    Status indicator
  </div>
  <button @click="$isActive = !$isActive">
    Toggle
  </button>
```

### Style Binding

Dynamically set inline styles:

```yaml
vars:
  textColor: "blue"
  fontSize: 16

html: |
  <!-- Simple variable binding -->
  <p style:color="textColor">Colored text</p>

  <!-- Function binding -->
  <p style:fontSize="() => $fontSize + 'px'">Sized text</p>
```

## Event Handlers

Attach event handlers with `on[Event]` attributes:

```yaml
html: |
  <button onClick="() => this.increment()">Add</button>
  <button onClick="() => this.reset()">Reset</button>
  <input onInput="(e) => this.set_name(e.target.value)" />
```

The UI automatically refreshes after event handlers execute.

## Shorthand Syntax

Spiderpup provides shorthand syntax to reduce boilerplate and improve readability. All transformations happen at compile time, and the traditional syntax remains fully supported.

### Variable Shorthand (`$var`)

Use `$var` instead of `this.get_var()` and `$var = value` instead of `this.set_var(value)`:

```yaml
# Traditional syntax
methods:
  increment: () => this.set_count(this.get_count() + 1)
  double: () => this.set_count(this.get_count() * 2)

# Shorthand syntax
methods:
  increment: () => { $count = $count + 1 }
  double: () => { $count = $count * 2 }
```

Works in methods, computed properties, watchers, lifecycle hooks, conditions, and event handlers:

```yaml
computed:
  doubleCount: () => $count * 2
  greeting: () => "Hello, " + $name + "!"

watch:
  count: (newVal) => console.log("Count is now:", newVal)

html: |
  <if condition="() => $count > 10">
    <p>Count is high!</p>
  </if>
```

Complex assignments are supported:

```yaml
methods:
  addItem: () => { $items = [...$items, "New Item"] }
  reset: () => { $count = 0; $name = "Guest" }
```

### Event Shorthand (`@event`)

Use `@click` instead of `onClick="() => ..."`:

```yaml
# Traditional syntax
html: |
  <button onClick="() => this.increment()">+1</button>
  <button onClick="() => this.set_count(0)">Reset</button>

# Shorthand syntax
html: |
  <button @click="increment()">+1</button>
  <button @click="$count = 0">Reset</button>
```

The `@event` syntax:
- Converts `@click` to `onClick`, `@mouseover` to `onMouseover`, etc.
- Automatically wraps the value in `() =>` if not already an arrow function
- Combines well with `$var` and implicit `this`

All standard DOM events work: `@click`, `@input`, `@change`, `@mouseover`, `@keydown`, etc.

### Implicit `this`

Bare method calls are automatically prefixed with `this.`:

```yaml
# Traditional syntax
html: |
  <button onClick="() => this.increment()">+1</button>
  <button onClick="() => this.reset()">Reset</button>

# Shorthand syntax (implicit this)
html: |
  <button @click="increment()">+1</button>
  <button @click="reset()">Reset</button>
```

JavaScript globals (`console`, `Math`, `JSON`, `Date`, `fetch`, `Promise`, etc.) and arrow function parameters are not prefixed:

```yaml
methods:
  log: () => console.log("Count:", $count)  # console is not prefixed
  process: (items) => items.map(x => x * 2)  # items and x are not prefixed
```

### Combined Example

Before (traditional):

```yaml
vars:
  count: 0
  name: "World"

methods:
  increment: () => this.set_count(this.get_count() + 1)
  reset: () => this.set_count(0)

computed:
  greeting: () => "Hello, " + this.get_name()

html: |
  <p>$greeting</p>
  <p>Count: $count</p>
  <button onClick="() => this.increment()">+1</button>
  <button onClick="() => this.set_count(this.get_count() - 1)">-1</button>
  <button onClick="() => this.reset()">Reset</button>
  <input onInput="(e) => this.set_name(e.target.value)" />
  <if condition="() => this.get_count() > 5">
    <p>Count is high!</p>
  </if>
```

After (shorthand):

```yaml
vars:
  count: 0
  name: "World"

methods:
  increment: () => { $count = $count + 1 }
  reset: () => { $count = 0 }

computed:
  greeting: () => "Hello, " + $name

html: |
  <p>$greeting</p>
  <p>Count: $count</p>
  <button @click="increment()">+1</button>
  <button @click="$count = $count - 1">-1</button>
  <button @click="reset()">Reset</button>
  <input @input="(e) => { $name = e.target.value }" />
  <if condition="() => $count > 5">
    <p>Count is high!</p>
  </if>
```

### Backward Compatibility

All traditional syntax continues to work:

```yaml
# You can mix styles freely
methods:
  increment: () => { $count = $count + 1 }                    # shorthand
  decrement: () => this.set_count(this.get_count() - 1)       # traditional

html: |
  <button @click="increment()">+1 (shorthand)</button>
  <button onClick="() => this.decrement()">-1 (traditional)</button>
```

## Control Flow

### Conditionals

Use `<if>`, `<elseif>`, and `<else>` tags:

```yaml
html: |
  <if condition="() => $count < 10">
    <p>Count is small</p>
  </if>
  <elseif condition="() => $count < 50">
    <p>Count is medium</p>
  </elseif>
  <else>
    <p>Count is large</p>
  </else>
```

### Transitions

Add animations when conditionals change:

```yaml
html: |
  <if condition="() => $isVisible" transition="fade">
    <div>This content fades in/out</div>
  </if>

  <if condition="() => $isOpen" transition="slide">
    <div>This content slides in/out</div>
  </if>
```

Built-in transitions: `fade`, `slide`

### Loops

Use the `for` attribute on any element to iterate:

```yaml
html: |
  <!-- Static array -->
  <ul for="[1, 2, 3]">
    <li textContent="(mod, item, idx) => `Item ${idx}: ${item}`"></li>
  </ul>

  <!-- Dynamic from vars (shorthand) -->
  <ul for="$items">
    <li textContent="(mod, item, idx) => item.toUpperCase()"></li>
  </ul>

  <!-- Dynamic from vars (traditional) -->
  <ul for="() => this.get_items()">
    <li textContent="(mod, item, idx) => item.toUpperCase()"></li>
  </ul>
```

## Components

### Importing Components

```yaml
import:
  button: /recipes/button.yaml
  card: /recipes/card.yaml
```

### Using Components

Use the namespace as the tag name, passing vars as attributes:

```yaml
html: |
  <button label="Click me" color="blue" />
  <card title="My Card">
    <p>Card content here</p>
  </card>
```

### Component Definition

Components are just pages that receive attributes as vars:

```yaml
# www/recipes/button.yaml
title: Button Component
vars:
  label: "Button"
  color: "gray"
css: |
  button { padding: 10px 20px; }
html: |
  <button style="background-color: $color">$label</button>
```

### Slots

Slots allow you to pass content into components. Slot content is **scoped to the component** that defines the slot, giving it access to the component's variables and methods.

#### Default Slot

Use `<slot/>` to define where child content appears:

```yaml
# www/recipes/card.yaml
title: Card Component
vars:
  title: "Card"
  theme: "light"
html: |
  <div class="card">
    <h2>$title</h2>
    <div class="card-content">
      <slot/>
    </div>
  </div>
```

Usage:

```yaml
import:
  card: /recipes/card.yaml

html: |
  <card title="My Card">
    <p>Theme is: $theme</p>  <!-- Accesses card's $theme, not page's -->
    <button>Action</button>
  </card>
```

#### Implicit Default Slot

If a component has no `<slot/>` defined, the **first element** in its template is used as the default slot target:

```yaml
# www/recipes/wrapper.yaml - no explicit slot
html: |
  <div class="wrapper">
    <span>Header</span>
  </div>

# Usage - content goes into the first div
html: |
  <wrapper>
    <p>This appears inside div.wrapper</p>
  </wrapper>
```

#### Named Slots

Use the `name` attribute on `<slot>` and target with `slot="name"`:

```yaml
# www/recipes/panel.yaml
vars:
  collapsed: false
html: |
  <div class="panel">
    <div class="panel-header">
      <slot name="header"/>
      <button @click="$collapsed = !$collapsed">Toggle</button>
    </div>
    <div class="panel-body">
      <slot/>  <!-- Default slot -->
    </div>
    <div class="panel-footer">
      <slot name="footer"/>
    </div>
  </div>
```

Usage:

```yaml
import:
  panel: /recipes/panel.yaml

html: |
  <panel>
    <h3 slot="header">Panel Title</h3>
    <p>Main content goes to default slot</p>
    <p>More content here</p>
    <div slot="footer">
      <button @click="$collapsed = true">Close</button>  <!-- Uses panel's $collapsed -->
    </div>
  </panel>
```

#### Slot Scoping

Slot content is scoped to the **enclosing component**, not the parent that provides the content. This allows slot content to interact with the component's internal state:

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

# page.yaml
import:
  counter: /recipes/counter.yaml
vars:
  pageVar: "from page"

html: |
  <counter>
    <!-- These access counter's scope -->
    <p>Count: $count</p>
    <button @click="increment()">Add</button>

    <!-- To access page scope, use parentModule -->
    <p textContent="() => this.parentModule.get_pageVar()"></p>
  </counter>
```

#### Accessing Parent Scope

From within slot content, use `this.parentModule` to access the parent's variables:

```yaml
# Slot content can reach up the component tree
<p textContent="() => this.parentModule.get_someVar()"></p>
<button @click="() => this.parentModule.someMethod()">Call Parent</button>
```

This pattern allows slot content to:
- Default to component scope (most common use case)
- Explicitly access parent scope when needed
- Chain multiple levels: `this.parentModule.parentModule.get_var()`

### Named Instances (`!name`)

Use `!name` to register a component instance for programmatic access via `this.instances.<name>`:

```yaml
import:
  myzippy: /recipes/zippy.yaml

lifecycle:
  onMount: |
    () => {
      console.log(this.instances.zip.get_color());
    }

html: |
  <myzippy color="blue" !name="zip">
    <h2>Content inside zippy</h2>
  </myzippy>
```

When the same `!name` appears a second time, the existing instance is **reused** — both DOM locations share the same state:

```yaml
html: |
  <myzippy color="blue" !name="zip">
    <h2>Slot content</h2>
  </myzippy>

  <!-- Reuses the same instance; updates at either location are reflected in both -->
  <myzippy !name="zip"></myzippy>
```

Shared behavior:
- Same vars, state, and child recipes across both locations
- `onMount` fires only once
- Clicking a button at either location updates the count everywhere

### Refs (Planned)

> **Note:** The `ref` attribute is planned but not yet implemented in the current version.

Access DOM elements and component instances directly:

```yaml
vars:
  value: ""

methods:
  focusInput: () => this.refs.myInput.focus()
  clearInput: |
    () => {
      this.refs.myInput.value = '';
      this.refs.myInput.focus();
    }

html: |
  <input ref="myInput" @input="(e) => { $value = e.target.value }"/>
  <button @click="focusInput()">Focus</button>
  <button @click="clearInput()">Clear</button>
```

For components, `ref` gives you the component instance:

```yaml
html: |
  <myComponent ref="comp"/>
  <button onClick="() => this.refs.comp.someMethod()">Call Method</button>
```

### Lifecycle Hooks

Execute code when components mount or unmount:

```yaml
lifecycle:
  onMount: |
    () => {
      console.log('Component mounted!');
      // Component is now in the DOM
    }
  onDestroy: |
    () => {
      console.log('Component destroyed!');
      // Cleanup timers, listeners, etc.
    }
```

### Broadcast / Receive

Enable communication between components using a pub/sub pattern:

```yaml
# Component A - broadcasts messages
methods:
  notifyAll: |
    () => {
      this.broadcast('user-updated', { id: 123, name: 'John' });
    }
  sendAlert: |
    () => {
      this.broadcast('alert', { type: 'warning', message: 'Something happened!' });
    }

html: |
  <button @click="notifyAll()">Notify All</button>
```

```yaml
# Component B - receives messages
lifecycle:
  onMount: |
    () => {
      this.receive('user-updated', (data, sender) => {
        console.log('User updated:', data);
        $userName = data.name;
        this.refresh();
      });

      this.receive('alert', (data) => {
        alert(data.message);
      });
    }
```

Key points:
- `broadcast(channel, data)` sends to all modules except the sender
- `receive(channel, callback)` registers a handler for a channel
- Callback receives `(data, senderModule)` arguments
- Multiple receivers can listen to the same channel
- Useful for cross-component state sync, notifications, events

### Event Bubbling

Emit events that propagate up the component hierarchy (like DOM events):

```yaml
# Child component - emits events
methods:
  handleClick: |
    () => {
      // Emit event that bubbles up to parents
      this.emit('item-selected', { id: 42, name: 'Example' });
    }
  handleDelete: |
    () => {
      this.emit('item-deleted', { id: 42 });
    }

html: |
  <button @click="handleClick()">Select</button>
  <button @click="handleDelete()">Delete</button>
```

```yaml
# Parent component - handles events from children
import:
  childItem: /recipes/child-item.yaml

lifecycle:
  onMount: |
    () => {
      // Handle event and allow it to continue bubbling
      this.on('item-selected', (event) => {
        console.log('Item selected:', event.data);
        // Event continues to bubble up
      });

      // Handle event and stop propagation
      this.on('item-deleted', (event) => {
        console.log('Item deleted:', event.data);
        event.stopPropagation();  // Stop bubbling here
        // Or: return false;      // Also stops propagation
      });
    }

html: |
  <div>
    <childItem/>
    <childItem/>
  </div>
```

Event object properties:
- `event.name` - The event name
- `event.data` - The data passed to emit()
- `event.source` - The module that emitted the event
- `event.stopPropagation()` - Stop the event from bubbling further

Methods:
- `emit(name, data)` - Emit an event that bubbles up
- `on(name, handler)` - Register an event handler
- `off(name, handler?)` - Remove event handler(s)

## Client-Side Routing

Build single-page applications with client-side navigation.

### Defining Routes

```yaml
title: My App

import:
  home: /home
  about: /about
  user: /recipes/user

routes:
  /: home
  /about: about
  /user/:id: user

html: |
  <nav>
    <link to="/">Home</link>
    <link to="/about">About</link>
    <link to="/user/123">User 123</link>
  </nav>
  <router-view/>
```

### Route Parameters

Parameters in routes (`:id`) are passed as vars to the component:

```yaml
# www/recipes/user.yaml
title: User Profile
vars:
  id: ""

lifecycle:
  onMount: () => console.log('Viewing user:', this.get_id())

html: |
  <h1>User Profile</h1>
  <p>User ID: $id</p>
```

### Navigation Links

Use `<link to="...">` for client-side navigation (no page reload):

```yaml
html: |
  <link to="/about">Go to About</link>
  <link to="/user/456">View User 456</link>
```

## Complete Example

```yaml
title: Todo App
css: |
  .completed { text-decoration: line-through; }
less: |
  @primary: #3498db;

  .todo-app {
    max-width: 400px;

    input {
      border: 2px solid @primary;
      padding: 8px;
    }

    button {
      background: @primary;
      color: white;

      &:hover {
        background: darken(@primary, 10%);
      }
    }
  }
vars:
  todos: []
  newTodo: ""
methods:
  addTodo: |
    () => {
      const todo = $newTodo;
      if (todo) {
        $todos.push({ text: todo, done: false });
        $newTodo = '';
      }
    }
html: |
  <div class="todo-app">
    <h1>Todo List</h1>
    <input @input="(e) => { $newTodo = e.target.value }" placeholder="Enter a todo" />
    <button @click="addTodo()">Add</button>
    <div for="$todos">
      <div textContent="(mod, item) => item.text"></div>
    </div>
  </div>
```

## Server Options

```bash
# Default (port 5000)
pupserver

# Custom port
pupserver --port 3000

# Custom webroot directory
pupserver --webroot /var/www/mysite

# With base URL path for reverse proxy (e.g., Apache ProxyPass /myapp)
pupserver --base-url-path /myapp

# HTTPS with SSL certificate
pupserver --ssl-cert cert.pem --ssl-key key.pem

# HTTPS on custom port
pupserver --port 8443 --ssl-cert cert.pem --ssl-key key.pem

# Disable HTML caching (recompile on every request)
SPIDERPUP_NO_CACHE=1 pupserver
```

### Required Perl Modules

- `CSS::LESSp` - LESS to CSS compilation
- `YAML` - YAML parsing
- `JSON::PP` - JSON encoding
- `IO::Socket::INET` - HTTP server
- `IO::Socket::SSL` - HTTPS support (optional, required for `--ssl-cert`/`--ssl-key`)

## Caching

Spiderpup automatically caches compiled HTML to improve performance:

- Cache stored in `www/webroot/html/` (servable by any webserver)
- Tracks all YAML dependencies (including imports)
- Automatically invalidates when any referenced file changes
- Works across server restarts

## Error Handling

### Server-Side Errors

YAML parsing or compilation errors display a styled error overlay instead of crashing:

- Shows error message and location
- Styled overlay with dark theme
- Still allows hot reload to retry after fixes

### Client-Side Errors

Runtime JavaScript errors show a dismissible overlay:

- Catches uncaught exceptions
- Catches unhandled promise rejections
- Shows error message and stack trace
- Click "Dismiss" to close

## Comparison with Other Frameworks

| Feature | Spiderpup | React | Vue | BackdraftJS |
|---------|-----------|-------|-----|-------------|
| Template syntax | YAML + HTML or SFC (.pup) | JSX | SFC | Pure JS |
| Virtual DOM | No | Yes | Yes | No |
| Build step | None (runtime compilation) | Required | Optional | None |
| Client JS size | ~15KB | ~40KB | ~30KB | ~2KB |
| Styling | LESS built-in (server-side) | External | Scoped CSS | External |
| Routing | Built-in | External | External | None |
| Server | Perl (included) | Node/external | Node/external | None |
