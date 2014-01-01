mt_repl_use_moonscript = false

if not mt_repl_debugging then
    mt = minetest
    p = minetest.get_player_by_name('singleplayer')
end

function len(x)
-- Counts the number of entries in the given table.
    local count = 0
    for _ in pairs(x) do
        count = count + 1
    end
    return count
end

function keys(x)
-- Returns an array of the given table's keys.
    local new = {}
    for k in pairs(x) do
        table.insert(new, k)
    end
    table.sort(new)
    return new
end
