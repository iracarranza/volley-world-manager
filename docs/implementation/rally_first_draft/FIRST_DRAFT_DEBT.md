# Rally first-draft debt ledger

Owned by the implementation run. Only failures and debt encountered or
deliberately deferred while executing this packet — not a copy of
`OUTSTANDING.md`.

## Entry template

```text
## FD-### — <short name>

Class: F0 / F1 / F2 / F3 / F4 / F5 / F6
Subsystem:
First observed at commit:
Reproduction command / fixture:
Expected semantic invariant:
Observed behavior:
Likely upstream owner:
Blocks later construction: yes / no
Why deferred:
Next diagnostic / repair:
Relevant existing spec/review:
```

---

## FD-001 — WITHDRAWN. The serve leg is published; the census was counting a leg that does not exist

Class: F3 (instrument defect, not engine defect)
Subsystem: `tools/run_action_window_census.gd`
Disposition: **withdrawn on evidence, not repaired**

The entry claimed the serve leg publishes nothing about the other eleven volis
and that presentation therefore invents them. It does not. A rally's first
contact has **no preceding interval** — playback draws a leg as
`event -> next_contact` and reads its targets off `next_contact` — so both
sides' serve-flight movement is published on the RECEPTION event, all twelve of
them, which is the only event where it can be drawn.

The resolver has known this the whole time. `_receive_formation_map`'s own note
records measuring 400 serves of 400 with no preceding flight, and says the map
is published on the reception "because playback draws a leg as `event ->
next_contact`".

So the 3,300 "silent" voli-legs on the SERVE row were an artefact of the census
scoring a leg that does not exist — a threshold measured against the wrong
distribution, committed by the instrument built to find those. The census now
carries a `no leg` column and excludes it.

What was real inside this entry was the receive formation being a *placement* at
coordinates gameplay did not use. That is FD-004, and it is repaired.

---

## FD-002 — attack coverage publishes no phase map

Class: F4
Subsystem: `_resolve_attack_coverage`
Reproduction: `godot --headless --path . --script res://tools/run_action_window_census.gd` — `ATTACK_COVERAGE` reads `published 0, silent 143` over 300 rallies
Disposition: **retained as non-blocking debt, with evidence**

The goal's test is whether this "still represents missing authoritative off-ball
state / actor-state substitution under packet first-draft criteria". It does not,
and the evidence is specific rather than a shrug:

- **No actor-state substitution.** Nothing resets or defaults a voli at the
  coverage boundary. `live_positions` carries across it, recovery debt is
  published on the coverage contact like every other, and C1's gate in
  `run_continuous_action_probe.gd` passes (273 contacts in 400 rallies carrying
  debt the next leg still owes).
- **No required M7 action is made impossible.** M7's own seven-item closure
  criterion is certified in full; coverage is not among the actions it names, and
  the actions it does name all overlap their preceding ball phases.
- **The interval is the block deflection**, 0.22–0.38 s measured in the D0 walk,
  on 13 events per 300 rallies.
- **Closing it would not close the class.** The remaining silence is 5,125
  voli-legs across five legs; coverage is 143 of them, 2.8%. This is one member
  of the FD-003 family, not a separable defect.

Its cost is presentation fidelity for a third of a second on a rare leg, which
the packet's §10 lists by name as permitted in a complete first draft.

Next repair: publish `_cover_phase_map` on the coverage event with the keep-alive
flight as the window — the same helper the block and transition legs already use.
Grouped with FD-003 rather than taken alone, because `_cover_phase_map` calls
`_reached_point`, so it moves volis and needs measuring with its siblings rather
than as three overlapping single-change measurements.

---

## FD-003 — presentation draws off-ball movement the resolver did not publish

Class: F4 — and explicitly permitted in a complete first draft
Subsystem: `scenes/components/tactical_court.gd` (`_support_target_for_side`)
Reproduction: as above — `volis presentation must invent: 5125 of 14736 (34.8%)`
Disposition: **open, non-blocking**

**The number was overstated and is corrected here.** This entry previously read
46.4%, which included FD-001's phantom serve leg. The measured figure with that
artefact removed is **34.8%**.

The packet's §10 permits a complete first draft to contain "presentation lag
behind newly authoritative state". This is exactly that: the simulation now
publishes traversal times, arrival windows, unified receiver geometry, per-contact
body positions and leg starts, and presentation has not caught up to any of it.

And the boundary is one-way, which is the part that matters for the completion
criterion. Verified rather than assumed: no script under `scripts/simulation`,
`scripts/models` or `scripts/managers` loads anything under `scenes/`, and
presentation never writes resolver state — `match_court_3d.live_positions` is the
court's own drawing copy, not the resolver's. Deleting `_support_target_for_side`
outright would change no gameplay number in any rally; it would change only what
is drawn. Presentation reconstructs no gameplay truth because it cannot.

Next repair: publish the acting side's off-ball map on the SET, ATTACK, BLOCK,
DIG and coverage legs, using `_establish_shape` and the existing phase maps, and
measure the five together. Then narrow the fallback to a genuine no-information
case and make it read as a hold rather than a journey.

---

## FD-004 — CLOSED. One receiver geometry, seeded before the serve

Class: F1 (two answers to one physical question) — repaired
Subsystem: `_receive_formation_map`, `_initial_home_positions`, `_initial_opponent_positions`
Disposition: **closed and certified**

The reception claim built `reception_origins` from `live_positions`, seeded from
the rotation grid or the plan's zone, while `_receive_formation_map` separately
published the shape the six actually take up. Gameplay believed one, the drawing
showed the other, and `result.initial_home_positions` — what `match_court_3d`
spawns actors at — was the gameplay one.

The formation is now seeded into `live_positions` at rally initialization, so it
is the spawn position, the claim's origin and the start of every later traversal
at once. The reception event publishes `_lineup_live_shape` — the volis' actual
state — instead of recomputing a second copy.

`tools/run_receive_geometry_probe.gd`, 500 rallies, 422 serve receptions:

```
bystanders that moved from spawn        0 of 2,110
worst displacement               0.000000 court units
receivers that travelled              411, mean 0.1367
serve -> reception lineage breaks       0
receptions stamped before the serve     0
```

A second home/opponent drift was found while tracing it and repaired in the same
pass: `_initial_home_positions` honoured a serve-receive zone whether or not it
was `enabled`, where `_initial_opponent_positions` had always checked.

Cost, measured and not fitted: dig 0.393 → 0.407, kill 0.659 → 0.611, contacts
4.796 → 4.827, every governed band still holding, reception quality unchanged at
0.434 to three decimals.

---

## FD-005 — contacts per rally and kill rate sit outside their advisory bands

Class: F5
Subsystem: whole-engine outcome mix
First observed at: M4 reception promotion (`9e2b55d`), unchanged by this run
Reproduction: `godot --headless --path . --script res://tools/run_rally_balance_probe.gd`
Observed: contacts per rally 4.796 against an advisory "above 6.0"; kill rate 0.659 against an advisory 0.45–0.50; ace rate 0.010 against 0.05–0.09
Likely upstream owner: reception outcome mix — roughly 12% of physical receptions floor, which was the recorded and deliberately unfitted consequence of M4's promotion
Blocks later construction: no
Why deferred: these are **advisory targets, not acceptance bounds**, and were recorded as observations at promotion. The bands the probe does gate on — dig rate 0.35–0.55, stuff 0.08–0.14, serve error 0.12–0.20 — are all inside. Fitting the architecture to move them is exactly what the packet forbids.
Next diagnostic: task #140, "Is 12% the right price for a shanked serve-receive?", which is a volleyball question and not a calibration one

---

## FD-006 — CLOSED. The ball's height at the moment it is touched has an owner in every family

Class: F4 — presentation drawing a quantity nobody has assigned
Subsystem: `BallPresentation.display_trajectory`, and `CONTACT_AND_BALL_FLIGHT.md` §5
Reproduction: `godot --headless --path . --script res://tools/run_playback_continuity_probe.gd`
Disposition: **closed; the residual is a different defect and is FD-009**

A drawn leg arrives at one height and the next departs from another, so the ball
jumps at the contact: 378 of 835 legs over 180 rallies, worst 3.227 m at
attack-to-block, mean 1.2--1.9 m at the block and 0.34--0.39 m at every
serve-to-reception.

**It is not two authorities for one fact**, which is the reading that first
suggested itself. The resolver publishes `end_height_meters` on every trajectory
and presentation computes its own, but those are *defined* to be different
quantities -- `rally_simulator.gd:1394` says `end_height_meters` "is not read as
this flight's endpoint. `BallFlight.from_trajectory` reads it as the height of
the **next contact**", and measurement agrees: `|published - body|` is 0.033 m on
the serve. So the published field is already the body's number, and presentation
is computing the one quantity with no owner at all -- where the ball actually is
when it is struck. `CONTACT_AND_BALL_FLIGHT.md` §5, *Realized segment*, is the
item that owns it and is marked TARGET.

One cause was separable and is fixed: the 0.08 s drawing floor was being used as
the integration window for a struck ball's far end. See
`docs/review/M8_VISUAL_CONTINUITY.md`.

**Narrowed: the block is out of it, and the remaining scope is exact.** One
family's contact height did have an owner all along -- the resolver reads the
swing's own flight at the tape to decide whether the wall can reach it -- and was
being consumed inside `_block_contact` and dropped at the promotion seam, with
playback drawing the ball at the blocker's *jumping reach* instead. That is now
published and read: every block leg where a hand met the ball is seamless on both
sides, 72 of 72. The 60 that still score a break are blocks the ball went **past**,
where the leg into the event does not end at the event -- the probe is scoring a
transition that is not a seam, not a contact that fails to line up. Row means fell
from 1.914 to 1.567 m (home) and 1.217 to 1.028 m (opponent); total seam jumps
378 to 309, and the worst is no longer a block. See
`docs/review/BLOCK_REALISED_CONTACT.md`.

**Narrowed again: the set and the attack are out of it too, and the residual is
now one family and one unwired function.** A census of every family
(`tools/run_contact_authority_census.gd`) found the seam was a *chain* with one
break: `_set_arc` is handed a release height and a hitter contact height, solves
the flight's duration between them, and returned neither -- so every set
published `BallTrajectory`'s 1.0 m default at both ends and every family
downstream read a body proxy for want of a number that was in scope upstream.
Returning them closed the attack outright, both sides: `body-proxy` with 273 of
273 legs breaking at a mean 2.09 m, to **authoritative** with none at 0.02 m. A
forward pass then copies each resolved far end onto the next contact, and SET/home
went 53 breaks to 0. Total drawn seam jumps 378 to 246. Outcome mix unchanged to
three decimals on every figure. See `docs/review/CONTACT_HEIGHT_CHAIN.md`.

**And the reception closed too**, once two readings were corrected. The serve's
published flight is already terminated at the pass -- its end time and the
reception's own stamp agree, so evaluating it at its far end *is* evaluating it
at the contact -- and a flight that resolves its start and publishes its launch
can state that far end by integrating across its own duration. RECEPTION went
**144 breaks to 0** on both sides; total drawn seams 378 to **184**.

**The residual is one thing and it is not a seam.** Closing the reception exposed
a 0.29--0.42 m disagreement that appears as a set seam, 124 legs: the reception's
outgoing arc is solved from the *platform's* height, so once its contact says the
ball's height instead, the arc departs from somewhere the contact no longer
claims. That was always in the record -- the platform proxy was wrong at both
ends at once and the two errors cancelled in the drawing, so nothing could see
either. Writing the contact height back onto the flight does not fix it: the
launch was solved from the start height it shipped with, so overwriting only the
height leaves a flight disagreeing with its own length.

Closing it means re-solving the pass from the ball's height rather than the
body's, and that is not free: `pass_apex_meters` feeds the set's release clamp,
so moving the pass's launch moves what the setter may do with it and therefore
moves rally outcomes. Simulation work with a measurable cost, wanting its own
before-and-after rather than a guess folded into a seam pass.

Two smaller items stay open: the `SET_DECISION` path's 114 legs publish no
outgoing flight at all, and 60 block legs still score a "seam" that is not one --
the ball went past the wall, so the leg into the event does not end at it.

Blocks later construction: no.

### Closed

Every contact family now answers to a published ball state rather than a body
measurement, and the census says so per family
(`tools/run_contact_authority_census.gd`, both serving sides):

```
ATTACK      both sides   authoritative              0 breaks
RECEPTION   home         authoritative              0 breaks
            opponent     0.002 m mean               2 of 125
BLOCK       both sides   authoritative by own proof 0 breaks
SET         home         0.005 m mean               7 of 139
```

Three repairs, no authored magnitude in any of them: `_set_arc` returns the two
heights it solves a flight between; a forward pass carries each resolved far end
onto the next contact; and the shared platform resolver reads the incoming
flight's height instead of the passer's own platform. Drawn seams **378 to 102**.

The last of those does move rally outcomes, which is why it was measured rather
than assumed. Every **gated** band holds -- dig 0.416 (0.35--0.55), stuff 0.106
(0.08--0.14), serve error 0.181 (0.12--0.20). Advisory figures moved and are
recorded as observations: kill 0.610 to 0.630, contacts per rally 4.807 to 4.814,
block touch 0.818 to 0.830, and **swing balance 0.932 to 0.888**, which is the
one worth watching -- it is a home/opponent symmetry indicator and it moved away
from 1.00. See `docs/review/CONTACT_HEIGHT_CHAIN.md`.

---

## FD-009 — the opponent's set disagrees with the pass that fed it, and the home side does not

Class: F6 (home/opponent asymmetry)
Subsystem: the opponent second-contact path
Reproduction: `godot --headless --path . --script res://tools/run_contact_authority_census.gd` -- `SET/opponent` reads 73 of 139 legs breaking at a 0.161 m mean, worst 1.014, against `SET/home` at 7 of 139 and a 0.005 m mean
Disposition: **open, non-blocking**

Split out of FD-006 rather than keeping that entry alive, because it is a
different defect: the ball's height at the set *has* an owner on both sides now,
and one side's two answers disagree. That is an asymmetry, and this repository
has found and repaired three of them in this packet alone.

**Where it is not**: both sides call the same `_reception_pass_result` with
symmetric arguments in the same order -- checked, not assumed -- so the pass
itself is not forked. The opponent path carries a `SET_DECISION` event the home
path does not (114 of them per 300 rallies, publishing no outgoing flight),
which is the most visible structural difference between the two and the first
place to look.

Blocks later construction: no.

---

## FD-007 — CLOSED. A pose asserts contact only when the ball was touched

Class: F4
Subsystem: `match_screen._apply_contact_poses`
Reproduction: `godot --headless --path . --script res://tools/probe_failed_contact_semantics.gd` -- 59 blocks and 47 digs per 180 rallies fail without publishing a ball
Disposition: **open, non-blocking**

The next contact's actor is posed through a wind-up-to-contact with no test for
whether the contact occurred, so a block that never touched the ball and a dig
that never reached it are both drawn playing it.

Worth stating precisely, because the obvious fix is wrong: a defender who cannot
reach still lunges, so suppressing the pose would replace one false statement
with another. The honest repair is a distinct reaching-and-missing pose, which is
animation work rather than authority work -- and note that `_build_movement_plan`
already gets the *position* half right, driving a failed receiver, digger or
coverer to their `movement_target` rather than onto the ball they never reached.

**`success` is not the test.** Measured: all 35 failed serves, 4 failed
receptions, 3 failed sets and 14 failed attacks still publish a ball -- those are
service errors, shanks and swings that went out, every one of them touched. Only
the block and the dig fail by not touching. The authoritative test is B0's: did
the contact publish a ball.

**The block half was never the pose, and a separate defect was hiding under it.**
`match_screen._carry_trajectory` already had the right test -- it refuses to draw
a deflection for a block whose `block_contact_kind` is empty -- and that key was
published on the ATTACK event and not on the BLOCK event, 0 of 236 measured. So
the guard read an absent key, found the empty string, and suppressed the carry on
*every* block including the 97 that touched the ball. Repaired by publishing the
key where it is read; see `docs/review/BLOCK_REALISED_CONTACT.md`.

**And the pose test was wrong in the other direction, which is now repaired.**
`_contact_posture` reached for the miss pose on `not event.success` -- the
contact's *outcome*, not whether the ball was met -- so every service error,
shank and swing that went out was drawn reaching for a ball it had just struck.
It now uses B0's test: did this contact publish a ball. The block never reaches
that function at all; it poses through `_pose_block_wall`, which draws the jump
the blocker actually made, so a beaten wall already reaches and misses without
the ball snapping to its hands.

### Closed, and the scope stated exactly

The entry asked for three things and all three now hold, certified by
`_test_a_miss_pose_means_the_ball_was_not_touched` and
`_test_a_beaten_block_reaches_without_the_ball_arriving`:

- **A contact pose iff a contact happened.** The predicate is B0's -- did this
  contact publish a ball -- so a shank and a service error keep their contact
  pose (they struck it) and a dig that never arrived takes the miss pose.
- **A beaten block visibly reaches.** It poses through `_pose_block_wall` from
  `block_jump_timing`, an entry per body that actually left the floor. Not
  suppressed: the blocker did go up, and hiding that would replace one false
  statement with another.
- **The ball never snaps to the hands.** `contact_height` returned the blocker's
  jumping reach for every block, so a swing that cleared a wall was drawn
  arriving in the hands it had just beaten. It reads the published ball height
  now, and the gate asserts the sample contains balls provably above every hand
  in the wall -- so the check is not vacuous on a population where the ball
  happened to sit at hand height anyway.

**One thing is deliberately *not* counted as residual here.** A reach that
misses and a reach that digs still share the `reaching` posture geometry, so the
ball's absence reads in the ball rather than in the body. That is the note
`_contact_posture` has carried since before this entry existed -- "not the whole
of 13a ... Logged" -- and it is animation authoring, not contact authority. It
belongs to the backlog it was already in, not to this entry, and folding it in
here would keep an authority defect open for a drawing refinement.

---

## FD-008 — the serve-receive leg is the one leg that never got off-ball movement

Class: F4
Subsystem: `_receive_formation_map`, and the five volis it publishes as stationary
Reproduction: `godot --headless --path . --script res://tools/probe_serve_receive_offball.gd`
Disposition: **open, non-blocking**

On the receiving side of a serve, the receiver travels and nobody else does at
all. 113 receptions, both serving sides:

```
role          legs    moved   moved %     mean m  worst m
receiver       113      112     99.1%      1.524    4.072
setter          56        0      0.0%      0.000    0.000
other          509        0      0.0%      0.000    0.000
serving side   678      452     66.7%      0.862    3.944
```

**This is not FD-003 and not a missing capability.** FD-003 is presentation
inventing movement the resolver was silent about; here the resolver is not
silent — it publishes all six receiving volis on the reception event, and
publishes five of them as "where you already are". Nor is the machinery absent:
C2 gives the setter a transition head start after a dig, C3 walks the hitter
into an approach during the set, C4 closes the blocker during the set flight,
C5 establishes the floor shape via `_establish_shape`, and
`setter_release_target` exists and is used. The serve leg calls none of it.
FD-004 seeds the formation at rally start, the claimant travels, and the other
five are copied out of `live_positions` unchanged.

The serving-side row is the control that makes it read as a defect rather than
a property of first contact: on the *same* leg, over the *same* interval, the
serving side moves 4 of 6 — because those volis are being walked into a block
and defence shape by the code above. Both sides had the same information and
the same window.

What volleyball does over that window and the resolver does not: the setter
releases toward the net before the ball is struck, one or two volis close on
the passer to support, and the front-row hitters open toward their runways.

Blocks later construction: no. Next repair: give the reception event's
receiving-side map the same treatment the other four legs have — the setter via
`setter_release_target`, the non-claiming defenders via `_establish_shape`, the
front row via the C3 approach opening — and measure the five together rather
than one at a time, since they all call `_reached_point` and move volis.

---

## Post-draft clustering

1. ball/contact authority — *empty; B0/B6 closed every edge by launch identity*
2. causality/timing — *empty; the B4 repair closed the one violation found*
3. movement/actor continuity — FD-008, the serve-receive leg publishing five of
   six receiving volis as stationary. Distinct from FD-002/003 in cluster 8:
   those are silence, this is a published fact that says "nobody moved"
4. responsibility/selection — *empty*
5. attack/block interaction — *empty*
6. home/opponent asymmetry — FD-009, the opponent's set disagreeing with the pass
   that fed it (73 of 139 legs against the home side's 7). *Previously empty;
   three drifts found and all three repaired — the block's stale swing, the receive zone's `enabled` check, and the opponent dig writing its reach after the event that reads it (`docs/review/BODY_CONTACT_ENDPOINT.md`)*
7. tactical wiring — *not yet audited (M9)*
8. presentation/reporting — FD-002, FD-003 (one family). **FD-006 and FD-007 are
   closed**: the ball's height at a contact has an owner in every family and a
   pose asserts contact only when the ball was touched. What is left in this
   cluster is the original pair — the resolver being *silent* about off-ball
   movement — which is a different thing from playback drawing a fact nobody
   published
9. calibration/balance — FD-005
