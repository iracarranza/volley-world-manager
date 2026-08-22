# 05 — M7 continuous per-voli actions and whole-engine integration

M7 is the largest remaining construction step. Its purpose is **not** to make playback smoother. Its purpose is to make player state causally continuous so the next contact is made by the body that actually spent the preceding time moving, preparing, recovering or waiting.

The governing sentence is:

> The ball has contact-to-contact phases. Athletes act continuously across them.

No global rewrite or frame-by-frame physics engine is required. Preserve the existing rally clock, movement authority, live position/velocity/facing/recovery carriers and phase-state builder. Extend them only enough that action timing survives ball-event boundaries.

## 1. M7 dependency graph

```text
C0  Current action-window audit
 ↓
C1  Previous contacter clears / recovery remains causal
 ↓
C2  Setter transition overlaps first/transition ball
 ↓
C3  Hitter release + approach overlaps set flight
 ↓
C4  Block read/commit/close overlaps pre-attack time
 ↓
C5  Floor defence establishes before swing
 ↓
C6  Early arrivals finish movement and wait
 ↓
C7  Phase boundaries sample persistent actor/action state
 ↓
════════════════════════ M7 FIRST-DRAFT COMPLETE
 ↓
D0  Canonical whole-rally integration walk
D1  Superseded event-window authority cleanup
D2  History/presentation consumption audit
D3  First-draft construction checkpoint
```

---

# C0 — Current action-window audit

Before adding state, map what currently begins/ends at each ball event.

For every ordinary leg record:

```text
SERVE → RECEPTION
RECEPTION → SET
SET → ATTACK
ATTACK → BLOCK / DEFENCE / TERMINAL
BLOCK → COVERAGE / DEFENCE / TERMINAL
DIG/COVERAGE → SET
```

For all twelve volis identify:

- current position at leg start;
- current velocity/facing/recovery;
- target/intention already computed for the leg;
- when that intention becomes knowable;
- movement start time currently used;
- traversal time from the movement authority;
- whether arrival is before or after ball/contact time;
- what state is thrown away at the next phase build.

Classify each current target as:

- **react to ball** (`chase`, `second_contact`);
- **prepare next action** (`release`, `approach`, `block_close`, `defensive_base`);
- **support** (`cover`, `base`, `support`);
- **recover/clear**.

Do not create new target geometry until the existing phase maps/assignments have been exhausted.

Done when the implementation agent can state, for each canonical leg, why every on-court player is or is not moving.

---

# C1 — Previous contacter clears and recovery remains causal

## Purpose

The player who just contacted the ball must not remain a fresh, available body at the action point merely because the next ball phase began.

## Existing authority to preserve

`player_recovery`, carried body state, `recovery_until`/ready-at, live position/velocity and facing already survive phase rebuilding. `ACTOR_CONTINUITY.md` certifies that compromised state reaches the contact envelope.

## Target

After contact, the actor's next state follows from:

```text
contact consequence
+ existing recovery debt
+ role/phase intention
+ available elapsed time
→ clearing/recovery position and body state
```

The previous contacter yields when volleyball responsibility says they should yield. They do not remain the preferred claimant merely because they are closest to their own contact point.

## Required transformations

1. Identify all next-leg claimant/availability paths that can reselect the previous contacter.
2. Ensure existing recovery/ownership policy is consulted before role/tie-break scoring.
3. Publish/use a clearing/recovery intention where the existing assignment policy already implies one.
4. Advance the actor physically during the next leg using the same movement model as everyone else.
5. Preserve contact-specific body consequences; do not replace them with a generic cooldown.

## Deferred

Do not tune obstruction clearance while this work changes who clears. Re-measure obstruction after clearing exists.

---

# C2 — Setter transition overlaps the preceding ball

## Existing first-ball behavior

The first-ball setter already has a head start represented as distance physically covered during the preceding serve flight. Preserve that semantic.

## Target

The setter's movement is two causally distinct pieces:

```text
before reception/contact is realised:
  release toward expected setter-release target using information available then

after the physical ball exists/interception is knowable:
  adjust remaining movement against the realised second-contact opportunity
```

The setter must not know the future pass endpoint at release time.

## First-ball path

After A1 is complete:

- run initial release movement toward plan/release target;
- carry resulting position/velocity/facing into the reception contact time;
- resolve physical reception/M5;
- determine actual second-contact actor and actual intercept state;
- if the setter is the actual candidate, resolve remaining leg from their current physical state;
- if another player intercepts, the setter's prior release still happened and becomes their starting state for the next action.

## Transition-set path

The current transition set lacks equivalent head start and has historical hardcoded timing debt. Replace a fixed window only where existing ball flight / rally-clock state supplies the real available time.

Do not invent a new transition-set duration.

## Done when

A setter chase is visibly and numerically underway during the preceding ball flight, and the second-contact resolver samples the setter's resulting state rather than calculating the whole journey after the pass has already arrived.

---

# C3 — Hitter release and approach overlap the set flight

## Purpose

Attack contact may remain event-based; the **approach cannot begin at the attack event**.

## Existing inputs to reuse

Use existing:

- rotation/role;
- fallback/attack assignment;
- approach start position;
- approach mechanics;
- set options/tempo/target decision;
- movement/locomotion authority.

## Target timing

At minimum:

1. eligible attackers release toward their approach starts before or around setter contact according to information already available from the offensive structure;
2. when the set is selected/released, the chosen hitter's approach continues against the actual set timing/target;
3. non-chosen attackers stop/redirect into existing cover/transition responsibilities rather than completing a fake attack;
4. attack contact samples the hitter's actual resulting approach/body state.

Do not grant the hitter knowledge of the final set before the setter decision exists.

The correct abstraction is overlapping **action intervals**, not backdating the ATTACK event.

## Required checks

Construct at least:

- quick/middle option;
- ordinary pin/high option;
- compromised/off-system set;
- hitter who arrives early;
- hitter who cannot complete the approach.

The chosen shot must reflect the body that actually arrived; do not stretch approach time or snap the hitter to contact.

---

# C4 — Blockers read, commit and close before attack contact

## Purpose

A block must be the consequence of pre-contact recognition and movement, not a wall materialized when the attacker touches the ball.

## Existing authority to reuse

Preserve existing:

- defensive plan;
- primary/assist blocker responsibility;
- read/commit signals;
- existing close/traversal movement;
- block geometry/interaction;
- block recovery/body-state consequences.

## Target sequence

```text
pass/set cues available
→ blocker recognition / commitment state
→ close movement begins
→ set flight continues
→ blocker plants/jumps according to existing block timing
→ attack contact intersects actual wall/hand state
```

Recognition may differ by blocker. Two blockers on one wall do not need identical recognition moments.

## Required transformations

1. Make the pre-attack movement interval part of each blocker's persistent action state.
2. Advance blocker position/facing before attack contact.
3. Ensure block contact uses that realised state.
4. Preserve late blockers as visibly/physically late instead of teleported low-quality blockers.
5. Carry landing recovery into the next leg through already-certified continuity.

Do not reopen block outcome bands or hand physics merely because movement timing changes their observed frequency.

---

# C5 — Floor defence establishes before the swing

## Purpose

Defenders should defend volleyball space before the ball is struck. A dig claimant may then react to the actual flight from that established base.

## Existing inputs to reuse

- defensive assignments/zones;
- line/cross/short relationships;
- phase intentions / base targets;
- attack coverage responsibility;
- actual blocker/wall state where defensive plan already uses it;
- `_reached_point` / movement authority.

## Target sequence

```text
opponent offensive development
→ defensive plan/base intention
→ defenders move/establish
→ attack contact creates one launch
→ read/reaction from actual established positions
→ claimant/interception/contact
```

The attack launch may change who ultimately owns the ball, but it does not create the defender's entire pre-swing position from scratch.

## Required transformations

1. Publish/persist base/coverage intentions early enough to act before attack contact.
2. Advance every defender using available physical time.
3. At attack launch, compute read/reaction from actual positions.
4. Let failed/partial establishment remain partial; do not snap to diagram positions.

Do not buff dig success to compensate for defenders who were previously positioned late. Position the bodies first; re-measure later.

---

# C6 — Early arrivals finish and wait

## Purpose

The current phase/window architecture can make an actor who arrives early move slowly enough to fill the entire ball flight. That is physically backwards.

## Rule

```text
movement traversal duration < available window
→ actor completes traversal at traversal end
→ actor remains at target / enters appropriate ready state for remaining slack
```

Do not stretch traversal to the ball-contact time.

## Required transformations

- distinguish **available window** from **actual traversal duration**;
- preserve arrival timestamp;
- preserve position after arrival;
- allow standing/ready/waiting body state for the remaining interval without inventing a new movement path;
- ensure playback consumes the same timing rather than re-expanding the movement.

This rule applies to setter release, hitter approach staging, blocker close, defensive establishment and other ordinary movement, not only SET.

`waiting` as a UI/cognition label remains a separate presentation issue; the simulation fact required here is simply that the actor arrived and did not keep traversing.

---

# C7 — Phase boundaries sample persistent actor/action state

## Purpose

Make the current phase-state rebuilding compatible with M7 without a wholesale rally-state rewrite.

## Minimal semantic requirement

At any contact timestamp, each on-court player has one current physical/action state derived from the prior state and elapsed actions.

The implementation may represent this with existing dictionaries + movement/action records, scheduled segments, or another local structure. It does **not** need a dense continuous simulation if state at required timestamps is derivable without contradiction.

Whatever representation is chosen must carry enough to answer:

- where is the player now?
- what velocity/movement form are they in?
- what are they trying to do?
- when did that action begin?
- have they arrived?
- what recovery/body state are they in?
- what facing did prior established movement leave them with?

## Phase build rule

A fresh `RallyState` may still be built for a new contact phase, but its actors must be seeded from the **current per-rally actor truth**, not from formation/default state when newer truth exists.

## Event publication

Events/history may publish useful snapshots/intentions for playback and diagnostics, but the event record is not itself the persistent actor authority.

### M7 done when

Across the canonical side-out:

- previous contacter clears/recovery persists;
- setter movement begins before first-ball second contact;
- hitter approach begins before attack contact;
- blockers move/prepare before attack contact;
- floor defenders establish before attack contact;
- early arrivals wait rather than time-stretch;
- next-phase feasibility reads the resulting actor states.

---

# D0 — Canonical whole-rally integration walk

After M7, walk a deterministic ordinary side-out end-to-end without trying to tune outcomes.

Trace:

```text
medium float serve
→ receive formation / setter release
→ physical reception
→ actual second contact
→ set
→ multiple attackers releasing / chosen approach
→ block read/close
→ defensive base
→ attack
→ block/dig/terminal
→ transition if playable
```

At every boundary record:

- authoritative incoming ball id/state;
- actor positions/body states immediately before contact;
- selected intent;
- actual contact actor/time/position/height;
- outgoing launch id/state;
- realised segment;
- next action intervals already in progress.

The walk is diagnostic. It is not required to produce a particular winner.

---

# D1 — Superseded event-window authority cleanup

Search for logic whose semantics are effectively:

```text
new ball event begins
→ reset/recompute complete player action for that event
```

If M7 now supplies persistent state, remove or narrow such resets so they only initialize genuinely new information.

Keep event boundaries for ball/contact classification; remove their accidental authority over athlete lifetime.

---

# D2 — History and presentation consumption audit

Once continuous actor state exists, expose enough authoritative state for playback/history to draw it.

Requirements:

- movement plans use actual start/end/traversal times;
- early arrivals are not stretched;
- off-ball movement is drawn only when resolver state supplies it;
- presentation does not interpolate a player to an endpoint they did not reach;
- debug/history labels may describe intention and realised action separately;
- cognition can later use persistent intention state without becoming its authority.

Do not spend the first-draft pass on pose polish, cogniticon coalescing, block-hand readability or other M10 work unless a missing presentation field prevents validation of the simulation.

---

# D3 — First-draft construction checkpoint

Construction is complete when:

1. M4 production physical reception is closed.
2. M6 authority audit/cleanup is closed.
3. M7 canonical overlapping action state is implemented.
4. Ordinary rallies run from serve to terminal without intentional legacy physical authority.
5. Canonical transition after a playable defence uses realised state.
6. Full suite can run even if some non-authority assertions fail.
7. M8/M9 probes can now evaluate the complete architecture.
8. Deferred defects are in the debt ledger rather than hidden.

At this point stop adding architecture and begin the post-draft certification/repair cycle in `07_CERTIFICATION_MATRIX.md`.
