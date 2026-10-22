local _, IDPeek = ...

-- "55752, 80801 x" -> {55752, 80801}, {"x"}
function IDPeek.Parse(text)
    local ids, bad = {}, {}
    for token in string.gmatch(text or "", "[^,%s]+") do
        if token:match("^%d+$") then
            ids[#ids + 1] = tonumber(token)
        else
            bad[#bad + 1] = token
        end
    end
    return ids, bad
end
