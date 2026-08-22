# 07 — Serve, Set, and Attack

Status: **VERIFIED / CERTIFIED FAMILIES, NOT FROZEN FOREVER**

Serve, set and attack are useful reference contact families because their forward causal chains have already been audited more deeply than platform play.

The project rule is:

> do not reopen a certified family merely because a nearby downstream symptom appears; require controlled evidence that the family's authority boundary is actually broken.

## Shared causal shape

Although the details differ, these contacts increasingly fit:

```text
player/tactical intent
+ ball/body state
→ feasible action/contact
→ execution
→ outgoing launch/trajectory
→ downstream interaction
```

They should not be modeled as “choose GOOD/BAD result, then draw a plausible ball.”

## Serve

A serve begins from a controlled possession state, so there is no incoming ball to absorb. Serve style/attributes/tactical target influence the chosen contact and launch.

Current ball timing uses force/geometry-derived launch relationships rather than a table that directly assigns a duration by outcome.

Relevant player data includes several distinct serve ratings—power, technique, placement, consistency, aggression, variation—and a primary serve style/proficiency profile.

The important modeling distinction is:

```text
serve style / risk / placement intention
→ attempted launch

execution
→ realized launch

flight
→ reception situation
```

not “ace chance” as the authoritative object.

## Set

A set is both a physical contact and a tactical distribution decision.

Current structure includes:

- who can make second contact (including emergency non-setter paths);
- setter capability/read/arrival;
- target/hitter/tempo choice;
- standing versus jump-set posture in relevant paths;
- outgoing set flight;
- hitter preparation/approach downstream.

The current `SET` machinery still contains **second-contact assumptions**. That is why an overhead first contact cannot simply be labeled `SET` during overpass work.

Generalizing “set contact form” across contact numbers is future M6 work, not permission to bypass those assumptions today.

## Non-setter second contacts already exist

The simulator can choose emergency second-contact players when the designated setter is not the honest claimant.

So “emergency setter” is not a future concept in itself. The newer M5 problem was that endpoint-based ball handling could still miss an en-route interception; free-flight authority addresses that physical question.

## Attack preparation

Attack is not only the instant of hand-ball contact. `ApproachMechanicsSystem` represents preparation/run-up/takeoff relationships that affect attack availability and execution.

This is an example of attributes affecting **how an action becomes feasible** rather than only multiplying its final quality.

Different roles can have different tactical approach demands without requiring different laws of motion.

## Geometric attack resolution

The attack chain uses current court/contact geometry, blockers, defenders, player attributes, approach state and tactical information to resolve a swing.

`OverpassActionSystem.execute_attack()` reuses this existing attack resolver instead of inventing overpass-only attack physics.

That reuse is architecturally important:

```text
overpass gives player an attack opportunity
→ ordinary attack machinery executes it
```

not:

```text
OVERPASS_ATTACK
→ separate shortcut outcome table
```

## Attack outcome is downstream

Kill, blocked, dug, error and other labels should describe what happened after the launch/interactions.

An open-net situation can be a strong kill opportunity, but a live integration should not skip a viable block/defender merely because the action originated from an overpass.

## Force-derived ball timing

The design work in `BALL_LAUNCH_KINEMATICS.md` moved serve/set/attack timing toward projectile solutions based on distance and launch angle/velocity rather than independent “flight duration” knobs.

This reduces contradictory states such as a ball claiming a small apex rise while remaining airborne for physically incompatible time.

When several fields describe one projectile, prefer deriving them together.

## Attributes and contact families

Do not assume each displayed attribute belongs to exactly one action.

For example:

- composure/decision making can influence choices across contacts;
- explosiveness/jump capacity affect multiple airborne actions;
- court vision matters to distribution/reading;
- attack power is not the same thing as aggression.

The same player model feeds many systems through semantically different roles.

## Certified does not mean perfect presentation

A contact family can be structurally certified while still having:

- pose/readability work;
- tactical-expression refinements;
- future cross-contact consistency work;
- new action forms that reuse it.

Do not confuse “we are not rewriting attack physics” with “attack can never change again.”

## Safe extension example: setter dump

A setter dump should eventually reuse existing pieces:

```text
second-contact situation
→ attack legally/physically available to setter
→ action chooser compares set vs attack
→ attack contact execution
→ ordinary outgoing ball / block / defence
```

The new work is primarily **action availability/choice across contact #2**, not a brand-new ball physics system.

## Reading exercise

Trace one ordinary attack from:

- setter/hitter preparation;
- approach/takeoff;
- attack resolver;
- outgoing ball;
- block/defence.

Then compare that with `OverpassActionSystem.execute_attack()`. Identify what is reused and what the overpass layer uniquely owns.

## Source trail

- `scripts/simulation/rally_simulator.gd`
- `scripts/simulation/rally_kinematics.gd`
- `scripts/simulation/approach_mechanics_system.gd`
- `scripts/simulation/geometric_attack_resolver.gd`
- `scripts/simulation/overpass_action_system.gd`
- `docs/review/FORWARD_WALK_ATTACK_CHAIN.md`
- `docs/design/BALL_LAUNCH_KINEMATICS.md`

Next: the block, which is not simply another team contact and therefore creates different ownership/continuation problems.