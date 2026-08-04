# The setter decides

## The hole this fills

Nobody in this engine chooses who attacks.

The home hitter is `_player_by_id(players, assignment.player_id)` -- whoever the
called play names. The transition hitter is `_fallback_hitter(...)`, which is a
default rather than a choice. The opponent picks `opponent_team.best_hitter()`,
which is a choice with no situation in it: the same player every ball, whatever
the pass, whatever the block.

So the second contact -- the one the whole sport is organised around -- has no
decision in it on either side of the net.

## Why it matters more than it looks

Defence and attack scale differently, and only one of them currently works.

**Defence scales with breadth, and delivers itself.** Six competent receivers
each contribute on every rally with no decision required. Every point of
`anticipation` bought is spent on every ball. Nothing has to route it.

**Attack scales with concentration, and has no channel.** One great hitter only
matters if the ball reaches them, and nothing sends it there. Attacking
investment therefore dissolves into the roster average instead of compounding on
the player it was spent on.

Measured over 6 roster pairings, both serving assignments, 120 rallies per
condition: a digging tradition takes **55.0%** of attack exchanges against an
attacking tradition's **51.4%**. That is not defence being overtuned. Raising
attacking numbers would lift every roster's average and leave the star exactly as
unreachable as before. The gap is structural, and this document is the structure.

The design target it serves, in the owner's words: building around a super
attacker should be *less feasible but much more rewarding* than building a
defensive system. A defensive system should stay the easier, safer, slightly
favourable choice -- park the bus works -- while the ceiling above it belongs to
an offence somebody had to construct.

## What the setter is deciding

One function, both sides of the net, returning **which hitter and at what
tempo**, given the ball actually in hand.

Every asymmetry found in this engine has been the same defect -- one side
modelled fully and the other as a simplified parallel implementation -- and eight
of them were fixed in a single session. This must not add a ninth. `best_hitter()`
and `assignment.player_id` both die; both sides call the same decision.

### Inputs, all of which already exist

| input | source | what it answers |
|---|---|---|
| eligible hitters | `RotationLineup`, front/back row | who may legally attack |
| what each can execute | `ApproachMechanicsSystem.available_attack_families`, `attack_family_deficit` | who can do anything with *this* pass |
| arrival | approach preparation, `hitter_arrival_margin` | who will actually be there |
| tempo ceiling | `SetterCapabilitySystem.evaluate` | what the setter can deliver off this ball |
| the forming block | `_form_opponent_block`, `_blocker_read_quality` | who is about to be faced by two hands and who by none |
| exposure | `Familiarity.attack_geometry`, `record_exposure`, `scouting_confidence` | what the opponent has already learned |
| instruction | `OffensivePlay`, `tendencies` | what the coach asked for |
| the hitter | `attack_power`, `shot_variety`, `attack_accuracy`, `match_confidence` | who is worth setting |

Nothing here is new. The decision is a composition of models that already run;
what does not exist is the composition.

### The shape

A score per eligible hitter, highest wins, with the setter's own judgment
deciding how sharply that score is followed:

```
for each eligible hitter:
    feasibility  -- can they execute anything off this pass, arrive in time,
                    and is the tempo within the setter's capability
    matchup      -- what the block in front of them looks like right now
    quality      -- what they are worth when they do get the ball
    instruction  -- what the coach asked for, as a bias not an override
```

`feasibility` is a gate, not a term: a hitter who cannot execute or cannot
arrive is not a candidate. The rest is a weighted sum, and the setter's
`decision_making` and `court_vision` decide how much of the true ordering they
actually perceive -- a poor setter sets the wrong hitter not because the model is
random but because they read the block wrong.

## Concentration, and the price of it

This is the part that makes the reward real, and it is the part most likely to
be got wrong by making the setter simply always pick the best hitter. That is
`best_hitter()` again, and it is a non-decision: a side that always does the same
thing cannot be caught doing the wrong thing. The engine already learned this
lesson once -- the opponent's tempo call is a constant, which is precisely why
`SetterCapabilitySystem`'s downgrade branch has never once fired on that side of
the net.

Concentration must therefore cost something, and the mechanism for charging it
already exists. `Familiarity.record_exposure` logs what a hitter is repeatedly
asked to do; `scouting_confidence` and `read_modifier` turn that into an opponent
who knows what is coming. A setter who feeds one hitter every ball is building
the read that beats them.

That gives the intended curve without inventing one:

- **A balanced offence** is readable by nobody in particular and exceptional
  against nobody in particular. The safe middle.
- **A concentrated offence** wins more early and is progressively better
  scouted, so the payoff decays across a match and across a season unless the
  hitter is genuinely good enough to beat a committed block.
- **A super attacker** is the roster that *can* beat a committed block, which is
  why building one is expensive and why it is worth it.

The counter-play is the block philosophy dial (see below): a side that reads a
concentrated offence commits earlier, and a hitter without the `shot_variety` to
punish a committed block stops being worth the concentration.

## What this unlocks elsewhere

**Block philosophy gets something to counter.** `_contest_block` already produces
`stuff`, `touch` and `funnel`, and no tactical instruction reaches those bands.
`block_defense_relationship` chooses *where* the block goes (Balanced / Defend
Line / Defend Cross), never *what it is for*. The two philosophies the game wants
-- seal the lane and end rallies, versus take a touch and let the floor play it
-- are the same axis the regional identities already sit on: Bloc du Larg's
`block_timing` + `jump_reach` is the terminal block, Lo-onğ Ralī's `anticipation`
+ `dig_control` + `stamina` is the facilitating one. Neither is selectable today.

**Scouting gets a real signal.** Familiarity currently records exposure that
nothing much varies. A setter who can choose is a setter with a pattern, and a
pattern is what scouting is for.

**Training and budget allocation acquire a shape.** Spreading investment across
six receivers is reliable and cheap to train. Concentrating it on one attacker is
expensive, needs a setter who can find them and a system that survives being
read, and pays more when it works. That is the decision the mode is about.

## Constraints this must respect

**One implementation, both sides.** Stated twice on purpose.

**The RNG stream.** Any new draw from the shared generator advances it and
silently rerolls everything downstream -- the defect that rerolled the world when
`ego` drew from the generation stream. If the decision needs randomness it takes
it as data, drawn in a fixed order before any branch is taken, exactly as
`GeometricAttackPromotion.draws` does.

**Capability is not permission.** The play calls a hitter; the setter may
deviate when the ball does not support the call. This is the same shape as
`_downgraded_assignment` one level up, and the deviation must cost something
rather than being free -- otherwise the play call becomes decorative.

**It moves every number in the engine.** Who attacks changes attack quality,
which changes what the block contests, which changes what the floor digs. The
identical-roster symmetry estimator must be re-run and must not regress; the
attack error, kill, stuff and dig rates all need re-checking against the sport's
bands. This lands *after* the geometric attack promotion or it becomes a second
moving target underneath it.

## How it gets measured

The gate is not "the setter makes sensible choices." It is four numbers.

1. **Does set share respond to hitter quality?** Sweep rosters where one hitter
   is strong and the rest ordinary; the star's share of sets must rise with the
   gap. If it does not, the decision is not deciding.
2. **Does concentration become readable?** A concentrated offence must show
   rising `scouting_confidence` and earlier block commitment across a match. If
   it does not, the reward has no price.
3. **Is a super-attacker roster more rewarding than a balanced one at equal
   total investment?** Same attribute budget, distributed flat versus spiked;
   the spiked roster should win more, and should lose more when badly set. If
   both distributions produce the same result, the whole exercise failed.
4. **Does symmetry hold?** Identical rosters on both sides, kill share within
   the 0.12 bound. Non-negotiable.

The first three are new sweeps and belong in `tools/`; the fourth already exists.

## Explicitly out of scope

- The opponent playbook. The opponent's tempo call is a constant and that is a
  separate, recorded defect; this document is about *who* is set, not what the
  bench asked for.
- The block philosophy dial. Named above because it is the counter-play, but it
  is its own gate.
- Attack landing targets, which are already continuous on both sides, and set
  destination zones, which are their own piece of work.
