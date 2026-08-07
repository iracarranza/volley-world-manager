# Tactics and training

Status as of 2026-08-07 (`f55ebac`): **the declare half exists and is
half-broken; the demonstrate half does not exist at all.** This file is the
design record for both, written because the argument below has lived only in
conversation and has had to be re-explained from scratch more than once.

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
any learned distribution, and any screen that shows the gap between what was
declared and what was drilled.

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
