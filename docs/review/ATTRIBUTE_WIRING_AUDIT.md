# Attribute Wiring Audit

Status: **REVIEW / MIGRATION AUDIT.**

Reviewed at `3ce029b` on `claude/system-fit-serve-receive-von64k`.

This document records attribute-wiring inconsistencies exposed by the rally
simulator redesign. It is not a normative attribute specification and it does
not imply that every flagged item should be repaired in the current production
model.

The target causal distinction is:

```text
perception
→ decision / tactical adherence
→ physical feasibility
→ selection
→ execution
→ authoritative ball
```

An attribute may have several downstream consequences, but ideally it answers
one primary causal question. Re-reading the same attribute independently at
several stages can silently spend it more than once.

---

## 1. Priority findings

| Priority | Finding | Current concern | Likely action |
|---|---|---|---|
| High | `serve_accuracy` remains exported/serialized but is outside the current ability/profile contract | Looks like a live attribute although the newer serving attributes replaced its role | Retire explicitly as migration-only, or define a distinct current role |
| High | `tactical_discipline` contributes to generic capability self-assessment | Adherence to the team plan is not the same question as recognizing one's own limits | Resolve semantic contract before expanding tactical intent |
| High | mass appears to be charged twice in live locomotion | `LocomotionModel.cadence_hz()` already prices mass, then `RallyMovementSystem._movement_profile()` multiplies finished speed by another mass factor | Measure fixed-player mass sweep, then remove duplicate ownership if confirmed |
| High | fatigue/state adjustment has multiple authorities | `_rating()`, locomotion, cognition and standalone models do not all consume fatigue/form/confidence the same way | Move toward one explicit effective-state contract per causal stage |
| High | reception attributes are spent repeatedly before the outgoing ball exists | `reception` / `ball_control` contribute to quality, platform feasibility and then execution through both | Do not rebalance old path; let platform-contact replacement remove duplication |
| Medium-high | `unpredictability` has setter and hitter meanings | Defined as setter distribution unpredictability, but also controls hitter preferred set-point jitter/learning resistance | Pick one semantic owner; likely remove it from hitter placement |
| Medium-high | `attack_accuracy` affects repertoire, body/contact control, salvage and final execution | An execution stat participates in too many upstream stages | Narrow toward realized-swing precision as attack architecture permits |
| Medium-high | `decision_making` often improves perception itself | Blurs the intended `perception → decision` boundary | Prefer vision/anticipation/familiarity for perception and decision-making for choice |
| Medium | `serve_aggression` and `serve_variation` mix tendency with capability | Both are scored as monotonic ability although their tooltips partly describe willingness/frequency | Audit whether these belong in ability scoring or should split tendency from proficiency |
| Medium | current-ability scoring omits morphology | Height/wingspan materially alter volleyball effectiveness but do not affect `current_ability_score()` | Decide explicitly whether CA means trainable skill or actual playing ability |

---

## 2. Physical attributes

### 2.1 Mass has two live locomotion penalties

`LocomotionModel.cadence_hz()` already applies a mass-derived turnover factor.
Its own comments explicitly argue that mass belongs in turnover rather than as
an outside multiplier on finished speed.

`RallyMovementSystem._movement_profile()` then computes:

```text
LocomotionModel.maximum_speed(player, mode)
× another local mass_factor
```

This appears to price mass twice.

**Before changing:** run a fixed-player sweep varying only mass and publish
cadence, `LocomotionModel.maximum_speed`, rally maximum speed and traversal time.
If the second multiplier is duplicate ownership, remove it rather than retuning
both terms around each other.

### 2.2 `work_rate` contradicts its own movement contract

`VolleyballPlayer.effort_scale()` says work rate affects how often a voli reaches
their movement ceiling, not the ceiling itself. It is multiplied into cadence,
and cadence × stride is the calculated maximum speed, so in practice work rate
does alter the ceiling.

The rest of the attribute has useful distinct semantics:

- willingness to keep pursuing/covering;
- resistance to fatigue consequences;
- recovery effort;
- greater likelihood of committing to difficult defensive contacts.

The locomotion role needs either a corrected contract or different wiring.

### 2.3 Physical movement still has competing fatigue semantics

The staged `FatigueModel` distinguishes:

```text
working  → small broad degradation
laboured → range / legs degradation
spent    → error pressure
```

but locomotion also applies separate linear fatigue factors directly to cadence
and acceleration. Other consumers use `_rating()`, which applies the staged
model plus match confidence/current form.

The same physical attribute therefore has different effective values depending
on which subsystem asks for it.

### 2.4 `arm_speed` is mostly well recovered, with one approximation to track

`arm_speed` now has real consumers in attack tempo, blocker/floor reads and
attack-power composites. That is preferable to the former inert attribute.

One use remains semantically approximate: some setting logic treats arm speed as
the nearest available proxy for arm-generated setting force. Do not add a new
attribute solely for this yet, but document that `arm_speed` is currently doing
more than its literal name.

---

## 3. Serving

### 3.1 `serve_accuracy` is legacy-shaped state

`VolleyballPlayer` still exports and serializes `serve_accuracy`, but it is absent
from:

- `ABILITY_ATTRIBUTES`;
- `AttributeProfileSystem.CATEGORY_ATTRIBUTES["Serving"]`;
- serving tooltips/profile axes;
- the current canonical serve execution path.

Legacy deserialization uses it as the fallback value for newer serve attributes,
which strongly suggests it is migration debt rather than a current skill.

**Decision required:** either mark/remove it as migration-only state, preserving
old-save compatibility, or give it a distinct current semantic role. Do not leave
it looking like an ordinary trainable current attribute.

### 3.2 `serve_aggression` is partly temperament but scored as ability

Its tooltip describes how readily the voli attempts point-ending pace/pressure.
That is a willingness/tendency question. Generic `aggression` was deliberately
kept out of ability scoring because high is not unconditionally better.

Audit whether `serve_aggression` should mean a trainable technical capability, a
serve-specific behavioral tendency, or a composition of player aggression and
tactical instruction.

### 3.3 `serve_variation` mixes frequency and credibility

Current wording combines:

```text
how often the server changes serve
+
how credibly they can execute those changes
```

Those are different causal questions. The first is selection/tendency; the second
is repertoire/capability. Existing `serve_style_proficiencies` may already own
much of the latter.

---

## 4. Platform contacts: reception / DIG / coverage

This is the largest current double-spending area, but it should primarily be
resolved by the planned platform-contact replacement rather than by tuning the
old formulas.

### 4.1 Reception spends the same attributes through several stages

Current production broadly does:

```text
reception + ball_control + composure
→ reception skill / quality

reception + ball_control + reception_balance + reception_stability + body state
→ platform_feasibility

platform_feasibility + reception_quality
→ execution
→ outgoing pass
```

Thus `reception` and `ball_control` can influence the same outgoing ball through
multiple independent paths.

The target platform architecture should instead make the roles explicit, for
example:

```text
reception technique
→ directional/platform execution skill

platform balance
→ body/platform configuration available at contact

platform stability
→ ability to preserve configuration against incoming force

ball control
→ cushioning / momentum-transfer control

dig control
→ directional control of a defended platform contact

realized launch
→ evaluated pass/dig quality
```

Do **not** rebalance the current weights merely to make the duplication smaller.

### 4.2 `reception_balance` / `reception_stability` may actually be platform attributes

`ContactEnvelopeSystem` uses the reception pair as the default balance/stability
ratings for non-set/non-attack contacts, including DIG-like platform actions.

If the unified platform family keeps that behavior, consider whether the durable
names are closer to:

```text
platform_balance
platform_stability
```

rather than serve-reception-specific names. Decide with the platform-contact
semantic contract, not as a standalone rename.

### 4.3 `ball_control` partly expands physical ownership/reach

`CoverageCalculator._base_reach_meters()` lets `ball_control` increase the radius
inside which a voli can physically own/play a ball.

A limited technical reach effect is defensible, but the causal split should be
examined once platform feasibility exists:

```text
body + wingspan + posture
→ contact reach

technical control
→ quality/feasible transfer from that reachable contact
```

Avoid letting a technical stat become a disguised body-length stat.

---

## 5. Setting

### 5.1 Setter technical attributes need stage contracts

The current cluster is useful but sometimes read at more than one stage:

- `tempo_control`
- `hand_control`
- `set_accuracy`
- `set_balance`
- `set_stability`

A cleaner eventual contract is:

```text
tempo_control
→ tempo relationships the setter can reliably command

hand_control
→ physical/touch redirection capability

set_balance / set_stability
→ body/contact circumstance

set_accuracy
→ precision realizing the selected set target
```

This does not require a current rewrite; it is the standard against which future
setting cleanup should be judged.

### 5.2 `set_disguise` has a strong distinct meaning

Its current role is coherent: mask the mechanics/direction of one release.
Keep this distinct from multi-contact distribution behavior.

### 5.3 `unpredictability` currently has two unrelated owners

The attribute is documented as how difficult a setter's distribution pattern is
to scout across a match.

`HitterPlacementModel` also uses the hitter's `unpredictability` to:

- jitter preferred contact position inside a lane;
- jitter preferred set depth;
- resist learning/settling onto previously successful locations.

A setter being hard to scout and a hitter varying where they want the set are
not necessarily the same skill.

**Recommended direction:** preserve the precise setter-distribution meaning and
find a hitter-specific source for placement variability if that behavior remains
useful.

---

## 6. Attack / block attributes

### 6.1 `attack_accuracy` currently spans too many causal stages

It contributes to:

- width of the credible attack-course repertoire with `shot_variety`;
- contact/body balance;
- salvage/recovery from a missed set path;
- net-body avoidance/control;
- final horizontal/vertical execution spread.

Its tooltip, however, describes precision hitting the intended target while
keeping the ball in play, which is primarily an execution question.

Long-term preferred split:

```text
shot_variety
→ what attack families/bearings are credible

body / approach state
→ what this contact permits

finesse / tooling / feinting
→ specialized technical solutions

attack_accuracy
→ how closely realized swing matches selected swing
```

### 6.2 `approach_timing` is broad but mostly causally legitimate

Good approach timing changes real body state, which then affects reach, balance,
power and available actions. Those downstream consequences need not be duplicate
spending if they all derive from the same improved approach state.

One questionable use is direct improvement of set-path **perception**. Consider
whether approach timing should instead improve the body's ability to adjust to a
read while `court_vision` / `anticipation` own the read itself.

### 6.3 `feinting` appears underwired

`feinting` is generated, trainable and shown in the profile contract, but no
clear promoted attack consumer was found in this audit.

Run a repository-wide inert-attribute check before calling it dead. Its natural
future role is opponent perception: selling a hard swing before a soft/redirected
contact, not a generic attack-quality bonus.

---

## 7. Mental / tactical attributes

The target semantic separation should be kept explicit:

| Attribute | Primary question |
|---|---|
| `court_vision` | What relevant spatial state does this voli perceive? |
| `anticipation` | What specific developing action do they predict before contact? |
| `decision_making` | Given the situation as perceived, how good is the option selected? |
| `composure` | How much do pressure/state disrupt otherwise available judgment/execution? |
| `tactical_discipline` | How strongly do they adhere to the team's assignment/method? |
| `improvisation` | How well do they create a solution when the planned action breaks down? |
| `adaptability` | How readily do they learn/acclimate to unfamiliar roles or methods over time? |
| `ego` | How readily do they revise a decision after committing? |
| `aggression` | How strongly do they pursue terminal/high-commitment actions? |

### 7.1 `decision_making` often improves perception itself

`BallReadSystem` includes decision making in reading ability. The geometric attack
read also blends court vision and decision making before degrading the perceived
block/floor picture.

That collapses part of the desired boundary:

```text
truth
→ perception
→ decision
```

Preferred direction: vision/anticipation/familiarity shape the perceived picture;
decision making evaluates/selects from that picture. Composure may degrade either
under appropriate pressure without becoming their permanent substitute.

### 7.2 `tactical_discipline` has both good and questionable consumers

Good fits include:

- how strongly team attack decisiveness pulls the hitter's own aggression;
- staying with the called offensive method rather than freelancing.

Questionable fits:

#### `AttemptJudgment`

Current `AttemptJudgment.judgment()` uses:

```text
decision_making 50%
tactical_discipline 30%
composure 20%
```

for the question:

> Does this voli recognize that the attempted action is beyond their capability
> and back off?

Recognizing one's own limit is not obviously tactical adherence. In some cases a
high-discipline voli following a difficult called action might persist **more**,
not less.

Resolve this semantic conflict before tactical-intent wiring begins to depend on
`tactical_discipline` more heavily.

> **Resolved 2026-08-16 in `docs/design/PLATFORM_CONTACT.md` §14.** The
> suspicion above is confirmed, and the repository already contained the correct
> contract: `AttackPowerModel.aggression_from` reads
> `lerpf(own_aggression, team_decisiveness, tactical_discipline)`, making
> discipline **a blend weight between individual disposition and the team's
> call** — never a capability and never a threshold.
>
> Under that contract `judgment()` is not merely imprecise, it is **inverted**:
> at all four `backs_off` sites the safer option is also a departure from the
> called action, so discipline should push toward persisting and instead pushes
> toward abandoning. It is also a monotonic-capability use of a non-ability
> attribute, which is the test §8.2 of this document sets.
>
> Recommended split — recognition (`decision_making`, `composure`) separated
> from response (`aggression`, then discipline **only where a call exists**). No
> new attribute; `aggression` already means "how strongly do they pursue
> terminal, high-commitment actions", which is what `backs_off` decides against.
> Weights deliberately not chosen: removal alone moves four live sites and needs
> a measured before/after.
>
> This blocks the block-instruction wiring, which would otherwise spend
> discipline twice at one decision.
>
> **Landed 2026-08-16** — see `docs/review/ATTEMPT_JUDGMENT_SPLIT.md`.
> `judgment()` became `recognition()` (decision_making + composure, renormalised)
> and `persistence()` (aggression, as a signed deviation from neutral);
> `tactical_discipline` left both. Measured: discipline moved the flip deficit
> across 40% of its reachable range and now moves it not at all; aggression's new
> range is the numerical mirror of discipline's old one. One live site moved
> materially — the block's soft-hands rate, 0.0875 → 0.0686 — and the scoreboard
> did not move at all, 410/800 home points before and after. Three coefficients
> remain uncalibrated and are marked as such in the source. The trace also
> corrected the site count: five, not four, and the setter's path is a bare
> in-file call inside `evaluate()` that a `grep` for `.backs_off(` misses.

#### Block contact-envelope balance

`ContactEnvelopeSystem` includes tactical discipline directly in block
`action_balance` alongside block timing and explosiveness. That lets a mental
adherence stat improve a physical/contact feasibility quantity.

Preferred causality:

```text
tactical discipline
→ whether/when/how the blocker follows the assignment
→ resulting body state
→ physical balance / feasibility
```

rather than discipline directly increasing balance.

### 7.3 `composure` risks becoming a superattribute

It currently contributes across reception, ball reads, set-path reads, capability
judgment, setter command, attack restraint, signature actions and confidence
sensitivity.

Most uses are individually plausible. The risk is cumulative spending on the
same contact.

Before changing weights, add or use a per-contact influence trace: for one serve,
set, attack, block or dig, list every direct and indirect place composure affected
the result. Fix repeated causal ownership rather than lowering every coefficient.

### 7.4 `adaptability` mixes long-term learning with instant tolerance

Its clearest semantics are long-term learning/acclimation, and hitter-placement
learning uses it that way.

It also widens multiple immediate system-fit tolerances, making a highly adaptable
voli instantly more tolerant of unfamiliar approach distance, setter release,
block engagement and defensive depth.

Preferred distinction:

```text
adaptability
→ rate of acclimation / learning / unfamiliar-role development

improvisation
→ immediate rally solution when plan breaks down
```

Audit system-fit tolerance before adding more instant consumers.

### 7.5 `ego` and generic `aggression` have strong definitions

Their current conceptual separation is useful and should be preserved:

```text
ego       → resistance to changing a committed decision
aggression → strength of terminal/high-commitment intent
```

Both are correctly excluded from `ABILITY_ATTRIBUTES` because neither has a
monotonic "more is always better" relationship to volleyball ability.

Use that same standard when reviewing serve-specific tendency attributes.

---

## 8. Ability/profile scoring

### 8.1 Morphology is excluded from `current_ability_score()`

`current_ability_score()` is 75% position-weighted ability attributes and 25% all
ability attributes. Height, wingspan and mass are not abilities and therefore do
not enter it.

That creates a deliberate-or-accidental distinction:

```text
CA = trainable skill profile
```

versus:

```text
CA = actual volleyball playing ability
```

If CA means the latter, two otherwise identical middles with radically different
standing/jumping reach should not receive the same score. If CA intentionally
means the former, document that clearly in the player-facing/scouting contract
rather than silently treating CA as total quality.

### 8.2 Ability-vs-tendency should be audited consistently

The current model correctly excludes `ego`, `aggression` and `leadership` from
ability scoring for semantic reasons.

Apply the same test to every raw rating:

> Does a higher value make this voli monotonically more capable, or merely make
> them choose/behave differently?

Priority review candidates:

- `serve_aggression`;
- the frequency half of `serve_variation`;
- any future tactical adherence / risk preference field.

---

## 9. Migration order

Do not turn this document into a broad attribute rebalance. Recommended order:

1. Resolve `serve_accuracy` as explicit migration-only state or a real current skill.
2. Define the Mental/Tactical causal-stage contract before expanding manager tactics.
3. Audit `tactical_discipline`, especially `AttemptJudgment` and block balance.
4. Measure/fix duplicate mass ownership and fatigue authority in locomotion.
5. Leave reception attribute reweighting alone until the platform-contact model replaces `quality → ball`.
6. Resolve setter-only vs hitter use of `unpredictability`.
7. Narrow `attack_accuracy` as the attack pipeline is further causalized.
8. Audit tendency-vs-ability classification for serving.
9. Decide what `current_ability_score()` is intended to mean before adding morphology to it.

---

## 10. Regression principle

The useful invariant for future attribute work is:

> **An attribute should primarily answer one causal question. If that answer has
> several consequences, derive those consequences downstream from the answer
> instead of independently spending the raw attribute again at each stage.**

A mechanically plausible outcome is not sufficient evidence that the wiring is
correct. The audit target is provenance: when a voli succeeds or fails, the
simulator should be able to say whether the cause was perception, choice,
physical circumstance, tactical adherence or execution without the same rating
quietly being all five.
