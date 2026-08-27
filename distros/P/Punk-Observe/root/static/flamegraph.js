/* flamegraph.js - click to zoom, and a search that reports its coverage.
 *
 * Zooming recomputes widths from the clicked node's subtree, which is
 * arithmetic over rects already in the DOM. No round trip, no re-render.
 *
 * The search box reports the MATCHED FRACTION of total time, which is the
 * number people actually want from a flamegraph and which almost none of them
 * show: "these frames are 34% of the time" is an answer, a set of highlighted
 * boxes is a picture.
 */
(function () {
  'use strict';
  /* Loaded from the layout on every page, including ones with no chart on
   * them and, under a test runner, with no document at all. Bail before
   * touching the DOM rather than throwing on load. */
  if (typeof document === 'undefined') return;
  var fg = document.getElementById('flame');
  if (!fg) return;

  var rects = Array.prototype.slice.call(fg.querySelectorAll('[data-self]'));
  var total = rects.reduce(function (a, r) {
    return a + (+r.getAttribute('data-self') || 0);
  }, 0);

  function zoom(root) {
    var base = +root.getAttribute('data-total') || total;
    var baseDepth = +root.getAttribute('data-depth') || 0;
    var path = root.getAttribute('data-path') || '';
    rects.forEach(function (r) {
      var p = r.getAttribute('data-path') || '';
      var inside = p === path || p.indexOf(path + '/') === 0;
      r.style.display = inside ? '' : 'none';
      if (!inside) return;
      var w = base ? (+r.getAttribute('data-total') / base) * 100 : 0;
      var x = base ? ((+r.getAttribute('data-start') -
                       +root.getAttribute('data-start')) / base) * 100 : 0;
      r.setAttribute('x', x + '%');
      r.setAttribute('width', Math.max(w, 0.05) + '%');
      r.setAttribute('y', ((+r.getAttribute('data-depth') - baseDepth) * 18));
    });
  }

  fg.addEventListener('click', function (e) {
    var t = e.target;
    if (t && t.hasAttribute && t.hasAttribute('data-self')) zoom(t);
  });

  var reset = document.getElementById('flame-reset');
  if (reset) reset.addEventListener('click', function () {
    var root = rects.filter(function (r) {
      return +r.getAttribute('data-depth') === 0;
    })[0];
    if (root) zoom(root);
  });

  var box = document.getElementById('flame-search');
  var out = document.getElementById('flame-matched');
  if (box) box.addEventListener('input', function () {
    var q = box.value.toLowerCase();
    var matched = 0;
    rects.forEach(function (r) {
      var hit = q && (r.getAttribute('data-name') || '').toLowerCase()
                        .indexOf(q) >= 0;
      r.classList.toggle('hit', !!hit);
      if (hit) matched += +r.getAttribute('data-self') || 0;
    });
    if (out) {
      out.textContent = q
        ? (total ? (matched / total * 100).toFixed(1) : '0') + '% of total time'
        : '';
    }
  });
})();
