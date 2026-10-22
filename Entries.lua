local _, IDPeek = ...

-- Which preview view shows each kind of id.
local VIEWS = { kit = "model", display = "model", model = "scene", texture = "texture" }

-- In-game checks:
--  1. worldeffect "735, 3079" -> "1 / 2 · worldeffect 735 -> model 200316" with the flag glow; Next -> model 199907.
--  2. spell 205128 -> "1 / 1 · spell 205128 -> visual 53761 -> kit 65054".
--  3. spell 999999 -> "1 / 1 · spell 999999 not in table", blank preview.
--  4. IDPeek_Data disabled in the AddOns list, /reload, spell 205128 -> chat
--     "IDPeek: IDPeek_Data not loaded (DISABLED)", no Lua error.
--  5. /reload, a kit list: /run print(IsAddOnLoaded("IDPeek_Data")) -> false.

-- The generated table is only loaded the first time a spell or worldeffect list is entered.
local function data()
    if not IsAddOnLoaded("IDPeek_Data") then
        local loaded, reason = LoadAddOn("IDPeek_Data")
        if not loaded then
            print(string.format("IDPeek: IDPeek_Data not loaded (%s)", tostring(reason)))
            return nil
        end
    end
    return IDPeek_Data
end

local EXPAND = {
    spell = function(entries, id, rows)
        for _, row in ipairs(rows) do
            for i = 2, #row do
                entries[#entries + 1] = { view = "model", kind = "kit", id = row[i],
                    chain = string.format("spell %d -> visual %d -> kit %d", id, row[1], row[i]) }
            end
        end
    end,
    worldeffect = function(entries, id, row)
        entries[#entries + 1] = { view = "scene", kind = "model", id = row[1],
            chain = string.format("worldeffect %d -> model %d", id, row[1]) }
    end,
}

-- kind, {ids} -> list of { view, kind, id, chain }; an entry without a view shows nothing.
function IDPeek.BuildEntries(kind, ids)
    local entries = {}
    local expand = EXPAND[kind]
    local tables = expand and #ids > 0 and data()
    if expand and not tables then
        return entries
    end
    for _, id in ipairs(ids) do
        if not expand then
            entries[#entries + 1] = { view = VIEWS[kind], kind = kind, id = id, chain = kind .. " " .. id }
        elseif tables[kind][id] then
            expand(entries, id, tables[kind][id])
        else
            entries[#entries + 1] = { kind = kind, id = id, chain = kind .. " " .. id .. " not in table" }
        end
    end
    return entries
end
