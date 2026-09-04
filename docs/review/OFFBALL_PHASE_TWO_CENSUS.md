# Off-ball claimant Phase Two paired census

## Method

`run_offball_claimant_rollout_probe.gd` resolves seeds 20000–20349 with both
serving sides twice. The paired arms differ only in the debug opening of
`ENABLE_OFFBALL_POSITION_CLAIMANTS`. Rally signatures include terminal outcome,
winner, decisive actor and every event's family, actor and success.

## Result at `ee7c798` plus this census

All 700 rally signatures are identical. Both arms report 4.636 contacts per
rally, 0.526 kill rate, 0.512 dig rate, 0.097 stuff rate and 0.194 serve-error
rate. Every delta is 0.000.

This is not evidence that published positions are too distant to matter. The
candidate population did not change: all six already own enabled floor zones,
and the two searches already consume their resolved positions. The expected
direction in the implementation spec therefore does not apply to this proposed
gate. No calibration is justified.

The full suite reports the baseline two failures in 2,232 checks: the known
strict-tempo assertion and stacked-blockers assertion. The three Phase Two
contract checks add no regression.
