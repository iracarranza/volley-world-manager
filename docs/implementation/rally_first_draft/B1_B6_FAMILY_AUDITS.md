# B1–B6 — per-family audits and the cross-family chain

The packet's disposition for B1–B4 is **audit, do not rewrite**: reopen a
certified family only on controlled proof of an authority break. This records
what was checked, what the evidence was, and the one break that was found.

---

## B1 — serve · **CLOSED, no change**

Required order: aim → feasible launch selection → execution error → one launch →
physical flight → net/landing/in-out truth → reception read.

| check | evidence |
|---|---|
| no pre-rolled verdict manufactures the landing | `serve_error`, `landing`, `duration`, `apex` and `contact_height` all come from `_canonical_serve` — the forward launch search |
| the preserved old error draw has no outcome authority | `_retired_serve_error_draw` occurs exactly twice in the file, both assignments, never read. It is `_`-prefixed and exists to hold RNG draw order |
| only one production serve launch exists | one `_canonical_serve` per path; `_stamp_launch_state` publishes it once |
| launch state is independent of the later receiver | the census reports `launch_source = resolver` on 600 of 600 serves, stamped before any receiver is chosen |
| receiver reads the physical flight | `SERVE → RECEPTION` is 494 of 494 the same ball |
| home and opponent are symmetric | both paths run the identical `_retired_serve_error_draw` / `_canonical_serve` pair |

No refactor for style, per the packet.

---

## B2 — set · **CLOSED, no change**

The claim that mattered is B2.1–B2.2: the incoming ball is the realised
trajectory of the previous physical contact, and the setter's actor, position,
height and time are realised state rather than the authored pass endpoint.

The census answers it exactly, and the arithmetic is worth stating:

| feeding family | sets fed | by launch identity |
|---|---:|---:|
| RECEPTION → SET | 414 | 414 |
| DIG → SET | 86 | 86 |
| ATTACK_COVERAGE → SET | 17 | 17 |
| **total** | **517** | **517** |

517 is every `SET` event in the census. **Every second contact in the engine
consumes a realised prefix by launch identity, whichever family fed it.**

The known debts the packet lists — opponent/transition set posture gaps,
unmeasured set-posture pace terms — are fidelity and calibration, not two
authorities over one physical fact. They stay where they are, per B2's own
instruction to classify rather than blindly fix.

---

## B3 — attack · **CLOSED, no change**

Geometric attack is production authority (`ENABLE_GEOMETRIC_ATTACK` and
`ALLOW_DEVELOPMENT_GEOMETRIC_ATTACK` both true). `551e29e`, the HEAD drift past
the packet's pinned base, sits inside this audit's scope: it repaired
`_resolve_overpass_attack` reading `attacker.position` off a Resource that has
no `position`, where `Dictionary.get`'s eagerly-evaluated default errored on
every call and produced `Vector2(null)` in the fallback. That is a correctness
repair inside the attack family and it does not introduce a second authority.

| check | evidence |
|---|---|
| no legacy quality scalar authors a second landing | `SET → ATTACK` 517 of 517 same ball; `ATTACK → BLOCK` and `ATTACK → DIG` both 100% after B4 |
| the attack event refers to the actual launch | the attack's `outgoing_trajectory` *is* the ball every downstream contact receives, by identity |
| home and opponent consume the same category of facts | after the B4 repair, both block paths read the attack event's published metadata |

---

## B4 — block · **ONE AUTHORITY BREAK FOUND AND REPAIRED**

The B0 census found 100 of 443 `ATTACK → BLOCK` edges handing the block a
different ball than the attack published.
`tools/run_block_authority_probe.gd` localized it:

| side | blocks | touching | stale incoming | late stamp | worst lateness |
|---|---:|---:|---:|---:|---:|
| home | 222 | 100 | **100** | **73** | **1.140 s** |
| opponent | 221 | 113 | 0 | 0 | 0.000 |

Both block paths re-slice the swing to the tape when the hands touch it — a
block that intercepts must not be fed the arc that would have reached the floor.
Only the opponent path re-read the truncated result. The home path had captured
the pre-truncation arc in a local and published that as the ball its wall met.

The same local decided the block's timestamp, so the two were one defect. The
home block used `_contact_time`, a flight's `end_time` — on an untruncated swing,
the moment the ball reaches the floor *behind* the blockers.
`_swing_reaches_net` exists for precisely this and says why in its own note:
reception, set and dig happen when a flight finishes; a block happens partway
through one.

Repaired by reading the attack event's published metadata, the same source the
opponent path reads, for both the incoming ball and the timestamp. Both sides
now measure 0 and 0.

**No decision changed.** Block counts and touch counts are identical before and
after; what changed is which ball the event says the wall met, and when. The
rally balance probe reports kill rate 0.661 and contacts per rally 4.771 both
before and after — the same figures recorded at the M4 promotion.

The other three B4 checks hold unchanged: a block touch changes the same ball
rather than spawning a replacement, the post-block continuation is one
authoritative ball (`BLOCK → DIG` 38 of 38, `BLOCK → ATTACK_COVERAGE` 23 of 23),
and `block_intent` / hand choice remain intent rather than terminal verdicts.

---

## B5 — platform-family closure · **CLOSED**

All three platform contexts run one physical model:

- `PlatformContactModel.evaluate` is called from **one** site in
  `rally_simulator.gd`, inside `_physical_platform_dig_result`.
- That helper has three callers: the controlled dig, attack coverage and
  reception.
- The six authored T1–T3 magnitudes appear nowhere outside
  `platform_contact_model.gd` except a probe that prints them and a test that
  asserts the relation — both class C diagnostics, neither an alternative
  authority.
- `contact_family` labels the flight and keeps the deterministic streams
  distinct; it does not select coefficients, and the function's own comment says
  so.

Every successful platform contact feeds M5 rather than a designated endpoint,
which the census confirms: reception, dig and coverage publish `realised_segment`
or `authoritative_free_flight` on 100% of their published balls, with a launch
identity on every one.

### One label defect, recorded not repaired

Attack coverage calls the shared resolver with the **default** `contact_family`
(`"dig"`) rather than `"coverage"`, so its flights are labelled as digs and its
seed string reads `platform-dig`. The seed already contains the contacting
voli's id and the contact time, so no collision is possible and no physics
changes — this is a reporting defect, not an authority one. Passing the correct
label would change the seed string and therefore the execution-error draw for
every coverage contact, which is a distribution move for a naming fix. Logged
rather than taken as a rider on this pass.

---

## B6 — cross-family one-ball chain · **CLOSED by identity**

### What was missing

`SERVE`, `SET`, `ATTACK` and `BLOCK` published balls with no
`authoritative_flight_id`. Every edge still handed over the right ball, but the
strongest available certification was "the same *shape* arrived", and P3's
matrix asks each edge for "same launch lineage". Two geometrically identical
records are indistinguishable from one record passed along — which is exactly
the substitution a one-ball chain exists to rule out.

### What was done

`_ball_trajectory` — the single construction point for every non-M5 flight in
the engine — now stamps a launch identity. Empty mints a new one; a **re-slice**
of an existing launch passes the source's id, because it is a prefix of that
launch and not a second one. The two `attack_to_block` truncation sites are the
only re-slices, and both now state their lineage rather than leaving it inferred
from coincident floats.

**The id and deliberately not `trajectory_role`.**
`authoritative_free_flight` is M5's word for a flight M5 resolved, and both
`FreeFlightInterceptionModel.opportunities` and `realised_prefix` refuse to act
on anything without it. Stamping it on a serve or a set arc would let those
flights walk into the interception search — a second physical authority arriving
through a label, which is the thing this identity was added to make detectable.

### The result

| edge | seen | same ball | by identity |
|---|---:|---:|---:|
| SET → ATTACK | 517 | 517 | 517 |
| SERVE → RECEPTION | 494 | 494 | 494 |
| ATTACK → BLOCK | 443 | 443 | 443 |
| RECEPTION → SET | 414 | 414 | 414 |
| ATTACK → DIG | 230 | 230 | 230 |
| DIG → SET | 86 | 86 | 86 |
| BLOCK → DIG | 38 | 38 | 38 |
| BLOCK → ATTACK_COVERAGE | 23 | 23 | 23 |
| ATTACK_COVERAGE → SET | 17 | 17 | 17 |

Zero edges hand over a different ball. Zero edges are missing an incoming ball.
Zero contacts are ordered backwards in time.

`_test_one_ball_chain_by_launch_identity` in `tests/test_runner.gd` asserts both
halves permanently, on the suite's own budget, so the chain cannot quietly
regress into geometric coincidence again.

### Legacy cleanup

Deliberately **not** done in this pass, and the packet's own condition says why:
"keep temporary legacy machinery only when a live paired comparison still needs
it." Three do.

- The legacy apex/spoil dig arm survives behind
  `ALLOW_DEVELOPMENT_PLATFORM_DIG_OVERRIDE`, and
  `run_reception_rollout_probe.gd` / the dig and coverage rollouts still run
  paired against it. Removing it would retire a live protocol, not dead code.
- The four `ENABLE_CONTINUOUS_*_EVENTS` rollout flags are all `false` with their
  development overrides `true`. Their shadow systems are the M7 substrate, not
  superseded authority.
- `_retired_serve_error_draw` must stay: deleting it resequences every RNG draw
  after it in the rally, which would move the whole outcome mix for a cosmetic
  gain.

### M6 closure criterion

> No known ordinary production edge has two independent physical authorities.

Met, and now met by identity rather than by shape.
