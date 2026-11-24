-- Bandeau présentation : bandeau 410px, image en fond, texte empilé à gauche.
-- Met en avant un contenu qui n'est pas une publication, en ouverture ou en
-- fin de page. Bouton libre, précédé d'un intertitre optionnel.
-- 0 item => section omise. Sans argument, seul le premier est rendu ;
-- `{{< bandeaupresentation id="..." >}}` rend l'item de même `id`.
--
-- YAML (_quarto.yml):
--   extensions:
--     ife-website:
--       bandeaupresentation:
--         items: "_index_jsons/bandeaupresentation.json"
--
-- JSON: { "items": [ { "id", "title", "text", "cta_title", "cta_label",
--                     "cta_url", "image" } ] }
-- Sans `cta_url`, le bouton et son intertitre `cta_title` sont omis.
-- Un `cta_url` en `mailto:` prend l'icône enveloppe et le texte masqué
-- « Écrire à ». Sans `cta_label`, le libellé est l'adresse.
-- `image` est décorative (`alt=""`) : pas de champ `image_alt`.

local utils = require(
    quarto.utils.resolve_path("_modules/utils.lua"):gsub("%.lua$", "")
)
local components = require(
    quarto.utils.resolve_path("_modules/components.lua"):gsub("%.lua$", "")
)

local function create_cta(item, level)
    local url = utils.pick(item, "cta_url")
    if url == "" then return "" end

    local label = utils.pick(item, "cta_label")
    local icon, prefix = "arrow", nil
    if url:match("^mailto:") then
        icon, prefix = "envelope", "Écrire à "
        if label == "" then label = url:gsub("^mailto:", "") end
    end

    return string.format([[
                    <div class="bandeaupresentation__cta">
                        %s
                        %s
                    </div>
    ]],
        utils.el(
            "h" .. (level + 1),
            "bandeaupresentation__cta-title",
            utils.html_escape(utils.pick(item, "cta_title"))
        ),
        components.cta_button(label, url, "outline-light", icon, prefix)
    )
end

local function create_banner(item, level)
    local id = utils.pick(item, "id")
    return string.format([[
        <section%s class="ife-band ife-band--cover bandeaupresentation">
            %s
            <div class="ife-band__inner">
                <div class="ife-band__content">
                    <div class="bandeaupresentation__intro">
                        %s
                        %s
                    </div>
                    %s
                </div>
            </div>
        </section>
    ]],
        id ~= "" and (' id="' .. utils.html_escape(id) .. '"') or "",
        utils.image_html(
            utils.pick(item, "image", "img", "cover"),
            "",
            "ife-band__media",
            true
        ),
        utils.el(
            "h" .. level,
            "bandeaupresentation__title",
            utils.html_escape(utils.pick(item, "title"))
        ),
        utils.el(
            "p",
            "bandeaupresentation__text",
            utils.rich_inline(utils.pick(item, "text"))
        ),
        create_cta(item, level)
    )
end

return {
    ["bandeaupresentation"] = function(args, kwargs, meta)
        local cfg = utils.block_config(meta, "bandeaupresentation")
        if not cfg then
            return pandoc.Str("")
        end
        local wanted = utils.to_str(kwargs and kwargs["id"])
        local item = cfg.items[1]
        if wanted ~= "" then
            item = nil
            for _, it in ipairs(cfg.items) do
                if utils.pick(it, "id") == wanted then
                    item = it
                    break
                end
            end
        end
        if not item then
            return pandoc.Str("")
        end
        return pandoc.RawBlock(
            "html",
            create_banner(item, utils.band_heading_level(meta))
        )
    end
}
