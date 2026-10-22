local _, IDPeek = ...

-- Which preview view shows each kind of id.
local VIEWS = { kit = "model", display = "model", model = "scene", texture = "texture" }

-- kind, {ids} -> list of { view, kind, id, chain }
function IDPeek.BuildEntries(kind, ids)
    local entries = {}
    for _, id in ipairs(ids) do
        entries[#entries + 1] = { view = VIEWS[kind], kind = kind, id = id, chain = kind .. " " .. id }
    end
    return entries
end
