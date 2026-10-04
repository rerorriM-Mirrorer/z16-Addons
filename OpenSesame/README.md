# OpenSesame

OpenSesame opens nearby doors automatically with `//os auto on`. With auto mode
off, it still opens a door you have targeted. The addon waits a little over
seven seconds between requests to the same door.

## Repeated-door guard

The addon now pauses requests to a door after four attempts during one visit.
Other doors continue working. It tracks the door's numeric ID, so doors with
the same name have separate counts. The count includes attempts sent by the
addon in either opening mode, even if the game does not open the door.

Move more than three yalms beyond the configured opening range for two seconds
to reset that door's count. With the default opening range of ten yalms, this
means moving more than thirteen yalms away. Zoning or logging out resets all
counts. The cap remains in your saved settings.

| Command | Effect |
| --- | --- |
| `//os auto [on\|off]` | Enable, disable, or toggle nearby-door mode. |
| `//os limit` | Show the current per-door attempt limit. |
| `//os limit 4` | Set the limit to four (any whole number from 1 to 20). |
| `//os reset` | Clear visit counts now; keep the existing seven-second cooldown. |

Changing the limit keeps current counts. Raising it can let a paused door
receive more requests. Lowering it can pause one immediately.

## How the guard works

`doors` is refreshed as nearby game entities change. `attempts` remembers how
many requests were sent to each door across those refreshes, while `last`
enforces the original seven-second cooldown. The comments in
`OpenSesame.lua` sit at the decisions that connect those pieces.

For an in-game check, stand by a door with auto mode on. It should stop after
four requests and print one pause message. Another door should still work.
Try auto mode off while keeping the first door targeted; it should remain
paused. Move away for two seconds and return, then try `//os reset` and a zone
change. These cases need a live Windower and retail FFXI client to verify.
