# Unreachable branch audit

Run: 2026-08-16, on `dce1598`. Instrument:
`tools/audit_unreachable_branches.py`. **Findings only — nothing was repaired.**

`docs/FAILURE_MODES.md` §0 names this repository's most-repeated defect as *a
value measured with the wrong instrument, or a knob that cannot reach its own
stated range*. The dead posture tier in `_dig_pass_result` was found by accident
during the platform-contact audit. This looked for the rest on purpose.

## The instrument, and the fact that its first version was wrong

The sweep collects every string literal used as a `match` arm and counts
*productions* of that literal elsewhere. Zero producers is a candidate.

**The first version could not find the case it was built for.** It required an
arm to end in a colon, so it saw only arms whose body was on the following line
and missed every inline `"x": y = 1` — which is exactly the form the known defect
takes. It reported two findings and looked entirely plausible.

That is the §0 failure inside the §0 audit, and it is written here because the
lesson generalises: **an audit instrument that cannot reproduce a known-true case
is measuring something else.** Validation against the dig posture branch is now
the first thing the tool is checked against, and distinguishing an arm from a
dictionary key needs brace-depth context, since both read `"literal":`.

## Confirmed: dead, with a consequence

### `"seal"` — `rally_simulator.gd:12655`, `match block_outcome`

```gdscript
match block_outcome:
    "funnel": bonus += FUNNEL_READ_BONUS        #  0.075
    "touch":  bonus += TOUCHED_BALL_READ_BONUS  #  0.090
    "seal":   bonus += SEAL_READ_BONUS          # -0.030   <- unreachable
```

The lowercase literal `"seal"` appears **nowhere in the codebase except this
arm**. The vocabulary `block_outcome` actually carries is `touch`, `tool`,
`miss`, `stuff`, `funnel`, `whiff`, `monster_block`, `recycle`.

So `SEAL_READ_BONUS = -0.030` — a floor defender reading *worse* because the
block sealed the lane — has never applied to any contact in any rally.

The likely history is visible in the neighbouring code: `"Seal"` **capitalised**
is a block *intent*, set on `DefensiveAssignment` by the planner. Somebody wrote
a read penalty expecting the outcome to name the intent. Outcomes name what the
ball did; intents name what the wall meant. The two vocabularies never met.

**Not repaired here.** Wiring it up changes floor-defence read quality on every
sealed block, which is a measurable behaviour change and belongs to the block
work already queued as tasks #62–64 — not to an audit.

### `"emergency"` — `rally_simulator.gd:9693`, `match posture`

Already documented in `docs/design/PLATFORM_CONTACT.md` §1 and the redesign log.
Reproduced here by the instrument rather than by luck, which is the point of
having one. `"fall"` beside it is produced four times — but as a *recovery
state*, never as a posture, so the arm is dead on both values.

## Confirmed: dead, no consequence

### `"approach"` — `rally_simulator.gd:8697`, `_movement_mode_for_kind`

Every `_movement_time` call in the simulator passes `"lateral"` or
`"transition"`; nothing passes `"approach"`. But `MovementMode.APPROACH` is set
correctly elsewhere, by `approach_mechanics_system.gd:439`, so no voli is drawn
with the wrong gait. The arm is a dead alias, not a defect.

Worth noting in passing: `rally_movement_system.gd` carries its own
`_movement_mode_for(action_type)`. Two mappings from a kind to a movement mode,
which is the shape that eventually drifts.

## Rejected: false positive

### `"labored"` — `ui_palette.gd:210`

The arm is `"laboured", "labored":` and `fatigue_model.gd:266` returns
`&"laboured"`. The American spelling is a defensive alias for the British one the
model actually emits. The branch is live; only the alias is unused.

**Generalisable:** a multi-value arm is reachable if *any* of its values is
produced, so per-value reporting overstates. The tool reports per value on
purpose — that is how the `"emergency", "fall"` pair was caught, since there the
*other* value is produced but never in the right domain — but every multi-value
hit needs this check before it is believed.

## The domain-aware pass, and why most of it is noise

A second sweep asked a harder question: which arm values are never *assigned to
the subject the match reads*, even if they exist elsewhere? That is the class
`"fall"` belongs to.

It correctly re-finds the posture case, and it produces a great deal of noise,
because most match subjects legitimately receive their values from another file
— `attack_type` from play data, `responsibility` from the planner,
`block_deflection_model`'s `kind` from `attack_resolution_model`. Cross-file
domain tracking is what would make it useful, and it is not built.

**The actionable subset is match subjects whose domain is produced inside the
simulation itself.** Those were checked by hand and are the findings above.

## Not covered

The other half of §0 — **a numeric threshold outside the distribution it acts
on** — is not addressed here. That needs a runtime measurement per threshold
rather than static analysis, and the simulation carries hundreds of tuned
constants. The serve pass found two of these by measuring one distribution at a
time (`SERVE_PACE_RELIEF_FLOOR`, and the flat clearance margin), which is the
only method known to work and does not scale to a sweep.

A cheaper proxy worth trying later: constants that appear in exactly one
comparison and are never mentioned in any test or probe are the ones nothing has
ever measured.

## Re-running

```bash
python3 tools/audit_unreachable_branches.py scripts scenes
```

Validate it first. If it does not report `"emergency"` under `match posture`, it
is broken again and its output means nothing.

---

## The numeric half, addressed by proxy

Added 2026-08-16. Instrument: `tools/audit_unmeasured_constants.py`.

The section above says the numeric half of §0 — a threshold outside the
distribution it acts on — needs a runtime measurement per constant and does not
scale to a sweep. That remains true. What *is* available statically is the
profile every §0 defect this repository has found has shared:

> **a constant that appears in exactly one comparison, and which no test and no
> probe has ever named.**

- `SERVE_PACE_RELIEF_FLOOR` — one comparison, never measured, stopped the launch
  search before the serve became feasible.
- The flat serve net-clearance margin — one comparison, never measured, sat where
  a function belonged.
- `RECOVERY_HEAVY_FORCE` — its own comment records the threshold landing outside
  the range force could reach, so no ball in the game could knock anyone down.

A constant a gate reads by name has been thought about. One that only ever
appears in a single `if` has not necessarily been.

### The headline is the ratio

| | count |
|---|---|
| numeric constants declared across the tree | **1,392** |
| named by any test or probe | **171 — 12%** |
| read in exactly one comparison and named by nothing | **189** |

**Seven eighths of this project's tuned constants are not mentioned by a single
test or probe.** That is not 1,213 defects — most are perfectly reasonable and
many are not thresholds at all — but it is the population every §0 defect so far
has been drawn from, and nothing currently distinguishes a measured constant from
an unmeasured one except reading the comment above it.

The 189 candidates are the sharp end: they decide exactly one thing, and no
instrument has ever looked at the distribution they decide it on. The simulation's
share includes `MAX_APPROACH_ANGLE_DEGREES`, `RECYCLE_DEPTH_SHARE`,
`STANDING_JUMP_FRACTION`, `APEX_WINDOW`, `CLOSE_FOR_ONE_ARM`,
`SETTER_COMMIT_LEAD_SECONDS` and `MIN_USABLE_SPAN_METERS`.

### What a candidate is worth

Nothing on its own. The list is a *reading order*, not a defect list — the way to
use it is to take one constant, measure the distribution it acts on, and either
find it inside (and add the probe, which moves it out of the candidate set
permanently) or find it outside (and have a §0 finding).

The serve pass did exactly that twice, one constant at a time, and both times the
constant was in this profile.

### Instrument note

The first version searched every constant against every line and did not finish
in two minutes across 224 files. Rewritten to one pass extracting upper-case
identifiers per line. Same answer, seconds instead.

### Re-running

```bash
python3 tools/audit_unmeasured_constants.py scripts scenes tests tools
```

The count of constants "named by a test or probe" is the number worth watching
over time. It should go up.
