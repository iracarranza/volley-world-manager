# Discussed but not implemented

Shared backlog for the two-agent workflow (Claude on the container, Codex on
the local machine). Everything here was designed, agreed, or half-built in
conversation and is *not* in `main` today. Measured at `7d94cdd`.

Order within each section is rough implementation order, not priority.

---

## 1. Body types — in progress

Branch: `claude/body-types-wip` (**634/636 checks — do not merge**).

Landed on that branch:

- `body_type` on `VolleyballPlayer` (categorical, alongside `dominant_hand`,
  deliberately *not* in `ABILITY_ATTRIBUTES`), serialized both ways.
- `BODY_TYPES` / `BODY_TYPE_METRICS` (height, mass, wingspan) /
  `BODY_TYPE_ATTRIBUTES` in `player_generator.gd`, applied to ceilings before
  storage, wired into both generation paths.
- Uniform assignment across all regions, no regional weighting — the one rule
  in `docs/design/BODY_TYPES.md` that must never be softened.

Still missing:

- **The `SystemFitProfile` shifts.** This is the primary layer per §2 of the
  design doc — body type is supposed to move `ideal_value` / `tolerance` /
  `in_system_bonus` so a Cani setter and a Feli setter are *suited
  differently*, not ranked. Only the secondary metric/attribute/ceiling layer
  is in.
- **Two failing balance checks**: `home stuff-block rate remains below the
  prototype balance ceiling`, and `physical serving creates more pressure,
  aces, and errors across six career seeds`. Untested hypothesis: the block
  one is probably real (Avi moves `jump` and `block_timing`, which feed
  blocking directly); the serving one may be an underpowered six-seed
  directional test now carrying extra per-player variance rather than a true
  regression.
- **Distribution-flatness regression test** — assert every region produces
  every type in equal proportion, so the universal-constant rule can't be
  eroded by a later tuning pass.
- **Ceiling-persistence test** — assert the ceiling deltas survive a
  save/load round trip.
- **One line in `docs/world/STYLE_AND_SETTING.md`** — that doc still says
  "everyone who isn't a manager is human." Body types either sit inside that
  as morphological variation or the sentence needs a light edit. Fix the
  vocabulary before it reaches twenty strings of news copy.
- **Surfacing in UI** — `body_type` appears nowhere in `scenes/`. It should
  read as flavour on the player dossier, never as a scouting category.

## 2. Regional strength — the unimplemented half

From `docs/design/REGIONAL_STRENGTH_AND_MINOR_REGIONS.md`. The talent-tier
affinity, positional affinity, roster capacity and the six minor regions all
landed; these did not:

- **`sixnet_prestige`** — a region's standing, so the Sixnet has a pecking
  order rather than six equals.
- **`region_prime_history`** — regions that were strong in a past era and
  aren't now, giving the world a memory.
- **Specialty-budget conservation** — regional specialties currently *add*
  ability with nothing paying for it. Without a conserved budget every future
  specialty inflates the world.
- **Challenge relegation** — the promotion path between the minor tier and
  the Sixnet.

## 3. Minor regions as playable

Explicitly deferred by the user ("doesn't need to be within scope
currently"), and the stated blocker has since been removed:
`docs/calibration/MINOR_REGION_POPULATION_2026_08_03.md` shows every minor
region already fields a starting seven and a 14-player squad at the current
4,000, so **no population bump is needed**. What remains is career-setup and
UI work only — `Regions.playable_names()` returns `SIXNET_PARTICIPANTS` and
would need to widen, plus whatever competition structure a non-Sixnet career
plays in (which is the same question as challenge relegation, above).

## 4. Career dashboard — the part of the rework that regressed out

The nav dropdown, Home news panel, Team sub-tabs and the aggregated lineup
wheel are all in. Two Roster-tab items from the agreed plan are not in the
current scene:

- **Reserved space for the 3D player visualizer.** The `RosterExtra` column
  holding `Placeholder3D` is gone from `career_dashboard.tscn`; the Roster
  profile is now `IdentityPanel` + `WheelPanel` only. The user asked for the
  space to exist before the feature does.
- **Biography block.** `home_region` / `club_region` / `traits` are surfaced
  in the Player Dossier popup rather than inline on the Roster tab. This may
  be an intentional Codex improvement rather than a regression — worth
  confirming before re-adding anything.

## 5. Flavor events

The Home news panel exists and is fed by a stand-in feed built from real
completed fixtures. The actual flavor-event system — the thing the panel was
built to hold — does not exist anywhere in `scripts/`. No data model, no
trigger, no copy.

## 6. Staff

`StaffPlaceholder` is a reserved panel on the Team overview. There is no
staff system: no hiring, no coaching effects, no staff model. Confirmed as
placeholder-only scope at the time; still open.
