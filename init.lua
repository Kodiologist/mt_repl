require 'posix'
inspect = require 'inspect'

local TO_REPL_FIFO = 'fifo_mt_to_repl'
local FROM_REPL_FIFO = 'fifo_repl_to_mt'

local function note(s)
    minetest.log('info', '[mt_repl] ' .. s)
end

function len(x)
-- Counts the number of entries in a table.
    local count = 0
    for _ in pairs(x) do
      count = count + 1
    end
    return count
end

local function encode_reply(chunk, errmsg)

    if not chunk then
        reply = 'Parse error: ' .. errmsg
    else
        succeeded, v = pcall(chunk)
        if not succeeded then
            reply = 'Runtime error: ' .. v
        else
            reply = inspect(v, {depth = 1})
        end
    end

    -- Encode internal newlines and add a terminating newline.
    reply = reply:gsub('\\', '\\\\')
    reply = reply:gsub('\n', '\\n')
    return reply .. '\n'
end

function setup_repl(player_name, fifo_dir)

    local path = fifo_dir .. '/' .. FROM_REPL_FIFO
    note('Opening from_repl: ' .. path)
    local from_repl_fd = posix.open(path, posix.O_NONBLOCK)

    path = fifo_dir .. '/' .. TO_REPL_FIFO
    note('Opening to_repl: ' .. path)
    local to_repl_obj = io.open(path, 'w')
    to_repl_obj:setvbuf 'no'

    note 'Connected'

    -- Define some globals for the REPL user's convenience.
    if not debugging then
        mt = minetest
        p = minetest.get_player_by_name(player_name)
    end

    local tear_down

    local function globalstep(dtime)

        local inp = posix.read(from_repl_fd, 1)

        if inp then

            if not inp:byte() then
               -- An EOF character.
               tear_down()
               return
            end

            note 'Got a character; consuming input till newline'
            while inp:sub(-1) ~= '\n' do
                local char = posix.read(from_repl_fd, 1)
                if char then
                    if char:len() == 0 then
                        --- End of file.
                        tear_down()
                        return
                    else
                        inp = inp .. char
                    end
                end
            end
            -- Remove the trailing newline.
            inp = inp:sub(1, -2)

            note('Loading: ' .. inp)
            -- Hack: We attempt to automatically promote
            -- expressions to statements by first trying to read
            -- the input with a prepended 'return', and trying to
            -- read the input as-is if that doesn't parse.
            chunk, errmsg = loadstring('return ' .. inp, '(i)')
            if not chunk then
                chunk, errmsg = loadstring(inp, '(i)')
            end

            note 'Sending reply'
            to_repl_obj:write(encode_reply(chunk, errmsg))
        end
    end

    minetest.register_globalstep(globalstep)

    tear_down = function()
        note 'Tearing down'

        -- Deregister the globalstep.
        for i, f in ipairs(minetest.registered_globalsteps) do
            if f == globalstep then
                table.remove(minetest.registered_globalsteps, i)
                break
            end
        end

        note 'Closing files'
        io.close(to_repl_obj)
        posix.close(from_repl_fd)

        note 'Done'
    end

    return tear_down
end

if minetest then

    debugging = false

    local fifo_dir = minetest.get_modpath(minetest.get_current_modname())
    minetest.register_chatcommand('repl', {
        params = '',
        description = 'start the Lua REPL',
        func = function(player_name, param)
            setup_repl(player_name, fifo_dir)
        end})

else

    -- This file is being executed directly for debugging.
    debugging = true

    -- Set up a mock Minetest object.
    minetest = {
        log = function(a, s)
            print(string.upper(a) .. ': ' .. s)
            end,
        registered_globalsteps = {},
        register_globalstep = function(f)
            table.insert(minetest.registered_globalsteps, f)
            end}

    setup_repl(nil, '.')

    while #minetest.registered_globalsteps > 0 do
        for _, f in ipairs(minetest.registered_globalsteps) do
            f(1)
        end
        posix.sleep(1)
    end

    note 'Exiting'
end
