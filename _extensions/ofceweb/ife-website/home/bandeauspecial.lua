-- Bandeau spécial : bannière unique, dégradé CEPII → OFCE.
-- Même contenu que `bandeaupublication`, habillage aux couleurs de l'IFE.
-- 0 item => section omise. Au-delà de 1, seul le premier est rendu.
--
-- YAML (index.qmd):
--   extensions:
--     ife-website:
--       bandeauspecial:
--         items: "_index_jsons/bandeauspecial.json"
--
-- JSON: { "items": [ { "title", "date", "subtitle", "excerpt", "author",
--                     "cta_label", "cta_url", "more_label", "more_url",
--                     "image", "updated" } ] }
-- `updated` (facultatif) : date de mise à jour, affichée sous la date si renseignée.
-- `title` est le thème, `subtitle` le titre de la publication.
-- `image` est décorative (`alt=""`) : pas de champ `image_alt`.
-- Boutons : `components.publication_actions`.

local utils = require(
    quarto.utils.resolve_path("_modules/utils.lua"):gsub("%.lua$", "")
)
local components = require(
    quarto.utils.resolve_path("_modules/components.lua"):gsub("%.lua$", "")
)

return {
    ["bandeauspecial"] = function(args, kwargs, meta)
        local cfg = utils.block_config(meta, "bandeauspecial")
        if not cfg then
            return pandoc.Str("")
        end
        if #cfg.items == 0 then
            return pandoc.Str("")
        end
        local item = cfg.items[1]
        return pandoc.RawBlock(
            "html",
            components.publication_band(
                "bandeauspecial",
                item,
                utils.band_heading_level(meta),
                utils.pick(item, "title")
            )
        )
    end
}
