# Current Textbook / Architecture Status

Last source audit for this textbook pass: **2026-08-22**.

This page is a **fast orientation**, not a substitute for live source. The rally engine is moving quickly; use the linked canonical design/review docs for exact certification status.

## Where to start

- Human learning/maintenance: [README.md](README.md) → relevant part/chapter.
- Search by question/symbol: [INDEX.md](INDEX.md).
- Current rally phase/status: `docs/design/RALLY_MILESTONES.md`.
- Current action-space target: `docs/design/RALLY_ACTION_SPACE.md`.
- Detailed rally proof/handoff: current files under `docs/review/`.
- Old Gate-era textbook/handoffs: [LEGACY.md](LEGACY.md), historical only.

## Project runtime shape

**VERIFIED:**

- Godot drives the application from the configured project/main scene.
- `CareerManager` / `GameManager` are long-lived manager/autoload services.
- `scenes/application.gd` routes major screens, lazily constructs expensive code-built screens, applies theme/style passes, and coordinates screen wipes/reveals.
- UI uses reusable `Control` components, Theme/StyleBox resources, procedural drawing, materials/shaders, and a separate off-screen 3D→2D sticker-bake pipeline.
- Persistent game data is primarily Resource/model based: players, teams, career state, fixtures, staff, rally records, etc.
- `CareerManager` coordinates career creation, calendar/week advancement, training, staff/world/transfer state and save/load.
- World population is persisted separately from the frequently written career state and loaded lazily when needed.
- Training supports squads/regimens, schedule block cost, fractional per-attribute progress, ceilings, fatigue/satisfaction and team familiarity/cohesion consequences.

## Rally architecture — current snapshot

The governing causal target is:

```text
attributes + tactics
→ perception / responsibility / intent / action choice

ball + body state
→ legal + physical feasibility

attributes
→ execution quality

contact physics
→ one outgoing ball

free flight / interaction
→ actual next situation

classification / presentation afterward
```

### Milestones

- **M0 — rally skeleton:** DONE.
- **M1 — responsibility / defensive ownership:** DONE.
- **M2 — physical preparation state:** DONE; one locomotion/opening relation remains explicitly deferred.
- **M3 — body centre vs contact geometry:** DONE.
- **M4 — physical platform contact:** IN PROGRESS. Shared T1–T3 physics exists; controlled-dig development launch exists; coverage physical state exists; production migration/coverage selection remain open.
- **M5 — authoritative free flight / interception:** IN PROGRESS at the last inspected active-branch checkpoint.
- **M6–M10:** future consistency/action-space, continuous actions, side-out certification, tactical A/B, presentation cleanup.

See `docs/design/RALLY_MILESTONES.md` for the canonical wording.

### Current M5 integration boundary

At the last source inspection on active branch `claude/system-fit-serve-receive-von64k`:

- authoritative same-side physical-dig free flight/interception is development-certified;
- intended recipient does not define the endpoint;
- later contacts use exact prefixes of an immutable source launch;
- legal net crossing can become the receiving side's ordinary first-contact problem;
- `OverpassActionSystem` can choose among legal/physical attack and platform-control candidates without fixed attack priority;
- the **control** branch is live-wired at both unresolved-overpass exits and certified with a constructed live fixture;
- a 1,200 ordinary-rally census hit that overpass exit zero times, so ordinary output remained byte-neutral while the constructed fixture proved the path;
- the **attack** live continuation was still the open integration at that exact audit snapshot;
- `ENABLE_PHYSICAL_PLATFORM_DIG` remained false.

If the active rally branch has advanced since this snapshot, inspect `docs/review/OVERPASS_ACTION_HANDOFF.md` before relying on the final two bullets.

## Platform T1–T3

Current shared authored game abstractions:

- T1 pace retention: `0.30`;
- T1 active generation: `6.5 m/s`;
- T2 planted redirection half-angle: `65°`;
- T2 maximum circumstance narrowing: `82%`;
- T3 weak-technique sigma: `7.0°`;
- T3 elite-technique sigma: `1.5°`.

These are explicitly **authored game abstractions, not measured biomechanics**. A recent unit audit also confirmed that reported T3 leverage values such as `0.696 → 0.140` were downstream **spatial error in metres**, not angular units.

## Known next policy boundary

After truthful M5 live overpass continuation, the known M4 blocker is **coverage keep-alive selection**:

> among physically feasible T1–T3 launches, what should a covering player value/select?

Do not answer this with a fixed apex, forced setter, coverage-only physics band, or arbitrary coefficient. It is action/decision policy.

## Future action-space direction

`team_contact_number` is context, **not action type**.

Current overpass play already demonstrates attack/control on contact #1. Future M6/M7 work includes generalizing:

- set/attack/control possibilities across contacts;
- setter dump / attack on two;
- set on one;
- safe returns;
- block-touch ordinary continuation;
- live net rebounds;
- jousts;
- later continuous/deceptive preparation.

These are not all implemented today. See `docs/design/RALLY_ACTION_SPACE.md`.

## Certified family disposition

- **Serve:** certified forward contact; closed absent controlled authority failure.
- **Set:** structurally certified; future cross-contact-form generalization is not a ground-up rewrite.
- **Attack:** structurally certified; reused by overpass attack execution.
- **Block:** structurally certified as an interaction; future nonterminal/joust consistency remains.
- **Platform contacts:** active M4 migration.

## Textbook status

Textbook v2 contains **45 substantive chapters** across seven parts:

1. Godot/GDScript foundations and source tracing;
2. interface/visual architecture;
3. game data/players/career persistence;
4. current rally architecture;
5. rally migration history;
6. management systems;
7. tests/calibration/certification/debugging/extension workflow.

The older `part_01_project` through `part_06_exercises` structure is retained as historical material only.

## Maintenance rule

When this page and live source disagree:

1. trust verified live source/current canonical design/review authority;
2. update the owning design/review document where appropriate;
3. update this page as an orientation snapshot;
4. do not change gameplay merely to make textbook prose true.
