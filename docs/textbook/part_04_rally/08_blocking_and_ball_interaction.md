# 08 — Blocking and Ball Interaction

Status: **VERIFIED STRUCTURAL FAMILY / FUTURE CONTINUATION CONSISTENCY OPEN**

Blocking is unusual because a block is an **interaction with an opponent's attack**, not an ordinary team contact in the three-contact count.

That changes both legality and continuation semantics.

## Attack → block is an interaction

A simplified causal view:

```text
attack launch/contact course
+ blocker positions/reach/timing/intent
→ block interaction
→ resulting ball
→ terminal OR playable continuation
```

The blocker is not simply “the next recipient.” The block changes the attacking ball based on a contested physical situation.

## Block touches do not consume a team contact

Indoor volleyball permits a block touch without counting it as one of the blocking team's three contacts, and the blocker may make the next team contact.

That means future fully consistent continuation must be able to represent:

```text
attack
→ block touch
→ ball remains on blocking side
→ blocker or teammate takes contact #1
```

without treating the block itself as contact #1.

## Existing block family is structurally certified

The current block chain has already undergone extensive shadow/coordination/rollout work and is treated as a certified interaction absent controlled proof of an authority failure.

That does not mean every nonterminal block continuation or visual pose is final. It means new work should reuse the block's established physical/decision machinery rather than casually replacing it.

## Blocking has perception and coordination

A blocker acts from incomplete information before attack truth is known.

Historical shadow-block work established a useful architecture:

```text
setter/hitter cues available to blocker
→ individual read/commitment
→ teammate-visible coordination
→ block roles/lanes
→ resolve against actual attack afterward
```

This avoids blockers receiving the final attack target before they commit.

Part V explains the migration history; the key current lesson is the information boundary.

## Home wall formation and compounding state

A previous defect applied setter-pull/home-wall transformation more than once during reformation, causing the wall geometry to drift.

The fix recorded whether the pull had already been applied rather than retuning block outcomes.

This is a useful state lesson:

> if a transformation should happen once, model its application state; do not compensate for repeated application with a smaller coefficient.

## Block result labels versus resulting ball

Labels such as:

- stuff;
- touch;
- tool;
- recycle;

can be useful descriptions.

But a nonterminal label should not automatically guarantee which teammate recovers the ball.

M6's consistency work should increasingly interpret a playable deflection as a new physical ball situation that ordinary responsibility/action systems solve.

## Block coverage is not floor defence

The event-vocabulary audit split `ATTACK_COVERAGE` from `DIG` because these situations differ:

```text
floor defence
→ defending opponent's attack

attack coverage
→ attacking team recovers ball after its own hitter is blocked
```

They may both involve platform-like contacts, but their responsibility/tactical context is not identical.

This distinction is especially relevant to M4 coverage selection.

## Poses versus physics

The project contains block-pose work such as arm number, reach, timing, possible future course-change/spread/drop-arm presentation.

The rendered hands should reflect real block state, but pose code must not decide the block outcome.

```text
block state/interaction
→ pose parameters
→ renderer
```

## Joust is not ordinary block resolution

A future joust involves simultaneous opposing contact at the net. It should not be forced into “attack first, then block second” if both bodies truly interact with the ball together.

That is why joust authority belongs in M6's cross-contact interaction audit rather than being implemented as an overpass special case.

## Safe extension: playable block deflection

When wiring a block deflection into free-flight authority:

1. preserve the attack/contact state that produced the deflection;
2. create one resulting ball state/launch;
3. do not increment team contact count for the block touch;
4. expose that ball to ordinary legal/physical claimant logic;
5. permit the blocker to be the next claimant if available;
6. keep terminal classifications downstream of the ball/interception result.

## Reading exercise

Find the path from an attack into the current block resolver and then into floor defence/coverage.

Mark:

- attack truth;
- blocker decision/preparation data;
- block interaction result;
- where event labels are assigned;
- where a playable ball is or is not yet fully authoritative.

## Source trail

- `scripts/simulation/rally_simulator.gd`
- block/geometry systems under `scripts/simulation/`
- `scenes/components/block_painter.gd`
- `docs/review/HOME_WALL_FORMATION.md`
- historical block Gate 44–49 reviews/calibrations
- `docs/design/RALLY_ACTION_SPACE.md`

Next: the active M4 migration—one shared physical model for reception, digs and coverage platform contacts.