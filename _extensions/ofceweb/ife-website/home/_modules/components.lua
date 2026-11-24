-- Primitives HTML partagées par les shortcodes de blocs (ife-website).
--
-- Les shortcodes appellent ces fonctions et assemblent le HTML de chaque
-- bloc. L'échappement et les dates passent par `_modules/utils.lua`.

local utils = require(
    quarto.utils.resolve_path("_modules/utils.lua"):gsub("%.lua$", "")
)

local components = {}

local ICONS = {
    arrow = "bi-arrow-right",
}

local SVG_ICONS = {
    envelope = "/www/mail_icon.svg",
}

local SOURCE_LABELS = {
    ofce = "IFE|OFCE",
    cepii = "IFE|CEPII",
}

-- Catégorie de contenu → couleur décorative du badge (`ife-badge--<clé>`).
-- Premier motif trouvé dans le libellé normalisé (minuscules, sans accent).
-- Un libellé absent de la liste garde la couleur par défaut.
-- Troisième champ : langue du libellé, si elle diffère de la page (RGAA 8.7).
local CATEGORY_PATTERNS = {
    { "blog", "blog" },
    { "ecograph", "ecograph" },
    { "prevision", "prevision" },
    { "lettre", "lettre" },
    { "policy brief", "policy", "EN" },
    { "working paper", "working", "EN" },
    { "revue", "revue" },
    { "rapport", "rapport" },
    { "etude", "rapport" },
}

local LANG_TITLES = {
    EN = "Publication en anglais",
    FR = "Publication en français",
}

local REGION_ICONS = {
    fr = "/www/flags/fr_icon.svg",
    us = "/www/flags/us.svg",
    de = "/www/flags/de.svg",
    eu = "/www/flags/eu_icon.svg",
    world = "/www/flags/world_icon.svg",
}

local VARIANTS = {
    ["solid-light"] = "solid-light",
    ["solid-dark"] = "solid-dark",
    ["outline-light"] = "outline-light",
    ["outline-dark"] = "outline-dark",
}

--- Classe Bootstrap Icons (`bi bi-…`), chaîne vide si name est vide
--- @param name string|nil Clé courte (`arrow`) ou classe (`bi-arrow-right`)
--- @return string
local function bi_icon(name)
    local key = utils.to_str(name)
    if key == "" then return "" end
    local class_name = ICONS[key] or key
    if not class_name:match("^bi%-") then
        class_name = "bi-" .. class_name
    end
    return string.format('<i class="bi %s" aria-hidden="true"></i>', class_name)
end

--- Icône CTA : SVG du projet, sinon Bootstrap Icons. Chaîne vide si name est vide.
--- @param name string|nil Clé courte (`arrow`, `envelope`) ou classe (`bi-arrow-right`)
--- @return string
local function cta_icon(name)
    local key = utils.to_str(name)
    if key == "" then return "" end
    local src = SVG_ICONS[key]
    if src then
        return string.format(
            '<img src="%s" alt="" aria-hidden="true" />',
            src
        )
    end
    return bi_icon(key)
end

--- Jeton CSS : minuscules, lettres, chiffres et tirets uniquement
--- @param value any
--- @return string
local function css_token(value)
    return utils.to_str(value):lower():gsub("[^a-z0-9%-]+", "")
end

--- @param source any
--- @return string `ofce`, `cepii`, ou jeton normalisé
local function source_key(source)
    local s = utils.to_str(source):lower()
    if s == "" then return "" end
    if s:find("cepii", 1, true) then return "cepii" end
    if s:find("ofce", 1, true) then return "ofce" end
    return css_token(s)
end

--- @param label any
--- @return string|nil Clé de `CATEGORY_PATTERNS`, nil pour la couleur par défaut
--- @return string|nil Langue du libellé (`EN`), nil si celle de la page
local function category_key(label)
    local s = utils.to_str(label):lower()
    for _, accent in ipairs({ "É", "é", "È", "è", "Ê", "ê" }) do
        s = s:gsub(accent, "e")
    end
    for _, entry in ipairs(CATEGORY_PATTERNS) do
        if s:find(entry[1], 1, true) then return entry[2], entry[3] end
    end
    return nil
end

--- @param region any
--- @return string `fr`, `eu`, `world`, ou jeton normalisé
local function region_key(region)
    local s = utils.to_str(region):lower()
    s = s:match("^%s*(.-)%s*$") or ""
    if s == "" then return "" end
    if s == "fr" or s == "france" or s:match("^fr%-") then return "fr" end
    if s == "ue" or s == "eu" or s:find("europe", 1, true) then return "eu" end
    if s == "world" or s == "monde" or s == "intl"
        or s == "international" or s == "world-wide" then
        return "world"
    end
    return css_token(s)
end

--- Liste JSON, MetaList YAML, ou valeur scalaire.
--- @param region any
--- @return boolean
local function is_region_list(region)
    if type(region) ~= "table" then return false end
    if region.t and region.t ~= "MetaList" then return false end
    return #region > 0
end

--- Codes normalisés, sans doublon, dans l'ordre d'écriture.
--- Accepte `"fr"`, `"fr, de, eu"` ou `{ "fr", "de", "eu" }`.
--- @param region any
--- @return table
local function region_keys(region)
    local raw = {}
    if is_region_list(region) then
        for _, item in ipairs(region) do
            table.insert(raw, item)
        end
    else
        local s = utils.to_str(region)
        for part in string.gmatch(s, "[^,]+") do
            table.insert(raw, part)
        end
    end

    local keys = {}
    local seen = {}
    for _, item in ipairs(raw) do
        local key = region_key(item)
        if key ~= "" and not seen[key] then
            seen[key] = true
            table.insert(keys, key)
        end
    end
    return keys
end

--- Chemin du drapeau. Les codes connus ont une icône dédiée.
--- Les autres codes ISO utilisent `www/flags/<code>.svg` s'il existe.
--- @param key string
--- @return string|nil
local function flag_src(key)
    if key == "" then return nil end
    local mapped = REGION_ICONS[key]
    if mapped then return mapped end
    if not key:match("^[a-z]{2}$") and not key:match("^[a-z]{2}%-[a-z0-9]+$") then
        return nil
    end

    local rel = "www/flags/" .. key .. ".svg"
    local cwd = "."
    if pandoc.system and pandoc.system.get_working_directory then
        cwd = pandoc.system.get_working_directory()
    end
    local project_dir = cwd
    if quarto.project and quarto.project.directory then
        project_dir = quarto.project.directory
    end
    local candidates = {
        project_dir .. "/" .. rel,
        cwd .. "/" .. rel,
        rel,
    }
    for _, path in ipairs(candidates) do
        local file = io.open(path, "r")
        if file then
            file:close()
            return "/" .. rel
        end
    end
    return nil
end

--- Badge de type de contenu (Policy Brief, Séminaire, …). Omis si vide.
--- La barre de couleur est décorative : le libellé porte l'information.
--- @param label string|nil
--- @return string
function components.badge_type(label)
    local text = utils.html_escape(utils.to_str(label))
    if text == "" then return "" end
    local key, lang = category_key(label)
    local class_name = key and ("ife-badge ife-badge--" .. key) or "ife-badge"
    return string.format(
        '<span class="%s"><span class="ife-badge__label"%s>%s</span></span>',
        class_name,
        utils.lang_attr(lang),
        text
    )
end

--- Chip de langue (`FR`, `EN`). Omis si vide.
--- L'`abbr` porte l'intitulé complet en français.
--- `lang="en"` est sur le code `EN`, pas sur le titre.
--- @param lang string|nil
--- @return string
function components.lang_chip(lang)
    local raw = utils.to_str(lang)
    if raw == "" then return "" end
    local text = utils.html_escape(raw)
    local title = LANG_TITLES[raw:upper()]
    if not title then
        return string.format('<span class="ife-lang-chip">%s</span>', text)
    end
    local code = text
    local lang_attr = utils.lang_attr(raw)
    if lang_attr ~= "" then
        code = string.format("<span%s>%s</span>", lang_attr, text)
    end
    return string.format(
        '<span class="ife-lang-chip"><abbr title="%s">%s</abbr></span>',
        utils.html_escape(title),
        code
    )
end

--- Marqueur PDF non cliquable. Affiché quand l'URL pointe un fichier .pdf,
--- pour signaler une publication disponible uniquement en PDF.
--- @param url string|nil URL principale de la publication
--- @return string
function components.pdf_icon(url)
    if not utils.to_str(url):lower():match("%.pdf$") then return "" end
    return '<span class="ife-pdf" aria-label="Disponible en PDF uniquement"><img src="/www/pdf_icon.svg" alt="" aria-hidden="true" /></span>'
end

--- Badge de source OFCE / CEPII, un drapeau par région.
--- `region` accepte un code (`fr`, `de`, `eu`, `us`, `world`),
--- une liste (`{ "fr", "de" }`) ou une chaîne `fr, de, eu`.
--- @param source string|nil
--- @param region string|table|nil
--- @return string
function components.source_badge(source, region)
    local key = source_key(source)
    if key == "" then return "" end
    local label = SOURCE_LABELS[key] or utils.html_escape(utils.to_str(source))
    local flags = {}
    for _, region_code in ipairs(region_keys(region)) do
        local src = flag_src(region_code)
        if src then
            table.insert(flags, string.format(
                '<img class="ife-source__flag" src="%s" alt="" aria-hidden="true" />',
                src
            ))
        end
    end
    local flag = ""
    if #flags > 0 then
        flag = '<span class="ife-source__flags">' .. table.concat(flags) .. '</span>'
    end
    return string.format(
        '<span class="ife-source ife-source--%s">%s<span class="ife-source__label">%s</span></span>',
        key,
        flag,
        label
    )
end

--- Rangée de mots-clés. Accepte une liste ou une chaîne unique. Omis si vide.
--- @param keywords table|string|nil
--- @return string
function components.keywords_row(keywords)
    local items = {}
    if type(keywords) == "string" then
        local s = utils.to_str(keywords)
        if s ~= "" then table.insert(items, s) end
    elseif type(keywords) == "table" then
        for _, kw in ipairs(keywords) do
            local s = utils.to_str(kw)
            if s ~= "" then table.insert(items, s) end
        end
    end
    if #items == 0 then return "" end

    local lis = {}
    for _, kw in ipairs(items) do
        table.insert(lis, string.format(
            '<li class="ife-keywords__item">%s</li>',
            utils.html_escape(kw)
        ))
    end
    return string.format(
        '<ul class="ife-keywords"><li class="ife-keywords__icon" aria-hidden="true">%s</li>%s</ul>',
        bi_icon("arrow"),
        table.concat(lis)
    )
end

--- Bouton d'action. Variantes : `solid-light`, `solid-dark`, `outline-light`, `outline-dark`.
--- `icon` : `arrow` (Bootstrap), `envelope` (`mail_icon.svg`), ou une classe Bootstrap Icons.
--- Omis si le libellé est vide. Sans URL, rend un `span`.
--- `hidden_prefix` : texte masqué lu avant le libellé (ex. « Écrire à »).
--- `hidden_suffix` : texte masqué lu après le libellé (ex. « sur Macroéconomie »).
--- `extra_class` : classe ajoutée au bouton, pour un script ou un bloc (ex. `ife-band__cta`).
--- @param label string|nil
--- @param url string|nil
--- @param variant string|nil
--- @param icon string|nil
--- @param hidden_prefix string|nil
--- @param hidden_suffix string|nil
--- @param extra_class string|nil
--- @return string
function components.cta_button(label, url, variant, icon, hidden_prefix, hidden_suffix, extra_class)
    local text = utils.html_escape(utils.to_str(label))
    if text == "" then return "" end

    local prefix = utils.to_str(hidden_prefix)
    if prefix ~= "" then
        text = string.format(
            '<span class="visually-hidden">%s</span>%s',
            utils.html_escape(prefix),
            text
        )
    end
    local suffix = utils.to_str(hidden_suffix)
    if suffix ~= "" then
        text = string.format(
            '%s<span class="visually-hidden">%s</span>',
            text,
            utils.html_escape(suffix)
        )
    end

    local variant_key = VARIANTS[utils.to_str(variant):lower()] or "solid-light"
    local icon_html = cta_icon(icon)
    local inner = text
    if icon_html ~= "" then
        inner = icon_html .. "<span>" .. text .. "</span>"
    end

    local class_name = "ife-btn ife-btn--" .. variant_key
    local extra = utils.to_str(extra_class)
    if extra ~= "" then class_name = class_name .. " " .. extra end
    local href = utils.to_str(url)
    if href == "" then
        return string.format('<span class="%s">%s</span>', class_name, inner)
    end
    return string.format(
        '<a class="%s" href="%s"%s>%s%s</a>',
        class_name,
        utils.html_escape(href),
        utils.link_attrs(href),
        inner,
        utils.new_window_hint(href)
    )
end

--- Bouton contour d'en-tête de section, vers la liste complète du bloc.
--- Omis sans `more_url`. Libellé par défaut : « Voir tout ».
--- Le titre du bloc complète le libellé en texte masqué : deux blocs peuvent
--- afficher le même libellé vers des pages différentes (RGAA 6.1).
--- @param cfg table Config du bloc (`utils.block_config`)
--- @param title string Titre du bloc
--- @return string
function components.section_more_button(cfg, title)
    if utils.to_str(cfg.more_url) == "" then return "" end
    local label = utils.to_str(cfg.more_label)
    if label == "" then label = "Voir tout" end
    return components.cta_button(label, cfg.more_url, "outline-dark", "arrow", nil, " : " .. utils.to_str(title))
end

--- Ligne d'auteurs. Chaque nom porte `ife-author`. Omis si vide.
--- @param raw string|nil Chaîne unique, noms séparés par des virgules
--- @param class_name string Classe du paragraphe (`alaune__authors`, …)
--- @return string
function components.authors_html(raw, class_name)
    local text = utils.to_str(raw)
    if text == "" then return "" end
    local spans = {}
    for name in string.gmatch(text, "[^,]+") do
        local trimmed = name:match("^%s*(.-)%s*$")
        if trimmed ~= "" then
            table.insert(spans, string.format(
                '<span class="ife-author">%s</span>',
                utils.html_escape(trimmed)
            ))
        end
    end
    if #spans == 0 then return "" end
    return utils.el("p", class_name, table.concat(spans, ", "))
end

--- Boutons d'un bandeau de publication, empilés dans `<block>__actions`.
--- « Lire cet article » (`cta_*`, blanc) mène à la publication du bandeau.
--- « Nos publications » (`more_*`, contour) mène à la liste des publications.
--- Chaque bouton est omis sans lien, le conteneur sans bouton.
--- « Lire cet article » reçoit le titre de la publication en texte masqué :
--- plusieurs bandeaux d'une page portent ce libellé (RGAA 6.1).
--- Il porte `ife-band__cta`, que band-publication.js relie au titre de la publication.
--- @param block string Classe du bloc (`ecograph`, …)
--- @param item table
--- @return string
function components.publication_actions(block, item)
    local buttons = {}

    local url = utils.pick(item, "cta_url", "url")
    if url ~= "" then
        local label = utils.pick(item, "cta_label")
        if label == "" then label = "Lire cet article" end
        local subtitle = pandoc.utils.stringify(
            pandoc.read(utils.pick(item, "subtitle"), "markdown").blocks
        )
        table.insert(buttons, components.cta_button(
            label,
            url,
            "solid-light",
            "arrow",
            nil,
            subtitle ~= "" and (" : " .. subtitle) or nil,
            "ife-band__cta"
        ))
    end

    local more_url = utils.pick(item, "more_url")
    if more_url ~= "" then
        local more_label = utils.pick(item, "more_label")
        if more_label == "" then more_label = "Nos publications" end
        table.insert(buttons, components.cta_button(
            more_label,
            more_url,
            "outline-light",
            "arrow"
        ))
    end

    if #buttons == 0 then return "" end
    return utils.el("div", block .. "__actions", table.concat(buttons))
end

--- Date de publication précédée de l'icône stylo, puis la ligne « Mise à jour le : … »
--- si `updated` est renseigné (publication republiée avec des modifications).
--- « Publié le » est masqué à l'écran : l'icône seule ne porte pas le sens. Omise si la date est vide.
--- @param class_name string Classe du bloc (`alaune__date`, …)
--- @param date any Date ISO de publication
--- @param updated any Date ISO de mise à jour, facultative
--- @return string
function components.pub_date(class_name, date, updated)
    local published = utils.html_escape(utils.format_date_fr(date))
    if published == "" then return "" end
    local updated_html = ""
    local updated_text = utils.html_escape(utils.format_date_fr(updated))
    if updated_text ~= "" then
        updated_html = string.format(
            '<p class="ife-pubdate__updated"><span class="ife-pubdate__label">Mise à jour le :</span> %s</p>',
            updated_text
        )
    end
    return string.format(
        '<div class="%s ife-pubdate"><p class="ife-pubdate__published"><span class="ife-pubdate__icon" aria-hidden="true"></span><span class="visually-hidden">Publié le </span>%s</p>%s</div>',
        class_name,
        published,
        updated_html
    )
end

--- Bandeau de publication pleine largeur, image décorative en fond.
--- Thème (titre du bandeau), date, titre de la publication, extrait, auteurs, boutons.
--- Partagé par `bandeaupublication`, `bandeauspecial` et `ecograph`.
--- Les classes suivent le bloc : `<block>__title`, `<block>__date`, …
--- Le titre de la publication prend le niveau sous le thème.
--- Boutons : voir `components.publication_actions`.
--- Le titre de la publication (`ife-band__subtitle`) ouvre la publication au clic
--- via band-publication.js, sans second lien (voir le script).
--- @param block string Classe du bloc (`ecograph`, …)
--- @param item table
--- @param level number Niveau du thème (voir `utils.band_heading_level`)
--- @param title string Texte du thème, non échappé
--- @return string
function components.publication_band(block, item, level, title)
    quarto.doc.add_html_dependency({
        name = "ife-band-publication",
        version = "0.1.0",
        scripts = { "band-publication.js" },
    })

    return string.format([[
        <section class="ife-band ife-band--cover %s">
            %s
            <div class="ife-band__inner">
                <div class="ife-band__content">
                    %s
                    %s
                    %s
                    %s
                    %s
                    %s
                </div>
            </div>
        </section>
    ]],
        block,
        utils.image_html(
            utils.pick(item, "image", "img", "cover"),
            "",
            "ife-band__media",
            true
        ),
        utils.el("h" .. level, block .. "__title", utils.html_escape(title)),
        components.pub_date(
            block .. "__date",
            utils.pick(item, "date"),
            utils.pick(item, "updated")
        ),
        utils.el(
            "h" .. (level + 1),
            block .. "__subtitle ife-band__subtitle",
            utils.rich_inline(utils.pick(item, "subtitle"))
        ),
        utils.el(
            "p",
            block .. "__excerpt",
            utils.rich_inline(utils.pick(item, "excerpt"))
        ),
        components.authors_html(utils.pick(item, "author"), block .. "__author"),
        components.publication_actions(block, item)
    )
end

--- Titre de section, serif, sans filet. Omis si vide.
--- @param title string|nil
--- @return string
function components.section_title(title)
    local text = utils.html_escape(utils.to_str(title))
    if text == "" then return "" end
    return string.format('<h2 class="ife-section-title">%s</h2>', text)
end

--- Ligne de méta : badge de type, date (calendrier), lieu (épingle).
--- Omis si les trois champs sont vides. La date ISO est formatée en français.
--- Le lieu ouvre Google Maps.
--- @param type_label string|nil
--- @param date any
--- @param location string|nil
--- @return string
function components.meta_line(type_label, date, location)
    local parts = {}

    local badge = components.badge_type(type_label)
    if badge ~= "" then table.insert(parts, badge) end

    local date_text = utils.html_escape(utils.format_date_fr(date))
    if date_text ~= "" then
        table.insert(parts, string.format(
            '<span class="ife-meta__date"><img src="/www/calendar_icon.svg" alt="" aria-hidden="true" />%s</span>',
            date_text
        ))
    end

    local loc = utils.to_str(location)
    if loc ~= "" then
        local href = "https://www.google.com/maps/search/?api=1&query=" .. utils.url_encode(loc)
        table.insert(parts, string.format(
            '<a class="ife-meta__location" href="%s"%s><img src="/www/localisation_icon.svg" alt="" aria-hidden="true" /><span class="visually-hidden">Voir sur Google Maps : </span>%s%s</a>',
            utils.html_escape(href),
            utils.link_attrs(href),
            utils.html_escape(loc),
            utils.new_window_hint(href)
        ))
    end

    if #parts == 0 then return "" end
    return string.format('<div class="ife-meta">%s</div>', table.concat(parts))
end

return components
