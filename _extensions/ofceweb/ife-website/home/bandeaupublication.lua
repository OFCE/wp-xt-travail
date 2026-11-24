-- Bandeau publication : la variante suit le nombre d'items.
--   1 item    => bandeau complet (thème, date, titre, extrait, auteurs, boutons).
--   2-3 items => cartes côte à côte (thème, bouton), une par item.
-- 0 item => section omise. Au-delà de 3, seuls les trois premiers sont rendus.
--
-- YAML (index.qmd):
--   extensions:
--     ife-website:
--       bandeaupublication:
--         items: "_index_jsons/bandeaupublication.json"
--
-- JSON: { "items": [ { "title", "date", "subtitle", "excerpt", "author",
--                     "cta_label", "cta_url", "more_label", "more_url",
--                     "image", "updated" } ] }
-- `updated` (facultatif) : date de mise à jour, affichée sous la date si renseignée.
-- `title` est le thème, `subtitle` le titre de la publication.
-- Bandeau complet : boutons de `components.publication_actions`.
-- Les cartes ne lisent que `title`, `more_label`, `more_url` et `image` :
-- leur seul bouton, « Nos publications », est celui du bandeau complet.
-- `image` est décorative (`alt=""`) : pas de champ `image_alt`.
-- Sans `more_url`, le bouton d'une carte est omis.
--
-- Les cartes ont toutes un h2 : sans titre commun, aucune ne peut être le h1.
-- La page qui les accueille porte donc son propre h1 (`title`).

local utils = require(
    quarto.utils.resolve_path("_modules/utils.lua"):gsub("%.lua$", "")
)
local components = require(
    quarto.utils.resolve_path("_modules/components.lua"):gsub("%.lua$", "")
)

local MAX_CARDS = 3

-- Les boutons des cartes ont souvent le même libellé : le thème, lu en texte
-- masqué, distingue leurs destinations (RGAA 6.1).
local function create_card(item)
    local theme = utils.pick(item, "title")
    local url = utils.pick(item, "more_url")
    local cta = ""
    if url ~= "" then
        local label = utils.pick(item, "more_label")
        if label == "" then label = "Nos publications" end
        cta = utils.el("div", "bandeaupublication__actions", components.cta_button(
            label,
            url,
            "outline-light",
            "arrow",
            nil,
            theme ~= "" and (" sur " .. theme) or nil
        ))
    end

    return string.format([[
            <li class="bandeaupublication__card">
                %s
                <div class="bandeaupublication__card-content">
                    %s
                    %s
                </div>
            </li>
    ]],
        utils.image_html(
            utils.pick(item, "image", "img", "cover"),
            "",
            "ife-band__media",
            true
        ),
        utils.el("h2", "bandeaupublication__title", utils.html_escape(theme)),
        cta
    )
end

local function create_cards(items)
    local cards = {}
    for i = 1, math.min(#items, MAX_CARDS) do
        table.insert(cards, create_card(items[i]))
    end
    return string.format([[
        <section class="ife-band ife-band--cover bandeaupublication bandeaupublication--cards bandeaupublication--cards-%d">
            <div class="ife-band__inner">
                <ul class="bandeaupublication__cards" role="list">
                    %s
                </ul>
            </div>
        </section>
    ]], #cards, table.concat(cards))
end

return {
    ["bandeaupublication"] = function(args, kwargs, meta)
        local cfg = utils.block_config(meta, "bandeaupublication")
        if not cfg then
            return pandoc.Str("")
        end
        if #cfg.items == 0 then
            return pandoc.Str("")
        end
        if #cfg.items > 1 then
            return pandoc.RawBlock("html", create_cards(cfg.items))
        end
        local item = cfg.items[1]
        return pandoc.RawBlock(
            "html",
            components.publication_band(
                "bandeaupublication",
                item,
                utils.band_heading_level(meta),
                utils.pick(item, "title")
            )
        )
    end
}
