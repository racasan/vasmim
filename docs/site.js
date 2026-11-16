// Vasmim project page: light/dark toggle only. Nothing is sent anywhere.
(function () {
  // The choice is remembered in this browser only; the page works without it.
  var root = document.documentElement;
  try {
    var saved = localStorage.getItem('vasmim-theme');
    if (saved === 'light' || saved === 'dark') root.setAttribute('data-theme', saved);
  } catch (e) {}
  document.addEventListener('DOMContentLoaded', function () {
    var button = document.querySelector('.theme-toggle');
    if (!button) return;
    button.addEventListener('click', function () {
      var dark = root.getAttribute('data-theme') === 'dark' ||
        (!root.getAttribute('data-theme') &&
          window.matchMedia('(prefers-color-scheme: dark)').matches);
      var next = dark ? 'light' : 'dark';
      root.setAttribute('data-theme', next);
      try { localStorage.setItem('vasmim-theme', next); } catch (e) {}
    });
  });
})();
