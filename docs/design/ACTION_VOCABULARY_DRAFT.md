# The action vocabulary (draft)

Date: 2026-08-03
Status: **draft for review.** Nothing here is implemented.

## The problem this solves

A rally is currently legible as a sequence of phases -- serve, reception, set,
attack, block, defense -- each carrying a quality float. A viewer can see that
something happened and can read a percentage, but cannot *name* what they saw.
The distinctions exist in the simulator; they are discarded at the point of
presentation.

The goal is a closed set of named actions, so that a viewer watching a rally
can say "he got tooled" or "she dug that off her shoelaces" rather than "the
block resolved at 0.61".

## The rule that generates the vocabulary

**A name is earned by the gap between what the situation demanded and what the
player delivered.** Not by outcome quality alone.

This gives four quadrants, and only two of them get names:

| | delivered well | delivered badly |
| --- | --- | --- |
| **hard ball** | **named -- the highlight** | unnamed (expected) |
| **easy ball** | unnamed (baseline) | **named -- the blunder** |

Both named quadrants matter. A vocabulary of only highlights makes every team
look brilliant; the blunder is what makes a weak player legible as weak. And
the two unnamed quadrants are not a gap in the design -- they are the silence
that lets the named ones register.

Difficulty is already computable everywhere it is needed:

- `arrival_margin` (`flight_time - travel_time`) -- negative means the defender
  arrived after the ball. Already computed in `_choose_opponent_defender`.
- incoming ball quality -- reception quality feeding a set, set quality feeding
  a swing, `BLOCK_DEFLECTION_CARRY` feeding a recycle.
- block state at contact -- `primary_close`, formation `quality`,
  `contact_depth_from_net`.

## Serve

| name | trigger | reads as |
| --- | --- | --- |
| **Ace** | serve lands, no reception contact or reception fails outright | already an outcome; needs surfacing, not deriving |
| **Service pressure** | reception succeeds but quality below the band that permits a full offence | *the named non-terminal good thing* -- the server wins the rally without ending it |
| **Missed serve** | serve error at low selected risk | blunder quadrant: an error while playing safe |

A serve error at *high* selected risk stays unnamed. It was the price of the
attempt, and naming it would punish aggression the design wants to encourage.

## Reception

| name | trigger | reads as |
| --- | --- | --- |
| **Platform dime** | quality high **and** `arrival_margin` small or negative | passed a ball they had no business reaching |
| **Scramble pass** | quality mid-low, `arrival_margin` clearly negative, rally continues | kept it alive, offence compromised |
| **Shank** | quality very low, `arrival_margin` comfortable | blunder: an easy ball butchered |

## Set

| name | trigger | reads as |
| --- | --- | --- |
| **Dime** | set quality high **and** resulting opponent block `primary_close` low | the killer-ball equivalent: the set is what isolated the hitter |
| **Save set** | set quality acceptable off a reception below the transition-ball threshold | made something out of nothing |
| **Telegraphed** | set quality fine but opponent block forms at full strength on the pin | blunder of choice rather than execution -- the set was clean and still wrong |

`Dime` is the most important entry in this table. It is the one name that
credits a player for a point they did not score, which is the whole reason
setters are interesting.

## Attack

| name | trigger | reads as |
| --- | --- | --- |
| **Tool off the block** | attack succeeds **and** block outcome was `touch`/`funnel` **and** ball lands in | the marquee attacking moment; currently invisible |
| **Cross-court bullet** | kill, `direction == "cross-court"`, high attack quality | |
| **Line shot** | kill, `direction == "line"` | |
| **Seam kill** | kill, `direction == "seam"` | |
| **Back-row bomb** | kill from a back-row contact depth | |
| **Roll shot / Tip** | existing `attack_type`, on a kill | off-speed as a *choice* that worked |
| **Swung into the block** | stuffed at low attack quality with the block already formed | blunder: hit into a wall that was visibly there |

`attack_type` already carries `Quick attack`, `Power swing`, `Line attack`,
`Roll shot`, `Tip`, `Emergency tip`, `Short tip`. That is intent. The vocabulary
above is outcome. Both are wanted -- intent explains the choice, outcome names
the result -- but only outcome should be surfaced as a moment.

## Block

This is where the vocabulary does the most work, because it is where the
current model throws away the most.

| name | trigger | reads as |
| --- | --- | --- |
| **Roof** | `stuff` outcome | terminal, rare, the signature block moment |
| **Soft block** | `touch` outcome **and** the defence subsequently digs it | *named, positive, non-terminal* -- the blocker created the dig |
| **Funnel** | `funnel` outcome and defence converts | block did its job by directing, not stopping |
| **Got tooled** | block contacts, attack lands in | the loser's half of "tool off the block" |
| **Beaten by tempo** | block fails to form, `primary_close` low, quick attack | names a *reason* rather than a failure |

**Soft block** is the entry that delivers what you asked for two messages ago --
a wider window for the block to matter without terminating the rally. It costs
no calibration change. The event already happens constantly; it is simply never
named, so a blocker who deflects twenty balls into easy digs currently reads as
having done nothing all match.

## Defense

| name | trigger | reads as |
| --- | --- | --- |
| **Sprawl dig** | dig succeeds with `arrival_margin` clearly negative | the slide-tackle equivalent -- the single most legible action in the sport |
| **Overhead dig** | dig succeeds on a high, hard ball at short range | |
| **Cover** | attack-coverage contact succeeds off a block touch | credits the player who kept a blocked ball alive |
| **Missed the easy one** | dig fails with `arrival_margin` comfortably positive | blunder |

`arrival_margin` already exists and is already negative on exactly the balls
that should read as desperate. This table is the cheapest one to build.

## Notability budget

Names are not free. If every contact carries one, the labels become texture and
we are back where we started.

Proposed rule: **at most two named actions per rally**, chosen by margin above
the naming threshold, plus the decisive action of the final point always being
eligible. A rally with nothing exceptional in it emits zero names and reads as
what it is -- competent volleyball.

Targets to gate in the test suite:

- share of rallies containing at least one named action: **40-60%**
- named actions per rally, mean: **~1**
- share of *points* whose decisive event carries a name: **high** (this is the
  one that encodes "named actions decide rallies")

The last two are different denominators on purpose. Named actions should be
**rare per contact and dominant per point**.

## What this implies for the block calibration

Left open deliberately, but the vocabulary changes the question. See
`BLOCK_CONTEST_DIAGNOSIS_2026_08_03.md` for the measured baseline of 39.4%.

If a `Roof` is a named moment, it cannot also be the routine outcome of an
attack. But "deliberately blocky" survives intact by splitting block
*involvement* from block *termination*: touches and funnels stay common, so the
block is visibly present on every swing and shapes where the ball goes, while
the terminal stuff becomes rare enough to be worth watching.
