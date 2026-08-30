# Ball Flight, Contact, Quick Tempo, and Rally Query Handoff

Date: 2026-08-25

Status: implemented and validated in the primary worktree; not committed.

Baseline for exact comparisons: clean `58669e1`. Claude comparison:
`505a9b3377f57cd3ca7d38d5957358662e6e821c`.

## Confirmed causes

1. Jump Topspin presentation dropped the launch's published
   `launch_gravity_mps2`. `BallPresentation` reconstructed height with default
   gravity and `MatchCourt3D` carried a second formula, so a spin-adjusted
   launch was displayed as a higher, flatter ball.
2. The steep Jump Float was authoritative, not a drawing error. The pre-change
   intended-angle histogram had a main band through 30 degrees, no samples in
   30--35 except one, then a separate 35--45 degree tail. Claude's `505a9b3`
   correctly measured that playback was faithful and that the launch search
   spent 64--87% of stated pace buying clearance; it deliberately made no
   production change. The additional census identifies the discontinuity that
   licenses a repertoire boundary.
3. The serve/reception seam combined two meanings. The serve trajectory was a
   natural free flight to the floor, while reception was a body-height contact.
   Display code reused the floor duration against the contact height and, before
   this pass, the wrong gravity. The outgoing pass then began from the reception
   event's coordinate rather than the physically played prefix's endpoint.
4. Reception placement put the actor body origin at the ball coordinate. The
   posed platform is 0.877--1.330 m from that origin across the six current
   silhouettes, so a body/head collision was inevitable.
5. Sets, attacks, serves and blocks had the same body-origin assumption. Their
   action poses existed, but playback never measured the posed hand/limb anchor
   before choosing the body's destination.
6. Quick set flight was physically short but playback omitted the hitter's
   resolved pre-release preparation, then normalized the remaining pose over the
   0.18--0.25 s ball flight. A second inconsistency labelled some delivered
   flights T1 even when they were shorter than the published
   takeoff-to-contact interval, leaving no physical clock that could satisfy all
   fields without accelerating the body.
7. Seed search was an ad-hoc CLI predicate collection. The debug path could
   silently force opponent serving, had no shared normalization, no nth-event or
   numeric selectors, no conjunction diagnostics, and could not open a result.

## Task files changed

- Simulation: `scripts/simulation/ball_presentation.gd`,
  `geometric_attack_resolver.gd`, `approach_mechanics_system.gd`,
  `rally_simulator.gd`, and new `rally_query.gd`.
- 3D presentation: `scenes/components/match_court_3d.gd`,
  `player_actor_3d.gd`, and `scenes/screens/match_screen.gd`.
- Debug UI: `scenes/main/main.gd` and `scenes/main/main.tscn`.
- Tests/tools: `tests/test_runner.gd`, `tools/run_seed_search.gd`, and new
  `run_ball_contact_outcome_census.gd`,
  `run_ball_contact_presentation_probe.gd`, `run_contact_anchor_probe.gd`,
  `run_quick_outcome_census.gd`, `run_quick_tempo_choreography_probe.gd`,
  `run_rally_query_probe.gd`, `run_rally_query_ui_probe.gd`,
  `render_ball_contact_evidence.gd`, and
  `ball_contact_evidence.tscn` (plus Godot-generated script UIDs).
- Evidence/docs: `artifacts/ball-contact-evidence/`, `docs/BACKLOG.md`,
  `docs/design/CONTACT_AND_BALL_FLIGHT.md`, and this handoff.

`match_screen.gd` and the main screen files also contain the pre-existing
broadcast/camera integration. Those hunks were preserved. The dirty worktree's
camera, VFX, venue, theme, actor-scene, broadcast-asset and other artifact files
are outside this task and were not reset, staged or reformatted by this pass.

## Authority decisions

The displayed ball now samples one shared `BallPresentation.sample` function.
It consumes the launch gravity, and the court has no private trajectory formula.
A successful serve is drawn only to the descending platform-height crossing of
the same published free flight. The outgoing pass starts at that exact point.
This is a derived realized-display prefix, not a new serve curve or a snap.

The simulator's floor-landing responsibility time is intentionally retained.
Promoting the platform crossing into gameplay was tested and rejected: across
800 fixed rallies it shortened 643 successful contact windows by a mean
0.188487 s (range 0.102480--1.542407), changed 128 claimants, 364 terminal
outcomes and 251 winners, and changed aces 7 to 54. Interception authority must
be redesigned before that endpoint can honestly own gameplay timing.

The 30-degree float limit applies to the intended launch selected by
`_serve_launch`, before `AttackSwingModel.deliver`. Delivered vertical execution
error is not clipped and 5.50% of certified float deliveries still exceed 30
degrees. That boundary is justified as repertoire/intent because it constrains
which float the server elects to strike; clipping after delivery would turn a
choice constraint into an outcome constraint and suppress mishits. It is
style-specific: Jump Topspin retains the spin-supported steep/dive relationship.
The number was selected at the observed empty band separating the main float
repertoire from the lofted tail, not by fitting a historical error rate.

The contact point remains a simulator fact. Presentation poses the real actor,
reads the relevant limb endpoints, and offsets that particular body until its
derived anchor meets the contact. No universal platform or hand offset exists.

Quick durations remain physical. Presentation now draws the already-resolved
approach and plant during the incoming pass, then uses the delivered takeoff
clock through set flight. The reconciliation retains the former
release-progress classification separately for gameplay while publishing the
physically achieved T0/T1 label. The fixed-census output before and after the
tempo/contact work is byte-identical, so these changes add no gameplay delta.

## Measurements

### Serve certification

Controlled certification covered all 36,000 side x style x risk x ability
deliveries.

| style | error | tape-reason error | mean clearance | mean duration |
|---|---:|---:|---:|---:|
| Jump Float, retained intent boundary | 18.75% | 12.78% | 0.807 m | 1.259 s |
| Jump Topspin | 7.57% | 1.44% | 1.133 m | 0.828 s |

Against the clean controlled Jump Float baseline, the boundary changes mean
angle 21.535 to 20.377 degrees, delivered angles above 30 degrees 11.13% to
5.50%, error 18.00% to 18.75%, tape-reason error 12.03% to 12.78%, clearance
0.9560 to 0.8066 m, and duration 1.2908 to 1.2586 s. Jump Topspin is unchanged.
The delivered-execution clamp and a 28-degree intended boundary were separately
measured and rejected.

In the exact 800-rally baseline/final census, errors move 141/800 (17.625%) to
152/800 (19.000%), clearance 0.887736 to 0.699994 m, duration 1.295310 to
1.252563 s, successful receptions 659 to 648, mean reception time 1.349099 to
1.298599 s, and aces 7 to 6. Fourteen rows change serve status/reason, 25 change
claimant, 34 terminal outcome and 25 winner. All of those changes are caused by
the authoritative float launch boundary. The final outcome file is byte-for-byte
identical with and without the contact/tempo presentation work.

### Ball and anchors

`run_ball_contact_presentation_probe.gd` passes over 196 successful receptions:
published/display gravity error 0, serve-to-pass handoff error 0, and
presentation/court sample error 0. Comparable curvature is 0.91270 m for float
and 2.32341 m for topspin. Corrected horizontal platform error is below
0.00000024 m and height error is at most 0.001 m.

`run_contact_anchor_probe.gd` passes 60 silhouette/posture combinations covering
platform, standing/jump/underhand front/back set, attack, serve and block
anchors. Worst ball-centre-to-anchor error is 0.00097084 m, below the 0.003 m
limit. The worst derived vertical body fit is 0.125567 m (Cani, one-hand block);
that is body placement, not ball/contact error.

### Quick tempo

Over seeds 24000--24599, the final physical timing probe reports:

| achieved | n | p05 | p25 | median | p75 | p95 | at 0.10 s minimum |
|---|---:|---:|---:|---:|---:|---:|---:|
| T0 | 47 | .100 | .100 | .126 | .148 | .166 | 15 (31.9%) |
| T1 | 36 | .169 | .181 | .202 | .225 | .255 | 0 |

Median T1 set flight is 0.202 s: visible for 0.202 s at 1x and 0.809 s at
0.25x. Including pre-release preparation it reads for 2.198 s at 1x and 8.793 s
at 0.25x. Physical clock error, takeoff clock error and release-pose seam are all
zero.

The same 600-seed gameplay census has 594 baseline attacks and 581 final attacks.
Achieved T0/T1 attacks move 92/594 (15.49%) to 83/581 (14.29%); their success
moves 70.65% to 71.08%. Requested T0/T1 share moves 223/594 (37.54%) to 216/581
(37.18%). These population changes are downstream of the float gameplay change,
not the tempo playback/reclassification, whose isolated census is identical.

Median T1 trace, seed 24041, opponent serving, set event 4:

- approach begins 0.205 s;
- plant begins 2.047 s;
- setter releases 2.628 s;
- hitter takes off 2.644 s;
- ball meets attacking hand 2.830 s;
- attack ball departs 2.830 s.

Set distance is 1.619 m, release/contact heights 2.190/3.420 m, set flight
0.202 s and takeoff-to-contact 0.186 s.

Near-minimum physical T1 trace, seed 24522, home serving, set event 3:

- approach begins 0.885 s;
- plant begins 2.254 s;
- setter releases 2.686 s;
- hitter takes off 2.663 s (0.023 s before release);
- ball meets attacking hand 2.853 s;
- attack ball departs 2.853 s.

Set distance is 2.471 m, release/contact heights 0.962/3.266 m, set flight
0.167 s and takeoff-to-contact 0.190 s.

## Deterministic query fixtures

The shared query probe passed over 1,200 rallies and repeated every retained
fixture:

- standing front set: seed 24015, opponent serving (21/1200);
- jump back set: seed 24007, opponent serving (176/1200);
- underhand second contact: seed 24004, home serving (319/1200);
- median achieved T1: seed 24041, opponent serving;
- near-minimum achieved T1: seed 24522, home serving;
- Jump Float reception: seed 24000, home serving (997/1200 successful);
- Jump Topspin reception: explicit temporary Jump Topspin repertoire, seed
  24000, home serving.

The seeded roster naturally produces Jump Float on 100% of serves, so the
natural Jump Topspin clause is correctly 0/1200. Terminal BLOCK occurs in 26.2%
of rallies but terminal outcome `tool` is 0%, so no combined fixture is claimed.
The query report exposes these individual rates rather than calling either case
merely rare.

Example commands:

```text
godot --headless --path . --script res://tools/run_seed_search.gd -- --from=24015 --to=24016 --serving=opponent --where="set[1].posture=standing;set[1].side=front"
godot --headless --path . --script res://tools/run_seed_search.gd -- --from=24041 --to=24042 --serving=opponent --query="first set achieved tempo is T1; sequence contains SERVE > RECEPTION > SET > ATTACK"
godot --headless --path . --script res://tools/run_seed_search.gd -- --from=24000 --to=24001 --serving=home --query="serve is Jump Float"
```

The in-game debug panel uses the same predicates, offers explicit serving side
and temporary Jump Topspin/Jump Float fixtures, preserves/restores match and
tactical state, lists seed/side/terminal/contact summary, prints a copyable
command, and opens the selected exact rally in 3D Match View.

The panel now presents that engine through 27 field prompts, context-sensitive
operator/value dropdowns, custom-value entry, removable AND conditions and 11
ready-made searches. Free-form syntax remains available behind an Advanced Text
toggle and round-trips through the same clauses used by the CLI. The scene-level
UI probe verifies the real controls and the captured layout is
`artifacts/ball-contact-evidence/rally_query_builder.png`.

## Validation and visual evidence

- Focused ball/contact presentation probe: PASS.
- 60-case rig contact-anchor probe: PASS.
- 600-rally quick-tempo choreography probe: PASS.
- 1,200-rally shared-query determinism probe: PASS.
- Guided-query scene probe: PASS (12 menu entries including the placeholder,
  27 prompted fields, preset expansion and advanced-text round trip).
- 36,000-delivery serve certification: completed, figures above.
- Full existing suite: `PASS: 2142 volleyball foundation checks`. It emitted
  the repository's known off-tree `global_transform` warnings in the rig stress
  section and leak warnings after completion; no assertion or compile failure.
  It was not rerun after completion.

The clean-baseline and current Match View captures live in
`artifacts/ball-contact-evidence/`. Both 0.25x and 1x sets contain launch,
midflight and contact for Jump Topspin and Jump Float, plus approach, setter
release, set flight and hitter contact for the median T1 fixture.

## Commit recommendation

Ready for review and commit, with the deliberate gameplay delta isolated above.
Do not commit the unrelated broadcast/camera/VFX/venue work as part of these
changes. Recommended commits:

1. share authoritative trajectory sampling and resolve the displayed serve
   prefix;
2. derive rig contact anchors and synchronize contact playback;
3. reconcile quick-tempo clocks and draw pre-release preparation;
4. retain the float intended-repertoire boundary with certification evidence;
5. add shared rally queries, debug UI, probes, evidence and documentation.
