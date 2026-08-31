# Vendored Funky-Frame subset

Source: /Users/lnation/Semantic/Funky-Frame (npm `funky-frame`)
Version: 1.0.4
Commit:  39cdad36ef286631d6aba937f81fcea54b810f59 (v1.0.4, 2026-01-07)

Note: js/core/namespace.js in this version hardcodes `Funky.version =
'1.0.2'` while the dist is 1.0.4; the runtime report is expected to say
1.0.2. Pin by the commit above, not by `Funky.version`.

## Re-vendor procedure

1. Check out the pinned commit (or the new one being moved to) in the
   Funky-Frame repo.
2. Re-copy every file listed below, keeping the numeric order prefixes -
   the server concatenates in lexical order and the order IS the
   dependency order (namespace absolutely first, registry second,
   themes.css last of the framework css).
3. Re-verify the two wire contracts this UI leans on, which are
   Funky internals and may move: Funky.Table `_buildAjaxParams` /
   `_handleAjaxResponse` (request `draw/page/limit/search/sort`,
   response `{data, total}`), and the csrf cookie name `csrf_token` +
   header `X-CSRF-Token` in js/core/api.js.
4. Update version + commit here, run t/75-admin-assets.t (bundle
   completeness/order) and the t/7x suite.

## js/ (concatenated into funky.js, this order)

    01-namespace.js          core - MUST be first; creates + locks the registry
    02-registry.js           core - MUST precede any component using
                             createInstanceRegistry at module scope
                             (table, stats-bar)
    03-util.js
    04-dom.js
    05-events.js
    06-pubsub.js
    07-media-query.js        badge depends on it
    08-storage.js            filter-toolbar depends on it
    09-cache.js
    10-timing.js
    11-date.js
    12-keyboard.js
    13-announce.js
    14-live-binding.js
    15-csrf.js
    16-api.js
    18-animate.js            toast depends on it
    19-modal.js
    23-visibility-observer.js
    24-websocket.js
    25-formatting.js         stats-bar hard-requires Funky.Format
    26-action-registry.js    bulk-actions calls ActionRegistry.create
                             unconditionally in its constructor
    27-toast.js
    28-spinner.js
    29-skeleton.js
    30-empty-state.js
    31-badge.js
    32-charts.js             pure inline SVG - the no-chart-library rule
                             survives
    33-relative-time.js
    34-stats-bar.js
    35-table.js
    36-bulk-actions.js
    37-filter-toolbar.js

## css/ (concatenated into funky.css, this order; punk-queue.css is
## appended after by the server as the override layer)

    01-dom.css
    02-layout.css
    03-buttons.css
    04-cards.css
    05-forms.css
    06-tables.css            Funky.Table's own skin (datatables-funky.css
                             is the legacy jQuery skin - NOT vendored)
    07-stats.css             also carries the Charts sparkline classes
    08-modals.css
    09-toasts.css
    10-empty-state.css
    11-skeleton.css
    12-spinner.css
    13-badge.css
    14-relative-time.css
    15-filters.css
    17-animate.css
    18-themes.css            MUST be last of the framework css (defines
                             the --pro-* tokens and [data-theme])

## FontAwesome (vendored since 0.08) - fontawesome/

Source: /Users/lnation/Semantic/Funky-Frame/vendor/fontawesome
Version: Font Awesome Free 6.4.0
Licence: LICENSE.txt beside the font (Icons CC BY 4.0, Fonts SIL OFL
1.1, Code MIT). It ships in the dist because the licence requires it.

    fontawesome/fa-solid-900.woff2   150,124 bytes, copied verbatim
    fontawesome/fontawesome.css      ours - @font-face + 36 content codes
    fontawesome/LICENSE.txt          copied verbatim

**Only the solid face, and only our icons' codes.** Upstream's
all.min.css is 102KB and carries the content code for every icon in the
set; this UI renders thirty-six, so fontawesome.css transcribes those
thirty-six and leaves the rest. Every value there is upstream's own -
re-derive any of them by grepping all.min.css for `.fa-NAME:before`,
never by guessing. `far` is mapped onto the solid face: the regular
weight is a second 25KB file and nothing here needs it.

`fa-wifi-slash` is a **Pro** icon and is in no Free weight. Funky's
websocket module emits it for the disconnected state, so fontawesome.css
maps it to `fa-link-slash`, which is free and means the same thing.

**Until 0.08 the answer was "vendor nothing".** punk-queue.css
neutralised `i.fas` and approximated each icon with a unicode glyph,
with a bullet for anything unlisted - which is what Funky.Table's cog
and its plus/minus, FilterToolbar's bookmark, EmptyState's rocket and
the websocket badge all rendered as. Ten live icons were falling
through. The shim is gone from punk-queue.css; only `.fa-spin` (ours,
not upstream's) stayed.

The font is served from its own route as `font/woff2` and the
`@font-face` url() is RELATIVE, so it resolves against
`<prefix>/assets/funky.css` and needs no server-side interpolation of
the mount prefix. Re-vendoring is: copy the two upstream files, re-check
the thirty-six codes, run t/75.

## Bootstrap checkpoint (per the plan: NOT vendored)

Bootstrap: NOT vendored. Funky's modal/toast/bulk-actions emit
Bootstrap STRUCTURAL class names (modal-dialog, toast-container, btn,
btn-close, d-flex, me-2, visually-hidden...); punk-queue.css provides a
minimal implementation of exactly the classes this UI renders, themed
with the --pro-* tokens so light/dark follow themes.css. No --bs-*
variable is consumed by any vendored css file (themes.css only DEFINES
--bs-* bridges, outbound).

## Behavioural facts that shaped app.js

- serverSide requires `ajax: {url}`; `ajaxUrl` silently downgrades to
  client-side paging. Selection hardcodes `row.id`.
- There is no page registry in this subset: app.js carries its own,
  keyed on the `data-page` id the server writes onto `#pqContent`, and
  routes the ws entity envelope to the active module's `update()`.
- `onRowClick` fires ONLY from keyboard activation (Enter on a focused
  row). A mouse click on a selectable table goes to _handleClick ->
  _handleRowClick, which does selection and nothing else - so a
  clickable row needs a real `a[href]` in the row, rendered with a
  `data-action` attribute (which _handleClick excludes from selection).
  The jobs table's ID link is the example.
- Do NOT add your own click listener to such a link. It is an anchor to
  a real URL and the browser already knows what to do with it; a
  handler that navigated instead would work on a left click and
  silently break middle-click, open-in-new-tab and copy-address. The
  `data-action` attribute is the whole point of the link, and it is for
  Funky.Table's selection handler, not for navigation.
- Funky.RelativeTime self-inits once the document is ready, so a page
  load is covered. Rows drawn LATER by a table reload are not: it
  listens for a `funky.datatable.draw` DOM event while Funky.Table
  emits `funky:table:draw` on PubSub. app.js bridges the two.

## Not vendored, deliberately

- **The SPA layer: js/17-history.js, js/20-navigation.js,
  js/21-pages.js, js/22-spa.js and css/16-spa.css.** Dropped in 0.08,
  and a re-vendor that follows step 2 literally would bring them back.
  Do not let it.

  The admin pages are rendered whole on the server and navigate as
  ordinary page loads. Funky.SPA intercepts every same-origin anchor at
  the document, which took back, forward, reload and the query-string
  filters (`/jobs?state=failed`) away from the browser, and let a
  websocket `entity_change` re-fetch and swap the page under the reader
  - `Pages.handleDataChange`'s `'refresh'` branch, which is the action
  our own bridge supplied by default. app.js carries a thirty-line page
  registry in its place.

  Funky.History and Funky.Navigation were referenced by nothing, not
  even by 22-spa.js, while the SPA was still here.

  The gaps at 16/17/20/21/22 in the numbering are this decision, not an
  oversight. Do not renumber the survivors: the prefixes are both the
  concatenation order and the correspondence to upstream.

- js/components/table.js drags no extra files, but is 370KB unminified
  and all-or-nothing; accepted.
- datatables-funky.css (legacy jQuery DataTables skin; the few
  .bulk-actions rules it carried are reproduced in punk-queue.css).
- vendor/bootstrap, vendor/fontawesome, fonts/, icons/ (see checkpoint).
- js/core/tabs.js, popover, tooltip, forms machinery, pwa/*, sw/*,
  dev/* - nothing in these pages initialises them.
