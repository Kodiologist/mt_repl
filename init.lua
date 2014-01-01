require 'posix'
inspect = require 'inspect'

local RC_FILE = os.getenv('HOME') .. '/.mt_replrc'
local TO_REPL_FIFO = os.getenv 'MT_REPL_FIFO_MT_TO_REPL'
local FROM_REPL_FIFO = os.getenv 'MT_REPL_FIFO_REPL_TO_MT'

mt_repl_use_moonscript = false

-----------------------------------------------------------------
-- * Subroutines
-----------------------------------------------------------------

local function note(s)
    minetest.log('info', '[mt_repl] ' .. s)
end

local function encode_reply(chunk, errmsg)

    if not chunk then
        reply = errmsg
    else
        succeeded, v = pcall(chunk)
        if not succeeded then
            reply = 'Runtime error: ' .. v
        else
            reply = inspect(v, {depth = 1})
        end
    end

    -- Encode internal newlines and add a terminating newline.
    reply = reply:gsub('@', '@@')
    reply = reply:gsub('\n', '@n')
    return reply .. '\n'
end

local function setup_repl()

    note('Loading rc file: ' .. RC_FILE)
    do
        local chunk, errmsg = loadfile(RC_FILE)
        if chunk then
            chunk()
        else
            note("Couldn't load rc file: " .. errmsg)
        end
    end

    local moonscript
    if mt_repl_use_moonscript then
        moonscript = {
            parse = require 'moonscript.parse',
            compile = require 'moonscript.compile'}
    end

    note('Opening from_repl: ' .. FROM_REPL_FIFO)
    local from_repl_fd = posix.open(FROM_REPL_FIFO, posix.O_NONBLOCK)

    note('Opening to_repl: ' .. TO_REPL_FIFO)
    local to_repl_obj = io.open(TO_REPL_FIFO, 'w')
    to_repl_obj:setvbuf 'no'

    note 'Connected'

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

            local chunk, errmsg
            if mt_repl_use_moonscript then
                note('Loading MoonScript: ' .. inp)
                -- Hack: We remove all the 'local' declarations
                -- in the generated Lua so that assignments go to
                -- global variables by default, as in plain Lua.
                -- As a side-effect, this also removes any
                -- 'local' declarations the user actually typed.
                local tree
                tree, errmsg = moonscript.parse.string(inp)
                if tree then
                    local lua_code, pos
                    lua_code, err, pos = moonscript.compile.tree(tree)
                    if lua_code then
                        lua_code = lua_code
                            :gsub('^local%s+%S+\n', '')
                            :gsub('(\n *)local%s+%S+\n', '%1')
                            :gsub('^local%s+', '')
                            :gsub('(\n *)local%s+', '%1')
                        chunk, errmsg = loadstring(lua_code, '(i)')
                        if errmsg then
                            errmsg = 'Generated-Lua parse error: ' .. errmsg
                        end
                    else
                        errmsg = 'MoonScript compilation error: ' .. moonscript.compile.format_error(errmsg, pos, inp)
                    end
                else
                     errmsg = 'MoonScript parse error: ' .. errmsg
                end
            else
                note('Loading Lua: ' .. inp)
                -- Hack: We attempt to automatically promote
                -- expressions to statements by first trying to
                -- read the input with a prepended 'return', and
                -- trying to read the input as-is if that doesn't
                -- parse.
                chunk, errmsg = loadstring('return ' .. inp, '(i)')
                if not chunk then
                    chunk, errmsg = loadstring(inp, '(i)')
                end
                if errmsg then
                    errmsg = 'Lua parse error: ' .. errmsg
                end
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

-----------------------------------------------------------------
-- * Mainline code
-----------------------------------------------------------------

if minetest then

    debugging = false

    local fifo_dir = minetest.get_modpath(minetest.get_current_modname())
    minetest.register_chatcommand('repl', {
        params = '',
        description = 'start the Lua REPL',
        func = function(player_name, param)
            setup_repl()
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

    setup_repl()

    while #minetest.registered_globalsteps > 0 do
        for _, f in ipairs(minetest.registered_globalsteps) do
            f(1)
        end
        posix.nanosleep(0, 1e8) -- .1 seconds
    end

    note 'Exiting'
end
