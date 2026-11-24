-- Bandeau informatif : annonce d'une ligne, image de fond, CTA blanc.
-- 0 item => bandeau omis. Au-delà de 1, seul le premier est rendu.
--
-- YAML (_quarto.yml):
--   extensions:
--     ife-website:
--       bandeauinformatif:
--         items: "_index_jsons/bandeauinformatif.json"
--
-- JSON: { "items": [ { "text", "cta_label", "cta_url", "image" } ] }
-- `text` accepte le Markdown inline et les logos `{ofce}` et `{cepii}`.
-- `image` est décorative (`alt=""`) : pas de champ `image_alt`.
-- Le texte est un `<p>`, pas un titre : une annonce n'ouvre pas de partie de la page.
-- `<section>` et non `<aside>` : Quarto déplace les `<aside>` dans la marge.

local utils = require(
    quarto.utils.resolve_path("_modules/utils.lua"):gsub("%.lua$", "")
)
local components = require(
    quarto.utils.resolve_path("_modules/components.lua"):gsub("%.lua$", "")
)

-- Logo dessiné en CSS (masque), doublé d'un texte masqué lu à sa place (RGAA 10.2).
local LOGOS = {
    ofce = "OFCE",
    cepii = "CEPII",
}

--- Remplace `{ofce}` et `{cepii}` par le logo blanc. Les autres `{…}` restent tels quels.
--- @param html string HTML inline déjà rendu
--- @return string
local function with_logos(html)
    return (html:gsub("{(%a+)}", function(key)
        local label = LOGOS[key:lower()]
        if not label then return nil end
        return string.format(
            '<span class="bandeauinformatif__logo bandeauinformatif__logo--%s"><span class="visually-hidden">%s</span></span>',
            key:lower(),
            label
        )
    end))
end

local function create_banner(item)
    local text = with_logos(utils.rich_inline(utils.pick(item, "text")))
    if text == "" then return "" end

    return string.format([[
        <section class="ife-band ife-band--cover bandeauinformatif" aria-label="Annonce">
            %s
            <div class="ife-band__inner">
                <p class="bandeauinformatif__text">%s</p>
                %s
            </div>
        </section>
    ]],
        utils.image_html(
            utils.pick(item, "image", "img", "cover"),
            "",
            "ife-band__media",
            true
        ),
        text,
        components.cta_button(
            utils.pick(item, "cta_label"),
            utils.pick(item, "cta_url"),
            "solid-light",
            "arrow"
        )
    )
end

return {
    ["bandeauinformatif"] = function(args, kwargs, meta)
        local cfg = utils.block_config(meta, "bandeauinformatif")
        if not cfg then
            return pandoc.Str("")
        end
        if #cfg.items == 0 then
            return pandoc.Str("")
        end
        return pandoc.RawBlock("html", create_banner(cfg.items[1]))
    end
}
