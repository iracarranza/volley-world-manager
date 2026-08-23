# M4 slice 1: every platform contact now says what it was for, and nothing reads it

Run: 2026-08-17, from `9651d5d`. Instruments:
`tools/run_platform_intent_census.gd`, and the same probe against the stashed
tree.

`PLATFORM_CONTACT.md` §11 asks this slice for two things that pull in opposite
directions:

1. **rallies must come back byte-identical** — nothing consumes any of it;
2. it must make countable, "for the first time, how many platform contacts in
   the game have any stated intent at all."

The first is what makes the second worth reading. A census of a population that
moved while being counted measures the counting.

---

## 1. What is published, and why it has three different shapes

Seven fields per platform contact — §11's five, plus the two source markers
§13.10 asks for — on all eight `_add_event` sites: two receptions, three attack
coverages, three digs.

| field | shape | source |
|---|---|---|
| `purpose` | label | the call site knows it |
| `target_anchor` | **anchor** | `_desired_pass_target` on reception; the fixed offset elsewhere |
| `anchor_source` | marker | `release_seat` or `contact_offset` |
| `intended_recipient_id` | id, or −1 | the active setter; absent on coverage |
| `height_anchor_meters` | **anchor**, or `unset` | `set_contact_height_meters(setter, false)` — class C |
| `arrival_floor_seconds` | **one-sided bound**, or `unset` | `_movement_time(setter, position, anchor)` — class C |
| `preference_source` | marker, `"none"` today | nothing supplies a preference yet |

The heterogeneity is §3a's finding, not a stylistic choice: the target and the
height have derived anchors and no derived widths; time has a derived floor and
no derived ceiling. A uniform representation would have had to invent whatever
the uniformity demanded — four of five bounds, by §3a's own count.

**`unset` is a `String`.** A sentinel float would be indistinguishable from an
anchor that happens to sit at the default, which is `FAILURE_MODES.md` §0 in one
line. It cost the probe a bug to prove the point — see §5.

---

## 2. The outcome mix did not move. 600 rallies, both serving sides

| | with the slice | with it stashed |
|---|---:|---:|
| rallies | 600 | 600 |
| home points | 290 | 290 |
| events | 3,887 | 3,887 |
| platform contacts | 785 | 785 |
| ace | 9 | 9 |
| attack_error | 54 | 54 |
| blocked | 26 | 26 |
| counter_block | 30 | 30 |
| kill | 159 | 159 |
| opponent_attack_error | 46 | 46 |
| opponent_kill | 160 | 160 |
| serve_error | 116 | 116 |

Measured on **one instrument, twice** — the probe run against the production
tree and then against `git stash`. Quoting a census taken on a different seed
base would have proved nothing, which is why the earlier 288/3,955 figure from
`ACTOR_CONTINUITY.md` is not the comparison used here: it is a different seed
base and a different loop.

`_platform_intent` calls `_movement_time`, and this is what says that call draws
no RNG and records nothing — which was the one live risk in an otherwise inert
change.

---

## 3. The census, and the doc's own prediction

§11 predicted: "coverage has none and the other two have half of one."

| purpose | contacts | recipient | height | arrival | **steerable** |
|---|---:|---:|---:|---:|---:|
| `attack_coverage` | 24 | 0 | 0 | 0 | 0 |
| `controlled_dig` | 277 | 277 | 277 | 277 | **0** |
| `serve_reception` | 484 | 484 | 484 | 484 | **484** |
| all | **785** | 761 | 761 | 761 | 484 |

Coverage has none, exactly as predicted. The other two were predicted to have
"half of one" and the measurement is sharper than that: **they have a recipient
and two derived anchors, and only the reception's target came from anywhere a
manager can reach.**

That last column is §13.9's item 3 made countable instead of anecdotal. Every
one of the 277 controlled digs names the setter as its recipient and then aims
`contact + (0.04, −0.03)` — a stride from the digger. **The record now states
both facts side by side, so the disagreement is data rather than a paragraph in
a design document.**

`preference_source` other than `"none"`: **0 of 785**. Nothing supplies a
tactical preference yet, and publishing the field with an absence marker is what
stops the schema changing when tactics arrive — the marker takes a new value, the
record does not grow a new shape.

### The arrival floor never went slack, and that is a real reading

| purpose | height anchor, min / p50 / max | mean floor s | slack (≤ 0) |
|---|---|---:|---:|
| `attack_coverage` | unset | unset | — |
| `controlled_dig` | 2.190 / 2.190 / 2.190 | 1.167 | **0** |
| `serve_reception` | 2.190 / 2.190 / 2.190 | 1.059 | **0** |

Zero slack in 761 contacts says the setter is never already at the anchor when
the ball is aimed. On reception that is honest — the setter is in the receive
shape and has a run to make. On the dig it is an artefact of the anchor: the ball
is aimed a stride from the digger, so of course the setter is a second away from
it. §3a's worked example — a setter at the seat stops constraining the ball
rather than compressing it to nothing — is therefore **unexercised in the live
population**, and the test constructs it directly instead of claiming the census
found it.

---

## 4. The constant column is the fixture, not the derivation

`2.190 / 2.190 / 2.190` across all 761 stated anchors is exactly what a
derivation that ignored the body would print, and it took one measurement to tell
the two apart:

```
home setter Mira h=185.0 w=188.0 reach=225.74 anchor=2.1896
opp setter  Ari  h=185.0 w=188.0 reach=225.74 anchor=2.1896
```

**The vertical slice has one setter body, twice.** The derivation reads
`standing_reach_cm()` and is fine; the population cannot show it. So the census
does not claim it does, and the check that the anchor tracks the body is made
against two constructed bodies — 176/179 against 198/205 — where it moves by more
than 15 cm.

This is the §0 screen doing its job in the direction it is usually needed: not
catching a broken value, but refusing to let a correct one be certified by an
instrument that could not have detected the break.

---

## 5. The probe's own bug, caught by running it backwards

The first version counted a stated anchor whenever
`record.get("height_anchor_meters")` was not a `String`. Against the pre-slice
tree — where there is no record at all — `get` returns `null`, `null is String`
is false, and the probe reported **785 of 785 contacts carrying a height
anchor** on a tree that published none.

The check is now `has` first, then the marker. It is worth stating because it is
the same failure the fields themselves are shaped to prevent: an absence that
reads as a value.

---

## 6. Tests — five checks, and the two directions differ

`_test_platform_contacts_state_an_intent`. Verified by renaming the
`"platform_intent"` metadata key at all eight sites and re-running:

```
TEST FAILED: every platform contact publishes a complete intent record
TEST FAILED: a reception aims at the release seat, at a person, with both anchors derived
FAIL: 2 of 2142 checks failed
```

The other three checks **pass in both directions, deliberately**, and they are
labelled as invariants rather than gates: they exercise `_platform_intent`
itself, which the surgical revert leaves standing. They are what says the two
derived fields are derived — from the setter's own reach, and from the setter's
own journey — rather than dialled.

Suite: **2,142 checks, no failures.** That is 2,137 plus exactly the five
written, which says the test addition disturbed no sampling population — and,
read together with §2, nothing else moved either.

---

## Re-running

```bash
godot --headless --path . --script res://tools/run_platform_intent_census.gd
git stash push scripts/simulation/rally_simulator.gd   # and again, for the comparison
```

Deterministic. 600 rallies on the vertical slice, seeds 23000–23299 on each
serving side.
