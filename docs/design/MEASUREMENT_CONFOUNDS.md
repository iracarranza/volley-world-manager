# Measurement confounds, and the open residuals they guard

This document exists because of a pattern, not a theory. Across a long run of
measure-diagnose-fix-verify work on the rally engine, every wrong diagnosis had
the same cause: two numbers compared that were taken under different
conditions. Not one instrument was faulty. Four hypotheses were falsified in a
row, and each died the same way.

The instruments are in `tools/`. What is not in `tools/` -- and what this file
is for -- is the set of conditions each one has to be read under.

## The confounds

**Identical rosters are not identical teams.** The vertical-slice fixture gives
its opponent `tendencies["tempo"] = 1`, a first-tempo offence, while the home
playbook requests tempo 3. Tempo drives the set's arc steeply enough that the
two sides get different amounts of approach time from tactics alone. A symmetry
gate that does not pin tempo reads a coaching choice as an engine defect.
`tools/run_match_sense_report.gd` pins it to `HOME_PLAYBOOK_TEMPO` for exactly
this reason; any new symmetry probe must do the same.

**Pooled rates hide per-path behaviour.** The three attack paths (first ball,
transition, continuation) do not behave alike. A pooled figure moved by one path
looks like a system-wide change. Decompose first -- `_defense_terms()`,
`_set_terms()`, per-path histograms -- then diagnose.

**`primary_close` and `assist_close` answer different questions.** A block-close
saturation hypothesis was killed by measuring `primary_close` at 0.966 and
concluding the term was saturated. The term that mattered was `assist_close`,
which was 0.391. Both are in the same metadata dictionary, one key apart.

**A band belongs to the sample size that produced it.** A timing band was
rebased from a 120-seed measurement while the test that asserted it ran 20 seeds
(1.0912 vs 1.1231). After writing down that this "was not worth making twice,"
it was made twice: a 0.481 figure from a `(4,120)` probe was documented for a
test running `(8,150)`, where the true value is 0.555. Before rebasing any
constant, check the sample size in the *assertion*, not in the probe.

**A suite result certifies only the tree it started on.** Editing a `.gd` file
while the suite runs does not corrupt the running process -- Godot has already
loaded the scripts -- but it does mean the green result describes a tree that no
longer exists. Never commit on a suite that started before the last edit.

**Asserting a rate is not measuring it.** "The home claim rarely fails" was
stated without measurement; it is 32.6% against the opponent's 50.0%.

**A degenerate result satisfies a monotonicity check trivially.** The timestamp
gate asserts coverage, ordering and zero causality-floor corrections, and
reported 100% / 0 / 0. It was reading data that is partly degenerate: on
home-serving rallies the first three events all carry a synthesised
`start_time` of 0.000, the reception's trajectory being byte-identical to the
serve's. All-equal stamps are never backwards, so a check for "backwards" is
silent on them. The gate needs to assert that a rally's timeline actually
*spans* -- that consecutive events are distinct where the sport says they must
be -- and not merely that it never reverses. Open; see below.

**A rate without its denominator is not a measurement.** `run_serving_side_split`
reported the home side's attack quality falling 0.330 to 0.191 on home-served
rallies -- a 42% collapse, reported as evidence of a second defect. It was eight
attacks. Home serves, so the opponent receives and swings first, and most of
those rallies end before the home side gets a swing at all; the cell can never
hold a usable sample. The neighbouring cell that *does* (the opponent's, n=280)
moved 0.462 to 0.440, which is a modest real effect and the opposite conclusion.
Both the tool and this file now carry counts beside rates. Note the shape: the
error was not in the number, it was in reading a four-cell table where two cells
are three orders of magnitude better sampled than the other two.

**An instrument's own labels are part of the measurement.** A dump script
hardcoded the `RallyEvent.EventType` order from memory. `SET_DECISION` is index
2, not 7, so every label from index 2 upward was shifted, and the output looked
exactly like an event-ordering defect: `POINT` before `SET_DECISION`, a rally
with no `SET`. There was no defect. Read the enum, do not recall it.

## Open residuals

Recorded because each is a thing that is *known to be imprecise* rather than a
thing believed to be right. A later reader who rediscovers one of these should
know it was seen and bounded, not missed.

**The attack-symmetry ratchet is red, and the baseline it ratchets against was
measured under a stopped clock.** `attack symmetry does not drift further while
tuning` fails at 0.646 against a 0.135 ceiling after `rally_clock` started
running on home-served rallies. Chased for a second defect and none was found:
the live attack integrator only runs on the home-*receive* path, so it is not
involved; the movement system uses `simulation_time` as an absolute clock with a
relative window, not as a budget. What is left is a genuine, modest effect --
the opponent's attack quality on home-served rallies falls 0.462 to 0.440
(n=280), consistent with losing an advantage they had while their
`simulation_time` was pinned at zero for half of every match. The previous
passing value was therefore not a measurement of the engine; it was a
measurement of the engine plus a clock that had not started. Deciding whether to
re-baseline is a human call, because widening it is the move the gate exists to
prevent.

**Home-serving rallies have a partly synthesised timeline.** Measured by
`tools/run_playback_schedule_probe.gd`: 25.5% of all inter-event gaps are under
5 ms, against a genuinely bimodal distribution -- a near-empty band between 5 ms
and 200 ms, then the real population from 0.2 s up. Some of those zero gaps are
legitimate simultaneity (`ATTACK -> BLOCK`, 85 of 3502). Most are not.
`_ensure_event_trajectories` fills missing trajectories at a fallback timestamp,
and on the home-serve path it fires for the first three events, stamping them
all at t=0. Playback must not be driven from `physical_time` until this is
fixed: half the rallies would render the serve and the reception as one instant.
The bimodality is worth keeping -- once the synthesised stamps are gone, the
empty band between 5 ms and 200 ms is what justifies a concurrency epsilon
rather than taste.

**Serve origin x is not mirrored.** Home serves from x = 0.82, the opponent from
x = 0.80. Both were literals; the y coordinate of each was wrong in the same way
and is now `CourtConstants.serve_origin`, but unifying x would move both sides'
serve angles and is a calibration change.

**Bare `rally_clock` event stamps.** `_stamp_physical_times` now produces zero
causality-floor corrections, which proves the derived moments agree with each
other -- not that each is independently correct. These sites in
`rally_simulator.gd` still stamp `"event_time": rally_clock` and are monotone
but unverified as derivations:

- the RECEPTION stamp, where `rally_clock` is the serve's arrival (probably
  right, and unused anyway -- `physical_time` prefers the outgoing trajectory)
- the setter-decision stamp, which inherits the reception moment rather than
  deriving the decision's own
- the continuation BLOCK, which carries no `incoming_trajectory`, so it falls
  back to the attack *contact* instead of the net crossing that the other two
  block sites use. Slightly early, and monotone, which is why the gate is
  silent about it.

**Stepper vs closed-form traversal.** A ~9% residual between
`ShadowMovementSystem`'s integrated stepper and `RallyMovementSystem`'s
closed-form time. Documented and bounded; the timing band in the suite is
rebased onto the closed form.

**`_build_movement_plan()` overwrites staged positions.** Known, not yet fixed.

**Opponent serve has no risk concept.** Deliberate: the home side's serve risk
is a tactical choice with no opponent counterpart yet. This is missing *content*,
not a symmetry defect, and should not be "fixed" by mirroring the home model
without deciding what an opponent's serve philosophy means.

## The match-sense gate, as last measured

Tactics-controlled, identical rosters, four pairings x 90 rallies x both serving
assignments. Read `tools/run_match_sense_report.gd` for the conditions.

| rate | home | opponent | gap | verdict |
| --- | --- | --- | --- | --- |
| kill | 0.560 | 0.552 | 0.008 | ok |
| stuffed | 0.033 | 0.045 | 0.012 | ok |
| attack_quality | 0.424 | 0.451 | 0.027 | ok |
| set_quality | 0.452 | 0.417 | 0.035 | suspect |
| dig | 0.320 | 0.137 | 0.182 | DEFECT |
| attack_error | 0.149 | 0.377 | 0.228 | DEFECT |

`kill`, `stuffed` and `attack_quality` being symmetric is what makes `dig` and
`attack_error` clean targets: most of the confounding that produced the earlier
false starts has been removed from the picture. `attack_error` is plausibly
downstream of `dig` and should not be attacked independently until the dig gap
closes.

The roster-response column (home spiked +0, +6, +12 across every rated
attribute) reads 0.603 / 0.660 / 0.714 home point share. That column is only
meaningful while the gaps above are small -- an asymmetric engine returns its
own bias there and it looks like a roster response.

## `stash@{0}`

A home-tempo decision change. It is a *trade* on the current movement model, not
a strict improvement: it closes `dig` and moves the points baseline, at the cost
of `attack_quality` and `kill`. It broke the suite twice (2 then 7 failures) and
was stashed rather than pushed both times. Do not apply it without re-running
the full suite and the match-sense report together.
