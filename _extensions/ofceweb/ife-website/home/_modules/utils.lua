-- Utils - Fonctions utilitaires partagées par les shortcodes Quarto ife-website
--
-- Dans webhome, `read_items_from_json` était dupliqué dans chaque shortcode.
-- Il est factorisé ici, avec l'échappement HTML repris tel quel.

local utils = {}

--- Échape les caractères HTML spéciaux (& < > ") dans une chaîne de caractères
--- @param text string|nil La chaîne de caractère à échapper
--- @return string La chaîne échappée (chaîne vide si text est nil ou vide)
function utils.html_escape(text)
    if not text then return "" end
    text = string.gsub(text, "&", "&amp;")
    text = string.gsub(text, "<", "&lt;")
    text = string.gsub(text, ">", "&gt;")
    text = string.gsub(text, '"', "&quot;")
    return text
end

--- Rend un champ texte (Markdown + HTML inline) en HTML inline, sans
--- enveloppe <p>, pour tenir dans un <p> ou un <h3> existant.
--- @param value any Texte Markdown, HTML inline, ou valeur Pandoc
--- @return string HTML inline (chaîne vide si l'entrée est vide)
function utils.rich_inline(value)
    local text = utils.to_str(value)
    if text == "" then return "" end
    local doc = pandoc.read(text, "markdown")
    local inlines = pandoc.utils.blocks_to_inlines(doc.blocks)
    local html = pandoc.write(pandoc.Pandoc({ pandoc.Plain(inlines) }), "html")
    return (html:gsub("%s+$", ""))
end

--- Convertit une valeur Pandoc (MetaInlines, etc.) ou un string Lua natif (JSON)
--- @param val any
--- @return string
function utils.to_str(val)
    if val == nil then return "" end
    local t = type(val)
    if t == "string" then return val end
    if t == "number" or t == "boolean" then return tostring(val) end
    local ok, s = pcall(pandoc.utils.stringify, val)
    if ok and s then return s end
    return ""
end

local function is_absolute_path(filepath)
    return filepath:match("^/") or filepath:match("^%a:")
end

--- Construit la liste des chemins à essayer pour un fichier relatif au projet
--- @param filepath string
--- @return table
local function candidate_paths(filepath)
    local paths = { filepath }
    if not is_absolute_path(filepath) then
        local cwd = (pandoc.system and pandoc.system.get_working_directory
            and pandoc.system.get_working_directory()) or "."
        local project_dir = (quarto.project and quarto.project.directory) or cwd
        table.insert(paths, 1, project_dir .. "/" .. filepath)
        table.insert(paths, cwd .. "/" .. filepath)
    end
    return paths
end

--- Lit et décode un fichier JSON (UTF-8). Retourne nil si le fichier est
--- introuvable ou si le JSON est invalide.
--- @param filepath string Chemin relatif au projet ou absolu
--- @return table|nil
function utils.read_json(filepath)
    if not filepath or filepath == "" then return nil end

    local content = nil
    for _, path in ipairs(candidate_paths(filepath)) do
        local file = io.open(path, "r")
        if file then
            content = file:read("*all")
            file:close()
            break
        end
    end
    if not content or content == "" then return nil end

    -- BOM UTF-8 éventuellement ajouté par un éditeur Windows
    if content:sub(1, 3) == "\239\187\191" then
        content = content:sub(4)
    end

    local ok, data = pcall(quarto.json.decode, content)
    if not ok or type(data) ~= "table" then return nil end
    return data
end

--- Lit un JSON `{ "items": [...] }` et retourne la table `items`.
--- Retourne une table vide si le fichier est absent, invalide, ou sans `items`.
--- @param filepath string Chemin relatif au projet ou absolu
--- @return table
function utils.read_items_from_json(filepath)
    local data = utils.read_json(filepath)
    if not data or not data.items then return {} end
    return data.items
end

--- True si la valeur stringifiée se termine par `.json`
--- @param val any
--- @return string|nil
local function as_json_path(val)
    if val == nil then return nil end
    local s = utils.to_str(val)
    if s ~= "" and s:match("%.json$") then return s end
    return nil
end

--- Résout les items d'un bloc : chemin JSON (`"file.json"` ou `{ items: "file.json" }`)
--- ou liste YAML inline (`{ items: [ {...}, ... ] }`).
--- @param block_data any Valeur lue dans le YAML du document
--- @return table
function utils.load_items(block_data)
    if not block_data then return {} end

    if type(block_data) == "table" and block_data.items then
        local filepath = as_json_path(block_data.items)
        if filepath then
            return utils.read_items_from_json(filepath)
        end
        local items = {}
        for _, item in ipairs(block_data.items) do
            table.insert(items, item)
        end
        return items
    end

    local filepath = as_json_path(block_data)
    if filepath then
        return utils.read_items_from_json(filepath)
    end
    return {}
end

--- Lit la config d'un shortcode sous `extensions: ife-website: <key>:`
--- @param meta table Métadonnées Pandoc du document
--- @param key string Clé du bloc (`bandeauspecial`, `alaune`, ...)
--- @return table|nil `{ items, title, url, more_url, more_label,
---                     intro_title, intro_text, json, raw }`
function utils.block_config(meta, key)
    local data = meta["extensions.ife-website." .. key]
    if not data then return nil end

    local title, url, more_url, more_label = "", "", "", ""
    local intro_title, intro_text = "", ""
    if type(data) == "table" then
        title = utils.to_str(data.title)
        url = utils.to_str(data.url)
        more_url = utils.to_str(data.more_url or data.more)
        more_label = utils.to_str(data.more_label)
        intro_title = utils.to_str(data.intro_title)
        intro_text = utils.to_str(data.intro_text)
    end

    local filepath = nil
    if type(data) == "table" then
        filepath = as_json_path(data.items)
    end
    if not filepath then
        filepath = as_json_path(data)
    end
    local json = nil
    if filepath then
        json = utils.read_json(filepath)
        if json then
            if intro_title == "" then
                intro_title = utils.to_str(json.intro_title)
            end
            if intro_text == "" then
                intro_text = utils.to_str(json.intro_text)
            end
        end
    end

    return {
        items = utils.load_items(data),
        title = title,
        url = url,
        more_url = more_url,
        more_label = more_label,
        intro_title = intro_title,
        intro_text = intro_text,
        json = json,
        raw = data
    }
end

--- Première valeur non vide parmi les clés (ou indices) d'un item
--- @param item table
--- @param ... string|number
--- @return any|nil
function utils.raw_pick(item, ...)
    if type(item) ~= "table" then return nil end
    for i = 1, select("#", ...) do
        local val = item[select(i, ...)]
        if val ~= nil and utils.to_str(val) ~= "" then
            return val
        end
    end
    return nil
end

--- Comme `raw_pick`, mais retourne toujours une chaîne
--- @param item table
--- @param ... string|number
--- @return string
function utils.pick(item, ...)
    return utils.to_str(utils.raw_pick(item, ...))
end

local MONTHS_FR = {
    "janvier", "février", "mars", "avril", "mai", "juin",
    "juillet", "août", "septembre", "octobre", "novembre", "décembre"
}

--- Formate une date ISO (`YYYY-MM-DD` ou `YYYY-MM-DDTHH:MM`) en français.
--- Les autres chaînes sont renvoyées telles quelles.
--- @param value any
--- @return string
function utils.format_date_fr(value)
    local iso = utils.to_str(value)
    if iso == "" then return "" end
    local y, m, d, hh, mm = iso:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)[T ](%d%d):(%d%d)")
    if not y then
        y, m, d = iso:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)")
    end
    if not y then return iso end
    local month = MONTHS_FR[tonumber(m)]
    if not month then return iso end
    local date_text = string.format("%d %s %s", tonumber(d), month, y)
    if not hh then return date_text end
    local h = tonumber(hh)
    local min = tonumber(mm)
    if min == 0 then
        return string.format("%s, %dh", date_text, h)
    end
    return string.format("%s, %dh%02d", date_text, h, min)
end

--- Élément HTML omis si le contenu est vide
--- @param tag string
--- @param class_name string|nil
--- @param content string|nil Déjà échappé si besoin
--- @param attrs string|nil Attributs HTML déjà formatés (ex. ` lang="en"`)
--- @return string
function utils.el(tag, class_name, content, attrs)
    if not content or content == "" then return "" end
    attrs = attrs or ""
    if class_name and class_name ~= "" then
        return string.format('<%s class="%s"%s>%s</%s>', tag, class_name, attrs, content, tag)
    end
    return string.format("<%s%s>%s</%s>", tag, attrs, content, tag)
end

local page_has_h1 = false

--- Niveau du titre d'un bandeau : 1 si la page n'a pas encore de h1, sinon 2.
--- La page a un h1 quand `title` est renseigné ou qu'un bandeau précédent l'a pris.
--- Un titre Markdown `#` dans le corps de la page n'est pas détecté.
--- @param meta table Métadonnées du document
--- @return number
function utils.band_heading_level(meta)
    if page_has_h1 or utils.to_str(meta and meta.title) ~= "" then
        return 2
    end
    page_has_h1 = true
    return 1
end

--- Encodage pourcent d'une chaîne destinée à une query d'URL.
--- La classe est ASCII : `%w` suit la locale et laisse passer l'octet C3 de « é ».
--- @param text string|nil
--- @return string
function utils.url_encode(text)
    local s = utils.to_str(text)
    if s == "" then return "" end
    return (s:gsub("([^A-Za-z0-9%-_%.~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

--- Attribut `lang="en"` si le champ langue vaut EN, sinon chaîne vide
--- @param lang string|nil
--- @return string
function utils.lang_attr(lang)
    if utils.to_str(lang):upper() == "EN" then
        return ' lang="en"'
    end
    return ""
end

--- Attributs `target`/`rel` pour une URL http(s)
--- @param url string
--- @return string
function utils.link_attrs(url)
    if utils.to_str(url):match("^https?://") then
        return ' target="_blank" rel="noopener noreferrer"'
    end
    return ""
end

--- Mention masquée « nouvelle fenêtre » pour une URL http(s)
--- @param url string
--- @return string
function utils.new_window_hint(url)
    if utils.to_str(url):match("^https?://") then
        return '<span class="visually-hidden"> (nouvelle fenêtre)</span>'
    end
    return ""
end

--- Balise ouvrante d'une carte : `<a>` si URL, sinon `<div>`
--- @param url string|nil
--- @param class_name string
--- @return string
function utils.item_open(url, class_name)
    local href = utils.to_str(url)
    if href == "" then
        return string.format('<div class="%s">', class_name)
    end
    return string.format(
        '<a href="%s" class="%s"%s>',
        utils.html_escape(href),
        class_name,
        utils.link_attrs(href)
    )
end

--- Balise fermante complémentaire de `item_open`
--- @param url string|nil
--- @return string
function utils.item_close(url)
    if utils.to_str(url) == "" then return "</div>" end
    return utils.new_window_hint(url) .. "</a>"
end

--- Bloc image BEM, omis si `src` est vide.
--- Si `decorative` est vrai, `alt` est une chaîne vide (RGAA 1.1 / 1.2).
--- Sinon `alt` est obligatoire : son absence interrompt le rendu.
--- @param src string|nil
--- @param alt string|nil
--- @param wrapper_class string
--- @param decorative boolean|nil
--- @return string
function utils.image_html(src, alt, wrapper_class, decorative)
    local href = utils.html_escape(utils.to_str(src))
    if href == "" then return "" end
    local alt_text = ""
    if not decorative then
        alt_text = utils.html_escape(utils.to_str(alt))
        if alt_text == "" then
            error(string.format(
                "image_alt manquant pour l'image informative « %s ». Renseigne le champ image_alt dans le JSON.",
                utils.to_str(src)
            ))
        end
    end
    return string.format(
        '<div class="%s"><img src="%s" alt="%s" /></div>',
        wrapper_class,
        href,
        alt_text
    )
end

--- En-tête de section (titre serif, lien optionnel, bouton optionnel à droite)
--- @param title string|nil
--- @param href string|nil
--- @param more_html string|nil Bouton déjà rendu (`components.section_more_button`)
--- @return string
function utils.section_header_html(title, href, more_html)
    title = utils.html_escape(utils.to_str(title))
    if title == "" then return "" end
    href = utils.to_str(href)
    more_html = utils.to_str(more_html)

    local inner = string.format([[
            <h2 class="ife-section-title">%s</h2>
    ]], title)

    local header
    if href ~= "" then
        header = string.format(
            '<a href="%s" class="section-header">%s</a>',
            utils.html_escape(href),
            inner
        )
    else
        header = string.format('<div class="section-header">%s</div>', inner)
    end

    if more_html == "" then return header end
    return string.format([[
        <div class="section-header-row">
            %s
            %s
        </div>
    ]], header, more_html)
end

--- Enveloppe `section.section > .container`, plus HTML optionnel hors conteneur
--- @param header_html string|nil
--- @param body_html string|nil
--- @param bleed_html string|nil Rendu après `.container`
--- @param extra_class string|nil Classe BEM additionnelle sur `<section>`
--- @return string
function utils.section_html(header_html, body_html, bleed_html, extra_class)
    local class_name = "section"
    extra_class = utils.to_str(extra_class)
    if extra_class ~= "" then
        class_name = class_name .. " " .. extra_class
    end
    return string.format([[
        <section class="%s">
            <div class="container">
                %s
                %s
            </div>
            %s
        </section>
    ]], class_name, header_html or "", body_html or "", bleed_html or "")
end

return utils
