// Bande commune de l'IFE : remplace, au chargement de la page, l'en-tête et le
// pied de page écrits au rendu par ceux de ce fichier, servi par le site en
// /assets/ife-band.js. Une modification atteint ainsi toutes les pages sans
// nouveau rendu. Si ce fichier ne répond pas, la page garde sa bande écrite au
// rendu, qui sert de repli. Voir docs/injection-bande.md.
//
// Source de /assets/ife-band.js : scripts/build-assets.sh y place le fragment
// tiré de html/header.html et html/footer.html.
(function () {
  "use strict";

  var FRAGMENT = String.raw`
<header class="ife-chrome ife-header">
  <div class="ife-chrome__inner">
    <a class="ife-lockup" href="/" aria-label="IFE, Institut Français d’Économie — Accueil">
      <img class="ife-lockup__logo" src="/assets/img/IFE_Institut_logo_anthrancite.svg" alt=""/>
    </a>
    <button type="button" class="ife-nav-toggle" aria-controls="ife-header-menu" aria-expanded="false" aria-label="Ouvrir le menu">
      <i class="bi bi-list" aria-hidden="true"></i>
    </button>
    <nav class="ife-header__end" id="ife-header-menu" aria-label="Menu principal">
      <a class="ife-header__about" href="/ife/qui_sommes_nous.html">À propos et contact</a>
      <div class="ife-brand-btns">
        <a class="ife-brand-btn ife-brand-btn--ofce" href="https://www.ofce.fr/" target="_blank" rel="noopener noreferrer">
<!--          <i class="bi bi-box-arrow-up-right" aria-hidden="true"></i> -->
          <span class="ife-brand-btn__logo" aria-hidden="true"></span>
          <span class="visually-hidden">Site de l’OFCE (nouvelle fenêtre)</span>
        </a>
        <a class="ife-brand-btn ife-brand-btn--cepii" href="https://www.cepii.fr/" target="_blank" rel="noopener noreferrer">
<!--          <i class="bi bi-box-arrow-up-right" aria-hidden="true"></i> -->
          <span class="ife-brand-btn__logo" aria-hidden="true"></span>
          <span class="visually-hidden">Site du CEPII (nouvelle fenêtre)</span>
        </a>
      </div>
      <ul class="ife-social" aria-label="Contact et réseaux sociaux">
        <li><a href="https://bsky.app/profile/ife-eco.bsky.social" target="_blank" rel="noopener noreferrer">
          <img src="/assets/img/bluesky_icon.svg" alt="Bluesky" />
          <span class="visually-hidden"> (nouvelle fenêtre)</span>
        </a></li>
        <li><a href="https://www.linkedin.com/company/ife-eco/" target="_blank" rel="noopener noreferrer">
          <img src="/assets/img/linkedin_icon.svg" alt="LinkedIn" />
          <span class="visually-hidden"> (nouvelle fenêtre)</span>
        </a></li>
<!-- Facebook : icône de la maquette. Renseigner href, puis retirer ce commentaire.
        <li><a href="URL_DE_LA_PAGE_FACEBOOK" target="_blank" rel="noopener noreferrer">
          <img src="/assets/img/facebook_icon.svg" alt="Facebook" />
          <span class="visually-hidden"> (nouvelle fenêtre)</span>
        </a></li>
-->
        <li><a href="https://www.youtube.com/@IFE-eco" target="_blank" rel="noopener noreferrer">
          <img src="/assets/img/youtube_icon.svg" alt="YouTube" />
          <span class="visually-hidden"> (nouvelle fenêtre)</span>
        </a></li>
<!-- Flux RSS : icône de la maquette. Renseigner href, puis retirer ce commentaire.
        <li><a href="URL_DU_FLUX_RSS">
          <img src="/assets/img/rss_icon.svg" alt="Flux RSS" />
        </a></li>
-->
        <li><a href="mailto:contact@ife.eco">
          <img src="/assets/img/envelope_icon.svg" alt="Écrire à contact@ife.eco" />
        </a></li>
      </ul>
      <nav class="ife-lang" aria-label="Choix de la langue">
        <a class="ife-lang__current" href="/" lang="fr" hreflang="fr">FR</a>
        <span class="ife-lang__sep" aria-hidden="true"> / </span>
        <span class="ife-lang__other" lang="en">EN <span class="visually-hidden">(Coming soon)</span></span>
      </nav>
    </nav>
  </div>
</header><footer class="ife-chrome ife-footer">
  <div class="ife-chrome__inner">
    <a class="ife-lockup" href="/" aria-label="IFE, Institut Français d’Économie — Accueil">
      <img class="ife-lockup__logo" src="/assets/img/IFE_Institut_logo_anthrancite.svg" alt="" />
    </a>
    <div class="ife-footer__end">
      <div class="ife-brand-btns">
        <a class="ife-brand-btn ife-brand-btn--ofce" href="https://www.ofce.fr/" target="_blank" rel="noopener noreferrer">
<!--          <i class="bi bi-box-arrow-up-right" aria-hidden="true"></i> -->
          <span class="ife-brand-btn__logo" aria-hidden="true"></span>
          <span class="visually-hidden">Site de l’OFCE (nouvelle fenêtre)</span>
        </a>
        <a class="ife-brand-btn ife-brand-btn--cepii" href="https://www.cepii.fr/" target="_blank" rel="noopener noreferrer">
<!--          <i class="bi bi-box-arrow-up-right" aria-hidden="true"></i> -->
          <span class="ife-brand-btn__logo" aria-hidden="true"></span>
          <span class="visually-hidden">Site du CEPII (nouvelle fenêtre)</span>
        </a>
      </div>
      <nav class="ife-footer__legal" aria-label="Liens légaux">
        <ul>
          <li><a href="/legal/cookies.html">Cookies</a></li>
          <li><a href="/legal/mentions_legales.html">Mentions légales</a></li>
          <li><a href="/legal/conditions_generales.html">Conditions générales</a></li>
          <li><a href="/legal/plan_du_site.html">Plan du site</a></li>
          <li><a href="https://www.sciencespo.fr/fr/accessibilite/" target="_blank" rel="noopener noreferrer">Accessibilité : en cours d’audit<span class="visually-hidden"> (nouvelle fenêtre)</span></a></li>
          <li><a href="/ife/qui_sommes_nous.html">Contact</a></li>
        </ul>
      </nav>
    </div>
  </div>
</footer>`;

  // Logo de la marque, lu sur <body> (classe posée par brand.lua). La bande
  // commune porte le logo de l'IFE ; une page IFE|OFCE ou IFE|CEPII garde le sien.
  var LOGOS = {
    ofce: "/assets/img/IFE-OFCE_logo_anthracite.svg",
    cepii: "/assets/img/IFE-CEPII_logo_anthracite.svg"
  };

  function brandLogo() {
    for (var brand in LOGOS) {
      if (document.body.classList.contains("ife-brand--" + brand)) return LOGOS[brand];
    }
    return null;
  }

  // Bande écrite au rendu, ou accroche posée sur une page figée.
  function target(part) {
    return document.querySelector(part + ".ife-" + part) ||
      document.querySelector('[data-ife-band="' + part + '"]');
  }

  function inject() {
    var fragment = new DOMParser().parseFromString(FRAGMENT, "text/html");
    var header = fragment.querySelector("header.ife-header");
    var footer = fragment.querySelector("footer.ife-footer");
    if (!header || !footer) return;

    var logo = brandLogo();
    if (logo) {
      [header, footer].forEach(function (part) {
        var img = part.querySelector(".ife-lockup__logo");
        if (img) img.setAttribute("src", logo);
      });
    }

    var oldHeader = target("header");
    var oldFooter = target("footer");
    if (oldHeader) oldHeader.replaceWith(document.adoptNode(header));
    if (oldFooter) oldFooter.replaceWith(document.adoptNode(footer));
  }

  // Bouton du menu mobile, tiré de html/nav-toggle.js par build-assets.sh.
  // Appelé après DOMContentLoaded, donc après le script de la page rendue, dont
  // il remplace le branchement ; il branche aussi le bouton d'une page figée.
  function bindMenu() {
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
  }

  function run() {
    try {
      inject();
      bindMenu();
    } catch (e) {
      // Repli silencieux : la bande écrite au rendu reste en place.
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", run);
  } else {
    run();
  }
})();
