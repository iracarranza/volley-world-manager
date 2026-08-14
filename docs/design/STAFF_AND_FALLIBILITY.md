# Staff, and being wrong

Why a bad chef is not a good chef with a smaller number attached.

Status: **the reliability model exists for one role and the failure model exists
for none.** `PasteRatio.drift_for(chef_rating, familiarity)` and
`StaffFamiliarity` are built and are already the right shape. Nothing yet fails
in a way a manager would call a mistake.

---

## 0. The rule

> **Skill should affect correctness, not only magnitude.**

Do not model:

```
3★ scout → good result
1★ scout → the same result, slower and smaller
```

Model:

| | |
|---|---|
| **high** | usually correct, precise, anticipates problems, occasionally catches the manager's mistake |
| **medium** | usually correct, less precise, needs direction, occasional errors |
| **low** | uncertain, misunderstands instructions, executes the wrong thing, fails in kinds rather than in degrees |

A weak staff member is not a weak multiplier. They are somebody who might go to
the wrong hall.

---

## 1. What already exists, and why it is nearly right

`PasteRatio.drift_for(chef_rating, familiarity)` is **literally skill ×
familiarity**:

> Rating and familiarity both pull it down, and neither alone reaches the floor:
> a brilliant chef who has never met a paste still fumbles the proportions, and a
> chef who knows it inside out is still only as steady as they are.

And `StaffFamiliarity` already gives per-subject learning with a weekly gain and
a decay, which is the whole of §4 below, built.

What is missing is that drift is a **magnitude** — the mix wobbles — and §0 says
magnitude is the wrong currency. The mechanism is there; the failure *kinds* are
not.

---

## 2. The constraint any failure model must respect

`PasteRatio.approximated` is deterministic in the week **on purpose**:

> Deterministic in the week, so the food screen and the chef's own report never
> disagree about what was served — and so a manager who reloads a save is not
> rerolling their dinner.

So a chef forgetting an allergy cannot be a roll at the moment the week ticks
over. It has to be a **derived fact about the week** — same rule as everything
else in this world, and the same rule the clock will have to obey
(`THE_DAY_AND_THE_CLOCK.md` §3.1). Otherwise the failure is save-scummable and
the two reports that must agree can disagree.

Key shape: `(week, staff_id, task, subject)`.

---

## 3. Failure is task-specific

Generic incompetence is a number again. Each role fails in its own vocabulary.

**Scout**
Goes to the wrong match. Watches a similarly-named voli. Files the report under
the wrong person. Misreads the role. Drops one of the criteria they were given.
Spends a trip on somebody unavailable. Draws a confident conclusion from thin
evidence.

> *"Find me an explosive libero who'd be interested in living here."*
> A poor scout fixes on raw speed, never asks about interest, and comes back
> with three-quarters of a report.

**Coach**
Drills yesterday's tactic. Forgets which one they were told. Misreads a
responsibility assignment. Spends the session on one component. Gives
contradictory instruction. Fails to notice bad reps. Prepares for the
opponent's *old* system.

**Chef**
Wrong ratio. Runs out. Substitutes a paste without asking. Forgets an
accommodation. Serves the special meal to the wrong voli. Cross-contaminates.

**Physio / care**
Wrong workload. Forgets an arrangement. Mixes up a schedule. Too cautious. Too
optimistic. Notices too late.

---

## 4. Failure scales with the task, not with a die

This is what keeps incompetence from being slapstick.

```
STAFF SKILL × TASK FAMILIARITY × TASK COMPLEXITY × WORKLOAD × FATIGUE
    → EXECUTION RELIABILITY
```

A poor chef can manage *everybody eats the normal mixture*. The task gets hard
when there are several separate meals, an allergy, multiple ratios to hold, an
overloaded kitchen, poor equipment, tired staff.

A weak scout can answer *find me somebody you think is exceptional*. They will
struggle with *find an affordable B-tier setter with these traits who is
comfortable with our housing and willing to move*.

**And they get better at the specific thing.** A mediocre chef who prepares the
same allergy-safe meal every week for a season should become very unlikely to
contaminate it — without their overall rating moving at all. `StaffFamiliarity`
already does this per subject; failure should read the same table.

Severity should be plausible. A weak chef does not routinely poison the squad. A
weak scout does not fly to the wrong country every week. Errors come from a hard
task, an unfamiliar one, overload, fatigue, ambiguity or poor organisation, and
range from harmless to consequential.

---

## 5. Failure is how the manager learns the organisation is people

The presentation matters as much as the model. Not:

```
SCOUT FAILURE EVENT      [ Resolve ]
```

but the answering machine:

> *"Boss? Call me when you get this. I think I may have gone to the wrong hall."*

and then a conversation. Likewise *"Don't panic, but can you call me?"* from the
kitchen, and *"I think we may have drilled the wrong rotation"* from the
assistant.

The phone is the interface through which a club stops being a set of modifiers
and becomes a collection of fallible people. See `THE_DESK_AND_THE_PHONE.md`.

---

## 6. This is what makes staff worth money

Without failure, staff quality is a percentage and hiring is arithmetic. With
it, **good staff buy back the manager's time** — the actual scarce resource
(`THE_DAY_AND_THE_CLOCK.md` §7).

> Strong assistant: *I can leave training alone.*
> Weak assistant: *last time I left, they drilled the wrong rotation for three
> hours.*

And a wealthy club should not have no problems — it should have staff, housing,
equipment and organisational familiarity that make **complex situations
manageable**. The problems do not vanish; they become handleable.

---

## 7. Recruitment promises become operational requirements

This is where staff and recruitment meet, and it is the best argument for both.

> Recruit: *"I can't eat Pāwan food."*
> Manager: *"We can accommodate that."*

The interview succeeds. The promise now depends on the club actually doing it
every week: separate food, the right utensils, no contamination, and remembering.
A good chef handles it routinely; a poor one, an overloaded kitchen, a
complicated rotation or bad equipment might not.

That is worth far more than `ALLERGY_ACCOMMODATED = TRUE`. **A recruitment
promise creates a simulation responsibility**, and the club can fail it.

See `ACCOMMODATIONS_AND_CARE.md` §2 for the three-data allergy split this sits
on — and note that the *voli's* belief and the *club's* belief are separate
data, so a chef can also be accommodating something that was never real.

---

## 8. The dependency underneath all of it

**Beliefs have no owner.** `scout_rating(staff)` returns the best scout you
employ and estimates salt by `(player_id, attribute_key)` only. The club holds
exactly one belief per voli, and two scouts cannot disagree.

Until that changes, *"scouted the wrong Kovarik"* is unrepresentable — there is
no per-scout belief for the wrong one to live in. It is item 3 in `SCOUTING.md`'s
own build order, and everything in §3 above rides on it.

(Worth noting: volis only acquired surnames recently, so two similarly-named
people are possible at all for the first time.)

---

## 9. Order

*Within this system.* Staff failure is **held** under `docs/BACKLOG.md`'s focus
hierarchy. This is the order for whenever it is picked up, not a claim about
what to build next.

1. **Beliefs with an owner** — `SCOUTING.md` #3. Unblocks scout failure, two
   reports side by side, and the club-belief third of the allergy split.
2. **Chef failure as a kind**, derived from `(week, staff_id, task, subject)`,
   reading `StaffFamiliarity` for the per-task learning that already exists.
3. **The phone as the delivery channel** — answering machine first, then
   outgoing calls, which is where the conversation happens.
4. Coach and physio failure, once the day model can charge for a session.
