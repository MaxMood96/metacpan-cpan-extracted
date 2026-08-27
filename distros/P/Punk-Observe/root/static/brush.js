/* brush.js - drag to select a time range, and one crosshair across the page.
 *
 * This is the module that makes the UI one tool rather than nine pages.
 *
 * THE URL CARRIES THE STATE. A brushed range rewrites the query string and
 * re-fetches, so every view is a link. That is not a nicety: an incident gets
 * shared by pasting a URL into a chat window, and a view that cannot be
 * linked to has to be described instead.
 *
 * A chart opts in by MARKUP alone - `data-brush` with the time range it
 * covers - so a new chart gets this by existing, not by registering.
 *
 * No dependency, no build step, no external reference.
 */
(function () {
  'use strict';

  /* The nanosecond arithmetic lives in nsmath.js, which the layout loads
   * first. It was here until the charts needed the same carry loop, and two
   * copies of one is two places for it to be wrong. */
  var NS = (typeof window !== 'undefined' && window.PONs)
        || (typeof require === 'function' ? require('./nsmath.js') : null);

  var addNs = NS.addNs;

  function setParams(kv) {
    var u = new URL(window.location.href);
    for (var k in kv) {
      if (!Object.prototype.hasOwnProperty.call(kv, k)) continue;
      if (kv[k] === null) u.searchParams.delete(k);
      else u.searchParams.set(k, kv[k]);
    }
    window.location.href = u.toString();
  }

  function Brush(node) {
    this.node = node;
    this.from = node.getAttribute('data-from');
    this.to   = node.getAttribute('data-to');
    this.sel  = null;
    this.x0   = 0;
  }

  Brush.prototype.span = function () {
    /* The visible width in nanoseconds, as a Number. Safe: it is a DURATION,
     * not an instant, and a chart never spans 2^53 nanoseconds (104 days is
     * 9e15). The instants stay strings. */
    var f = Number(this.from), t = Number(this.to);
    return (isFinite(f) && isFinite(t) && t > f) ? t - f : 0;
  };

  Brush.prototype.at = function (clientX) {
    var r = this.node.getBoundingClientRect();
    var frac = (clientX - r.left) / (r.width || 1);
    if (frac < 0) frac = 0;
    if (frac > 1) frac = 1;
    return frac;
  };

  Brush.prototype.begin = function (e) {
    var self = this;
    this.x0 = this.at(e.clientX);
    this.sel = document.createElement('div');
    this.sel.className = 'brush-sel';
    this.node.appendChild(this.sel);

    function move(ev) { self.draw(self.at(ev.clientX)); }
    function up(ev) {
      document.removeEventListener('mousemove', move);
      document.removeEventListener('mouseup', up);
      self.commit(self.at(ev.clientX), ev.shiftKey);
    }
    document.addEventListener('mousemove', move);
    document.addEventListener('mouseup', up);
  };

  Brush.prototype.draw = function (x1) {
    if (!this.sel) return;
    var a = Math.min(this.x0, x1), b = Math.max(this.x0, x1);
    this.sel.style.left  = (a * 100) + '%';
    this.sel.style.width = ((b - a) * 100) + '%';
  };

  Brush.prototype.commit = function (x1, pan) {
    var a = Math.min(this.x0, x1), b = Math.max(this.x0, x1);
    if (this.sel && this.sel.parentNode) this.sel.parentNode.removeChild(this.sel);
    this.sel = null;

    var span = this.span();
    if (!span) return;
    /* A click is not a zero-width range. Under two pixels' worth is a click,
     * and a click that silently selected an empty range would look like the
     * chart had broken. */
    if (b - a < 0.005) return;

    if (pan) {
      var shift = (a - this.x0) * span;
      setParams({ from: addNs(this.from, shift), to: addNs(this.to, shift) });
      return;
    }
    setParams({ from: addNs(this.from, a * span),
                to:   addNs(this.from, b * span) });
  };

  /* Zoom out doubles the range around its centre. */
  function zoomOut(b) {
    var span = b.span();
    if (!span) return;
    setParams({ from: addNs(b.from, -span / 2), to: addNs(b.to, span / 2) });
  }

  /* ONE crosshair for the whole page, from ONE listener on the container.
   * A listener per chart, each moving its own element, is what makes three
   * charts feel like three pages. */
  function crosshair(charts) {
    var container = document.querySelector('[data-charts]') || document.body;
    var lines = [], i;
    for (i = 0; i < charts.length; i++) {
      var l = document.createElement('div');
      l.className = 'crosshair';
      l.hidden = true;
      charts[i].appendChild(l);
      lines.push(l);
    }
    container.addEventListener('mousemove', function (e) {
      for (var k = 0; k < charts.length; k++) {
        var r = charts[k].getBoundingClientRect();
        var x = e.clientX - r.left;
        if (x < 0 || x > r.width) { lines[k].hidden = true; continue; }
        lines[k].hidden = false;
        /* transform, not `left`: one composited move per chart rather than a
         * layout pass over every row beneath it. */
        lines[k].style.transform = 'translateX(' + x + 'px)';
      }
    });
    container.addEventListener('mouseleave', function () {
      for (var k = 0; k < lines.length; k++) lines[k].hidden = true;
    });
  }

  function init() {
    var nodes = document.querySelectorAll('[data-brush]');
    var charts = [], i;
    for (i = 0; i < nodes.length; i++) {
      (function (node) {
        var b = new Brush(node);
        charts.push(node);
        node.addEventListener('mousedown', function (e) {
          if (e.button !== 0) return;
          e.preventDefault();
          b.begin(e);
        });
        node.addEventListener('dblclick', function () { zoomOut(b); });
      })(nodes[i]);
    }
    if (charts.length) crosshair(charts);

    /* An exemplar dot is a link to its trace: the cross-signal jump as one
     * click, which is the interaction the storage design was arranged to make
     * possible. Delegated, so dots redrawn by a re-fetch still work. */
    document.addEventListener('click', function (e) {
      var t = e.target;
      while (t && t !== document) {
        if (t.getAttribute && t.getAttribute('data-trace')) {
          var href = t.getAttribute('data-trace-href');
          if (href) window.location.href = href;
          return;
        }
        t = t.parentNode;
      }
    });
  }

  /* Under a test runner there is no document. The pure arithmetic above is
   * exported so it can be EXECUTED rather than grepped: a regular expression
   * over source is not a test of what the code does. */
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = { addNs: addNs, strAdd: NS.strAdd, strSub: NS.strSub,
                       strCmp: NS.strCmp };
  }

  if (typeof document === 'undefined') return;
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else init();
})();
