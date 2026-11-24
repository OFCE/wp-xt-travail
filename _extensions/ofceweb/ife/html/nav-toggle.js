// Bouton du menu mobile de la bande, branché par délégation sur document : il
// fonctionne sur la bande écrite au rendu comme sur la bande injectée.
// Source unique : template.html l'inclut comme partial Pandoc, et
// scripts/build-assets.sh le place dans /assets/ife-band.js. Chaque
// branchement retire le précédent : le script de /assets/, exécuté après celui
// de la page, impose donc le comportement de la dernière version publiée.
// Partial Pandoc : ce fichier ne doit contenir aucun signe dollar.
(function () {
  function setOpen(header, toggle, open) {
    header.classList.toggle("is-open", open);
    toggle.setAttribute("aria-expanded", open ? "true" : "false");
    toggle.setAttribute("aria-label", open ? "Fermer le menu" : "Ouvrir le menu");
    var icon = toggle.querySelector("i");
    if (icon) {
      icon.classList.toggle("bi-list", !open);
      icon.classList.toggle("bi-x-lg", open);
    }
  }
  function onClick(e) {
    var toggle = e.target.closest && e.target.closest(".ife-nav-toggle");
    var header = toggle && toggle.closest("header.ife-header");
    if (!header) return;
    setOpen(header, toggle, !header.classList.contains("is-open"));
  }
  // Échap ferme le menu et rend le focus au bouton.
  function onKeydown(e) {
    var header = document.querySelector("header.ife-header");
    if (e.key !== "Escape" || !header || !header.classList.contains("is-open")) return;
    var toggle = header.querySelector(".ife-nav-toggle");
    if (!toggle) return;
    setOpen(header, toggle, false);
    toggle.focus();
  }
  var previous = window.ifeNav;
  if (previous) {
    document.removeEventListener("click", previous.onClick);
    document.removeEventListener("keydown", previous.onKeydown);
  }
  window.ifeNav = { onClick: onClick, onKeydown: onKeydown };
  document.addEventListener("click", onClick);
  document.addEventListener("keydown", onKeydown);
})();
