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

## 0. Three things, and they are a cycle

> **Amended by §0.9.** This section was written when all three lived on the
> clipboard as pages. Two still do. The third -- match training -- turned out not
> to be a page at all: it is an appointment in the day, and running it is a live
> event. What each *does* is unchanged and still correct; only where you stand
> when you do it has moved. Read §0.9 before building any of this.

| Thing | Where it happens | What it changes | The unit it changes |
|---|---|---|---|
| **Attribute training** | clipboard page | current ability, upward toward the potential ceiling | the 0-100 ratings |
| **Match training** | *a session, in the day* | *comfort and preference*, not ability | coordinates, tempos, zones, postures |
| **Tactical planner** | clipboard page | a declared plan | presets, then specifics |

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

## 0.3 Is this too much for a player? Only if it is all exposed

The question that produced the rest of this section: a system with ratings,
bands, learned preferences, presets, asks, zones, tempos and postures sounds
like six spreadsheets before every match.

The answer is that **model complexity and decision complexity are different
quantities and only the second one costs anything.** The rally already computes
forty things nobody sees. What would sink this is not how many properties exist
but how many the player has to touch each week.

Football Manager is the proof, and it is worth being precise about *why* it
works rather than just citing it. FM's individual instructions are a large
surface and its mandatory decision count is near zero, because **every
instruction defaults from the role**. Pick a role and eight things are set
without being seen; override the two you care about. The modularity is
available, never imposed.

Volleyball earns *more* modularity than football, not less: six players, discrete
phases, and role specificity tight enough that a "case" is exact -- the middle in
rotation 3 -- rather than fuzzy. Cases are enumerable here, so case-by-case is
cheaper. That is an argument for the engine resolving many cases internally, not
for showing the player more of them.

### The layers

Three layers of state, and one rule that applies to all of them:

| Layer | What it holds | Where it surfaces |
|---|---|---|
| **Tactics** | declarative intent -- attack this way, defend this way | the planner page |
| **Individual instructions** | the tactic decomposed into per-voli asks | the planner, one level down |
| **Training** | what closes the gap the asks declare | attribute training on the clipboard; match training in the day's session (§0.9) |

**Individual instructions are generated, not authored.** They arrive filled in
from the preset and the squad's own comfort; the player edits exceptions. That is
what makes the layer free for somebody who ignores it, and it is exactly the FM
structure above.

Note that "an advanced surface for exact values" is deliberately *not* a fourth
layer -- see §0.6.

## 0.4 Every ask resolves from somewhere

The rule that makes "coarse by default" actually work. Each ask takes the first
of these that has an opinion:

1. **The voli's own comfort** -- do what you already do
2. **The preset** -- where the preset has an opinion
3. **The manager's edit** -- overrides both

The first entry is load-bearing and easy to leave implicit, which would be a
mistake: if the coarse default meant *unset*, the simulator would have to invent
a value, and a system that is simple to operate and impossible to reason about is
worse than a complicated one.

It also means **a blank tactic is a real playable position, not a stub.**
Everything defaulting to comfort is maximum familiarity and no edge -- a
legitimate way to play, and the honest baseline every edit is measured against.
Every edit past that is an explicit trade: better shape, worse familiarity, until
it is drilled.

## 0.5 The grain follows the thing being learned

What unit does a drill act on -- position, player, squad? The answer is that it
is **not a choice the player makes**, and it is not uniform either. Each
trainable has a natural grain that comes from the physical fact:

| Trainable | Grain | Why |
|---|---|---|
| Hitting coordinate | per voli, per lane | a coordinate is personal |
| Tempo comfort | per hitter–**setter pair** | tempo is a relationship, not a property of either |
| Dig loci and courses | per **rotation slot** | who takes deep line depends on where you stand, and volleyball rotates |
| Block posture (bunch/spread, commit/read) | per blocking **pair** | a block is two people agreeing |

"Per position or per player" is the obvious heuristic and it misses the two hard
cases, both of which are relationships rather than properties. A hitter who has
run first tempo for years has not run it *with this setter*, and that is the
interesting fact.

**Watch the pair matrices.** Tempo per hitter × setter is already six entries;
per lane as well it is thirty and the cost has exploded. Prefer a per-hitter
value with a per-setter modifier -- same fiction, linear cost.

## 0.6 Granularity, not modes

The tempting shape is a simple mode and an advanced mode. It is a trap: two
interfaces, one of them under-tested, and a mapping between them that leaks the
moment they disagree. It also frames depth as something you graduate to, which
makes the simple path feel like training wheels rather than a way to play.

The food-paste principle is stronger than a mode switch and worth stating in its
own terms: **draw the ratio with a finger or type the numbers -- there is one
ratio.** Two input methods writing the same state on the same object. Nothing to
keep in sync, nothing to outgrow.

So the coarse control and the exact control are the same control at different
zoom. A hitting coordinate is a mark you drag on a court *and* a pair of numbers;
a block posture is a slider *and* a distance in metres. Not two screens.

## 0.7 Rotations are the multiplier, and they are already 6x

The real scope risk, and the one that a tidy layering does not solve on its own:
`DefensivePlan`, `RotationLineup` and `OffensivePlay` each carry
`rotation_number` in 1..6 today. Four clean layers each at six times the surface
is still six times the administration.

Football has no equivalent -- a football tactic has one state, not six.

**Author one rotation and derive the rest.** Rotations are a rigid permutation,
and a system is mostly rotation-invariant: the differences between them are
mechanical (who is front row, who is behind the setter). Two authored rotations
-- one serve-receive, one serving -- covers the genuine difference. Per-rotation
authoring stays available for anyone who wants it.

If six rotations stay mandatory, the subsystem dies of admin however good the
rest of it is.

## 0.8 The failure mode to design against

Not week one. Presets and comfort-defaults handle a new player fine.

**Week forty**, with three tactics, six rotations and eleven volis, when somebody
gets injured and the screen asks for a re-audit of all of it. A management game
is mostly its maintenance interaction, and that is a different problem from
onboarding. The weekly loop should be: the fit score names the worst gap, you
drill that, done -- one decision, not thirty-six.

## 0.9 Drills are an appointment, not a page

The structural correction. **Drills come out of the clipboard entirely.** They
are not a menu you configure; they are an hour in the day you either attend or
do not, and attending is a live event on the same footing as a match.

### The day

The day advances an hour at a time. The hour that matters is **the start of
training**, and the day's shape is a property of the roster rather than a
setting:

- Each voli has a window -- when they wake, when they can still work. Traits
  move it: an **Early Riser** wakes before the squad, a **Night Owl** is
  serviceable at ten in the evening.
- The team's session can only start at the **earliest hour the squad it needs
  is actually awake**, so the day you get is composed from the people you
  signed. A squad of night owls has a different clock than a squad of early
  risers, and neither was chosen from a dropdown.
- Not every day has a session.

At the session hour the game asks one question: **are you taking this one?**

- **No** -- the assistant coach runs it. It resolves, it moves the numbers, you
  see the result. This is the whole of the maintenance interaction on a normal
  day, and it must stay one keypress.
- **Yes** -- the drill session opens as a live event, and you participate. Your
  inputs are the demonstration (§1), so the session is where the demonstration
  physically happens.

This is what §4's two constraints were asking for, arrived at from the other
direction: a thing you can skip with an honest auto-result, and a thing worth
attending when you choose to. Neither is achievable by a screen with a
dropdown on it, which is why the drill page was never going to work.

### Time is the resource, and it is contested

Training does not cost "training points". It costs **hours**, and the hours have
other claimants: fitness upkeep, sleep, social time, sponsorship obligations.
Buying more session time means taking it from one of those, and taking it has a
cost somewhere else. This is the mechanism that makes a training decision a
decision at all -- without it, the answer to "should I drill this?" is always
yes.

That makes the planner load-bearing rather than decorative: it stops being
"choose this week's focus" and becomes the day's hours laid out, which is what a
planner on a desk is for.

### Why you would train at all

The list, and the last one is the one this game has that FM does not:

1. An attribute is declining.
2. A match exposed a weakness, or an opponent's weakness worth exploiting.
3. You changed the tactic, and the squad has not been taught it.
4. **A match taught somebody something you did not ask for.** A hitter kept
   getting away with a coordinate half a metre off the one you declared, so
   they drifted toward it (§0.1's shared channel, which is now the agreed
   design). You can **revert** it or **encourage** it -- and either way you are
   spending the same hour.

(4) is the strongest justification for the whole structure, because it closes
the loop with an observed cause: the match wrote the drift, the clipboard shows
it, the session is where you answer it.

### What this costs, and the thing to measure first

A forty-week season at an hour a tick is a few thousand ticks. If a meaningful
fraction of them stop and ask something, the game is unplayable by week ten --
which is §0.8's failure mode wearing a clock instead of a roster.

So the number to measure before building the loop, not after: **how many hours
in a simulated season actually raise a prompt.** Not how many *could*, and not
what a threshold is nominally set to -- the count, over a real season, on a real
roster. A per-hour advance that prompts on 4% of hours is a rhythm; one that
prompts on 30% is a chore, and it will not announce which one it is.

### What this does *not* change

Everything §1-§5 says about what a rep writes, and everything §0.1 says about
the state split, is unaffected. Match training still moves learned preferences
and only those. It just does it in a room instead of on a page.

## 0.10 The board has two axes, and the empty cells are the design

The tactic board is not one picture with a phase selector on it. It is a
**matrix**: what you can adjust is the intersection of *what you are planning*
and *where you are standing to look at the court*.

| | Top down | Three quarter | Along the net |
|---|---|---|---|
| **Serve receive** | where the receiving three stand | -- | -- |
| **Attack** | lane priority | -- | set tightness, setter release distance |
| **Block** | which way the block funnels | who takes the seam, how wide the wall sits | -- |
| **Floor** | where each defender stands | -- | how tight the back row plays for the follow |

Each view can only answer the questions its own geometry contains, and that is
the reason to have more than one rather than a limitation to route around. Top
down answers *where* -- anything whose answer is a place on the floor. Along the
net answers *how far from the net* -- set tightness, the setter's release, how
tight a defender plays the follow, none of which exist in a plan view. Three
quarter answers neither, and **that is its job**: it is the only view where
depth and lateral position are legible at once, so it is what you look at to
*read* a plan the other two authored.

### The three views are one camera, and the unit is the metre

The views are three positions on a single orbit around the court, written as a
yaw and an elevation: three quarter stands 38° round from square-on and 30°
above the floor, along the net swings to 76° and drops to 12°, top down carries
on to 90° and 90°. Reading them in that order *is* the orbit, and keeping the
swing in one direction is why the near court stays on the left in all three -- a
view that flips which end is yours is one a coach has to re-learn on every
toggle.

**How much court is in frame is a property of the phase, not the view.** The
view fixes the angle and therefore how wide and how tall the frame has to be;
the phase fixes how deep. Blocking holds the net and the ground either side of
it, attack has to reach the far endline because that is where the ball is going,
floor is your court plus enough of theirs for the swing to come from somewhere.

That second axis is a correction. The first pass framed the whole eighteen-metre
court in every view, which made every metre honest and made the drawing small --
a pair of blockers that had filled a third of the sheet came out about sixty
pixels tall, because the block page was paying for sixteen metres of floor it has
no opinion about. The answer is *not* to go back to a net sized off the panel;
that is what made one net two different heights. One scale per view survives
untouched. What changed is what is inside the box, which is a framing decision
rather than a measurement.

Everything on the sheet is placed in metres and projected through that one map:
the net is 2.43 m because it is 2.43 m, the attack line is 3 m back, a voli is
as tall as the bake says they are. **A view's pixels-per-metre is derived, not
chosen** -- project the box of world it has to hold, measure what comes back,
divide by what the panel has.

This is the correction of a specific class of mistake rather than a
generalisation for its own sake. Each view used to build its own geometry from
shares of the panel, and the consequences were all of one kind: the same net drew
at two different heights depending on which view you were in, a blocker came out
roughly four metres tall in the plan view because shrinking the court grew the
voli, the plan view showed half a court, three quarter drew a shallow oblique
while baking its bodies at 14° of yaw -- which is not three quarters of anything
-- and a voli dropped in one view reappeared somewhere unrelated in another,
because the sheet was remembering where the cursor had been rather than where
the voli was.

The rule that falls out: **a placement is stored in court metres, never in
panel shares.** A share is only the same place while the panel and the camera
both hold still, and neither does.

### The empty cells were a design gap, and §0.11 closed them

Six of the twelve cells were blank, and two pieces of interface behaviour
existed only to cope with that -- **greying** (a view that cannot express a phase
says so rather than accepting the click and drawing nothing) and **auto-switch**
(choosing a view whose current phase is blank moves the phase). Both were honest
and both were debt: every cell filled is one fewer behaviour that has to explain
itself.

The drill filled them. Where a swing comes from and where it is aimed are both
places on a court, all three views draw the court, so all three can set it. The
table above is now full, which means greying and auto-switch never fire. They
are kept -- a new phase or a genuinely view-specific control would reopen a hole,
and the behaviour should be there when it does -- but they are no longer load
bearing, and the wording of each cell now says what that view is *better* at
rather than whether it can say anything at all.

Two rules the auto-switch has to follow while it exists, because a control that
silently moves *another* control is how a player loses their model of a screen:

1. **The view wins.** The player just asked for that view; it is the phase that
   moves. Moving the view instead would mean the two selectors chase each other.
2. **It has to be visible.** The board says what the current pair adjusts, in
   words, on the line beneath it -- so "what does this screen do right now" is
   always written down rather than inferred from which buttons are lit.

### Serve receive has one cell, and that is suspicious

It is a floor shape and nothing else, so top down is the only view with anything
to say about it. Either it earns cells in the other two -- passer depth against a
jump serve is an along-the-net question and a real one -- or it is not a peer of
the other three and belongs somewhere else entirely. Worth settling before the
zoom level below multiplies it.

## 0.11 The drill: a place on the net, a place on the floor, and a shot

The sheet's marks became its controls. There are two grids on every view and
they are the same two on all three, because every phase is an opinion about the
same pair of places:

- **The net zones** — 4, 3, 2 and the pipe — where a swing leaves. Marked on the
  tape and clicked there. "Right pin" is a place, and the honest control for a
  place is the place, which is the same argument that replaced the block
  priority `OptionButton` with four bars.
- **The target grid** on the receiving floor, where it lands. Dragged.

Between them runs a **dashed arrow**, and dashed is doing work: everything else
on the sheet states something about the court (the net is 2.43 m, the attack
line is three metres back) and this states something about the future.

**Dropping a voli on a pin makes them the one swinging.** No separate "assign
hitter" control, because there is nothing one would say that the drop does not.
Any voli can be dropped on any pin — if you want your setter grooving a right-pin
swing for a 6-2, the sheet lets you write that down, and refusing it would be the
interface having an opinion about volleyball that the manager did not ask for.

**Scrolling cycles the shot: spike, roll, tip.** What changes is the *shape* of
the arrow, because those three take visibly different paths out of one hand.

### What the drill is and is not

It is **familiarity, not tactics.** Writing "Ivo drills a roll from 4 into deep
cross" does not mean Ivo will play a roll shot there in a match; it means those
are the reps, and the rally model will find him more comfortable with that
contact from that place. This is the same split §0.1 draws everywhere else on
this clipboard: what is *practised* and what is *chosen* are different state, and
mixing them is how a training screen becomes a cheat menu.

The three phases read one arrow from three sides:

| phase | the same arrow |
|---|---|
| **Attack** | outgoing, from your pin to their floor — what is being grooved |
| **Floor** | incoming, from their pin to your floor — the course being read |
| **Block** | outgoing, with a wall in its path |

One arrow mirrored, rather than three concepts. What a defender is told to
expect is exactly what an attacker is told to hit, and drawing them as two
different things would hide that.

### Open, and deliberately not guessed at

Three questions the concept raised that the build does not answer, recorded
rather than resolved by fiat:

1. **Do opponents get placed?** A blocker in the arrow's path, a defender under
   it. It is the obvious way to make floor defence legible — a shot course with
   nobody to beat is hard to have an opinion about — but it also turns a plan for
   *your* volis into a plan against a specific imagined opponent, which is a
   different object and possibly a different page.
2. **Does the block redirect the arrow?** Drawing a deflection where a blocker
   stands is honest about what a block does. Whether the sheet should say *kill
   versus soft block* is the doubtful part: that is technique, and technique is
   what a drill session trains rather than what a plan declares.
3. **If blocking technique is drilled rather than planned, why is shot selection
   planned?** The asymmetry is real and unresolved. Either both are drill
   parameters and the sheet is choosing reps in both cases, or the shot is
   overreaching. Worth settling before opponent placement multiplies it.

### The zoom is a third axis, and it is the one that can run away

Drilling into a single zone -- a coordinate inside an attack zone, a blocking
behaviour against an attack from this zone, a shot type to expect in this floor
zone -- is a genuinely different grain, and it is where the most interesting
instructions live. It is also 3 views x 4 phases x 2 grains = 24 states, which
is §0.8's week-forty problem arriving early.

The mitigation is to refuse to make it a mode. **You drill in by clicking a mark
that is already on the board**, and what opens is about that mark. Then the zoom
level is never a place you can be lost in: it is always "this zone, this phase",
two clicks from anywhere, and the way out is the way you came.

### What is unbuilt and load-bearing

Marks are drawn, not manipulated. Selecting and dragging a blocker, a defender or
a coordinate needs every drawn element to carry an identity and a hit rect, which
is a larger job than the drawing was and is the actual next step -- the views are
worth nothing until a mark can be moved.

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
| Training clipboard | Tactics and development -- what you declare and what you raise | `training_screen.gd` |
| Scouting folders | Prospects and marks | `scouting_screen.gd` |
| The planner | The day's hours, and what claims them | `schedule_screen.gd` |
| The session | A drill session, run live | *not built* -- see §0.9 |
| Match centre | The match, and in-match adjustments only | `match_screen.gd` |

The clipboard carries **two** tabs, not three: **Tactics** (declare) and
**Development** (raise). Drills are not on it -- they are the session, and the
session is an appointment in the day (§0.9). What the clipboard keeps is the
**fit strip** that names the gap: `Rotation 1 · 4 asks · 1 unfamiliar ⟨ Ivo 4 ·
slide coordinate ⟩ →`, which points at *tomorrow's session* rather than at a
tab. That is the week-forty maintenance interaction in full: open the clipboard,
the strip names one gap, mark it for the session, leave.

Only the journal wears the scrapbook / cross-stitch treatment. The other objects
are different media and want different ones -- see
`UI_VISUAL_SYSTEM_CONSTRAINTS.md`.
