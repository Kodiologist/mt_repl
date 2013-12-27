mt_repl is a Minetest_ mod that provides a Lua `read–eval–print loop`_ (REPL). You can type Lua statements or expressions and see the results in your favorite terminal emulator while Minetest is running. mt_repl is intended as a tool for debugging other mods.

Features
============================================================

- Automatic ``return`` (e.g., you can just type ``2 + 2`` instead of ``return 2 + 2`` or ``=2 + 2``)
- Pretty-printing::

      ~~> minetest.get_player_by_name('singleplayer'):getpos()
      {
        x = 133.19999694824,
        y = -2.5,
        z = -62.799999237061
      }

- GNU Readline support (including persistent history)
- Custom startup files

Caveats
============================================================

- I've only tested it on Linux, and it's implemented in a way that it probably won't work on non-Unix-likes (it uses named pipes and luaposix).
- I've only tested it in single-player mode. There is no sandboxing. **Don't enable this mod on a multiplayer server if you don't trust the other players not to erase your home directory.**
- Multi-line commands aren't allowed.
- ``print`` will use the Minetest server's standard output, which isn't the terminal you're looking at while you're using the REPL.

Installation
============================================================

Minetest versions 0.4.7 and later should be supported.

- Install the Lua modules `luaposix`_ and `inspect.lua`_. (luaposix is also available as the Debian package ``lua-posix``.)
- `Install the mod`_ like an ordinary Minetest mod. 
- Set the environment variables ``MT_REPL_FIFO_REPL_TO_MT`` and ``MT_REPL_FIFO_MT_TO_REPL`` to the paths of a pair of named pipes. I recommend doing this by putting

  ::

     export MT_REPL_FIFO_REPL_TO_MT="$HOME/.minetest/mods/mt_repl/fifo_repl_to_mt"
     export MT_REPL_FIFO_MT_TO_REPL="$HOME/.minetest/mods/mt_repl/fifo_mt_to_repl"

  in your .bashrc or whatever, then saying::

    $ mkfifo "$MT_REPL_FIFO_REPL_TO_MT"
    $ mkfifo "$MT_REPL_FIFO_MT_TO_REPL"

Usage
============================================================

When the mod is enabled, use the chat command ``/repl`` in-game, then run the included Python script ``repl.py`` in another terminal window, which should display a prompt.

To quit from the Python script, hit Control-D to signal EOF or enter the special input ``quit``. This will also terminate the REPL on the Minetest side, so you'll need to restart it (by saying ``/repl``) if you want to use it again.

If you put a Lua script named ``.mt_replrc`` in your home directory, it will be run each time the REPL starts up. See ``rc-example.lua``.

License
============================================================

This program is copyright 2013 Kodi Arfer.

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 2.1 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the `GNU Lesser General Public License`_ for more details.

.. _Minetest: http://minetest.net
.. _`read–eval–print loop`: http://en.wikipedia.org/wiki/Read%E2%80%93eval%E2%80%93print_loop
.. _luaposix: http://luaforge.net/projects/luaposix/
.. _inspect.lua: https://github.com/kikito/inspect.lua
.. _`Install the mod`: http://wiki.minetest.net/Installing_Mods
.. _`GNU Lesser General Public License`: http://www.gnu.org/licenses/
