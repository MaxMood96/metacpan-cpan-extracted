# Spiderpup API Reference

Technical reference for all public APIs, classes, methods, data structures, and compilation internals.

---

## Table of Contents

- [Client-Side Runtime (spiderpup.js)](#client-side-runtime)
  - [Recipe](#recipe)
  - [RecipeSlot](#recipeslot)
  - [RecipeLoop](#recipeloop)
  - [RecipeConditional](#recipeconditional)
  - [SpiderpupRouter](#spiderpuprouter)
  - [SpiderpupEvent](#spiderpupevent)
  - [Global Store](#global-store)
  - [Global Functions and Objects](#global-functions-and-objects)
- [YAML Schema](#yaml-schema)
  - [Page / Recipe Fields](#page--recipe-fields)
  - [Recipe Fields](#recipe-fields)
  - [HTML Template Syntax](#html-template-syntax)
  - [Structure Node Format](#structure-node-format)
- [SFC Module (Yote::Spiderpup::SFC)](#sfc-module)
  - [Exported Functions](#sfc-exported-functions)
- [Server (pupserver)](#server)
  - [CLI Options](#cli-options)
  - [Environment Variables](#environment-variables)
  - [Path Resolution Functions](#path-resolution-functions)
  - [Compilation Functions](#compilation-functions)
  - [Caching Functions](#caching-functions)
  - [SSR Functions](#ssr-functions)
  - [HTTP Server](#http-server)
- [Transform Module (Yote::Spiderpup::Transform)](#transform-module)
  - [Exported Functions](#exported-functions)

---

## Client-Side Runtime

File: `www/webroot/js/spiderpup.js`

The runtime is loaded as a standard `<script>` tag (not an ES module). It exposes the `Recipe` base class and related infrastructure on the global scope.

---

### Recipe

```
class Recipe
```

Base class for all compiled page and component classes. Generated subclasses extend this with `title`, `structure`, `vars`, `imports`, `routes`, and user-defined methods.

#### Instance Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `attrBindings` | `Array` | `[]` | Dynamic function-based attribute bindings |
| `bindings` | `Array` | `[]` | Two-way binding entries |
| `classBindings` | `Array` | `[]` | `class:*` binding entries |
| `conditions` | `Array` | `[]` | Tracked conditional nodes |
| `defaultSlot` | `RecipeSlot\|null` | `null` | Default slot instance for this component |
| `dirty` | `boolean` | `false` | Whether this component needs a re-render |
| `eventHandlers` | `Array<{node, eventName, handler}>` | `[]` | Registered DOM event listeners (for cleanup) |
| `eventListeners` | `Object<string, Function[]>` | `{}` | `on()`/`off()` handlers keyed by event name |
| `handlers` | `Array` | `[]` | General handler references |
| `imports` | `Object<string, class>` | `{}` | Map of tag name to imported component class |
| `instances` | `Object<string, Recipe>` | `{}` | Named component instances registered via `!name`. Second use of the same `!name` reuses the existing instance. |
| `_childByNode` | `Map\|null` | `null` | Maps structureNode references to child component instances, enabling shared instance reuse when a component re-renders its template at a second DOM location |
| `loops` | `Array` | `[]` | Tracked loop nodes |
| `moduleId` | `number\|null` | `null` | Index in `moduleRegistry` |
| `namedSlots` | `Object<string, RecipeSlot>` | `{}` | Named slot instances keyed by slot name |
| `parentModule` | `Recipe\|null` | `null` | Parent component in the tree (for event bubbling) |
| `receivers` | `Object<string, Function[]>` | `{}` | `receive()` handlers keyed by channel |
| `refs` | `Object<string, Element\|Recipe>` | `{}` | DOM element/component refs (planned) |
| `rootEl` | `Element` | — | Root DOM element of this component |
| `seenConditionals` | `Object<number, boolean>` | `{}` | Structure indices consumed by `if` chains |
| `styleBindings` | `Array` | `[]` | `style:*` binding entries |
| `updatableElements` | `Array<[structureNode, Element]>` | `[]` | Pairs of structure nodes and their DOM elements for refresh |
| `updatableRecipes` | `Array<Recipe>` | `[]` | Child Recipe instances to refresh |
| `vars` | `Object` | `{}` | Reactive variable store |
| `watchers` | `Object<string, Function>` | `{}` | Variable change watchers |
| `yamlPath` | `string` | `''` | Relative path to the YAML source file |

#### Static Properties

| Property | Type | Description |
|----------|------|-------------|
| `Recipe._cssInjected` | `Set<string>` | Tracks which class names have had CSS injected to avoid duplicates |

#### Properties Set by Generated Subclasses

These are defined in the compiled JS class that extends `Recipe`:

| Property | Type | Description |
|----------|------|-------------|
| `title` | `string` | Page/component title |
| `structure` | `Object` | Parsed HTML template as a tree (see [Structure Node Format](#structure-node-format)) |
| `routes` | `Array<RouteConfig>\|null` | Parsed route definitions, or `null` |
| `_css` | `string\|undefined` | Compiled CSS string for runtime injection |
| `_initialStore` | `Object\|undefined` | Initial global store values |
| `onMount` | `Function\|undefined` | Lifecycle hook called after DOM render |
| `onDestroy` | `Function\|undefined` | Lifecycle hook called before teardown |

#### Constructor

```javascript
new Recipe(el)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `el` | `Element` | Root DOM element |

#### Methods

##### `me()`

```javascript
me() → Recipe
```

Returns `this`. Overridden in `RecipeSlot`, `RecipeLoop`, and `RecipeConditional` to return `this.parentModule`.

---

##### `get(name, defaultValue)`

```javascript
get(name, defaultValue) → any
```

Read a reactive variable. If the variable doesn't exist yet, initializes it to `defaultValue` and sets `dirty = true`.

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | `string` | Variable name |
| `defaultValue` | `any` | Value to initialize if not present |

**Returns:** The current value of the variable.

---

##### `set(name, value)`

```javascript
set(name, value) → void
```

Write a reactive variable. If the value differs from the current value, sets `dirty = true` and calls any registered watcher.

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | `string` | Variable name |
| `value` | `any` | New value |

**Side effects:** Calls `this.watchers[name](newValue, oldValue)` if a watcher is registered.

---

##### Auto-generated Getters/Setters

For each variable declared in `vars`, the compiler generates:

```javascript
get_<varName>(defaultValue) → any    // calls this.get('<varName>', defaultValue)
set_<varName>(value) → void          // calls this.set('<varName>', value)
```

---

##### `initUI()`

```javascript
initUI() → void
```

Build UI from scratch (client-side rendering mode). Called when the document body does NOT have `data-sp-ssr`.

1. Injects component CSS via `_injectCss()`
2. Registers in `moduleRegistry`
3. Iterates `this.structure.children` and calls `render()` for each
4. Initializes `SpiderpupRouter` if `this.routes` and `this._routerViewEl` exist
5. Invokes `onMount` hooks (deferred via `setTimeout(fn, 0)`)

---

##### `hydrateUI()`

```javascript
hydrateUI() → void
```

Adopt server-side rendered DOM (hydration mode). Called when the document body has `data-sp-ssr`.

Same lifecycle as `initUI()` but walks existing DOM nodes via cursor instead of creating them.

---

##### `render(attach_to, structure_nodes, structure_idx, loop_item, loop_idx)`

```javascript
render(attach_to, structure_nodes, structure_idx, loop_item, loop_idx) → void
```

Renders a single structure node into the DOM.

| Parameter | Type | Description |
|-----------|------|-------------|
| `attach_to` | `Element` | Parent DOM element to append to |
| `structure_nodes` | `Array` | Sibling structure nodes array |
| `structure_idx` | `number` | Index of the node to render |
| `loop_item` | `any` | Current loop item (if inside a `for` loop) |
| `loop_idx` | `number` | Current loop index (if inside a `for` loop) |

**Handles:**
- Text nodes (static and dynamic)
- `<if>` / `<elseif>` / `<else>` — creates `RecipeConditional`
- Imported components — instantiates (or reuses via `!name` / `_childByNode`), sets vars from attributes, renders, plugs slots
- `<link>` — renders as `<a>` with SPA click handler
- `<router>` (from `<router-view/>`) — creates placeholder `<div data-router-view>`
- Regular HTML tags — creates element, binds attributes/events, recurses children
- `for` attribute — creates `RecipeLoop`
- `slot` attribute — creates `RecipeSlot`

---

##### `hydrate(cursor, structure_nodes, structure_idx, loop_item, loop_idx)`

```javascript
hydrate(cursor, structure_nodes, structure_idx, loop_item, loop_idx) → void
```

Adopt an existing DOM node during SSR hydration. Falls back to `render()` on mismatch.

| Parameter | Type | Description |
|-----------|------|-------------|
| `cursor` | `{parent: Element, childIdx: number}` | Cursor tracking position in DOM children |
| `structure_nodes` | `Array` | Sibling structure nodes |
| `structure_idx` | `number` | Index of node to hydrate |
| `loop_item` | `any` | Current loop item |
| `loop_idx` | `number` | Current loop index |

---

##### `refresh(loop_item, loop_idx)`

```javascript
refresh(loop_item, loop_idx) → void
```

Re-evaluate all dynamic bindings if `dirty` is `true`. Updates DOM text content and attributes for `updatableElements`, then calls `refresh()` on all `updatableRecipes`. Resets `dirty` to `false`.

---

##### `destroy()`

```javascript
destroy() → void
```

Tear down the component:
1. Calls `onDestroy` lifecycle hook
2. Removes all registered DOM event listeners
3. Clears `updatableElements` and `updatableRecipes`

---

##### `on(eventName, handler)`

```javascript
on(eventName, handler) → void
```

Register a handler for bubbling events emitted by child components.

| Parameter | Type | Description |
|-----------|------|-------------|
| `eventName` | `string` | Event name to listen for |
| `handler` | `Function(SpiderpupEvent)` | Handler function. Return `false` to stop propagation. |

---

##### `off(eventName, handler?)`

```javascript
off(eventName, handler?) → void
```

Remove event handler(s).

| Parameter | Type | Description |
|-----------|------|-------------|
| `eventName` | `string` | Event name |
| `handler` | `Function\|undefined` | Specific handler to remove. If omitted, removes all handlers for this event. |

---

##### `emit(eventName, data)`

```javascript
emit(eventName, data) → SpiderpupEvent
```

Emit an event that bubbles up the `parentModule` chain. Does not trigger on `this` — starts at `this.parentModule`.

| Parameter | Type | Description |
|-----------|------|-------------|
| `eventName` | `string` | Event name |
| `data` | `any` | Payload data |

**Returns:** The `SpiderpupEvent` instance.

---

##### `receive(channel, callback)`

```javascript
receive(channel, callback) → void
```

Register a listener for broadcast messages on the given channel.

| Parameter | Type | Description |
|-----------|------|-------------|
| `channel` | `string` | Channel name |
| `callback` | `Function(data, sender)` | Called with the broadcast data and the sending Recipe instance. `this` is bound to `this.me()`. |

---

##### `broadcast(channel, data)`

```javascript
broadcast(channel, data) → void
```

Send a message to all registered receivers on the given channel across all modules in `moduleRegistry`, except `this`.

| Parameter | Type | Description |
|-----------|------|-------------|
| `channel` | `string` | Channel name |
| `data` | `any` | Payload data |

---

##### `plugin(struct)`

```javascript
plugin(struct) → void
```

Route a slot content node to the appropriate slot. If the node has a `slot` attribute matching a named slot, it goes there. Otherwise it goes to `defaultSlot`. If no `defaultSlot` exists, one is created from `this.rootEl`.

| Parameter | Type | Description |
|-----------|------|-------------|
| `struct` | `Object` | A structure node from the parent's children |

---

##### `renderSlots(attach_to, loop_item, loop_idx)`

```javascript
renderSlots(attach_to, loop_item, loop_idx) → void
```

Render all named slots and the default slot into the DOM.

---

##### `_injectCss()`

```javascript
_injectCss() → void
```

Inject this component's `_css` string as a `<style>` element in `<head>`. Idempotent per class name (tracked via `Recipe._cssInjected`).

---

##### Computed Property Accessors

For each property in `computed`, the compiler generates:

```javascript
get_<computedName>() → any
```

Calls the computed function with `this` context and returns the result.

---

##### `yamlUrl` (getter)

```javascript
get yamlUrl() → string
```

Returns the full URL to this module's YAML source file, incorporating `BASE_PATH`.

---

### RecipeSlot

```
class RecipeSlot extends Recipe
```

Handles `<slot/>` and `<slot name="..."/>` content insertion.

#### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `contents` | `Array<Object>` | `[]` | Structure nodes to render into this slot |

#### Methods

##### `me()`

Returns `this.parentModule` (slot content executes in the parent component's scope).

##### `insert(struct)`

```javascript
insert(struct) → void
```

Add a structure node to this slot's contents.

##### `renderSlot(attach_to, loop_item, loop_idx)`

```javascript
renderSlot(attach_to, loop_item, loop_idx) → void
```

Render all collected contents by calling `this.parentModule.render()` for each.

---

### RecipeLoop

```
class RecipeLoop extends Recipe
```

Handles elements with `for` attribute.

#### Constructor

```javascript
new RecipeLoop(el, node)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `el` | `Element` | Container DOM element |
| `node` | `Object` | Structure node containing `for` and `children` |

#### Methods

##### `me()`

Returns `this.parentModule`.

##### `renderLoop(loop_item, loop_idx)`

```javascript
renderLoop(loop_item, loop_idx) → void
```

Evaluates `this.loopNode.attributes.for` (a function returning an array), then for each item calls `this.render()` for every child structure node in `this.loopNode.children`.

##### `refresh(loop_item, loop_idx)`

```javascript
refresh(loop_item, loop_idx) → void
```

Empties `this.rootEl` and calls `renderLoop()` again (full re-render on each refresh).

---

### RecipeConditional

```
class RecipeConditional extends Recipe
```

Handles `<if>`, `<elseif>`, `<else>` chains.

#### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `branches` | `Array<Object>` | `[]` | Structure nodes for each branch |
| `lastBranchIdx` | `number\|undefined` | `undefined` | Index of the last rendered branch |

#### Methods

##### `me()`

Returns `this.parentModule`.

##### `addBranch(ifstruct)`

```javascript
addBranch(ifstruct) → void
```

Add an `if`, `elseif`, or `else` structure node as a branch.

##### `pickBranchIdx(loop_item, loop_idx)`

```javascript
pickBranchIdx(loop_item, loop_idx) → number|undefined
```

Iterate branches and return the index of the first whose `condition` evaluates truthy (or is an `else`). Returns `undefined` if no branch matches.

##### `renderIf(loop_item, loop_idx)`

```javascript
renderIf(loop_item, loop_idx) → void
```

Pick the active branch and render its children into `this.rootEl`.

##### `refresh(loop_item, loop_idx)`

```javascript
refresh(loop_item, loop_idx) → void
```

If the active branch hasn't changed, refresh in place. If it has changed, empty the container and re-render.

---

### SpiderpupRouter

```
class SpiderpupRouter
```

Client-side SPA router using `history.pushState` and `popstate`.

#### Constructor

```javascript
new SpiderpupRouter(routes, viewEl, pageInstance)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `routes` | `Array<RouteConfig>` | Route definitions from compiled page |
| `viewEl` | `Element` | The `<div data-router-view>` element |
| `pageInstance` | `Recipe` | The root page Recipe instance |

Sets `globalRouter = this` and listens for `popstate`.

#### RouteConfig

```javascript
{
  path: string,            // Original path pattern, e.g., "/user/:id"
  pattern: RegExp,         // Compiled regex, e.g., /^\/user\/([^/]+)$/
  component: class,        // Reference to the component class (extends Recipe)
  params: string[]         // Parameter names, e.g., ["id"]
}
```

#### Methods

##### `matchRoute(path)`

```javascript
matchRoute(path) → {route: RouteConfig, params: Object} | null
```

Match a URL path against defined routes. Strips `BASE_PATH` and `.html` suffix before matching. Returns matched route and extracted parameters, or `null`.

##### `navigate(path)`

```javascript
navigate(path) → void
```

Push a new URL to history (with `.html` suffix for static file compatibility) and render the matched route.

##### `handleRoute()`

```javascript
handleRoute() → void
```

Match `location.pathname` and call `renderRoute()` if matched.

##### `renderRoute(match)`

```javascript
renderRoute(match) → void
```

1. Destroy and unregister the current route component
2. Empty the `viewEl`
3. Instantiate the matched component class
4. Set route params as vars
5. Render component children into `viewEl`
6. Schedule `onMount`

---

### SpiderpupEvent

```
class SpiderpupEvent
```

Event object passed to `on()` handlers during event bubbling.

#### Constructor

```javascript
new SpiderpupEvent(name, data, source)
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `name` | `string` | Event name |
| `data` | `any` | Payload passed to `emit()` |
| `source` | `Recipe` | The component that called `emit()` |
| `propagationStopped` | `boolean` | Whether propagation has been stopped |

#### Methods

##### `stopPropagation()`

```javascript
stopPropagation() → void
```

Prevents the event from bubbling further up the `parentModule` chain.

---

### Global Store

```
window.store
```

Global reactive key-value store. Changes trigger `refresh()` on all registered modules.

#### Internal Properties

| Property | Type | Description |
|----------|------|-------------|
| `_state` | `Object` | Key-value storage |
| `_watchers` | `Object<string, Function>` | Per-key watcher callbacks |

#### Methods

##### `store.get(key)`

```javascript
store.get(key) → any
```

Retrieve a value from the store.

##### `store.set(key, value)`

```javascript
store.set(key, value) → void
```

Set a value. If the value differs from the current value:
1. Updates `_state[key]`
2. Calls `_watchers[key](newValue, oldValue)` if registered
3. Calls `_notifyAll()` — marks all modules `dirty` and calls `refresh()` on each

##### `store.init(obj)`

```javascript
store.init(obj) → void
```

Initialize multiple keys at once. Does **not** trigger refresh or watchers.

| Parameter | Type | Description |
|-----------|------|-------------|
| `obj` | `Object` | Key-value pairs to initialize |

##### `store.watch(key, callback)`

```javascript
store.watch(key, callback) → void
```

Register a watcher for a specific key. Only one watcher per key (overwrites previous).

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | `string` | Store key to watch |
| `callback` | `Function(newValue, oldValue)` | Called when the key's value changes |

##### `store._notifyAll()`

Internal. Iterates `moduleRegistry`, sets `dirty = true` on each, and calls `refresh()`.

---

### Global Functions and Objects

| Name | Type | Description |
|------|------|-------------|
| `window.moduleRegistry` | `Array<Recipe>` | All active Recipe instances |
| `window.globalRouter` | `SpiderpupRouter\|null` | The active SPA router (if any) |
| `window.store` | `Object` | Global reactive store |
| `window.SPIDERPUP_BASE_PATH` | `string` | Base URL path (set by generated page script) |

#### `getBasePath()`

```javascript
getBasePath() → string
```

Returns normalized base path from `window.SPIDERPUP_BASE_PATH` (leading slash, no trailing slash).

#### `empty(el)`

```javascript
empty(el) → void
```

Remove all child nodes from a DOM element.

#### `setAttribute(el, attr, val)`

```javascript
setAttribute(el, attr, val) → void
```

Set an attribute on an element. Special handling:
- `textcontent` → sets `el.textContent`
- Boolean attributes (`selected`, `disabled`, `checked`, `readonly`, `required`, `hidden`, `multiple`, `autofocus`, `autoplay`, `controls`, `loop`, `muted`, `open`) → present if truthy, removed if falsy
- All others → `el.setAttribute(attr, val)`

#### `showErrorOverlay(message, stack)`

```javascript
showErrorOverlay(message, stack) → void
```

Display a dismissible error overlay. Injected automatically on `window.error` and `unhandledrejection` events.

#### Transition CSS Classes

Injected once when transitions are used:

| Class | Properties |
|-------|------------|
| `.sp-fade-enter` | `opacity: 0` |
| `.sp-fade-enter-active` | `transition: opacity 0.3s ease` |
| `.sp-fade-leave` | `opacity: 1` |
| `.sp-fade-leave-active` | `opacity: 0; transition: opacity 0.3s ease` |
| `.sp-slide-enter` | `transform: translateX(100%)` |
| `.sp-slide-enter-active` | `transition: transform 0.3s ease` |
| `.sp-slide-leave` | `transform: translateX(0)` |
| `.sp-slide-leave-active` | `transform: translateX(-100%); transition: transform 0.3s ease` |

---

## YAML Schema

### Page / Recipe Fields

Top-level keys in a page or recipe YAML file:

These fields apply to both YAML files and `.pup` script blocks.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `title` | `string` | No | Browser tab title. Defaults to `'Untitled'`. |
| `html` | `string` | No | HTML template with Spiderpup syntax |
| `css` | `string` | No | Raw CSS (scoped to page namespace in output) |
| `less` | `string` | No | LESS source (compiled to CSS via `CSS::LESSp`) |
| `vars` | `Map<string, any>` | No | Reactive variables with initial values |
| `computed` | `Map<string, string>` | No | Computed property expressions |
| `watch` | `Map<string, string>` | No | Variable change callbacks (planned, not yet implemented) |
| `methods` | `Map<string, string>` | No | JavaScript function expressions |
| `lifecycle` | `Map<string, string>` | No | `onMount` and/or `onDestroy` hooks |
| `import` | `Map<string, string>` | No | Component namespace → YAML path |
| `recipes` | `Map<string, RecipeDefinition>` | No | Nested sub-recipe definitions |
| `routes` | `Map<string, string>` | No | URL pattern → import namespace |
| `initial_store` | `Map<string, any>` | No | Global store keys to initialize on mount |
| `import-css` | `Array<string>` | No | External CSS URLs (emitted as `<link>` tags) |
| `import-js` | `Array<string>` | No | External JS URLs (emitted as `<script src>` tags) |
| `include-js` | `Array<string>` | No | Local JS file paths to inline in `<head>` (relative to `www/`) |

### Recipe Fields

A recipe defined inside `recipes:` supports a subset:

| Field | Type | Description |
|-------|------|-------------|
| `vars` | `Map<string, any>` | Reactive variables |
| `computed` | `Map<string, string>` | Computed properties |
| `methods` | `Map<string, string>` | JavaScript methods |
| `lifecycle` | `Map<string, string>` | Lifecycle hooks |
| `html` | `string` | HTML template |
| `css` | `string` | Raw CSS |
| `less` | `string` | LESS source |
| `import` | `Map<string, string>` | Imports |

### HTML Template Syntax

#### Special Elements

| Element | Attributes | Description |
|---------|------------|-------------|
| `<if>` | `condition="expr"` | Conditional rendering. Condition must be a function expression. |
| `<elseif>` | `condition="expr"` | Additional condition branch. Must immediately follow `<if>` or another `<elseif>`. |
| `<else>` | — | Fallback branch. Must immediately follow `<if>` or `<elseif>`. |
| `<slot/>` | `name="string"` (optional) | Content insertion point. Default slot if no `name`. |
| `<router-view/>` | — | Route component outlet. Compiled to tag name `router`. |
| `<link>` | `to="path"` | Client-side navigation link. Rendered as `<a>` with click handler. |

#### Special Attributes

| Attribute | Syntax | Compiled Form | Description |
|-----------|--------|---------------|-------------|
| `for` | `for="$array"` or `for="[1,2,3]"` or `for="() => expr"` | `*for: function(){...}` | Iterate over array. Children receive `(mod, item, idx)` context. |
| `@event` | `@click="handler()"` | `*onclick: function(){...}` | Event handler shorthand. Auto-wrapped in `() =>`. |
| `textContent` | `textContent="(mod, item, idx) => expr"` | `*textcontent: function(mod,item,idx){...}` | Dynamic text content. |
| `class:name` | `class:active="() => bool"` | `*class:active: function(){...}` | Toggle CSS class based on return value. |
| `style:prop` | `style:color="varName"` or `style:fontSize="() => expr"` | `*style:color: function(){...}` | Dynamic inline style property. |
| `slot` | `slot="name"` | `slot: "name"` | Target a named slot in the parent component. |
| `transition` | `transition="fade\|slide"` | — | Animation on conditional show/hide. |
| `!name` | `!name="id"` | `!name: "id"` | Register component instance as `this.instances[id]`. A second tag with the same `!name` reuses the existing instance — both DOM locations share the same state and update together. |
| `condition` | On `<if>` / `<elseif>` | `*condition: function(){...}` | Condition expression. |

#### Attribute Compilation Rules

During HTML parsing, attributes are classified:

1. **`condition`** (on `if`/`elseif`) → key `*condition`, value run through `transform_expression()`
2. **`for`** → key `*for`, value run through `transform_expression()`. Inline arrays (`[...]`) get `()=>` prepended.
3. **`@event`** → key `*on<event>`, value run through `transform_expression()`
4. **Value starts with `(`** → treated as function expression, key prefixed with `*`, value run through `transform_expression()`
5. **Value contains `$`** → compiled to template literal function: `function(){return \`...\`}`, key prefixed with `*`
6. **Otherwise** → static string attribute, key lowercased

#### Text Node Compilation Rules

1. **Starts with `(params) =>`** → dynamic, run through `transform_expression()`, stored as `*content`
2. **Contains `$`** → compiled to template literal: `function(){return\`...\`}`, stored as `*content`
3. **Otherwise** → static string, stored as `content`

### Structure Node Format

The compiler parses HTML templates into a JSON tree. Each node is one of:

#### Element Node

```javascript
{
  tag: "div",                    // Lowercased tag name
  attributes: {                  // Attribute map
    "class": "card",             // Static: string value
    "*onclick": function(){...}, // Dynamic: function value (key prefixed with *)
    "*for": function(){...},     // Loop function
    "*condition": function(){...}, // Condition function
    "!name": "myInst",          // Instance name (special, not rendered)
    "slot": "header"             // Slot targeting
  },
  children: [...]                // Array of child nodes
}
```

#### Text Node (static)

```javascript
{
  content: "Hello world"          // Static text string
}
```

#### Text Node (dynamic)

```javascript
{
  "*content": "function(){return`Hello ${this.get_name()}`}"  // Template function string
}
```

**Note:** In the JSON structure, dynamic attributes and content have keys prefixed with `*`. When emitted to JavaScript, the `"*..."` keys have their quotes around the function body removed so they become actual JavaScript functions.

---

## SFC Module

File: `lib/Yote/Spiderpup/SFC.pm`

Package: `Yote::Spiderpup::SFC`

Parser for the single-file component (`.pup`) format. Converts `<script>`, `<style>`, and `<template>` blocks into a Perl hashref identical to what `YAML::LoadFile` produces, so the entire downstream pipeline works unchanged.

### SFC Exported Functions

```perl
use Yote::Spiderpup::SFC qw(parse_sfc);
```

#### `parse_sfc($content)`

```perl
parse_sfc($content) → hashref
```

Parse a `.pup` file's content string into a page/recipe data structure.

| Parameter | Type | Description |
|-----------|------|-------------|
| `$content` | `string` | Full contents of a `.pup` file |

**Returns:** A hashref with the same structure as `YAML::LoadFile` output — keys like `title`, `vars`, `methods`, `html`, `css`, `less`, `recipes`, etc.

**Block extraction:**

| Block | Result Key | Notes |
|-------|-----------|-------|
| `<style>` | `css` | Concatenated if multiple blocks |
| `<style lang="less">` | `less` | LESS stylesheet |
| `<template>` | `html` | Main HTML template |
| `<template name="X">` | `html_X` | Variant template |
| `<template recipe="X">` | `recipes.X.html` | Sub-recipe HTML |
| `<script>` | Top-level keys | Merged into result |
| `<script recipe="X">` | `recipes.X.*` | Sub-recipe fields |

**Script parsing:**

The script block contains a JavaScript-style object literal (outer braces optional). The parser dispatches value parsing based on the key name:

| Key Category | Keys | Parsing |
|-------------|------|---------|
| Function context | `methods`, `computed`, `lifecycle`, `watch` | Values kept as raw strings (for `transform_expression`) |
| Data context | `vars`, `import`, `routes`, `initial_store` | Parsed into Perl hashes/arrays/scalars |
| Array keys | `import-css`, `import-js`, `include-js` | Parsed as arrays |
| Recipes | `recipes` | Recursive: each value parsed like a top-level block |
| Scalars | `title`, etc. | Simple string/number |

**Supported syntax features:**
- `//` line comments and `/* */` block comments
- Trailing commas
- Single-quoted, double-quoted, and backtick template literal strings
- Nested braces, brackets, and parentheses in function expressions
- Bare identifiers and quoted strings as keys
- `async` functions
- Script block with or without outer `{}`

---

## Server

Entry point: `bin/pupserver` | Module: `Yote::Spiderpup` (`lib/Yote/Spiderpup.pm`)

### CLI Options

```
pupserver [OPTIONS]
```

| Option | Arguments | Description |
|--------|-----------|-------------|
| `--port` | `PORT` | Listen port (default: 5000) |
| `--base-url-path` | `PATH` | URL prefix for reverse proxy setups (e.g., `--base-url-path /myapp`) |
| `--webroot` | `DIR` | Webroot directory for static files and compiled output (default: `www/webroot`) |
| `--compile` | — | Batch compile all YAML to JS and HTML, then exit |
| `--watch` | `[INTERVAL]` | Watch for file changes and recompile. Default interval: 5 seconds. |

With no options, starts the HTTP server on port 5000.

### Environment Variables

| Variable | Description |
|----------|-------------|
| `SPIDERPUP_NO_CACHE` | Set to `1` to disable HTML/JS caching. Every request recompiles. |
| `SPIDERPUP_DEV` | Set to `1` to enable dev mode (checked via `is_dev_mode()`). |

### Directory Layout (Yote::Spiderpup instance attributes)

| Attribute | Default Path | Description |
|-----------|-------------|-------------|
| `www_dir` | `./www` | Web root directory (constructor arg) |
| `pages_dir` | `./www/pages` | Page files (YAML or .pup) |
| `recipes_dir` | `./www/recipes` | Recipe files (YAML or .pup) |
| `webroot_dir` | `./www/webroot` | Static output (servable by any web server) |
| `js_dir` | `./www/webroot/js` | Compiled JavaScript output |
| `static_dir` | `./www` | Static file serving root |

---

### Component File Helpers

#### `_find_component_file($dir, $name)`

```perl
_find_component_file($dir, $name) → string | undef
```

Look for a component file by name, trying `.yaml` first, then `.pup`. Returns the full path if found, `undef` otherwise.

| Parameter | Type | Description |
|-----------|------|-------------|
| `$dir` | `string` | Directory to search in |
| `$name` | `string` | Base name without extension |

#### `_load_component_data($file_path)`

```perl
_load_component_data($file_path) → hashref
```

Load and parse a component file. Dispatches to `YAML::LoadFile` for `.yaml` files or `parse_sfc` for `.pup` files.

| Parameter | Type | Description |
|-----------|------|-------------|
| `$file_path` | `string` | Full path to a `.yaml` or `.pup` file |

---

### Path Resolution Functions

#### `parse_page_path($path)`

```perl
parse_page_path($path) → string
```

Convert a URL path to a page name.

| Input | Output |
|-------|--------|
| `/` | `index` |
| `/home` | `home` |
| `/home.html` | `home` |
| `/corpse` | `corpse/index` (if `corpse/` is a directory in `$PAGES_DIR`) |
| `/corpse/play` | `corpse/play` |

#### `load_page($path)`

```perl
load_page($path) → hashref | undef
```

Load and parse a component file (YAML or .pup). Strips leading `/`, `.html`, `.yaml`, and `.pup` suffixes. Checks `recipes/` prefix to determine whether to look in `$RECIPES_DIR` or `$PAGES_DIR`. Uses `_find_component_file` to locate the file and `_load_component_data` to parse it. Returns the parsed data as a Perl hashref with `yaml_path` added, or `undef` if file not found.

#### `resolve_recipe_name($import_path)`

```perl
resolve_recipe_name($import_path) → ($module_name, $class_name, $js_path, $is_page)
```

Map an import path to its identifiers.

| Return Value | Type | Description |
|-------------|------|-------------|
| `$module_name` | `string` | Canonical name (e.g., `card`, `corpse/play`) |
| `$class_name` | `string` | JavaScript class name (e.g., `Card`, `Corpse_play`) |
| `$js_path` | `string` | URL path to compiled JS (e.g., `/js/card.js`, `/js/pages/home.js`) |
| `$is_page` | `boolean` | Whether this is a page (vs. a recipe) |

**Class name rules:**
- `/` → `_`
- `-x` → `X` (hyphen-to-camelCase)
- First letter uppercased

---

### Compilation Functions

#### `generate_single_class($class_name, $page, $page_imports_obj)`

```perl
generate_single_class($class_name, $page, $page_imports_obj) → string
```

Generate a JavaScript class definition extending `Recipe`.

| Parameter | Type | Description |
|-----------|------|-------------|
| `$class_name` | `string` | JS class name |
| `$page` | `hashref` | Parsed YAML data |
| `$page_imports_obj` | `string` | JavaScript object literal mapping tag names to classes |

**Output includes:**
- `title`, `yamlPath`, `structure` (JSON), `vars` (JSON), `imports`, `routes`
- `_css` property (compiled LESS + raw CSS)
- `_initialStore` property (if `initial_store` defined)
- `get_<var>()`/`set_<var>()` for each var
- User-defined methods (transformed via `transform_expression()`)
- Computed property getters
- Lifecycle hooks
- `onMount` wrapper that calls `store.init()` if `initial_store` is defined

#### `compile_recipe($module_name)`

```perl
compile_recipe($module_name) → string
```

Compile a recipe file (YAML or .pup) to a JavaScript ES module file. Writes to `$JS_DIR/<module_name>.js` and `$JS_DIR/<module_name>.js.meta`.

**Process:**
1. Find and load component file from `$RECIPES_DIR` (tries `.yaml` then `.pup`)
2. Resolve and compile import dependencies
3. Generate `import` statements for dependencies
4. Generate sub-recipe classes (from `recipes:` field)
5. Generate main class
6. Write JS file with `export` statements
7. Write `.meta` file with dependency file modification times

#### `compile_recipe_if_stale($module_name)`

```perl
compile_recipe_if_stale($module_name) → void
```

Only compile if the `.meta` cache indicates source files have changed.

#### `compile_page_js($page_name)`

```perl
compile_page_js($page_name) → string
```

Compile a page file (YAML or .pup) to a JavaScript ES module. Writes to `$JS_DIR/pages/<page_name>.js`. Handles relative import paths based on directory depth.

#### `compile_page_js_if_stale($page_name)`

```perl
compile_page_js_if_stale($page_name) → void
```

Only compile if the `.meta` cache indicates source files have changed.

#### `build_html($page_data, $page_name)`

```perl
build_html($page_data, $page_name) → string
```

Generate a complete HTML document from page data.

**Output structure:**
```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>...</title>
    <!-- import-css <link> tags -->
    <!-- <style> with compiled LESS + CSS -->
    <!-- import-js <script src> tags -->
    <!-- include-js inline <script> -->
    <script src="/js/spiderpup.js"></script>
    <script type="module">
        import { ClassName } from '/js/pages/pageName.js';
        window.SPIDERPUP_BASE_PATH = '...';
        document.addEventListener('DOMContentLoaded', function() {
            const page = new ClassName();
            page.pageName = '...';
            document.body.classList.add('...');
            if (document.body.hasAttribute('data-sp-ssr')) {
                page.hydrateUI();
            } else {
                page.initUI();
            }
        });
    </script>
</head>
<body data-sp-ssr><!-- SSR content --></body>
</html>
```

#### `compile_all()`

```perl
compile_all() → void
```

Batch compile all YAML files:
1. Phase 1: All recipes in `$RECIPES_DIR` → JS files
2. Phase 2: All pages in `$PAGES_DIR` (recursive) → HTML files

Prints errors but continues compilation.

#### `watch_and_compile($interval)`

```perl
watch_and_compile($interval) → void (loops forever)
```

Run `compile_all()` initially, then poll for YAML file changes every `$interval` seconds and recompile when changes are detected.

---

### Caching Functions

#### `get_cache_paths($page_name)`

```perl
get_cache_paths($page_name) → (html => $path, meta => $path)
```

Returns paths for cached HTML and metadata files in `$WEBROOT_DIR`.

#### `get_recipe_cache_paths($module_name)`

```perl
get_recipe_cache_paths($module_name) → (js => $path, meta => $path)
```

Returns paths for cached JS and metadata files in `$JS_DIR`.

#### `collect_yaml_files($page_data, $page_name, $collected)`

```perl
collect_yaml_files($page_data, $page_name, $collected?) → hashref
```

Recursively collect all source files (YAML or .pup) referenced by a page (including transitive imports). Returns `{ $filepath => $mtime, ... }`.

#### `is_cache_valid($page_name, $page_data)`

```perl
is_cache_valid($page_name, $page_data) → boolean
```

Compare cached metadata modification times against current file modification times. Returns true if all files are unchanged.

#### `get_cached_html($page_data, $page_name)`

```perl
get_cached_html($page_data, $page_name) → string
```

Return cached HTML if valid, otherwise call `build_html()`, cache the result and metadata, and return. Bypasses cache entirely if `SPIDERPUP_NO_CACHE` is set.

---

### SSR Functions

#### `render_ssr_body($structure, $vars, $recipes_map)`

```perl
render_ssr_body($structure, $vars, $recipes_map) → string
```

Render the top-level structure to an HTML string for server-side rendering.

#### `render_ssr_node($siblings, $idx, $vars, $recipes_map, $slot_children, $seen)`

```perl
render_ssr_node($siblings, $idx, $vars, $recipes_map, $slot_children, $seen) → string
```

Render a single node to HTML. Handles:

| Node Type | SSR Output |
|-----------|------------|
| Static text | HTML-escaped text |
| Dynamic text (`*content`) | Variable-substituted template |
| `<if>` chain | `<div data-sp-if></div>` (empty placeholder; client renders) |
| `<elseif>`, `<else>` | Consumed by `<if>` handler or skipped |
| Imported component | Recursively rendered with component vars |
| `<link to="path">` | `<a href="base+path.html">...</a>` |
| `<router-view/>` | `<div data-router-view></div>` |
| Element with `for` | `<tag data-sp-for></tag>` (empty; client renders) |
| `<slot>` | Empty container (client fills) |
| Regular element | `<tag attrs>children</tag>` |

#### `ssr_substitute_vars($func_str, $vars)`

```perl
ssr_substitute_vars($func_str, $vars) → string
```

Extract template string from `function(){return\`...\`}` and replace `${this.get_varName()}` with actual values from `$vars`.

#### `_render_static_attrs($attrs)`

```perl
_render_static_attrs($attrs) → string
```

Render only static (non-function, non-special) attributes as an HTML attribute string. Skips keys starting with `*`, `!`, and keys `for`, `slot`, `condition`.

#### `_build_recipes_map($page_data)`

```perl
_build_recipes_map($page_data) → hashref
```

Build a lookup table from tag names to `{ data => $yaml_data, class_name => $string }` for all imports and nested recipes of a page.

---

### HTTP Server

#### `run_server($port)`

```perl
run_server($port) → void (loops forever)
```

Start a forking HTTP server on the given port (default 5000). For each incoming connection:
1. Fork a child process
2. Parse the HTTP request line
3. Strip `$BASE_PATH` from the path
4. Route:
   - `*.js` → serve from `$WEBROOT_DIR`
   - `*.yaml` / `*.pup` → serve raw source from `$WWW_DIR`
   - Everything else → `load_page_from_path()` → compile and serve HTML
5. Send response and close connection

Child processes are reaped via `$SIG{CHLD} = 'IGNORE'`.

#### `load_page_from_path($path)`

```perl
load_page_from_path($path) → string
```

Full request pipeline: parse path → load YAML → compile → return HTTP response string (including headers). Returns styled error overlays for compilation errors or 404 for missing pages.

#### Content Types Served

| Pattern | Content-Type |
|---------|-------------|
| `*.js` | `application/javascript; charset=utf-8` |
| `*.yaml` | `text/yaml; charset=utf-8` |
| `*.pup` | `text/plain; charset=utf-8` |
| Pages | `text/html; charset=utf-8` |

---

## Transform Module

File: `lib/Yote/Spiderpup/Transform.pm`

Package: `Yote::Spiderpup::Transform`

Compile-time expression transformer. Converts Spiderpup shorthand syntax into standard JavaScript.

### Exported Functions

```perl
use Yote::Spiderpup::Transform qw(
    transform_dollar_vars
    transform_expression
    extract_arrow_params
    add_implicit_this
    parse_html
);
```

#### `transform_dollar_vars($expr)`

```perl
transform_dollar_vars($expr) → string
```

Transform `$var` shorthand into getter/setter calls.

**Transformation rules:**

| Pattern | Output |
|---------|--------|
| `$var` (read) | `this.get_var()` |
| `$var = expr` (assign, not `==`/`===`) | `this.set_var(expr)` |

**Features:**
- Protects string literals (single, double, backtick) from transformation
- Handles escaped quotes within strings
- Recursively transforms `$var` references within assignment RHS
- Properly handles nested brackets/parens for RHS boundary detection
- Assignment boundary: `;`, `,`, or unmatched `)`, `]`, `}` at depth 0

**Examples:**

| Input | Output |
|-------|--------|
| `$count` | `this.get_count()` |
| `$count + 1` | `this.get_count() + 1` |
| `$count = 5` | `this.set_count(5)` |
| `$count = $count + 1` | `this.set_count(this.get_count() + 1)` |
| `$items = [...$items, x]` | `this.set_items([...this.get_items(), x])` |
| `$a == $b` | `this.get_a() == this.get_b()` (comparison, not assignment) |
| `"$foo"` | `"$foo"` (protected inside string) |

---

#### `extract_arrow_params($expr)`

```perl
extract_arrow_params($expr) → hashref
```

Extract parameter names from arrow function expressions. Returns a hashref of `{ name => 1 }`.

**Matches:**
- `(a, b, c) => ...` → `{a => 1, b => 1, c => 1}`
- `x => ...` → `{x => 1}`
- Default values stripped: `(a = 5) => ...` → `{a => 1}`

---

#### `add_implicit_this($expr, $local_vars, $known_methods)`

```perl
add_implicit_this($expr, $local_vars, $known_methods) → string
```

Add `this.` prefix to bare function calls that are known methods.

| Parameter | Type | Description |
|-----------|------|-------------|
| `$expr` | `string` | JavaScript expression |
| `$local_vars` | `hashref` | Variable names to skip (arrow params, loop vars) |
| `$known_methods` | `hashref` | Method names to prefix with `this.` |

**Skip conditions (no `this.` added):**
- Already preceded by `.` (property access)
- Preceded by `new ` or `function `
- Already preceded by `this.`
- Name is in `$local_vars`
- Name is **not** in `$known_methods` (whitelist approach)

**Protects string literals** from transformation.

---

#### `transform_expression($expr, $known_methods)`

```perl
transform_expression($expr, $known_methods) → string
```

Master transformation pipeline. Applies all shorthand transformations in order.

| Parameter | Type | Description |
|-----------|------|-------------|
| `$expr` | `string` | Raw expression from YAML |
| `$known_methods` | `hashref` | Method names defined in this recipe's `methods:` |

**Pipeline:**

1. **Wrap bare expressions** — If the expression doesn't start with `(`:
   - Wrap as `function(){return expr}`
2. **Convert arrow functions** — If it matches `(params) => { body }`:
   - Convert to `function(params){ body }`
3. **Convert arrow expressions** — If it matches `(params) => expr`:
   - Convert to `function(params){return expr}`
4. **Extract local variables** — `extract_arrow_params()` on the result
5. **Transform dollar vars** — `transform_dollar_vars()`
6. **Add implicit this** — `add_implicit_this()` with local vars and known methods

**Examples:**

| Input | Output |
|-------|--------|
| `$count + 1` | `function(){return this.get_count() + 1}` |
| `() => { $count = 0 }` | `function(){ this.set_count(0) }` |
| `() => increment()` | `function(){return this.increment()}` (if `increment` is a known method) |
| `(e) => console.log(e)` | `function(e){return console.log(e)}` |

---

#### `parse_html($html, $known_methods)`

```perl
parse_html($html, $known_methods) → hashref
```

Parse an HTML template string into a hierarchical structure tree.

| Parameter | Type | Description |
|-----------|------|-------------|
| `$html` | `string` | HTML template from YAML `html:` field |
| `$known_methods` | `hashref` | Method names for `transform_expression()` |

**Returns:** A hashref with a single key `children` containing an array of node objects.

**Parsing behavior:**
- Tokenizes on `<tag>` boundaries
- Handles self-closing tags and HTML void elements
- Tracks open/close tag stack for nesting
- Processes attributes with transformation rules (see [Attribute Compilation Rules](#attribute-compilation-rules))
- Whitespace-only text nodes are discarded
- Tag names and attribute names are lowercased
- `<router-view/>` is parsed as tag `router`
- Attribute matching: `name="value"` first, then bare attributes get value `'true'`

---

## Compilation Pipeline Summary

```
Source file (.yaml or .pup)
    │
    ├─ YAML::LoadFile()       → page data hashref (for .yaml)
    │   or
    ├─ parse_sfc()            → page data hashref (for .pup)
    │
    ├─ parse_html()           → structure tree (JSON)
    ├─ CSS::LESSp->parse()    → compiled CSS string
    ├─ transform_expression() → transformed method/computed/lifecycle JS
    │   ├─ extract_arrow_params()
    │   ├─ transform_dollar_vars()
    │   └─ add_implicit_this()
    │
    ├─ generate_single_class() → JS class extending Recipe
    │
    ├─ compile_recipe()       → www/webroot/js/<name>.js (ES module with exports)
    │   or
    ├─ compile_page_js()      → www/webroot/js/pages/<name>.js (ES module)
    │
    ├─ render_ssr_body()      → SSR HTML string
    │
    └─ build_html()           → www/webroot/<name>.html (full document)
```

**Generated JS class structure:**

```javascript
// ES module imports
import { DepClass } from './dep.js';

// Sub-recipe classes
export class Main_subrecipe extends Recipe {
    title      = '...';
    yamlPath   = '...';
    structure  = { children: [...] };
    vars       = { ... };
    imports    = {};
    routes     = null;
    _css       = '...';

    get_var(defaultValue) { return this.get('var', defaultValue); }
    set_var(value) { return this.set('var', value); }
    methodName = function() { ... };
    get_computed() { return (function(){...}).call(this); }
    onMount = function() { ... };
}

// Main class
export class Main extends Recipe {
    // ... same structure ...
    imports = { dep: DepClass, "dep.sub": DepClass_sub };
}
```

**Generated HTML document lifecycle:**

1. Browser loads HTML (SSR content in `<body data-sp-ssr>`)
2. `spiderpup.js` loaded (defines `Recipe`, `store`, etc.)
3. Page ES module loaded (defines page class)
4. `DOMContentLoaded` fires
5. Page class instantiated
6. `hydrateUI()` called (adopts SSR DOM, attaches event handlers, renders conditionals/loops)
7. `onMount` hooks fire (deferred via `setTimeout(..., 0)`)
8. Router initialized if `routes` defined
