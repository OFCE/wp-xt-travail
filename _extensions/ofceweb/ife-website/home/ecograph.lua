-- L'Ecograph : bannière unique, graphique en fond.
-- 0 item => section omise. Au-delà de 1, seul le premier est rendu.
-- Rendu partagé avec `bandeaupublication` : `components.publication_band`.
--
-- YAML (index.qmd):
--   extensions:
--     ife-website:
--       ecograph:
--         items: "_index_jsons/ecograph.json"
--
-- JSON: { "items": [ { "number", "title", "date", "subtitle", "excerpt",
--                     "author", "cta_label", "cta_url", "more_label",
--                     "more_url", "image", "updated" } ] }
-- `updated` (facultatif) : date de mise à jour, affichée sous la date si renseignée.
-- `image` est décorative (`alt=""`) : pas de champ `image_alt`.
-- Boutons : `components.publication_actions`.

local utils = require(
    quarto.utils.resolve_path("_modules/utils.lua"):gsub("%.lua$", "")
)
local components = require(
    quarto.utils.resolve_path("_modules/components.lua"):gsub("%.lua$", "")
)

local function heading_text(item)
    local title = utils.pick(item, "title")
    if title ~= "" then return title end
    local number = utils.pick(item, "number")
    if number == "" then return "" end
    return "L'Ecograph n°" .. number
end

return {
    ["ecograph"] = function(args, kwargs, meta)
        local cfg = utils.block_config(meta, "ecograph")
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
                "ecograph",
                item,
                utils.band_heading_level(meta),
                heading_text(item)
            )
        )
    end
}
