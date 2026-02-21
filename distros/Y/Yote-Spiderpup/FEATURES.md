# Spiderpup Features

Spiderpup is a web framework that compiles declarative page and component definitions into static HTML and JavaScript. Components can be authored in YAML or the single-file `.pup` format. It is built with Perl and JavaScript and requires no Node.js toolchain.

---

## YAML and SFC Authoring

Every page is a single file — either YAML or a `.pup` single-file component. A page definition can include an HTML template, variables, methods, styles, lifecycle hooks, imported components, and routing rules — all in one place. The source file compiles to a standalone HTML page with an accompanying JavaScript module.

The `.pup` format uses `<script>`, `<style>`, and `<template>` blocks, similar to Vue or Svelte. Both formats produce identical compiled output.

Pages map directly to URLs based on their file path under the `pages/` directory.

## Reactive Variables and Computed Properties

Components declare variables with default values. The compiled JavaScript generates getter/setter pairs for each variable, and templates reference them with `$var` shorthand. Computed properties derive values from other variables and are recalculated on each refresh.

The UI updates when a component refreshes. Event handlers trigger a refresh automatically after they run; outside of handlers, `refresh()` can be called explicitly.

## Shorthand Syntax

Spiderpup provides shorthand that compiles down to standard JavaScript:

- **`$var`** for reading and assigning reactive variables
- **`@event`** for attaching DOM event handlers
- **Implicit `this`** on method calls within templates and handlers

All shorthand is resolved at compile time. The traditional long-form syntax is always available and can be mixed freely with shorthand.

## LESS and CSS Styling

Pages and components can include raw CSS or LESS stylesheets. LESS support includes variables, nesting, mixins, color functions, and math. Page-level styles are scoped to the page automatically.

## Reusable Components

Components (called "recipes") are YAML or `.pup` files that can be imported and used as custom HTML tags. They are self-contained units with their own variables, methods, styles, and templates. Components can define sub-recipes for internal use, and sub-recipes are also accessible from the outside via dot notation.

## Slots

Components accept child content through slots. A default slot captures all child content; named slots allow content to target specific insertion points within a component's template. Slot content is scoped to the component, with access to the parent available through `parentModule`.

## Named and Shared Instances

A component instance can be registered with a name. When the same name appears again in the template, the existing instance is reused rather than creating a new one. Both locations share the same state, child components, and lifecycle — updates at one location are reflected at the other.

## Component Communication

Two patterns are available:

- **Broadcast / Receive** — pub/sub messaging across all components, regardless of their position in the tree
- **Emit / On** — event bubbling up the component tree, similar to DOM events, with the ability to stop propagation

## Global Store

A reactive key-value store is shared across all components. Setting a value in the store triggers a refresh on every component. The store supports per-key watchers and is accessible from the browser console for debugging.

## Conditionals and Loops

Templates support `<if>`, `<elseif>`, and `<else>` tags for conditional rendering, with optional built-in transitions (fade, slide). Any element can iterate over an array using the `for` attribute, with access to the current item and index.

## Client-Side Routing

Single-page applications are supported with a built-in router. Routes map URL paths to imported components, with support for parameterized segments. Navigation between routes uses `pushState` and avoids full page reloads. A `<router-view/>` element marks where matched components render, and `<link to="...">` provides client-side navigation links.

## HTML Variant Structures

A component can define multiple HTML templates using `html_<variant>` keys. The active template is selected at use time, allowing a single component to present different layouts without duplicating its logic or state.

## Lifecycle Hooks

Components support `onMount` and `onDestroy` hooks. `onMount` fires after the component's DOM is built and is the place to fetch data, start timers, register message handlers, or initialize third-party libraries. `onDestroy` fires on removal for cleanup.

## External Assets

Pages can pull in external CSS and JavaScript via URL, or inline local JavaScript files directly into the compiled page. This integrates third-party libraries without a bundler.

## Server and Compilation

Spiderpup includes a built-in development server that compiles YAML on the fly and serves the result. It supports three modes:

- **Server mode** — compiles on demand per request, with caching
- **Watch mode** — monitors YAML files for changes and recompiles automatically
- **Compile mode** — batch-compiles all pages and recipes, then exits

The compiled output is a static `webroot/` directory that can be served by any standard web server (Apache, Nginx) with no runtime dependency on Spiderpup.

## Hydration

The runtime supports both client-side rendering and hydration of server-rendered HTML. When hydrating, it adopts existing DOM nodes rather than rebuilding them, falling back to client-side rendering on mismatch.

## Base URL Path

Projects can be configured with a base URL prefix for deployment behind a reverse proxy or at a subpath. All internal URLs and import paths adjust automatically.
