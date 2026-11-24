// À la une : un clic sur l'image ouvre l'article, comme le lien du titre.
// L'image reste décorative et hors de l'arbre d'accessibilité : pas de
// second lien, le titre reste le seul accès clavier (RGAA 6.1, 7.3).
(function () {
  function titleLink(event) {
    var chart = event.target.closest(".alaune__chart");
    if (!chart) return null;
    return chart.closest(".alaune__item").querySelector(".alaune__title a");
  }

  document.addEventListener("click", function (event) {
    var link = titleLink(event);
    if (!link) return;
    // Ctrl / Cmd / Maj + clic : nouvel onglet, comme sur un vrai lien.
    if (event.ctrlKey || event.metaKey || event.shiftKey) {
      window.open(link.href, "_blank", "noopener");
      return;
    }
    // click() reprend le target du titre (nouvelle fenêtre pour un lien externe).
    link.click();
  });

  // Clic molette : nouvel onglet.
  document.addEventListener("auxclick", function (event) {
    if (event.button !== 1) return;
    var link = titleLink(event);
    if (link) window.open(link.href, "_blank", "noopener");
  });
})();
