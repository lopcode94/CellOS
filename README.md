# Symbio-Shack

**Don't digest me, I'll be your engine!** An endosymbiosis comedy roguelike in Godot 4. You're a frantic bacterium running the power plant inside a giant, dim-witted amoeba.

## Play
- **Windows, quickest:** double-click `play.bat`. It expects Godot at `%USERPROFILE%\Godot\`.
- **Any OS:** install [Godot 4.7+](https://godotengine.org/download), open this folder as a project, and press **F5**.

## Controls
| | Touch | PC |
|---|---|---|
| Steer | drag on empty soup | WASD / arrows |
| Slingshot ATP into the nucleus | grab a canister, pull back, release | click, drag back, release |
| ATP bomb (pops viruses, hurts the boss) | pull **all the way back** until it glows red, release | same with the mouse |
| Flick free radicals out | swipe them hard into the membrane | click, drag, release mid-swing |
| Citric cycle I ↔ II | tap CRANK | tap Space / right-click / 1-2 |
| **OVERDRIVE** (fast + strong, but mutates you) | hold CRANK | hold Space / right mouse |
| Emergency purge (−35% on both meters, 20 s cooldown) | PURGE button | F |
| Peel Macrophage Mom off the wall | tap her dent 3 times, or hold OVERDRIVE | click the dent |
| Unclog the conveyor, splat acid | tap | click |
| Lysosome cannon (if mutated) | CRY | E |
| Pause / mute | buttons | P or Esc / M |

Keep the ATP Energy Bar in the etched sweet zone. Starve the host and it **digests** you. Overfeed it and it **mutates** until it goes **supernova**. First run? A six-step tutorial walks you through it, and the title screen's TUTORIAL button replays it.

## For developers
- Full design: [GDD.md](GDD.md)
- Self-test: `godot --headless --path . -- --autotest`
- Screenshots: `godot --path . -- --shots=<folder>`
