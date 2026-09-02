# Volley World Manager

A volleyball management sim in Godot 4. The simulation is the point: numbers
come from models, not from dials, and the interface is a desk of physical
workspaces rather than one generic dashboard. The hand-kept journal is the
manager's organized working knowledge of the club and career, not a substitute
for every specialist interface.

## Run the tests

```bash
godot --headless --path . --script res://tests/test_runner.gd
```

Current branch baseline, verified 2026-09-02 at `4b60055`, after the merge of
`origin/main` at `e8ef68f` and the simulation/playback authority changes 1-5:
**2 of 2,221 checks fail**. A *third* failure is a regression; these two are not.

**The delta from that merge is not computable, and the reason is worth one
line.** Two attempts to measure the merged tree's own predecessor were spoiled --
the first had the working tree change underneath it mid-run, the second buffered
its output through a pipe and outlived its timeout -- so 2,221 has no measured
number before it on this tree. Four checks were authored
(`_test_movement_contract_completeness`), and the balance probe over 700 rallies
is byte-identical across all five changes, so no sampling population moved. What
that *cannot* say is how much of the distance from 2,174 is the 84 commits the
merge brought in. Quoting a difference against 2,174 would be comparing two
different trees, which is the mistake the rest of this section is about.

**The two are older than this branch and fail on `origin/main` unchanged.** Named
so nobody re-derives them:

- `_test_tempo_buys_flight_time` -- "only an extremely strict tactic imposes
  authored set shape over hitter rhythm"
- `_test_playback_geometry_is_drawable` -- "the two blockers stand beside each
  other, not inside each other (24 walls, 1 stacked, narrowest 0.000 m)"

**The line above used to read "2,178 checks pass, 0 fail" at `8f96dc6`, and it
was still saying so a week after that stopped being true.** The 2,174-with-two
measured at `5a55494` was never written here, so the file told every reader the
branch was green and to treat any failure as a regression -- which would have
made both known failures look like something the reader had just broken. That is
the exact failure this section spends a page warning about, and it happened to
the headline rather than to an entry.

**Zero delta from `5a55494`, and that is the right answer.** 2,174 before, 2,174
after, same two failures. The seven commits in between are documentation plus
`PRODUCE_BODIES` geometry -- the Stalk rebuilt from a smooth shaft into a leek --
and the suite samples neither, so an unmoved count is what a presentation-only
pass has to look like. The claim is checked independently: the garment clearance
and sole contact probes both re-run clean (every row positive, collars 0.0180
exactly, `defending` 9.71 degrees), and
`validate_voli_body_construction.gd` passes.

One caveat on that zero. `probe_garment_clearance.gd:36` iterates the six body
*types* and builds one Vegi, whose produce is whatever `produce_for(1)` returns
-- **Pepper**. The Stalk collar is the one thing this pass changed that
`_seat_collar` reads, and no probe has ever measured it. See
`docs/review/GARMENT_INK_CLEARANCE.md`.

**Four checks written, four gained, and the predecessor was recorded** -- so the
delta is attributable and says no sampling population moved. That is the right
answer for this pass twice over: FD-009 changed only which event the stamping
loop treats as a contact, and FD-007 changed only which half of an existing
animation plays. The balance probe agrees, byte-identical on all nine figures.

Before it, 2,174 at `10bfbdd`, on the §5 platform-height closure.

**Two readings there, and they said different things.** 2,163 to 2,170 came from a run
that authored *no* checks -- the gate was appended after `test_runner.gd` was
loaded -- so the whole of that seven is sampling gates drawing more, which is
what a real behaviour change looks like. 2,170 to 2,174 is then exactly the four
that gate adds, so publishing the wall's reaches on the block event moved no
population at all, which is what a pure metadata addition has to look like. Two
deltas, two different meanings, and the only reason either can be read is that
both predecessors were written down.

**A note on the second one, because the point survives being right.** 2,174 was
written into this line as a prediction while that run was still going, and then
removed. It turned out to be the correct number. Removing it was still right: a
figure is worth the commit it was *measured* on, and an unmeasured guess that
happens to land is not evidence -- it is a guess that got lucky, and the next one
will not.

**The interesting number in the entry above: seven more checks from writing none.**
2,163 was the predecessor and the run that measured 2,170 loaded `test_runner.gd`
before the gate was appended, so nothing was authored into it -- the whole delta
is sampling gates drawing more, which is what a real behaviour change looks like.
The platform resolver now reads the ball's height instead of the passer's body,
and rallies resolve differently as a result. The balance probe says how much and
which way: every **gated** band holds (dig 0.416, stuff 0.106, serve error
0.181), and the advisory figures moved -- kill 0.610 to 0.630, block touch 0.818
to 0.830, and **swing balance 0.932 to 0.888**, which is a home/opponent symmetry
indicator moving away from 1.00 and is recorded as an observation to watch rather
than acted on. See `docs/review/CONTACT_HEIGHT_CHAIN.md`.

Before it, 2,163 at `b28c099`, on the §5 contact-height chain pass.

**Seven checks were written and the count moved by seven, and that meant
something, because the predecessor was written down.** 2,156 was measured
at `0ea8402` and recorded here on the same pass, so the delta is attributable:
the count moved by exactly what was authored and no sampling population changed
size. The balance probe agrees independently -- contacts per rally, kill, dig,
stuff, serve error, ace, reception quality and block touch all byte-identical --
which is what a pass that moves the *record* rather than the rally has to look
like. Read the entry below for what happens when the predecessor is not written
down, one pass earlier.

Before it, 2,156 at `0ea8402`, on the block realised-contact pass.

**Seventeen checks were written and the delta cannot be computed, because the
pass in between never wrote its number down.** This line said 2,139 at `413eee5`
and the M8 side-out certification came after it without updating it, so the true
predecessor is either 2,139 -- in which case seventeen written and seventeen
gained means no sampling population moved -- or the 2,141 that pass measured and
left in a transcript, in which case two gates drew fewer and the population
moved. Those two readings say opposite things and there is no way to choose
between them now. **Which is the whole failure this section keeps warning about,
committed again, one pass later, by the pass that wrote the warning.** The number
is only worth the commit it was measured on, and a commit nobody recorded is not
one.

What is not ambiguous: the FAIL line is zero, and the population question the
count could not answer was measured directly. Contacts per rally 4.827 to 4.807,
dig 0.407 to 0.412, block touch 0.822 to 0.818, stuff and serve error unchanged,
every governed band holding -- so rallies *do* resolve differently, and the
probes say so whatever the count does. See
`docs/review/BLOCK_REALISED_CONTACT.md`.

The entry below is the older baseline and its own warning, kept because the
warning is the durable part.

**And that number cannot be attributed, which is the point of saying so.** Two
checks were written this pass (`_test_one_ball_chain_by_launch_identity`), and
C5 made floor defenders walk into their defensive shape instead of appearing in
it -- so rallies resolve differently and every sampling gate draws against a
different population. No pre-change count was measured on this branch state, so
how much of the move is the two checks and how much is the defence is simply not
known. What is known is the FAIL line: zero.

Two figures were already on record for the *same* M4 promotion and they disagree:
`RALLY_MILESTONES.md` says "Suite **2,132 PASS**" and the
`ENABLE_PHYSICAL_RECEPTION` comment says "the full suite is 2161/2161". Both were
true when written; at least one was measured on a slightly different tree. Left
standing rather than reconciled, because guessing which is which is exactly the
mistake this section keeps warning about -- but noted here so the next reader
does not treat either as the number to beat.

That is 2,142 plus six checks written **minus one**, and the minus one is the
interesting half: the continuation dig stopped fabricating a constant stretch, so
rallies resolve differently and a sampling gate drew one fewer. The 600-rally
outcome mix is nevertheless unchanged, because the repair touches nine contacts.

Five of those six are **characterisation checks rather than invariants** -- they
hold open the finding that the incoming ball's speed reaches no platform launch
and that a dig thrown four times as far leaves at the same height, and slice 3 is
supposed to make them fail. Adding a two-line transfer term moved the count to
2,149. See `docs/review/PLATFORM_TRANSFER.md`.

Before it, 2,137 plus exactly the five checks written, on a pass that was *required*
to move nothing: slice 1 publishes what a platform contact was for and nothing
reads it. The outcome mix over 600 rallies was verified byte-identical by running
one probe twice -- production, then `git stash` -- which is the only comparison
worth making, because the census quoted two entries below was taken on a
different seed base and could not have detected a change. See
`docs/review/PLATFORM_INTENT.md`.

Before it, 2,133 plus exactly the three checks written, and 2,133 was 2,131 plus
two. Four consecutive passes have
now moved the count by precisely what they wrote while moving populations by
wildly different amounts -- one halved the home wall's failure rows, two changed
no outcome at all -- so the count is measuring test authorship and nothing else.

Before it, 2,129 plus exactly the two checks written, on a change that moved no
outcome at all -- the mix over 600 rallies came back byte-identical, because no
live claim ever reaches the condition the repair added. A repair can be correct
and latent at the same time, and the count says nothing about which.

Before it, 2,126 plus exactly the three checks written -- a *repair* that moved a
population hard (the home wall's "no wall" rows fell 134 to 42 on the matched
block-band fixture) and still moved the count by precisely what it wrote, because
none of the sampling gates draw on the block census. Which is the reminder worth
keeping: a count that behaves says nothing about whether the population under it
moved. Read the FAIL line, then read the probe.

Before it, 2,123 plus exactly the three checks written, and 2,123 was itself 2,117
plus exactly the six before it. Two consecutive passes that moved the count by
precisely what they wrote -- which says only that neither disturbed a sampling
population, never that either was correct. The second of them *deleted a field*
and the outcome mix over 600 rallies came back byte-identical, which is what an
exactly-folded constant has to look like. See `docs/review/MOVING_ORIENTATION.md`
and `docs/review/READINESS_REMOVAL.md`.

Before them, 2,111 plus five checks written plus one: defenders now pay a turn cost
when the ball is behind them, so rallies resolve differently and a sampling gate
drew one more. See `docs/review/READY_ORIENTATION.md`.

That is 2,106 plus eleven checks written *minus six*: a landing blocker is now
unavailable to the floor-defence claim search, so rallies resolve differently and
several sampling gates drew fewer checks. A negative delta with checks added is
exactly what a real behaviour change looks like. See
`docs/review/DEFENSIVE_READINESS_BOUNDARY.md`.

The pass before it moved 2,104 → 2,106: two checks written and, again, no
sampling movement. See `docs/review/FORWARD_WALK_ATTACK_CHAIN.md`.

The pass before it moved 2,098 → 2,104: six checks written and, again, no
sampling movement. See `docs/review/SET_QUALITY_AND_GENERATION.md`.

The pass before it moved 2,095 → 2,098: four checks written and one sampling
gate drawing a check fewer, because the opponent's second contact began
consuming the state it was selected on and rallies resolve differently. See
`docs/review/FORWARD_WALK_HITTER_AND_SETTER_MOVEMENT.md`.

That one arrived in two moves and they mean opposite things. 2,087 → 2,090 came
with **no checks written at all**: the second contact may now transfer away from
an unreachable setter, so rallies resolve differently and the sampling gates
drew three more samples than before. Then 2,090 → 2,095 is exactly the five
checks that pass added, which says the test addition disturbed no sampling
population. See `docs/review/SECOND_CONTACT_TRANSFER.md`.

The two passes before it moved 2,078 → 2,082 → 2,087, each by precisely the
number of checks written — production behaviour changed and **no sampling gate's
population changed size**. See `docs/review/BLOCK_INSTRUCTION_PROOF.md` and
`docs/review/ATTEMPT_JUDGMENT_SPLIT.md`.
A count that moves by precisely the number of checks you wrote is the one case
where the total is worth reading — and it still is not evidence the change was
correct, only that it did not disturb coverage.

It does not always behave. The 2,078 entry was *fewer* than the 2,083 recorded
the day before with nothing deleted, because the forward serve changed which
rallies reach a reception and several sampling gates draw a check per sample. A
delta can therefore be negative, zero, or exactly what you wrote, and only the
last of those tells you anything.

The count itself is not the signal and should not be read as one -- sampling
tests emit a variable number of checks, and this line sat at 1,048 for four days
while the real figure climbed past 1,800, which is the failure mode a stale
baseline has: it is quoted, believed, and never rechecked. **Read the FAIL
line.** A number here is only worth the commit it was measured on, which is why
one is now named.

The slowest gate in the suite is `_test_world_aging`, which runs twenty seasons
of the world and counts what survives. It is the only check that will notice a
generation change leaking talent, and it is worth knowing it exists before
changing anything in `player_generator.gd` -- it has caught a one-line ceiling
bug that 1,047 other checks did not.

After adding or renaming a `class_name`, re-import before the suite will see it:

```bash
godot --headless --path . --import
```

`--check-only` reports autoload identifiers (`GameManager`, `CareerManager`) as
undeclared. That is not a real error.

## Read before you change things

**`docs/FAILURE_MODES.md` first, and its §0 screen in particular.** Every entry
is a mistake actually made in this repository, most of them more than once. The
recurring one is worth stating here: *a value measured with the wrong
instrument, or a knob that cannot reach its own stated range.* Before shipping a
threshold, measure the distribution it acts on. A threshold outside its
distribution does nothing, and does nothing silently.

Then, by subject:

| Working on | Read |
|---|---|
| **Anything about the interface at all** | `docs/design/DIEGETIC_MANAGEMENT.md` |
| Journal, roster/voli pages, what the manager knows, personality/preferences, staff reports, tabs/notes, career archive, office/job transitions | `docs/design/THE_JOURNAL_AND_KNOWLEDGE.md` |
| Paired 2D/3D views, observation vs input, physical presence | `docs/design/ABSTRACTION_AND_MANIFESTATION.md` |
| The clock, the day, the calendar, manager time | `docs/design/THE_DAY_AND_THE_CLOCK.md` |
| Signing, offers, the interview | `docs/design/RECRUITMENT_AND_THE_OFFER.md` **and** `docs/design/THE_JOURNAL_AND_KNOWLEDGE.md` for what an interview teaches the club |
| Staff, how they get things wrong, reports and interpretation | `docs/design/STAFF_AND_FALLIBILITY.md` **and** `docs/design/THE_JOURNAL_AND_KNOWLEDGE.md` |
| Contractors, outsourcing, services, when a role belongs inside the club | `docs/design/CONTRACTORS_AND_SERVICES.md` |
| **Anything in the rally, and whether it looks like volleyball** | `docs/design/VOLLEYBALL_FIDELITY.md` |
| **Who owns a physical fact: contact, launch, flight, the drawn ball** | `docs/design/CONTACT_AND_BALL_FLIGHT.md` |
| The forearm contacts -- reception, dig, emergency dig, coverage | `docs/design/PLATFORM_CONTACT.md` |
| Why the rally simulator is shaped the way it is, and what was tried | `docs/review/RALLY_SIMULATOR_REDESIGN_LOG.md` |
| Club culture, philosophy, what a team believes | `docs/design/TEAM_IDENTITY_AND_PHILOSOPHY.md` |
| Tactics, training, drills, the planner | `docs/design/TACTICS_AND_TRAINING.md` |
| The title screen | `docs/design/TITLE_SCREEN.md` |
| The match centre, the whiteboard | `docs/design/THE_TACTICAL_WHITEBOARD.md` |
| Cogniticons, what a voli is showing | `docs/design/COGNITICONS.md` |
| Anything visual | `docs/design/UI_VISUAL_SYSTEM.md` and `UI_VISUAL_SYSTEM_CONSTRAINTS.md` |
| Setter choice, who swings | `docs/design/SETTER_DECISION.md` |
| Tempo, set height, approach | `docs/design/TEMPO_AND_APPROACH.md` |
| Movement, gait, traversal time | `docs/design/LOCOMOTION_AND_GENERATION.md`, `MOVEMENT_FLUIDITY_DRAFT.md` |
| What the other ten players are doing | `docs/design/OFF_BALL_MOVEMENT.md` |
| Clubs, transfers, why the roster matters | `docs/design/CLUBS_REGIONS_AND_THE_ROSTER_DECISION.md` |
| Traits and what they may touch | `docs/design/TRAITS.md` |
| Scouts, uncertainty, what a report means | `docs/design/SCOUTING.md` |
| The phone, incoming/outgoing calls, information arrival | `docs/design/THE_DESK_AND_THE_PHONE.md` **and** `docs/design/THE_JOURNAL_AND_KNOWLEDGE.md` §§10, 17 |
| The team wheel, functional contribution | `docs/design/TEAM_ATTRIBUTE_WHEEL.md` |
| Accommodations, food, lodging simulation | `docs/design/ACCOMMODATIONS_AND_CARE.md` |
| Housing workspace, inherited property, architects, quotes and construction | `docs/design/HOUSING_WORKSPACE_AND_ARCHITECTURE.md` |
| Who the manager is | `docs/design/CHARACTER_CREATION.md` |
| Regions, principles, what makes a team feel like itself | `docs/design/REGIONAL_IDENTITY_OVER_A_MATCH.md`, `REGIONAL_DIFFERENTIATION_SPEC.md` |
| Ball flight | `docs/design/BALL_LAUNCH_KINEMATICS.md` |
| Player generation, bodies | `docs/design/ATTRIBUTE_FIRST_GENERATION.md`, `BODY_TYPES.md` |
| How a voli stands and dresses -- ready stance, kits | `docs/design/THE_VOLI_BODY.md` |
| Setting, regions, naming | `docs/world/` |
| What is designed but unbuilt | `docs/BACKLOG.md` |

`docs/textbook/` is the reference layer -- `EVIDENCE.md` and
`GLOSSARY.md` are the two worth knowing exist.

## Names

The interface is a desk with objects on it. Use these names in code, comments
and conversation; they are not decorative and the old ones have been renamed
away.

| Object | Screen |
|---|---|
| The journal -- the manager's organized working knowledge of the club and career | `scenes/screens/journal_screen.gd` |
| Training clipboard -- tactics and drills | `scenes/screens/training_screen.gd` |
| The scouting board -- cork, pinned | `scenes/screens/scouting_screen.gd` |
| The planner -- the daily schedule | `scenes/screens/schedule_screen.gd` |
| Match centre | `scenes/screens/match_screen.gd` |
| The housing folder -- the current home, and the one open question about changing it | `scenes/screens/accommodation_screen.gd` |
| The kitchen -- the block and the paste on it | `scenes/screens/kitchen_screen.gd` |
| The desk -- the home state, not a menu | `scenes/screens/desk_screen.gd` |
| The phone -- a call cutting in | `scenes/components/call_intrusion.gd` |

"Career dashboard" and "recruitment" are dead names. A player is a **voli**.

## Conventions

- **Full-screen pages are built on `VolleyballScreenShell`** -- backdrop,
  ribbon, card. A page built from a bare `MarginContainer` gets no background,
  which is invisible in the dark theme and unreadable in the light one.
- **A medium is a whole material, not a border.** `UIStyleSystem` carries a
  `ui_medium` down the tree and each one owns the *substrate, the stock, the
  divisions and the hand* together. Changing only the edge is what made the
  clipboard read as the journal with a different outline.

  | medium | substrate | divisions | who made the marks |
  |---|---|---|---|
  | `sewn` -- the journal | halftone, warm cream, per-patch tint | running stitch | everything, by hand; structured working pages may accumulate player-added tabs, notes and keepsakes without sacrificing readability |
  | `form` -- the clipboard | flat stock, cooler, unscreened | printed hairlines, square corners, faint grid | only the annotation: marker, red pen, highlighter |
  | `drawn` -- default | halftone, pen edge | broad-nib pen | by hand |
  | `board` -- the match centre | melamine, cool, a wiped smear, no screen | marker rules edge to edge; magnets, not borders | all of it, in four markers, minutes ago |
  | `card` -- the housing folder | manila, buff, a fibre fleck one pixel across | a fold and three cut edges -- no border at all | pencil, and only on hover |
  | `pinned` -- the scouting board | no surface at all: separate scraps on cork | none -- air and shadow, never a line | a pin per item, and biro on the slips |

  **`card` was built for scouting and is now housing's.** A folder is a container
  for *one subject*; a board is a surface where things accumulate and relate.
  Scouting is the second -- connections, unsolicited discoveries, a shortlist
  compared against itself -- and housing is emphatically the first. Each metaphor
  had been attached to the system whose information shape it did not fit. See
  `docs/design/THE_DESK_AND_THE_PHONE.md` §0.

  `pinned` shares its cork with the training clipboard, which is the fourth
  chance this codebase has had to make two objects out of one material. The
  separation is structural, not tonal: a clipboard is mostly *sheet* with a
  margin of cork and one steel clamp; the board is mostly *board*, with many
  tilted scraps and a pin each. `UICorkBoard.clamped` is the one flag that
  switches between them, and `UIPinnedSlip`'s header carries the table.

  `card` is the only medium whose texture is the **material** rather than
  something done to it: a halftone is a reproduction, a form and a board are
  manufactured featureless, and manila is unbleached pulp with the fibre still
  in it. It is also the only one with no line around a surface -- see
  `UICreasedEdge`. Its stock multiplier in Mikasa is large (`3.75, 1.275, 0.586`)
  because getting to buff from a blue ground takes most of the blue out, and that
  multiplier tints a `Button`'s own lettering, which is why `_uncolour_text`
  exists. `docs/design/SCOUTING.md` §Medium.

  `board` is drafted but unbuilt; see `docs/design/THE_TACTICAL_WHITEBOARD.md`.
  Its display face is **Yatra One**, not Cherry Bomb One, and it shares exactly
  one property with `form` -- no halftone -- so building it off `MEDIUM_FORM`
  will reproduce the defect in the row above it.

  The title screen is exempt from all of it because it is not an object on the
  desk but the **room the desk is in**. See `docs/design/TITLE_SCREEN.md`.
- **Comments are NOTEs, not prose.** One line, three at the absolute most, never
  a paragraph. State the fact and point at the record:

  ```gdscript
  ## NOTE reads the ball's height, not the passer's body -- CONTACT_HEIGHT_CHAIN.md
  ## NOTE 12% of physical receptions floor -- FD-005
  ```

  The reasoning, the measurement, and the account of what an earlier version got
  wrong belong in `docs/review/`, organised by subject, which is where a reader
  goes looking for them. Keep a number inline only when it is the fact — then
  keep the number and drop the sentence around it.

  **This replaces the previous rule**, which asked comments to explain the
  decision and how it was measured. That was not wrong about the information
  being worth keeping; it was wrong about where it goes. The result was 46,526
  comment lines across the `.gd` files — 28% of every non-blank line, 37% of
  `rally_simulator.gd`, 96% of `rally_feature_flags.gd` — and prose that
  duplicates the review docs almost paragraph for paragraph. A file that is one
  third essay is harder to read, not better documented.
- **Themes are `Mikasa` (dark) and `Molten` (light)** everywhere they are named.
- Godot gotchas that have cost time before: `_`-prefixed parameters mean
  explicitly unused; `%-22s` padding only aligns in a monospace font and this
  interface is not set in one; `MOUSE_FILTER_IGNORE` on children keeps a row one
  click target; a `Control` under a `Container` has its rect recomputed every
  layout pass and will fight a `Tween`.