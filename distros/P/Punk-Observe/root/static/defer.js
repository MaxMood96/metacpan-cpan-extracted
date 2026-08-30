/* defer.js - a panel that names its data arrives without it, then fetches.
 *
 * The overview used to hold its whole render behind its slowest queries; on
 * a fat store that was seconds of blank page for figures a reader may not
 * even scroll to. A deferred panel carries `data-defer="<url>"`: the page
 * ships instantly with a placeholder, this module fetches the URL - a
 * SERVER-RENDERED HTML fragment, so what arrives is exactly what inline
 * rendering would have produced - swaps it in, and mounts any charts in it
 * via PunkPlot.scan.
 *
 * `data-defer-poll="N"` re-fetches every N seconds, so the numbers stay
 * current without anybody reloading. Polling pauses while the tab is
 * hidden - a wall of background tabs each re-running the store's heaviest
 * queries is a self-inflicted load test - and catches up once on return.
 *
 * Scripting off is not a dead panel: the placeholder's <noscript> link
 * re-requests the page with ?full=1, which renders the same fragment
 * inline. No dependency, no external reference; bails without a document.
 */
(function () {
  'use strict';

  /* The poll interval, bounded: a zero or garbage attribute means "do not
   * poll", and anything under 5s is raised to 5 - the fragments exist
   * because these queries are the expensive ones. */
  function pollSeconds(attr) {
    var n = parseInt(attr, 10);
    if (!attr || isNaN(n) || n <= 0) return 0;
    return n < 5 ? 5 : n;
  }

  function refresh(node, url, done) {
    var xhr = new XMLHttpRequest();
    xhr.open('GET', url, true);
    xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
    xhr.onreadystatechange = function () {
      if (xhr.readyState !== 4) return;
      if (xhr.status === 200 && xhr.responseText) {
        node.innerHTML = xhr.responseText;
        if (window.PunkPlot) window.PunkPlot.scan(node);
      }
      /* A failed fetch keeps the placeholder (first load) or the previous
       * answer (poll) - stale data over an error box, on a panel whose
       * whole job is a glance. The next poll tries again. */
      if (done) done();
    };
    xhr.send();
  }

  function arm(node) {
    var url = node.getAttribute('data-defer');
    if (!url) return;
    var every = pollSeconds(node.getAttribute('data-defer-poll'));
    var behind = false;
    var inflight = false;

    function tick() {
      if (inflight) return;
      if (document.hidden) { behind = true; return; }
      inflight = true;
      refresh(node, url, function () { inflight = false; });
    }

    tick();
    if (!every) return;
    setInterval(tick, every * 1000);
    document.addEventListener('visibilitychange', function () {
      if (!document.hidden && behind) { behind = false; tick(); }
    });
  }

  function init() {
    var nodes = document.querySelectorAll('[data-defer]'), i;
    for (i = 0; i < nodes.length; i++) arm(nodes[i]);
  }

  if (typeof module !== 'undefined' && module.exports) {
    module.exports = { pollSeconds: pollSeconds };
  }

  if (typeof document === 'undefined') return;
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else init();
})();
