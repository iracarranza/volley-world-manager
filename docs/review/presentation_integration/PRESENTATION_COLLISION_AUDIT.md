# Presentation collision and salvage audit

Audit written before presentation merge or scene-conflict resolution.

## Compared authority

- Integration base: `b8bc9119c7e4d2e7cf9c20f0fc1470504c07c70f`, accepted-M8 documentation line plus canonical M9.
- Presentation proposal: `chatgpt/presentation-m9-parallel-pass` at `680d77f`.
- Gameplay implementation: `codex/gameplay-broadcast-integration` at `b2455be`.
- Presentation-branch merge base: `1a4b88943dd05376719326b7033f4c1ae93396b8`.

The branches directly overlap on only two files,
`scenes/components/dynamic_court_camera.gd` and
`scenes/screens/match_screen.tscn`, but the semantic overlap is broader: the
proposal describes the shell that the gameplay branch implements through the
real `MatchScreen`, fixture data, venue builder, commentary, camera and probes.

## Authority flow to preserve

```text
Fixture/team identity -> kit + venue appearance
RallyResult/events -> MatchScreen playback -> actors + ball
                                   |-> score and commentary
                                   |-> camera framing
                                   `-> truthful presentation effects
```

Gameplay state and rally events remain authoritative. Presentation may select
appearance, framing and readable commentary; it may not synthesize contacts,
movement, scores or tactical consequences.

## `chatgpt/presentation-m9-parallel-pass`

| File | Disposition | Reason |
|---|---|---|
| `docs/implementation/PRESENTATION_INTEGRATION_SPEC.md` | **SALVAGE** | Retain the real-`MatchScreen` authority flow, non-truncating commentary, fixture/venue separation, capture matrix and anti-fabrication rules. |
| `docs/implementation/m9_tactical_causality/00_SCOPE_AND_AUTHORITY.md` | **EXCLUDE** | Competing M9 packet; canonical packet already integrated. |
| `docs/implementation/m9_tactical_causality/01_TACTIC_CAUSAL_MAP.md` | **EXCLUDE** | Competing M9 packet. |
| `docs/implementation/m9_tactical_causality/02_WORK_UNITS.md` | **EXCLUDE** | Competing M9 packet. |
| `docs/implementation/m9_tactical_causality/03_CERTIFICATION.md` | **EXCLUDE** | Competing M9 packet. |
| `docs/implementation/m9_tactical_causality/04_HANDOFF.md` | **EXCLUDE** | Competing M9 packet. |
| `scenes/components/dynamic_court_camera.gd` | **ALREADY IN BASE** | Its `voli_name` crash repair entered the accepted M8 ancestry. Keep that identity source when taking broadcast ribbon/zoom work. |
| `scenes/components/player_actor_3d.gd` | **ALREADY IN BASE** | The stored `voli_name` authority entered the accepted M8 ancestry. |
| `scenes/screens/match_screen.tscn` | **REPLACE WITH GAMEPLAY IMPLEMENTATION** | Useful hierarchy sketch, but its score bug is explicitly unbound and it has no venue, announcer or live score implementation. |
| `tools/check_voli_name.gd` | **ALREADY IN BASE** | Diagnostic for the inherited camera/name repair. |
| `tools/check_voli_name.gd.uid` | **ALREADY IN BASE** | Companion import identity. |
| `tools/check_voli_name.tscn` | **ALREADY IN BASE** | Companion diagnostic scene. |
| `tools/probe_ace_playback.gd` | **ALREADY IN BASE** | Existing real-playback diagnostic; retain. |
| `tools/probe_ace_playback.gd.uid` | **ALREADY IN BASE** | Companion import identity. |

## `codex/gameplay-broadcast-integration`

| File | Disposition | Reason / integration rule |
|---|---|---|
| `.github/workflows/gameplay-broadcast-integration.yml` | **EXCLUDE** | Branch-specific CI policy pins Godot 4.7.2 while accepted certification uses 4.7.1. Toolchain/CI policy is separate debt. |
| `scenes/components/dynamic_court_camera.gd` | **RECONCILE** | Take bottom-ribbon control lookup, compact labels and zoom controls; retain accepted `actor.voli_name` instead of regressing to formatted `identity_label.text`. |
| `scenes/components/match_court_3d.gd` | **INTEGRATE** | Adds the production venue seam and lets the existing court remain playback authority. |
| `scenes/components/regional_venue_3d.gd` | **INTEGRATE** | Shared production/gallery venue builder. |
| `scenes/components/regional_venue_3d.gd.uid` | **INTEGRATE** | Companion import identity. |
| `scenes/components/voli_headshot_view.gd` | **INTEGRATE** | Neutral announcer portraits, separate from court-player crops. |
| `scenes/components/voli_headshot_view.gd.uid` | **INTEGRATE** | Companion import identity. |
| `scenes/main/main.gd` | **RECONCILE** | Take fixture-to-view configuration and exhibition venue selection without disturbing M9 authoring/handoff. |
| `scenes/main/main.tscn` | **RECONCILE** | Take Match View naming and venue option around the accepted tactical scene. |
| `scenes/screens/journal_screen.gd` | **INTEGRATE** | Persist/select venue only where fixture rules permit it. |
| `scenes/screens/match_screen.gd` | **GAMEPLAY AUTHORITY** | Real `RallyResult` playback drives score, commentary state, venue and capture signals. Preserve all accepted M8 playback seams. |
| `scenes/screens/match_screen.tscn` | **GAMEPLAY AUTHORITY** | Use the implemented score bug, commentary/headshot cluster and control ribbon, not the parallel draft hierarchy. |
| `scripts/managers/career_manager.gd` | **INTEGRATE** | Backward-compatible host venue derivation and persistence. |
| `scripts/models/fixture.gd` | **INTEGRATE** | Explicit `venue_id` and opt-in venue selection; opponent and venue stay independent. |
| `scripts/simulation/rally_simulator.gd` | **RECONCILE UNDER M9/M8 AUTHORITY** | Take opponent region in playback physical profiles only; canonical tactical and physical resolution remains authoritative. |
| `tests/test_runner.gd` | **RECONCILE** | Keep existing suite and add venue, fixture, opponent-kit and broadcast-text regressions. |
| `tools/gameplay_broadcast.tscn` | **INTEGRATE** | Runs capture through production Match View. |
| `tools/render_gameplay_broadcast.gd` | **INTEGRATE** | Real-rally six-frame inspection harness; composition aid, never simulation evidence. |
| `tools/render_gameplay_broadcast.gd.uid` | **INTEGRATE** | Companion import identity. |
| `tools/run_venue_probe.gd` | **INTEGRATE** | Convert the old duplicate venue implementation to the shared production builder. |
| `tools/run_visual_court_gallery.gd` | **INTEGRATE** | Break circular preload while retaining gallery coverage. |

## Conflict-resolution order

1. Import the presentation specification only; never import its five-file M9 packet.
2. Merge the gameplay implementation without committing, so excluded workflow and
   manual reconciliations can be reviewed together.
3. Resolve `MatchScreen` scene/script as one unit, then camera control paths.
4. Resolve fixture/venue persistence and the small playback-profile addition.
5. Import and parse before running probes; fail on missing `%` bindings or stale
   node paths.
6. Run the full suite, M9 certificate and real Match View capture. Inspect all six
   frames for score/commentary/ball/player occlusion and event truth.

No presentation branch owns gameplay semantics, and no scene resolution may
replace accepted M8/M9 authority with staged render state.
