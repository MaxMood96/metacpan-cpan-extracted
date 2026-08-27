/* waterfall.js - pan and zoom a trace.
 *
 * THE WHOLE TRICK: every bar is positioned in terms of two CSS custom
 * properties on the container. A pan rewrites TWO PROPERTIES and the browser
 * recomputes layout once. The obvious implementation - walking the bars and
 * setting each one's left and width - is four thousand DOM writes for a large
 * trace, and it is why most trace viewers stutter.
 *
 * Everything here is enhancement. The waterfall is complete and correct in
 * the markup with this file absent.
 */
(function () {
  'use strict';
  /* Loaded from the layout on every page, including ones with no chart on
   * them and, under a test runner, with no document at all. Bail before
   * touching the DOM rather than throwing on load. */
  if (typeof document === 'undefined') return;
  var wf = document.getElementById('wf');
  if (!wf) return;

  var scale = 1, offset = 0;

  function apply() {
    if (scale < 1) { scale = 1; offset = 0; }
    /* Clamp so the trace cannot be dragged off the screen entirely - a pan
     * that loses the data is a pan the user cannot undo. */
    var min = -(scale - 1) * wf.clientWidth;
    if (offset < min) offset = min;
    if (offset > 0) offset = 0;
    wf.style.setProperty('--wf-scale', scale);
    wf.style.setProperty('--wf-offset', offset + 'px');
  }

  wf.addEventListener('wheel', function (e) {
    if (!e.ctrlKey && !e.metaKey) return;
    e.preventDefault();
    var rect = wf.getBoundingClientRect();
    var at = e.clientX - rect.left;
    var before = (at - offset) / scale;
    scale *= e.deltaY < 0 ? 1.15 : 1 / 1.15;
    if (scale > 200) scale = 200;
    offset = at - before * scale;
    apply();
  }, { passive: false });

  var dragging = false, startX = 0, startOffset = 0;
  wf.addEventListener('pointerdown', function (e) {
    dragging = true; startX = e.clientX; startOffset = offset;
    wf.setPointerCapture(e.pointerId);
  });
  wf.addEventListener('pointermove', function (e) {
    if (!dragging) return;
    offset = startOffset + (e.clientX - startX);
    apply();
  });
  wf.addEventListener('pointerup', function (e) {
    dragging = false;
    try { wf.releasePointerCapture(e.pointerId); } catch (x) {}
  });

  /* Subtree collapse: a class on the row, so the CSS does the hiding. */
  wf.addEventListener('click', function (e) {
    var li = e.target.closest ? e.target.closest('li') : null;
    if (!li || dragging) return;
    var depth = +li.getAttribute('data-depth');
    var n = li.nextElementSibling;
    var hide = !li.classList.contains('collapsed');
    li.classList.toggle('collapsed', hide);
    while (n && +n.getAttribute('data-depth') > depth) {
      n.hidden = hide;
      n = n.nextElementSibling;
    }
  });

  /* Errors only, as a class on the root rather than a filter over the rows. */
  var only = document.getElementById('errors-only');
  if (only) only.addEventListener('change', function () {
    wf.classList.toggle('errors-only', only.checked);
  });

  apply();
})();
