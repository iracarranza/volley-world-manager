# Match Presentation Integration — Implementation Spec

## Goal

Regional venue identity, club kits/marks, broadcast UI, announcers, camera direction and signature VFX must appear in the real MatchScreen while RallyResult/event playback remains authoritative.

## Current boundary observed on `main`

`MatchScreen.load_and_play_rally()` consumes `RallyResult`, builds player names/handedness/physical profiles, calls `MatchCourt3D.setup_players()`, then drives the real event sequence. This is the integration point. Do not replace it with staged render state.

The current scene still presents a proof-oriented HUD:
- full-width top `3D MATCH ENGINE` control bar;
- centered bottom panel ~1040 px wide;
- `DetailLabel.text_overrun_behavior = 3`, which permits the commentary/detail truncation seen in gameplay;
- DynamicCourtCamera already exists and should be retained.

## Desired authority flow

```text
Fixture
├─ home identity ─────→ home roster visual profiles → home kit/marks
├─ opponent identity ─→ opponent roster/profile     → away kit/marks
└─ venue identity ────→ MatchCourt3D venue skin/geometry/backdrop

RallyResult/events ───→ MatchScreen playback ───────→ actors + ball
                                          ├────────→ broadcast score/state
                                          ├────────→ commentary
                                          ├────────→ camera director
                                          └────────→ signature VFX
```

Fixture/team/venue data chooses appearance. Rally events choose action. Presentation chooses framing only.

## Broadcast shell

### Persistent score bug — top-left

Normal state: region/team display names, point scores, set number/set count, serve indicator. Compact live-rally state may reduce footprint but must preserve both names/scores + set context.

### Commentary + announcers

Test top-right and extreme bottom-right against the same real rally states. Default = placement with least action/ball occlusion. Longer dead-ball analysis may expand.

Text:
- word-wrap;
- no ellipsis/truncation;
- bounded width, variable height;
- if hard maximum is required, paginate/advance rather than discard semantic text.

Announcers are dedicated neutral Volis, not court-player crops. Reuse PlayerActor3D/headshot visual construction but no team kit/region assignment. Two persistent commentator identities are sufficient for first draft. Current speaker emphasized; reaction states restrained.

### Bottom ribbon

Move playback/camera controls from top bar to a compact bottom ribbon over runoff/dead visual space. Preserve Pause/Replay/Skip/speed/Broadcast camera and existing dynamic-camera behavior. Free/Follow/zoom capabilities remain presentation controls, never simulation authority. Ribbon may fade/recede after inactivity later; first implementation should not require a new timing constant merely for that polish.

### Rally/dead-ball hierarchy

Live rally: score + short commentary call when present + minimal/faded controls.
Dead ball: commentary analysis + contextual lower third/replay affordance may expand.
Debug/movement-proof instrumentation remains available but outside normal broadcast hierarchy.

## Venue model

Fixture venue must be independent from opponent identity even when ordinary schedules derive venue from host.

Minimum persisted concept:
- `venue_id` (stable identity; backward-compatible default/derivation);
- host/home identity remains separate.

Normal scheduled match: derive host venue where existing schedule semantics determine host.
Friendly/exhibition/neutral fixture: expose venue selection if fixture setup already exposes editable settings.

Venue owns visual environment only: court surface/design, runoff, architecture/backdrop, lighting, spectator structure. It does not alter rally physics unless a future explicit product rule says so.

## Venue geometry first-draft standard

All regional venues should read as volleyball spaces before regional decoration:

`court → substantial free/runoff zone → officials/media separation → raised spectator tier → regional backdrop/architecture`.

Do not place bleachers immediately against playable court. Raised seating should create depth in low/cinematic cameras. Regional identity should come from architecture/material/structure + restrained motifs, not dense decorative props.

Pāwa Hitō priority: preserve its identity while increasing depth/runoff and lifting spectator mass away from court level.

## VFX

Signature VFX must consume the actual signature/event state. No VFX may imply a contact/outcome that the rally did not resolve.

Visual grammar target: transient field/aura/pulse/tendrils integrated with action; avoid rigid wire/hot-glue geometry.

Foresight: pre-contact read/prediction, movement beginning before strike; visual may communicate a projected/uncertain read and must allow inaccurate prediction.
Heroics: reactive explosive rescue with narrow actionable window; energy follows urgent body/reach/chase rather than implying generic dig-quality buff.
Other signatures: read current design/source semantics before drafting; effect communicates mechanic rather than generic power.

## Verification

Use real MatchScreen/RallyResult playback for integration certification. Staged render scenes are composition tools only.

Capture representative states:
- serve/high ball;
- set→attack→two-person block;
- block touch→dig/coverage;
- terminal/dead ball;
- ≥2 venues/regions;
- normal + compact score;
- both commentary placements before selecting default;
- signature examples from their real triggering contexts where available.

Review for ball/player/UI occlusion, court depth, kit/mark readability, commentary truncation, and whether any presentation layer fabricates simulation truth.
