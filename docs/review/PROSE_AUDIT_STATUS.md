# Prose audit: what is closed and what is left

Companion to `prose_audit_findings.json`, which carries the findings
themselves. This file records the state, so the next reader does not have to
re-derive it by grepping 128 quotes.

## Where it stands

**103 of 128 findings closed. 25 open, and 24 of those are not comment work.**

| Kind | Open | What it is |
|---|---:|---|
| `vibe-code` | 11 | Code structure — duplication, a helper that should exist |
| `monkey-code` | 13 | Code structure — a pattern copied without its reason |
| `redundant` | 1 | Comment |

**Every `meta-commentary`, `tells-not-shows` and `overlong-narrative` finding
is closed**, along with all but one `redundant`. What remains is a *refactoring*
backlog wearing the same label, and it should be scheduled as one — it changes
behaviour surfaces, so it wants its own predecessor measurement and its own
balance-probe reading. The comment pass did not touch code.

## What the comment pass did

Measured before and after, on the same tree:

| | Before | After |
|---|---:|---:|
| `scenes/components/player_actor_3d.gd` | 47.9% | 46.7% |
| `scripts/simulation/rally_simulator.gd` | 23.2% | 22.8% |
| repository-wide `.gd` | 29.4% | 29.3% |

About 200 comment lines removed. The repo-wide ratio barely moves because the
file totals shrink with it — **the ratio is the wrong instrument for this work**
and is recorded only so nobody quotes it as progress. The honest figure is the
line count and the block lengths.

## The three shapes that came up repeatedly

**Epitaphs.** Three separate blocks explained why a *deleted* thing was deleted:
`OPPONENT_SERVE`/`OPPONENT_BLOCK`/`OPPONENT_DEFENSE`, `_best_blocker()`, and
`_best_positioned_defender()`. A reader could not find any of them. A deleted
function's obituary belongs in the commit that deleted it.

**Duplication across sites.** One four-line block about publishing a term beside
the pressure it is contested against appeared at **three** sites. The fix is not
to keep the essay at one site and delete the others — it is a two-line NOTE at
each, which is what `CLAUDE.md` asks for.

**Comments on the wrong key.** Two were attached to something they did not
describe: a `_turn_toward` doc sitting 88 lines above its function with another
function in between, and a dig-timing note above `"contact_recovery"`. Both were
invisible while the prose around them was long enough to skim.

## What was moved rather than cut

Cutting prose is only safe once the record has somewhere to live.

`MOVING_ORIENTATION.md` §7 now holds the open-up cone finding — that at ninety
degrees the membership test put perpendicular travel exactly on the boundary, so
the lateral bound written to make a middle look like a middle could never fire
for a middle — with the 4,727-leg measurement behind it. The constant carries a
two-line NOTE pointing there.

## Two gaps admitted rather than explained away

Both were comments asserting a justification nothing measures:

- `AIRBORNE_ELEVATION` / `GROUNDED_ELEVATION` claimed to sit above settling
  noise and below any real jump. **No probe reads either constant.** The NOTE
  now says both were picked by eye.
- `SPRINT_COST_MULTIPLIER` quoted the design requirement for a sprint/walk
  separation, which is real, as though it justified `3.4`, which it does not.

Both now point at `FAILURE_MODES.md` §0. An unmeasured threshold that says so is
worth more than one with a confident paragraph above it.
