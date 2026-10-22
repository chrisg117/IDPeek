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

-- BuildEntries, lookup kinds (WoW globals stubbed)
local printed, loadResult = {}, { true }
print_real, print = print, function(s) printed[#printed + 1] = s end
function IsAddOnLoaded() return IDPeek_Data ~= nil end
function LoadAddOn(name)
    assert(name == "IDPeek_Data")
    if loadResult[1] then
        IDPeek_Data = { spell = { [205128] = { { 53761, 65054 } }, [1] = { { 10, 20, 21 }, { 11, 30 } } },
                        worldeffect = { [735] = { 200316, 19 } } }
    end
    return unpack(loadResult)
end

loadResult = { nil, "DISABLED" }
check("data missing", IDPeek.BuildEntries("spell", { 205128 }), {})
check("data missing message", printed, { "IDPeek: IDPeek_Data not loaded (DISABLED)" })

loadResult = { true }
check("spell", IDPeek.BuildEntries("spell", { 205128 }),
    { { view = "model", kind = "kit", id = 65054, chain = "spell 205128 -> visual 53761 -> kit 65054" } })
local e = IDPeek.BuildEntries("spell", { 1 })
check("spell flattens", { #e, e[3].id, e[3].chain }, { 3, 30, "spell 1 -> visual 11 -> kit 30" })
check("worldeffect", IDPeek.BuildEntries("worldeffect", { 735 }),
    { { view = "scene", kind = "model", id = 200316, chain = "worldeffect 735 -> model 200316" } })
check("not in table", IDPeek.BuildEntries("spell", { 999999 }),
    { { kind = "spell", id = 999999, chain = "spell 999999 not in table" } })
print = print_real

print("OK")
