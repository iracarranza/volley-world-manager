# Sports-sim architecture vs VWM

Research artifact. Reference material, not prose. Written 2026-08-31 against
`3c2cb2d`.

Claim tags: **DOC** documented · **INF** strong inference · **PLAUS** plausible ·
**UNK** unknown. Every VWM claim cites `file:symbol`.

> **Method caveat, stated first.** This began as a `deep-research` workflow run
> (108 agents, 82 completed). Its verification stage hit a session limit and
> produced **systematic false negatives**: it marked 7 claims "refuted" 0-3.
> All 7 were then re-fetched by hand and **all 7 are present verbatim in their
> sources** — the verifier agents were failing, not the claims. The synthesis
> step never ran. Treat that run's refuted list as void; everything below was
> re-verified directly.

---

## 1. Bottom line

**VWM is model C→D: an event simulation, visualised afterward, with a
continuous ball and a partially built continuous substrate that production
never calls.** Not B — B would require a scheduler stepping agents, and the
scheduler exists but has no production caller.

The defect is **not** that movement is "resolver-allotted" (the known issue in
`MOVEMENT_FLUIDITY_DRAFT.md` §Remaining). It is one level worse:

> **Motion is derived three separate times, by three different pieces of code,
> from each other's *outputs* rather than from shared state.**

| # | Layer | Derives motion by | Evidence |
|---|---|---|---|
| 1 | Resolver | `_movement_time()` returns a **duration** | `rally_simulator.gd:9562`; written to events as `movement_duration` at `:1272`, `:1458`, `:1715` |
| 2 | 2D playback | **Re-integrates a path** at 30 Hz to fill that duration | `tactical_court.gd:_integrate_phase_path` → `ShadowMovementSystem.integrate(…, DEFAULT_STEP_SECONDS = 1/30)` |
| 3 | 3D actor | **Re-derives speed** from successive drawn placements | `player_actor_3d.gd:1005` `instant_speed := travelled / frame_time`, smoothed at `:1048`, drives `stride_cycle` |

Layer 2 already knows it is lying and says so:

> "The resolver already spent movement time deciding this traversal was
> possible; re-charging a full turn here would make the player miss the endpoint
> the event says they reached." — `tactical_court.gd:_integrate_phase_path`

That comment is the whole architecture in one sentence. The drawn body is
*fudged into agreement* with a decision made by different code.

**Mature sims invert this.** The sim computes a spatiotemporal target and the
animation layer is *given* it (DOC, §2). VWM's animation layer **reconstructs**
it. That is the single root cause behind wait→snap, slide, and implausible
reaction, and no animation change fixes it.

---

## 2. External architecture findings

### 2.1 The canonical layering

| Claim | Tag | Source |
|---|---|---|
| Autonomous character motion decomposes into **action selection → steering → locomotion** | DOC | Reynolds, GDC99 [S5] |
| Interception via **linear velocity extrapolation over interval T**, explicitly assuming no turn — cheap, sufficient | DOC | [S5] |
| **Arrival** is distinct from seek: desired velocity ramps to zero inside a stopping radius, so the body decelerates *to* the target | DOC | [S5] |

> Reynolds' three levels are exactly the prompt's WHAT → WHERE/WHEN → HOW.
> **This is a 1999 paper and it is still the right decomposition.** Nothing
> below supersedes it; motion matching and warping are implementations of level
> three.

### 2.2 How the render layer is driven

| Claim | Tag | Source |
|---|---|---|
| Motion matching searches a pose DB each frame for the entry matching **current pose + desired future trajectory** — control is a *trajectory goal*, not a state transition | DOC | EA GDC23 [S1] |
| Runtime "continuously find[s] the frame … that simultaneously matches the current pose and the **desired future plan**" | DOC | GDC [S4] |
| Markup on **long mocap sequences** (5–10 min imported directly) replaces small clips in a big transition graph | DOC | [S4] |
| Animation **warping**: "any animation that must reach a **specific point at a specific time**" can be deformed to hit it | DOC | EA GDC [S8] |
| FIFA warps turn animations **on-the-fly** rather than authoring every variant | DOC | [S8] |
| FIFA 22 uses a machine-learned procedural animation system, **ML Flow** (existence DOC; internals UNK) | DOC/UNK | [S2] |
| Single-character motion matching generates the **transition into** multi-character (contact) animations; contact itself is synchronised/authored | DOC | EA GDC21 [S3] |
| EA ships a **generalized multi-character interaction system** across titles | DOC | [S3] |
| Interactions can be anchored to **future intercept positions of moving objects** | DOC | [S3] |
| FM: Motion Matching selects animations "for every player in FM **relative to the context of the match**" | DOC | SI official [S5b] |
| FM: **Inverse Kinematics** used "to reflect the real-life captured data" — IK as the reconciliation layer | DOC | [S5b] |
| FM: players "adjust their position based on the **roles and movement of teammates** around them" — dynamic off-ball, not static slots | DOC | [S5b] |
| Locomotion config lives in **data (XML meta), decoupled from engine code** | DOC(patent) | EA US11620781B1 [S9] |
| Animation content is a **three-level hierarchy**: motions → motion types → archetypes | DOC(patent) | [S9] |
| Sim↔animation communicate through a **blackboard**: systems publish state, neither knows the other's internals | DOC(patent) | [S9] |

### 2.3 The one principle that matters here

Every source above agrees on the same boundary, from three directions:

- motion matching is **given** a desired future trajectory (DOC [S1][S4]);
- warping is **given** a point and a time (DOC [S8]);
- the patent has the sim **publish to a blackboard** the locomotion layer reads (DOC [S9]).

> **The sim owns WHERE/WHEN. The animation layer owns HOW, and never
> re-computes WHERE/WHEN.**

VWM violates this in the opposite direction from the usual mistake: not by
letting animation decide outcomes, but by making animation **re-derive the
journey** the sim already priced.

### 2.4 Volleyball-specific human data

| Claim | Tag | Source |
|---|---|---|
| Reception has **two temporal control bases**: foot movement onset time-locked to *serve contact*; arm/platform onset time-locked to *anticipated ball contact* | DOC | [S6] |
| Therefore body repositioning and platform preparation are **separate clocks**, not one atomic contact | INF (from [S6]) | [S6] |
| Expert serves give receivers **~1.0–1.1 s** flight (16.4 m/s, ~2.6–2.8 m apex) — the whole perceive→decide→move budget | DOC* | [S7] |
| Receiver **initial position + movement direction** predict which platform technique is used — technique is a consequence of pre-contact positioning | DOC* | [S7] |
| Elite spike approach starts **~4–4.5 m** from net, covers **<3 m** | DOC* | [S10] |
| Take-off converts horizontal→vertical: forward **3.5→1 m/s**, vertical **0.8→3 m/s** | DOC* | [S10] |

`*` = source-attributed; the workflow's verification aborted before voting on
these six. Quotes captured, votes absent. Treat as **strong but unvoted**.

---

## 3. Minimum volleyball reference model

Per phase: **perception → decision → pre-contact movement → reachability →
contact → recovery.** This is the target, not a description of VWM.

| Phase | Perception | Decision | Pre-contact movement | Reachability | Contact | Recovery |
|---|---|---|---|---|---|---|
| **Serve** | own toss only | placement + risk | toss, load | — | launch | step in, ~0.2 s |
| **Receive** | flight estimate w/ recognition delay; **~1.0 s budget** [S7] | who calls it (seam contest) | **two clocks**: feet from serve contact, platform from predicted TC [S6] | can feet arrive *and* platform be set? | platform launch | 0.16 s normal / 0.34 s emergency |
| **Transition** | ball + teammates | base vs release | continuous off-ball, role×teammates [S5b] | — | — | — |
| **Set** | pass flight | target hitter + tempo | setter chase to release seat | arrive *and* be balanced | hand launch | ~0.2 s |
| **Approach** | set trajectory | commit / abort | **4–4.5 m run, <3 m covered** [S10] | run-up must fit window | plant | — |
| **Attack** | block shape, seam | lane + shot | **3.5→1 m/s horizontal, 0.8→3 m/s vertical** [S10] | contact height vs reach | swing | land 0.34 s |
| **Block** | setter+ball+hitter cues, **no lane foreknowledge** | commit / hold / assist | close along net, stay square | reach vs contact height | press | land 0.36 s |
| **Defend** | attacker cues | base position | read step, low base | envelope by body state | dig | 0.34 s |
| **Continue** | new flight | re-claim | everyone re-bases | — | — | — |

**Non-negotiables** (each maps to a source above):

1. One clock. Every phase advances on the same timeline.
2. Perception ≠ truth, with latency. (`BallReadSystem` already does this.)
3. Two clocks *within* reception. [S6]
4. Arrival, not seek — decelerate to the target. [S5]
5. Momentum survives phase boundaries.
6. WHERE/WHEN computed once, upstream. [S1][S4][S8][S9]
7. Off-ball is continuous and role-relative. [S5b]

---

## 4. Current VWM pipeline (traced: serve→reception)

> **Superseded as of `1d59d8c` (2026-09-06).** This section describes the state
> this research found. The three derivations it documents — and a fourth and
> fifth it did not — have since been removed; see
> `docs/review/AUTHORITATIVE_MOVEMENT_EXECUTION.md`. The trace is kept because
> the *findings* are what dated, not the tracing, and §4a below states what
> replaced it.
>
> ### 4a. What the pipeline is now
>
> ```
> RallySimulator._committed_path(...)   one solve, one RallyMovementPath
>   published on:  every contact leg, every off-ball leg (_travel_intent),
>                  the staged walk, the actor's own leg (_add_event),
>                  and the leg each held position implies (_phase_hold_paths)
>   → tactical_court._authoritative_phase_path()   interpolates, never re-solves
>   → match_screen plan["path"] → match_court_3d._plan_sample()
>   → player_actor_3d.set_tactical_position(..., motion)   solved speed and facing
> ```
>
> Measured over 150 rallies and 9,473 drawn legs: **81.9% authoritative, 6.9%
> recorded corrections, 11.3% holds, zero contract violations.** The two
> re-solving layers in the trace below (`_integrate_phase_path`, the actor's
> delta-derived speed) are gone, as are the 2D lerp table
> (`_support_target_for_side`) and the 3D straight-line `_plan_sample`, neither
> of which this research identified.

```
main.gd::_resolve_rally
  → GameManager.resolve_active_rally(seed)          game_manager.gd:499
  → RallySimulator.resolve(...)                     rally_simulator.gd:824
      phase order: serve → reception → set → attack → block → defence → continuation
      _initial_home_positions()                     seeds live_positions
      CoverageCalculator.choose_claimant()          picks receiver
      _movement_time(player, start, target, kind)   rally_simulator.gd:9562  ← DURATION, not a path
      _read_adjusted_arrival() / BallReadSystem     perceived ≠ true flight
      _add_event(...)  metadata["movement_duration"] = receiver_move_time   :1272 :1458
      _finish()
  → RallyResult.events
  → main.gd::_play_rally
      tactical_court._build_movement_paths()        tactical_court.gd:654
        _integrate_phase_path()                     :671  ← RE-INTEGRATES the journey
          RallyPlayerState.create(...)              fresh actor, facing pre-aligned
          ShadowMovementSystem.integrate(..., 1/30) :703
      match_court_3d.set_tactical_position(...)     match_court_3d.gd:160,406
        player_actor_3d: instant_speed := travelled / frame_time   :1005  ← RE-DERIVES speed
          → ground_speed_mps (smoothed :1048) → stride_cycle → gait
```

**Key structural facts**

| Fact | Evidence |
|---|---|
| No scheduler-driven loop in production | `RallyScheduler` instantiated **only** at `rally_opportunity_system.gd:36`, a shadow system. Zero production callers. |
| `MOVEMENT_UPDATE` is shadow-only | scheduled `rally_opportunity_system.gd:55`, consumed `:148`; Gate 50 |
| Movement is priced as a scalar | `_movement_time()` returns seconds; events carry `movement_duration` |
| Playback re-integrates | `tactical_court.gd:_integrate_phase_path` runs its own 30 Hz integration |
| Playback pre-aligns facing to hit the endpoint | same function: *"re-charging a full turn here would make the player miss the endpoint the event says they reached"* |
| Actor speed comes from drawn positions | `player_actor_3d.gd:1005`, by design — header says a sim-driven gait "would be right about the player and wrong about the figure on screen" |
| Continuous substrate exists, unused | `contact_envelope_system.gd` (`balance_factor`, `posture_factor` by `BodyState`, takeoff gated while DIVING/RECOVERING/AIRBORNE); `BodyState` = BALANCED/MOVING/REACHING/DIVING/AIRBORNE/RECOVERING |
| Recovery costs are bare constants | `live_reception_integrator.gd:59` `0.34 if emergency else 0.16`; `live_block_integrator.gd:160` `0.36 if airborne else 0.20`; `live_attack_integrator.gd:32` `0.34 if AIRBORNE else 0.18` |
| Traversals were all timed from a dead stop | `rally_simulator.gd:9568` comment: **14,991 of 14,991 legs**; cost 1.020 s vs 0.674 s entering at half speed; **"83% of attack contacts were placed beyond the hitter's reach"** |

---

## 5. Comparison matrix

| # | Principle | VB requirement | VWM behavior | Repo evidence | Verdict | Consequence | Fix direction |
|---|---|---|---|---|---|---|---|
| 1 | One clock | All phases on one timeline | Phase-ordered resolution; scheduler unused | `rally_simulator.gd:824`; `RallyScheduler` only in shadow | **ABSENT** | Ball landing untouched is not expressible | SIM: step agents against the rally clock |
| 2 | WHERE/WHEN computed once | Sim supplies target; anim obeys [S1][S8] | Journey derived 3× independently | `:9562` / `tactical_court.gd:671` / `player_actor_3d.gd:1005` | **CONTRADICTS** | Slide, snap, endpoint fudging | SIM: publish a sampled path, not a duration |
| 3 | Perception ≠ truth | Latency + error | `BallReadSystem` → `BallFlightEstimate` | `ball_read_system.gd` | **MATCH** | — | keep |
| 4 | Two clocks in reception | Feet from TS, platform from TC [S6] | One atomic contact | `_movement_time` + single reception event | **ABSENT** | Platform appears at contact | SIM+TIMING: split prep from arrival |
| 5 | Arrival not seek | Decelerate to target [S5] | Duration only; no deceleration profile in truth | `:9562` | **PARTIAL** | Playback invents the profile | SIM: emit a velocity profile |
| 6 | Momentum across phases | Entry speed carries | Was 0 for **14,991/14,991** legs; guard now exists | `:9568` | **PARTIAL** | Historically 83% of attacks unreachable | SIM: verify guard fires |
| 7 | Body state gates action | Compromised body ≠ balanced | Modelled, flag-gated off | `contact_envelope_system.gd` | **PARTIAL** | Unused in production | SIM: promote |
| 8 | Off-ball continuous | Role × teammates [S5b] | Phase staging + `live_positions` | `rally_simulator.gd` staging comments | **PARTIAL** | Re-bases per phase | AI: continuous re-base |
| 9 | Block has no foreknowledge | Cues only | Correctly identified as next slice; not built | `MIGRATION` / handoff | **ABSENT** | Blocks unreadable as decisions | AI |
| 10 | Recovery is derived | From contact + body state | **Production already derives it**: `_note_recovery` keys on recovery state and scales by `explosiveness`/`work_rate`. Literals remain only in the development-only integrators | `rally_simulator.gd:11445`, 6 call sites | **MATCH** (production) | — | keep; literals are dev-path only |
| 11 | Anim reaches a point at a time | Warp to spatiotemporal target [S8] | Anim re-derives its own speed | `player_actor_3d.gd:1005` | **CONTRADICTS** | Gait fights position stream | KINEMATICS: drive gait from supplied velocity |
| 12 | Contact is synchronised | Ball↔body coupled [S3] | Contact from event metadata; ball drawn from trajectory | `outgoing_trajectory` | **PARTIAL** | Continuity contract carries it | keep, enforce |

---

## 5b. Corrections to this artifact

Found while executing `docs/specs/AUTHORITATIVE_RALLY_MOVEMENT.md`. See
`docs/review/AUTHORITATIVE_MOVEMENT_EXECUTION.md` P5.

| Claim as published | Corrected |
|---|---|
| R5 / row 10: per-contact recovery costs are bare literals | **Production derives recovery.** `_note_recovery` (`rally_simulator.gd:11445`, 6 sites) keys on recovery state and scales by `explosiveness * 0.6 + work_rate * 0.4`. The literals cited are in `live_*_integrator.gd`, which are the **development-only** promoted paths |
| Row 7: body-state gating "modelled, flag-gated off" | **Upheld**, with a caveat: `contact_envelope_system.evaluate()` is shadow-only, but *other* functions in that file are production (`setter_capability_system.gd:217`) |

Neither correction changes the artifact's bottom line — the three-times
derivation of motion — which P0 confirmed directly.

## 6. Root causes

| ID | Cause | Class | Downstream symptoms |
|---|---|---|---|
| **R1** | Movement priced as a **scalar duration**, not a path | SIM | 2, 5, 11 — forces playback to invent a journey |
| **R2** | **No production scheduler**; phases resolve in order | SIM | 1, 4, 8, 9 |
| **R3** | Motion **re-derived three times** from outputs | SIM/KINEMATICS | 2, 11 — the endpoint fudge |
| **R4** | Continuous substrate built but **flag-gated off** | SIM | 7, 10 |
| **R5** | Per-contact costs are **literals** in the *development-only* integrators | TIMING | 10 |

> R1 and R3 are one problem seen twice. Fix R1 and R3 dissolves: if the resolver
> emits a sampled path, playback has nothing left to re-integrate.

---

## 7. Priority changes

### ESSENTIAL

| Change | Why | Touches |
|---|---|---|
| **E1. Resolver emits a sampled path, not a duration.** `_movement_time` already calls the movement model — return the trail it computed and put it on the event. | Kills R1+R3 in one move. Playback stops re-integrating; the actor can be *given* velocity. Directly implements [S1][S8][S9]. | `rally_simulator.gd:9562`; event metadata; `tactical_court.gd:671` becomes a consumer |
| **E2. Delete the second integration.** `_integrate_phase_path` consumes E1's samples instead of running its own. | Removes the endpoint fudge and its comment. | `tactical_court.gd:654-712` |
| **E3. Actor takes velocity from the path, not from drawn deltas.** | Gait stops fighting the position stream; removes the smoothing/noise-floor machinery's reason to exist. | `player_actor_3d.gd:1005,1048` |

### HIGH VALUE

| Change | Why |
|---|---|
| **H1. Split reception into two clocks** — feet scheduled from serve contact, platform from predicted TC. [S6] | The single highest-fidelity gain per line; matches measured human control. |
| **H2. Derive recovery from contact + body state**, replacing the three literals. | One function, three call sites; makes recovery a voli property. |
| **H3. Promote `contact_envelope_system` body-state gating to production.** | Already built and measured. Pure unlock. |
| **H4. Verify the momentum guard fires** — the 14,991/14,991 figure means it never had. | Cheap; large historical error. |

### POLISH

- Stepped/animatic quantisation — **only after E1–E3**; quantising a noisy signal strobes.
- Idle micro-motion (breath, blink, weight shift) — already scoped in `BACKLOG.md`.
- Per-produce inflections.

### NOT NEEDED

- A full scheduler-driven loop **as a prerequisite**. E1–E3 deliver most of the perceptual gain without it. Gate 50 can proceed independently.

---

## 8. AAA techniques to reject

| Technique | Why not | What to do instead |
|---|---|---|
| **Motion matching** | Needs a large mocap corpus and per-frame DB search. VWM has authored pure-function biomechanics and no mocap. | Keep `*_biomechanics.gd`. Adopt only the *interface*: be given a trajectory. |
| **ML-driven animation (ML Flow)** [S2] | Training pipeline ≫ project scope. | — |
| **Generalized multi-character interaction system** [S3] | Volleyball has ~6 contact types, all ball-mediated. No two-body grapples. | Keep the continuity contract. |
| **Full IK reconciliation layer** [S5b] | `PLANT_CORRECTION_LIMIT_DEGREES = 26` foot corrector already covers the visible case. | Keep the bounded corrector. |
| **Physics-driven ragdoll/contact** | Determinism is load-bearing here (seeded rallies, 2,251 checks). | Keep kinematic. |
| **Blackboard indirection** [S9] | Solves team-scale decoupling VWM does not have. | Direct calls. |
| **Long-mocap markup** [S4] | Presupposes mocap. | — |

> The pattern: **adopt the AAA *contracts*, reject the AAA *machinery*.** Every
> essential change above is an interface change, not a technology import.

---

## 9. Sources

| ID | Source | Quality |
|---|---|---|
| S1 | [Motion Matching at EA, GDC 2023 (slides)](https://media.gdcvault.com/gdc2023/Slides/Motion+Matching+at+EA_Delannoy_JC.pdf) | primary |
| S2 | [FIFA 22's animation, GDC Animation Summit](https://gdcvault.com/play/1027746/Animation-Summit-FIFA-22-s) | primary |
| S3 | [Environmental and Motion-Matched Interactions, GDC 2021](https://www.gdcvault.com/play/1027465/Animation-Summit-Environmental-and-Motion) | primary |
| S4 | [Motion Matching and The Road to Next-Gen Animation, GDC](https://gdcvault.com/play/1023280/Motion-Matching-and-The-Road) | primary |
| S5 | [Reynolds, *Steering Behaviors for Autonomous Characters*, GDC 1999](https://www.red3d.com/cwr/steer/gdc99/) | primary |
| S5b | [Football Manager — Truer Football Motion](https://www.footballmanager.com/features/truer-football-motion-match-authenticity-positional-play) | primary (vendor) |
| S6 | [Reception: foot vs arm movement onset (PubMed 25622694)](https://pubmed.ncbi.nlm.nih.gov/25622694/) | primary |
| S7 | [Serve reception technique & flight time, *Front. Psychol.* 2016](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2016.01694/full) | primary |
| S8 | [Animation Warping for Responsiveness, GDC](https://gdcvault.com/play/1012342/Animation-Warping-for-Responsiveness-in) | primary |
| S9 | [EA patent US11620781B1 — locomotion system](https://patents.google.com/patent/US11620781B1/en) | primary |
| S10 | [Spike approach & take-off kinematics (PMC5548173)](https://pmc.ncbi.nlm.nih.gov/articles/PMC5548173/) | primary |

Also consulted, low weight: FM match-engine AI features pages, ESPN FM26
interview, `open-football` (unreliable), steering-behaviour tutorials.

---

## 10. Repo evidence map

| Concern | File | Symbol / line |
|---|---|---|
| Entry | `scenes/main/main.gd` | `_resolve_rally()`, `_play_rally()` |
| Dispatch | `scripts/managers/game_manager.gd` | `resolve_active_rally()` :499 |
| Resolver | `scripts/simulation/rally_simulator.gd` | `resolve()` :824, `_add_event()`, `_finish()` |
| **Movement pricing** | same | **`_movement_time()` :9562**; dead-stop note :9568 |
| Event payload | same | `movement_duration` :1272 :1458 :1715 |
| Claimant | `scripts/simulation/coverage_calculator.gd` | `choose_claimant()` |
| Perception | `scripts/simulation/ball_read_system.gd` | → `BallFlightEstimate` |
| Envelope | `scripts/simulation/contact_envelope_system.gd` | `balance_factor`, `posture_factor`, takeoff gate |
| Body state | `scripts/models/rally_player_state.gd` | `BodyState` enum |
| Locomotion | `scripts/simulation/locomotion_model.gd` | stride × cadence, `MODE_CADENCE_BAND`, `direction_change_seconds` |
| Scheduler (unused) | `scripts/simulation/rally_scheduler.gd` | instantiated only `rally_opportunity_system.gd:36` |
| Shadow moments | `scripts/simulation/rally_opportunity_system.gd` | `MOVEMENT_UPDATE` :55, :148 |
| **2nd integration** | `scenes/components/tactical_court.gd` | **`_build_movement_paths()` :654, `_integrate_phase_path()` :671, `ShadowMovementSystem.integrate` :703** |
| Step size | `scripts/simulation/shadow_movement_system.gd` | `DEFAULT_STEP_SECONDS = 1/30` :44 |
| 3D placement | `scenes/components/match_court_3d.gd` | `set_tactical_position()` :160, :406 |
| **3rd derivation** | `scenes/components/player_actor_3d.gd` | **`instant_speed := travelled / frame_time` :1005**, smoothing :1048 |
| Gait | same | `stride_cycle`, `STEPS_PER_GAIT_CYCLE = 2.0`, `should_open_up()`, `_turn_toward()` |
| Foot plant | same | `PLANT_CORRECTION_LIMIT_DEGREES = 26` |
| Pure motion | `scripts/data/*_biomechanics.gd`, `cogniticon_motion.gd` | seconds-based, no node/state/frame-delta |
| Recovery literals | `live_reception_integrator.gd:59`, `live_block_integrator.gd:160`, `live_attack_integrator.gd:32` | |
| Known issue | `docs/design/MOVEMENT_FLUIDITY_DRAFT.md` | §Remaining, "resolver-allotted" |
