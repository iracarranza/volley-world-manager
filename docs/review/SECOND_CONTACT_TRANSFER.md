# The second contact may transfer: strong responsibility, not absolute

Run: 2026-08-16, from `767faf7`. Instrument:
`tools/run_second_contact_probe.gd` (gates 1–6 and the head-start section are
new in this pass). **Production behaviour changed**, in two places, both one
argument wide.

The policy this implements, decided after the `767faf7` audit stopped at it:

> The designated setter has strong first responsibility for the second contact,
> but that responsibility is **not absolute**. If the realized ball and the
> existing movement model show the setter cannot realistically fulfil it while
> another responsible voli can, the second contact may transfer.
>
> Not "nearest player wins" and not "best setter wins."

The chain, unchanged in shape:

```text
REALIZED PASS
→ planned second-contact responsibility
→ existing physical availability can defeat an impossible claim
→ ONE selected second-contact voli
```

§7 is the residual boundary, and it is real: the corrected weights do everything
asked of them, and the *arrival model* turns out to be what cannot tell "had to
take a step" from "could never have got there."

---

## 1. The change

Two lines, and neither adds a threshold, a constant or a model.

### 1a. The designated-setter term replaces the plan's duty instead of stacking

```gdscript
## rally_simulator.gd, _spatial_setter_choice
if candidate.id == designated_setter_id:
    duty_bonus = 0.46        ## was: duty_bonus += 0.46
```

`Primary emergency setter` and `Secondary emergency setter` describe who covers
**when the normal setter cannot take the second contact**. They are a fallback
hierarchy. Adding one to the normal setter's own authority because the rotation
happened to park them in slot 2 is a category error, and it was the whole defect:

| setter stands in | before | after |
|---|---:|---:|
| slot 2 (plan's primary emergency slot) | +0.80 | **+0.46** |
| slot 1 (secondary) | +0.64 | **+0.46** |
| slots 3–6 (no duty) | +0.22 | **+0.46** |

+0.46 still sits above the plan's own primary emergency duty (+0.34), so
responsibility stays firmly first. And 0.46 against a no-duty −0.24 is a gap of
0.70, inside the arrival term's 1.04 — so an impossible claim can now yield,
which +0.80 against −0.24 (**exactly** 1.04) could not.

The branch is unreachable for a setter who played the first contact — they are
excluded from `candidates` — so the fallback hierarchy is untouched. Gate 5
confirms rather than assumes it.

### 1b. The opponent's second contact gets the serve's flight as a head start

```gdscript
## _resolve_opponent_transition gains head_start_seconds (last in the list),
## passed through to _spatial_setter_choice. The serve-receive caller supplies:
serve_time,
```

Not a repair bundled in for tidiness — it became a defect *in this node* the
moment responsibility stopped being absolute. §5.

---

## 2. The six gates, before and after

Every gate walks the setter through all six rotation slots on **identical
geometry**. Both selectors are deterministic, so these are exact.

| gate | before | after |
|---|---|---|
| 1 — normal setter, reachable | PASS | **PASS** |
| 2 — stranded setter, nominated team-mate on the ball | PASS | **PASS** |
| 3 — stranded setter, **no-duty** team-mate on the ball | **SPLIT** — rotation decides | **PASS** |
| 4 — rating control (`set_accuracy` sweep) | **MOVED** at 99, rotations 3–6 | **PASS** |
| 5 — setter made first contact | 6/6 nominated | **6/6 nominated** |
| 6 — the `767faf7` pathological fixture, rotated | **FAIL** — 2 answers in 6 | **PASS** |

### Gate 3, the defect itself

```text
before                              after
rot  setter duty  chosen            rot  setter duty  chosen
1    secondary    team-mate         1    secondary    team-mate
2    primary      SETTER   <-       2    primary      team-mate
3    none         team-mate         3    none         team-mate
4    none         team-mate         4    none         team-mate
5    none         team-mate         5    none         team-mate
6    none         team-mate         6    none         team-mate
```

One row moved. That row was the whole bug.

### Gate 4, which got *better* rather than surviving

Before, at `set_accuracy` 99 the challenger took the ball in rotations 3–6 —
because the setter was under-weighted at +0.22 there, and 0.49 × 0.28 of rating
edge was enough to buy it. Flattening the term to +0.46 raised the setter in
exactly those four rotations, and the sweep is now clean at every value:

```text
set_acc   before                                  after
50        SETTER SETTER SETTER SETTER SETTER SETTER   SETTER x6
70        SETTER SETTER SETTER SETTER SETTER SETTER   SETTER x6
85        SETTER SETTER SETTER SETTER SETTER SETTER   SETTER x6
99        SETTER SETTER slot6  slot6  slot6  slot6    SETTER x6
```

**Technical quality no longer buys a second ball off a reachable setter in any
rotation.** That was not the goal of the change and is the strongest evidence
the diagnosis was right: removing a double count fixed a defect at the *other*
end of the same range.

---

## 3. Responsibility still orders the transfer

The gates say *whether* a ball transfers. This says the transfer is still
governed by the sheet, which is the difference between the decided policy and
"nearest player wins."

One challenger walks from the far corner onto the ball while the setter stands
stranded. The number is the walk fraction at which they take it:

| challenger's duty | before | after |
|---|---|---|
| `Secondary emergency setter` (+0.18) | 0.90 | **0.50** |
| `No second-contact duty` (−0.24) | never | **0.90** |

A nominated cover takes an impossible ball from **further away** than an
unnominated one does. The plan still decides who is entitled to what; the legs
decide only whether the entitlement is physically meaningful. That ordering is
the policy, and it is now visible in a table rather than asserted.

The ceiling sweep confirms the mechanism changed rather than the threshold: a
no-duty voli standing on the ball now wins at `set_accuracy` **50**, where before
they needed 75. It is the legs taking it, not the rating.

---

## 4. In situ

800 isolated rallies, fresh `GameManager` per seed, both serving sides.

| | before | after |
|---|---:|---:|
| second contacts | 874 | 873 |
| emergency second contact | 44 (0.0503) | 48 (**0.0550**) |
| uncontested (`claimant_count` ≤ 1) | 374 (0.4279) | 101 (**0.1157**) |
| mean claimants | 2.8490 | **3.9244** |
| seam conflicts | 4 (0.0046) | 3 (0.0034) |
| mean arrival margin | 0.5384 s | 0.5429 s |
| mean travel | 0.5232 s | 0.5197 s |
| late arrivals (margin < 0) | 38 (0.0435) | 35 (0.0401) |

**Emergency setting moved 5.03% → 5.50%.** Not tuned toward anything; the old
rate was a measurement and is not a target. The distinct-setter census is
unchanged in shape — two volis per side, ever:

| actor | before | after |
|---|---:|---:|
| 1 (home setter) | 415 | 411 |
| 2 (home emergency) | 44 | 48 |
| 101 (opponent setter) | 391 | 389 |
| 102 (opponent emergency) | 24 | 25 |

### Outcome mix — regression observation only

| | before | after |
|---|---:|---:|
| home points | 413 (0.5162) | 417 (0.5212) |
| kill | 245 | 245 |
| opponent_kill | 205 | 200 |
| attack_error | 71 | 72 |
| opponent_attack_error | 71 | 76 |
| counter_block | 22 | 21 |
| blocked / ace / serve_error | 41 / 4 / 141 | 41 / 4 / 141 |

Four rallies in eight hundred changed hands. Recorded because a second-contact
change that moved the scoreboard would be worth *seeing*; it is emphatically not
worth steering.

---

## 5. The home/opponent asymmetry, and why it had to be fixed here

The audit found two. Only one of them turned out to belong to this node.

### The head start — corrected

The probe drives `_spatial_setter_choice` directly with the two values the two
call sites actually pass:

| fixture | opponent (0 s) | home (1.34 s) | same? |
|---|---|---|---|
| normal | setter | setter | yes |
| setter mid-far | setter | setter | yes |
| **setter stranded** | **team-mate** | **setter** | **NO** |

Before this pass that row read *yes*, because the setter's inflated duty bonus
won regardless of when they started running. **The defect was masked by the
defect.** Once responsibility stopped being absolute, the two sides began
answering an identical physical situation differently with nothing between them
but a missing argument — which is an authority defect in this selector, not a
cosmetic one, so it was corrected with the input already in scope.

It landed exactly where intended and nowhere else:

| side | mean claimants before | after |
|---|---:|---:|
| home | 4.4183 | **4.4183** — untouched, to four decimals |
| opponent | **1.1133** | **3.3768** |

An opponent second contact used to have barely one reachable claimant because
five bodies were timed from a standing start. Now it has 3.38.

**Three of the four `_resolve_opponent_transition` callers still pass nothing** —
the two dig paths and the coverage path. Each has a flight in scope and each
mirrors `_resolve_home_continuation`, which does pass one, so the same asymmetry
is very likely live there too. It was not changed because the fixture that
demonstrated the defect is a serve reception, and repairing three unmeasured call
sites on the strength of one measured one is how a pass stops being verifiable.
That is the remaining gap between 3.38 and home's 4.42, along with genuinely
different geometry; this instrument cannot separate the two.

### The movement recomputation — documented, and now more urgent

Lines 4035–4050 re-read `setter_start` from `opponent_live_positions` and
recompute `setter_move_time` on the `lateral` profile, rather than taking
`start` and `travel_time` out of `opponent_setter_choice` as the home path does.

This affects **reporting and execution downstream, not selection** — the chosen
voli is already decided — so per this pass's own scope it belongs to the
setter-movement pass. But it got worse in a specific way worth writing down: the
opponent's setter is now *selected* from a head-start-advanced position and still
*drawn* from the un-advanced one. Before this pass those agreed because both were
un-advanced. Whoever takes the setter-movement pass should start here.

Related and found while measuring: **the opponent SET event publishes no
`arrival_margin` and no `emergency_setter`.** The per-side table above reads
0.0000 for both on that side — that is a missing key, not a measurement. Every
opponent figure in this document is therefore claimant counts and travel only.

---

## 6. Tests

`_test_second_contact_rotation_invariance`, five checks:

1. a reachable designated setter keeps the ball in every rotation;
2. an unreachable setter yields to the voli on the ball in every rotation;
3. **those two fixtures genuinely differ** — without this, both could be uniform
   because responsibility had been flattened to nothing and every other check
   would still pass;
4. `set_accuracy` cannot buy the ball off a reachable setter;
5. the rotation does not decide who covers an unreachable setter, when the voli
   on the ball holds **no duty at all**.

**Verified bidirectional.** Reverting `=` to `+=` and re-running the suite fails
checks 4 and 5 and passes the rest. Checks 1–3 hold on both versions, which is
worth stating plainly: they document the policy but do not guard this change,
and check 5 is the one that does. It was added after the first draft passed on
both versions — a gate that cannot fail is not a gate, and that is the same
mistake the block-hands probe made with a single fixture.

Suite: **2,087 → 2,090 → 2,095.** The first move is +3 with no checks written —
production behaviour changed and several sampling gates draw a check per sample,
so their populations changed size. The second is +5, exactly the checks written,
meaning the test addition disturbed no sampling population. No failures.

---

## 7. The residual boundary — the arrival model, not the weights

The gate that asks *where* the ball changes hands, with a nominated challenger
parked exactly on it and the setter walking out from beside it:

| setter's distance | own arrival margin | reachable | chosen |
|---:|---:|---|---|
| 0.0000 m | +1.200 s | yes | setter |
| **0.1250 m** | **−0.133 s** | yes | team-mate |
| 0.2499 m | −0.113 s | yes | team-mate |
| 0.4999 m | −0.101 s | yes | team-mate |
| 1.2497 m | −0.224 s | yes | team-mate |
| 3.1242 m | −0.465 s | NO | team-mate |
| 6.2484 m | −1.067 s | NO | team-mate |

**The margin falls from +1.200 s to −0.133 s over twelve and a half
centimetres**, then stays roughly flat for the next metre. That is the movement
model's fixed standing-start cost, not a duty weight: at a 1.20 s window,
*having to take a step at all* costs about as much as crossing the court.

So the honest statement of what this pass achieved:

> The **weights** now express the policy correctly and rotation-invariantly. The
> **arrival model** cannot distinguish "had to move" from "could never have got
> there" over short legs, so at the pathological end — a team-mate standing
> exactly on the contact point — the setter yields sooner than the policy's
> wording implies.

This is not a new finding. It is `OUTSTANDING` §1's short-leg timing problem,
already documented at the home call site in the comment that holds
`setter_release_target` back for the same reason: *"the fixed costs, the standing
start and the turn, are a much larger share of two tenths of a second than of one
and a half."*

**Not papered over**, and deliberately so. The available fix is a reachability
cutoff — "the setter keeps it unless their margin is worse than X" — and that is
exactly the invented threshold this pass was told not to add, sitting outside any
distribution anyone has measured. The short-leg timing wants fixing first; then
this table re-measures itself.

Its practical weight is small and worth stating alongside: in situ the change
moved emergency setting by half a percentage point, because a team-mate standing
within centimetres of the contact point while the setter is beside it is not a
common shape. The pathological fixture is a measuring instrument, not a rally.

---

## 8. Where this stops

At the boundary into `choose hitter`, unchanged from the audit's §8: the second
contact hands the third a name, a legality constraint (`setter.id` excluded) and
`reception_quality`. Nothing in this pass touched hitter selection, set quality,
set generation, `SetterCapabilityModel`, the three duty tables, the semantics of
`Stay available to attack`, or the `quality → ball` inversion.

---

## Re-running

```bash
godot --headless --path . --script res://tools/run_second_contact_probe.gd
```

Cases A–E and gates 1–6 are exact and should reproduce byte-for-byte. Part B is
one fixture; its rates are description, never targets.
