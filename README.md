# minenet

Automated ore mining with ComputerCraft turtles. Requires a Geo Scanner and a
pickaxe. Place a chest next to the turtle to auto-deposit when full.

## Installation

On the turtle, run:

```
wget run https://raw.githubusercontent.com/icanthink42/minenet/refs/heads/main/turtle/install.lua
```

Press Enter to use the `main` branch.

## Deployment

Place the turtle facing **north**, then reboot. It will start mining immediately.

It drills shafts from its starting Y level down to bedrock, then back up, then
moves to the next column. Shafts are 16 blocks apart and it works up to 8
chunks from home.

## Modes

Run `mode <name>` to switch modes (restart `main` to apply).

| Mode | What it mines |
|------|---------------|
| `normal` | All ores |
| `diamond` | Diamond ore only |
| `netherite` | Ancient debris only |

<!-- vim: set tw=80: -->
