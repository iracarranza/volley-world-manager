# 01 — Target architecture, authority and state

## 1. First-draft end state

The rally-engine first draft is complete when the implementation satisfies all of the following structurally, even if later certification still finds defects inside individual components:

1. One ordinary rally is one causal chain from serve launch to truthful terminal outcome.
2. Every ordinary contact family participates in the same ownership rubric.
3. Every physical contact produces at most one authoritative outgoing ball.
4. Free flight and physical interactions determine the actual next situation.
5. Intent and selected recipients/targets remain intent; they do not define realised endpoints.
6. Subsequent contacts consume realised upstream state.
7. Per-voli body/action state survives ball-event boundaries sufficiently for the canonical side-out to contain overlapping, physically timed actions.
8. Superseded production authority is retired or isolated behind an explicitly non-production validation path.
9. Simulation truth is sufficient for history/presentation; those layers do not have to reconstruct gameplay facts.
10. The whole engine can run M8 canonical side-out and M9 tactical A/B certification meaningfully.

## 2. Canonical causal chain

This is the governing model for remaining work:

```text
attributes + tactics
→ perception / responsibility / decision / intent / action choice

ball + body state
→ legal and physical feasibility

attributes
→ execution quality inside feasible space

contact physics
→ one authoritative outgoing launch

free flight / interaction
→ actual next situation

classification afterward
```

Three distinctions are load-bearing:

```text
intended recipient ≠ actual interceptor
intended target ≠ realised endpoint
outcome label ≠ trajectory author
```

Team contact number is context, not an action type.

## 3. Authority table

| fact | authority | explicitly not authority |
|---|---|---|
| tactical purpose / intended recipient / target anchor | action/intent decision | trajectory endpoint |
| whether a body can physically make contact | body + ball + reach/locomotion/contact envelope | outcome label |
| actual contact point/height/time | physical contact/interception state | planned destination |
| outgoing ball launch | contact physics | later recipient, presentation |
| free-flight path | ball-flight/kinematics authority | event classification |
| actual next actor | legal/physical interception + responsibility policy where applicable | intended recipient |
| realised segment | prefix of authoritative free flight ending at actual interaction | independent reconstructed trajectory |
| terminal truth | physical flight/interactions + rules | pre-rolled verdict |
| player body state | persistent per-rally actor state | fresh phase defaults when prior state exists |
| event labels/history | classification/reporting after physical truth | ball/body authoring |
| visual interpolation | presentation | gameplay reach, speed or contact physics |

## 4. Trusted existing substrate

The following are closed unless controlled evidence proves an authority violation at their boundary.

### M0 — authoritative rally skeleton

Preserve one rally chain. Do not introduce a parallel transition engine or hidden replacement ball.

### M1 — responsibility / defensive ownership

Preserve feasibility-gated ownership, short/zone responsibility, transfers/fallbacks and recovery debt.

### M2 — physical preparation

Preserve the existing facing/body-preparation semantics. The separately named per-form locomotion relation debt is not permission to invent a turn-rate or speed relation while doing unrelated work.

### M3 — body centre vs contact geometry

Preserve the derived contact offset and actual contact-family/per-voli heights. Do not put body centres back on ball endpoints.

### M4 already closed in production

- controlled dig uses shared physical platform authority;
- successful attack coverage uses the same authority;
- both route through M5 rather than forcing a setter endpoint.

### M5 — free flight / interception

Preserve:

- outgoing launch immutability;
- realised segment as an exact prefix of authoritative free flight;
- same-side interception/floor terminals;
- legal net crossing as receiving side ordinary first contact;
- intended recipient independent of actual interceptor;
- source-state immutability.

## 5. Current open boundary at pinned base

### Physical reception is already built

Do not reconstruct this feature.

At entry it already:

- reuses the shared T1–T3 platform resolver;
- publishes one authoritative physical launch when opened;
- routes the home first-ball path through M5;
- routes opponent reception through the existing transition M5 path;
- supports alternate interceptors and intended misses;
- feeds a realised intercepted prefix into the SET path;
- resolves truthful floor/net/out/crossing terminals;
- is development-certified by the paired reception rollout.

What remains is not reception physics. It is:

1. first-ball reporting/state semantics that still assume pass endpoint authority;
2. the short-leg movement/timing disagreement exposed by real interception timing;
3. production promotion after those are corrected.

## 6. State continuity contract for M7

The ball has contact-to-contact phases. Players do not.

For every voli:

```text
state at t1
+ actions/movement/recovery during (t1, t2)
→ state at t2
```

A new contact event may **sample** that state; it may not recreate the voli as though the previous phase did not happen.

State that already has an established per-rally owner must be carried rather than duplicated. At the pinned base this includes at least:

- live position;
- live velocity;
- carried recovery/body state;
- carried facing/orientation where established;
- recovery-until/ready-at consequences;
- movement/action intent when the M7 work adds persistence beyond current phase maps.

`ACTOR_CONTINUITY.md` already proves the smaller plumbing fact: recovery/body state survives phase rebuilding and reaches the contact envelope. M7 extends continuity to action timing and overlapping movement; it does not replace the certified body-state carry.

## 7. Realised-state consumption rule

Whenever the engine has both a planned/expected state and a realised physical state, downstream gameplay consumes the realised state unless the downstream calculation is explicitly about expectation/perception.

Examples:

- setter contact position/height/time after physical reception → M5 interception, not authored pass destination;
- set incoming trajectory after a physical interception → realised prefix, not full untouched flight;
- next-contact actor → actual legal interceptor, not intended recipient;
- terminal landing → physical flight, not an outcome label that causes a landing to be manufactured.

Expectation remains valid for perception, release targets, tactical planning and decision-making. It must not overwrite realised state after the physical event exists.

## 8. Classification rule

Classification is downstream of physics.

A kill, dig, overpass, net error, out ball, successful reception, set or transition label may describe what happened. It may not create the ball path needed to make the label true.

When a historical test asserts an old classification-driven physical consequence, migrate the assertion to the new physical authority rather than recreating the old consequence.

## 9. Presentation/history boundary

Presentation/history may:

- interpolate authoritative state;
- crop or convert coordinates;
- draw realised portions of trajectories;
- summarize contact classification;
- expose cognition/intent supplied by simulation.

They may not:

- decide launch speed;
- create an endpoint needed by gameplay;
- decide who intercepted;
- extend/shorten a gameplay trajectory to fit an animation;
- invent movement targets because the resolver did not publish them.

## 10. First-draft completion boundary vs certification

A complete first draft may still contain:

- incorrect movement magnitudes inside an otherwise complete movement path;
- a failed symmetry gate;
- a poor outcome distribution;
- rare-state defects found by later fixtures;
- presentation lag behind newly authoritative state.

It may **not** knowingly contain:

- a missing ordinary contact family;
- two production authorities for one physical question;
- a legacy path still manufacturing the ball where the target architecture says free flight owns it;
- event-boundary player resets that make required M7 actions impossible;
- an unresolved architectural decision silently replaced by a guessed constant.
