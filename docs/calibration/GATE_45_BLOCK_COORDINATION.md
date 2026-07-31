# Gate 45: Coordinated Block Decisions

Review date: 2026-07-31

Status: **PASS; SHADOW ONLY**

Gate 44 gave every front-row blocker an independent hypothesis but nothing that
let one blocker's decision affect another's. Roles were labelled afterward, and
labelled badly: `primary` and `assist` were chosen by sorting closers on how
near their target landed to the authoritative contact. That ranked blockers by
how close they had *guessed to the truth*, which is a decision-quality score
wearing a role's name, and it meant moving the authoritative contact alone
reshuffled who was primary while every perception stayed identical.

Gate 45 replaces that with real coordination.

## Two passes

`ShadowBlockSystem.evaluate()` now runs the blockers twice.

Pass one is Gate 44 unchanged: each blocker reads the setter, the set flight,
and the hitter's approach load alone, and forms a tentative commitment. Those
values are preserved on every blocker as `tentative_commitment`,
`tentative_commitment_target_x`, `tentative_implied_zone`, and
`tentative_wrong_read`.

Pass two is coordination. Every blocker observes their teammates and may revise.
All revisions read the same pass-one snapshot, so revisions are simultaneous and
the result does not depend on the order blockers are visited.

## What a blocker may see of a teammate

Only what is visible across a net, degraded by the observer's own reading
ability:

- `teammate_slot` and `teammate_home_zone` -- public rotation knowledge;
- `perceived_movement_zone` -- the direction that teammate appears to be
  driving, built from their target with a reading-scaled position error;
- `perceived_committed` -- whether they look like they are driving at all,
  rather than staying square and reading;
- `cue_confidence` -- the observer's own confidence in the cue, not the
  teammate's.

A teammate's confidence, decisive threshold, implied zone, perceived attack
point, and every graded field stay private. `BlockRolloutAudit` fails a
candidate by name (`teammate_cue_leaks_private_state`) if any of them appear in
a cue, and a focused test asserts the cue dictionary contains nothing outside
the list above.

## The coordination rules

- **Stepped up: own zone uncovered / read zone uncovered.** A blocker holding
  their read who sees nobody covering the zone they read takes it. The
  confidence bar drops by `UNCOVERED_ZONE_THRESHOLD_RELIEF` because
  responsibility has landed on them -- committing on a thin read beats leaving
  the swing unblocked.
- **Joined: closing with the zone owner.** A blocker holding or releasing, who
  reads a zone a teammate is already closing and can travel to it, joins and
  makes it a double block. This is the single most characteristic block
  coordination and the move that turns two independent reads into one block.
- **Released home zone: read zone uncovered.** A blocker committed to their own
  zone while the read says the swing is going somewhere nobody covers leaves
  and helps. Holding a zone the ball is not coming to is the worse mistake.
- **Re-engaged: no teammate committed.** A blocker who released while nobody
  looks committed anywhere comes back to contest.
- **Declined third body: held own zone instead.** A blocker travelling to a seam
  that already has two bodies converging on it turns back. A third blocker on
  one swing is worth less than a body on the open one.

## Roles without truth

`_resolve_roles()` picks primary and assist from the coordinated commitments
alone: a blocker closing the zone they own outranks one travelling to help, ties
break on arrival margin and then on player id. Nothing in the ordering consults
the authoritative contact position.

The regression suite proves this directly: two evaluations that share a seed, a
set flight, and every perception but differ in where the authoritative contact
actually is must produce identical commitments, identical primary, and identical
assist. Under Gate 44's ordering that test fails.

## Misread versus placement

A blocker sent away from the ball by a deliberate coordinated decision is not a
blocker who read the play wrong, and counting them together would make the Gate
46 misread rate meaningless. The two are now separate:

- `wrong_read` -- the blocker's *perceived* zone was not the true zone, and they
  committed on that belief. A perception failure.
- `commitment_off_target` -- the final commitment landed in a zone other than
  the true one. Can be true after a correct read when coordination deliberately
  sent them elsewhere.

The same distinction fixed `hesitated`, which Gate 44 defined as holding a read
while confidence cleared the blocker's *own* threshold -- structurally
impossible, since a blocker only ever holds when confidence sits below that
threshold. It is now measured against `HESITATION_CONFIDENCE`, the sharpest
achievable threshold in the model, and means "the best reader in the league
would have gone on this and you did not." Gate 46 guards it against becoming
unreachable again.

## `block_engagement_distance` is now consumed

`VolleyballPlayer`'s `block_engagement_distance` SystemFitProfile -- derived and
cached since the system-fit work, consumed nowhere -- now grades the distance a
blocker would have to close to meet the swing they think they see. The distance
is measured against the *perceived* attack point, so it is known before a
commitment is chosen and never smuggles truth into the decision. Landing inside
the natural engagement band eases the confidence bar: a close a blocker has made
a thousand times needs less confirmation than one from an unfamiliar range.
Roughly 20-50% of blockers are in system depending on reading tier.
