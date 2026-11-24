// Bandeaux de publication : un clic sur le titre de la publication ouvre la
// publication, comme le bouton « Lire cet article ».
// Le titre reste un texte, hors de l'ordre de tabulation : pas de second lien
// vers la même destination, le bouton reste le seul accès clavier (RGAA 6.1, 7.3).
// Seul le titre réagit : un lien ajouté ailleurs (auteurs…) garde son comportement.
(function () {
  function ctaLink(event) {
    // Un lien placé dans le titre garde sa propre destination.
    if (event.target.closest("a")) return null;
    var subtitle = event.target.closest(".ife-band__subtitle");
    if (!subtitle) return null;
    return subtitle.closest(".ife-band__content").querySelector(".ife-band__cta");
  }

  document.addEventListener("click", function (event) {
    var link = ctaLink(event);
    if (!link) return;
    // Sélectionner le titre pour le copier ne doit pas ouvrir la publication.
    if (String(window.getSelection()) !== "") return;
    // Ctrl / Cmd / Maj + clic : nouvel onglet, comme sur un vrai lien.
    if (event.ctrlKey || event.metaKey || event.shiftKey) {
      window.open(link.href, "_blank", "noopener");
      return;
    }
    // click() reprend le target du bouton (nouvelle fenêtre pour un lien externe).
    link.click();
  });

  // Clic molette : nouvel onglet.
  document.addEventListener("auxclick", function (event) {
    if (event.button !== 1) return;
    var link = ctaLink(event);
    if (link) window.open(link.href, "_blank", "noopener");
  });
})();
