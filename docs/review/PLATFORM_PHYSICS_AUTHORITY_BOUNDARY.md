# M4 platform physics: prepared authority boundary

Run: 2026-08-17, after controlled-dig intent repair `6f26af6`. Instrument:
`tools/run_platform_contact_context_probe.gd`. No production resolver, rollout,
feature flag, event outcome, animation or tuning value changed.

## Result

M4 has reached the last boundary that can be crossed from repository facts
alone. The current checkout now publishes or can derive, without a new
parameter:

```text
incoming contact velocity/components where the trajectory owns its vertical state
+ contact position/height/time
+ body journey velocity and body-to-ball offset
+ posture/reach margin/read error
+ target, height and arrival intent anchors
+ the ratings currently spent by the live path
+ the canonical legacy outgoing launch where a resolver-owned ball exists
```

The probe joins these facts after resolution. It does not write metadata back to
the rally, call a shadow resolver, or promote a display fallback into physics.

## Current fact coverage

Fixed population: seeds 23000–23299, once with each serving side; 600 rallies,
785 platform events.

| family | events | successful | authoritative incoming xyz | resolver-owned outgoing xyz | body/offset/intent/ratings |
|---|---:|---:|---:|---:|---:|
| serve reception | 484 | 475 | 484 | 484 | 484 |
| controlled dig | 277 | 87 | 230 | 87 | 277 |
| attack coverage | 24 | 24 | 0 | 0 | offset/intent/ratings 24; body velocity 8 |

The 47 digs without incoming xyz retain horizontal trajectory derivatives but
do not own enough vertical launch/contact-height state to call the third
component physical. Attack coverage has no contact resolver. Its event receives
a display fallback later in the event-normalisation pass; the probe deliberately
reports no outgoing ball for it.

Observed legacy output remains an audit baseline, not physical evidence:

- controlled-dig outgoing speed: 6.01 / 7.10 / 7.65 m/s min/median/max (87);
- reception outgoing speed: 7.39 / 8.66 / 12.08 m/s (484);
- actual endpoint to stated intent anchor: 0.02 / 0.78 / 8.38 m (571);
- derived contact-arrival speed differs from the already-published incoming
  launch-speed scalar by 0.00 / 2.97 / 23.12 m/s (714), which is why the future
  relation must consume a vector at contact rather than relabel the launch
  scalar.

These distributions say what the old model emits. They do not authorize a
retention coefficient, an angle envelope or execution spread.

## T1–T3 evidence disposition

### T1 — incoming to outgoing velocity: still unmeasured

Callupe et al., *Testing protocol for evaluating underhand serve-reception
biomechanics in volleyball*, demonstrates a launcher plus synchronized force,
IMU and video protocol. It reports an approximately 13 m/s launch and 7.5 m/s
landing speed, but publishes body force/angle results rather than a paired
post-contact ball track. The publisher and repository expose no raw trajectory
supplement from which outgoing velocity can be recovered.

Nikolaeva and Markov formulate the right dependency—absolute collision speed
from ball, body-centre and forearm motion, followed by a rebound relation—but do
not measure its restitution/compliance parameters. A theoretical function with
unknown coefficients does not supply T1 magnitudes.

**Missing:** paired pre-contact and post-contact ball velocity, synchronized to
platform/body velocity and circumstance, with ball model and pressure recorded.

### T2 — reachable angle interval: still unmeasured

Published successful departure angles are selected and realized trials, not the
minimum and maximum a player could physically produce. None of the reviewed
studies varies contact height, lateral/off-axis reach and body motion while
testing angle limits. The Russian ballistic calculation solves what launch is
needed to reach a setter; it does not establish which launches a platform can
reach.

**Missing:** feasible minimum/maximum departure direction conditioned on contact
height, body-to-ball offset, platform/body velocity and posture/reach margin.

### T3 — selected to realized angle: only scale-informed

Ridgway and Hamilton report approximately 3.4° standard deviation in realized
projection angle for both low- and high-skilled groups. That distribution mixes
different intentions, player bias, delivery variation and measurement error. It
does not measure error from a selected launch and does not establish a
skill-to-sigma slope. Paulo et al. track incoming serves and pass efficacy, not
the outgoing ball selected-versus-realized relation.

**Missing:** repeated declared/imposed launch intent and realized launch vector
for the same circumstance, across skill tiers, retaining failed trials.

## Route A — minimal measurement capture

Use one synchronized 3D coordinate frame and retain every attempt, including
misses and balls outside the requested target.

1. Track the ball centre for at least three samples immediately before and
   after contact. Use at least 240 fps; higher speed is preferable if contact
   impulse itself is to be resolved. Record ball model, pressure and launcher
   setting.
2. Track the platform midpoint/orientation, wrists/elbows, trunk or body centre,
   feet and floor. Derive contact time/position/height, platform/body velocity,
   body-to-ball offset and planted/moving/reaching/off-axis circumstance in the
   same frame.
3. Repeat controlled incoming speeds and bearings for a free ball, a serve and
   a driven attack. Impose or record the requested setter target so the selected
   outgoing launch is reconstructible.
4. For T2, deliberately sweep requested target height/direction under fixed
   planted, moving and constrained-reach fixtures until both successful and
   failed bounds are observed. Do not infer a bound from ordinary successful
   passes.
5. For T3, repeat identical incoming ball, circumstance and requested launch
   across skill tiers. Compute angular deviation from each trial's selected
   launch only after T2 has classified the request as reachable.

This is the smallest route that measures all three relations rather than fitting
the current simulator to itself.

## Route B — minimum authored game abstraction

If measurement is not the chosen route, the design owner can explicitly
authorize seven shared calibration parameters. Their values would be game
calibration, not biomechanical findings:

| relation | minimum parameter | semantic ownership |
|---|---|---|
| T1 | passive incoming-pace retention | energy from the arriving ball that remains after a neutral platform contact |
| T1 | active platform/body velocity gain | outgoing contribution from the platform/body moving through contact |
| T2 | planted minimum departure angle | lower feasible boundary for a normal squared platform |
| T2 | planted maximum departure angle | upper feasible boundary for a normal squared platform |
| T2 | circumstance narrowing rate | how reach/off-axis/body-state severity contracts that interval; it cannot select the ball |
| T3 | weak-technique angular sigma | execution deviation from a reachable selected launch |
| T3 | elite-technique angular sigma | other endpoint of the same monotonic technique mapping |

There remains one shared platform model. Contact purpose may choose a launch
inside the interval, but no reception/dig/coverage apex band may fabricate its
own flight. The current output distribution may be used to observe behavior
delta, never as the physical source of these values.

## Acceptance gates for either route

- a body that cannot contact the ball remains unable to create an outgoing ball;
- easy feasible contacts remain playable for weak and elite volis;
- difficult feasible contacts preserve strong monotonic attribute leverage;
- T1 changes with incoming contact pace and body/platform motion;
- circumstance narrows T2 but never chooses or directly degrades a ball;
- intent/tactics selects only within the feasible interval;
- T3 is deviation from the reachable selected launch, not punishment for an
  unreachable request;
- one outgoing launch drives free flight, interception, playback and result;
- reception's known attribute double-spending is not inherited accidentally;
- paired-seed production outcomes remain identical while the model is shadow.

## Required owner decision

The next implementation would require an unmeasured magnitude. Choose either:

- **A — measure:** collect the fields above, then bind T1–T3 to those data; or
- **B — author:** authorize the seven shared game-calibration parameters and
  their acceptance gates, with no claim that the values are measured physics.

Until that decision, building a shadow envelope would only wrap guessed
constants in correct architecture.

## Primary sources checked

- Callupe et al.: <https://doi.org/10.1177/17543371221106360>
- Ridgway and Hamilton: <https://ojs.ub.uni-konstanz.de/cpa/article/view/2336>
- Nikolaeva and Markov: <https://top-technologies.ru/article/view?id=36225>
- Paulo et al.: <https://doi.org/10.3389/fpsyg.2016.01694>
- Kapidžić et al.: <https://www.iiste.org/Journals/index.php/JEP/article/view/12341>
- Schneider et al.: <https://doi.org/10.1177/1754337118823996>
