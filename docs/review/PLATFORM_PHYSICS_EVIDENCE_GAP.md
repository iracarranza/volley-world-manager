# Platform T1–T3 evidence boundary

Review: 2026-08-17, after attribute-leverage certification. No production or
shadow relation was implemented.

M4 slice 2 needs three authored physical relations:

```text
T1  incoming ball + platform/body state → outgoing speed
T2  circumstance → reachable platform-angle interval
T3  technique → deviation from the selected angle
```

The repository supplies their inputs and a representation precedent. It does
not supply their magnitudes. This review checked primary measured evidence to
determine whether those magnitudes could be bounded without choosing them by
eye.

---

## 1. What the evidence does provide

Ridgway and Hamilton, *The Kinematics of Forearm Passing in Low Skilled and High
Skilled Volleyball Players* (ISBS, 1987), filmed seven low-skilled and seven
NCAA Division I female players for three trials each at 200 frames per second.
It reports:

| group | projection angle | outgoing speed | target success |
|---|---:|---:|---:|
| low skilled | 71.94° ± 3.39° | 12.95 ± 1.32 m/s | 7 / 21 |
| high skilled | 63.74° ± 3.42° | 10.27 ± 2.12 m/s | 17 / 21 |

It also records longer contact time for the high-skilled group (0.013 s versus
0.009 s) and interprets their lower, slower, more accurate ball as better force
attenuation and redirection rather than reduced ability.

This is useful evidence for the management-sim premise. Skill changes the ball,
and “more skilled” is not equivalent to “more speed”: the skilled group produced
less pace and a lower projection while hitting the target much more often. It
also places an observed combined projection-angle spread near 3.4° in one
standardised task.

Kapidžić et al., *Kinematic Analysis Forearm Passing in Volleyball at Different
Distances* (2014), studied 31 male university students, five passes each to
targets at 6 m and 9 m. It finds that body centre, shoulder and lower-body
kinematics change with target distance. It does not publish incoming or outgoing
ball velocity and explicitly identifies varying incoming ball speed as future
work.

Schneider et al., *Analysis of mechanical properties of different volleyballs*
(2019), measured volleyball coefficient of restitution in drop tests. Ball
model, gauge pressure and incident velocity all significantly affected the
coefficient. That is a useful warning against a universal ball-only retention
number. It is not a forearm-contact measurement and cannot supply the platform
relation.

The 2026 wall-volley pose-estimation study by Lin et al. validates recognition
of ready posture, contact location and rhythm. It does not report paired
incoming/outgoing ball velocities or a reachable-angle envelope.

---

## 2. Why this is not enough to author T1

The Ridgway/Hamilton study measures the ball **after** contact but does not state
the incoming velocity delivered by the training device. The reported 10.27 and
12.95 m/s therefore cannot be converted into retention, absorption or generated
speed.

The ball-material study supplies a coefficient against a rigid test surface at
low velocity. A moving forearm plus legs is neither rigid nor passive, and the
study itself shows the coefficient changes with incident velocity. Copying that
coefficient would turn a warning about context dependence into a context-free
constant.

The repository's own values cannot fill the gap:

- the block's 0.12–0.72 pace-kept values prove the representation, not a
  platform magnitude;
- the current reception's implied 0.656 median is produced by the apex/distance
  machinery being replaced;
- the current dig spans 0.139–4.228 even while planted, direct evidence that its
  implied ratio is not controlled.

**Missing quantity:** paired incoming and outgoing ball velocity for a forearm
contact, ideally with platform/body velocity and posture, across slow free
balls, serves and driven attacks.

---

## 3. Why this is not enough to author T2

Observed projection angles are selected and executed balls. They are not the
minimum and maximum angles the body could have produced. The standardised pass
task also does not vary contact height, reach margin, lateral offset or posture
in the controlled way T2 requires.

Taking mean ± three standard deviations would describe where that study's 42
passes happened to go. It would not describe a reachable envelope, and mapping
that interval onto planted/reaching/off-axis contacts would be an authored
biomechanical claim with no evidence.

**Missing quantity:** reachable minimum/maximum outgoing angle conditioned on
contact height and body circumstance, or an explicit authored abstraction for
how much arrival margin/off-axis reach narrows a normal planted range.

---

## 4. Why this only partly informs T3

The roughly 3.4° standard deviations are a distribution of realized projection
angles. They combine:

- different intended balls;
- between-player bias;
- execution error;
- measurement error;
- any variation in the training-device delivery.

They therefore provide a useful order-of-magnitude check for a future shadow,
but not “execution error from the selected angle”. The low- and high-skilled
groups also have nearly identical angle standard deviations despite sharply
different accuracy, so this study does not justify an attribute-to-sigma slope.

`AttackSwingModel.vertical_spread_degrees()` supplies the correct functional
precedent—normal angular deviation scaled by technique—but copying its 1.1°–5.0°
attack magnitudes would assume a forearm platform and an arm swing have the same
precision budget.

**Missing quantity:** repeated intended-versus-realized platform angle by skill
tier, or an explicit authored decision that M4 deliberately reuses the attack
precision range as a game abstraction.

---

## 5. Decision boundary

The safe next code is a shadow envelope only after one of these occurs:

1. a source or captured dataset supplies the three missing quantities;
2. the design explicitly authors abstraction bounds for T1–T3 and accepts them
   as game-model values rather than derived volleyball physics.

Without one of those, a shadow implementation would be a set of guessed
constants wrapped in correct architecture. It could produce tables and pass
tests while proving nothing.

## Verdict

**M4 SLICE 2 IS EVIDENCE-BLOCKED AT T1/T2; T3 IS ONLY ORDER-OF-MAGNITUDE
BOUNDED.** Attribute leverage is certified and remains a required before/after
gate. No production outcome, tuning, feature flag or animation changed in this
review.

## Sources

- Ridgway and Hamilton (1987):
  <https://ojs.ub.uni-konstanz.de/cpa/article/view/2336>
- Kapidžić et al. (2014):
  <https://www.iiste.org/Journals/index.php/JEP/article/view/12341>
- Schneider et al. (2019):
  <https://doi.org/10.1177/1754337118823996>
- Lin et al. (2026): <https://doi.org/10.3390/engproc2026134090>
