/* nsmath.js - decimal arithmetic on nanosecond instants.
 *
 * A nanosecond instant does not fit a double. A Number holding 1.7e18 is off
 * by hundreds of nanoseconds: invisible on a chart, wrong in a URL, and the
 * URL is what somebody pastes into a query. So every instant in this UI is a
 * decimal STRING, and the arithmetic on it is done on the digits.
 *
 * Shared by brush.js and plot.js. It was brush.js's private arithmetic until
 * the charts needed the same thing, and two copies of a carry loop is two
 * places for it to be wrong.
 *
 * No dependency, no build step, no external reference.
 */
(function () {
  'use strict';

  function strTrim(a) { return a.replace(/^0+(?=\d)/, ''); }

  function strAdd(a, b) {
    var out = '', carry = 0, i = a.length - 1, j = b.length - 1;
    while (i >= 0 || j >= 0 || carry) {
      var s = (i >= 0 ? a.charCodeAt(i--) - 48 : 0)
            + (j >= 0 ? b.charCodeAt(j--) - 48 : 0) + carry;
      out = String(s % 10) + out;
      carry = s >= 10 ? 1 : 0;
    }
    return strTrim(out);
  }

  function strCmp(a, b) {
    a = strTrim(a); b = strTrim(b);
    if (a.length !== b.length) return a.length < b.length ? -1 : 1;
    return a < b ? -1 : (a > b ? 1 : 0);
  }

  function strSub(a, b) {          /* a >= b, both non-negative */
    var out = '', borrow = 0, i = a.length - 1, j = b.length - 1;
    while (i >= 0) {
      var s = (a.charCodeAt(i--) - 48)
            - (j >= 0 ? b.charCodeAt(j--) - 48 : 0) - borrow;
      if (s < 0) { s += 10; borrow = 1; } else borrow = 0;
      out = String(s) + out;
    }
    return strTrim(out);
  }

  function addNs(base, delta) {
    base = String(base);
    if (!/^\d+$/.test(base)) return base;
    if (!isFinite(delta)) return base;
    var neg = delta < 0;
    var d = Math.abs(Math.round(delta)).toFixed(0);
    if (!neg) return strAdd(base, d);
    /* Clamped at zero rather than allowed to go negative: a URL with a
     * negative instant in it is a query nothing can answer. */
    if (strCmp(base, d) <= 0) return '0';
    return strSub(base, d);
  }

  /* Multiply a decimal string by a non-negative integer that fits a double.
   * Schoolbook, least significant digit first, so the carry can exceed 9. */
  function strMulInt(a, m) {
    if (m === 0) return '0';
    var out = [], carry = 0, i;
    for (i = a.length - 1; i >= 0; i--) {
      var p = (a.charCodeAt(i) - 48) * m + carry;
      out.push(p % 10);
      carry = Math.floor(p / 10);
    }
    while (carry > 0) { out.push(carry % 10); carry = Math.floor(carry / 10); }
    return strTrim(out.reverse().join('')) || '0';
  }

  /* Divide a decimal string by 10^n, rounding half up. Dropping digits is a
   * substring; the rounding is the digit that falls off the end. */
  function strDivPow10(a, n) {
    a = strTrim(a);
    if (n <= 0) return a;
    if (a.length <= n) {
      /* The result is 0 or 1: everything is below the point. */
      var lead = a.length === n ? a.charCodeAt(0) - 48 : 0;
      return lead >= 5 ? '1' : '0';
    }
    var keep = a.slice(0, a.length - n);
    var next = a.charCodeAt(a.length - n) - 48;
    return next >= 5 ? strAdd(keep, '1') : strTrim(keep);
  }

  /* THE INSTANT A FRACTION OF THE WAY THROUGH A WINDOW.
   *
   * This is what a brushed selection and a Plotly zoom both reduce to: the
   * chart reports a position as a fraction, and the answer has to be an exact
   * instant.
   *
   * The delta is NOT taken as a Number. brush.js used to argue that no chart
   * spans 2^53 nanoseconds because 104 days is 9e15 - true of every named
   * range except `all`, which is the one an operator reaches for when their
   * data is older than the default, and a year is 3.2e16. So the span is
   * subtracted as digits, scaled by a billionth-resolution integer, and
   * divided back down.
   */
  function lerpNs(from, to, frac) {
    from = strTrim(String(from));
    to   = strTrim(String(to));
    if (!/^\d+$/.test(from) || !/^\d+$/.test(to)) return from;
    if (!isFinite(frac)) return from;
    if (frac <= 0) return from;
    if (frac >= 1) return to;
    if (strCmp(to, from) <= 0) return from;

    var span = strSub(to, from);
    var scale = Math.round(frac * 1e9);       /* exact in a double */
    return strAdd(from, strDivPow10(strMulInt(span, scale), 9));
  }

  /* Milliseconds for a chart axis. Plotly plots on a Number axis, so the
   * instant has to be narrowed to one somewhere - it happens HERE, once, and
   * only for the drawing. Nothing read back off the axis is trusted as an
   * instant: the exact value travels beside the point and comes back through
   * lerpNs. */
  function toMs(ns) {
    ns = strTrim(String(ns));
    if (!/^\d+$/.test(ns)) return NaN;
    return Number(ns.length > 6 ? ns.slice(0, ns.length - 6) : '0')
         + Number(ns.length > 6 ? '0.' + ns.slice(ns.length - 6) : '0');
  }

  /* Where a millisecond position falls in a window, as a fraction. The
   * counterpart of toMs: a chart hands back a Number, and this is the only
   * thing done with it before lerpNs turns it back into digits. */
  function fracOf(from, to, ms) {
    var a = toMs(from), b = toMs(to);
    if (!isFinite(a) || !isFinite(b) || b <= a) return 0;
    var f = (ms - a) / (b - a);
    return f < 0 ? 0 : (f > 1 ? 1 : f);
  }

  var API = {
    strTrim: strTrim, strAdd: strAdd, strCmp: strCmp, strSub: strSub,
    strMulInt: strMulInt, strDivPow10: strDivPow10,
    addNs: addNs, lerpNs: lerpNs, toMs: toMs, fracOf: fracOf
  };

  /* Exported so it can be EXECUTED rather than grepped: a regular expression
   * over source is not a test of what the code does. */
  if (typeof module !== 'undefined' && module.exports) module.exports = API;
  if (typeof window !== 'undefined') window.PONs = API;
})();
