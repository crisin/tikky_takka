// Switches the design (theme) of a preview page and carries the choice across links.
(function () {
  var classes = {"Schwarz": "", "Dunkel": "th-dunkel", "Hell": "th-hell", "Neon": "th-neon", "Kassette": "th-kassette", "Arcade": "th-arcade", "Lava": "th-lava"};
  var root = document.querySelector('.tt');
  var sel = document.getElementById('design');
  var motion = document.getElementById('motion');
  var q = new URLSearchParams(location.search);
  function apply(name) {
    Object.keys(classes).forEach(function (k) { if (classes[k]) root.classList.remove(classes[k]); });
    if (classes[name]) root.classList.add(classes[name]);
    sel.value = name;
  }
  if (q.get('design') && q.get('design') in classes) apply(q.get('design')); else sel.value = root.dataset.design;
  if (q.get('still')) { root.classList.add('still'); motion.checked = false; }
  function carry() {
    var p = new URLSearchParams();
    p.set('design', sel.value);
    if (!motion.checked) p.set('still', '1');
    document.querySelectorAll('a[href$=".html"]').forEach(function (a) { a.href = a.getAttribute('href').split('?')[0] + '?' + p; });
  }
  sel.addEventListener('change', function () { apply(sel.value); carry(); });
  motion.addEventListener('change', function () { root.classList.toggle('still', !motion.checked); carry(); });
  carry();
})();
