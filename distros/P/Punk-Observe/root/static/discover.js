/* discover.js - a filter key click composes into the query box.
 *
 * The "What you can filter on" panel lists attribute keys. Each is a real
 * link - `<source> | by key | count`, on the current page - so the feature
 * is complete with scripting off. This module upgrades the click: instead of
 * navigating, it puts the CURRENT query back in the box with
 * `| where <key> = ` appended and the cursor at the end, which is the
 * composing gesture the link can only approximate.
 *
 * Delegated, so keys re-rendered by a later fetch still work; bails without
 * a document, like every module here. No dependency, no external reference.
 */
(function () {
  'use strict';

  function init() {
    document.addEventListener('click', function (e) {
      var t = e.target;
      while (t && t !== document && !(t.getAttribute && t.getAttribute('data-qappend')))
        t = t.parentNode;
      if (!t || t === document) return;

      var box = document.querySelector('.toolbar input[name="q"]');
      if (!box) return;                 /* no box, the link is the behaviour */

      e.preventDefault();
      /* The SERVER composed the text - current query plus the where stage -
       * so the box and the href agree about what the base was. Focus with
       * the cursor at the end: the next keystroke is the value. */
      box.value = t.getAttribute('data-qappend');
      box.focus();
      try { box.setSelectionRange(box.value.length, box.value.length); }
      catch (err) {}
    });
  }

  if (typeof module !== 'undefined' && module.exports) {
    module.exports = {};                /* nothing pure to export; see t/95 */
  }

  if (typeof document === 'undefined') return;
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else init();
})();
