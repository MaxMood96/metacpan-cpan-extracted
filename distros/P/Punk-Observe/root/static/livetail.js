/* livetail.js - the log tail, over SSE.
 *
 * Everything on the logs page renders without this file. What it adds is
 * MOVEMENT, and three pieces of honesty that a naive tail gets wrong:
 *
 *   1. THE DOM IS A BOUNDED RING. A busy tail appends thousands of rows a
 *      minute. Left alone the tab consumes a gigabyte and stops responding
 *      within the hour, and the user's conclusion is that the product is
 *      broken. At most MAX_ROWS live, dropping from the top, and the count of
 *      what scrolled off is shown.
 *
 *   2. IT PAUSES WHEN THE USER SCROLLS UP. A list that jumps while it is
 *      being read is unusable. Paused it says so, and says how many lines are
 *      waiting.
 *
 *   3. IT SHOWS WHAT WAS LOST. A truncated line carries a marker, a gap
 *      carries a number. A silently short stream is indistinguishable from a
 *      quiet one, which is the whole reason the server counts these.
 *
 * No dependency, no build step, no external reference.
 */
(function () {
  'use strict';

  var MAX_ROWS = 2000;

  function el(tag, cls, text) {
    var n = document.createElement(tag);
    if (cls) n.className = cls;
    if (text !== undefined && text !== null) n.textContent = String(text);
    return n;
  }

  function Tail(root) {
    this.root    = root;
    this.list    = root.querySelector('[data-tail-rows]') || root;
    this.status  = root.querySelector('[data-tail-status]');
    this.url     = root.getAttribute('data-tail');
    this.paused  = false;
    this.pending = [];
    this.dropped = 0;      /* scrolled off the top of the DOM ring */
    this.missed  = 0;      /* reported by the server as never delivered */
    this.lastId  = null;
    this.src     = null;
    this.retry   = null;
  }

  /* Pausing is decided by scroll POSITION, not by a mouse event: a user who
   * has scrolled up is reading, whatever the pointer is doing. */
  Tail.prototype.atBottom = function () {
    var l = this.list;
    return l.scrollHeight - l.scrollTop - l.clientHeight < 24;
  };

  Tail.prototype.setStatus = function () {
    if (!this.status) return;
    var bits = [];
    if (this.paused) bits.push('paused, ' + this.pending.length + ' waiting');
    if (this.dropped) bits.push(this.dropped + ' scrolled off');
    /* Never merged into the line above: one is this browser discarding rows
     * it has already shown, the other is rows that never arrived at all. */
    if (this.missed) bits.push(this.missed + ' dropped by the server');
    this.status.textContent = bits.join(' - ');
    this.status.hidden = bits.length === 0;
  };

  Tail.prototype.row = function (rec) {
    var tr = el('div', 'logrow' + (rec.sev_name ? ' row-' + rec.sev_name : ''));
    tr.appendChild(el('span', 'col-time', rec.time || ''));
    tr.appendChild(el('span', 'col-sev sev-' + (rec.sev_name || 'info'),
                      rec.sev_name || ''));
    tr.appendChild(el('span', 'col-svc', rec.service || ''));
    var body = el('span', 'col-body', rec.body || '');
    if (rec.truncated) {
      /* A marker, and a way to the whole record. A truncation the reader can
       * see is a different thing from a line that never arrived. */
      var mark = el('a', 'truncated', ' [truncated]');
      if (rec.id) mark.href = this.root.getAttribute('data-record') + rec.id;
      body.appendChild(mark);
    }
    tr.appendChild(body);
    return tr;
  };

  Tail.prototype.append = function (recs) {
    var i, frag = document.createDocumentFragment();
    for (i = 0; i < recs.length; i++) frag.appendChild(this.row(recs[i]));
    this.list.appendChild(frag);

    /* Trim from the top in one pass. removeChild in a loop over a live
     * childNodes list is the classic way to remove every other row. */
    var over = this.list.children.length - MAX_ROWS;
    while (over-- > 0 && this.list.firstChild) {
      this.list.removeChild(this.list.firstChild);
      this.dropped++;
    }
    this.list.scrollTop = this.list.scrollHeight;
  };

  Tail.prototype.onRecord = function (rec) {
    if (rec.missed) this.missed += rec.missed;
    if (this.paused) {
      this.pending.push(rec);
      /* The pending queue is bounded too, or pausing for ten minutes on a
       * busy stream is the same memory bug by another route. */
      if (this.pending.length > MAX_ROWS) {
        this.pending.shift();
        this.dropped++;
      }
      this.setStatus();
      return;
    }
    this.append([ rec ]);
    this.setStatus();
  };

  Tail.prototype.resume = function () {
    this.paused = false;
    if (this.pending.length) { this.append(this.pending); this.pending = []; }
    this.setStatus();
  };

  Tail.prototype.start = function () {
    var self = this;
    if (!this.url || typeof EventSource === 'undefined') return;

    /* THE CURSOR GOES IN THE URL, and the connection is reopened by this
     * code rather than by the browser.
     *
     * An EventSource reconnects on its own and sends Last-Event-ID, which
     * works right up until something between here and the server does not
     * forward the header. What that looks like is not an error: it is the
     * same page of lines arriving again every few seconds, for ever, and it
     * is what this tail did. Reopening explicitly means the cursor is in the
     * URL, where nothing can drop it. */
    var url = this.url;
    if (this.lastId) {
      url += (url.indexOf('?') === -1 ? '?' : '&') + 'since=' + this.lastId;
    }
    this.src = new EventSource(url);

    this.src.addEventListener('error', function () {
      /* CLOSED means it will not retry by itself; anything else means it is
       * already retrying and reopening here would make two connections. */
      if (self.src && self.src.readyState === 2) {
        self.stop();
        self.retry = setTimeout(function () { self.start(); }, 2000);
      }
    });

    this.src.addEventListener('log', function (e) {
      var rec;
      try { rec = JSON.parse(e.data); } catch (err) { return; }
      /* TWO DIFFERENT IDENTIFIERS, and conflating them costs one of them.
       * The event id is the record's TIMESTAMP and is the resume cursor; the
       * payload's id is the record's own identifier and is what a row links
       * to. Overwriting the second with the first gives every row a link to
       * a record that does not exist. */
      if (e.lastEventId) self.lastId = e.lastEventId;
      self.onRecord(rec);
    });

    /* A named event for the gap, so it cannot be mistaken for a log line. */
    this.src.addEventListener('gap', function (e) {
      var g;
      try { g = JSON.parse(e.data); } catch (err) { return; }
      self.missed += (g.missed || 0);
      self.setStatus();
    });

    /* Bound ONCE, not per connection: start() runs again on every reconnect,
     * and a listener added each time is a listener run N times per scroll. */
    if (!this.bound) {
      this.bound = true;
      this.list.addEventListener('scroll', function () {
        if (self.atBottom()) { if (self.paused) self.resume(); }
        else if (!self.paused) { self.paused = true; self.setStatus(); }
      });
    }
  };

  Tail.prototype.stop = function () {
    if (this.retry) { clearTimeout(this.retry); this.retry = null; }
    if (this.src) { this.src.close(); this.src = null; }
  };

  function init() {
    var nodes = document.querySelectorAll('[data-tail]');
    for (var i = 0; i < nodes.length; i++) new Tail(nodes[i]).start();
  }

  /* No document under a test runner, and none of this means anything without
   * one. Bail before touching it rather than throwing on load. */
  if (typeof document === 'undefined') return;
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else init();
})();
