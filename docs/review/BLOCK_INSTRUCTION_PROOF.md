# The block-hands call: the first end-to-end tactical proof

Run: 2026-08-16, from `2bc58e9`. Instrument:
`tools/run_block_instruction_probe.gd`. **Production behaviour changed** —
though not, on the shipped save, by anything a scoreboard can see. §5 says why
that is the right result rather than a disappointing one.

The chain this proves:

```text
MANAGER CALL           TacticSheet, "3:Block" -> "soft block"
→ RECOGNITION          decision_making + composure: am I beaten?
→ PERSONAL RESPONSE    aggression: do I go anyway?
→ ADHERENCE            tactical_discipline: does the call win the disagreement?
→ ATTEMPTED ACTION     soft hands or kill hands
→ FEASIBILITY          the contest, untouched by any of the above
```

---

## 1. The plumbing that was missing, and what it actually was

The `STOP` condition was whether the instruction is reachable without inventing a
tactical call. **It is**, and nothing was invented — but three separate links were
absent and the third is the one that made this look bigger than it was.

| link | before | needed |
|---|---|---|
| `TacticSheet` → simulator | `resolve()`'s own comment: *"the resolver deliberately never sees the `VolleyballTeam` it is resolving for"* | one field, handed in beside `pair_familiarity` |
| blocker → slot | — | `lineup.slot_for_player()`, already existed |
| slot → behaviour | — | `TacticSheet.behaviour_of(slot, "Block")`, already existed |
| formation → decision | `formation.get("hands_instruction", "")` | nothing wrote the key |

`game_manager.gd` already assigns team-derived state onto the simulator three
lines above the `resolve()` call, with a comment saying that is the pattern —
*"Handed in before the resolve, not looked up inside it."* The sheet follows it
exactly, so the resolver still never sees the `Team`, only a `Resource`, which is
the same boundary `defensive_plan` and `team_principles` already respect.

**Only the two hands behaviours map.** `close line` and `close cross` live on the
same clipboard page and say nothing about the hands; reading them as a hands call
would be inventing a call the manager did not make.

**Home only.** The sheet is the manager's own club's, so the opponent has no
hands call and gets none. That asymmetry is honest rather than an omission, and
inventing an opponent call is exactly what the brief forbids.

---

## 2. Before

### 2a. The decision, driven directly

`_block_hands_intent` with a synthetic blocker, fixed contest, 600 seeds per cell.

```
call         disc   soft     kill
(none)       10     1.0000   0.0000
(none)       50     1.0000   0.0000
(none)       90     1.0000   0.0000
soft block   10     1.0000   0.0000
soft block   50     1.0000   0.0000
soft block   90     1.0000   0.0000
kill block   10     0.0000   1.0000
kill block   50     0.0000   1.0000
kill block   90     0.0000   1.0000
```

**Flat in every row.** The call was an unmediated `match … return`, so every
blocker obeyed identically, and `tactical_discipline` did nothing anywhere.

### 2b. In situ, 800 isolated rallies

| | |
|---|---|
| blocks | 758 |
| soft / kill / neutral | 52 / 706 / 0 |
| **blocks carrying a hands call** | **0** |

Zero, as the §13.2 audit predicted from reading the code. The instruction was
reachable in principle and unreachable in fact.

---

## 3. The change

```gdscript
## before -- the call replaces the voli
match instruction:
    "soft block": return "soft"
    "kill block": return "kill"

## after -- the call is something the voli adheres to
var own := "kill" if deficit <= 0.0 \
    else ("soft" if AttemptJudgment.backs_off(blocker, deficit) else "kill")
if call.is_empty() or call == own:
    return {"hands": own, …}
var follows := _identity_roll("block-hands|%d" % blocker.id) \
    < _rating(blocker, "tactical_discipline")
return {"hands": call if follows else own, …}
```

Four properties, each of which the brief required and one of which is the whole
point:

1. **Recognition is untouched.** `AttemptJudgment` was not reopened; discipline
   is not back in self-assessment.
2. **Discipline acts only on a disagreement.** If the voli was going to do what
   was asked, adherence has nothing to resolve and does nothing.
3. **The sign comes from the call.** The branch returns `call`, so the same
   attribute pushes toward soft under a soft call and toward kill under a kill
   call. This is what makes it adherence rather than a second temperament.
4. **No new RNG.** `_identity_roll` is the existing repeatable per-rally channel
   the identity calls already use, so nothing downstream reseeds.

`_block_hands_intent` now returns `{hands, call, followed}` instead of a bare
string, and the block event publishes `block_hands_call` and
`block_hands_followed`. An instruction nobody can see obeyed or ignored is not an
instruction.

---

## 4. After — the gate, and it is bidirectional

Two fixtures, because one cannot test both directions. **The first version of
this probe used one**, whose own verdict was `soft` at every discipline — so a
soft call agreed with the voli and the soft direction was untestable by
construction. That flaw would have let a one-way attribute pass.

**`beaten`** — losing the contest, still closing. Own read: **soft**.

| call | disc | soft | kill | followed |
|---|---:|---:|---:|---:|
| (none) | 10 / 50 / 90 | 1.0000 | 0.0000 | — |
| soft block | 10 / 50 / 90 | 1.0000 | 0.0000 | 1.0000 |
| **kill block** | 10 | 0.9083 | **0.0917** | 0.0917 |
| | 50 | 0.5000 | **0.5000** | 0.5000 |
| | 90 | 0.1083 | **0.8917** | 0.8917 |

**`winning`** — on the ball, positive margin. Own read: **kill**.

| call | disc | soft | kill | followed |
|---|---:|---:|---:|---:|
| (none) | 10 / 50 / 90 | 0.0000 | 1.0000 | — |
| **soft block** | 10 | **0.0917** | 0.9083 | 0.0917 |
| | 50 | **0.5000** | 0.5000 | 0.5000 |
| | 90 | **0.8917** | 0.1083 | 0.8917 |
| kill block | 10 / 50 / 90 | 0.0000 | 1.0000 | 1.0000 |

> **Kill attempts rise with discipline under a kill call; soft attempts rise with
> discipline under a soft call.** Same attribute, opposite directions, and the
> direction is a property of the instruction rather than of the voli. The gate
> passes.

Three controls, all flat as required:

- **no call**: identical at every discipline, in both fixtures. Discipline does
  nothing when nobody asked;
- **call agrees with the read**: flat at 1.0. Nothing to adhere against;
- **feasibility**: `_block_hands_intent` receives the contest margin and close
  fraction and returns a choice about hands. It writes to neither, and a gate
  asserts they come back unchanged.

The follow rate tracks discipline almost exactly (0.0917 / 0.5000 / 0.8917 for
10 / 50 / 90) because `_identity_roll` is a uniform hash. That is the intended
reading of the attribute: **discipline is the probability the call survives your
own opinion.**

---

## 5. In situ: nothing moved, and that is the correct result

| | before | after |
|---|---:|---:|
| blocks | 758 | 758 |
| soft / kill | 52 / 706 | 52 / 706 |
| home soft rate | 0.0817 | 0.0817 |
| opponent soft rate | 0.0563 | 0.0563 |
| blocks with a hands call | 0 | 0 |
| home points | 410 / 800 | 410 / 800 |
| every outcome category | — | **identical** |

**The vertical slice ships no drawn tactic sheet**, so no blocker is told
anything and the adherence branch is never entered. The mechanism is live and the
default save is unchanged, byte for byte.

That is the ideal shape for a first tactical wiring: **zero regression risk, and
the behaviour appears exactly when a manager writes an instruction and not
before.** It is also why Part B alone would prove nothing about the wiring — it
would look identical whether the sheet reached the simulator or not, which is the
state the code was already in. The end-to-end gate in §6 is what closes that.

---

## 6. Tests

`_test_block_hands_instruction_adherence`, five checks:

1. a soft call reaches disciplined blockers more often (soft direction);
2. a kill call reaches disciplined blockers more often (kill direction);
3. discipline changes nothing when no call was made;
4. the decision leaves the contest margin and close fraction it was handed alone;
5. **end to end** — a behaviour written on a real `TacticSheet` at `"3:Block"`
   arrives at the blocker standing in slot 3, and a simulator with no sheet
   returns empty.

Check 5 is the one that matters most and the one Part B cannot supply. Without
it, every other check would still pass on a simulator that never received a
sheet.

---

## 7. Remaining concerns

1. **The opponent has no hands call**, by design. When opponent tactics exist
   they will need their own source; they must not borrow the manager's sheet.
2. **Only the primary blocker is instructed.** The assist gets no hands call, and
   whether it should is a block-design question rather than a wiring one.
3. **`ContactEnvelopeSystem.action_balance` still reads `tactical_discipline`**
   as a component of physical block balance. Untouched here on instruction; it
   remains the outstanding misuse and it is now the *only* one, since this pass
   gave discipline its first legitimate rally use.
4. **The clipboard writes `"3:Block"` by slot, and slot is rotational.** A voli
   who rotates out of slot 3 stops receiving the instruction, which is correct
   for a positional plan and worth knowing before anyone reads a follow rate
   across a match.
5. **Nothing in the game writes a sheet during normal play** except the training
   clipboard. Until a manager opens it, this pass is inert by construction.

---

## Re-running

```bash
godot --headless --path . --script res://tools/run_block_instruction_probe.gd
```

Part A is exact and should reproduce byte-for-byte. Part B is one fixture with an
empty clipboard; treat its rates as a regression check, never a target.
