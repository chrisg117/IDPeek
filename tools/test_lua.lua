-- Unit tests for IDPeek's pure Lua (no WoW API). Run from the addon folder:
--   lua5.1 tools/test_lua.lua
local IDPeek = {}
for _, file in ipairs({ "Parse.lua", "Entries.lua" }) do
    assert(loadfile(file))("IDPeek", IDPeek)
end

local function same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for k, v in pairs(a) do if not same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

local function check(name, got, want)
    if not same(got, want) then
        error(name .. ": unexpected result", 2)
    end
end

-- Parse
local ids, bad = IDPeek.Parse("55752, 80801")
check("parse list", { ids, bad }, { { 55752, 80801 }, {} })
ids, bad = IDPeek.Parse("55752,,x abc")
check("parse junk", { ids, bad }, { { 55752 }, { "x", "abc" } })
ids, bad = IDPeek.Parse("")
check("parse empty", { ids, bad }, { {}, {} })
ids, bad = IDPeek.Parse("7 7\t8")
check("parse keeps order and duplicates", ids, { 7, 7, 8 })

-- BuildEntries, plain kinds
check("kit", IDPeek.BuildEntries("kit", { 55752 }),
    { { view = "model", kind = "kit", id = 55752, chain = "kit 55752" } })
check("display", IDPeek.BuildEntries("display", { 71701 })[1].view, "model")
check("model", IDPeek.BuildEntries("model", { 1381346 })[1].view, "scene")
check("texture", IDPeek.BuildEntries("texture", { 136207 })[1].view, "texture")
check("empty", IDPeek.BuildEntries("kit", {}), {})

print("OK")
