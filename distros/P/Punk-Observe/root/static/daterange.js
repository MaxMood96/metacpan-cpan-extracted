/* daterange.js - the time range control.
 *
 * The server renders the range as a row of preset buttons and a hidden field
 * carrying the answer. That row IS the control when this file does not run:
 * every button is a submit button naming its own range, so the whole thing
 * works with JavaScript off, on a browser too old for the picker, and in the
 * seconds before this loads. What happens here is a REPLACEMENT of that row
 * by a calendar, not the arrival of a control that was missing.
 *
 * So the order matters. The buttons are hidden only once the picker has been
 * constructed successfully; every early return below leaves a working page.
 *
 * Depends on moment.js and vanilla-datetimerange-picker, both served from the
 * mount, and on nsmath.js for the arithmetic. layout.tmpl loads all three
 * before this one and `defer` runs scripts in document order, so that is the
 * ordering rather than a hope about timing.
 */
(function () {
  'use strict';

  var host = document.querySelector('[data-rangepick]');
  if (!host) return;
  if (typeof DateRangePicker !== 'function') return;
  if (typeof moment !== 'function') return;
  if (!window.PONs) return;

  var form = host.closest ? host.closest('form') : null;
  if (!form) return;

  /* The presets, read off the buttons the server drew rather than repeated
   * here. PO_RANGES lives in C and this is the only copy of it that reaches
   * the browser; a second list in JavaScript would be a second list to keep
   * in step, and the one that drifts is always the one nobody tests. */
  var buttons = host.querySelectorAll('.rangebtn');
  if (!buttons.length) return;

  var presets = [];      /* { key, label } in the server's order */
  var i;
  for (i = 0; i < buttons.length; i++) {
    var key = buttons[i].getAttribute('value');
    var label = buttons[i].getAttribute('title') || key;
    if (key) presets.push({ key: key, label: label });
  }
  if (!presets.length) return;

  function presetByLabel(label) {
    for (var j = 0; j < presets.length; j++)
      if (presets[j].label === label) return presets[j];
    return null;
  }
  function presetByKey(key) {
    for (var j = 0; j < presets.length; j++)
      if (presets[j].key === key) return presets[j];
    return null;
  }

  /* A preset key as a number of seconds. `all` is deliberately absent: it is
   * unbounded, and the span it would need here is not a duration. */
  function secondsOf(key) {
    var m = /^(\d+)([mhd])$/.exec(key);
    if (!m) return null;
    var n = Number(m[1]);
    return m[2] === 'm' ? n * 60 : (m[2] === 'h' ? n * 3600 : n * 86400);
  }

  /* ---- the fields the form actually submits ------------------------------
   *
   * `range` is always present. `from` and `to` are rendered only for a window
   * that has no preset key, so on a preset page they have to be created - and
   * they are created EMPTY, which the server reads as absent, because
   * po_ns_plausible rejects an empty string before the named range is even
   * consulted. */
  function field(name) {
    var el = form.querySelector('input[type=hidden][name=' + name + ']');
    if (!el) {
      el = document.createElement('input');
      el.type = 'hidden';
      el.name = name;
      el.value = '';
      form.appendChild(el);
    }
    return el;
  }

  var fRange = field('range'), fFrom = field('from'), fTo = field('to');

  /* Milliseconds to a nanosecond DECIMAL STRING, multiplied as digits.
   *
   * `String(ms * 1e6)` does in fact print the right digits today, and it is
   * worth being precise about why, because the reason is not that the
   * arithmetic is correct. `1755000000123 * 1e6` is 1755000000123000064 as a
   * double - doubles are 256 apart up there - and it reads correctly only
   * because String() prints the shortest decimal that round-trips, which for
   * a value with thirteen significant digits recovers those digits.
   *
   * That holds for whole milliseconds and stops holding the moment anything
   * finer arrives, or the number is added to rather than printed. This is a
   * URL somebody pastes into a query, so it does not rest on a property of
   * the formatter. */
  function toNs(m) { return window.PONs.strMulInt(String(m.valueOf()), 1000000); }

  /* And back, for seeding the picker from a window already in the URL. This
   * direction is allowed to lose sub-millisecond precision because it only
   * decides which day the calendar opens on. */
  function fromNs(ns) {
    var ms = window.PONs.toMs(ns);
    return isFinite(ms) ? moment(Math.round(ms)) : null;
  }

  /* ---- where the picker opens -------------------------------------------- */

  var active = presetByKey(fRange.value);
  var start = null, end = null;

  if (fFrom.value && fTo.value) {
    start = fromNs(fFrom.value);
    end   = fromNs(fTo.value);
  }
  if (!start || !end || !start.isValid() || !end.isValid()) {
    var secs = active ? secondsOf(active.key) : 3600;
    end = moment();
    start = moment().subtract(secs === null ? 3600 : secs, 'seconds');
  }

  /* The preset menu. `all` gets a start of the unix epoch, which is not a
   * claim about the data - it is what the calendar highlights while the
   * pointer is over the entry. What the form submits for it is `range=all`,
   * resolved from the LABEL in the callback, and the store's own unbounded
   * scan is what that turns into. */
  var ranges = {};
  for (i = 0; i < presets.length; i++) {
    var s = secondsOf(presets[i].key);
    ranges[presets[i].label] = s === null
      ? [moment(0), moment()]
      : [moment().subtract(s, 'seconds'), moment()];
  }

  /* ---- the control ------------------------------------------------------- */

  var input = document.createElement('input');
  input.type = 'text';
  input.className = 'rangeinput';
  input.readOnly = true;                  /* the calendar is the only editor */
  input.setAttribute('aria-label', 'Time range');
  host.insertBefore(input, host.firstChild);

  function describe(preset, a, b) {
    if (preset) return preset.label;
    return a.format('D MMM HH:mm') + ' - ' + b.format('D MMM HH:mm');
  }
  input.value = describe(active, start, end);

  function chosen(a, b, label) {
    var preset = presetByLabel(label);
    if (preset) {
      /* A NAMED RANGE STAYS NAMED. Submitting the two instants a preset
       * happened to resolve to would freeze the window at the moment it was
       * picked, so "last 15 minutes" would quietly stop meaning the last
       * fifteen minutes as soon as fifteen minutes passed. */
      fRange.value = preset.key;
      fFrom.value = '';
      fTo.value = '';
    } else {
      fRange.value = 'custom';
      fFrom.value = toNs(a);
      fTo.value = toNs(b);
    }
    input.value = describe(preset, a, b);
    if (form.requestSubmit) form.requestSubmit();
    else form.submit();
  }

  var picker;
  try {
    picker = new DateRangePicker(input, {
      startDate: start,
      endDate: end,
      ranges: ranges,
      timePicker: true,
      timePicker24Hour: true,
      timePickerSeconds: true,
      timePickerIncrement: 1,
      autoUpdateInput: false,      /* describe() writes the text, not the picker */
      alwaysShowCalendars: true,
      linkedCalendars: false,
      opens: 'left',
      drops: 'auto',
      locale: {
        format: 'D MMM HH:mm',
        separator: ' - ',
        applyLabel: 'Apply',
        cancelLabel: 'Cancel',
        customRangeLabel: 'Custom'
      }
    }, chosen);
  } catch (e) {
    /* The buttons are still there and still work. */
    input.parentNode.removeChild(input);
    return;
  }

  /* ONLY NOW. Everything above can bail out and leave the row of buttons
   * doing the job it was doing before this file loaded. */
  host.classList.add('picked');
  if (picker) host.setAttribute('data-rangepick', 'on');
})();
