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
   course. This is our "zombies are only curable for a limited time" idea, made
   simple: cure early or there's nobody left to cure. (5%/day means the average zombie
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
| **CURE** a cell | ~20% of its infected become `cured` (immune). Costs 1 dose. |
| **CLEAR** a cell | ~40% of its infected become `dead`. Free. The morally heavy option. |
| **WAIT** | Skip today (the AI — and honest players — need a legal "do nothing"). |

- Start with ~10 doses. No doses → CURE unavailable.
- Buying an upgrade is a purchase alongside your action, not the action itself. ~decide

## 4. Money

Earn ~10/day flat + ~1 per 100 healthy alive — protecting neighborhoods literally funds
you; letting them rot shrinks your budget.

Display: internal units are small numbers for easy balancing; the UI shows them ×$1k —
"Funding: $55k", upgrades cost "$100k", etc.

## 5. PLAYER upgrades — 4 independent tracks with levels, NO tree

Four separate tracks, no connections between them — buy any track, any order. Two tracks
have a second level; level 2 requires level 1 of the SAME track only.

| Track | Level 1 | Level 2 |
|---|---|---|
| Better Cure | ~$100k — CURE 20% → 35% | ~$200k — 35% → 50% |
| Extra Doses | ~$80k — +5 doses | ~$120k — +5 more |
| Rush Vaccine | ~$150k — vaccine 3 days earlier | — |
| Quarantine | ~$120k — all spread chances halved | — |

Economy check: lifetime income is ~$250–300k, maxing everything costs ~$770k — so you
afford 2–3 purchases per game. Choosing WHICH is part of the game.

(Not to be confused with the VIRUS "skill tree" idea — that's §11 post-MVP.)

## 6. Vaccine + endings

- Vaccine ready day ~25 (~22 rushed). Cannot be rushed further — that's the point: you
  can't win early, only lose less until rescue. When it arrives, all `healthy` become
  `cured`, game ends. Still-infected at that moment count as lost — only cures save zombies.

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
  agent plays thousands of games, learns which cells to help and when curing beats clearing.
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
  trained on" research question
- Varying AI-partner assistance / information given to the player
- Partial information (player only sees some cells' details clearly)

---
*v2 — my proposal, everything's arguable. Comment and we'll tune it, then freeze. — Aydin*
