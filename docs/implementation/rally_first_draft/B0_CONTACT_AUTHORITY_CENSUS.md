# B0 — contact-authority census

The packet's B0 asks for "one current table before editing any certified family",
naming every duplicate opinion about a physical fact.

**Measured, not read.** `tools/run_contact_authority_census.gd` runs 600 ordinary
rallies (300 per serving side, seeds 71000+) and reads what each contact actually
published into its own event, rather than inferring it from source. The
difference matters here more than usual: this repository's standing failure mode
is a value reviewed in the abstract and never put against the thing it acts on,
and a census assembled by reading `rally_simulator.gd` would be exactly that.

Run it with:

```bash
godot --headless --path . --script res://tools/run_contact_authority_census.gd
```

## What the provenance markers mean

M5 stamps three things on any trajectory it owns:

| marker | value | says |
|---|---|---|
| `trajectory_role` | `authoritative_free_flight` | this is one launch's whole unconstrained flight |
| | `realised_segment` | this is the played prefix of one, ending at a real interaction |
| `authoritative_flight_id` | a string | which launch this came from |
| `launch_source` | `resolver` | the launch state was published by contact physics |

A trajectory carrying none of them is not automatically wrong — serve, set and
attack have their own certified flight machinery and predate M5. It means their
one-ball chain can be certified by **geometry** but not by **identity**.

## The table

Measured at `c1978e6` plus the B4 repair below.

| family | contacts | publishes | free flight | realised | unmarked | flight id | launch source |
|---|---:|---:|---:|---:|---:|---:|---:|
| SERVE | 600 | 600 | 0 | 0 | 600 | 0 | 600 |
| RECEPTION | 494 | 494 | 4 | 490 | 0 | 494 | 494 |
| SET | 517 | 517 | 0 | 0 | 517 | 0 | 0 |
| ATTACK | 517 | 517 | 0 | 0 | 517 | 0 | 0 |
| BLOCK | 443 | 213 | 0 | 0 | 213 | 0 | 0 |
| DIG | 268 | 92 | 1 | 91 | 0 | 92 | 92 |
| ATTACK_COVERAGE | 23 | 23 | 0 | 23 | 0 | 23 | 23 |

`BLOCK` publishes on 213 of 443 because a block that does not touch the ball has
no outgoing ball to publish, which is correct. `DIG` publishes on 92 of 268 for
the same reason — a dig that does not come up produces nothing.

`RECEPTION`, `DIG` and `ATTACK_COVERAGE` — the three platform families — are the
only ones marked, which is the expected shape: they are the families M4 moved
onto the shared physical authority.

### Authority per family

| fact | serve | reception | set | attack | block | dig | coverage |
|---|---|---|---|---|---|---|---|
| incoming ball | — (rally start) | serve flight | M5 realised prefix | set flight | attack flight | attack/block flight | block flight |
| chooser | serve aim/risk | responsibility policy | `_spatial_setter_choice` / M5 | attack decision | defensive plan | responsibility policy | second-contact policy |
| feasibility | forward launch search | reach + contact envelope | setter capability | approach mechanics | block geometry | reach + envelope | reach + envelope |
| execution | `_canonical_serve` | `PlatformContactModel` T1–T3 | set geometry | `GeometricAttackResolver` | block interaction | `PlatformContactModel` | `PlatformContactModel` |
| outgoing launch | `_canonical_serve` → `_stamp_launch_state` | shared platform resolver | set arc | geometric swing | deflection arc | shared platform resolver | shared platform resolver |
| free flight | ballistic arc | **M5** | ballistic arc | ballistic arc | ballistic arc | **M5** | **M5** |
| actual next contact | receiver read | **M5 interception** | attacker options | block/defence | coverage/defence | **M5 interception** | **M5 interception** |
| legacy/shadow path | retired error draw (no authority) | legacy arm behind dev override | — | shadow attack (flag off) | shadow block (flag off) | legacy apex/spoil arm (dev override) | — |
| production flag | always | `ENABLE_PHYSICAL_RECEPTION` = true | always | `ENABLE_GEOMETRIC_ATTACK` = true | always | `ENABLE_PHYSICAL_PLATFORM_DIG` = true | always |

## The edges — is the next contact's incoming ball the previous outgoing one?

This is the table that matters. A family can look immaculate on its own row and
still hand the next contact a different ball.

| edge | seen | same ball | by identity | different |
|---|---:|---:|---:|---:|
| SET → ATTACK | 517 | 517 | 0 | 0 |
| SERVE → RECEPTION | 494 | 494 | 0 | 0 |
| ATTACK → BLOCK | 443 | 443 | 0 | 0 |
| RECEPTION → SET | 414 | 414 | **414** | 0 |
| ATTACK → DIG | 230 | 230 | 0 | 0 |
| DIG → SET | 86 | 86 | **86** | 0 |
| BLOCK → DIG | 38 | 38 | 0 | 0 |
| BLOCK → ATTACK_COVERAGE | 23 | 23 | 0 | 0 |
| ATTACK_COVERAGE → SET | 17 | 17 | **17** | 0 |

Every edge hands over the same ball. No edge is missing an incoming ball, and no
contact is ordered backwards in time.

414 + 86 + 17 = **517**, which is every `SET` in the census: every second contact
in the engine consumes a realised prefix by launch identity, whichever family
fed it. That is B2's central claim, certified rather than asserted.

## Two findings

### F-1 — the home block intersected a superseded swing (fixed)

**100 of 443 `ATTACK → BLOCK` edges handed the block a different ball.**
`tools/run_block_authority_probe.gd` localized it to one side of a symmetric
pair:

| side | blocks | touching | stale incoming | late stamp | worst lateness |
|---|---:|---:|---:|---:|---:|
| home | 222 | 100 | **100** | **73** | **1.140 s** |
| opponent | 221 | 113 | 0 | 0 | 0.000 |

Both block paths re-slice the swing to the tape when the hands actually touch it
— a block that intercepts must not be fed the arc that would have reached the
floor. Only the opponent path then re-read the truncated result. The home path
had captured the pre-truncation arc in a local, and published *that* as the ball
its wall intersected.

The same local decided the block's timestamp, so the two were one defect. The
home block used `_contact_time`, which is a flight's `end_time` — on an
untruncated swing, the moment the ball reaches the floor *behind* the blockers.
`_swing_reaches_net` exists for exactly this and its own note says why:
reception, set and dig happen when a flight finishes; a block happens partway
through one. Worst case measured, the hands were stamped **1.140 s** after the
ball they were supposedly touching had landed.

Repaired by reading the attack event's published metadata — the same source the
opponent path reads — for both the incoming ball and the timestamp. Both sides
now measure 0 and 0. No decision changed: block counts and touch counts are
identical before and after; what changed is which ball the event says the wall
met, and when.

This is the shape B4 and B6 exist to find. Not a rule that was wrong, but one of
two symmetric paths drifting from its twin — and only the second framing names
the repair.

### F-2 — four families publish unmarked balls (open, B6)

`SERVE`, `SET`, `ATTACK` and `BLOCK` publish no `authoritative_flight_id`. Their
edges are certified by geometry, which does establish that no second physical
authority is inventing a ball, but not by identity.

Serve carries `launch_source = resolver` on 600 of 600 and no id; set and attack
carry neither.

This is not a physics defect and nothing in the engine reads a wrong number
because of it. It is a *certifiability* gap: the packet's P3 matrix asks each
edge for "same launch lineage", and on four families the strongest available
answer is "same shape". See B6.

**Closed in the same pass.** `_ball_trajectory` now stamps
`authoritative_flight_id` on every flight it builds, and the two `attack_to_block`
re-slices carry their source's id rather than minting a new one. Re-running the
census puts every one of the nine edges at 100% same-lineage — the `by identity`
column above reads `seen` on every row. The `trajectory_role` column is
deliberately still empty for those four families and always will be: that string
is M5's, and `FreeFlightInterceptionModel` gates on it.

The table in this file is left as it was measured, chronologically, because the
sequence is the finding: the chain was already correct and only became
*provable* afterwards, and a reader who sees only the repaired state cannot tell
those two things apart. `B1_B6_FAMILY_AUDITS.md` carries the closed table.

## Instrument note

The first run of this census reported 230 of 268 `BLOCK → DIG` edges as handing
over a different ball, which read as the worst authority break in the engine. It
was not. A block that does not touch the ball publishes nothing, and 230 is
exactly the number of silent `BLOCK` events; the comparison was scoring "the
previous contact was silent" as "the previous contact handed over something
else".

The census now measures each edge against the last contact that actually
published a ball, which is what the one-ball chain means anyway — a ball survives
a no-touch block, and the dig after it is receiving the attack's ball, correctly.

Recorded because it is the same failure this file's opening paragraph warns
about, committed by the instrument built to catch it.
