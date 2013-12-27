#!/usr/bin/env python

import os.path, atexit
import readline
  # Automatically adds GNU Readline to raw_input.

history_path = os.path.expanduser("~/.mt_repl_history")
readline.set_history_length(500)

fifo_dir = os.path.expanduser('~/.minetest/mods/mt_repl')
FROM_MT_FIFO = fifo_dir + '/fifo_mt_to_repl'
TO_MT_FIFO = fifo_dir + '/fifo_repl_to_mt'

def decode_reply(reply):
    # Strip trailing newline and decode internal newlines.
    reply = reply[:-1]
    reply = reply.replace('\\n', '\n')
    reply = reply.replace('\\\\', '\\')
    
    if reply == 'nil':
        return None
    else:
        return reply

try:
    readline.read_history_file(history_path)
except IOError:
    pass
atexit.register(readline.write_history_file, history_path)

with open(TO_MT_FIFO, 'w') as to_mt, open(FROM_MT_FIFO, 'r') as from_mt:
    while True:

        try:
            inp = raw_input('~~> ')
        except EOFError:
            break

        print >>to_mt, inp
        to_mt.flush()

        reply = decode_reply(from_mt.readline())
        if reply is not None:
            print reply
