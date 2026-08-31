# Rally simulator -- the reasoning behind each decision

Relocated verbatim from `scripts/simulation/rally_simulator.gd`. Every comment
block of twelve lines or more is reproduced here in full and left in the code as
a single NOTE. Shorter blocks stayed where they were.

At the time of the move the file carried 7,025 comment lines in 963 blocks --
37% of its non-blank lines. The 179 blocks below held 3,564 of them.

Sections are keyed on the declaration or statement the block sat above, with the
enclosing function named underneath.

## `const MAX_EXCHANGES: int = 4`

*in `(module level)`*

How many attack exchanges a rally may contain. Measured, and it is a backstop
rather than a rule.

Flagged in the constant audit on the guess that a cap of four sat at the median
rally length and was therefore ending rallies that play should have ended. That
guess was wrong. Over 200 rallies the swing distribution is:

swings per rally    0    1    2    3    5
rallies            40  123   26    9    2

The cap binds in 1.0% of rallies -- two of two hundred -- which is what a
runaway guard should look like.

**What the same measurement does say is worse, and is not about this number.**
The median rally contains *one* swing. 123 of 200 rallies end on the first
attack and only 37 ever reach a second. A rally in this sport is a sequence of
transitions; here it is almost always a single exchange, which means the floor
defence essentially never keeps a ball alive. That is the same finding as a
home kill rate of 0.83-0.91 per swing seen from the other side, and it is the
floor defence that every geometric-attack flag comment already names as the
blocker. Raising this constant would change none of it.

## `const BLOCK_SHOULDER_OFFSET: float = 0.095`

*in `(module level)`*

Fallbacks for a setter with no derived release profile. These are the
midpoints of the bands `VolleyballPlayer.refresh_system_fit_profiles()`
produces, so a profile-less setter behaves like an average one.
Where the two blockers stand when a wall forms. A double block is two players
shoulder to shoulder at the net, not two markers at one coordinate: playback
had been placing each blocker at their own defensive court position, which for
a block resolves both onto the attack lane and draws them stacked. Geometry is
the resolver's to own, so the pair is recorded on the event.
Centre-to-centre between the two blockers, as a fraction of court width --
0.855 m. Measured against the bodies that have to stand there: the widest torso
in the game is a Tomato at 0.715 m, and the previous 0.085 left it 5 cm of
clearance from its neighbour. A sealed double block is shoulder to shoulder, not
interpenetrating, and 14 cm reads as the former.

## `const RECEPTION_LOST_CONTROL_RISK: float = 0.16`

*in `(module level)`*

`contact_control` is continuous, so it must not be turned into a cliff that
makes one weak passer fail every serve and the player one point better pass
every serve. `contact_control` is an ordinal execution score, not itself a
probability, so lost control is mapped through one calibrated curve. The
square root keeps high-control receptions from becoming infallible while a
12% ceiling prevents a low-rated passer from becoming a deterministic ace
machine: a 0.70 platform fails 8.8%, and 0.50 or 0.30 platforms reach 11.3%
and 12.0%. Perfect control remains a certain play. The final fixed censuses
measure 7.5% when the managed side serves and 2.8% when the opponent serves,
both inside the repository's broader 2--10% rally-readiness band. The draw
is hashed so the physical outcome is deterministic without resequencing the
rally RNG.

## `const ASSIST_COMMIT_FLIGHT_SECONDS: float = 0.65`

*in `(module level)`*

How much of the time between the pass and the set's release a blocker can
actually use to move.

Closing used to begin at set contact, giving a high ball 0.69 s and a quick
set 0.23 s -- and reaction plus the block jump consume about 0.49 s of
either, so blockers had roughly 0.2 m of footwork at any tempo and could not
cover one metre of net. A lane 0.9 m from the nearest blocker sat at the
block-quality clamp floor. Real blockers read the pass and the setter's body
and are moving well before the ball leaves the hands.

Not all of that window is usable: the set's direction is not certain until it
is released, and a blocker who commits early to the wrong lane is worse off
than one who waited. That uncertainty is what `read_quality` models, so this
is the share a blocker spends moving rather than waiting.
How long a set has to be in the air before an assist blocker can bank the
whole of their pre-set read.

Anchored on the measured cost of a close, not on the length of a high ball.
`primary_close_terms.required_seconds` runs 0.58-0.67 s across tempos 0-2 --
that is what crossing to a lane actually takes -- so an assist needs about
that much *post-set* time before anticipating the lane is worth committing
to. Below it they are guessing and cannot recover if they guess wrong.

Set at the high end of that band. Tried at 0.95 first, taken from the high
ball's own flight, and it was far too severe: double blocks fell to 18% at
tempo 1 and 24% at tempo 2, which deletes the ordinary read block rather than
the one that should not have formed. Mean set flight for reference: 0.204 s
at tempo 0, 0.392 at tempo 1, 0.426 at tempo 2, 1.006 at tempo 3.

## `const ASSIST_COMMIT_SIGNAL_FLOOR: float = 0.46`

*in `(module level)`*

What a wall that *committed* keeps when the ball comes quick.

Bounding the assist by the set's flight alone produced zero double blocks at
tempo 0 -- every rally, every wall, every roster. That is not a model of
anything, it is a threshold driving a degenerate distribution, which is the
same defect this engine keeps being caught by elsewhere. Committing to a lane
before the set is exactly how a first-tempo ball gets doubled, and a blocker
who reads early and adapts fast should sometimes be there too.

So only the *reactive* share of the pre-set credit is bounded by the flight.
The committed share survives whatever the tempo, because committing is a
decision taken before the tempo is known. Its cost is already priced: a wall
that commits and guesses wrong has moved away from where the ball went.

Floor and span are set so the median wall -- commitment and read both near
0.5 -- keeps little, while a genuinely committed or fast-reading one keeps
most of it.

## `const BLOCK_STUFF_MARGIN: float = 0.34`

*in `(module level)`*

How decisively the block has to beat the swing for each outcome.

Re-derived twice. At -0.06 and -0.24 the block touched 82% of all attacks and
rallies never ended. Tightening to positive margins fixed that against a
block that could not move; once closing began at the pass rather than at set
contact, blockers reached lanes they never used to and the touch rate went
back to 0.61 on the same numbers. A margin is a statement about how much the
block has to win by, and it only means something against a given amount of
block -- change what the wall can reach and it has to be restated.
Where a block's contest margin has to land for each outcome, set from the
distribution of that margin rather than from taste.

`contest - attack_quality` is one number and these are three thresholds on it,
so the only way to know what share each outcome gets is to know where the
distribution sits. Measured over 1,013 home blocks against an opponent that
swings: p10 -0.176, p25 -0.052, p50 0.077, p75 0.237, p90 0.363.

The old trio -- 0.10, 0.18, 0.22 -- packed all three bands into a 0.12-wide
window near the middle of a spread half a unit across, and the consequence was
not subtle: **the `funnel` outcome fired zero times under every intent**, because
its band was 0.08 wide and the touch band above it took everything. A three-way
cascade with a dead middle rung is a two-way cascade, and the block-intent dials
that shift that rung were shifting nothing.

Set to the shares Gate D asks for: a stuff at roughly the top eighth of the
distribution, and touch plus funnel taking about another thirty percent, so the
block is involved in 40% of attacks and terminates 12% of them.

**These are the legacy resolver's, and nothing reads them while the geometric
attack is open.** `_geometric_promotion` overwrites `block_outcome` whenever
`ENABLE_GEOMETRIC_ATTACK` is true, so on the production path the outcome comes
from `AttackResolutionModel._block_contact` -- a height and edge comparison
against a real wall -- and these three thresholds decide nothing. Changing them
produced byte-identical rallies, which is how that was discovered.

They are kept rather than deleted because `_contest_block` is a live fallback:
turn the geometric flag off and it resolves every block again. What must not
happen is what already had -- a calibration tuning them and reporting the
result as the game's block mix. `ExecutionScaleCalibration.contest_shares`
did exactly that, had zero callers, and has been deleted.

## `func _block_hands_intent(`

*in `(module level)`*

What this blocker means to do with their hands.

Three sources, in the order a real decision has them:

1. **The instruction**, when the manager wrote one. `TacticSheet` stores a
per-voli block behaviour and "soft block" and "kill block" are two of its
four options -- this is their first consumer. A voli told what to do does
it, which is what an instruction is for.
2. **The read**, when nobody said. `AttemptJudgment.backs_off` asks whether a
player recognises that what they are attempting is beyond them, and a
blocker who is late, low or facing a swing they cannot beat is in exactly
that position. Recognising it and angling the hands back *is* the safer
option, so the same function that makes a setter take the high ball makes a
blocker take the soft block.
3. **Pressing**, otherwise. A blocker who is on the ball, or who has not
noticed they are not, goes for it.

`deficit` is how far the swing is beyond this block, on the 0-to-0.4 scale
`AttemptJudgment` documents: zero when the contest is winning, growing as the
swing pulls ahead.
Returns `{hands, call, followed}` rather than a bare string, so a rally record
can say what was *asked* as well as what was done. An instruction nobody can
see obeyed or ignored is not an instruction.

## `var short_of_the_ball := (1.0 - clampf(close_fraction, 0.0, 1.0)) \`

*in `_block_hands_intent`*

**Late and low, not behind on the contest.**

The first version read the deficit off `contest - attack_quality`, and every
block in the game came out pressing: 224 of 224. That margin is the
*outcome* of the contest, decided after the fact and including the execution
roll -- a blocker in the air cannot feel it, and it sat at or above zero even
on swings the wall went on to miss.

What a blocker can feel is whether they got there. `primary_close` is how
much of the travel to the ball they completed, and a blocker who is still
closing knows it in the air -- that is the moment the choice is actually
made. The contest margin still contributes, because a wall that is beaten on
height as well as position is further outside its capability, but it is the
smaller term rather than the only one.

## `const BLOCK_KILL_STUFF_BONUS: float = -0.045`

*in `_block_hands_intent`*

What the hands are *trying to do*, which is a different axis from where the
wall stands.

`block_intent` -- Seal or Funnel -- is lateral: it decides which part of the
hitter's cone the wall takes away. This is the other axis, and the sport has
always had both: two blockers at the same height with the same timing produce
different balls depending on whether they pressed over the tape to end it or
angled back to keep it alive. It is not an attribute. It is a decision, and
`AttemptJudgment` is the module that already models exactly this decision for
the second and third contacts -- a setter backing off a quick, a hitter
rolling instead of swinging. The block is the fourth contact that needs it and
the only one that never asked.

**Pressing is not simply better.** A kill block that comes off wins more
rallies outright; one that is beaten hands the hitter a tool at full pace,
because there is nothing behind hands that are already committed forward. A
soft block gives up stuffs and converts the swing into a ball the defence can
actually play. That trade is the whole reason the choice exists, and it is why
this changes both the stuff margin and the absorption rather than only one.

## `const DEFAULT_TRANSITION_SECOND_CONTACT_SECONDS: float = 0.68`

*in `_block_hands_intent`*

Where an own-side delivery actually arrives, in metres of standard deviation
from where it was aimed.

Own-side contacts do not need trajectory simulation -- there is no line to be
on the wrong side of and no block to intersect -- but they do have to emit a
*position*, because the next contact's geometry reads it. Until now a set
landed on `CourtConstants.lane_target(lane)`, a fixed table entry, so a 0.95
set and a 0.35 set delivered the ball to the identical point and set quality
had no geometric consequence whatsoever.

Values are the ones specified in
docs/textbook/EVENT_CALCULATION_TAXONOMY.md, which designed this before it
was built. Stated in metres and converted per axis at the point of use,
because the court is 9 m across and 18 m deep -- one normalized number would
scatter a ball twice as far sideways as long.
What a transition second contact gets when the dug ball has no modelled
flight. The literal 0.68 this replaces was the only contact window in the
engine not derived from a ball; it survives as the fallback rather than being
deleted, because a dig genuinely may not have an arc yet.

## `const HOME_SET_DELIVERY_MIN_Y: float = 0.515`

*in `_block_hands_intent`*

How far a delivery is allowed to stray before it stops being a delivery.

A set nominally lands at y = 0.53, which is 0.54 m from the net, and the
worst-case spread is 0.40 m -- so an unclamped tail can put the ball through
the net onto the opponent's side. That is a real volleyball event (the
overpass), and emitting a position rather than a table entry is exactly what
makes it *detectable*, but there is no rally branch that plays one out yet.
Until there is, the delivery is held on its own side rather than silently
teleporting the rally. The former 0.51 floor was only 18 cm from the tape --
close enough that a regulation-size ball plus a reaching hand visually read
as clipping it. 0.515 is 27 cm, and changes only this error tail; the intended
front-row target remains centred at 54 cm.

## `const FUNNEL_READ_BONUS: float = 0.075`

*in `_block_hands_intent`*

What the wall in front of a defender tells them.

**Funnelling has never bought the diggers anything, which is the whole point
of funnelling.** A block told to funnel gives the line and channels the ball
into the middle, so the defence behind it knows where to be -- and until now
the intent moved only the wall's own position, so choosing it was a decision
with no consequence for the six people it was made on behalf of.

Sealing is worth less rather than nothing: holding the line still removes one
option, it simply concedes the angle rather than narrowing it. A touched ball
is worth the most of the three, because a defender is reading a ball that has
already slowed and changed direction -- and the engine already pays them the
extra flight time for it, so this is the read that goes with the time.

## `const OPPONENT_QUICK_CALL_PASS: float = 0.68`

*in `_block_hands_intent`*

Where a pass stops supporting a quicker call and starts forcing a slower one.
Asserted rather than swept -- see `_tempo_call`.
**Measured against the distribution it cuts, and it is outside it.**

Home pass quality runs p10 0.291, p25 0.350, p50 0.419, p75 0.494, p90 0.567
(`tools/run_shot_downgrade_probe.gd`). A quick-call floor of 0.68 sits above
the ninetieth percentile, so the quicken branch of `_tempo_call` fires
essentially never -- while `OPPONENT_SLOW_CALL_PASS` at 0.38 sits between the
first quartile and the median and fires on roughly a third of balls. The tempo
call is therefore a one-way ratchet toward the slowest set in the game, which
is most of why 91% of home swings are tempo 3.

Not moved here, because it is shared with the opponent's path and their pass
distribution is a different shape (p50 0.276 against the home side's 0.419) --
one constant cut against two distributions is its own problem and wants its
own measurement rather than a value tuned until the home side looks right.

## `const LIVE_QUICK_CALL_PASS: float = 0.49`

*in `_block_hands_intent`*

The three tempo gates, re-sited on the distributions they actually cut.

Every one of them was set outside its own spread, which is why 91% of home
swings came out at tempo 3 and `tempo_variation` and `transition_commitment`
were attributes that changed nothing for the default identity.

quick call        pass quality p75 is 0.494 home, 0.486 opponent; the old
0.68 sat above *both* p90s and never fired once
tempo variation   presets run 0.24-0.88 with Balanced on 0.50
commitment        blended presets run 0.225-0.843, three of six in 0.42-0.51

Each is placed at or just below the median of its own table, so the default
identity is inside every gate rather than outside all three.

## `const COMMITMENT_FULL_PULL: float = 0.34`

*in `_block_hands_intent`*

How far from neutral a blended commitment has to sit to pull the tempo every
time it can.

**The gates above were the right fix to the wrong shape.** Re-siting them
inside their own distribution stopped them missing the default identity, and
left them as *gates* -- so Pāwa Hitō at 0.841 and Xérvu at 0.644 both cleared
`LIVE_COMMITMENT_HIGH` and received exactly the same instruction, and the
region whose entire identity is relentless transition was indistinguishable
from one whose identity is serving. Measured across 640 rallies each, their
mean tempo came out 1.86 against 1.91 and their nearest-neighbour separation
was the second-tightest in the league.

Tempo is an integer 0-3, so a continuous input cannot become a fractional
shift; it becomes a *probability* of the shift. The number is the largest
deviation from neutral the regional table actually contains -- blended
commitment runs 0.30 (Blôc du Larg) to 0.84 (Pāwa Hitō) around a neutral
0.50 -- so the two extremes act on every eligible set, Landavol at 0.50 acts
on none, and everyone in between is graded rather than sorted.

## `const HITTER_PRESET_SHARE: float = 0.82`

*in `_block_hands_intent`*

How much of the pre-set window the hitter is credited with.

The blocker already gets `preset_window * preset_share`, 0.26 to 0.72 of it
depending on their read -- and the hitter got nothing at all, despite both
reading the same pass. That is why running quick *cost* the offence: measured
across the six identities, kill rate fell monotonically with tempo shift,
0.3774 for the identity that slows sets down against 0.3239 for the one that
speeds them up. A first-tempo ball squeezed the attacker and left the wall's
head start untouched.

Higher than the blocker's best share, and deliberately: a hitter knows the
play and starts their approach off the pass, while a blocker cannot commit
until the set is up and is guessing until then. The pre-set window is worth
more to the person who already knows where they are going.

## `const DIG_ATTACKER_ADVANTAGE: float = -0.04`

*in `_block_hands_intent`*

How much the attacker is favoured when swing and dig are equally good. A
clean swing beats a set defence more often than not, so an even contest is
not a coin flip.
Measured, not assumed: with the block re-derived, 416 swings reached the
floor and 82% of them came up. A clean swing beating a set defence should not
be the exception, and at 0.09 an even contest was close to a coin flip on a
scale where the two sides sit at parity.

**How much better than the defence an attack has to be to beat it.**

Named for what it is now rather than for what it was. As
`DIG_ATTACKER_ADVANTAGE` it sat at +0.07, and read against `edge = defence -
attack` that means the defence had to be *seven points better* just to draw
level: at equal quality the attacker won. The design says the opposite --
"a good defence beats a good offence, but a good defence loses to a much
better offence" -- so the sign was wrong for the claim it was implementing,
and the previous re-fit from 0.20 had moved its size without questioning its
direction.

Negative, so the defence holds when the two are level and keeps holding while
it is up to this far behind. Above that the attack is through, and
`_dig_outcome`'s grading then makes the rest of the margin count: a ball that
clears the bar by a little is dug badly, one that clears it by a lot is a
kill. That is the "much better" half, and it is a slope rather than a second
threshold.

Measured against the distribution it cuts: over 247 digs the margin runs
-0.517 at the tenth percentile to +0.468 at the ninetieth, so a bar anywhere
in that range moves a real share of contests rather than sitting off the end
of it doing nothing.

**Sized by what the statement actually claims, which is parity.** "A good
defence beats a good offence" is a claim about *level* quality, not about the
defence being handed a cushion. At -0.14 with the solo share raised alongside
it, the dig rate came out at 0.630 against a 0.35-0.55 band and the kill rate
fell to 0.382 -- a defence that wins comfortably, which is a different and
worse claim. Just past zero is the whole of what was asked for.

## `const DIG_SOLO_SHARE: float = 0.93`

*in `_block_hands_intent`*

One defender is not a whole defence. The attacker picks where the ball goes;
a defender covers the zone they were assigned. Without this the dig scale
centred above the swing scale -- exactly the mismatch a solo block had at
0.78 -- and 470 swings produced 42 kills against 63 errors and 44 stuffs.

**0.90 from 0.62, and this is the re-fit `docs/BACKLOG.md` has been waiting
on.** The whole floor defence was fitted against attacks modelled as
ground-to-ground lobs; a spike is struck downward at 16 to 30 m/s and arrives
in about half the time, which is the correction the drawing landed. Fitted
against the sport rather than against the previous number -- over 700 rallies,
both serving sides, the three rates a real match has real values for:

before   after   target
kill rate        0.628   0.481   0.45 - 0.50
dig rate         0.232   0.478   0.35 - 0.55
stuff rate       0.106   0.112   0.08 - 0.14

`tools/run_rally_balance_probe.gd` is that reading and is the instrument to
re-run before touching either of these again.
**Raised from 0.90 with the ball's new pace.** One defender is still not a
whole defence and this still says so; what changed underneath is that a spike
now arrives at up to 28 m/s where it used to arrive at 18, and the floor
defence was priced against the slower ball. Measured after the pace work, the
two fastest speed bands were dug 12% and 11% of the time -- a hard swing had
become close to undiggable, which is the opposite of a defence a viewer can
be proud of. This is the flat buff that pays for the faster ball, sized at
0.93 rather than the 0.96 first tried: with the breakthrough bar moved as
well, 0.96 double-counted the same correction and pushed the dig rate out of
band on the other side.

## `const CLAMPED_CONTACT_SEVERITY: float = 0.22`

*in `_block_hands_intent`*

What a metre of dragged-back contact costs the swing.

`_reachable_contact` spares a hitter who cannot make the ideal contact by
moving the ball to them, and `ENABLE_CLAMPED_ARRIVAL_MARGIN` correctly stops
billing them for lateness afterwards. But hitting from a metre further off the
net is genuinely worse -- a flatter angle over the tape and a longer ball to
the floor -- and with the lateness gone nothing charged that at all. Measured
on the displacement fixture, a hitter dragged 0.74 m back came out marginally
*better* for it.

Sized against the term it replaces rather than chosen. The old lateness charge
reached the swing through `swing_deficit * ATTACK_OVERREACH_SEVERITY`, and the
arrival component of that deficit ran about 0.66 for a clamped opponent swing
-- roughly a metre of drag for roughly a point of deficit. This is that same
exchange rate expressed in the channel the cost actually belongs to.

## `const DEFAULT_SECOND_CONTACT_SECONDS: float = 0.68`

*in `_block_hands_intent`*

FLAGGED. These four bound every setter's tempo and are now load-bearing:
`ENABLE_OPPONENT_APPROACH_WINDOW` spends `DEFAULT_SET_RELEASE_SECONDS +
DEFAULT_SECOND_CONTACT_SECONDS` as the pass-to-release window that lets a
hitter walk to their mark, so a fix rests on two numbers nothing derived.

They are defensible *as defaults* -- a mean pass-to-release time is a real
quantity and `SYSTEM_FIT_SET_RELEASE` already varies it per setter. What is
missing is not a derivation for the mean but a consequence for the tail: a
setter working far outside their band is modelled as merely *inaccurate*, and
that is not what happens. A ball held too long is a lift, and a poor or
out-of-position setter -- a libero forced to set, a young middle taking the
second ball -- commits ball-handling faults at a rate the sport notices.
`MINIMUM_SET_RELEASE_SECONDS` and `MAXIMUM_SET_RELEASE_SECONDS` currently clamp
silently where they should sometimes produce a fault instead.

So the work here is a lift/double-contact outcome driven by `setting_technique`
against the release the situation demands, not a better constant.

## `var player_facing: Dictionary = {}`

*in `_block_hands_intent`*

Which way a body was set when it finished its last committed leg.

The third of the three things a body carries, beside where it is and what it
is carrying. Only a leg whose *form* establishes an orientation writes here --
`movement_establishes_facing()` decides, so a shuffle or a block close leaves
whatever was already set. A voli with no entry is seeded from their side's
ready facing by `RallyStateBuilder`, which is what every actor got before this
existed.

**Expected inert for defenders, and that is not a failure.** Every defensive
leg in the resolver is `"lateral"` and LATERAL preserves, so a defender cannot
change their own orientation while the form comparison is blocked -- measured
at 2 of 796 defensive contacts made by a body that had run. See
`docs/review/ACTOR_CONTINUITY.md`.

## `var exertion_cost: Dictionary = {}`

*in `_block_hands_intent`*

What each player *did*, in condition, this rally.

**Fatigue used to be charged by the rally rather than by the work.** Everyone
on court paid `RALLY_FATIGUE_BASE` whether they had jumped six times or stood
in position and watched, which makes conditioning a property of being selected
rather than of playing. A middle who blocks every ball and a libero who never
leaves the floor tired at exactly the same rate, and the one attribute meant
to separate them -- `stamina` -- could only scale a number that was already
the same for both.

Booked here and charged by the match layer, exactly as `recovery_fatigue_cost`
already is, and for the same reason: a resolver that writes to the roster it
is resolving breaks replay determinism, and the gate catches it immediately.

## `var narration: Dictionary = {}`

*in `_block_hands_intent`*

Names available to player-facing narration, filled in as the rally reaches
each contact.

`RallyExplanations` substitutes these into headline, explanation and factor
text. Threading them through the ~20 `factor()` call sites individually would
have meant proving each name was in scope at each one; accumulating them here
means a line can only name a role the rally has already resolved, which is
the same constraint stated once.

A per-call `values` dictionary merges *over* this, so a line about the
opponent's hitter can override `hitter` without disturbing the home name the
rest of the rally uses.

## `var opponent_authored_plan: Resource = opponent_team.current_defensive_plan() \`

*in `resolve`*

Weights are relative importance and are normalised by their own total, so
this is a genuine 0-1 quality rather than one capped at the coefficient
sum. They previously added to 0.72, which meant an opponent server with
every rating at 100 produced 0.72 -- and since reception subtracts
`serve_quality * 0.48`, the most dangerous serve in the game could apply
only 0.35 of pressure. The home formula already spans the full range
because its tactical risk term makes up the remainder.
The server's own appetite, then the bench's, on the same 0.70 scale the
home side uses. This read the player attribute alone, so an opponent whose
whole identity is the serve -- Xérvu at 0.92 -- served exactly like one who
never risks it, and `serve_aggression` was the single best-wired principle
in the resolver while being visible from only one side of the net.

## `)`

*in `resolve`*

**`end_height` stays NAN, and that is a ruling rather than a gap.**

Publishing a real one was tried: `out_reason` already says whether this
serve stopped at the tape or reached the floor, so the flight's own
endpoint is a fact and not a choice. The suite refused it -- 60 of 120
serves -- and the refusal was correct. `end_height_meters` is not read
as this flight's endpoint. `BallFlight.from_trajectory` reads it as the
height of the **next contact**, and the comment inside
`_ball_trajectory` already names the conflict: *"Those are different
numbers and choosing between them is `CONTACT_AND_BALL_FLIGHT.md`'s
unresolved item 5, not something to settle as a side effect of owning
the launch."*

So the 1.000 m default is a placeholder standing in for an unresolved
design question, not a bug to repair. See
`docs/review/BODY_CENTRE_SCOPE.md` section 6.

## `var reception_origins := {}`

*in `resolve`*

**Judged from the bodies, not the formation.** `origins` is optional and
this call omitted it, so every voli was measured from their zone centre --
which `evaluate_arrival` itself says is "true in a serve-receive formation
and true nowhere else". At serve time it is nearly true, and the cost was
invisible until something asked about *spacing*: measured over 590
contested receptions the nearest-teammate distance came back 2.99 m on
every single one, p05 through max, because it was the distance between two
fixed points on a formation diagram rather than between two volis.

A constant input is a knob that cannot reach its own range, which is this
repository's most-repeated failure, and it would have made the crowding
term below unfireable while looking exactly as though it worked.

## `var serve_free_flight: Dictionary = canonical_serve.get(`

*in `resolve`*

**Where this ball is passed, which is not where it lands.**

The reception used to be stamped at `serve_trajectory.end_time` and placed
at `serve_landing` -- the moment and the point at which the ball reaches
the floor. A passer meets a descending serve at their platform, which is
strictly earlier and, at serve pace, a metre or more in front. The old
contact was at ground level and only looked like a height because the
reader integrated the launch under 9.8 where this ball falls at 21.009,
which turned a ball on the floor into a ball at 3.79 m. See
`docs/review/SERVE_RECEPTION_HEIGHT_SEAM.md`.

The height is the same `pass_contact_height_meters` this path already used
for the outgoing pass and for `_reached_point` below, so the contact is now
resolved at the height the body was always being placed for.

**Named residual:** the claim above still ranks candidates against the
landing and the full serve duration, because who takes the ball is decided
before which body's platform height applies. A passer reading where a serve
is coming down is the right way to choose, but it leaves the claim's
arrival margin measured over a window 0.084 s longer than the one actually
available on the seed above. Bounded and stated rather than fixed by
guessing a representative height here.

## `delivered_set_contact_height \`

*in `resolve`*

**Where the ball was, not how high the setter can reach.**

This read the pass's *apex* -- the highest the ball ever got -- and
clamped a body-derived release height against it. The apex is not the
contact: a ball that peaked at 2.9 m and was met on the way down at
1.79 m left the setter's hands, on the published record, from 2.46 m.
Both legs of that contact claimed to know their heights and disagreed
by 0.40 m on 87 of 88 sets, which is the one seam in the census where
two *facts* contradict rather than a fact meeting a default.

`delivered_set_contact_height` is that contact, already computed above
from the interception rather than the launch, and already consumed by
the capability read -- its own comment says the two "have to consume
the same one or the two describe different contacts". The set arc was
the third reader and took a different number.

No feasibility is lost by dropping the reach clamp: M5's opportunity
search decides *when* this setter can touch this ball, so a height it
returns is one they could reach. The clamp was re-checking a question
already answered, against the wrong quantity.

## `var set_contact_time := (`

*in `resolve`*

The instant the ball leaves the setter's hands. The set flight, the SET
event, and the hitter's approach window are all timed from this one value.

**The two arms measure from different origins, and only one of them can add
a duration to `rally_clock`.** On the home first ball the clock is never
advanced to the reception -- the reception derives its own moment from the
serve's `end_time` instead -- so `rally_clock` sits behind the pass. The
legacy window is a duration measured from that same lagging origin, so the
sum stays self-consistent. A physical interception is not: its `contact_time`
is an absolute moment on the free flight's own timeline, and adding the
interval between two absolute moments back onto the lagging clock lands the
set *before* the reception that fed it -- which is what the causality floor
was correcting. Read the interception's own moment instead. The transition
paths reach the identical quantity by the other route, because there the
clock has already been advanced to the feeding contact.

## `var home_cover_stage_intents := {}`

*in `resolve`*

**FD-003, the attacking side's own six.** This leg is the set flight, and
until now only the *defending* side was published on it -- the wall
staging and the floor shape behind it -- so half of every attack leg was
`_support_target_for_side` guessing with a lerp table.

Cover is not struck into existence. It is walked into while the set is in
the air, and the block leg has always published the finished shape from
the same helper; this is that shape one flight earlier, through the same
traversal authority, so a voli who cannot reach the ring inside a quick
set's flight simply does not get there. Written into `live_positions` for
the same reason the opponent's staging is: a map that presentation draws
toward and the resolver then reasons from a different position would be
two answers to one question.

## `opponent_live_positions[opponent_defender.id] = opponent_defender_reach`

*in `resolve`*

Where they actually ended up, not where the ball was. A defender who was
beaten to it starts the next phase short of it, which is the position the
rest of the rally should reason from.

**Above the event, because the event reads it.** This sat below the
`_add_event` call, alone among the four floor-defence sites -- the home dig
and the transition dig both write the reach before appending. Nothing
between the two lines resolved anything, so the drift was invisible until
two published facts started reading `opponent_live_positions` at append
time: `body_contact_position` reported every opponent digger contacting
the ball from the spot they started at (13 of 13 diggers, mean travel to
the ball 1.97 m, mean travel to the published body 0.000 m), and
`opponent_phase_targets` below published a defensive shape in which the
digger had not moved while the caption said "after moving 1.8m".

## `var opponent_lineup: RotationLineup = opponent_team.current_lineup()`

*in `_resolve_home_serve`*

`opponent_setter_release` is resolved above, before the pass, because the
pass is thrown at it. It used to be the hardcoded court centre (0.50,
0.34), which put the setter directly on top of whoever was covering the
middle -- the setter marker visibly vanished inside another opponent's
during serve receive -- and had them setting from a position no setter
takes.
Stage the setter where a setter stands.

The receiver gets a live position on the line above and the setter never
did, so `_resolve_opponent_transition` fell through to
`court_position(id, "transition")` -- the rotation's transition base --
and had the setter run to the release point from there on every single
serve. Measured over 488 sets that put their arrival term at -0.153
against the home setter's -0.022, about 0.85s late against 0.12s, and it
dragged two more terms with it: a setter reaching from the wrong place is
the same setter whose delivery lands outside their capability and whose
set travels a worse angle. Those three terms carried the entire 0.287 set
gap, which in turn was the largest asymmetry left in the engine.

The home setter is walked to their release target during the serve's
flight through `staged_next_position` on the reception event. This is that,
for the one player on the other side of the net who needed it.

## `head_start_seconds: float = 0.0,`

*in `_resolve_opponent_transition`*

**How long these volis have already been running when the pass is played**,
which on this side of the net was nothing at all.

The home side has passed the feeding ball's own flight into
`_spatial_setter_choice` since that parameter existed -- the serve's for a
first ball, the swing's for a transition -- because a setter releases
toward their zone when the ball is *struck*, not when the platform touches
it. This path passed nothing, so every opponent second contact was timed
from a standing start.

That was invisible while the designated setter's duty bonus was large
enough to win regardless. Once responsibility stopped being absolute the
two sides began answering identical physical situations differently: on a
stranded-setter fixture the home side kept the setter and the opponent
transferred the ball, with nothing between them but this argument. Gate
`HOME/OPPONENT SYMMETRY` in `tools/run_second_contact_probe.gd`.

**Last in the list deliberately**, for the same reason
`incoming_pass_trajectory` above is: four callers pass this function
positionally, and inserting a parameter in the middle silently hands one
of them a float where a trajectory belongs.

## `var setter_choice_matches: bool = \`

*in `_resolve_opponent_transition`*

**Consume the selection rather than rebuilding a second one.**

These four values used to be reconstructed here from scratch: the start
re-read from `opponent_live_positions`, the route re-solved, the travel
re-timed on the `lateral` profile, and the margin measured against the
literal `DEFAULT_SECOND_CONTACT_SECONDS`. All four already existed on
`opponent_setter_choice`, computed from the state the voli was actually
selected on -- so the side effect was that selection and execution
described two different setters.

Measured on one selection with both recipes applied to it: with the serve
flight as a head start the chooser had the setter standing **on** the ball
(0.000 m, margin +0.420 s) while this block had them 1.698 m away with a
margin of -0.287 s. Worse, that -0.287 was **identical at pass durations
of 0.42, 0.68, 0.95, 1.30 and 1.80 s**, because a constant cannot hear the
ball. The home side has measured the same quantity against
`second_contact_window` since it existed.

The profile change from `lateral` to `transition` rides along and is not
cosmetic: it is the profile the chooser timed the decision on, so keeping
`lateral` here would be preserving the disagreement rather than the model.
An earlier note held the travel time back to avoid "a second change
wearing this one's name" -- correct then, when both recipes at least
started from the same position; the head start ended that.

The fallbacks matter: `_spatial_setter_choice` can return a `player` that
is not `opponent_setter` after the two null-guards above, and consuming
another voli's run would be a worse error than rebuilding one. Guarded.

## `var setter_move_time: float = float(opponent_setter_choice.travel_time) \`

*in `_resolve_opponent_transition`*

**A release is a run, so this leg is `transition`.**

It was `lateral`, and it was the only setter movement in the engine that
was: `_spatial_setter_choice` -- the selector both sides and the shadow
systems go through -- resolves a release as `transition` at both of its
movement sites. This is the fallback taken when the second contact
transferred away from the designated setter, and what it computes is still
a *release*: the designated setter travelling from where they stand to the
setting position. Purpose decides the form, not distance. A setter opening
up and running to the ball is the same movement whether or not they end up
being the one who sets it.

The policy's other half -- an established setter *adjusting* to a realized
pass is `lateral` -- has no site in the resolver today. There is one setter
movement, base to setting position. Recorded rather than given a site it
does not have. See `docs/review/HOME_WALL_FORMATION.md`.

## `var opponent_tempo_call := _tempo_call(`

*in `_resolve_opponent_transition`*

Same model as the home transition set, and now the same attributes. The
two sides read different ones -- this side set_accuracy, court_vision and
decision_making, the home side set_accuracy, ball_control and composure --
so a setter improved on one team's terms was not improved on the other's.
The opponent's own capability read, run on a serve reception exactly as
the home setter's is. On a dug ball there is no called play to overreach
against, so the penalty is zero and the pass stands as it arrived.
A dug ball is set high by anybody. The opponent asked its serve-receive
tendency what to run on a scramble ball too, so it played the same middle
tempo out of defence as it does off a clean pass -- while the home side
has always set its own transition high. The tendency is what the bench
prefers *when there is a choice*, and out of defence there is not one.
Their bench's call, then their bench's identity on top of it -- the same
two steps the home side takes, in the same order. Without the second one
`tempo_variation` and `transition_commitment` were home-side attributes,
so a Spëddigh opponent ran Landavol's tempo.

## `var opponent_hitter_slot := int(opponent_team.current_lineup().slot_for_player(`

*in `_resolve_opponent_transition`*

**Per lane, not the general floor.** The first cut of this mirrored
`HOME_SET_DELIVERY_MIN_Y` and dropped `lane_delivery_min_y`, which exists
for exactly one reason: the pipe has an attack line to respect and the
pins do not. Six of 170 opponent back-row swings were struck in front of
the line -- the identical defect `court_constants.gd` records the home
side having, whose own note says a zone edge is not a legality guarantee
and the floor belongs on the delivered point.

Mirrored about the net, so the home side's *minimum* y becomes this
side's *maximum*: further from the net is a smaller y on their half.
**Asked of the hitter's row, not the lane's name.** The first cut of this
read `lane_at_x`, and a lane cannot tell you this: the pipe is
distinguished by *depth*, so a centre-x ball reads as a quick whether it
sits at the net or behind the line. The floor stayed inert and the same
six of 170 back-row swings were struck in front of the line.

The rule is about the body: a voli in a back-row slot must contact behind
their attack line wherever the ball is. `lane_delivery_min_y` already
encodes exactly that distance under the name "Pipe", which is the home
side's only back-row lane, so it is asked for it directly rather than
having the number restated here.

## `var resolved_set_geometry := _set_geometry(`

*in `_resolve_opponent_transition`*

The authoritative value, once the real hitter and contact point are known.
This is the one that feeds the swing, and it kept the retired formula
after the provisional computation above was moved onto the shared model --
so the propagation link and the aligned attribute list reached the
estimate and never reached the ball.
The geometry of the set that is actually being played.

`set_geometry` above is computed before the hitter is chosen, against
`Vector2(0.50, 0.48)` standing in for a target nobody knows yet -- and
then reused here, where the target *is* known, so every opponent set in
the game was scored for difficulty as though it were being delivered to
the middle of the court. The home side has never done this: it reads
`intended_set_target` and the setter's release seat, which is why its
difficulty term sits at 0.077 against this side's 0.131.

It went unnoticed while the setter stood exactly where the pass landed,
because a placeholder distance and a real one were both short. Scattering
the pass gave the setter ground to cover and the fiction started costing
the opponent a set.

## `if RallyFeatureFlagsModel.ENABLE_DELIVERED_SET_SHOT_CHOICE \`

*in `_resolve_opponent_transition`*

Decide roll-against-swing on the set that was delivered.

`_choose_opponent_attack` had to pick a hitter before the contact existed,
so it read the *first* `opponent_set_quality` above -- computed against
`set_geometry.difficulty`, whose target is the placeholder `(0.50, 0.48)`
rather than the contact the setter actually found. The two are not close:
the SET event stamps a median of 0.755 while shot selection was reading
about 0.344, and the consequence was that 97% of opponent attacks came out
as rolls or tips -- three power swings in a hundred and twenty -- despite
only 11% of their sets falling below the compromise threshold.

That is upstream of most of the dig asymmetry. A side that rolls nearly
every ball hands the other side a slow lofted one to read, which is the
0.526 s of defensive flight time against 0.339 s, and everything the reach
margin and the dig rate inherit from it.

Re-applied here rather than fixed in place because the ordering is genuinely
circular: the contact decides the set's difficulty and the set's difficulty
decides the shot. Who swings stays chosen on the estimate; only what they
do with it is re-read. The improvisation draw is carried from the first
decision rather than redrawn, so the number of draws a rally consumes is
unchanged and no seeded outcome downstream is re-sequenced.

## `var opponent_incoming_pass: Dictionary = {}`

*in `_resolve_opponent_transition`*

When the setter actually touches the ball.

This set was stamped at bare `rally_clock` -- the moment of the pass that
fed it -- so the opponent set left the setter's hands at the same instant
the ball arrived at them, with no flight from the passer and no release.
210 of the sub-20ms event gaps in `run_playback_schedule_probe` were this
one thing.

The home side has always used the incoming pass's own flight plus a
release interval drawn from the setter's system fit, and this function
already knew the figure: it hands `DEFAULT_SET_RELEASE_SECONDS +
DEFAULT_SECOND_CONTACT_SECONDS` to `_form_home_block` below, described
there as "the opponent's own pass-to-release time". The block was reading a
delay the set itself did not take.

## `var opponent_set_incoming := Dictionary(`

*in `_resolve_opponent_transition`*

**The ball this set was resolved against.** Stamped so the chain from
a dig to its set can be proven by identity rather than by two
endpoints happening to be close. Empty for feeds that publish no
physical flight, which is what makes the remaining gaps countable.

Under a physical interception the ball that reached this setter is the
**realised prefix**, not the full authoritative flight to the floor --
the very segment `_stamp_free_flight_resolution` wrote onto the feeding
contact as its outgoing ball. Report that same object here, so the
dig-to-set chain holds by identity and the setter's window is the
interception time it was actually resolved against, rather than the time
the untouched ball would have taken to land. Legacy and spatial feeds
carry no realised segment and fall through to the full flight unchanged.

## `var home_block_read_tags: Array[String] = []`

*in `_resolve_opponent_transition`*

The home block reads the opponent, the way the opponent block reads them.

`_opponent_block_adaptation_bonus` gives the opponent's wall a quality
bonus when it anticipated the lane and tempo it is facing, drawn from
`observe_rally` accumulating what the home team keeps doing. The home wall
had no equivalent -- `observe_rally` is called once per rally for the
opponent alone and nothing records what the *opponent* keeps doing -- so
scouting in this engine ran one way across the net.

It is read per blocker rather than per team, through the familiarity model
the opponent's floor defence already uses. That is a deliberate difference
from the opponent's team-level `block_bonus()`: a blocker who has faced
this hitter in this lane has learned something a team average cannot
express, and it needs no new store because familiarity already persists on
the player. The team-level half -- a home equivalent of `observe_rally`
and `scouting_confidence` -- does need one, and is not built here.

## `var opponent_attack_spin := _swing_spin(opponent_hitter, opponent_record)`

*in `_resolve_opponent_transition`*

The full shot, to where it is actually aimed. `_contest_block()`
re-slices this to the net if the block touches it; truncating here
unconditionally made every opponent spike travel about three percent of
the court and the rest arrive as a "deflection".
**The record itself, not a copy fetched back out of the trace.**

This read `_trace_summary()["geometric_attack_opponent"]` -- the same
dictionary, stored four lines above and retrieved here. Except the store is
conditional on `shadow_reception_trace`, and that is null on every path
that never built a trace, an opponent transition inside a home serve
foremost among them. On those rallies the retrieval came back empty, so the
swing lost its speed *and* its certified launch angle and was redrawn as a
generic driven spike.

Measured by side, which is the split that found it: home swings carried the
angle on 15 of 16 lofts, opponent swings on 1 of 19 -- 18 lofted opponent
attacks drawn going *down* at a mean of -9 degrees, and 14 of them straight
into the net. `docs/BACKLOG.md`'s first failure mode, once more: a value
computed correctly and dropped before anything could use it.

## `var opponent_swing_flight: Dictionary = opponent_attack_trajectory`

*in `_resolve_opponent_transition`*

**The swing the wall actually met, re-read after the truncation above.**

The block event used to publish `opponent_attack_trajectory` -- the local
captured *before* that re-slice -- as both its incoming ball and the source
of its own timestamp. So on every home block that touched the ball, the
wall was recorded intersecting an arc the attack no longer had: measured at
100 of 100 touching home blocks against 0 of 113 on the opponent side,
which is the tell that this is one path drifting from its twin rather than
a shared rule being wrong.

The timestamp came with it. `_contact_time` is the flight's `end_time`, and
on an *untruncated* swing that is the moment the ball reaches the floor
behind the blockers -- so the hands were being stamped up to 1.140 s after
the ball they were supposedly touching had landed. `_swing_reaches_net`
exists for exactly this and its own note says why: reception, set and dig
happen when a flight finishes, a block happens partway through one.

Read through the event rather than kept in a second local, because the
event's metadata *is* the published ball and a local copy is how the two
came apart in the first place.

## `var visible_opponent_attack: Dictionary = opponent_attack_event.metadata.get(`

*in `_resolve_opponent_transition`*

**The dig's flight budget is the flight that was drawn.**

This was the whole dig asymmetry, and it was never a defensive defect. The
same opponent swing was solved twice with two different launch angles: the
drawn arc used the hitter's own shot shape, and the defender's budget was
re-solved through `_opponent_attack_type` -- a *defensive* classifier, whose
"Short tip" branch covers everything landing inside y 0.80, which is most of
the court. So most opponent swings were lobbed at 22-32 degrees for timing
purposes and hit flat at 5-14 degrees for drawing purposes.

Measured on identical rosters: home defenders got 0.739 s of flight and
opponent defenders 0.490 s, and every downstream term inherited exactly that
gap -- reaction delay was equal at 0.325 s against 0.333 s, and physical
reach differed by 0.74 m purely because one side had 2.5x the time to travel.
Three earlier passes chased this as a claim or positioning problem.

`attack_type` above still classifies the ball for the *defence* -- which is
what it was written for -- and no longer decides how fast it flies.
**Measured, reverted, and the measurement is the finding.**

Reading the drawn flight here was tried unconditionally in the same pass
that made the drawn flight physical, on the reasoning above -- the two
expressions are one fact computed twice, and the drawn one is now correct.
It is still one fact computed twice. But the drawn flight is no longer a
0.74 s lob, it is a struck ball at 12 to 20 m/s, and handing the floor
defence that number produced, over 700 rallies:

opponent swings   681 -> 8
home kill rate  0.85 -> 1.000

Nobody digs anything, so no rally reaches a second exchange, so the
opponent never attacks. That is not the calibration moving; that is the
floor defence turning out to be *entirely* calibrated against attacks being
modelled as lobs, which nothing had measured before because the two numbers
had never been made to disagree this much.

So the lofted classifier stays for now and the ball on screen is right,
which is the honest state: the drawing has been fixed and the defence has
not been re-fitted. Re-fitting it is tasks #62 to #64 -- the same
degeneracy `docs/BACKLOG.md` names as the limiter -- and it is a bigger
change than this one, not a line in it.
**Unconditional now, and the number that closed the dig asymmetry.**

The paragraph above found the defect and the fix stayed behind
`ENABLE_UNIFIED_ATTACK_SHAPE` because turning it on collapsed the rally --
with the dig fitted where it was, giving the home defence the real flight
time meant nothing came up at all. That was never an argument that the two
solves should disagree; it was the dig being calibrated against a budget
only one side of the net received.

Measured over 700 rallies with the dig re-fitted alongside it, this is what
the split was worth:

home dig rate       0.929 -> 0.693
opponent dig rate   0.180 -> 0.307
home kill rate      0.602 -> 0.531
opponent kill rate  0.279 -> 0.415

Five to one, on identical code, entirely because the home defence was
timing the ball off a lofted classifier while the opponent defence timed it
off the swing. What remains of the gap is an offence difference -- home
swings come out at 0.484 and opponent swings at 0.332 -- which is a
different claim and is what tasks #62 to #64 are still for.

## `if assignment.lane not in ["Front Quick", "Right Quick"]:`

*in `_resolve_home_continuation`*

The same read the opponent's setter makes, off the same base. This path
took `_fallback_assignment`'s literal 3 and never varied it, so a home
setter given a clean dig and the judgment to use it ran the same high
ball as one scrambling -- and the histogram's `tempo_demand` term of
0.000 on this path was that constant showing up as a cost nobody paid.
Correct, then clobbered -- caught by counting the lanes against the tempos.

`_fallback_assignment` gives a quick its first-tempo ball, and this line
then overwrote it with a transition call based on `TRANSITION_TEMPO_BASE`,
which is 3. The result was 74 quick *lanes* against 35 first-tempo balls:
a middle running a quick approach under a high ball, which is neither of
the two things it could have been.

A quick is a first-tempo ball by definition -- that is what makes it a
quick -- so the tempo is not the transition setter's to call once the lane
has been chosen. Everything else still reads the dig.

## `var realised_pass_contact_height := float(physical_choice.get(`

*in `_resolve_home_continuation`*

What this setter can actually deliver off this ball.

The transition set was the only set in the engine paying neither a
capability penalty nor a geometry difficulty -- both passed as literal
0.0 -- and carrying no familiarity term at all. It was also the only one
that emitted no `set_terms`, so the gap was invisible to every
measurement: the per-path histogram could rank this path and not
decompose it. Three of the six things a set is made of reached every set
in the game except this one.

The reach term is the substantial one here. A setter taking a low, ugly
dig is contacting the ball below their standing reach or above what the
approach lets them jump to, and that is priced identically for a first
ball. It was simply never asked on this path.

## `var attack_choice := _choose_attack_target(`

*in `_resolve_home_continuation`*

Where this swing is aimed.

It used to be `Vector2(1.0 - set_target.x, rng.randf_range(0.12, 0.38))`:
straight back over the setter's line, at a uniformly random depth. The
other two swings call `_choose_attack_target`, which reads
`attack_accuracy`, `shot_variety` and `decision_making`, scans the court
for the gap, and errs by an amount the hitter's accuracy decides. On this
path none of those attributes touched the ball and the defenders standing
in the court were invisible to it -- a transition hitter aimed the same
way whether they were the best finisher on the roster or the worst.

The contact passed is `set_target`, the point the ball is actually struck
from after the reachability clamp, rather than the lane table entry the
first ball still hands it. That difference is deliberate and is the first
ball's to fix, not this one's.

## `Dictionary(cont_defense.get("arrival", {})),`

*in `_resolve_home_continuation`*

The arrival, which was `{}` -- so `reach_margin` defaulted to 0.0 and
`stretched` computed a constant 0.294 on every continuation dig,
whatever the defender actually did. `PLATFORM_CONTACT.md` section 4b
traced it and stopped; it is not a design question, because
`cont_defense` carries the arrival and the two lines above already
read it.

Measured over 600 rallies before the repair: 9 resolved continuation
passes, reach margins spanning -0.160 to 1.866, and the stretch they
imply is **0.000 at the median** -- so 8 of the 9 were charged a
stretch penalty for a ball they reached comfortably. A term that
cannot vary is not a weak term; it is an absent one wearing a weight.

## `var assist_reaction := clampf(`

*in `_form_opponent_block`*

The assist cannot have crossed the court before the setter touched it.

Both blockers were handed the same budget, and that budget is mostly
*pre-set*: measured, the window ahead of the set runs 0.78-1.07 s and
barely moves with tempo, while the set's own flight runs 0.20-0.99 s. At
tempo 0 that is 79% of the closing time credited before the ball exists.

For the primary that is fair, and deliberately untouched here. The primary
is by definition the blocker already nearest the attacked lane, so their
pre-set time is spent reading rather than travelling. The assist is the one
who has to cross a slot, and crediting them with having crossed it before
the lane was chosen is what made a first-tempo ball draw a double block
37% of the time.

Anticipation still pays -- `preset_share` is the read, and it stays. What
it now buys is bounded by whether there is time to *finish* the crossing
once the set confirms it. A high ball leaves the whole window usable; a
first-tempo ball leaves almost none, which is the entire reason a quick set
beats a double block, and the reason a zero ball has to be committed to
rather than read.

## `static func _block_intent_margins(intent: String) -> Dictionary:`

*in `_form_opponent_block`*

Settles a formed block against the swing that was actually hit at it. One
copy, both sides of the net, every exchange.
What a block intends, as three shifts to the outcome bands.

The bands must stay ordered -- funnel below touch below stuff -- so an intent
moves all three rather than one, and what it really changes is the *width* of
the band where the block gets a piece of the ball without ending the rally.

Sealing narrows it from both directions: the wall is committed, so it either
beats the swing outright or the swing goes past it. Funnelling widens it: the
block is not trying to end the rally, it is trying to slow the ball down and
put it somewhere the floor is already standing. That is the whole tactical
choice, and it is a real one -- a terminal block wins points a funnel does
not, and a funnel keeps rallies alive that a beaten seal loses.

## `static func _block_contact_point(`

*in `_block_intent_margins`*

Where the ball met the tape, as the realised contact rather than a position
assembled beside it.

`CONTACT_AND_BALL_FLIGHT.md` §5: a realised contact is the single point where
the incoming segment ends and the outgoing one begins, so it has to *be* the
intersection that was proved. `AttackResolutionModel._block_contact` proves
one -- height against reach, lateral against half width, timing folded into
both -- and publishes the crossing it cut on. All three block events placed
the contact at the **hitter's** contact x instead, which is where the wall was
staged and not where the ball went: measured over 300 rallies, mean 0.278 m
apart, worst 0.784 m, and wider than a blocker's own hand on 17.4% of the
contacts that published both. See
`docs/review/block_authority/BEFORE_block_contact_authority.txt`.

`fallback_x` is that hitter contact, and it stays as the fallback for one
reason: with `ENABLE_GEOMETRIC_ATTACK` shut there is no crossing to read, and
the legacy contest stages the wall on the hitter's lane by construction, so
the hitter's x is then the best available statement rather than a wrong one.

## `static func _block_contact_blocker(`

*in `_block_contact_point`*

Whose hands, when the ball met any.

The event named the formation's *primary* blocker -- the one who closed
furthest -- and `_block_contact` picks by centrality, because the ball meets
the surface in its path rather than the tallest or the best-closed one. Its
own note records the cost of getting that wrong: 32% of two-blocker contacts
credited to a less central hand than the ball met, which read as hitters
finding the outside hand and made a second blocker easier to tool.

Falls back to the primary when nothing was touched, because a beaten block is
still an event about the blocker who went up, and there is no contact to take
an actor from.

## `func _attack_coverage_target(`

*in `_resolve_opponent_block`*

Where a ball deflected off the wall comes down on the hitter's own side.

It used to be drawn around the *set* target with a spread widened by a block
quality scalar, which is the pre-geometric block API surviving into a world
that knows where the hands are. The scalar and the coordinates were being
published side by side in the same dictionary -- `_form_opponent_block`
returns `primary_net_x`, `assist_net_x` *and* `quality` -- and this read the
scalar.

A deflection comes off the hands, so it leaves from where the ball met the
tape, not from where the setter put the ball. And how far back it carries is
a question about how solidly it was met: a ball taken well below the top of
the hands is stopped and drops near the net, while one that grazes the top
keeps most of its pace and travels. `block_depth_below_reach_meters` is
exactly that quantity and is already forwarded here.

## `const ATTACK_ERROR_OVERSHOOT_METERS: float = 0.60`

*in `_attack_coverage_target`*

How far past the line a missed attack lands, how far onto the hitter's own
side a netted one drops, and how far below the error threshold a swing has
to be before it goes into the net rather than out.

Stated in metres and converted per axis rather than kept as one normalized
number, because the two axes are not the same scale: the court is 9 m across
and 18 m deep, so a single normalized overshoot puts a wide ball twice as far
out as a long one. The first version of this used a flat 0.045 normalized
units and landed *inside* the painted lines -- 0.09 m in from the sideline,
0.18 m in from the endline -- because the renderer maps normalized 0 and 1
onto the lines themselves. The ball was correctly ruled out and still drawn
in, which is the exact complaint this was meant to fix.

## `func _approach_budget(`

*in `_attack_coverage_target`*

Where a swing that misses actually lands.

The error verdict is read off `attack_quality` *after* the ATTACK event has
been emitted, and used to leave the trajectory pointed at the target the
hitter intended. Playback therefore drew the ball landing cleanly inside the
court and then ended the rally with "the attack misses the court": the ball
appeared to vanish at the end of a legal-looking arc. An error has to move
the ball, not just the scoreline.

The miss is pushed past whichever line the intended target was already
nearest, so a cross-court swing sails wide and a deep swing sails long
rather than every error teleporting to one arbitrary spot. A swing with
almost nothing behind it goes into the net instead, which is what a badly
mistimed attack actually does. Deterministic on purpose -- it reads only the
intended target and the quality that already decided the outcome, so a
replayed seed still draws the identical miss.
What the hitter is given, against what they need -- in **two windows**, because
the approach is paid for out of two different clocks.

The first version of this charged both legs against the set's flight and reported
a deficit on 100% of attacks. That was wrong, and the way it was caught is worth
keeping: the same measurement also said the approach model reached its mark on
100% of attacks, and two measures of one event cannot both be right when they
disagree completely. The approach model was the honest one.

`ApproachMechanicsSystem.prepare_for_attack()` runs the walk to the approach mark
during `set_contact_time - release_time` -- the window between the hitter being
released from their previous duty and the setter touching the ball. That leg is
already over when the set goes up. Only the **run-up** competes with the set's
flight.

So there are two budgets and they must not be added:

- **preparation:** the walk to the mark, against the pre-set window.
- **run-up:** the approach itself, against the set's flight.

Both are reported. Adding them charges the walk twice and inflates the deficit by
roughly a second, which is how a real 0.13 s overrun at third tempo came out as
1.02 s and made the compromise branch look like it would fire on everything.

## `var run_up_window := minf(`

*in `_approach_budget`*

**The run-up's clock is bounded by the run-up, not by the set.**

The same cap `ApproachMechanicsSystem.evaluate_takeoff` applies, on the
path that actually serves the home side -- and the first attempt put it
only on the other one, which is why the displacement gates came back
bit-identical and proved nothing.

A hitter given a 1.5 s high ball does not run for 1.5 s. They take three or
four steps and spend the rest standing at the back of their runway. Handing
the whole hang time to the run-up meant every extra second of set height
bought another second of running, so once sets were timed honestly no
hitter could be made late by anything.

## `func _choose_attack_target(`

*in `_missed_set_drop_trajectory`*

Where this hitter aims, chosen continuously from the actual open floor.

This used to pick from five fixed coordinates, so every attack in the game
landed on one of five spots regardless of where the defence stood. The floor
is now scanned properly: each sample is scored by how far it sits from the
nearest defender, how naturally it fits the shot family being hit, and how
far the hitter has to swing away from their approach line to reach it -- a
sharp cross-court from a tight set is a harder ball than an easy line shot,
and only a hitter with the accuracy and shot variety to attempt it should.

The winning sample is then displaced by an aiming error that shrinks with
`attack_accuracy`, so the resolved target is a continuous point that no
table contains.
Where this swing is aimed, for either side of the net.

Written for the home side only, which made the home attack the one that
searched the floor for a gap while the opponent's picked a depth band at
random. Invisible while kills were 12% of swings; at 54% it decided matches,
and 180 rallies produced 117 home kills against 13 opponent ones.

`defenders` are the positions to hit away from, and `mirrored` flips the
result into the home half for an opponent swing. Everything else -- the swing
range, the read roll, the accuracy-shrinking aiming error -- is the same act
on both sides because it is the same act.

## `func _choose_opponent_defender(`

*in `_choose_attack_target`*

Who on the opponent plays this ball, through the same search the home side
uses.

This was a hand-rolled scan and it lost the rally in three separate ways. It
struck the setter and both middles off the list, so a six-player defence
defended with three. It reported no support count, so the covered-defender
term was permanently zero on one side of the net and averaged 0.30 on the
other. And it made a defender run to the exact landing coordinate, while
`choose_claimant` credits the home defender with a metre and a half of reach
before asking them to move at all -- which is most of why the home defender
arrived with 0.97s to spare and the opponent 0.56s late, and why the home
side dug 42% of balls to the opponent's 23% with identical dig attributes on
both sides by construction.

None of those were decisions. They were the shape of a second implementation
written for the same job, and the fix is not to correct them one by one but
to stop having two.

## `var budget := set_flight_time + OPPONENT_HITTER_LATE_GRACE`

*in `_reachable_attack_contact`*

The whole journey used to be charged against the set's flight alone, which
is the double-charge the home side's `_approach_budget` was built to stop
and which was never taken off this side. A hitter does not stand still
until the ball leaves the setter's hands: they transition out and walk to
their mark while the pass is in the air and the setter is releasing it, and
only the run-up from the mark to the contact is paid out of the set's hang
time.

Measured with the walk double-charged: 541 of 552 opponent swings clamped
short, a 6.12 m run at both p50 and p90 against a 0.55 s set, and contacts
landing a median 5.48 m off the net when the ask was 3.60 m -- an opponent
swinging from their own baseline on nearly every ball. That is also the
whole of the block's placement error, since the crossing displacement is
`tan(bearing) * off_net_metres`.

## `func _reached_point(`

*in `_reachable_attack_contact`*

How far along their run a player actually got, when the ball beat them there.

Playback draws each contact's actor travelling to the contact point over the
previous ball's flight. For a defender who never reached the ball that is a
lie in the player's favour and it reads as a teleport: they were shown
arriving, at whatever speed the geometry demanded, and then failing for
reasons the picture did not show. Emitting the point they actually reached
lets the ball land next to somebody who is visibly short of it, which is what
the simulator already decided happened.

Bisected against `_movement_time` rather than scaled by the time fraction,
because locomotion has an acceleration phase: a player who has used 60% of
the time has covered less than 60% of the ground, and the difference is
exactly the early part of the run where the error would be most visible.

## `func _body_behind_contact(`

*in `_reached_point`*

**Where the body stands, given where the contact is.**

M3's whole content in one place. A passer gets *behind* the ball -- further
along its own line of travel -- and plays it in front of their platform, so
the body sits `contact_offset_meters` beyond the contact point along the
incoming direction. The offset is Pythagoras from the shoulder anchor
`BodyTypeModels.UNIVERSAL_RATIOS` already authors and this voli's own arm, and
it is zero above the shoulder and zero at the floor because the geometry says
so rather than because a band was drawn.

Returns the contact point unchanged when either input is absent, which is what
keeps an un-migrated caller on exactly its old arrival.

## `var improvise_roll := 0.0`

*in `_choose_opponent_attack`*

Drawn ahead of the branch, so the number of draws a rally consumes does not
depend on which way the branch goes, and returned alongside the shot, because
the shot decided here is provisional: it is chosen against a set quality
computed for a *placeholder* target, and the real one is not known until the
contact is final. Re-deciding later with a fresh draw would consume a second
number and re-sequence every seeded outcome after it.

Gated on the flag that needs it, because the original `set_quality < 0.38 or
rng.randf()` short-circuits: hoisting the draw is the correct shape but it is
not free, and taken unconditionally with the flag off it re-sequenced roughly
one rally in three hundred and moved the attack-symmetry ratchet 0.654 to
0.660 while delivering nothing. A flag that is off has to be byte-identical
or the reading it is measured against is not the one it will ship into.

## `func _initial_home_positions(`

*in `_attack_direction`*

`stage_server` is false when the caller wants a *resting* arrangement rather
than the opening snapshot. The serve-origin placement below is correct for the
first frame of a rally and wrong for anywhere else -- a base posture that puts
somebody behind the baseline would have them walk back off the court every
time the ball crossed the net.
**Where a side stands when the whistle goes.**

FD-001 / FD-004. A receiving side used to be placed on the rotation grid --
or on the plan's serve-receive zone where one existed -- while
`_receive_formation_map` separately published, onto the reception event, the
shape the six *actually take up* to receive: passers on their seams, front row
off the passing lanes, setter at the release. Two answers to one physical
question, and gameplay believed neither of the drawn one: the reception claim
builds `reception_origins` out of `live_positions`, so a receiver read the
serve from the rotation grid while a viewer watched them stand in formation.

The formation is the answer. A receiving side is in its receive shape *before*
the ball is struck -- that is what serve receive is -- so the shape belongs in
the state the whistle starts from rather than in a map drawn afterwards. Now
the same call seeds `live_positions`, `result.initial_home_positions` (which
is what the 3D court spawns actors at) and the origin of every later traversal.

`players` is needed only to pick the passers. Empty keeps the old rotation-grid
behaviour, and `home_base_positions` deliberately passes nothing: a *defending*
base is not a receive shape and asking for one there would have been the third
representation rather than the removal of the second.

## `var zone: Resource = defensive_plan.zone_for(`

*in `_initial_home_positions`*

**`enabled` is checked here now, and was not.**

`_initial_opponent_positions` below has always required a zone to
be enabled before it moves anybody; this side took any zone that
existed. So a serve-receive zone the manager had switched off
still relocated a home receiver and never an opponent one --
the same shape of home/opponent drift the block's stale swing
turned out to be, found while tracing this one.

An enabled zone still wins over the formation, and should: the
formation is the structural default and the zone is the manager
saying otherwise. That is one resolution, not two geometries.

## `"transition_speed_mps": LocomotionModel.maximum_speed(`

*in `_physical_playback_profile`*

How fast this body can actually be moved across the floor.

Playback had no notion of a speed limit: it lerped every planned leg
across whatever window the ball happened to be in the air for. Measured
over 600 rallies that printed a p99 of 13.4 m/s and a worst case of
57.1 m/s -- a 4.49 m transition drawn inside a 0.079 s attack-to-block
window. Bolt runs at 12.

The same `LocomotionModel.maximum_speed` the engine times traversals
with, so the drawn pace and the simulated one come from one model rather
than from a constant invented in the view. `TRANSITION` because that is
the mode a player crossing the court between phases is in; fatigue is
already inside `cadence_hz`, so a tired voli is drawn tired.

## `func _establish_shape(`

*in `_home_floor_phase_positions`*

Where a defending six stands while the ball is being attacked at them.

This used to exist for the home side only, and that single fact was most of
the engine's home advantage. The home six were walked to their floor-defence
shape during the attack's flight, so they met the ball having already
arrived; the opponent six were left wherever the previous phase had put them
-- at the block wall, at a hitter's contact point -- and had to cover that
ground inside the attack. Measured over 407 digs the home defender arrived
with 0.97s to spare and the opponent 0.56s late, a gap of a second and a half
in a model whose timing term saturates at 1.2s. Home dug 42% of balls and the
opponent 23%, with identical dig attributes on both sides by construction.

Nothing about standing in your defensive shape is home-specific, so the side
is now a parameter rather than a copy: the y axis mirrors, the depth and
posture adjustments flip with it, and both sixes get the same preparation.
Walk a side **into** a defensive shape instead of teleporting them into it.

`_floor_phase_positions` below computes the shape the plan asks for -- zones,
depth, seam, the wall's two shoulders -- and every one of its three callers
then wrote that shape straight into the live position map. So the defence
*arrived* in the diagram the instant the attacker swung, from wherever the
previous phase had left them, across any distance, for free.

The C0 action-window census counted the consequence exactly: of 1,350 volis
placed on an `ATTACK` event, **none** had spent any time getting there. Every
other journey in this file goes through `_reached_point`; the defensive base
was the one that did not, which is why it was also the only one that always
succeeded.

This is gameplay and not drawing. The shape is handed to
`CoverageModel.choose_claimant` as the defenders' real positions for the dig
reach check, so a defender who had no time to get to their zone was still
reaching from inside it.

C5 states the rule in one sentence -- "the attack launch may change who
ultimately owns the ball, but it does not create the defender's entire
pre-swing position from scratch" -- and adds a second: partial establishment
stays partial. `_reached_point` already does that. A defender who cannot cover
the distance in the set's flight stops where the time ran out.

**Nothing new is authored here.** The traversal authority, the cost per metre
and the lateral mode are the ones every other off-ball leg already uses; the
window is the set flight the defence genuinely has. What changes is that the
journey is now taken rather than assumed, and defensive establishment is
billed the exertion it always cost in the sport and never cost here.

## `var wall := wall_positions.duplicate(true) \`

*in `_floor_phase_positions`*

The wall, at its two shoulders. Both blockers used to be handed the *same*
point -- `Vector2(attack_x, wall_y)` -- so in 3D playback their bodies were
stacked by construction rather than merely close: one actor standing inside
another. The 2D court never showed it because it draws its squares from
`_block_wall_positions()`, which has always separated them; the 3D view takes
its placement from this function, and nothing reconciled the two.

Same source now. A wall is two players side by side and that is a fact about
where they stand, not a detail of how one view draws them.
Staged on the crossing the blocking side read, when one was supplied. The
floor behind them still shades on the attack lane: where the hitter is and
where the ball goes through the tape are different facts, and only the wall
stands on the second one.

## `func _tempo_call(`

*in `_floor_phase_positions`*

What tempo the opponent calls on this ball.

It was `tendencies.get("tempo", 2)` -- the same number on every ball of every
rally of every match. Structurally that already mirrored the home side, which
also calls before the pass and lets `SetterCapabilityModel` resolve down; what
it did not mirror is that the home call comes from a playbook and ranges 0 to
3 while this one never varied. A side that always runs the same play cannot be
caught running the wrong one, which is why the capability model's downgrade
branch never once fired here.

The thresholds below are asserted, not derived. There is no home-side
equivalent to mirror, because the home tempo comes from a playbook the
opponent does not have, so this is calibration by assertion until the roster
influence sweep prices it properly. It was measured before being kept: the
promoted symmetry estimator moves from 0.617 to 0.594 -- from three
thousandths inside the bound to twenty-six -- against 0.007 of opponent set
quality. The likely mechanism is that a varying tempo sometimes catches the
home block closing for the wrong ball, since set flight time is what
`_contest_block` gets its close window from; that is plausible and unverified,
and worth confirming before these numbers are trusted further.
What tempo this setter calls off this ball. One function, both sides.

It was `_opponent_tempo_call` and only the opponent used it; the home side
took `assignment.tempo` from the called play on a first ball and a hardcoded
3 out of `_fallback_assignment` on every transition. That is two constants
rather than one decision, and `_set_launch_angle_degrees` makes the
difference enormous: tempo 3 leaves at 45-55 degrees, tempo 2 at 25-35.

Measured, identical rosters, the set flight the hitter gets to run under:

home_first_ball        0.902s      opponent_first_ball    0.488s
home_transition        1.063s      opponent_transition    0.489s

Half the airtime is half the approach, which is why the opponent hitter
arrived 0.33s late against the home side's 0.06s, ran up 36% slower, jumped
lower and erred at twice the rate on every out-channel at once.

## `for zone_type in [`

*in `_opponent_defensive_plan`*

Deliberately no floor preset on top.

`ensure_defaults` seeds `defender_positions` from
`CourtConstants.ROTATION_SLOT_POSITIONS`, whose own comment says it "is
NOT a tactical formation and must not be used to position players during
live play" -- it exists to check overlap legality at the moment of serve.
That is a real defect, and it is the *home* side's defect too:
`apply_floor_preset` is only ever called from the tactics screen, so a
default career plan defends from the rotation grid exactly like this one
does. Applying Perimeter here alone would hand the opponent a floor
system the player has to go and choose, which is the same asymmetry as
the one this gate exists to remove, pointed the other way. Both sides
move together or neither does.
Mirrored at the source, not at every reader. `ensure_defaults` lays the
plan out in home coordinates because that is the only court it has ever
described, and a zone centred on the home back row is not a place an
opponent defender can stand. Flipping it once here means any reader that
does not have a staged position for somebody still gets a centre on the
right half of the net, instead of a defender who appears to be defending
from inside the other team.

## `actor.facing = entry_facing`

*in `_travel`*

**The route no longer chooses the orientation.**

This used to read `actor.facing = opening.normalized()` -- face the way you
are going -- which made every movement in the engine perfectly prepared by
construction. `facing_fit` was 1.0 for every voli on every leg, so the turn
cost the locomotion model computes could never fire, and a defender caught
flat-footed with the ball behind them was timed as though they were already
squared to it.

Zero means **unknown**, and `_movement_profile` leaves `facing_fit` at 1.0
for an unreadable facing -- so a caller that has nothing to say keeps
exactly the behaviour it had, and only a caller that actually knows the
body's orientation pays for it. That is what makes this safe to land before
every caller has been migrated.

## `func _pre_release_home_block_stage(`

*in `_wall_stage_x`*

What the home wall is allowed to know before the opposing setter releases.

Playback plans an interval from the metadata on the *next* contact. That
means `home_phase_targets` attached to an opponent SET are consumed while
the pass is still travelling to the setter. Publishing the resolved hitter
lane there lets the wall move to an answer the rally has not shown yet.

A called commit is different: it is a prediction made from the rotation and
the instruction. Commit Middle names its lane outright. Commit Pin chooses
the strongest front-row pin in the visible opponent rotation. A read block
simply establishes each blocker's own net base. None of these branches is
handed the selected hitter, delivered set target, or eventual attack lane.

## `static func _block_wall_positions_preserving_order(`

*in `_block_wall_positions`*

Keep the named primary on the read crossing while choosing the assistant's
shoulder from the side that player is actually closing from. The basic wall
helper quite reasonably prefers the court's inward side, but on a middle
attack either side is inward. If the resolved assistant came from the other
half, blindly using that default inverted the pair's left/right order: two
independent straight-line journeys crossed during the jump, merged, and
emerged in the opposite slots.

This is still the same two-slot wall and the same shoulder offset. It only
mirrors the assistant slot when the default would force the two identified
bodies to exchange sides. The pair is shifted together at a clamp boundary
so the full shoulder spacing survives deterministically.

## `func _block_deflection_trajectory(`

*in `_block_deflection_lands_on_blocking_side`*

A ball coming off the block, timed by geometry rather than a constant.

The three deflection segments each carried a hardcoded 0.18-0.30 s. A stuff
driven straight down is that fast. A ball squirting up off the hands and
travelling four metres is not -- and the defender chasing it was drawn
covering that ground in a quarter of a second, about sixteen metres a
second. A stuff keeps its constant, because the rally ends on it and nobody
chases; every other deflection now solves the same arc every other flight in
this file solves.
**A ball comes off the hands at the pace it arrived, less what the hands took
out of it.**

The deflection used to derive its own speed from the distance to wherever the
ball was going to land -- `solve_struck_arc` answers "how hard must this be hit
to get there" -- so a 25 m/s spike and a 12 m/s roll came off the block at the
same pace, and the blocker had nothing to do with it. Pace is the one thing a
deflection is *made of*: it is not a shot anybody chose, it is a collision.

So the speed is the incoming swing's, scaled by how much of it the blocker
absorbs, and the flight time is then distance over that speed like every other
struck ball in this file. Two consequences fall out without being written:
a hard-driven ball reaches the defender sooner, and `_incoming_ball_force`
reads the faster arc, which is what `CoverageModel.reception_body_penalty`
spends `reception_stability` against. The pace-resistance half of this was
already built and had nothing real to resist.

**`block_timing` is a stand-in and should be replaced.** What belongs here is
how well a blocker's hands absorb a ball, and no such attribute exists --
`ball_control` is displayed as "Touch Control" but is the *receiver's* hands
and is read by reception quality. `block_timing` is the nearest true thing: a
blocker who meets the ball at full extension presents a firm angled surface and
one who is already falling gives with it. That is a real part of the effect and
not the whole of it.

## `deflection_landing: Variant = null,`

*in `_block_deflection_trajectory`*

**What `BlockDeflectionModel` said this ball did.**

The soft branch below has always solved its own flight properly -- pace
absorbed against block timing and the hands' intent, then
`struck_arc_from_speed`. The *stuff* branch did neither. It flew to
`post_block_target`, which is the attack's own target rather than
anywhere the ball was deflected to, and it took
`BLOCK_STUFF_FLIGHT_SECONDS` to get there -- a constant. That is the
reported suspicion in as many words: a preset amount of time for a block
touch rather than a time that falls out of the trajectory.

Optional, so a caller with no deflection in hand keeps the flight it
always had rather than being handed a zero.

## `var contact_height := ball_contact_height_meters \`

*in `_block_deflection_trajectory`*

**Where the ball actually met the hands, when the resolver proved it.**

This was `max(apex_hint, the tape)` -- a floor under a hint, which is a
guess with a sensible shape rather than a measurement. The intersection
test has known the real height since BLOCK_REALISED_CONTACT and publishes
it on the event; the leg out of the contact was still launching from the
guess, and the leg in was ending at the 1.0 m default, so the two happened
to agree at nothing and the census scored a clean zero. Now that the swing
states where the wall met it, this has to state the same number or the
seam is real -- and it was, 0.343 m of it.

The old expression stays as the fallback for a caller with no proved
contact, which is a beaten block: there is no hand for this to be the
height of.

## `static func _reachable_contact(`

*in `_stamp_launch_contact_height`*

The ball is contacted where the hitter can be, not where the set wanted them.

`evaluate_takeoff` already knows this: on seed 6144 it reports a hitter
covering 0.19 m of a 2.07 m runway inside a 0.228 s set flight -- 4.5% -- and
the rally emitted the ATTACK event at the far end of that runway anyway.
Nothing was wrong with the movement model; the resolver asked it a question,
was told the hitter could not get there, and placed the contact there
regardless. Playback then had to cover two metres in a quarter second, which
is the 9.1 m/s teleport, and capping the animation would only have left the
hitter short while the ball met empty air.

So the contact slides back down the hitter's own path to the point they
actually reach. A ball met at the wrong point is a worse ball -- already
priced, through the negative arrival margin this same shortfall produces --
and the swing still happens, from where the swing really is.

All three attack paths call this, deliberately. It was first added to the
home continuation alone, which left the opponent swinging at contacts it
never reached: the same one-side-modelled-fully defect this engine has now
produced ten times, and the tenth was introduced by the fix for the ninth.

## `static func _hitter_preset_credit(preparation: Dictionary) -> float:`

*in `_reachable_contact`*

The lateness that survives the clamp above.

`_reachable_contact` exists precisely so a hitter who cannot get to the ideal
contact strikes the ball short of it instead of missing -- it pulls the
contact back to the point they reach as the ball arrives. So once it binds,
the hitter is on time *by construction*, and the margin is zero.

Both swings kept billing the pre-clamp figure. The opponent's hitter was
therefore charged a mean 0.461 s of lateness against a contact they no longer
took: the ball was moved to them and they were penalised for not reaching
where it used to be. That single stale number was 0.662 of their 0.958 mean
approach deficit, and it is why they backed off 71% of their swings against
the home side's 2% -- the two sides run identical code and only this term
binds on one of them.

Returned from beside the clamp rather than recomputed at each call site, so
the rule about when lateness survives lives in one place.
How far the reachability clamp had to drag the contact, in metres.

The other half of `_clamped_arrival_margin`, and it was missing. Sparing a
hitter the lateness is correct -- they are not late to a contact that was
moved to them -- but hitting from further off the net is *worse*, and nothing
charged them for it. Measured on the displacement fixture: a hitter dragged
0.74 m back off the tape came out with attack quality 0.247 -> 0.252, very
slightly *better* for having been displaced across the court.

So the clamp had removed a consequence rather than relocating it. This is the
consequence, in the channel it actually belongs to.
The part of the pre-set window the hitter gets to run in.

Reads `preparation_time_seconds`, which the approach model already computes
and already publishes -- it was simply never spent by anything. A value that
exists, is correct, and reaches no consumer is the commonest defect in this
engine and this is one more instance of it.

## `func _swing_reaches_net(trajectory: Dictionary, fallback: float) -> float:`

*in `_contact_time`*

When the swing reached the tape, or `fallback` if this arc cannot say.

A block is not timed like the contacts either side of it. Reception, set and dig
all happen when the ball *finishes* its flight, so `_contact_time` is right for
them; a block happens partway through one. `_net_crossing_time` below has always
known how to find that instant and only the timeline finaliser was asking it --
and only for blocks that never touched the ball. A block that *did* touch it took
its moment from the deflection arc's own start timestamp, which was whatever the
call site passed, so the hands moved on a clock nobody had derived.

An on-time block and an on-time swing are the same moment in the sport, give or
take the fraction of a second the ball takes to cross: on a normal cross-court
swing from y 0.55 to 0.15 the tape sits an eighth of the way along.

## `func _trace_summary() -> Dictionary:`

*in `_swing_reaches_net`*

The flight a swing actually produced.

`_geometric_swing` resolves every attack in the game -- it picks a course,
chooses a power from `AttackPowerModel`, solves the driven root off the
hitter's real contact height and checks the ball clears the tape -- and then
hands back `speed_mps`, `vertical_angle_degrees` and `contact_height_meters`.
Every one of those three was dropped on the floor, and the drawn attack was
rebuilt from `solve_launch_arc`: a ball lobbed *upward* at eight to twelve
degrees from ground level to ground level.

The consequence was not subtle once it was measured. A spike is struck
downward -- `DRIVEN_REFERENCE_ANGLE_DEGREES` is minus fifteen and always has
been -- so re-deriving it as an upward lob forced the solver to pick a speed
slow enough that the lob would still land in the court, around 6.6 m/s against
the 16-30 m/s the power model works in. This is the first failure mode in
`docs/BACKLOG.md`, exactly: a value computed correctly, dropped before
anything could use it, and re-derived worse downstream.

The fallback is not the old lob. A swing with no geometric record still gets
the driven reference angle and the speed that shape needs, because a spike
drawn as a lob is wrong whether or not the resolver had an opinion about it.
The shadow trace's summary, or an empty one.

`shadow_reception_trace` is null on the paths that never built a trace -- an
opponent transition inside a home serve is one -- and reading `.summary` off
it was a crash the moment anything outside the reception pipeline wanted a
geometric record. Which is now every attack.

## `var gravity := BallSpin.gravity_for(spin_state)`

*in `_swing_arc`*

**The resolver's own angle, when the ball is going where the resolver sent
it.**

`GeometricAttackResolver` does not pick the driven root and stop. It
searches for an angle that *clears the tape* -- `_height_at_net` and
`NET_SPEED_RELIEF_STEPS` exist for nothing else -- and re-solving here threw
that constraint away, so a back-row swing came out at an angle that
physically cannot get over the net from four metres back. Measured, 50 of
181 attack-to-block flights crossed below net height.

Carrying it is only sound because the two targets turn out to already be
one: every attack site assigns `attack_target = geometric.target` *before*
solving this arc, so the distance below and the angle in the record describe
the same shot. The earlier attempt that drew two-second flights nine metres
up carried the angle onto the *to-block leg*, whose distance is the short
hop to the net rather than the shot's own range -- a different defect with
the same symptom, and the reason this takes a flag rather than always
trusting the record.
**And upward-struck balls too.** This condition used to read
`vertical_angle_degrees <= 0.0`, on the grounds that carrying the angle
unconditionally moved the mean height of an untouched attack at the tape
from 2.69 m to 5.19 m -- a lofted angle gets over the tape by going a long
way up, and the flat-spike report this thread came from was never about
roll shots.

That is §0 twice over. A bound was placed on the drawing to hold down a
number the *resolver* had chosen, and it was placed exactly across the
branch it was needed for. `_feasible_launch` reaches for a lofted root only
when no driven one clears -- lofting *is* the clearance -- so excluding
lofted deliveries threw the angle away on precisely the swings that had no
other way over. Measured on 205 attacks met by a block: all 26 lofted
swings were certified over the tape by the resolver, all 26 were drawn at
a mean of -18.4 degrees, and 23 of the 26 were drawn *through the net*.
Against 16 of 171 on the driven branch, which is a different defect.

The 5.19 m is not evidence against carrying it. It is the resolver saying
these hitters are rolling the ball over a formed block from the back row,
which is a claim about the swing that the drawing does not get a vote on.
If that number is wrong the fix belongs in the clearance search, where the
shot is chosen; drawing a flat spike on top of a lofted solve does not make
the swing flatter, it makes the picture disagree with the rally.

## `func _truncated_arc(`

*in `_swing_arc`*

The same swing, drawn only as far as the block.

Not a new solve. Re-solving against the *distance to the net* asks "what shot
lands at the tape", so the re-sliced leg was aimed at the block rather than
through it. Truncating a flight must not change its shape, only where it
stops, so the leg keeps the parent swing's launch and takes the share of its
duration the shorter distance is worth.

`swing_duration_seconds` is the parent's own flight time, carried so a reader
can still ask how far through the *swing* something happened. The block's
timing gate needs exactly that: it measures when the hands met the ball
against the flight they contested, and once this leg ends at the tape by
construction, measuring against the leg answers 1.0 every time.

## `start_height: float = NAN,`

*in `_ball_trajectory`*

**Where the ball actually was, vertically, at each end of this flight.**

`BallTrajectory.create` has taken these since it was written and no caller
ever passed them, so every published trajectory in the game carried the
1.0 m defaults. That was invisible because `apex_height_meters` is a
*relative rise* -- a documented contract with its own gate -- and because
presentation rebuilds the real heights from body profiles before drawing.

It stopped being invisible the moment anything asked the trajectory itself:
`height_at_progress`, `height_at_time` and `earliest_contact_time` all
derive from these two fields, so on seed 20010's dig the record answered
1.000 m at the far end where the ball really arrives at 2.190 -- a metre
and a fifth of fiction, in the exact methods a future interception resolver
has to trust.

NAN means "this writer does not know", which is honest and keeps the old
default. `height_source` records which it was so the gap stays countable.

## `flight_id: String = "",`

*in `_ball_trajectory`*

**Which launch this flight belongs to.**

The B0 census found four families -- serve, set, attack and block --
publishing balls with no identity on them at all. Every edge between them
still handed over the right ball, but the strongest thing a certification
could say was "the same *shape* arrived", and P3's matrix asks each edge
for "same launch lineage". Two geometrically identical records are
indistinguishable from one record passed along, which is precisely the
substitution a one-ball chain exists to rule out.

Empty mints a new identity: this contact is a new launch. A **re-slice of
an existing launch** -- the swing truncated to the tape when a block
touches it -- passes the source's id instead, because it is a prefix of
that launch and not a second one. That is the whole distinction, and it is
stated by the caller rather than inferred from coincident floats.

## `func _stamp_launch_state(trajectory: Dictionary, resolved: Dictionary) -> void:`

*in `_ball_trajectory`*

Put the launch state on the published flight, so nothing has to rebuild it.

**`BallPresentation.launch_speed_mps` reconstructs launch speed from the two
endpoint heights and the duration**, which makes it a property of wherever the
flight was cut rather than of the contact that made it -- the §3 violation the
spec names, and it is read by `_read_error_meters`, which is gameplay. A ball
dug at six metres left the hand at the same speed as one that reached the
floor, and a record that cannot say so will keep being asked to guess.

Only the serve carries this today. Every other family still reconstructs, and
`_read_error_meters` still falls back to the reconstruction for them, so the
marker is also the migration's own to-do list.

## `func _platform_intent(`

*in `_stamp_launch_state`*

What a platform contact was *for*, published beside what it did.

`PLATFORM_CONTACT.md` section 11, slice 1, plus the two source markers section
13.10 asks for. **Nothing reads any of it.** The slice's own acceptance
criterion is that rallies come back byte-identical, and publishing it inert is
the point: it makes countable, for the first time, how many platform contacts
in this engine have any stated intent at all.

The three shapes are not a stylistic choice and section 3a is the reasoning.
The target and the height have derived *anchors* and no derived widths; the
arrival has a derived *floor* and no derived ceiling. A uniform representation
would have had to invent whatever the uniformity demanded and the data does not
supply -- four of five bounds, by section 3a's own count.

`anchor_source` separates a manager-set release seat, which is steerable, from
a fixed contact offset. Receptions and controlled digs state the former;
coverage still has only the latter because it has no recipient or pass intent.

## `const PASS_APEX_RISE_MIN_METERS: float = 1.45`

*in `_set_geometry`*

How high a pass goes above the platform that played it, from a shank to a
perfect one.

The floor is a ball that barely clears the passer -- it still reaches a
setter's hands on nobody, which is exactly the point: a low rise off a 0.9 m
platform apexes under every setter's standing reach in the game, and the
second contact has to be taken underhand. The ceiling is the textbook high
pass that hangs above the setter and lets the whole offence organise
underneath it.

**Raised, because the ceiling was under the setter's own jump.** The band was
1.05-2.90 m and measured over 1,052 passes it produced apexes of 2.42-3.31 m
about a 2.89 m median. A setter's jump-set contact is
`lerp(standing_reach, jumping_reach, 0.58)`, which is about 2.83 m for a
1.90 m body -- so the *median* pass peaked six centimetres above the point a
setter would meet it in the air, and the bottom of the band peaked below it.
There was no ball in the game high enough to be worth leaving the floor for,
which is both why the jump set could never be the standard and why the pass
read as too low to jump to.

The new band apexes roughly 2.35-4.70 m about a 3.4 m median, which puts the
ordinary pass comfortably above a jump-set contact and the good one well
above it. The floor deliberately stays under the standing release: a bad pass
must still be a bad pass.

## `func _dig_pass_result(`

*in `_set_geometry`*

The ball that physically leaves a successful floor dig.

**Before this, a dug ball had no flight.** The dig event carried a destination
and nothing else -- no apex, no duration, no contact height -- and the two
transition resolvers filled the hole with constants: a 0.68 s second-contact
window for setter reachability, and a table-drawn contact height. Both were
labelled as gaps in place; `_resolve_opponent_transition` still says
"NAN when the feeding contact has no height model, which today is every dug
ball on either side". This is that model. The display trajectory that
`_ensure_event_trajectories` used to invent afterwards was never the ball the
setter had been resolved against, so the drawn flight and the simulated one
were two different balls that happened to share an endpoint.

**Reuses the reception primitives, not the reception helper.**
`_reception_pass_result` computes exactly this physics -- contact height,
apex, set-contact height, `BallFlightModel.duration_for_apex` -- but takes a
serve origin and a serve force and is calibrated against reception platform
feasibility. A dig is not a reception: it is played off a swing, from a
posture, at a reach margin, and often while falling. So the primitives are
shared and the geometry is its own.

**No new random draw.** Everything below is derived from what the dig already
resolved: its control, its posture, its reach margin, how far the defender
travelled and how fast the ball was coming. The dig contest has already
consumed its randomness; a second roll here would make the same dig produce
two different balls.

## `var contact_height := GeometricAttackPromotionModel \`

*in `_physical_platform_dig_result`*

**The ball's height, where the incoming flight can state it.**

This was the passer's own platform height for every platform family, and
the reception's site says why in its own words: the trajectory's endpoint
height was "ambiguous", so the body's number was used rather than make
either meaning of `end_height_meters` authoritative by accident. That
ambiguity is resolved -- the serve's published flight terminates at the
pass, and a flight that resolves its start and publishes its launch states
its far end -- so the deferral has expired and the ball can be read
directly.

The body stays as the fallback for a flight that resolves neither end, and
for the degenerate case where the derivation lands at or below the floor:
`PlatformContactModel` refuses a contact at zero height, and a ball that
reached the floor is a ball nobody passed.

## `func _coverage_keep_alive_flight(`

*in `_physical_platform_reception_enabled`*

The keep-alive ball a successful attack-coverage contact launches.

**Coverage owns no recipient policy of its own.** The intended target is
exactly the actor the existing second-contact policy names --
`_second_contact_setter`, the one selector every dig and transition already
goes through -- with the coverer excluded as its `first_contact_player_id`, so
a coverer is never named their own recipient and an unavailable designated
setter falls to that selector's existing emergency-setter branch. Coverage
adds no ranking, no weight and no coefficient here; it reuses the policy whole.

From that intent this is the shared physical platform contact and nothing
bespoke: the authoritative incoming ball, the coverer's own body/contact
state, and the T1--T3 model produce one authoritative free flight. The launch
selects nothing about who touches the ball next -- M5 interception decides that
against the flight, so the intended actor may miss, a teammate may intercept,
or the ball may floor, sail or cross the net untouched.

Returns `{}` when the physical platform path is closed (the same flag and
development override `_dig_pass_result` gates on), when the policy can name no
available second-contact actor besides the coverer, or when the model declines
the contact. The caller then keeps its legacy fabricated trajectory, so
production is byte-unchanged until the flag opens.

## `var pass_contact_height := GeometricAttackPromotionModel \`

*in `_reception_pass_result`*

**How high the ball was put up, and therefore how long the setter has.**

The flight time was `0.38 + distance / lerp(5.2, 8.4, execution)` clamped
into 0.42..1.25 -- a horizontal speed dressed as a duration, in which a good
pass got to the setter *faster* than a bad one. That is backwards. A good
pass is a high one; height is the entire currency of a second contact,
because it is the only thing that buys the setter time to arrive, square up
and choose, and buys the hitters time to find their run-ups behind it.

So the pass is now described the way a coach describes it -- how high it
went -- and the hang time falls out of gravity. The apex band is the one
that was already here as `lerpf(1.1, 2.8, execution)`, which was passed to
the trajectory as an apex, thrown away by the drawing, and read by nothing:
a value computed correctly and dropped, which is this engine's commonest
defect and was hiding the fix to this one.

## `const POSTURE_EXPECTED_CONTROL := {`

*in `_reception_pass_result`*

Whether a defender stayed on their feet, and what happened to them if not.

`contact_posture` says how *strained* the contact was; this says what the
strain did to the player. They are separate axes on purpose: a reaching
contact taken well leaves a defender standing, and a planted contact taken
into a ball travelling far too fast does not.

Four states, in ascending cost, and every one of them is legible from the
stands without a caption:

- **platform** -- stayed up, played it off the forearms.
- **knee** -- went down on one knee to finish the play. Follows a *reaching*
or *moving* contact taken poorly, or comes from a defender whose reception
stability is low enough that they go down on ordinary balls too.
- **fall** -- went to the floor. Follows an *off-axis* contact taken poorly,
or a defender with low reception balance -- being unable to square up and
being unable to stay up are the same failing seen twice.
- **blown_away** -- did not play it so much as get hit by it. Requires *both*
a badly taken contact **and** a ball arriving hard, which is why it cannot
come from a reaching contact: a defender already stretched for a ball is
not standing in front of it.

The costs are what make this more than a pose. A knee or a fall takes the
defender out of the next contact; being blown away takes them out of the
rally. That is the first time a defensive *success* has a price, which is the
whole reason the knee was worth modelling -- see `docs/design/CLUB_LIFE.md` on
failure being legible and gentle.

Thresholds are named rather than inline so the four bands can be retuned as a
set. A recovery state that fires on a third of contacts is wallpaper; one that
fires on none is a pose nobody sees.
How badly a contact has to go, per contact type.

**Two thresholds per type, not one shared pair**, and that is a measurement
rather than a preference. `contact_control` puts both contacts on the same
*axis*, but not in the same *place* on it: measured over 720 rallies, a
reception's control sits at a median of 0.81 while a dig's sits at 0.37,
because receiving a serve in this engine is genuinely much easier than digging
a swing. One shared threshold cannot describe both -- the pair that gave digs a
sane 18% knee rate made receptions literally unreachable at 100% platform, and
the pair that reached receptions put a third of all digs on the floor.

What a contact of each posture normally produces, measured over 1,078 of them.

**`poor` is relative to the posture, not to the contact type.** That is the
finding this table exists to record. A flat threshold made the two conditions
the bands ask for -- a poor contact *and* a difficult posture -- into the same
condition: cross-tabulated, 138 of 155 reaching contacts were poor and 0 of 431
off-axis ones were, because a reaching contact scores badly *by definition* and
an off-axis one does not. So "reaching and poor" meant reaching, "off-axis and
poor" meant never, and two of the four bands were unreachable while a third was
wallpaper.

Posture also explains most of what looked like a contact-type difference: a
dig's control sits far below a reception's mainly because a third of digs are
reaching and almost no receptions are. One table replaces two.

## `const RECOVERY_KNEE_SHORTFALL: float = 0.207`

*in `_reception_pass_result`*

Where each pose begins, as a *shortfall* against the posture's own norm.

`shortfall = 1 - control / expected`, so zero is a contact that scored exactly
what its posture usually does and positive numbers are how far short it fell.
Normalising by posture first is what makes one scale work across a table that
spans an order of magnitude -- a reaching contact scoring 0.105 against a norm
of 0.08 is a *good* contact and lands at -0.31, which is where it belongs.

Measured over 252 contacts, the shortfall distribution runs:

p50 0.087   p75 0.187   p80 0.207   p85 0.236
p90 0.260   p95 0.342   p97 0.363   p99 0.461

The bands below are read off that. They replace a single `poor` flag set at
`RECOVERY_POOR_SHARE`, which sat at **p75** -- so the worst quarter of every
contact qualified for a severe pose, and three of them were drawn from that
quarter. Twenty-two per cent of all contacts ended up on the floor, and
`blown_away` was landing on contacts whose control was 0.444 against an
average of 0.475. The pose said catastrophe and the contact was ordinary.

Ordered thresholds on one scale also make severity monotone by construction.
The old branches could not be: `knee` was gated on posture and `blown_away` on
force, so they selected different populations and `blown_away` ended up
producing *better* passes (mean 0.301) than `knee` (0.208) -- the worst thing
that can happen to a defender being, on average, better than the second worst.

## `const RECOVERY_HEAVY_FORCE: float = 0.86`

*in `_reception_pass_result`*

How hard the ball has to arrive to drive an average voli off it.

Re-measured and moved. This was 0.78, described as "the top tenth of arcs" --
and against the contacts that actually reach a defender it is **p68**, so a
third of every ball arriving qualified as heavy. Combined with a `poor` gate
that was also loose, seven per cent of all contacts were being drawn as
blown away. 0.894 is p75 of the same distribution, which with the shortfall
bands narrowed leaves this band genuinely rare rather than merely uncommon.

**One gate, not two.** The band originally asked for a *dire* contact as well
as a heavy ball, and measured that turned out to be self-defeating: the
contacts with the worst control are the ones the defender had to stretch for,
and a defender stretching is explicitly not being blown away. Requiring both
made the band structurally empty -- 0 of 1,078 contacts. What actually happens
is a defender standing in the right place taking something too fast for them,
so the force does the work and a poor contact is the qualifier.

## `const POSTURE_OFF_AXIS_ALIGNMENT: float = 0.10`

*in `_reception_pass_result`*

Where a contact stops being planted, per branch.

All three were inline numbers, and two of them sat outside the distribution
they were testing. Measured over 1,078 contacts: `body_alignment` runs from a
5th percentile of 0.442 upward, so an off-axis bound of 0.42 could never fire,
and `edge_ratio` reaches 0.82 in only the top tenth. The consequence was not
subtle -- **the off-axis and moving dig postures were never drawn in a live
match at all**, and two of the four bodies built for playback existed only in
the portfolio.

Re-centred so each branch owns a real share: off-axis about a seventh of
contacts, moving about a fifth. The ordering is unchanged -- a defender who
could not reach it is described as reaching first, whatever else was also true.
Off-axis is tested *before* moving, and that ordering is load-bearing. Low
alignment and a high edge ratio are strongly correlated -- alignment is partly
built from the edge ratio -- so with moving first, every off-axis contact was
classified as moving instead and the branch stayed dead even after its bound
was corrected. "Could not square up" is the more specific claim of the two.
Both from the measured distribution of the term each one tests:
`movement_alignment` has a median of 0.254 -- a receiver ordinarily moves toward
the ball rather than toward the setter -- and `edge_ratio` a median of 0.239.

## `const JUMP_EFFORT_COST: float = 0.0048`

*in `_reception_pass_result`*

What a jump costs in condition, and what a metre of court costs.

**Jumping is the expensive thing a volleyball player does**, and by some
distance: it is a maximal effort of the whole leg, repeated, and it is what
empties a middle blocker across five sets while a libero who covers more
ground is still fresh. So a jump is worth roughly forty metres of walking, and
the two are separated rather than blended into one per-rally figure.

The pair is anchored on the match rather than picked: a starter plays on the
order of two hundred rallies in a five-setter, jumps on perhaps half of the
ones they are involved in, and covers a few metres on most. `RECOVERY_FATIGUE_COST`
below is the third channel and was already priced this way -- a trip to the
floor is more than a jump, because getting up is work the jump does not have.

`JUMP_EFFORT_COST` is the full-effort figure. A jump set or a soft block reads
as a fraction of it via the effort each contact actually used, so a side that
runs everything at full stretch pays for that and a side that plays within
itself does not.
Both anchored on the measured match rather than guessed. At the first values
tried (0.0022 and 0.00005) a five-set match left the most-worked starter at
0.531 -- inside `laboured` and short of `spent`, so the error channel the
design exists to deliver could never fire. Scaled by the ratio that measurement
demanded, which puts a worked starter into `spent` late in a fifth set and
leaves the median one labouring. The ratio between them is unchanged, because
the ratio is the design and only the scale was wrong.

## `func _incoming_ball_force(trajectory: Dictionary, fallback: float) -> float:`

*in `_reception_pass_result`*

How well this voli stays on their feet, as three separate questions.

The first version of this read two raw attributes and nothing else, which made
every band a referendum on a single number -- and left `composure`,
`explosiveness`, `work_rate`, `ball_control` and the voli's own *mass* with no
say in whether they ended up on the floor, despite all five being exactly what
decides it.

They are kept as three composites rather than one, because the three outcomes
are not degrees of the same failing:

- **footing** is staying square and re-planting -- the knee band.
- **balance** is not toppling when you could not square up -- the fall band.
- **anchor** is not being moved by the ball at all -- the blow-away band, and
the only one where being *heavy* is an advantage.
How hard the ball was actually travelling, from the flight that was drawn.

The recovery bands used to be handed a *quality* -- the serve's rating, or the
attack's effectiveness -- as their idea of force, which meant a perfectly
placed floater and a jump serve at the same rating hit a defender equally hard.
Speed is a property of the arc, and the arc is already built and drawn, so this
reads it rather than standing in for it: distance over duration, normalised
into the band above. `fallback` covers the paths where no trajectory exists
yet, so the change can never make a contact forceless.

## `func _dig_recovery(`

*in `_incoming_ball_speed`*

What a dig cost the defender, on the same four bands as a reception.

A dig is the same act with a harder ball, so it resolves through the same
function -- but its inputs have to be translated, because a dig *quality* is
not a reception *execution*: dig quality averages around a third where
reception execution averages around two thirds, so feeding it in raw would put
nearly every dig in the world on the floor.

The honest translation is the margin. A dig that comfortably beat the swing it
faced was clean; one that barely survived was desperate; one that lost was a
body on the floor. That is exactly the comparison `_dig_contest` already makes,
so the recovery is read off the same difference the outcome is.

## `func _reception_skill(receiver: VolleyballPlayer) -> float:`

*in `_recovery_anchor`*

What a receiver brings to a serve reception, before the serve itself is
weighed. One formula for both sides of the net.

Written out twice before this: the home side (opponent serving) summed
reception 0.65 + ball_control 0.20 + composure 0.15 -- three attributes to
1.0. The opponent side (home serving) summed reception 0.58 + ball_control
0.24 -- two attributes to 0.82, composure never read at all. Measured across
629 receptions on identical rosters: home reception quality averaged 0.606,
the opponent's 0.378 -- the largest single asymmetry in the engine, and it
was upstream of the whole chain the set-quality histogram measured
downstream of it (opponent set capability_penalty 0.297 against home's
0.132, opponent attack error 47.7% against home's 15.4%). Composure alone
does not explain a 0.228 gap; the short weights did the rest.

## `var force_needed := RECOVERY_HEAVY_FORCE \`

*in `_contact_recovery_state`*

Ordered, worst first, on one scale -- so a worse contact can never land in
a gentler pose than a better one. The old branches selected different
populations through different gates and were not ordered at all:
`blown_away` came out better on average than `knee`.

Being driven off the ball keeps its extra requirement, because it is the
one state that is not simply about handling it badly -- a defender is
blown away by a ball that was too heavy for them, and without the force
gate this band would just be "the worst contacts", which is `fall`.
The anchor still sets how heavy is heavy for this particular voli.
The anchor swing has to keep the whole band inside the scale it reads.

At 0.44 around a 0.894 base, a well-anchored voli needed 1.11 -- and force
is capped at 1.0, so no ball in the game could ever knock them off. A
threshold outside its own distribution, arrived at by moving the base
without re-checking what the swing did to the top of the range.

## `func _commit_facing(player_id: int, leg: Dictionary) -> void:`

*in `_contact_recovery_state`*

Record what a contact cost the player who made it, and charge it.

Two costs, and they are different in kind. The *delay* is spent inside this
rally -- it is why a defender who dug off the floor is not the one covering
the next ball -- and the *fatigue* is spent across the match. Both are booked
here so no call site can take the pose without the price.
**What a body is still carrying when a new phase state is built.**

`RallyStateBuilder` makes every actor at rest, BALANCED and IDLE, and the
resolver rebuilds a phase state several times per rally. So a blocker who had
just landed, or a defender still getting up off the floor, arrived in the next
phase as though nothing had happened -- the debt was still charged against
their *clock* through `_recovery_time_penalties`, but the body the contact
envelope looked at was fresh.

`player_recovery` has carried both the debt and a **name** for it since it was
written (`"airborne"` from a block jump, `"fall"`, `"knee"`, `"blown_away"`,
`"platform"` from a floor contact). Nothing ever read the name back. This does,
and nothing else: no new state, no new value, no new relation. A voli who owes
nothing at this moment is left exactly as the builder made them.

This is what `ContactEnvelopeSystem`'s AIRBORNE takeoff exclusion and the
claimant's usable-time requirement were both waiting on -- two certified
repairs that could not fire because the state they test never survived a leg.
See `docs/review/ACTOR_CONTINUITY.md`.
Records the orientation a committed leg left a body in, when its form
establishes one at all. A `"transition"` or `"approach"` leg opens the body up
and the route becomes the orientation; every other form preserves what was
already there, so nothing is written and nothing is overwritten.

## `func _recovering_count(at_time: float) -> int:`

*in `_note_recovery`*

The seconds each player still owes, in the shape `choose_claimant` takes.

This is where a recovery stops being bookkeeping. A defender getting off the
floor has less of the next ball's flight available to reach it -- literally,
not as a penalty -- so the claim search sees a shorter clock for them and
somebody else takes the ball. Without it the whole cost was inert: measured,
zero digs in 720 rallies were ever taken out of a recovery.
How many players are on the floor right now. Reported on contacts so the census
can see the cost being paid: the *primary* effect of a recovery is that the
player is not chosen for the next ball at all, which makes the dig-quality
multiplier invisible in the outcome -- the exclusion succeeded, so the excluded
player never appears in the sample. A count of who was down is the thing that
can actually be observed.

## `func _note_block_airborne(`

*in `_recovering_count`*

How long each blocker is still off the floor when the ball comes down.

**A blocker who has just jumped was competing for the next ball as though
they were standing ready.** `_note_recovery` is called at exactly five sites,
all of them platform contacts -- a reception or a dig -- so nothing in the
engine ever recorded that a body is airborne. `_recovery_time_penalties` is
handed to `CoverageModel.choose_claimant` for the floor defence, and for a
front-row blocker it was always empty: the claim search gave them the ball's
whole flight to reach it, starting from a body two feet in the air.

Measured over 300 rallies: **0 of 151 defensive contacts** happened with any
body registered unavailable. After this, 72 of 155.

Nothing here is invented. `block_jump_timing` already publishes each blocker's
`hang_seconds` and whether they went up late, and `BlockJumpModel.jump_timeline`
already turns that into a landing instant -- `hang_seconds` itself is
`2 * sqrt(2 * leap / g)`, ballistics rather than a tuned number. All of it was
consumed only by playback, so the engine drew the jump correctly and then
forgot about it when deciding who could reach the next ball.

Written straight into `player_recovery` rather than through `_note_recovery`,
because that function looks its delay up in `RECOVERY_DELAY_SECONDS` by name
and the four states there are floor recoveries -- knee, fall, blown away.
Adding a fifth would be inventing a duration for something the jump model
already measures. The record shape is the one `_recovery_time_penalties` and
`_recovery_debt` read, so the existing mechanism carries it unchanged.

An airborne blocker is not "recovering" the way a dug-out defender is. The
state is named so that stays legible, and it deliberately takes no fatigue
cost: `RECOVERY_FATIGUE_COST` prices hitting the floor, and the jump is
already charged elsewhere.

## `func _ready_facings(player_ids: Array, side: StringName) -> Dictionary:`

*in `_note_block_airborne`*

Which way each of these bodies is set, for the claim search.

**Side-relative and toward the net**, which is where a voli waiting for the
other team's attack stands -- and it is mirrored, because the two sides face
opposite ways down the same axis. Not toward the ball: preparation must not
gain information from the action it is about to be tested against.

This is the *standing* case, and it is the honest one for a defender who has
not moved since the rally reset them. A defender who has chased a ball has no
established post-movement orientation anywhere in this engine -- see
`docs/review/READY_ORIENTATION.md` for why that transition is the boundary
this pass stops at, and why guessing it here would be inventing a turn model.

## `const BERTH_NEUTRAL_SETTLED: float = 0.50`

*in `_can_enter_attack`*

Who is physically taking this second contact, and from where.

The candidate list, their starting positions and the designated setter's id
all arrive as arguments rather than being read off `lineup` and
`live_positions` directly, because both sides of the net need this and they
keep their players in different places. That was the whole defect: the home
side ran this and `_second_contact_setter` below, and the opponent ran
`opponent_team.setter()` -- one line, always the same player, including on
the ball that player had just dug themselves.

On identical rosters that showed up as a `capability` term of 0.625 for the
home transition set against 0.878 for the opponent's, which is only possible
if the two sides are choosing different people to set. One of them was not
choosing at all.
Where this voli has to run to get round the bodies in their way, or `null`
when the line is clear. The corner comes back with the body that caused it
and how far short of clearance they were, so the bend can be drawn against
the thing it bends around instead of appearing from nowhere.

**A collision is not a decision.** The first version of this charged a flat
delay before the claim, so a badly obstructed setter simply lost the ball to
somebody clearer -- which is a setter choosing not to go, and a setter
choosing not to go is not a collision. It was also invisible: a number added
to a number, with nothing for playback to draw.

What actually happens is that the voli still goes and their route bends. A
back-row setter runs round the passer who stepped in short; a middle loses
their approach to a libero on the floor behind them; two volis crossing the
same ground each give way a little. So this returns the corner they have to
turn, `_movement_time` times the staged route through it, and the cost falls
out of the geometry rather than being asserted.

The corner is the closest point on the line, pushed sideways until the
obstructing body clears -- away from them, so the detour goes round rather
than through. Worst obstruction only: a voli threading two bodies takes the
wider berth, and stacking every detour would bend a path into a spiral for
a court that has five other people on it.
`bodies` is the caller's own side, id to position. It is deliberately not
`live_positions`: that dictionary is the home side only and holds just the
players who have already moved this rally, so the opponent's setter was
being tested against bodies on the far half of the net -- never within
clearance, so the whole thing was inert over there. The second-contact
candidate `starts` are side-correct and cover all six, so they are what gets
passed in.
How much room this mover leaves *this* teammate, as a multiple of a torso.

Two volis who have run this overlap a hundred times pass close: each knows
which way the other will break, so neither swings wide. Two who have not both
hedge, and hedging is a wider berth and therefore a longer route -- which is
the cost of poor cohesion expressed as geometry rather than as a penalty
added to a number.

Ego is the other half and it acts on the *mover*: a voli who does not expect
to be moved for holds their line and cuts close, and the give-way is somebody
else's problem. That is not a virtue. It is why a squad of high-ego volis
produces the collisions this model is for, and it is measured on the mover
alone because the obstructing body is not making a decision here -- they are
standing somewhere.
**Centred, not lerped between two ends.** The first version was
`lerp(1.30, 0.80, settled)`, which hands an ordinary squad 1.12 -- so the
knob did not separate squads, it widened every berth in the game by 12% and
called that cohesion. The movement-agreement gate caught it: SET already
carries a documented residual at its lower bound and a systematically longer
second-contact route tipped it.

So this is a deviation from 1.0 about a stated neutral. A default squad
(`Team` ships 0.50 cohesion and 0.35 familiarity, and an unknown pair reads
`BASELINE` 24 of 100) computes `settled` = 0.361, which sits slightly wide of
neutral on purpose: a squad that has not played together should hedge a
little.

The swing is deliberately modest and deliberately measured rather than felt.
It is not yet known whether +/-8% of a torso changes anything a player would
notice -- `tools/obstruction_probe.tscn` is what says so, and the value stays
small until it does.

## `func _stamp_second_contact_claim(event: RallyEvent, choice: Dictionary) -> void:`

*in `_navigation_waypoint`*

Puts the second-contact claim onto the event that resulted from it.

`_spatial_setter_choice` computes the reach margin, the claim gap, the seam
and the corner the setter had to turn, and until this existed exactly one of
them -- the travel time -- left the function. The rest were computed and
dropped at the seam, which is the fault this file has now made four times.

`navigation_waypoint` is the one with a drawn consequence: both playback
paths already stage a corner for a hitter's approach, and a setter running
round the passer who stepped in short is the same shape of leg.

Skipped wholesale when the live setter replaced the chosen body, because
then every field describes somebody who did not take the ball.

## `const SECOND_CONTACT_EGO_PULL: float = 0.050`

*in `_stamp_navigation`*

How much this voli calls for a ball nobody has been assigned.

Legs and duty decide most of a second contact and they are the two terms
above this one. What they cannot express is that a loose ball between two
bodies is settled by who *shouts* -- and three separate temperaments answer
that differently:

- **ego** is the one that takes a ball it has no business taking. It is the
unwillingness to be talked off a decision, so it belongs here rather than
in a duty weight: duty is what the sheet says and ego is what happens when
nobody consults the sheet.
- **leadership** is the mirror image, and it is why it is worth half as much.
Both make a voli likelier to end up with the ball, but leadership does it
by the others *clearing out*, which is a good outcome, and ego does it by
the others being overruled, which is often not.
- **aggression** barely belongs and is here small and deliberate: a second
ball is not a terminal contact, so the voli who wants to end rallies has
only a slight pull toward being the one who touches it. If this term grows
it is a sign the second contact is being modelled as an attack.

Sized against `duty_bonus` -- but **this paragraph used to state that spread
wrongly and the constants below were sized against the wrong number.** It
read "+0.46 for the designated setter and -0.24 for no duty at all -- a
spread of 0.70", which takes the designated-setter term as if it were the
whole of that voli's duty. It is not: it is added *on top of* whatever the
plan already gave them, so the real extreme is +0.80 -- the plan's own
"Primary emergency setter" (+0.34) plus the designated-setter term (+0.46) --
and the real spread is **1.04**. Measured, not reasoned:
`tools/run_second_contact_probe.gd` and `docs/review/SECOND_CONTACT_AUDIT.md`.

The constants are left where they are. 0.09 against 1.04 is still well under
the tenth the paragraph below claims, so the sizing conclusion survives its
own arithmetic being wrong -- which is worth saying plainly rather than
quietly correcting, because it was luck and not judgement.

**The first sizing said a tenth and was a third.** 0.14 + 0.07 + 0.04 reaches
0.25 for a voli at the top of all three, which is enough to hand a second
ball to somebody with no duty at all, and the fatigue gate caught it: matches
resolved differently enough that peak fatigue over 24 weeks fell from above
0.15 to 0.10. Stating a magnitude in a comment is not the same as having it,
and the arithmetic was never done. These reach 0.09 together, which is the
tenth the paragraph claims: it decides a coin flip and never overrules the
sheet.

Cohesion is *not* here on purpose. A confident squad does not produce a voli
who wants the ball more; it produces one who yields cleanly when somebody
else has it. That is the seam, and it is handled there.

## `const SUPPORT_CROWDING_METERS: float = 1.05`

*in `_second_contact_claim_score`*

What a teammate nearby is worth, which is not always positive.

**Two volis in one space were being scored as double coverage.** The term
this replaces was `min(count * 0.025, 0.075)` -- a count of reachable
teammates, with no distance in it at all, added as a bonus. A teammate five
metres away and one thirty centimetres away contributed identically, and the
crowded case contributed *more* because crowding puts more bodies in reach.

Cover is a band, not a monotone. A teammate too far away is not covering this
ball; one on top of you is worse than nobody, because at that spacing you get
platform interference, a blocked sightline, a foot in your step and a moment
of who-has-it. The peak sits where a second body can chase a deflection
without being inside your swing.

Sized so the harm can exceed the help. A bonus that bottoms out at zero would
make stacking *neutral*, and neutral is still not a reason to stop doing it
-- the handoff's point is that bad spacing has to cost something a manager
can see. The floor is deliberately deeper than the ceiling is high.

Distances are unmeasured as thresholds: nothing had ever published defender
spacing, which is why the old term could go this long without anyone
noticing it had no distance in it. `tools/responsibility_probe.gd` prints the
distribution now, and these want cutting from it rather than from taste.

## `var attack_map: Dictionary = opponent_live_positions if defending_home \`

*in `_resolve_overpass_attack`*

The attacker's own live position, read from the map for the side they are
actually on -- `defence_map` above is the *defending* side's.

The previous fallback was `attacker.position`, which could never return
anything: a `VolleyballPlayer` is a Resource carrying attributes and has
never had a `position`. Two failures, not one. `Dictionary.get` evaluates
its default eagerly, so that access ran on *every* call and pushed an error
even when `choice` carried a perfectly good contact position; and on the
path it was written for it produced `Vector2(null)`, putting a first-ball
overpass swing in the corner of the court instead of under the attacker.
A fallback that cannot reach its own stated range, failing silently in the
one case it exists for.

## `head_start_seconds: float = 0.0,`

*in `_spatial_setter_choice`*

**How long these volis have already been running when the pass is
played.** Zero is the old behaviour and is a lie the engine told itself
everywhere: every second contact was timed from a standing start at the
instant the platform touched the ball, as though the setter had spent the
whole serve flight watching.

Measured before this existed, the setter's arrival margin ran a median
-0.37 s with a p95 of -0.03 s -- 95% of setters arriving late to their own
ball, which is not a hard game, it is a missing head start. It also made
the jump set unreachable, since loading a hop needs margin nobody had.

Spent as *distance already covered*, not as time added to the window. A
setter did not get two seconds to react to a pass that had not happened;
they got a head start toward the place the ball was always going, and the
pass then tells them how much of the last adjustment they still owe.

## `expected_area: Vector2 = Vector2.ZERO,`

*in `_spatial_setter_choice`*

**Where the setter is running while the head start runs, which is not
where the ball turns out to go.**

The first cut advanced every candidate toward `target` -- the resolved
pass destination -- during the serve flight, which is a coordinate that
does not exist yet. A setter releasing on serve contact knows the serve's
trajectory, the likely receiver and the zone they are supposed to set
from; they do not know where the platform will actually put the ball.
Running them at the answer is precognition, and it makes the head start a
free arrival rather than a real one.

`Vector2.ZERO` means "no expectation published", and then the head start
is spent toward the target as before -- kept only so a caller that has not
been given a zone is unchanged rather than silently frozen.

## `var arrival: Dictionary = CoverageModel.evaluate_arrival(`

*in `_spatial_setter_choice`*

**How confidently, not merely whether.**

The physical half now comes from the same `evaluate_arrival` the first
contact uses, judged from where this body actually is rather than from a
formation slot -- so a second contact reports a reach margin in metres
the way a reception always has. The duty weighting below stays local,
because a serve receive and a second ball genuinely do rank
responsibility differently and one shared chooser would have to pretend
otherwise.

No zone: there is no second-contact zone type, and a null one used to
exclude a candidate outright. Admitted with no responsibility credit
instead, which is the same correction `assigned_reach` already carries
-- legs decide who can get there, the assignment decides who should.

## `var score := _second_contact_claim_score(`

*in `_spatial_setter_choice`*

**The active setter's responsibility replaces the plan's, it does not
stack on it.** `Primary emergency setter` and `Secondary emergency
setter` describe who covers *when the normal setter cannot take the
second contact*. They are a fallback hierarchy, and reading them as an
extra bonus for the normal setter is a category error: it made the
setter's own authority depend on which slot the rotation had put them
in, because the plan writes those duties per slot.

`+=` totalled +0.80 in slot 2 (where the plan's own primary emergency
duty lives), +0.64 in slot 1 and +0.22 in the other four -- a swing of
0.58 that no design document asks for. And the top of that range was
exactly pathological: +0.80 against a no-duty -0.24 is a gap of 1.04,
while `arrival_score` below is clamped to [-1, 1] and weighted 0.52, so
the whole authority the legs have is **also 1.04**. Two spans of
identical width, so in that one rotation the legs could tie
responsibility and never beat it. Measured: a stranded setter kept a
ball a team-mate was standing on in rotation 2 and lost it in all five
others, on identical geometry.

`=` gives the setter a flat +0.46 in every rotation. That is still
above the plan's primary emergency duty (+0.34), so responsibility
stays strongly first -- and 0.46 against -0.24 is 0.70, inside the
legs' 1.04, so an impossible claim can now yield. The policy this
implements: **strong first responsibility, not absolute.**

Note this branch is unreachable for a setter who played the first
contact -- they are excluded from `candidates` above -- so the fallback
hierarchy among the remaining five is untouched by the change.
`docs/review/SECOND_CONTACT_TRANSFER.md`;
`tools/run_second_contact_probe.gd` gates 1-6.

## `best["seam_conflict"] = gap < _seam_margin(`

*in `_spatial_setter_choice`*

**A seam is a failure to delegate, so cohesion is the width of it.**

The gap is how far apart two volis' claims are; the threshold is how
small a gap this squad can still resolve without both going or neither.
A side that has played together reads the same ball the same way and
one of them clears out early -- so the window in which they collide is
narrow. A side that has not hedges, and a gap that a settled squad
would have delegated cleanly becomes two people calling for it.

Leadership is the other half and it applies to the *leader of the two*:
somebody the room follows shuts a seam that two equals would argue
over. Read off whichever claimant leads, not the winner, because a
captain deferring is still a captain resolving it.

## `const SEAM_COHESION_SPAN: Vector2 = Vector2(2.2, 0.4)`

*in `_spatial_setter_choice`*

How wide the window is in which two volis both think the ball is theirs.

`SECOND_CONTACT_SEAM_MARGIN` is the middle of the range rather than the whole
of it -- it is what a squad at 0.5 cohesion with two ordinary volis gets.
Measured over 1,520 second contacts before this existed: the fixed 0.10 fired
zero times against a real claim-gap distribution starting at p05 0.142, which
is a threshold sitting outside its own distribution, so a *constant* here was
never going to be the answer whatever value it took.

The spread is deliberately wide for that reason: at zero cohesion between two
volis nobody follows it reaches 0.10 * 2.2 = 0.22, which is above the p05 of
the distribution, and at full cohesion it falls to 0.10 * 0.4 = 0.04, well
below it. A knob that cannot reach its own range is the failure this
repository keeps making; this one is built to span it and then be measured.

## `func _second_contact_setter(`

*in `_seam_margin`*

The designated setter, unless they took the first contact -- then whoever the
plan nominated to cover for them.

**This does not decide who sets.** Every caller hands the answer straight to
`_spatial_setter_choice` as `preferred_setter`, where it is worth +0.20 in a
re-score that reads live positions, the realized pass's own duration, the
head start and recovery debt. So this function contributes a *preference* and
a null-fallback, and nothing else -- which is the right shape, because it
takes no position and no clock and could not honestly decide reachability.

Worth knowing before reading the numbers below: they are **not** the duty
weights `_spatial_setter_choice` uses. The same four duty strings are scored
+0.42 / +0.24 / -0.10 / -0.22 here and +0.34 / +0.18 / -0.16 / -0.24 there,
and `ShadowSetterResponseSystem._duty_priority` uses a third table that ranks
"Stay available to attack" *below* "No second-contact duty" -- the opposite
order to both of these. Three tables for one concept, in one leg. Recorded in
`docs/review/SECOND_CONTACT_AUDIT.md` §4 rather than unified here, because
picking which table is canonical is a tactical decision, not a tidy-up.

## `func _stamp_physical_times(result: Resource) -> int:`

*in `_build_rally_analysis`*

When each event physically happened, on the clock the rally was simulated on.

An event's moment is when its actor touches the ball and sends it, which is
exactly its outgoing trajectory's `start_time`. Measured across 300 rallies,
every event that carries both that and a resolver-supplied `event_time`
agrees to within a microsecond, so the trajectory is authoritative and the
hand-placed stamps are corroboration rather than a second opinion.

Two kinds carry neither and are derived rather than invented:

A block that never touched the ball has an empty `outgoing_trajectory` --
the resolver deliberately emits no deflection segment for an untouched
ball -- and was stamped with bare `rally_clock`, which at that point is
still the moment the *set* left the setter's hands. That produced 90
blocks per 300 rallies recorded 0.782 s *before* the swing they blocked.
The real moment is when the ball crosses the net, which is a known
fraction along the attack's own flight.

POINT has no trajectory and no stamp at all. It happens when the ball
finishes, which is the last trajectory's end.

The running maximum at the end is a causality floor, not a schedule: events
are emitted in the order they occur, so a physical time may not precede the
event before it. It is counted, because a floor that fires often would mean
the derivations above are wrong.

## `static func realised_flight_end_height(trajectory: Dictionary) -> float:`

*in `_net_crossing_time`*

**Where the ball was when each contact was made, carried forward once.**

`CONTACT_AND_BALL_FLIGHT.md` §5: a realised contact is one point, so the
incoming segment's far end *is* the contact's height. Every family that
publishes a resolved flight already states that far end; nothing read it, and
presentation fell back to a body measurement -- a reach, a platform, a hip --
which is a fact about the player standing in for a fact about the ball.

This is a copy, not a computation. It reads the incoming leg's own
`end_height_meters` and only when that leg says it knows
(`height_source == "resolved"`), so a family whose writer never resolved its
heights is left alone rather than given a number invented here. That is the
difference between propagating authority and minting a second one.

The block is skipped because it already publishes its own, proved by the
intersection test rather than inherited from the incoming flight -- and on a
beaten block there is no contact for this to be the height of. See
`docs/review/BLOCK_REALISED_CONTACT.md`.
Where a published flight ends, in absolute metres, from the flight itself.

Two ways a flight can say, and no third. A writer that resolved both ends
states it (`height_source == "resolved"`). A writer that resolved its start
and published its launch has said it implicitly, and integrating that launch
across the flight's own duration reads it out -- that is evaluating the
flight, not extrapolating past it, because the duration is the flight's.

`NAN` for a flight that resolved neither, which is honest: the 1.0 m default
`BallTrajectory.create` falls back to is not a height anybody measured.

## `if event == null or int(event.event_type) in [`

*in `_stamp_realised_contact_heights`*

**An action event is not a ball contact, and must not become one by
standing between two.**

This skipped only `POINT`, so a `SET_DECISION` -- which publishes no
outgoing flight, because nothing was struck -- became the `previous`
event for the set that followed it, and the set was left with no
contact height at all. Measured: 109 of 261 sets stamped from nothing,
every one of them preceded by a decision, and none of the 152 without
one affected. The seam was not an asymmetry between the two sides'
physics; it was one side's rallies carrying an extra event and this
loop counting it as a contact.

`MatchScreen._next_contact_index` skips exactly this pair, and has
since it was written. Matching it rather than inventing a second
opinion about what a contact is.

## `var incoming: Dictionary = previous.metadata.get(`

*in `_stamp_realised_contact_heights`*

**Only when the incoming flight actually ends at this contact.**

`height_source == "resolved"` is that test, and it is a narrower
one than it looks. A set is solved *between* two heights, so its
far end is the contact that receives it and the two are one point.
A serve is not: it publishes the whole flight to where the ball
would land, and the reception happens partway along it, so the
serve leaves `end_height_meters` unresolved and this correctly
declines to speak for the pass.

The contact's own outgoing launch height was tried as a second
source and rejected on measurement: on the reception it equals the
body proxy to three decimals (`|launch - body| = 0.000` over 162
legs), so it is the platform wearing a flight's clothes rather
than an independent statement about the ball. Preferring it moved
no reception seam and widened the opponent set's from 42 breaks to
63. See `docs/review/CONTACT_HEIGHT_CHAIN.md`.

## `event.metadata["ball_contact_height_meters"] = maxf(`

*in `_stamp_realised_contact_heights`*

Same derivation the platform resolver now uses, so the height
a contact is *resolved* at and the height it is *drawn* at are
one function rather than two that agree by inspection.
**A flight that knows where it started and how it left can say
where it finished.**

The serve is the family this exists for. It resolves its own
contact height and its launch and leaves its far end unstated,
which read as "the serve cannot say where the pass was" -- and
the measurement says otherwise: the serve flight's published
end time and the reception's own stamp agree, so the flight is
already terminated at the pass rather than running on to the
floor. Integrating its launch across its own duration is
therefore evaluating the flight *at the contact*, not
extrapolating past one.

Not a second physics. This is the same integration
`BallPresentation` performs to draw the leg, moved to the side
of the boundary that owns the fact -- which is the whole of §5.

## `previous = event`

*in `_stamp_realised_contact_heights`*

**`outgoing.start == C` is the third term and it is not closed here.**

Writing the contact height back onto this event's own flight was tried
and does nothing: every family that reaches this point publishes a
launch, and a launch was solved *from* the start height it shipped
with. Overwriting only the height would leave a flight disagreeing with
its own length, which is a worse record than an honest gap.

What the gap is, exactly: the reception's arc is solved from the
platform's height, so once its contact says the ball's height instead,
the arc departs from somewhere the contact no longer claims -- 0.29 to
0.42 m, and it appears as a set seam. That disagreement is not created
here. It was always in the record and the platform proxy was hiding it
on both ends at once. Closing it means re-solving the pass from the
ball's height, which moves `pass_apex_meters` and therefore the set
clamp, and is simulation work rather than a seam repair. See
`docs/review/CONTACT_HEIGHT_CHAIN.md`.

## `var requested_time := float(metadata.get("event_time", timeline))`

*in `_finalize_rally_timeline`*

What the resolver itself said, kept before this function replaces it.

`event_time` is read here as a request and then written back over with
the finalised value, so the resolver's own physical timestamp -- the
one the rally was actually simulated on -- is destroyed on the way
out. Nothing downstream could tell a time the physics produced from a
time this loop invented, and the coverage question ("does every event
carry a real one?") could not be asked at all from outside.

Recorded, not yet used. Driving playback from it means deleting the
accumulator that currently guarantees monotonic ordering, and that is
only safe once the coverage is known rather than assumed.

## `timeline += maxf(flight_duration, trajectory_duration)`

*in `_finalize_rally_timeline`*

The ball's own motion advances the rally clock. Nothing else does.

This used to advance by `duration`, which is the longest of the ball's
flight, the actor's traversal, and a per-type floor -- so a defender
taking a read step held the ball in the air until they finished, and a
block that never touched it still cost 0.24 s of dead clock. Because
the running total is then `maxf`'d against each event's real physical
time, once the accumulation drifts ahead it stays ahead and pushes the
whole remainder of the rally later.

Measured over 300 rallies: 0.96 s per rally of held ball against a
5.78 s mean span -- 17% of playback, most of it DEFENSE at 0.483 s a
time with 126 of 162 bound by movement rather than by the ball.

`event_duration` is untouched, so an actor's animation still knows how
long it takes; it now runs *alongside* the flight instead of in series
with it, which is what it does in the sport.

## `RallyEventModel.EventType.DIG, \`

*in `_ensure_event_trajectories`*

**A successful floor dig no longer arrives here.** It publishes
its own `outgoing_trajectory` at the contact, so the `continue`
at the top of this loop already skipped it. What reaches this
arm is a *failed* dig -- a ball nobody controlled -- and the
flight drawn for it is display only, which is correct: there is
no physical pass to model because no pass happened.

**Coverage has to be listed or it silently loses its ball.**
The default arm below is `continue`, not a fallback -- an
unlisted type gets no `outgoing_trajectory` at all and the ball
teleports out of the contact. Splitting the enum without this
line would have deleted the flight from every one of the 38
coverage contacts in 700 rallies.

## `if event_type != RallyEventModel.EventType.SERVE:`

*in `_add_event`*

**FD-003: where the twelve are, on every leg, from the one place that
sees every contact.**

A phase map says "these volis travel to here during this leg" and only
some legs have one -- SET publishes one side, DIG and BLOCK about half --
so presentation invented targets for the rest out of
`_support_target_for_side`'s lerp table. That is the F4 class in
`01_TARGET_AUTHORITY_STATE` §9: drawing authoring movement nobody decided.

The missing statement is not a journey. It is a *hold*: the resolver did
not move these volis on this leg, and `live_positions` is its own record
of where they consequently are. Publishing that is stating a fact it owns,
not inventing one -- and it is what FD-003's own next-repair note asks for
in its second half, "make it read as a hold rather than a journey".

Under separate keys deliberately. Several sites stamp a real phase map
*after* `_add_event` returns and do so by replacing the whole dictionary,
so filling `home_phase_targets` here would be silently discarded on the
legs that matter most. Presentation reads the real map first and falls
back to this, which also keeps the two distinguishable in the census: a
voli who was walked somewhere and a voli who stayed put are different
findings and should not merge into one column.

**Not the serve.** A rally's first contact has no preceding flight, so
there is no leg for anyone to hold *through* -- playback draws a leg as
`event -> next_contact` and the serve has nothing before it. Both sides'
serve-flight movement is already published on the RECEPTION, which is the
event that leg belongs to. Stamping a hold here would have counted the
same twelve volis as answered *and* as having no interval, which inflates
the census denominator by 3,300 and makes "0% invented" partly an artefact
of the instrument. FD-001 is the same mistake in the other direction and
this file's own `no leg` row exists because of it.

## `var recovery_owed := _recovery_time_penalties(rally_clock)`

*in `_add_event`*

**What every body on court still owes, on the contact that samples it.**

M7 / C1, and D2's "expose enough authoritative state for playback and
history to draw it". `player_recovery` has carried contact consequences
across phase boundaries since `ACTOR_CONTINUITY.md` certified the plumbing,
and `_recovery_time_penalties` hands it to the second-contact and defensive
claim clocks -- so it is already gameplay authority. It was simply never
*published*. Nothing outside this file could see that the voli who just dug
the ball is still getting up, which meant a probe asking C1's question --
does a contact leave debt the next leg still owes -- had no channel to read
and returned zero for the whole engine.

Published from `_add_event` for the same reason the jump is charged here:
one place sees every contact, and a per-site publication is a list with one
site missing from it.

Written onto the event's own copy rather than into `metadata`, which is the
caller's dictionary and in several places is reused for the next event.

## `if not event.metadata.has("body_contact_position"):`

*in `_add_event`*

**Where the body that made this contact was standing.**

M8 asks every boundary for `actor_start -> traversal -> contact(position,
time)`, and the contact position was published by two families of seven:
SET and ATTACK, on both sides. Serve, reception, block, dig and coverage
published only where the *ball* was -- a reception event's
`start_position` is the serve's landing point, which is a fact about the
ball and says nothing about the passer.

Nothing is derived here. At the moment a contact event is appended the
actor's live position *is* their contact position: every family writes it
before appending -- `live_positions[receiver.id] = receiver_reach`,
the hitter's from the attack integration, the setter's from theirs. This
publishes the state that already exists rather than reconstructing it, and
it defers to a family that stated a more precise one of its own.

## `var trust := (`

*in `_setter_option_terms`*

**How well this setter knows this hitter.**

The one term here that is about a *pair* rather than about either voli
alone. A setter goes to the hitter whose run they can feel, and stays away
from the one whose timing they are still guessing at -- which is why
bringing in a better arm does not immediately make them the first option.

Read through the setter's own judgement, as everything else here is: a
good setter's preference for a trusted hitter is a *read*, and a poor
one's is a habit. Centred on the baseline so an untracked pair -- a
friendly, an opponent whose table nobody keeps -- scores neutral rather
than as strangers.

## `func _attack_pressure(`

*in `_attack_effectiveness`*

How hard the ball itself is to handle, on top of how well it was struck.

**The swing barely participated in its own contest.** Measured over 299 digs,
attack effectiveness spans 0.356 to 0.557 between the tenth and ninetieth
percentile -- a range of 0.20 -- while the defender's quality spans 0.125 to
0.923, a range of 0.80. So the outcome was four times more a fact about where
the defender was standing than about the attack, and a hammer and a roll shot
with the same execution score were the same problem to dig. That is the
mechanical reason a powerful hit does not feel powerful.

**Pace, and only as a contact difficulty.** A faster ball is already harder to
dig through a channel that exists and works: it arrives sooner, the reach
margin shrinks, and `_defense_terms`' timing factor falls with it -- measured,
the dig rate runs 0.70 in the slowest speed band against 0.34 in the fastest.
Adding pace to *arrival* again would price the same difficulty twice, which is
the mistake `DIG_ATTACKER_ADVANTAGE` was re-fitted to undo.

What is genuinely unpriced is the other half: a ball struck at thirty metres a
second is harder to keep on the court *once you are there*, off a platform
that has to absorb it. That is about the contact, not the journey, and nothing
in the dig contest knew it. `_contact_recovery_state` reads `incoming_force`
to decide whether a defender is knocked over, and that was the only place in
the game where the weight of the ball meant anything at all.

Applied at the dig rather than folded into `_attack_effectiveness`, because
the block's contest is a timing and geometry problem where pace is not the
question, and the two consumers should not be handed one number that means
two things.

## `var quick_is_on := RallyFeatureFlagsModel.ENABLE_HOME_MIDDLE_OFFENSE \`

*in `_fallback_hitter`*

The middle, on a pass that allows one.

This function has only ever looked for Outside Hitters, falling through to
"any front-row body" if there were none -- so a front-row middle was never
chosen while an outside hitter existed, which is always. Measured over 185
home swings: Left Pin 34, Right Pin 151, and not one quick or pipe in the
sample. The home offence was two hitters and a high ball.

Gated on the pass because a quick is not a shot you can run off a bad one,
which is the whole reason the middle is a *conditional* option rather than
simply another name in the list.
Whether a quick is on at all. The middle is *eligible* on this ball, not
entitled to it.

This used to return the front-row middle outright the moment the pass
allowed one, ahead of the scored selection below -- so a good pass meant the
middle, every time, and the scoring only ever ran on balls nobody could run
a quick off. With the fixture squad given real attributes that produced
Front Quick 0.716 of 74 swings: the monoculture moved lanes rather than
breaking up, which is what a bypass does to a decision.

## `if not front_row:`

*in `_fallback_hitter`*

The back row swings too, on a ball that allows it.

This loop skipped every back-row slot, so the pipe was unreachable by
any code path on this side of the net -- five lanes in
`CourtConstants.LANES`, four the offence could produce, and the one it
could not is the one that occupies the middle blocker and stops a
front-row-only offence being read three-wide. Everything else it needs
already existed: `LANE_X`, a `lane_target` behind the attack line, the
"Pipe attack" hit type, an approach profile, and a play validator that
has always required back-row hitters to use this lane.

Gated on the same pass the quick is, and for the same reason: a hitter
running from four metres back needs the ball where they expected it.
A middle blocker in the back row is not a pipe hitter -- they are
resting, and in this squad they are usually about to be substituted.

## `var lane := _natural_hitter_lane(contender, lineup)`

*in `_fallback_hitter`*

And spread the ball, because ability alone is still one lane.

Ranking on the swing picked the best attacker every rally, which moved
the whole offence from Right Pin to Left Pin and left it just as narrow.
A setter who always feeds their best hitter is a setter the block reads
in one rotation, and distribution is the thing that stops that.

**Deliberately a placeholder, and worth naming as one.** The real term
is a setter decision against what the opponent is anticipating --
`OpponentTeam.anticipated_lane()` and `Familiarity` already track it and
are write-only against the home side today. This is a deterministic
per-rally spread standing in for that until it is wired: it consumes no
random draw, so it re-sequences nothing, and it is small enough that a
clearly better hitter still gets the ball.

## `applied_setter_pull: Dictionary = {},`

*in `_form_home_block`*

**The drift this wall has already been given, if any.**

This former runs *twice* per opponent transition -- once before the set is
released and once re-formed with the achieved tempo -- and it used to
write the setter pull into `live_positions` on both. The second call then
read the already-pulled position as its start and pulled again from it, so
one misread moved the same body twice. Measured over the matched block-band
population that was 92 of the 134 swings the home wall failed to form on.

Passing the first call's result in says "this drift already happened".
The body keeps whatever live displacement it genuinely has, the reported
magnitude stays the one that was actually applied, and nothing here decides
whether the pull *should* mutate a body at all -- that is the block-symmetry
question task #63 owns, and it stays open. See
`docs/review/HOME_WALL_FORMATION.md`.

## `var assist_reaction := clampf(`

*in `_form_home_block`*

The assist cannot have crossed the court before the setter touched it.

Both blockers were handed the same budget, and that budget is mostly
*pre-set*: measured, the window ahead of the set runs 0.78-1.07 s and
barely moves with tempo, while the set's own flight runs 0.20-0.99 s. At
tempo 0 that is 79% of the closing time credited before the ball exists.

For the primary that is fair, and deliberately untouched here. The primary
is by definition the blocker already nearest the attacked lane, so their
pre-set time is spent reading rather than travelling. The assist is the one
who has to cross a slot, and crediting them with having crossed it before
the lane was chosen is what made a first-tempo ball draw a double block
37% of the time.

Anticipation still pays -- `preset_share` is the read, and it stays. What
it now buys is bounded by whether there is time to *finish* the crossing
once the set confirms it. A high ball leaves the whole window usable; a
first-tempo ball leaves almost none, which is the entire reason a quick set
beats a double block, and the reason a zero ball has to be committed to
rather than read.

## `func _blocker_read_quality(`

*in `_form_home_block`*

**A blocker reads the arm, and a fast arm gives them less of it to read.**

`hitter` is new and optional. Everything above it is a read of the *play* --
the pass, the setter's body, the tempo -- which is what a blocker has before
the ball leaves the setter's hands. What they have after that is the swing,
and the swing is over faster for some hitters than others: a middle who gets
the arm through in a blink shows a blocker almost nothing, while a slow big
windup announces the shot in time to move on it.

Centred on the population rather than applied as a flat multiplier, so an
ordinary arm changes nothing and the trait cuts both ways. A slow arm is a
real weakness here and not merely the absence of a strength -- which is the
same correction `AttackPowerModel.choose_power` had to make to `aggression`.

## `func _dig_read_bonus(`

*in `_blocker_read_quality`*

What a defender can tell about a swing before it happens.

Three reads, all of them things a real defender is actually doing, and none of
them previously modelled:

- **The arm, against their own eyes.** `court_vision` was read by the attack's
own resolver and by the blocker above and by nothing on the floor, so a
libero's vision decided nothing about digging. Here it is contested directly
against the hitter's `arm_speed`: seeing the shot early is worth exactly as
much as the hitter's arm is slow.
- **The wall in front of them.** A funnelling block is *telling* the defence
where the ball is going -- that is the entire point of choosing to funnel,
and until now choosing it bought the diggers behind it nothing at all. A
sealing block buys less, because holding the line concedes the angle rather
than narrowing it.
- **A hand on the ball.** A touched ball is slower and has changed direction,
which is harder in one way and much easier in another; the engine already
pays the defender the extra flight time and this is the read that goes with
it.

Returns a signed adjustment to `read_bonus`, so a defender facing a fast arm
with no wall in front of them is *worse* off than the neutral case rather than
merely not better off.

## `var closing_actor := RallyPlayerState.create(`

*in `_blocker_close_terms`*

Blocking closes through the shared locomotion model like every other
movement in the engine. It used to carry its own `lerpf(1.25, 4.40,
lateral_speed)` -- a fourth private copy of the speed curve -- so none of
the stride, cadence or limb-turnover work reached blocking at all.

`&"home"` for an opponent blocker too, and that is now a claim rather than
an oversight: `create()` derives the ready facing from the side, so the two
sides are set at `(0, -1)` and `(0, +1)`. A close runs *along* the net, so
the route is +/-x and the dot product with either facing is zero --
`facing_fit` is 0.5 for both sides and the turn cost is identical. It stops
being irrelevant the moment a close is given any component toward the net,
which is why it is written down here instead of left to be rediscovered.

## `"closed_net_x": lerpf(start_x, footwork_x, fraction),`

*in `_blocker_close_terms`*

Where this blocker actually ended up, in normalised court x.

`footwork_x` is where they were *going*; the fraction says how much of
that they got, so the reached position is the two together. Until this
was returned it was computed and discarded, and the geometric wall
asked `live_positions` instead -- which is where the blocker *started*.
So the block closed in the timing model and stood still in the geometry
model, and the wall was drawn at the blocker's rotation slot rather than
at the lane they had just travelled to. Measured on Front Quick, whose
lane sits at x 0.400 against a middle blocker's slot near 0.5, that is a
0.9 m gap -- wider than any half-width the wall could plausibly have, so
every such ball classified as beating the block "around". It is why
doubling `BLOCKER_HALF_WIDTH_METERS` converted four balls out of
fifty-eight: the wall was never within reach of the ball to begin with.

## `func _attack_execution(`

*in `_approach_execution_fit`*

One swing, wherever in the rally it happens.

The engine carried three copies of this. The home attack summed 1.50 of
positive weight across ratings, approach and set quality; the opponent attack
used `attack_power * 0.62 + set_quality * 0.20 + 0.08`; the continuation used
a third set of weights again. All three were then compared against the same
block contest and the same error threshold, which only made sense for one of
them at a time.

Capability is what the hitter brings, normalised to a fraction of an ideal
hitter. Opportunity is what the rally handed them, and it is a **product**:
a great hitter off a terrible set, with no run-up, arriving late, should put
the ball in the stands. Summing those terms instead put roughly 0.75 of
rating weight under every swing in the game, so attack quality never fell
below 0.321 against a 0.29 error threshold and the engine produced no attack
errors at all -- not few, none, across 180 rallies.

## `func _geometric_swing(`

*in `_attack_execution`*

Gate E. The geometric swing for this attack, alongside the legacy one.

Every attack site calls this. Today nothing downstream reads the answer
unless the rollout is open -- it is recorded into the shadow summary so the
geometric outcome mix can be measured against the legacy one on live rallies
rather than on a synthetic sweep. That is the same order Gates 44 through 49
ran in, and for the same reason: an outcome model that has only ever been
swept in isolation has never met the inputs a rally actually produces.

The draws come from `geometric_rng`, a stream of its own seeded from the rally
seed and the contact index. This is not tidiness. The shadow pass runs on
every attack whether or not it is promoted, so drawing from `rng` would
advance the rally's own stream and silently change every rally in the game --
the same defect that rerolled the world when `ego` drew from the shared
generation stream. A private stream means an unpromoted geometric attack is
exactly as invisible as it claims to be.

## `func _canonical_serve(`

*in `_geometric_swing`*

**The serve. One of them, forward.**

This used to be `_geometric_serve_record`, a shadow: it resolved the serve
properly, wrote what it found onto `result.analysis`, and was then ignored
while the official ball was fitted backwards to a landing point a coin flip
had already chosen. The audit in `docs/design/CONTACT_AND_BALL_FLIGHT.md`
found the two disagreed by 2.89x on horizontal pace and concluded that
neither was the authority: production asked *"what launch puts the ball where
I already decided it lands?"* and the shadow asked *"what does this server's
ball do?"* -- two different questions, so the gap was never arithmetic.

The order here is the one the audit asked for and it is the whole of the
change:

aim -> launch search -> execution error -> flight -> landing -> verdict

`_errant_serve_landing` is gone with the rest of the inverse path. A serve
misses now because the ball it was hit as missed, and which way it missed --
into the tape, long, wide, outside the antenna -- is read off the same flight
that decides everything else about it.

## `var direction := AttackCourseModelRef.direction_meters(`

*in `_canonical_serve`*

**The serve as a flight that can be asked a question about a time.**

Every other family's ball is minted by `FreeFlightInterceptionModel`, which
is what makes it answerable: `height_at_time` and `opportunities` need a
flight they can evaluate at any instant, not two endpoints and a duration.
The serve was the one family that never got one -- M5 scoped free flight to
physical platform contacts, and its certification counted digs -- so the
reception could only be handed the serve's *end*.

That end is the landing, and the reception is stamped at exactly that
instant, so the passer was being placed on the ball at the moment it
reaches the floor. Reading it under the wrong gravity is the only reason
the number looked like a height at all: 9.8 against this ball's 21.009
turns a ball on the floor into a ball at 3.79 m. See
`docs/review/SERVE_RECEPTION_HEIGHT_SEAM.md`.

Published here and read by nobody yet. The launch is the same one
`_stamp_launch_state` already puts on the drawn arc, so this is a second
*view* of one ball rather than a second ball -- which is the distinction
`authoritative_flight_id` exists to keep checkable.

## `func _geometric_promotion(record: Dictionary) -> Dictionary:`

*in `_geometric_swing_record`*

Gate E promotion. What the geometric resolver decided, or `{}` when attacks
are still resolved by `_attack_execution` and `_contest_block`.

The shadow record is already the translation; this only decides whether the
rally is allowed to *act* on it, and re-expresses the outcome in the legacy
block vocabulary so the block event, the deflection leg and the coverage
branch keep reading the one string they have always read.

What promotion takes over is the swing's result: where the ball lands,
whether it landed in, and whether the wall got to it. What it deliberately
does not take over is the drawn arc -- `solve_launch_arc` is a ground-to-
ground solver and the resolver launches from three metres up, which is the
whole reason `_feasible_launch` exists. Handing it the resolver's elevation
would draw a spike that leaves the hitter's hand going upward at a negative
angle. The trajectory stays on the existing kinematics until it is promoted
on its own terms.

in                        the ball is down and the defence has to play it
net, out                  the swing missed; no block was involved
stuff                     the wall put it down
monster_block             a charged apex contact put it down
touch                     hands slowed it and the rally continues
tool, block_crush,
high_hands                the hitter's point, decided at the net
The one thing promotion deliberately leaves alone is `attack_quality`.

The resolver derives a quality *from* its outcome, which is the right shape
for a model that owns the whole swing -- but the legacy execution chain is
still running here, and it is what the resolver's own bearing and power
channels are driven by. Overwriting it would mean a hitter dragged out of
position and swinging late reported whatever quality their result happened to
imply, so a displaced hitter who still found the floor scored higher than a
well-set one the block grazed. Execution is how the swing was struck; outcome
is what it produced. They are allowed to disagree, and in this sport they do.

## `func _was_funnelled(record: Dictionary) -> bool:`

*in `_geometric_promotion`*

Did the wall *shape* this swing, though it never touched it?

`_contest_block` has four bands and this promotion had three words. Every
would-be funnel became a `miss`, so a wall that squeezed a hitter into the one
lane the defence was standing in was recorded identically to one beaten by
three metres -- and the `Funnel` block intent, which is a tactical choice the
manager makes on the clipboard, had no outcome that could express it working.

That is §0 in a shape worth naming: not a threshold outside its distribution,
but a **band whose value a downstream mapping could not say**. It computed
correctly and was discarded one function later, silently, for as long as
geometric promotion has been on.

## Two conditions, both geometric

**The ball went past an edge**, not over the top. Measured: of 140 beaten
blocks, the 56 hit `over` have an edge miss of 0.00 m to ten decimal places --
a ball that cleared the hands never went past them. Cutting the whole beaten
population would put a threshold inside a spike at zero and call every
over-the-top swing a funnel.

**And it went past narrowly.** The 65 blocks with a lateral escape spread from
0.02 m to over a metre, median 0.42. A funnel is the narrow end: the hitter
had to squeeze the ball past the hand rather than sail it wide.

The cut is `BLOCKER_HALF_WIDTH_METERS` -- the ball crossed closer to the hand
than the hand is wide. That is a physical statement rather than a number
chosen to hit a rate, and it uses a constant the wall is already built from,
so a wider blocker funnels more without a second dial being invented.

Measured at that cut: about 7% of blocks, which sits between the stuff band's
10.2% and the touch band's 27.6% rather than swamping either.

## `const ATTACK_COMMITMENT_ERROR_SHIFT: float = 0.06`

*in `_was_funnelled`*

**How much a team's commitment moves the bar a swing has to clear.**

`decisiveness` reached the attack twice and neither touched error.
`_attack_effectiveness` scales quality by 0.85-1.15 but `attack_missed` reads
the *unmultiplied* figure, deliberately -- commitment prices what a ball does
after it lands in. That left `_identity_hit_type`, which substitutes a roll or
a tip on a ball a cautious side does not like, as the only path to error.

Measured over 200 rallies per identity with the resolver confirmed reading
`decisiveness = 0.18`, that substitution fired **0.0% of the time** while the
same function's committed branch converted 43 tempo swings into power swings.
Its trigger needs set quality under 0.48 and home first-ball set quality now
sits at 0.708, so the branch went out of reach by the offence improving rather
than by a bad constant.

A property that depends on how often a bad ball happens is a property that
disappears when a team gets good at not producing bad balls. So commitment
moves the bar continuously instead: a side that swings at everything asks more
of each swing than a side that picks its moments, whatever the ball was.

Sized against the curve it shifts rather than guessed. The response width is
0.12, so a full swing of the axis moves the threshold by half a width -- large
enough to separate two identities in a 48-sample directional check, small
enough that it cannot swamp execution, which is still what decides the shot.

**This is live only on the non-geometric fallback, and that is not enough.**
Three lines after the home call site, `attack_missed = bool(geometric
.attack_missed)` overwrites it whenever a geometric swing resolved -- which is
the ordinary path. So the shift below is computed and discarded on almost
every attack in the game, and the identity calibration came back **byte
identical** after it was added: 0.0843 against 0.0806, the same four decimals
as before.

Failure mode #1, walked into while fixing a dead branch. Recorded here rather
than quietly left, because the parameter is correct where it is reached and
the real repair is one level down: a geometric swing lands in or out from its
own course and speed, so commitment has to move something the resolver reads
-- the swing's aim tolerance or its speed -- rather than a threshold applied
afterwards. See `docs/BACKLOG.md`.

## `func _serve_error_chance(server: VolleyballPlayer, tactical_risk: float) -> float:`

*in `_attack_missed`*

How often this serve misses, given how much the server is asking of it.

Both serve sites carried their own sum of small offsets --
`0.025 + risk * 0.07 + aggression * 0.025 - consistency * 0.065 - style * 0.02`
and a near-twin -- and neither could reach the sport. The maximum either
expression could return was 0.12, at maximum aggression against a server with
zero consistency; a typical server produced 0.022. A rate that cannot enter
its own band is not a low rate, it is an absent mechanism, and serve
aggression was therefore free.

A serve misses when the server asks more of it than their control supports.
Demand comes from the tactical risk and the server's own aggression; control
is technique and consistency, normalised. Neither term is an offset, so the
rate spans the range instead of resting on its floor.

## `func _set_execution(`

*in `_serve_error_chance`*

One set, wherever in the rally and whichever side of the net.

There were two models. The home first ball summed 1.18 of un-normalised
weight -- 0.90 of ratings plus 0.28 of pass quality -- while the transition
set was a normalised capability times what the arriving ball allowed. A
typical home set scored about 0.75 and a typical opponent set about 0.48, and
since every opponent attack in the game was built off a transition set, that
0.27 gap was worth roughly 0.11 of attack quality: twice what a +15 hitter is
worth, handed to one side of the net for free. It produced 115 home kills
against 17.

`capability_penalty` carries what `SetterCapabilitySystem` charges for
attempting a tempo beyond command or reaching above the jump; it is zero for
a transition set, which has no play called on it to overreach.

## `func _execution_spread(`

*in `_usable_transition_ball`*

How widely a player's execution scatters around what they are capable of.

Every contact in the engine carried a flat spread -- the same +/-0.10 for a
world-class hitter and a replacement-level one -- so consistency was not an
attribute. That is why only the hitter registered in results: a +15 change one
contact upstream moves the ball it feeds by about 0.02, against a shared
+/-0.10 of noise on that contact and another fresh term on the next. Anything
more than one link from the terminal act was drowned before it could reach
the scoreboard.

Reliability is composure -- holding technique together under rally pressure --
plus the technical rating that governs the act itself. An elite player does
not merely average better; their bad contact is much closer to their good one,
which is what makes them felt through a chain rather than only at its end.

## `return _normal_from_uniform_halfwidth(spread)`

*in `_execution_error`*

Normal, not uniform on [-spread, spread].

A uniform draw has hard support boundaries, and every consumer of this
value is eventually compared against a threshold. So whenever a
contest's systematic margin sat further than `spread` from its
threshold, the outcome stopped being uncertain at all -- not unlikely,
impossible. The block contest showed it plainly: swept across generated
roster pairings, one pairing recorded zero stuff blocks in 127 contests
and another 84 in 144, because their mean margins sat 0.085 below and
0.102 above the same cutoff while blocker spread ran 0.04-0.13. There
was no gradient between them for a squad to move along, which is the
wrong shape for a game about incremental improvement.

Matched on standard deviation (a uniform's is its half-width over root
three), so ordinary contacts scatter exactly as much as before and only
the tails change. Clamped well outside the old bound purely to stop a
freak draw putting a set in the stands; at 3.5 deviations the residual
probability is about 2e-4, which is rare rather than forbidden.

## `const SET_DELIVERY_REFERENCE_METERS: float = 3.63`

*in `_normal_from_uniform_halfwidth`*

Where an own-side delivery lands, given where it was aimed and how well it
was executed.

This is the whole of the "positional promotion": no flight is simulated and
no boundary is tested, but the contact stops arriving at a table entry and
starts arriving at a point that depends on the player. That is what the next
contact's geometry needs -- a hitter's available angles depend on where the
set actually is, not on where the lane says it should be.

Normal rather than uniform, matching `_execution_error`. A uniform spread
would make "can this setter miss the pin" a hard threshold on quality instead
of a tail, which is the same defect that made block outcomes impossible
rather than unlikely.
How far a ball misses the point it was aimed at, and how much further a long
one misses.

**Scatter did not know how far the ball was going.** One standard deviation
from set quality, applied identically to a 1.5 m back-set and a 9 m ball to
the far pin. Measured over 1,216 sets before this: drift ran 0.26 m at 3-6 m
and 0.40 m beyond 6 m, and *0.34 m under 3 m* -- worse at short range than at
medium, which is backwards for anything thrown. What that non-monotonicity
actually shows is that distance was never an input; the buckets differ only
because short sets are attempted in worse situations.

An angular error is the shape that fixes it. A setter releases the ball a few
degrees off, and a few degrees is centimetres near the net and half a metre
across the court -- so the deviation grows with the throw rather than being
a fixed radius the whole offence lives inside.

The existing quality band stays and is now the *angular* term. The reference
distance is where the two agree, chosen as the measured median set so that
the population's middle is unchanged and only its tails move.

## `const DELIVERY_HEIGHT_REFERENCE_METERS: float = 1.10`

*in `_normal_from_uniform_halfwidth`*

How high the ball climbs before accuracy starts paying for it, in metres
above the release, and how fast it pays.

**A ball you put up is a ball you stop steering.** Distance was the only
thing scatter knew about, and height is the other half of the same geometry:
every extra metre of climb is more time in the air with nothing acting on the
ball but gravity and whatever the release got wrong, and the release error is
amplified over a longer arc rather than being carried straight to the target.

The reference is roughly a normal set's climb, so an ordinary ball pays
nothing and this describes the tail: the rescue set put up to buy a hitter
time, the high outside ball, the emergency bump that goes to the ceiling.
Those are exactly the balls that should be harder to place, and the reason
a team does not simply set everything high.

The slope is deliberately gentle. It is unmeasured -- nothing has published
accuracy against ball height, because until now nothing varied the height --
so this is a starting value, and `tools/pass_and_set_probe.tscn` prints the
distribution the tuning will need.

## `rise_above_release_meters: float = 0.0,`

*in `_delivered_point`*

**How far the ball climbs above the release**, not its absolute apex and
not only the rescue portion.

Named in full because the first cut got it wrong on one path of three:
home and transition passed `arc.apex_height_meters + rescue`, which is the
whole climb, and the opponent passed the rescue alone -- so an ordinary
opponent set had a rise of zero and paid no height penalty at all, while
an ordinary home set paid for its entire arc. One number, three callers,
two meanings, and the asymmetry ran the way this file's asymmetries always
run. `_set_arc` returns `apex_height_meters` already relative to the
release, which is what makes the sum correct and what made the omission
invisible.

## `func _defense_execution(`

*in `_delivered_point`*

One dig, wherever in the rally it happens.

The engine carried three of these too. Home defence summed 0.96 of weight
across four attributes, the opponent's summed 0.84 across two, and the
continuation summed 0.86 across three -- and all three were compared against
an attack quality on a fourth scale, with three different offsets. Once the
swing became a fraction of an ideal swing, none of them meant anything: a
defender composite near 0.61 against a typical swing of 0.42 dug almost
everything, and rallies stopped ending.

Same shape as the swing. Capability is what the defender brings, normalised.
Opportunity is what the rally gave them, as a product, because a defender who
did not get there has no technique to apply. `read_bonus` carries scouting,
responsibility fit and defensive-plan posture -- the things that tell a
defender where the ball is going before it goes there.
The dig, given how much reach the defender had left over.

The second parameter is *metres*, not seconds. It used to be called
`arrival_margin` and weighed against a constant called
`DIG_LATE_ARRIVAL_SECONDS`, and every production caller was already feeding it
`physical_reach - distance` from the coverage model -- so the model was not
wrong, its name was, which is worse in one specific way: it told anyone
reading it that a seconds value belonged here, and eventually something put
one in.

## `const READ_COMMIT_SHARE: float = 0.62`

*in `_defense_execution`*

The same dig, with its working shown.

Every attempt to explain why one side of the net digs better than the other
has so far been a guess at which term was responsible, and two of those
guesses were wrong -- the parallel implementation, then the timing term. A
composite that only ever reports its product cannot be asked which factor
moved, so it now reports the factors too and the question can be measured
instead of argued.
How badly this defender misreads where the ball is going, in metres.

**`BallReadSystem` was built for exactly this and wired to nothing live.**
Four shadow systems call it; the rally called it nowhere, so
`choose_claimant` was handed the ball's *true* landing point and every
defender in the game went to precisely the right spot. `anticipation` bought a
shorter reaction delay and a better claim score -- getting there sooner, and
being more likely to be the one who goes -- but never a *worse place to go*,
because there was no such thing.

The estimate's own terms are the ones the report asked for: reading ability,
familiarity with this ball, how much of the flight has been watched, and the
flight's novelty -- and novelty is `BallContactSignature.baseline_novelty()`,
which weights topspin at 0.17, sidespin at 0.18 and instability at 0.16. So a
float serve and a heavily spun ball are harder to track by construction rather
than by a special case, and a ball watched all the way from the far endline is
easier than a spike from four metres.

Returned as a *distance* rather than as a point, because that is what the
arrival terms need and because the direction of a read error is not something
any consumer downstream can act on: a defender who is 40 cm out is 40 cm out
whichever way. The point itself stays available on the estimate for playback
if it is ever wanted.
How far into a flight a defender commits to where they think it is going.

Not the whole of it: a defender who watched the ball all the way to the floor
would know exactly where it landed and have no time left to use the knowledge.
Rather more than half, because the last of the information arrives late and a
defender is still adjusting into the final step.

## `float(trajectory.get(`

*in `_read_error_meters`*

**The pace the ball actually left the contact at, when the record
knows it.**

`BallPresentation.launch_speed_mps` derives speed from the start
height, the *chosen endpoint* height and the duration, so a flight cut
short somewhere else comes back slower -- presentation deciding a
gameplay physical value, which §7 of the spec forbids and which this is
the one live instance of. Worse, every published trajectory carried
1.0 m at both ends, so its vertical term was exactly zero for every
ball in the game and the "speed" a defender read was pure horizontal.

The serve now publishes its own launch state and this reads it. The
other families still reconstruct, and will until each owns its launch
in turn; the fallback is what makes that a migration rather than a
rewrite.

## `var estimate: Resource = BallReadSystem.estimate(`

*in `_read_error_meters`*

**Measured from the flight's own clock, not the rally's.**

`observation_progress` is how much of the ball a defender has watched, and
passing `rally_clock` made that depend on where in the code the question
was asked: the home floor defence reaches its claim with the clock already
advanced into the swing, while the opponent's is still sitting at the set's
contact. Same model, same ball, two different amounts of information --
measured, the two sides' dig rates opened from a gap of 0.100 to 0.231 and
neither of the two wiring asymmetries I fixed first was the cause.

Anchored on the flight instead, every defender gets the same share of the
same ball, and the term means what it says.

## `func _read_adjusted_arrival(`

*in `_read_error_meters`*

The arrival a defender actually has, once they have gone to the wrong place.

`choose_claimant` answers against the true landing point, and that stays: the
call is a team decision -- somebody shouts "mine" -- and it is made on where
the ball is going, not on one player's private guess. What is individual is
*where that player then goes*, and the cost of being wrong is paid at the end
of the journey with no time left to fix it.

So the error is added to the distance rather than moving the target: the
defender covers what they meant to cover and is then short by their own read
error, which is exactly the quantity `reach_margin` measures and exactly what
the `reaching` posture is classified from. A defender with reach to spare
absorbs it and stays planted; one who was already at full stretch does not.

## `const DIG_COMFORT_SPAN: float = 0.40`

*in `_defense_terms`*

Whether this dig comes up, against the swing that was actually hit.

One contest, all three places a ball is dug. The attacker's advantage is
explicit rather than hidden in three different random offsets, so it can be
calibrated in one place and read in one place.
Whether the ball was dug, **and how well**, from the same number.

`_dig_contest` returned a bool and threw the margin away. Measured over 299
digs that made the contest a step function: the execution noise is +/-0.10
against a margin spanning 0.79, so two of every five digs were certain
failures, two were certain successes, and one band in the middle sat at 0.80.
Worse, the DEFENSE event recorded `defense_strength` -- the defender's own
terms -- as its quality, so a dig that survived by a hundredth and one that
was never in doubt were written down identically, and the setter behind them
received the same ball.

Which is the half the design was missing. A hit that clears the defence
outright is a kill and always was; a hit that *nearly* clears it should still
hurt -- the defender gets a platform on it and the ball goes somewhere,
rather than to their setter. That is what makes a powerful attack worth
making against a defence good enough to keep it up, and it is the whole of
"the margin multiplies its effectiveness".

`control` is graded from the threshold rather than from zero, so the span and
the bar cannot drift apart: whatever `DIG_ATTACKER_ADVANTAGE` becomes, a dig
sitting exactly on it is still a scramble and one `DIG_COMFORT_SPAN` above it
is still clean. The span is 0.40 because the measured margin runs -0.397 to
+0.476 between the tenth and ninetieth percentile, so it covers the half of
that range a surviving defender actually occupies.

## `const ATTACK_COMPROMISE_SET_QUALITY: float = 0.30`

*in `_best_home_server`*

How poor a set has to be before the hitter gives up the swing.

The rule lived on the opponent side only, at a threshold of 0.38 -- and measured,
opponent first-ball sets have a median of 0.344, so it fired on more than half of
their attacks. The opponent essentially never spiked: it rolled the ball over at
20-32 degrees instead of 5-14, while the home side swung at everything because it
had no such rule at all.

That one difference produced the whole dig asymmetry. Home defenders were digging
lobs with 0.739 s of flight and opponent defenders spikes with 0.490 s, and every
claim term downstream inherited exactly that gap while reaction delay and raw
speed came out identical on both sides. Three earlier passes read it as a
positioning problem.

Now shared, and set from the pooled distribution rather than one side's: roughly
the worst eighth of home sets and worst third of the opponent's, which keeps the
compromise a real event on both sides without either team abandoning the swing as
its default.

## `func _fallback_assignment(`

*in `_hit_type`*

The lane and tempo for a swing nobody called a play for.

The lane used to be decided by which half of the court the hitter happened to
stand in, which can only ever produce a pin -- and `_hit_type` reads
"Quick attack" off the *lane*, never off the tempo, so no amount of tempo
variation could have produced one. A middle assigned a pin is a middle
running a pin approach, which is not what a middle does and not what the
block has to solve.

The tempo 3 default is deliberate and stays: a set nobody called is a safe
high ball. What changes is that a quick is now a lane a middle can be given,
and a quick is a first-tempo ball by definition.

## `var natural := ("Front Quick" if left_side else "Right Quick") if is_middle \`

*in `_fallback_assignment`*

The lane a hitter *can* be set, rather than the one their rotation slot
implies.

This was `"Left Pin" if x <= 0.5 else "Right Pin"` -- a lookup on where the
chosen hitter happened to be standing, with no decision anywhere in it. Four
lanes were reachable in principle and two in practice: measured over 67 home
swings, Right Pin 0.821 and Front Quick 0.179, with Left Pin, Right Quick
and Pipe at zero. Lane and tempo were bound together on the same lookup, so
`_apply_identity_tempo` could only ever redistribute tempo *within* a lane
it had no say in -- which is why 55 of 55 Right Pin swings came out at tempo
3 and every attribute meant to create variety measured as inert.

A hitter gets their natural lane and one they can be moved to. The middle
runs the quick in front of the setter or slides behind it; a pin hitter can
be brought inside on a shoot. Both alternatives are quick balls, so both are
gated on the setter being able to deliver one -- which the setter has been
deciding in shadow all along.

## `func _distributed_choice(scored: Array[Dictionary]) -> VolleyballPlayer:`

*in `_fallback_assignment`*

One of these hitters, in proportion to how good an option they are.

An argmax was the wrong shape here and the measurements said so twice. The
scores this ranks are close together -- four front-row attackers land inside
about a tenth of each other -- so picking the maximum makes the offence a step
function of its own constants: moving `QUICK_OPTION_BONUS` from 0.14 to 0.06,
six hundredths, took Front Quick from 0.568 to 0.176 and Left Pin from 0.203
to 0.595. A distribution that flips on a constant that small is not measuring
the constant, it is measuring which side of a tie it fell.

`SET_SPREAD_STEP` was a deterministic stand-in for this and its own comment
called itself a placeholder. This replaces it. A setter distributes: the best
option gets the ball most often and everybody else gets it sometimes, which is
also the only thing that stops a block reading one rotation.

Sharpness rather than a flat share, so the gap between hitters still matters.
It consumes one draw, which re-sequences the rally -- an accepted cost, since
the alternative is an offence decided by rounding.

## `intended = _open_serve_point(`

*in `_serve_landing_point`*

Where the zone actually is, given who is standing in the way.

The four anchors above used to *be* the answer: a serve landed on one of
four fixed dots regardless of how the receiving side had lined up, while
reception resolved against a real seam formation with per-passer arrival
margins and body penalties. The receive was geometry at resolution and a
menu of four points at selection, and nothing made the two agree -- the
home serve did not even take the receivers as an argument, and was called
with an empty array.

The named zone still decides roughly where the ball goes. Within that, the
serve now finds the gap: a passer standing on Zone 5 makes Zone 5 a worse
place to serve than the seam beside it, which is the entire reason a
server looks at the other side before they toss.

## `func _open_serve_point(`

*in `_usable_serve_pace`*

The best point to serve near a requested zone, given where the passers are
*and* what this server can actually hit.

Three terms. How far the ball lands from the nearest passer and how far it
strays from the zone the bench asked for are both in metres, so they trade off
without a fudge factor. The third is the one that keeps this honest: the open
floor is only worth what the server can bank.

Without it this function is an argmax over openness, and openness is maximised
exactly where the ball is nearly out -- so it replaced four hardcoded dots
with one computed dot in the deep corner, chosen identically on every serve by
every server. That is worse than the menu it replaced, because at least the
menu's dots were inside the court on purpose.

`confidence` is the share of this server's own error distribution that still
lands in, times whether the ball carries that far at all. It is not a rule
that gates zones by attribute -- it is the arithmetic of a spread against a
line, and the gating falls out: a server whose placement scatters 1.5 m has
no business aiming 0.4 m off the sideline, so for them the corner scores as
the empty floor it is, and they take the anchor. A server who scatters 25 cm
gets to attack it. Nobody is told which; they are priced.

## `func _lineup_live_shape(lineup: RotationLineup, live: Dictionary) -> Dictionary:`

*in `_receive_formation_positions`*

Where every voli on the receiving side stands to take a serve, by player id.

**The formation was already being built and five sixths of it thrown away.**
`_receive_formation_positions` above asks `CourtConstants` for the whole
six-slot shape and then keeps only the passers, because all it needed was
somewhere to aim the serve. Everyone else's position was computed, discarded,
and then not drawn -- which is why serve receive publishes phase targets for
0 of 400 serves and a court of twelve stands still through the phase a viewer
watches most closely.

Nothing here is invented. It is the same call, kept whole.
The six on court, where they actually are.

Published on the reception event in place of a recomputed
`_receive_formation_map`. The shape is seeded into `live_positions` at rally
initialization now, so asking the formation builder again at reception time
would be computing a second copy of state that already exists -- and it would
be *wrong* for one voli, the receiver, who has since moved to the ball.

## `func _transition_phase_map(`

*in `_receive_formation_map`*

Where the four volis who are neither passing nor setting go while the pass is
in the air.

This is the leg the report was about: a shanked serve receive, and a court of
twelve standing still watching it. They stood still because playback refuses
to invent movement and the resolver had published an opinion about exactly two
people -- the passer, and whoever was taking the second ball.

Nothing here is new physics, and deliberately so. Each voli is given the
target their phase already implies: a front-row voli releases to the approach
mark `_approach_start_position` would put them on for the lane
`_fallback_assignment` says is theirs, a back-row voli goes to base. Then
`_reached_point` -- the same function that times every other journey in the
game, and the same one that charges for it -- decides how much of that they
actually cover in the time the pass is in the air. Most honest answers are
"not all of it", which is the information a viewer needs.

**The three people this must not touch are the three it already has an
authority for**, and forgetting one of them is measurable. The receiver and
the second contact are obvious. The hitter is not: their release to the
approach mark is already staged on the SET event, and moving them here as well
meant `ApproachMechanicsModel.prepare_for_attack` ran from a position the
approach had already been walked to. It halved the leg without halving the
time allotted for it, and the ATTACK phase's timing ratio went 1.0912 ->
1.2111 -- a phase the movement-timing gate asserts to two decimal places.

The chase is the one judgement call, and it is derived rather than authored.
`setter_arrival_margin` is the time the second contact has to spare; when that
is gone, the pass is one nobody planned for, and the nearest other voli breaks
for the ball. Whether they are *allowed* to play it is a separate question and
is not answered here -- see `docs/design/OFF_BALL_MOVEMENT.md`, "Not in scope".
What is answered is whether a shanked pass looks contested or conceded.

## `func _opponent_transition_phase_map(`

*in `_transition_phase_map`*

The same idea for the other side of the net, at the fidelity that side has.

**This is deliberately coarser than `_transition_phase_map` and the difference
is worth stating rather than hiding.** The home five are sent to approach
marks because the home offence has already named a lane and a tempo by the
time that map is written. Here the hitter is not chosen until eighty lines
below, so each opponent is sent to their own model's transition base --
`court_position(id, "transition")`, which is that team's own opinion about
where the player stands in transition and not a number invented here. It is a
smaller movement than the home side's and it is honest about being one.

The chase is the same, and is the half that matters: when the second contact
has no time to spare, the nearest other voli goes too.

## `func _cover_phase_map(`

*in `_opponent_transition_phase_map`*

Where the attacking side goes while their own spike is in the air.

**The intentions were already written down and never read.** Every
`DefensiveAssignment` carries an `attack_coverage_responsibility` -- one of
*cover nearest attacker*, *cover assigned hitter*, *take second contact* or
*release for transition* -- and until now the only thing that read it was
`_resolve_attack_coverage`, to pick the single voli who plays a recycled ball.
The other four had a stated intention and nowhere to stand.

So nothing is invented here either. Each voli goes where their own
responsibility means, and `_reached_point` decides how much of it they cover.
An attack flight is short -- often under a quarter of a second -- so most of
these answers are "barely moved", which is the correct picture: cover is a
collapse you commit to before the ball is struck, and a viewer should see who
committed and who released.

`release_for_transition` is the interesting one, and it is why this reads as
volleyball rather than as everyone converging: the voli the tactic told to
leave goes the *other* way, off the net, to be available to swing next.

## `static func _defensive_intents(`

*in `_cover_phase_map`*

How much of an intended journey a voli actually covered, 0 to 1.

The progress a cogniticon fills with, and it is deliberately *distance
covered* rather than any judgement about whether covering it was enough. A
voli who commits to a cover mark and gets a third of the way there fills a
third of their glyph; whether a third was sufficient is the rally's business
and not the icon's. See `PlayerCognitionCue.progress`.

A journey of no length is complete by definition -- a voli already standing on
their mark has nothing left to do, and reporting that as zero progress would
draw an empty glyph on the one voli who is entirely ready.
One intent for a whole published map, where the map is already one idea.

`_floor_phase_positions` places a defensive shape and the wall staging places
a wall -- neither has a per-voli branch to preserve, so they do not need the
`out_intents` treatment the travel maps got. They need saying out loud, which
is different and cheaper.

Progress is deliberately absent: these are placements rather than journeys,
and a progress bar on a voli who was simply put somewhere would be a number
with nothing behind it.
A defensive shape's intents: the journeys that were taken, over a `defending`
stamp for anyone the shape placed without one.

Two different facts wearing one name is what `_uniform_intents` was becoming
here. A voli walked into their zone has a traversal and an arrival; a voli the
wall staging put on the net does not, because a different path owns their
movement. Overlaying keeps both honest rather than averaging them into a
progress bar with nothing behind it.

## `const DEFLECTION_LEAN: float = 0.28`

*in `_uniform_intents`*

Where the side that just served goes while their own serve is in the air.

**They were going nowhere, because nothing published them.** The receive
formation covers the six receiving; the other six -- the team that struck the
ball -- had no phase map on this leg at all, so the half of the court that
just served stood still through the phase a viewer watches most closely.
Measured before this existed, a serve's flight moved 2.50 volis of twelve and
most of that was the passer adjusting.

What they do is not invented either: after a serve you take base defence, and
`_floor_phase_positions` is the side's own defensive shape. The attack
coordinate is centre because nobody has set yet -- the shape a team takes
before they know where the ball is going is exactly the neutral one -- and no
blocker is named for the same reason.

The server is included deliberately. They strike from behind the baseline and
have to walk in, and that walk is the single most visible piece of movement on
the leg.
The floor closing toward where the ball actually went.

**The one leg that published targets and moved nobody.** The defensive shape
is computed once, applied on the opponent's attack event, and then republished
verbatim on the block and on the dig -- so by the time the ball comes off the
block every defender is already standing on their target and the flight from
the block to the dig moved 0.00 metres across 329 legs. A phase map whose
positions are already occupied is a knob that cannot reach its own range.

A block touch changes where the ball is going, and the floor answers it. Not
by converging on the ball -- five defenders piling onto one dig is not
volleyball -- but by leaning toward the new line, which is what closing a seam
looks like. The lean is capped so the shape stays a shape.

The defender playing it is excluded; they already carry their own
`movement_target`, and moving them twice is the defect the hitter taught.

## `func _tool_pursuit_map(`

*in `_uniform_intents`*

The blocking side going after a ball that came off their own hands.

**A tool is not a ball nobody may touch.** Three geometric outcomes end at the
net in the hitter's favour -- through the hands, off the hands and out, and
placed off them deliberately -- and all three claimed the point before the
recycle branch could see them, so the defending six stood still while a ball
they had just touched dropped. That is wrong on the rules as well as on the
screen: the deflection is the *blocking* team's contact, they have two touches
left, and a ball is not out until it lands, so chasing it past the sideline is
an ordinary play rather than an impossible one.

What this publishes is the chase. Whether the chase can ever *save* the point
is a separate question with a separate cost -- a ball played from outside the
court arrives at a set and an attack whose geometry assumes an in-court
origin -- so this reports the arrival margin rather than acting on it, and the
conversion waits on a measurement of how often it would fire.

The blockers themselves are excluded. They are at the net with their hands
above it and the ball has gone behind them; the people who chase are the ones
already facing the right way.

## `func _travel_intent(`

*in `_travel_fraction`*

One off-ball journey, published with **when it ended** and not only where.

M7 / C6. Every phase map in this file published a destination and a fraction
covered, and nothing at all about time. So a voli who crossed two metres in
0.31 s of a 1.14 s window and then stood waiting was indistinguishable, in
everything downstream, from one who spent the whole window walking -- and
playback, given a start, an end and a window, draws the second. The C0 census
counted it: **0 of 8,125** placed volis carried a duration.

The resolver has always known the answer. `_reached_point` computes
`_movement_time` to decide whether the target is reachable at all, then throws
the number away and returns a position. Asking the same authority for the time
to where the voli *actually got* costs one more call and invents nothing: no
new speed, no new relation, no window-filling.

`traversal_seconds` is the journey. `window_seconds` is how long the ball gave
them. A voli with `traversal < window` arrived early and the remainder is
theirs to stand in, which is the physical fact C6 asks for -- stated here so
that anything drawing them has it, rather than left for presentation to
assume. `arrival_progress` is that ratio precomputed, because "did they arrive
early" is the question every consumer actually has and deriving it from two
fields is where an off-by-one lives.

A journey that was cut short comes back with `traversal == window`, by
construction: `_reached_point` bisects to exactly the point the window buys,
so the time to that point is the window. That is correct and not a special
case -- a voli who ran out of time did not arrive early.

## `func _set_launch_angle_degrees(`

*in `_serve_style_proficiency`*

Intended shot shape for a set, by tempo. `tempo` is already the real
tactical input (chosen by the called offensive play, not hardcoded); this
only changes what a tempo *means physically*, from a table lookup to a
shape that a real distance is then flown at.

**Kept, and no longer the input to the set's flight.** A launch angle is the
wrong free variable for a set and it took a physical solve to see why. A set
has to *rise* about a metre from the setter's hands into the hitter's, and at
the shallow angles this table calls a quick -- six to ten degrees -- the only
ball that climbs a metre over four metres of court is one hit at 26 m/s. The
solver said so, honestly, and the drawn quick came out at 0.16 s. A coach does
not describe a set by its launch angle in any case; they describe it by how
high it goes, which is what `_set_apex_meters` below now supplies.

This still feeds `path_length_factor` and the signature the reception carries,
which want an angle and are unaffected by the change.

## `const SET_CLEARANCE_BY_TEMPO: Array[float] = [0.15, 0.60, 1.30, 2.20]`

*in `_set_launch_angle_degrees`*

How high a set goes above the hands that will hit it, by tempo.

The set's real free variable, and the one every coach and every player already
uses: a first-tempo quick is delivered flat to a hitter already in the air, a
high ball climbs two metres above them to buy the outside every fraction of a
second it can. Everything else about the flight -- its speed, its hang time,
the window the hitter runs in -- falls out of this and the two contact heights,
through `BallFlightModel.duration_for_apex`.

Stated as clearance *above the hitter's contact* rather than as an absolute
height, because that is the quantity that stays meaningful when the hitter
changes. A 1.72 m setter feeding a 2.06 m opposite and the same setter feeding
a 1.85 m libero on an overpass are putting the ball in very different places
above the floor and the same place above the hands.

## `const SET_RISING_ANGLE_MARGIN_BY_TEMPO: Array[float] = [8.0, 18.0]`

*in `_set_launch_angle_degrees`*

**A fast set is struck before its apex, and the model could not say so.**

`duration_for_apex` clamps the apex to at or above both ends, so every set was
timed as rise-to-apex plus fall-to-hands: the ball always arrived on the way
*down*. That put a floor under every set of the time it takes to climb from
the setter's hands to the hitter's -- 0.429 s between 2.10 m and 3.00 m -- and
tempo could only add to it. A first tempo was structurally unable to be fast,
which is what a first tempo is for.

The same arc read the other way costs nothing to compute and answers
correctly: the ball that peaks at 3.15 m crosses 3.00 m at 0.288 s going up
and 0.638 s coming down, and the model was taking the second number.

Clearance cannot express the first one, though, and that is why this is an
angle. A higher apex launches faster and therefore crosses the hitter's height
*sooner*, so parameterising a rising contact by clearance inverts the tempo
order -- tempo 1 would arrive before tempo 0. What separates a quick from a
second-tempo ball on the rise is how much steeper than the straight line to
the hands the setter pushes it: flatter is faster.

Stated as a margin above that straight line rather than as an absolute angle
for the same reason clearance is stated above the hands rather than above the
floor -- the geometry moves. A 6-degree launch is a quick over five metres to
a pin and cannot reach a middle standing a metre and a half away at all, and
the tempo table this replaces for these two rows was cut for the first case
and applied to the second.

## `const JUMP_SET_LOAD_SECONDS: float = 0.34`

*in `_set_apex_meters`*

The flight of a set, timed by how high it was put up.

Behind `ENABLE_SET_HEIGHT_TIMING`, which is now on after the approach and
floor-defense calibration recorded beside the flag. Real hang times are about
triple the legacy launch-angle times, so this must not be toggled independently
of the timing and balance gates named there.
The ball has to be up there, and you have to have got there in time.

Every set in this game was a standing set. `set_contact_height_meters` takes
a `jumping` flag, `JUMP_SET_EFFORT` prices the hop, `SetterCapability` prices
the penalty and `shadow_setter_response_system` lists `jump_set` as an
option -- and the live path called the function with the default and never
asked. That made the pass apex inert too: contact was
`min(pass_apex, standing_reach * 0.97)` and the reach was always the smaller,
so a 3.16 m pass and a 2.42 m pass were played from exactly the same height.
Measured over 1,052 passes, apex ran 2.42-3.31 m and *every* one of them was
truncated to the setter's standing hands.

Three conditions, and the point is that they can each fail alone:

- **The ball got high enough.** You cannot jump to meet a ball that never
rose to where you would be. A pass below the standing release is played
underhand and this is what says so.
- **There was time to load.** Measured, the budget between the pass being
played and the ball leaving the hands runs p05 1.12 s to p95 2.64 s about a
1.67 s median -- so a rushed setter is common rather than exotic, and the
hop is the first thing they lose.
- **The body can do it under pressure.** Balance and stability, not leap:
a setter jumping is not trying to get high, they are trying to arrive
square and release from a moving platform.

## `const JUMP_SET_PACE_BONUS: float = 0.12`

*in `_jump_set_decision`*

What a set's pace comes from, as a multiple of the baseline.

Two halves, and the geometric one is already free: `_set_arc` solves the
flight from the release height, so a higher contact flattens the parabola to
the same destination without anything here asking it to. What is missing is
the kinetic half -- the jump puts the body's momentum into the ball, and a
setter who stays on the floor has to find the same pace out of the arm alone.

So a standing set is not merely lower, it is *slower unless the arm is
strong*. `arm_speed` is the nearest thing this engine has to arm strength and
it is already generated, rated and trained; adding an eighth attribute for
the one contact that needs it would be a worse answer than reading the one
that already means "how hard this body can move a ball with the arm".

Centred so an ordinary arm standing is 1.0 and the jump is the bonus, rather
than penalising every standing set and calling the jump neutral.

## `"release_height_meters": release_height_meters,`

*in `_set_arc`*

**Where this ball starts and where it arrives, in absolute metres.**

`duration_for_apex` is solved *between* these two and then neither left
the function, so every set published a trajectory carrying
`BallTrajectory`'s 1.0 m default at both ends -- measured at 159 of 159
set flights, `height_source == "default"`. The set is the seam where
the chain breaks: it consumes a reception flight whose heights are
resolved and hands the attack one that has forgotten them, so every
family downstream reads a body proxy for want of a number that was in
scope here all along. See
`docs/review/contact_authority/BEFORE_contact_authority_census.txt`.

Not a second opinion about where the ball goes: the duration above is
the time to fall from `apex` to `arrival_height_meters`, so a flight
drawn to any other far end disagrees with its own length.
