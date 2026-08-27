/* plot.js - the charts, drawn by Plotly from a figure the server computed.
 *
 * A chart is markup plus a block of JSON:
 *
 *     <div class="chartwrap" data-chart data-from="..." data-to="...">
 *       <script type="application/json" data-plot>{"data":[...]}</script>
 *     </div>
 *
 * THE FIGURE IS DATA, NOT CODE. It arrives in a script block of type
 * application/json - which a browser does not execute - rather than as a
 * `Plotly.newPlot(...)` call written into the page. A figure carrying a
 * service name or a log body is untrusted input, and the difference between
 * the two forms is whether that input is parsed or run.
 *
 * COLOUR COMES FROM THE STYLESHEET, NEVER FROM PLOTLY. The categorical ramp
 * in observe.css was measured for perceptual distance under two simulated
 * colour vision deficiencies; Plotly's own colorway was not. So every colour
 * in every figure is read back off the custom properties at draw time, which
 * is also what makes one figure correct in both themes.
 *
 * No build step, no external reference. Loaded from the mount like the rest.
 */
(function () {
  'use strict';

  var NS = (typeof window !== 'undefined' && window.PONs)
        || (typeof require === 'function' ? require('./nsmath.js') : null);

  /* ---- the palette, read from the document ------------------------------ */

  function tokens(el) {
    var cs = (typeof getComputedStyle === 'function')
           ? getComputedStyle(el || document.documentElement) : null;
    var get = function (name, fallback) {
      if (!cs) return fallback;
      var v = cs.getPropertyValue(name);
      v = v ? v.replace(/^\s+|\s+$/g, '') : '';
      return v.length ? v : fallback;
    };
    var series = [], i;
    for (i = 1; i <= 8; i++) series.push(get('--series-' + i, '#888'));
    return {
      series: series,
      ink:    get('--ink',   '#16181d'),
      muted:  get('--muted', '#5a6069'),
      faint:  get('--faint', '#878d97'),
      line:   get('--line',  'rgba(0,0,0,.14)'),
      paper:  get('--paper', '#f7f8fa'),
      /* The alert states, so a band on the timeline is the same colour as the
       * badge on the row beside it. Two spellings of one state would be two
       * states as far as a reader is concerned. */
      ok:     get('--ok',    '#0b7a55'),
      warn:   get('--warn',  '#9a5b00'),
      err:    get('--err',   '#b32330'),
      sev: {
        trace: get('--sev-trace', '#9aa8b0'), debug: get('--sev-debug', '#5895b7'),
        info:  get('--sev-info',  '#468362'), warn:  get('--sev-warn',  '#7d5e22'),
        error: get('--sev-error', '#8c322f'), fatal: get('--sev-fatal', '#5d2546')
      }
    };
  }

  /* A figure names a colour by ROLE - "series:2", "sev:error" - and the role
   * is resolved here. A figure that named a hex would be a figure that is
   * wrong in one of the two themes, and the server has no idea which theme
   * the reader is in. */
  function resolve(spec, t) {
    if (typeof spec !== 'string') return spec;
    var m = /^series:(\d+)$/.exec(spec);
    if (m) return t.series[(parseInt(m[1], 10) || 0) % t.series.length];
    m = /^sev:([a-z]+)$/.exec(spec);
    if (m) return t.sev[m[1]] || t.muted;
    if (spec === 'ink') return t.ink;
    if (spec === 'muted') return t.muted;
    if (spec === 'faint') return t.faint;
    if (spec === 'line') return t.line;
    if (spec === 'paper') return t.paper;
    if (spec === 'ok') return t.ok;
    if (spec === 'warn') return t.warn;
    if (spec === 'err') return t.err;
    return spec;
  }

  /* WHICH KEYS HOLD A COLOUR. Plotly spells them `color`, `colors`,
   * `colorway`, `bgcolor`, `fillcolor`, `colorscale` - every one contains the
   * word, which is a more durable rule than a list that goes stale the first
   * time a new trace type is used.
   *
   * It has to be a rule at all because resolve() answers to bare words -
   * `ok`, `line`, `err` - and those are also perfectly ordinary DATA. A
   * Sankey node named "line", or a bar chart grouped by alert state with an
   * `ok` bucket, would otherwise have its label rewritten into a hex. */
  function isColorKey(k) {
    return typeof k === 'string' && k.toLowerCase().indexOf('color') >= 0;
  }

  /* Walk the figure and resolve every role, wherever it sits. Colours live at
   * a dozen different depths in a Plotly figure - marker.color, line.color,
   * marker.line.color, a colorscale's stops.
   *
   * AND IN ARRAYS. A per-point colour is an array the same length as the
   * data - which is how a Sankey colours one link per edge - and this used to
   * hand each element back to itself: paint() returns anything that is not an
   * object unchanged, so a role sitting in an array was walked over rather
   * than resolved. Plotly then received the literal string "sev:error", made
   * nothing of it, and drew the links black. */
  function paint(node, t, key) {
    if (node === null || typeof node !== 'object') return node;
    var i, k;
    if (Object.prototype.toString.call(node) === '[object Array]') {
      for (i = 0; i < node.length; i++) {
        node[i] = (isColorKey(key) && typeof node[i] === 'string')
                ? resolve(node[i], t)
                : paint(node[i], t, key);   /* key carries into a colorscale */
      }
      return node;
    }
    for (k in node) {
      if (!Object.prototype.hasOwnProperty.call(node, k)) continue;
      if (typeof node[k] === 'string') {
        if (isColorKey(k)) node[k] = resolve(node[k], t);
      }
      else node[k] = paint(node[k], t, k);
    }
    return node;
  }

  /* ---- the layout every chart shares ------------------------------------ */

  function baseLayout(t) {
    return {
      paper_bgcolor: 'rgba(0,0,0,0)',
      plot_bgcolor:  'rgba(0,0,0,0)',
      colorway: t.series,
      font: { color: t.muted, size: 11,
              family: 'ui-sans-serif, system-ui, -apple-system, sans-serif' },
      margin: { l: 48, r: 12, t: 8, b: 32 },
      xaxis: { gridcolor: t.line, zerolinecolor: t.line, linecolor: t.line,
               automargin: true },
      yaxis: { gridcolor: t.line, zerolinecolor: t.line, linecolor: t.line,
               automargin: true },
      legend: { orientation: 'h', y: -0.2, font: { color: t.muted } },
      hoverlabel: { bgcolor: t.paper, bordercolor: t.line,
                    font: { color: t.ink } },
      showlegend: true
    };
  }

  /* A deep merge, because a figure overrides one axis property and must not
   * lose the other nine by supplying its own axis object. */
  function merge(base, over) {
    var out = {}, k;
    for (k in base) if (Object.prototype.hasOwnProperty.call(base, k)) out[k] = base[k];
    for (k in over) {
      if (!Object.prototype.hasOwnProperty.call(over, k)) continue;
      if (over[k] && typeof over[k] === 'object'
       && Object.prototype.toString.call(over[k]) !== '[object Array]'
       && base[k] && typeof base[k] === 'object') {
        out[k] = merge(base[k], over[k]);
      } else out[k] = over[k];
    }
    return out;
  }

  var CONFIG = {
    displaylogo: false,
    responsive: false,          /* handled here, so a resize is one redraw */
    modeBarButtonsToRemove: [ 'select2d', 'lasso2d', 'autoScale2d',
                              'toggleSpikelines' ],
    doubleClick: false          /* the range lives in the URL, see below */
  };

  /* ---- the URL is the state --------------------------------------------- */

  function setParams(kv) {
    var u = new URL(window.location.href), k;
    for (k in kv) {
      if (!Object.prototype.hasOwnProperty.call(kv, k)) continue;
      if (kv[k] === null) u.searchParams.delete(k);
      else u.searchParams.set(k, kv[k]);
    }
    window.location.href = u.toString();
  }

  /* A ZOOM IS A NEW QUERY, NOT A NEW VIEW OF THE SAME ROWS.
   *
   * Plotly can rescale what it already has, but what it already has is the
   * result of a query over the old window - already aggregated, already
   * pruned, and already truncated if it hit the budget. Rescaling it would
   * magnify a summary and present it as detail.
   *
   * So a zoom rewrites the range in the URL and asks the server again, which
   * is also what makes the view linkable.
   *
   * The endpoints are computed in decimal. Plotly reports the axis range in
   * milliseconds as a Number, and a nanosecond instant does not survive one.
   */
  function onRelayout(wrap, ev) {
    if (!ev) return;
    if (ev['xaxis.autorange'] || ev.autosize) return;
    var a = ev['xaxis.range[0]'], b = ev['xaxis.range[1]'];
    if (a === undefined || b === undefined) return;

    var from = wrap.getAttribute('data-from'), to = wrap.getAttribute('data-to');
    if (!from || !to) return;

    var ms = function (v) {
      if (typeof v === 'number') return v;
      var d = Date.parse(v);
      return isFinite(d) ? d : NaN;
    };
    var lo = ms(a), hi = ms(b);
    if (!isFinite(lo) || !isFinite(hi) || hi <= lo) return;

    setParams({
      from:  NS.lerpNs(from, to, NS.fracOf(from, to, lo)),
      to:    NS.lerpNs(from, to, NS.fracOf(from, to, hi)),
      range: null                 /* an explicit window outranks a named one */
    });
  }

  /* A point that carries a trace id is a link to that trace. The cross-signal
   * jump as one click is the interaction the storage design was arranged to
   * make possible, so it is one click. */
  function onClick(wrap, ev) {
    if (!ev || !ev.points || !ev.points.length) return;
    var p = ev.points[0];
    var id = p.customdata;
    if (id === null || id === undefined) return;
    if (Object.prototype.toString.call(id) === '[object Array]') id = id[0];
    if (!id) return;
    var base = wrap.getAttribute('data-trace-base');
    if (base) window.location.href = base + id;
  }

  /* ---- drawing ----------------------------------------------------------- */

  var charts = [];

  function figureOf(wrap) {
    var src = wrap.querySelector('script[type="application/json"][data-plot]');
    if (!src) return null;
    try { return JSON.parse(src.textContent || src.innerHTML || 'null'); }
    catch (e) { return null; }
  }

  function draw(wrap, fig) {
    var t = tokens();
    /* The figure is re-read from source each time rather than mutated in
     * place: paint() resolves roles to hexes, and a repainted figure would
     * have no roles left to resolve on the next theme change. */
    var data = paint(JSON.parse(JSON.stringify(fig.data || [])), t);
    var layout = merge(baseLayout(t), paint(JSON.parse(
                   JSON.stringify(fig.layout || {})), t));
    var config = merge(CONFIG, fig.config || {});
    return window.Plotly.react(wrap, data, layout, config);
  }

  function mount(wrap) {
    var fig = figureOf(wrap);
    if (!fig || !fig.data) return;

    var entry = { node: wrap, fig: fig, ro: null, timer: null };
    draw(wrap, fig);

    wrap.on && wrap.on('plotly_relayout', function (ev) { onRelayout(wrap, ev); });
    wrap.on && wrap.on('plotly_click', function (ev) { onClick(wrap, ev); });

    /* Debounced, because a drag on a panel edge fires this continuously and
     * a redraw per event makes the whole page stutter. */
    if (typeof ResizeObserver === 'function') {
      entry.ro = new ResizeObserver(function () {
        if (entry.timer) clearTimeout(entry.timer);
        entry.timer = setTimeout(function () {
          if (wrap.isConnected === false) return;
          window.Plotly.Plots.resize(wrap);
        }, 80);
      });
      entry.ro.observe(wrap);
    }

    charts.push(entry);
  }

  /* THE THEME IS NOT CSS HERE. Every other component follows a custom
   * property and needs nothing; a Plotly figure has the colours baked into it
   * at draw time, so the theme control has to redraw them. */
  function retheme() {
    for (var i = 0; i < charts.length; i++) draw(charts[i].node, charts[i].fig);
  }

  function init() {
    if (typeof window.Plotly === 'undefined') return;   /* nothing to draw with */
    var nodes = document.querySelectorAll('[data-chart]'), i;
    for (i = 0; i < nodes.length; i++) mount(nodes[i]);
    if (!charts.length) return;

    if (typeof MutationObserver === 'function') {
      new MutationObserver(retheme).observe(document.documentElement,
        { attributes: true, attributeFilter: ['data-theme'] });
    }
    /* The system theme, for a reader who has chosen neither light nor dark.
     * Without this the page follows the change and the charts do not. */
    if (window.matchMedia) {
      var mq = window.matchMedia('(prefers-color-scheme: dark)');
      if (mq.addEventListener) mq.addEventListener('change', retheme);
      else if (mq.addListener) mq.addListener(retheme);
    }
  }

  /* Exported so the pure parts can be EXECUTED by a test rather than grepped.
   * A regular expression over source is not a test of what code does. */
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = { resolve: resolve, paint: paint, merge: merge,
                       baseLayout: baseLayout };
  }

  if (typeof document === 'undefined') return;
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else init();
})();
