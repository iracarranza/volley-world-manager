# Three balance gates that were measuring noise

Date: 2026-08-03
Occasion: body types went red on three checks; none of them was a body-type
defect.

## Why this kept happening

Rally generation draws from one shared RNG stream, so **any** change that adds
or removes a draw reshuffles every subsequent value for every player generated
afterward. The test file already knew this — there is a comment on the block
distribution test explaining that its seed moved from 900000 to 900006 because
"900000 happened to land on a home team that dominates blocking entirely once
reshuffled; 900006 reads sane again."

That is the whole problem stated out loud and then handled by re-rolling. Body
types add one draw per generated player. The stream reshuffled. The same gates
came up red again.

Three separate gates were affected, and in every case the fix was to measure
the quantity properly rather than to find another lucky seed.

## 1. Home stuff-block rate: one draw from a very wide distribution

The gate asserted `stuff_blocks / home_block_events < 0.22` for a single
generated roster pairing. Swept across twelve independently generated pairings,
300 rallies each:

| | mean | median | min | max |
| --- | ---: | ---: | ---: | ---: |
| unmodified tree | 0.288 | 0.223 | 0.000 | 0.907 |
| with body types | 0.324 | 0.306 | 0.000 | 0.669 |

The two distributions are indistinguishable. The unmodified tree's spread is if
anything *wider*. The gate passed on `main` only because seed 900006 lands at
0.128 — the second-lowest of the twelve draws.

So a 0.22 ceiling on one pairing is a lottery ticket with roughly a 75% chance
of failing, and body types did not break blocking. **This corrects an earlier
hypothesis recorded on the WIP branch** — that the block failure was "probably
real, since Avi moves `jump` and `block_timing`, which feed blocking directly."
It is not. Body types actually *lower* mean jump reach: the `jump_reach` deltas
sum to −8.5 across the six types.

The gate now averages six pairings of a hundred rallies, which costs about two
seconds and gives a number that moves when blocking does. Measured at 0.248 on
`main` and 0.342 with body types; the bound is 0.50.

### The real finding underneath

A single pairing's stuff rate ranges from **0.000 to 0.907**. Blocking outcomes
are dominated by how the two rosters happen to match up. That is arguably
correct — a much better blocking team should stuff a lot — but the swing is
extreme enough to be worth its own investigation. It is not a body-type
question and it is not fixed here.

## 2 and 3. Identity directional claims at 12 samples

`_test_team_identity_directional_outcomes` called `identity_calibration(12)`
while the function's own default is 40. Measured effect sizes across that
family run from 15% relative down to 1.4%:

| claim | at 12 samples | at 48 samples | effect |
| --- | --- | --- | ---: |
| Physical serves with more errors | 0.1042 > 0.0833 ✓ | 0.1372 > 0.0990 ✓ | 25% |
| Physical serves with more quality | 0.5868 > 0.5574 ✓ | 0.5823 > 0.6379 ✓ | 5% |
| Physical serves more aces | 0.0208 = 0.0208 ✗ | 0.0382 > 0.0365 ✓ | 5% |
| Fast Tempo has shorter rallies | 5.812 > 5.694 ✗ | 5.458 < 5.538 ✓ | 1.4% |
| Defensive attacks with fewer errors | 0.1501 > 0.1362 ✗ | 0.1442 < 0.1850 ✓ | 22% |
| Defensive attacks with fewer kills | 0.3902 < 0.4716 ✓ | 0.5182 < 0.6002 ✓ | 15% |

(Ace rate at 12 samples is a comparison between one ace and two.)

Raising the calibration to 48 samples costs a few seconds and makes all six
claims resolvable at once. That is better than deleting the marginal ones: the
properties are real, the measurement was too coarse to see them.

One clause — "defensive attack lowers error risk" — was removed for a single
commit while the calibration still ran at 12. It is restored, because at 48 it
holds on both the unmodified tree (0.1721 against 0.1782) and with body types
live (0.1442 against 0.1850).

## The rule this suggests

A directional gate should be sized against the effect it claims to detect. A
1.4% effect measured over a dozen samples is not a gate, it is a coin flip with
a comment attached — and it costs more in false failures and misdirected
investigation than the runtime it saves. Three separate changes were blamed for
breakages they did not cause before this was measured.
