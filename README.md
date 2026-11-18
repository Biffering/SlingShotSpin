# Slingshot Spin (Godot 4)

Pull back the slingshot, let the ball fly, and watch it bounce around a spinning drum,
collect power-ups and smash barriers. Spend your points on upgrades that carry over between runs.

## Run it

1. Install **Godot 4.3 or newer** (the standard build; the .NET build is not needed).
2. Open Godot, click **Import**, and pick `project.godot` in this folder.
3. Let it import the sounds (a few seconds), then press **F5** (Run Project).

It runs in a portrait window (540×960) and scales to any size. Touch works on phones too.

## How to play

- **Press on the ball, drag back, let go.** The ball launches the opposite way you pull. The further you pull, the harder it goes (the % under the slingshot shows power).
- After launch you just watch. The run ends when the ball comes to a stop (or after 60 s).
- Your score is added to your **bank**. Spend it in **Upgrades**. Progress saves automatically.

## What's in the arena

| Thing | What it does |
|---|---|
| **The spinning drum** (big ring) | Its wall is split into sections worth 10 to 250 points. Three sections are open gaps, so the ball can fly *into* the drum, ricochet off the inside, and fly back out. Hitting a section kicks the ball in the spin direction. |
| **Jackpot core** (gold center) | Fly through it for 300 points. |
| **Spinner bumpers** (3 small drums) | Fast-spinning slices worth 10-50, with a hard bounce. |
| **Barriers** | Take 1-3 hits to break (white pips = hits left). Break them for points. |
| **Emblems** (floating, spinning in place) | Fly through to collect: |
| ⚡ Speed | The ball stays fast for a few seconds. |
| ✸ Smash 1-5 | The ball ploughs straight through that many barriers (number and pips show the level). Smashed barriers pay 1.5×. |
| x2 | Double points for a few seconds. |
| $ | Instant bonus points. |

**Pep talks:** when the ball is running out of steam, the game cheers it on ("COME ON, BALL!") and gives it a push. You get 1 per run, plus more from upgrades.

## Upgrades (saved between sessions)

| Upgrade | Effect per level |
|---|---|
| Launch Power | +8% launch speed |
| Endurance | Ball slows down more gradually (longer runs) |
| Point Value | +15% points from everything |
| Smash Strength | Smash emblems roll higher levels |
| Emblem Luck | +1 emblem in the arena |
| Power Duration | Speed and x2 last 15% longer |
| Pep Talks | +1 motivational push per run |

Prices go up by 55% per level. The save file is `user://save.json`; in Godot use **Project > Open User Data Folder** to find it, and delete it to start fresh.

## Sounds

All sounds are in `audio/sfx/` and were synthesized for this game (no licensing to worry about):

- **Slingshot:** rubber creak while you pull (rises in pitch), snap and whoosh on release
- **Hits:** metal clang (drum sections), bright ding (spinners), wood knock (barriers), soft thud (walls)
- **Smash:** crash with a low boom, debris and glass tinkles, plus screen shake
- **Collecting:** a different sound per emblem (rising whoosh, power chord, coin, sparkle)
- **Ball movement while powered up:** looping sounds that follow the ball's speed: wind for Speed, a fiery crackle for Smash, a shimmer for x2
- **Celebrations:** fanfares for combos, score milestones and a new best, applause for jackpots and big combos, a "boing + coach whistle" when the ball gets a pep talk

### Adding real voice lines (optional)

The shout-outs ("GO BALL GO!", "COME ON, BALL!", "SMASHING!") appear on screen. To hear them spoken too,
drop recordings into `audio/voice/` named like this (`.wav`, `.ogg` or `.mp3`, up to 9 per key, a random one plays):

| File name | Plays when |
|---|---|
| `launch_1.ogg` | The ball is launched |
| `motivate_1.ogg` | A pep talk pushes the ball |
| `smash_1.ogg` | A barrier is smashed |
| `powerup_1.ogg` | Any emblem is collected |
| `combo_1.ogg` | A combo streak (replaces the small fanfare) |
| `milestone_1.ogg` | Score passes 500 / 1,000 / 2,500... |
| `jackpot_1.ogg` | The jackpot core is hit |
| `best_1.ogg` | New best score (replaces the big fanfare) |
| `end_1.ogg` | A run ends |

## Tuning

Most numbers are at the top of each script in `scripts/`:

- `main.gd`: arena layout (`RING_CENTER`, spinner spots), `BARRIER_COUNT`, `MAX_RUN_TIME`, shout-out lines
- `ring_drum.gd`: drum size, number of sections, gap positions, `VALUE_POOL` (section points)
- `save_data.gd`: upgrade list, prices and what each level does
- `ball.gd`: max speed, speed-boost minimum speed
- `emblem.gd` / `main.gd` `_roll_kind()`: how often each power-up appears

## Files

```
project.godot        Project settings (portrait, physics, autoloads)
scenes/main.tscn     The one scene; everything else is built in code
scripts/main.gd      Game flow, arena building, scoring, shout-outs
scripts/ball.gd      The ball, power-up state, movement sounds
scripts/slingshot.gd Pull-back aiming and launch
scripts/ring_drum.gd The big spinning drum with point sections and jackpot core
scripts/spinner.gd   Small spinning bumper drums
scripts/barrier.gd   Breakable barriers
scripts/emblem.gd    Floating power-up emblems
scripts/hud.gd       Score, banners, results screen, upgrade shop
scripts/save_data.gd Bank, best score, upgrades (autoload "SaveData")
scripts/sfx.gd       Sound manager and voice-line hooks (autoload "Sfx")
audio/sfx/           Sound effects
audio/voice/         Your optional voice recordings
```
