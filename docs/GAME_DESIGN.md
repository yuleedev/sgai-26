# SGAI-26: Contain the Outbreak — How the Game Works (v2)

My proposal for the full rulebook, based on our team plan doc — everything with ~ is a
number we can tune, just update this doc when we change one.

Why this doc matters: the Godot game (humans play) and the Python copy (the RL trains on)
must follow the EXACT same rules and numbers, or comparing human vs AI decisions is
meaningless.

---

## 1. The board — how a cell actually works

A 5×5 grid. **24 infectable neighborhoods + 1 base**: the center cell (2,2) is the
spawn/base — ambulances dispatch from it, it can never be infected, it isn't a neighborhood.

A cell doesn't contain moving things — it's a box holding four numbers:

| Number | Meaning |
|---|---|
| `healthy` | people alive and uninfected |
| `infected` | zombies |
| `cured` | cured/vaccinated — immune forever (needed for scoring) |
| `dead` | self-explanatory |

- Population per neighborhood is random at start: ~50–150. Bigger population = catches
  infection easier (§2) — this is the "population density" trait from our plan.
  (Income & weather traits: post-MVP, §11.)
- Cell color on screen = infection level (the heatmap already built).
- The ambulance doesn't drive. "Dispatch" = click a cell. The game is about WHERE help
  goes, not the trip. (Driving animation = post-MVP decoration.)

## 2. The day loop (core engine)

One turn = one day, ~30 days max. Every day, in this exact order:

1. **Player acts** (§3) — one action.
2. **Infection grows inside cells**: each cell's infected convert ~30% of their count
   from healthy per day (rounded down, limited by healthy available).
   Also ~5% of each cell's infected **die naturally** per day — the infection runs its
   course. This is our "zombies are only treatable for a limited time" idea, made
   simple: treat early or there's nobody left to treat. (5%/day means the average zombie
   lasts ~20 days — "they die after a time" without tracking individual timers.)
3. **Spread to neighbor cells — chance-based**: each infected cell rolls once per
   up/down/left/right neighbor per day:
   `spread chance = (source infected × 0.5%) × (target population ÷ 100), capped at 60%`
   Example: 40 zombies beside a 120-person cell → 20% × 1.2 = **24% chance** ~2 infected
   appear there today. Crowded cells catch it easier. The base never can.
4. **Money comes in** (§4).
5. **Day +1**, check endings (§6).

## 3. Player actions (one per day)

| Action | What happens |
|---|---|
| **TREAT** a cell | ~20% of its infected become `cured` (immune). Costs 1 dose. |
| **CLEAR** a cell | ~40% of its infected become `dead`. Free. The morally heavy option. |
| **WAIT** | Skip today (the AI — and honest players — need a legal "do nothing"). |

- Start with ~10 doses. No doses → TREAT unavailable.
- Buying an upgrade is a purchase alongside your action, not the action itself. ~decide

## 4. Money

Earn ~10/day flat + ~1 per 100 healthy alive — protecting neighborhoods literally funds
you; letting them rot shrinks your budget.

Display: internal units are small numbers for easy balancing; the UI shows them ×$1k —
"Funding: $55k", upgrades cost "$100k", etc.

## 5. PLAYER upgrades — 5 independent tracks with levels, NO tree

Five separate tracks, no connections between them — buy any track, any order. Some
tracks have a second level; level 2 requires level 1 of the SAME track only. Exact costs
are all still TBD (marked below) — decide these once we start playtesting.

| Track | Level 1 | Level 2 |
|---|---|---|
| Better Treatment | TBD — TREAT 20% → 35% | TBD — 35% → 50% |
| Reinforced Clear | TBD one-time unlock — then each CLEAR use can optionally pay a small TBD fee for 40% → 55% kill (base free 40% CLEAR stays available too) | — |
| Extra Doses | TBD — +5 doses | TBD — +5 more |
| Rush Vaccine | TBD — vaccine 3 days earlier | — |
| Quarantine | TBD — all spread chances halved | — |

Note: Reinforced Clear works differently from the rest of the table — it's the only
track with a cost that repeats every time you use it, not a one-time purchase. This
mirrors TREAT's dose cost, so both actions now have a "free but weaker" and a "costs a
resource but stronger" version once unlocked.

Economy check: lifetime income is roughly $250–300k (rough estimate, depends on how
many people stay healthy — see open question below). Buying everything costs far more
than that, so you'll only ever afford a handful of purchases per game. Choosing WHICH
is part of the game. **Quarantine's price needs to land high enough that it isn't an
auto-buy — flagged as an open balance question, not yet resolved.**

(Not to be confused with the VIRUS "skill tree" idea — that's §11 post-MVP.)

## 6. Vaccine + endings

- Vaccine ready day ~25 (~22 rushed). Cannot be rushed further — that's the point: you
  can't win early, only lose less until rescue. When it arrives, all `healthy` become
  `cured`, game ends. Still-infected at that moment count as lost — only treatment saves zombies.

| Ending | Condition |
|---|---|
| **WIN** | vaccine arrived AND ≥ ~50% of original population alive (healthy+cured) |
| **PYRRHIC WIN** | vaccine arrived, < 50% alive |
| **LOSS** | all 24 neighborhoods fully infected/dead before the vaccine |

## 7. Score screen

Three numbers, shown separately, never combined (that tension is the serious-game point):
**People lost · Zombies killed · Zombies cured**

## 8. Decision logging

Both game versions append one CSV row per day:

```
game_id, player_type(human|ai), day, action, cell_x, cell_y,
doses_left, money, total_healthy, total_infected, total_cured, total_dead
```

...plus one summary row per game (ending, days, three scores, upgrades bought).
Comparing these files between humans and AI IS the research project.

## 9. The AI plan (parallel track, doesn't block the game)

- **RL-only for MVP** — no images/CNN. The AI sees numbers.
- Python copy of §1–6 (no graphics), reusing the class baseline's DQN machinery. The
  agent plays thousands of games, learns which cells to help and when treating beats clearing.
- AI sees daily: 24 cells' numbers + doses + money + day + vaccine countdown.
  AI picks: cell + action, or WAIT, or an upgrade.
- (Formally this is a Markov Decision Process — the "markov decision tree" from our
  plan. DQN is a standard way to solve one.)
- Humans play Godot, AI plays the Python twin, logs compared. Live AI-in-Godot bridge:
  optional polish.

## 10. Build order

1. Day loop + spread (§2) — nothing is testable without it
2. Actions + doses (§3) — now it's a game
3. Money + upgrades (§4–5) — now there are tradeoffs
4. Vaccine + endings + scores (§6–7) — now it's finishable
5. CSV logging (§8) — required for the research
6. Polish (animations, sounds, fancy menus) — LAST

## 11. Post-MVP ideas from our plan (kept, staged, not deleted)

- Income / weather traits per cell affecting play
- Morale system
- **Virus evolution "skill tree"**: scenario files that change how the outbreak behaves
  each run (random starts, weights, virus behavior) — great for the "vary what the AI is
  trained on" research question **→ NOW IMPLEMENTED as CSV scenario system, see §12**
- Varying AI-partner assistance / information given to the player
- Partial information (player only sees some cells' details clearly)

## 12. CSV scenario system — virus evolution & environment data

Each game run loads two CSV files from `data/` that replace hardcoded randomness with
deterministic, shareable, tuneable data. A procedural generator (`scenario_generator.gd`)
creates new random scenarios on demand. The game falls back to random generation if
CSV files are missing.

### 12a. Scenario CSV (`data/<id>.csv`)

Per-cell environment configuration. One row per cell (25 rows for 5×5 grid):

```
x,y,population,origin,climate,terrain,wealth,pop_density
0,0,85,0,temperate,urban,1.2,1.1
0,1,75,0,temperate,suburban,0.8,0.9
...
```

| Column | Type | Meaning |
|---|---|---|
| `x`, `y` | int | Cell coordinates (0–4) |
| `population` | int | Starting healthy population. `0` for base cell or to trigger random fallback. |
| `origin` | 0/1 | `1` = virus spawn cell (exactly one per file). Must not be the base (2,2). |
| `climate` | string | Future-use tag: `temperate`, `tropical`, `arid`, `cold` |
| `terrain` | string | Future-use tag: `urban`, `suburban`, `rural`, `industrial` |
| `wealth` | float | Future-use income multiplier (~0.5–1.5) |
| `pop_density` | float | Future-use population density modifier (~0.6–1.4) |

### 12b. Virus schedule CSV (`data/<id>_virus_schedule.csv`)

The virus's "skill tree" — timed upgrades that change outbreak behavior each run:

```
day,upgrade_type,value,target_x,target_y,description
2,spread_boost,1.2,-1,-1,Virus adapts to local conditions
5,infection_rate,0.35,-1,-1,Strain B emerges — faster conversion
17,new_origin,-1,-1,-1,Virus migrates to most-infected cell
25,mutation,1.8,-1,-1,Final evolutionary leap — all parameters boosted
```

| Upgrade type | Effect on game constants |
|---|---|
| `spread_boost` | Multiplies `active_spread_chance` by `value` (compounding) |
| `infection_rate` | Replaces `active_convert_rate` with `value` |
| `death_resistance` | Replaces `active_death_rate` with `value` (lower = virus survives longer) |
| `new_origin` | Moves virus base to `(target_x, target_y)`, or most-infected cell if `-1` |
| `mutation` | Multiplies all three rates by `value` (compounding) |
| `extra_spread_amount` | Replaces `active_spread_amount` with `value` (int) |

Upgrades apply at the **start** of each day (after day increments, before infection
calculations). This means a day-5 upgrade is active during day 5's spread and growth.

### 12c. Procedural generator

`ScenarioGenerator` (static class in `scripts/core/scenario_generator.gd`) creates
random CSVs:

- `generate_scenario(id)` — random populations (50–150), random origin cell, random
  climate/terrain/wealth/pop_density tags. Writes `data/<id>.csv`.
- `generate_virus_schedule(id)` — 5–8 upgrades, escalating from mild (early) to
  aggressive (late). Early-game: spread/infection boosts. Mid-game: + death resistance,
  possible origin migration. Late-game: mutations, high multipliers. Writes
  `data/<id>_virus_schedule.csv`.

Call from GDScript: `ScenarioGenerator.generate_scenario("run_42")`
Then update `game_manager.gd` to load `"res://data/run_42.csv"`.

### 12d. Integration with game engine

`game_manager.gd` loads scenarios in `_ready()`:
1. `ScenarioLoader.load_scenario("res://data/sample_scenario.csv")` → populates
   `cell_data` with populations, sets `zombie_cell` from origin column.
2. `ScenarioLoader.load_virus_schedule("res://data/sample_virus_schedule.csv")` →
   stores upgrades keyed by day.
3. Mutable rate overrides (`active_convert_rate`, `active_spread_chance`, etc.)
   are initialized from the base constants and modified by virus schedule events.
4. `grow_infection()` and `spread_infection()` read the active rates, not the constants.

If either CSV is missing, the game falls back to the original random behavior.

---
*v3 — CSV scenario system added (§12). — opencode*
