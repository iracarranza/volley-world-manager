# Tactics and training

Status as of 2026-08-07 (`bde2856`): **one of the three pages exists, one is
built but mis-scoped, and one does not exist at all.** This file is the design
record, written because the argument below has lived only in conversation and
has had to be re-explained from scratch more than once.

Read **§0 first** -- it is the settled structure, and the sections after it are
the reasoning that produced it.

What is live now:

- **A tactical planner**, in the match centre, built before training existed:
  drag blockers, set coverage zones, set the setter's release point. It is
  currently mis-sized (see "The planner's sizing contradiction" below).
- **An attribute training screen** (`training_screen.gd`), with two halves --
  an activity rail from conditioning to film, and an in-match flowchart of the
  rally. Both set the same `TrainingRegimen`.
- **`DefensivePlan`**, blocking strategy, floor system and serve targeting, all
  in the model and all read by the simulator.
- **A familiarity / system-fit layer** that already carries most of what
  "how well does this squad know this system" would need.

What does not exist: any input loop where the manager *demonstrates* something,
any learned-preference state distinct from ratings, any preset decomposed into
comparable asks, and any score of a tactic against what the squad is
comfortable with.

Mapped onto §0's three pages:

| Page | State |
|---|---|
| Attribute training | **built.** Squads, focus, pools, fractional progress. |
| Match training | **not built.** The tab exists and is a second way into attribute training. |
| Tactical planner | **built, in the wrong place, and only half the job.** It draws a plan; it does not decompose presets or score fit. |

---

## 0. The clipboard has three pages, and they are a cycle

The settled structure. Open the clipboard and flip between three pages:

| Page | What it changes | The unit it changes |
|---|---|---|
| **Attribute training** | current ability, upward toward the potential ceiling | the 0-100 ratings |
| **Match training** | *comfort and preference*, not ability | coordinates, tempos, zones, postures |
| **Tactical planner** | a declared plan | presets, then specifics |

They are not three menus. They are a loop:

1. The planner is where you **declare** a tactic -- from a preset ("Feed
   Opposite", "Combination Play", "Pipe and Middle"; "Funnel into Line",
   "Spread Block") and then specified further.
2. The tactic is **scored against what the squad is actually comfortable
   with**. Every ask a tactic makes -- this hitter at this coordinate, at this
   tempo, this blocker bunched rather than spread, this defender covering that
   locus -- is a thing match training tracks, so the fit is directly comparable
   rather than inferred.
3. That score is **what tells you which match training to run.** The tactic
   names the gap; the drill closes it.
4. Match training moves the comfort values toward what the tactic asked for.
   Familiarity rises, and the same tactic scores better next week.

**Attribute training sits outside the loop, deliberately.** It raises the
ceiling of what is possible and has nothing to say about any particular tactic.
A hitter with enormous attack power whose comfortable coordinate is at the pin
still cannot run your combination play, and no amount of strength work will
change that -- only drilling the coordinate will. The two are different verbs on
different state and neither substitutes for the other.

**Focus belongs to attribute training only.** Low/medium/high, the attribute
pool, striking off versus aiming at -- all of it is about directing a rating
upward, so it has no meaning on the other two pages. The current build applies
focus to everything, which is wrong.

## 0.1 The state split this implies

Three kinds of per-voli state, and keeping them apart is the load-bearing
decision:

- **Ratings** -- 0-100, player-facing, in `ABILITY_ATTRIBUTES`. Capability.
  Attribute training moves these.
- **Bands** -- `SystemFitProfile`, an ideal and a tolerance, read directly by
  the simulator. Today these are *derived from ratings* by
  `refresh_system_fit_profiles`.
- **Learned preferences** -- comfortable coordinates per zone, comfortable
  tempos, the loci and courses a voli can dig, block posture comfort. Match
  training moves these. Mostly not player-facing as numbers; shown as marks on
  a court.

**The tension to resolve before building.** Match training is supposed to move
"comfortable hitting tempos", but the set-release band is *computed* from
`tempo_control`, `hand_control` and `adaptability`. As it stands, match training
cannot move it without either overriding the derivation or layering on top of
it.

The layered form is the one that serves the fiction:

```
band = derived-from-ratings  +  learned offset from match training
```

Attribute training moves the first term -- what this voli is naturally capable
of. Match training moves the second -- what *this manager* taught them. Which is
exactly "a professional knows how to hit a slide; they do not know this
manager's slide", expressed as arithmetic rather than as flavour.

There is a precedent already in the engine: `HitterPlacementModel` keeps a
`placement_memory` per voli per lane, learned *during rallies* from what worked.
That is the same kind of state match training would write. Whether the two share
one channel is a real decision and probably yes -- a match that keeps punishing
a drilled coordinate should un-teach it, which is the "places that work are
gravitated towards" mechanic. But it means drills and matches compete, and that
should be chosen rather than discovered.

## 0.2 What a preset actually has to be

A preset cannot be a label. For step 2 above to work, "Combination Play" has to
decompose into concrete asks in the same space the preferences live in --
per-slot lane, tempo, coordinate, and for the defensive presets a block posture
and a set of covered loci. Only then can it be scored against what the squad is
comfortable with.

**That decomposition is the real work of the planner**, and it is worth more
than the drawing tools. A preset that is only a name gives the fit score nothing
to compare.

**Score per ask, not per tactic.** One familiarity number for a whole tactic
tells you it is going badly and nothing about what to do. A number per ask tells
you which drill to run, which is the entire point of the loop.

---

## 1. The idea worth protecting

**Your inputs are the training data.**

You are not selecting "Train: Quick Sets, 3 hours". You are demonstrating a
tempo, repeatedly, and the team's learned distribution converges on what you
actually demonstrated. The fiction is exact: a professional knows how to hit a
slide. They do not know *this manager's* slide.

The concrete shape, from the original sketch:

- **Tempo.** The hitters run and swing at the net at a regular pace. Your
  spacebar press determines when the set comes out, which is how high and how
  fast it goes. Tighter, more consistent timing teaches a faster tempo.
- **Hitting zone.** Press and release: a longer press means a further set at a
  preset height.
- **Slides at first tempo.** Arrow-key input for approach location and speed,
  space to jump and swing.

## 2. The load-bearing question: what does one rep write?

This is the decision the whole subsystem stands on.

**If a rep writes a scalar** -- `quick_set_familiarity += 3` -- then this is
FM training with a rhythm game bolted on. A skill check dressed as a mechanic.
It will feel like busywork by season two and the honest thing would be to cut
it.

**A rep must write a distribution.** The mean *and variance* of the release
timing you demonstrated, and the team's execution distribution moves toward
yours. Then "tighter timing teaches faster tempo" is not a rule anybody coded --
it falls out of you having demonstrated a tighter interval. The mechanic and the
model become the same object, which is rare and worth protecting from the first
line of code.

### Mistakes, and why they need no fail state

Yes, mistakes should be possible, and no, they should not be punished.

A mistimed rep is a *wide sample*. It widens the variance of what you taught.
One is nothing. Consistently sloppy and you have taught a sloppy tempo. That is
the entire consequence, and it needs no failure screen, no retry, and no score.

Difficulty scaling comes free from the same place: a first-tempo set has a
narrow window because *the physics window is narrow*, not because anything sets
`difficulty = hard`. Same principle as the rest of this engine -- the number
comes from the model, not from a dial.

## 3. One inversion: the setter still matters

As originally described, your press *is* the set -- which means during training
the setter's own attributes stop mattering, and a weak setter trains exactly as
well as a great one.

Better: **your input is the target, and the setter executes it through their own
band.** The simulator already models `set_release_interval` as an ideal value
plus a tolerance -- their natural rhythm, and how far off it they can work. A
great setter reproduces your demonstration tightly; a poor one smears it.

Then training a weak setter on first tempo *visibly does not take*, which is a
much better lesson than a rhythm game you can simply be good at.

## 4. Repetition tolerance

This is what kills subsystems like this, and both defences are cheaper to decide
now than to retrofit.

- **It must be skippable with an auto-result.** Delegate to the assistant coach
  = the existing distribution, no improvement. Not a penalty, just no movement.
- **A full week's session must be under about thirty seconds.** Cooking Mama is
  ninety seconds you play once; this is a weekly loop across multiple seasons.
  At two minutes it gets skipped by season two and the subsystem is dead weight
  that still has to be maintained.

## 5. Declare and demonstrate are two verbs

The tactic screen and the training loop are the same data seen twice, and the
naming should keep them apart rather than collapse them:

- **Tactics -- you declare.** Zones, assignments, priorities. Cheap, revisable,
  no skill involved. This is `DefensivePlan` and friends with a better front end.
- **Drills -- you demonstrate.** The rep loop. Writes distributions.

**The gap between them is the story.** Blockers declared pressing zone 3 but
only ever drilled reading zone 2 → the simulator shows them late on 3. That gap
is already half-modelled by the familiarity / system-fit layer.

Calling the whole thing "tactical training" hides the gap, and the gap is the
good part: name it one thing and there is nothing left to be inconsistent
*with*.

**Declared-versus-trained, as two overlays on one court, is the screen that
teaches you the game.** It is also buildable against what exists today, which
the drill loop is not -- that needs a real-time input loop, a rep scheduler and
a learned-distribution model the simulator reads. Build the legible screen
first; build the thing that teaches against it second.

### What the current training screen gets wrong

It reports `"system familiarity +2.0%, cohesion +0.5% a week"`. That is a number
about a number. The planner was legible precisely because it drew the
consequence *on the court*: this blocker stands here, this zone is watched.
Training should borrow that instrument rather than invent a percentage.

## 6. Two visual-language notes

- **One heat instrument, not two.** A 2D EQ-style visualiser for the net *and* a
  3D topographic map for the net is one thing done twice. The net is a plane, so
  an EQ visualiser is the right instrument for it. Topography belongs to the
  floor, which genuinely is a surface seen from above. Two visual languages for
  the same act of scroll-to-heat costs more than it returns.
- **A zone can be a place you stand or a thing you watch**, and blocking has
  both. The drag-and-drop and the heatmap may therefore be two different *axes*
  rather than two views of one thing. Worth settling before either is built.

## 7. The planner's sizing contradiction

Measured at `f55ebac`. `tactical_court.tscn` declares
`custom_minimum_size = Vector2(400, 500)` -- portrait. Its host,
`CourtAspectRatio` in `main.tscn`, declares `ratio = 2.0` -- landscape. A
container cannot shrink a child below its minimum, so the court stays 400x500
and the `AspectRatioContainer` centres the overflow: it lays out at **y = -155**,
with a third of it above the panel. That is why the lane labels are cut off
mid-word in the match centre, and why it looks correct once the workspace popup
gives it 786px of width.

The court draws landscape -- net vertical, two halves side by side -- so the
minimum is the wrong one of the two.

Note also that if most of the planner moves pre-match, as section 5 implies,
the match centre should keep only *adjustments* (timeout, rotation, a couple of
toggles) and most of this screen leaves rather than gets resized.

## 8. Where these live on the desk

Naming, settled:

| Object | What it is | Code |
|---|---|---|
| Title screen | Saves, theme, the room | `title_screen.gd` |
| The journal | The club: home, roster, team, transfers, competition | `journal_screen.gd` |
| The desk | The menu -- zoom out from the journal | *not built* |
| Training clipboard | Tactics *and* drills | `training_screen.gd` |
| Scouting folders | Prospects and marks | `scouting_screen.gd` |
| The planner | The daily schedule | `schedule_screen.gd` |
| Match centre | The match, and in-match adjustments only | `match_screen.gd` |

Only the journal wears the scrapbook / cross-stitch treatment. The other objects
are different media and want different ones -- see
`UI_VISUAL_SYSTEM_CONSTRAINTS.md`.
