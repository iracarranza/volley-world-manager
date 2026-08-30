# Match presentation gameplay integration

Status: implementation-ready seam specification; no gameplay implementation in this pass.

## Authority rule

The presentation is a consumer of a resolved fixture, `MatchState`, and
`RallyResult`. It must never become a second source of fixture identity, score,
rotation, serve, contact, trajectory, timing, player position, cognition, or
signature success. A gallery may arrange a review tableau, but staged state must
not be accepted by a career or a live match.

In particular, do not change rally resolution, physics, contact semantics, or
the M8 contact-to-contact action model to make a shot look better. Playback may
interpolate between resolver-published facts and cameras may read actor
transforms. It may not repair a trajectory, invent a touch, move a contact time,
or write a rendered position back to `GameManager`, `MatchState`, or a rally
model.

## Audit: what the game actually does today

| Link | Current source and hand-off | State |
|---|---|---|
| Calendar fixture -> opponent | `VolleyballFixture` persists `opponent_region` and `opponent_club_index`. `CareerManager.prepare_fixture()` selects the fixture, calls `GameManager.set_opponent_region()`, then starts the match. The manager assigns the opponent team name, player names, and both region fields. | **Gameplay-live.** Opponent identity is deterministic and persistent. |
| Fixture -> home identity | The career persists its managed region; the managed roster/player data supplies `club_region`. A fixture has no explicit home/away or host field. | **Partial.** A career has an address, but a fixture does not yet identify host or venue. |
| Fixture -> venue | No venue model, venue id, host venue, or selected venue is stored on `VolleyballFixture`. | **Missing.** |
| Teams -> rally | `GameManager.resolve_active_rally()` passes the managed players/current lineup/called play and `opponent_team` into the simulator. `record_rally()` alone advances match score/rotation/statistics. | **Gameplay-live and authoritative.** |
| Roster -> visual profile | The simulator publishes names, handedness, initial positions, and `player_physical_profiles` on `RallyResult`. `_playback_physical_profiles()` includes body measurements/type and resolves one home-side `club_region`. | **Gameplay-live data.** Correct safe presentation input. |
| Profile -> bodies/kits/marks | `MatchScreen.load_and_play_rally()` passes the result dictionaries into `MatchCourt3D.setup_players()`. `PlayerActor3D.configure()` consumes the profile. `RegionalKits` supplies the home regional strip/marks; the opponent is deliberately passed an empty club region and therefore wears the universal away strip. | **Live for home; partial for away.** Regional away identity exists in the fixture/team but is intentionally discarded before presentation. |
| Venue -> court/backdrop | `MatchCourt3D` always instantiates its one common court. Regional architecture, surfaces, lighting, and backdrops are built procedurally by `tools/run_venue_probe.gd` and its visual-gallery subclasses around a production court instance. | **Render-only.** The authored regional venues are tool callables, not runtime assets/data. |
| Rally -> ordinary Match View | `main.gd` resolves a rally, runs the persistent 2D `TacticalCourt` playback, then records its result. This is the default visible match path. | **Gameplay-live.** |
| Rally -> 3D Match View | `MatchScreen` is present in `main.tscn` and can replay the last `RallyResult`, but automatic 3D playback is gated by `ENABLE_3D_MATCH_PLAYBACK = false`. The explicit replay path is live. | **Gameplay-connected but opt-in/deprioritised.** |
| Rally -> captions/commentary | The 2D view derives headline/detail from published rally events. The 3D view displays event label/detail and the result explanation. There is no dedicated broadcaster/commentary model in the Match Screen. | **Live event copy; broadcast commentary treatment is presentation-only.** |
| Rally -> camera | `MatchCourt3D` owns static presets. `DynamicCourtCamera` reads rendered actor transforms, adds Free/Follow/zoom controls, and writes only to `Camera3D`. | **Gameplay-live presentation, safely non-authoritative.** |
| Rally -> signature VFX | Resolver metadata reaches `PlayerActor3D`, which supplies signature cue, charge, success, phase, and contact anchor to `SignatureSurge3D`. A separate signature gallery supplies staged examples. | **Live consumer plus render-only review instrument.** VFX must visualize the published mechanic and never infer success. |

## Target identity contract

### Fixture venue persistence

Add serializable fields to `VolleyballFixture` (with backward-compatible
defaults in `from_dict()`):

* `host_side: StringName` — `home` or `opponent`; default `home` for old saves.
* `venue_id: String` — stable asset id, not a display label. Empty means resolve
  the default at match preparation time.
* `venue_selection_locked: bool` — distinguishes competition-assigned fixtures
  from fixtures in which the manager may choose an eligible venue.

The fixture is the durable source. Do not save a NodePath, procedural build
callable, material, or scene instance. Once a match is prepared, resolve an empty
id to a concrete id and persist it on the fixture before play so reloading the
same fixture cannot silently move the match.

### Default and selectable rules

1. Resolve the host region from `host_side`: career region for `home`, fixture
   opponent region for `opponent`.
2. Ask a presentation-only `VenueCatalog.default_for_region(host_region)` for a
   stable venue id. Unknown/legacy regions return the common neutral hall.
3. A scheduled regional/league fixture is locked to its host's default unless
   competition data explicitly declares venue choice.
4. A friendly, exhibition, or later tournament fixture may expose a selector,
   limited to catalog entries allowed by that competition. The selection writes
   `fixture.venue_id`; a gallery option never does.
5. Completing a fixture retains its venue id for history/replay. Changing the
   player's career region later does not rewrite old fixtures.

Introduce a small data/resource catalog under presentation code. Each entry
contains `id`, display name, region, court surface/theme id, backdrop scene, and
camera-safe bounds. Convert the current tool-only venue builders into reusable
runtime scenes/resources; gallery tools should instantiate the same assets as
gameplay, not remain the canonical venue definitions.

### Fixture teams -> regional kits and marks

At match preparation, build an immutable presentation context:

```text
fixture id, home/away labels, home/opponent region,
home/opponent mark id, home/opponent kit role, venue id
```

The context reads `CareerState.region`, the prepared `opponent_team.region`, and
the selected fixture. It does not mutate either team. Keep `RegionalKits.side_region()`
as the defensive home fallback, but publish both side regions in the playback
profile/context. Choose home/change strips once per side using a deterministic
contrast rule; never choose per player. `PlayerActor3D` should receive an
explicit resolved kit descriptor (or side region + kit role), rather than using
`is_home_team` to discard opponent regional identity. Existing body geometry,
kit definitions, and marks remain unchanged.

### Venue -> regional court and backdrop

Make `MatchCourt3D` expose a presentation-only method such as
`apply_venue(VenuePresentationResource)`. It may replace/materialize court
surface, free-zone, officials/media boundary, spectator structure, environment,
and lighting beneath a dedicated `VenuePresentation` node. It must not change
the tactical-to-world conversion, court dimensions used by playback, actor
positions, ball trajectory coordinates, or simulation constants.

Runtime and render tools must share the same venue scene/resource. The safe
dependency direction is:

```text
fixture.venue_id -> VenueCatalog -> venue presentation asset -> MatchCourt3D
                                             `-> gallery renderer
```

It is never `gallery tableau -> fixture` or `venue mesh -> rally geometry`.

### Real MatchScreen -> broadcast shell

The broadcast shell belongs in/around `scenes/screens/match_screen.tscn`, not in
the simulator and not only in a screenshot tool. Give `MatchScreen` one
read-only `MatchPresentationContext` before `load_and_play_rally()`:

* region/team display names, marks, scores, set counts, and serving side come
  from the prepared fixture and current `MatchState`;
* live/dead-ball state comes from `playback_active` and completion of the
  current result, not from a UI timer guessing whether the rally ended;
* event lower thirds/commentary receive published event/result text;
* the playback ribbon binds the existing speed, pause, replay, skip, camera,
  Free, Follow, and zoom actions rather than duplicating their state;
* replay mode reuses the last immutable `RallyResult` and is labelled replay;
* wrapped labels grow/reflow and never ellipsize authoritative text.

`main.gd` should create the context after `prepare_fixture()` and refresh the
score/serve projection after `GameManager.record_rally()`. Keep the current
order—resolve, play, then record—explicit: while a rally is playing, the score
bug displays the pre-rally score and may show the published serving side; it
advances only from the returned match update. A replay must not record again.

## Implementation work units

1. **Data migration:** add fixture venue fields and round-trip tests, including
   old-save defaulting and retained completed-fixture venue identity.
2. **Catalog extraction:** turn each gallery venue definition into a reusable
   presentation asset and make both `MatchCourt3D` and gallery tools consume it.
3. **Prepared context:** construct and validate the immutable fixture/team/kit/
   venue context at fixture preparation; reject unknown ids to neutral fallback.
4. **Two-sided visual profiles:** publish/consume both side identities while
   preserving the existing single-kit-per-side invariant and away contrast.
5. **Broadcast shell:** bind the real Match Screen to context, `MatchState`, and
   `RallyResult`; preserve all camera/playback controls and explicit replay.
6. **Certification:** play a real prepared fixture, then prove its teams, venue,
   kits, marks, score, serve, commentary, camera, and VFX agree with the saved
   fixture and resolver result. Also load an old save and render neutral fallback.

## Non-authority certification gates

* The same rally seed and inputs produce an identical serialized `RallyResult`
  with the broadcast shell and venue enabled or disabled.
* Changing camera, zoom, compact UI, commentary placement, venue presentation,
  or VFX visibility cannot change `MatchState`, fixture fields, or rally events.
* A replay does not call `record_rally()` and cannot advance score/rotation.
* Gallery scripts accept fixture/context/result snapshots only as read-only
  inputs; their staged tableaux are never importable as gameplay state.
* No presentation code imports or calls rally resolvers. Its only rally input is
  a completed `RallyResult` and published match update/state.
* Playback geometry diagnostics remain visible failures; presentation does not
  conceal them with contact snaps or trajectory edits.

## Remaining integration debt

The safe work deferred from this documentation pass is: fixture schema/save
migration, a venue catalog and extraction of procedural tool geometry into
runtime assets, opponent regional strip/contrast resolution, a prepared
presentation-context type, and binding the new broadcast shell to the real
Match Screen. Until those land, regional venues remain render-only, automatic
3D Match View remains disabled, opponent regional marks are absent in 3D, and
broadcast commentary is a visual draft rather than a gameplay-live subsystem.
