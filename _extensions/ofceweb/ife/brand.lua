-- Habillage de la page selon la marque déclarée par `institution` dans
-- _quarto.yml : ife (défaut), ofce pour IFE|OFCE, cepii pour IFE|CEPII.
-- Pour ofce et cepii, le filtre pose `ife-brand` et `ife-brand-logo`, que
-- template.html lit pour la classe de <body> et le logo. Pour ife, il ne pose
-- rien : la page est celle de l'IFE.

local BRANDS = { "ife", "ofce", "cepii" }

local LOGOS = {
    ofce = "/assets/img/IFE-OFCE_logo_anthracite.svg",
    cepii = "/assets/img/IFE-CEPII_logo_anthracite.svg",
}

local function is_brand(value)
    for _, brand in ipairs(BRANDS) do
        if brand == value then return true end
    end
    return false
end

function Meta(meta)
    if meta.institution == nil then return nil end
    local declared = pandoc.utils.stringify(meta.institution)
    local brand = declared:lower()
    if not is_brand(brand) then
        quarto.log.warning(
            "institution : valeur \"" .. declared .. "\" inconnue, habillage de l'IFE appliqué."
            .. " Valeurs admises : " .. table.concat(BRANDS, ", ") .. "."
        )
        return nil
    end
    if LOGOS[brand] == nil then return nil end
    meta["ife-brand"] = brand
    meta["ife-brand-logo"] = LOGOS[brand]
    return meta
end
