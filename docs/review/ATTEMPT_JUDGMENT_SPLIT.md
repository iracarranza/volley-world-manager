# AttemptJudgment: recognition separated from response

Run: 2026-08-16, from `32b5871`. Instrument:
`tools/run_attempt_judgment_probe.gd`. **Production behaviour changed.**

`ATTRIBUTE_WIRING_AUDIT.md` §7.2 asked that `tactical_discipline`'s semantic
conflict be resolved before tactical intent starts depending on it.
`PLATFORM_CONTACT.md` §14 resolved it on paper. This is the measurement and the
change.

---

## 1. The live sites — five, and the previous count was wrong twice

Traced from current code rather than from the prior prose, which named four and
described one of them incorrectly.

| # | site | attempted action | `backs_off = true` means | team call in scope? |
|---|---|---|---|---|
| 1 | `setter_capability_system.gd:198`, inside `evaluate()` | the called tempo | take the fastest tempo they can command; the play is abandoned via `_downgraded_assignment` | the play, but it is not passed in |
| 2 | `rally_simulator.gd:493`, `_block_hands_intent` | a kill block | soft-block instead | **an instruction exists and is dead** — §13.2 |
| 3 | `rally_simulator.gd:2534` | home hitter's swing | controlled roll, or emergency tip | the called play |
| 4 | `rally_simulator.gd:4809` | opponent hitter's swing | roll shot | the called play |
| 5 | `rally_simulator.gd:6306` | continuation swing | controlled roll, or emergency tip | none — a transition ball |

**Two corrections to the earlier count.** The setter site was described as a
direct `AttemptJudgment` call; it is not. `SetterCapabilitySystem.judgment()` and
`.backs_off()` are wrappers that **nothing outside the file calls** — the live
path is a bare `backs_off(setter, wanted_deficit)` inside `evaluate()`, which a
`grep` for `.backs_off(` does not find. `evaluate()` is then called twice per
rally, once per side.

**The shared property is what matters.** At all five, the safer option is *also*
a departure from what was called. That is the fact that inverts discipline's
sign.

---

## 2. Before

### 2a. The function itself — exact, one attribute at a time

`backs_off` is deterministic, so the *flip deficit* — the smallest overreach a
voli declines — is the model's entire behaviour for that voli, solved rather than
sampled. Lower means backs off more readily. `OBVIOUS_DEFICIT` is 0.40.

| attribute | 10 | 30 | 50 | 70 | 90 |
|---|---|---|---|---|---|
| `decision_making` | 0.3667 | 0.3000 | 0.2333 | 0.1667 | 0.1000 |
| `tactical_discipline` | 0.3133 | 0.2733 | 0.2333 | 0.1933 | 0.1533 |
| `composure` | 0.2867 | 0.2600 | 0.2333 | 0.2067 | 0.1800 |
| `aggression` | 0.2333 | 0.2333 | 0.2333 | 0.2333 | 0.2333 |

**Discipline moved the flip deficit across 0.16 of a 0.40 scale — 40% of the
reachable range — and aggression did nothing at all.**

> **The first version of this table was worthless and the reason generalises.**
> It tiered the real 15-voli roster, and the `weak` bucket of `decision_making`,
> `tactical_discipline` and `composure` all reported the identical 0.3420,
> because generation correlates mental attributes and it was the same two volis
> every time. A tier table over a correlated population measures the population,
> not the function.

### 2b. The live sites, 800 isolated rallies

| site | attempts | back-offs | rate |
|---|---:|---:|---:|
| attack swing downgrade (3 sites) | 900 | 11 | 0.0122 |
| — home | 467 | 4 | 0.0086 |
| — opponent | 433 | 7 | 0.0162 |
| block soft hands | 754 | 66 | 0.0875 |
| setter tempo downgrade | 900 | 100 | 0.1111 |

---

## 3. The change

```gdscript
## before
judgment = decision_making * 0.50 + tactical_discipline * 0.30 + composure * 0.20
backs_off = judgment >= threshold(deficit)

## after
recognition = (decision_making * 0.50 + composure * 0.20) / 0.70
persistence = aggression
backs_off  = recognition - (persistence - 0.5) * PERSISTENCE_SHARE >= threshold(deficit)
```

**Why each term is where it is.**

- **`decision_making` → recognition.** Judging that an action is beyond you is
  evaluating an option against yourself, which is the attribute's definition.
- **`composure` → recognition.** The recognition happens under rally pressure
  rather than in the abstract; this is the surviving half of the old docstring's
  justification and it was always right.
- **`aggression` → response.** Already defined as how strongly a voli pursues
  terminal, high-commitment actions, and backing off is by definition a decision
  not to pursue one. No attribute invented and no meaning stretched.
- **`tactical_discipline` → neither, for now.** It is a blend weight toward a
  team call, and none of the five sites has a call in scope. It joins
  `persistence` when one does. **Inventing a call so the attribute had somewhere
  to live would have been worse than leaving it out.**

**Three coefficients, none calibrated, all marked in the source.**
`RECOGNITION_DECISION_SHARE` 0.50 and `RECOGNITION_COMPOSURE_SHARE` 0.20 are the
surviving weights at their existing ratio, renormalised so recognition still
spans 0–1 — the smallest change that removes only the term that does not belong.
`PERSISTENCE_SHARE` is 0.30, deliberately the weight discipline vacated:
choosing a new number would have been authoring temperament's importance in the
same pass that removed a term for being unjustified.

**Centred, not offset.** Temperament enters as a signed deviation from neutral,
the pattern `serve_risk + (serve_aggression - 0.5) * 0.70` already ships. A voli
at aggression 50 therefore behaves *exactly* as the old model did with everything
at 50. **This is a re-attribution, not a rebalance**, and that property is
gate-checked.

---

## 4. After

### 4a. The function

| attribute | 10 | 30 | 50 | 70 | 90 |
|---|---|---|---|---|---|
| `decision_making` | **never** | 0.3286 | 0.2333 | 0.1381 | 0.0429 |
| `tactical_discipline` | 0.2333 | 0.2333 | 0.2333 | 0.2333 | 0.2333 |
| `composure` | 0.3095 | 0.2714 | 0.2333 | 0.1952 | 0.1571 |
| `aggression` | 0.1533 | 0.1933 | 0.2333 | 0.2733 | 0.3133 |

Discipline is flat. Aggression now spans **0.1533 → 0.3133 — numerically the
mirror of discipline's old 0.3133 → 0.1533**, because the vacated weight was
reused and centred. The same magnitude of effect, moved to the attribute that
means it, with the sign the other way round.

### 4b. The live sites

| site | before | after | change |
|---|---:|---:|---|
| attack swing downgrade | 11/900 = 0.0122 | 10/903 = 0.0111 | −1 event |
| — home | 4/467 = 0.0086 | 3/469 = 0.0064 | −1 |
| — opponent | 7/433 = 0.0162 | 7/434 = 0.0161 | 0 |
| **block soft hands** | 66/754 = 0.0875 | **52/758 = 0.0686** | **−14, −21.6% relative** |
| setter tempo downgrade | 100/900 = 0.1111 | 97/903 = 0.1074 | −3 |
| mean resolved tempo | 1.9178 | 1.9147 | −0.0031 |

**One site moved materially: the block's soft-hands rate, down a fifth.** That is
causally what the correction predicts. The vertical slice is a well-drilled
roster, so removing a term that rewarded discipline with better self-assessment
takes the recognition bonus away from exactly the volis who were getting it, and
fewer of them notice they are beaten. Soft-blocking was partly being driven by an
attribute with nothing to do with knowing you are beaten.

The three attack sites and the setter barely move, and the reason is visible in
2a: their deficits sit where the threshold curve is steep in `decision_making`,
which did not change sign, rather than in discipline.

---

## 5. Downstream rally outcomes — the scoreboard did not move

800 isolated rallies, same seeds.

| outcome | before | after |
|---|---:|---:|
| **home points** | **410 / 800 = 0.5125** | **410 / 800 = 0.5125** |
| mean rally events | 7.0838 | 7.1000 |
| ace | 12 | 12 |
| serve_error | 132 | 132 |
| kill | 235 | 235 |
| opponent_kill | 207 | 206 |
| attack_error | 78 | 78 |
| opponent_attack_error | 68 | 67 |
| blocked | 31 | 32 |
| counter_block | 37 | 38 |

**Who wins is identical and no outcome category moves by more than one rally.**
That is the right shape for this change: it moved *why* volis do what they do
without moving *how often they win*, which is exactly what "re-attribution, not
rebalance" should look like from the scoreboard.

It is also the strongest available evidence that nothing was tuned back toward
the old rates — no tuning happened, and the outcome mix was never consulted.

---

## 6. Tests

`_test_attempt_judgment_recognition_and_response`, four checks, all exact rather
than sampled:

1. **discipline does not decide recognition** — verdicts identical at every
   deficit across discipline 10/50/90, and `recognition` identical at 10 and 90;
2. **recognition rises with decision-making and with composure** — it is a
   capability and must behave like one;
3. **aggression makes a voli persist where their equal declines** — searched
   across the reachable deficit band rather than asserted at one value, so it
   cannot pass by landing on a lucky threshold;
4. **the neutral voli lands where the old model put them** — `recognition` at
   all-50 is exactly 0.50. This is the guard that keeps a future pass from
   turning the split into a rebalance.

**Suite: 2,078 → 2,082, no failures.** The delta is exactly the four new checks;
no sampling gate's population changed count, despite the behaviour change.
`CLAUDE.md`'s baseline is updated for that reason and no other.

---

## 7. Remaining concerns

1. **`PERSISTENCE_SHARE` is uncalibrated**, and inherited rather than chosen. It
   sets how much temperament is worth against recognition, which is a real design
   quantity nobody has measured.
2. **The 2.5 : 1 recognition ratio is inherited too.** The old model asserted
   decision-making matters about two and a half times composure for judging your
   own limit. This pass has no evidence either way and did not manufacture any.
3. **Renormalisation widened the bottom of the range.** A voli at
   `decision_making` 10 now has effective 0.2143, below `OBVIOUS_THRESHOLD` 0.25,
   so they **never** recognise an overreach at any size. Defensible — recognition
   now rests on two terms rather than three, so each matters more — but it is a
   newly-reachable absolute, and absolutes are where §0 defects live. Worth a
   look if generation ever produces `decision_making` that low in quantity.
4. **`ContactEnvelopeSystem.action_balance` still reads `tactical_discipline`**
   as a component of *physical* block balance. Untouched by instruction; it is
   the same defect one layer over and belongs to the block pass.
5. **The 71% figure in `run_backoff_terms_probe`'s header is a different
   population.** It measures a generated-attribute fixture at seed 900006; this
   probe measures the default vertical slice and sees 1.6%. The two must not be
   compared, and the discrepancy is not a change caused here.
6. **The in-situ rates are one roster of 15.** Part A's synthetic sweep carries
   the attribution and is exact; Part B's rates describe this fixture only.

---

## 8. Recommendation for the next pass

**The block tactical proof is now unblocked, and this measurement supports it
rather than merely permitting it.**

The soft-hands rate is the one site that moved materially, which means
`_block_hands_intent` is the most sensitive of the five to what a voli believes
about their own capability — and it is also the only one with a manager
instruction already written for it. Wiring `formation["hands_instruction"]` there
would now be adding adherence to a decision whose read half has just been given a
clean contract, with no risk of spending `tactical_discipline` twice, because it
no longer appears in the read at all.

That is a recommendation, not a plan.

---

## Re-running

```bash
godot --headless --path . --script res://tools/run_attempt_judgment_probe.gd
```

Part A is exact and should reproduce byte-for-byte. Part B is one fixture: treat
its rates as descriptive of that roster, never as a target.
