/* Banto landing — vanilla, no deps. */
(function () {
  'use strict';
  var docEl = document.documentElement;
  var body = document.body;
  var reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* ---------- language toggle (dual-DOM, persisted) ---------- */
  var STORE_KEY = 'banto-site-lang';
  function setLang(lang) {
    if (lang !== 'ja' && lang !== 'en') lang = 'en';
    body.setAttribute('data-lang', lang);
    docEl.setAttribute('lang', lang);
    var btns = document.querySelectorAll('[data-setlang]');
    for (var i = 0; i < btns.length; i++) {
      btns[i].classList.toggle('on', btns[i].getAttribute('data-setlang') === lang);
    }
    try { localStorage.setItem(STORE_KEY, lang); } catch (e) {}
  }
  // Deterministic default: English (the public default). Only an explicit, persisted
  // choice overrides it — predictable, never surprises on reload.
  var saved = 'en';
  try { saved = localStorage.getItem(STORE_KEY) || 'en'; } catch (e) {}
  setLang(saved);
  document.addEventListener('click', function (e) {
    var t = e.target.closest('[data-setlang]');
    if (t) setLang(t.getAttribute('data-setlang'));
  });

  /* ---------- prepare SVG draw paths (precise dash lengths) ---------- */
  var dashed = { merge: 1, 'flow-exc': 1, 'f-man': 1 };
  var paths = document.querySelectorAll('.flow, .lp-flow, .ctx-flow, .ws-arc, .loop-run');
  for (var p = 0; p < paths.length; p++) {
    var el = paths[p], skip = false;
    for (var k in dashed) { if (el.classList.contains(k)) skip = true; }
    if (skip) continue;
    try {
      var len = el.getTotalLength();
      if (len && isFinite(len)) el.style.setProperty('--len', Math.ceil(len));
    } catch (e) {}
  }

  /* ---------- reveal + diagram animation on scroll ---------- */
  var targets = document.querySelectorAll('.reveal, .diagram, .gate-demo');
  if (reduce || !('IntersectionObserver' in window)) {
    for (var r = 0; r < targets.length; r++) targets[r].classList.add('in');
    runCounters();
  } else {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        if (en.isIntersecting) {
          en.target.classList.add('in');
          if (en.target.classList.contains('stat-strip')) runCounters();
          io.unobserve(en.target);
        }
      });
    }, { threshold: 0.18, rootMargin: '0px 0px -8% 0px' });
    for (var t = 0; t < targets.length; t++) io.observe(targets[t]);
    // stat strip is a .reveal too; ensure counters fire
    var strip = document.querySelector('.stat-strip');
    if (strip) {
      var io2 = new IntersectionObserver(function (entries) {
        if (entries[0].isIntersecting) { runCounters(); io2.disconnect(); }
      }, { threshold: 0.4 });
      io2.observe(strip);
    }
  }

  /* ---------- count-up ---------- */
  var countersDone = false;
  function runCounters() {
    if (countersDone) return; countersDone = true;
    var nums = document.querySelectorAll('.count');
    nums.forEach(function (n) {
      var to = parseInt(n.getAttribute('data-to'), 10) || 0;
      if (reduce) { n.textContent = to; return; }
      var start = null, dur = 1100;
      function step(ts) {
        if (!start) start = ts;
        var k = Math.min((ts - start) / dur, 1);
        var eased = 1 - Math.pow(1 - k, 3);
        n.textContent = Math.round(eased * to);
        if (k < 1) requestAnimationFrame(step);
      }
      requestAnimationFrame(step);
    });
  }

  /* ---------- reading progress + nav state ---------- */
  var bar = document.getElementById('progressBar');
  var nav = document.getElementById('nav');
  var ticking = false;
  function onScroll() {
    if (ticking) return; ticking = true;
    requestAnimationFrame(function () {
      var h = docEl.scrollHeight - docEl.clientHeight;
      var pct = h > 0 ? (docEl.scrollTop || body.scrollTop) / h : 0;
      if (bar) bar.style.width = (pct * 100).toFixed(2) + '%';
      if (nav) nav.classList.toggle('scrolled', (docEl.scrollTop || body.scrollTop) > 8);
      ticking = false;
    });
  }
  window.addEventListener('scroll', onScroll, { passive: true });
  onScroll();

  /* ---------- click-to-copy ---------- */
  document.addEventListener('click', function (e) {
    var c = e.target.closest('[data-copy]');
    if (!c) return;
    var text = c.getAttribute('data-copy');
    var done = function () {
      c.classList.add('flash', 'copied');
      var hint = c.querySelector('.copy-hint');
      var prev = hint ? hint.textContent : null;
      if (hint) hint.textContent = (body.getAttribute('data-lang') === 'ja') ? 'コピーしました' : 'copied!';
      setTimeout(function () {
        c.classList.remove('flash');
        if (hint && prev !== null) hint.textContent = prev;
      }, 1400);
    };
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(done, fallback);
    } else { fallback(); }
    function fallback() {
      try {
        var ta = document.createElement('textarea');
        ta.value = text; ta.style.position = 'fixed'; ta.style.opacity = '0';
        document.body.appendChild(ta); ta.select(); document.execCommand('copy');
        document.body.removeChild(ta); done();
      } catch (err) {}
    }
  });
})();
