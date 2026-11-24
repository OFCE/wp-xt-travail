-- Dernières publications : liste de lignes à trois colonnes, puis panneau
-- sombre vers les sites OFCE et CEPII.
-- 0 item => section omise. `sites` vide => panneau omis.
--
-- YAML (index.qmd):
--   extensions:
--     ife-website:
--       publications:
--         items: "_index_jsons/publications.json"
--
-- JSON: { "intro_title", "intro_text",
--         "sites": [ { "url", "title", "description", "cta_label",
--                      "theme", "image" } ],
--         "items": [ { "url", "kicker", "title", "authors", "date",
--                      "type", "lang", "keywords", "source", "region",
--                      "updated" } ] }
-- `updated` (facultatif) : date de mise à jour, affichée sous la date si renseignée.
-- `region` : un code (`"fr"`) ou une liste (`["fr", "de", "eu"]`).
-- `image` est décorative (`alt=""`) : pas de champ `image_alt`.

local utils = require(
    quarto.utils.resolve_path("_modules/utils.lua"):gsub("%.lua$", "")
)
local components = require(
    quarto.utils.resolve_path("_modules/components.lua"):gsub("%.lua$", "")
)

local function title_html(title, url, lang)
    local text = utils.html_escape(title)
    if text == "" then return "" end
    local href = utils.to_str(url)
    local lang_attr = utils.lang_attr(lang)
    if href == "" then
        return string.format('<h3 class="publications__title"%s>%s</h3>', lang_attr, text)
    end
    return string.format(
        '<h3 class="publications__title"%s><a href="%s"%s>%s%s</a></h3>',
        lang_attr,
        utils.html_escape(href),
        utils.link_attrs(href),
        text,
        utils.new_window_hint(href)
    )
end

local function head_html(item)
    local parts = {
        components.badge_type(utils.pick(item, "type", "kicker")),
        components.lang_chip(utils.pick(item, "lang")),
        components.pdf_icon(utils.pick(item, "url", 1)),
    }
    local nonempty = {}
    for _, part in ipairs(parts) do
        if part ~= "" then table.insert(nonempty, part) end
    end
    if #nonempty == 0 then return "" end
    return string.format(
        '<div class="publications__head">%s</div>',
        table.concat(nonempty)
    )
end

local function create_item(item)
    local url = utils.pick(item, "url", 1)
    local title = utils.pick(item, "title", 3)

    return string.format([[
        <article class="publications__item">
            <div class="publications__meta">
                %s
                %s
            </div>
            <div class="publications__body">
                %s
                %s
            </div>
            <div class="publications__aside">
                %s
                %s
            </div>
        </article>
    ]],
        head_html(item),
        components.pub_date(
            "publications__date",
            utils.raw_pick(item, "date", "published"),
            utils.raw_pick(item, "updated")
        ),
        title_html(title, url, utils.pick(item, "lang")),
        components.authors_html(
            utils.pick(item, "authors", "author"),
            "publications__authors"
        ),
        components.source_badge(
            utils.pick(item, "source"),
            item.region
        ),
        components.keywords_row(item.keywords)
    )
end

local function theme_key(item)
    local t = utils.pick(item, "theme", "kicker", "source"):lower()
    if t:find("cepii", 1, true) then return "cepii" end
    if t:find("ofce", 1, true) then return "ofce" end
    local url = utils.pick(item, "url"):lower()
    if url:find("cepii", 1, true) then return "cepii" end
    if url:find("ofce", 1, true) then return "ofce" end
    return ""
end

local function card_class(item)
    local theme = theme_key(item)
    if theme == "" then return "publications__site" end
    return "publications__site publications__site--" .. theme
end

local function create_card(item)
    local title = utils.pick(item, "title")
    local image = utils.pick(item, "image", "img", "cover")
    local cta = utils.pick(item, "cta_label", "cta")
    if cta == "" then cta = "Visiter le site" end

    return string.format([[
        <article class="%s">
            %s
            <div class="publications__site-content">
                %s
                %s
            </div>
            %s
        </article>
    ]],
        card_class(item),
        utils.image_html(image, "", "publications__site-media", true),
        utils.el("h3", "publications__site-title", utils.html_escape(title)),
        utils.el(
            "p",
            "publications__site-description",
            utils.rich_inline(utils.pick(item, "description", "excerpt"))
        ),
        components.cta_button(
            cta,
            utils.pick(item, "url"),
            "solid-light",
            "arrow"
        )
    )
end

local function create_panel(sites, intro_title, intro_text)
    local cards_html = {}
    for _, item in ipairs(sites) do
        table.insert(cards_html, create_card(item))
    end

    return string.format([[
        <div class="ife-band publications__panel">
            <div class="ife-band__inner">
                <div class="publications__panel-intro">
                    %s
                    %s
                </div>
                <div class="publications__sites">
                    %s
                </div>
            </div>
        </div>
    ]],
        utils.el("h3", "publications__panel-heading", utils.html_escape(intro_title)),
        utils.el("p", "publications__panel-text", utils.rich_inline(intro_text)),
        table.concat(cards_html)
    )
end

return {
    ["publications"] = function(args, kwargs, meta)
        local cfg = utils.block_config(meta, "publications")
        if not cfg then
            return pandoc.Str("")
        end
        if #cfg.items == 0 then
            return pandoc.Str("")
        end

        local items_html = {}
        for _, item in ipairs(cfg.items) do
            table.insert(items_html, create_item(item))
        end

        local title = cfg.title
        if title == "" then title = "Dernières publications" end

        local body = string.format([[
                <div class="publications__list">
                    %s
                </div>
        ]], table.concat(items_html))

        local sites = {}
        if cfg.json and type(cfg.json.sites) == "table" then
            sites = cfg.json.sites
        end
        if #sites > 0 then
            local intro_title = cfg.intro_title
            if intro_title == "" then
                intro_title = "Explorez nos publications !"
            end
            body = body .. create_panel(sites, intro_title, cfg.intro_text)
        end

        local html = utils.section_html(
            utils.section_header_html(title, cfg.url, components.section_more_button(cfg, title)),
            body,
            "",
            "publications"
        )
        return pandoc.RawBlock("html", html)
    end
}
