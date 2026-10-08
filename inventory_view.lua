local M = {}

M.sort_modes = { "name", "name-desc", "quantity", "quantity-desc", "fill", "fill-desc" }

-- Lua's lower() handles ASCII; fold accented UTF-8 letters explicitly too.
function M.search_key(text)
    text = (text or ""):gsub("%[[^%]]*%]", "")
    local folds = {
        a = {"À","Á","Â","Ã","Ä","Å","à","á","â","ã","ä","å"},
        e = {"È","É","Ê","Ë","è","é","ê","ë"},
        i = {"Ì","Í","Î","Ï","ì","í","î","ï"},
        o = {"Ò","Ó","Ô","Õ","Ö","ò","ó","ô","õ","ö"},
        u = {"Ù","Ú","Û","Ü","ù","ú","û","ü"},
        c = {"Ç","ç"}, n = {"Ñ","ñ"}, y = {"Ý","Ÿ","ý","ÿ"},
        oe = {"Œ","œ"}, ae = {"Æ","æ"},
    }
    for replacement, letters in pairs(folds) do
        for _, letter in ipairs(letters) do text = text:gsub(letter, replacement) end
    end
    return string.lower(text):match("^%s*(.-)%s*$")
end

function M.request_names(player, pdata, items)
    pdata.item_names = pdata.item_names or {}
    pdata.item_name_requests = pdata.item_name_requests or {}
    pdata.item_name_pending = pdata.item_name_pending or {}
    for name in pairs(items) do
        local prototype = prototypes.item[name]
        if prototype and not pdata.item_names[name] and not pdata.item_name_pending[name] then
            local id = player.request_translation(prototype.localised_name)
            if id then
                pdata.item_name_requests[id] = name
                pdata.item_name_pending[name] = true
            end
        end
    end
end

function M.items()
    local items = {}
    for name in pairs(storage.inventory) do if prototypes.item[name] then items[name] = true end end
    for name in pairs(storage.limits) do if prototypes.item[name] then items[name] = true end end
    return items
end

function M.matches(name, query, pdata)
    query = M.search_key(query)
    if query == "" then return true end
    return M.search_key(name):find(query, 1, true) ~= nil
        or M.search_key((pdata.item_names or {})[name]):find(query, 1, true) ~= nil
end

function M.sorted(items, pdata, mode)
    local result, keys = {}, {}
    for name, included in pairs(items) do
        if included and prototypes.item[name] then
            result[#result + 1] = name
            keys[name] = M.search_key((pdata.item_names or {})[name] or name)
        end
    end
    local function alphabetical(a, b)
        if keys[a] == keys[b] then return a < b end
        return keys[a] < keys[b]
    end
    local function fill(name)
        local limit = storage.limits[name]
        return limit and limit > 0 and (storage.inventory[name] or 0) / limit or math.huge
    end
    table.sort(result, function(a, b)
        if mode == "name-desc" then return alphabetical(b, a) end
        if mode == "quantity" or mode == "quantity-desc" or mode == "fill" or mode == "fill-desc" then
            local av, bv
            if mode == "fill" or mode == "fill-desc" then
                av, bv = fill(a), fill(b)
                -- Unlimited/blocked items have no meaningful fill ratio: keep them last.
                if (av == math.huge) ~= (bv == math.huge) then return bv == math.huge end
            else
                av, bv = storage.inventory[a] or 0, storage.inventory[b] or 0
            end
            if av ~= bv then
                if mode == "quantity-desc" or mode == "fill-desc" then return av > bv end
                return av < bv
            end
        end
        return alphabetical(a, b)
    end)
    return result
end

return M
