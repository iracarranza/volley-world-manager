# P3-C2 — Debugging, Testing, and Git

Status: **VERIFIED**
Keywords: fixed seed, determinism, test runner, balance probe, parser scan, git diff, regression, concurrent edits
Primary sources: `tests/test_runner.gd`; `tools/run_rally_balance_probe.gd`; [VALIDATION.md](../VALIDATION.md)

## Prerequisites

- [P3-C1 Safe Change Workflow](01_safe_change_workflow.md) — the loop these tools serve
- [P1-C4 §4](../part_01_project/04_following_a_user_action.md) — what a seed buys

## Learning goals

After this chapter you should be able to:

1. turn a vague symptom into a reproducible report;
2. use a fixed seed correctly, and know when a seed difference is *not* a bug;
3. pick the right testing layer for a question;
4. read the balance probe and say whether a population moved;
5. use git to protect work that is not yours.

## Vocabulary

| Term | Meaning |
|---|---|
| **Symptom** | What was observed. Not a diagnosis. |
| **Reproduction** | Seed plus inputs that reliably produce the symptom. |
| **Invariant** | Something that must be true of every run. |
| **Incidental value** | A number that may legitimately change between runs. |
| **Balance probe** | A sweep reporting rally-population rates against real-sport targets. |
| **Regression test** | A check that fails for the original defect and passes after the fix. |

---

## 1. Debugging from evidence

### 1.1 Turning a symptom into a report

Capture the exact symptom, seed, event sequence, actor IDs, positions, ball
trajectory and expected behaviour.

> "Movement looks wrong after ten seconds" becomes actionable when paired with
> **the first event where position continuity breaks**.

### 1.2 Find the first wrong frame, not the worst one

The most visible moment is almost never the origin. A ball visibly in the wrong
place at `t=10` usually diverged at `t=3` by a few centimetres. Search backwards
for the **first** disagreement, not the largest.

### 1.3 Diagnose the side before the cause

Use the symptom table in
[P1-C4 §3.1](../part_01_project/04_following_a_user_action.md). Establishing
"this is a playback problem" eliminates most of the codebase before you read a
line.

---

## 2. Determinism and fixed seeds

### 2.1 Using one seed

The simulator seeds its random generator. Reuse one seed while investigating so
that changes in output are caused by **code**, not by a different random
sequence.

### 2.2 When a seed difference is not a bug

Same seed, different result is a bug **only if the resolver did not change**. A
change to how a contact resolves *will* produce a different rally from the same
seed, and that is how the probes detect movement at all.

Check your tree before hunting for hidden state.

### 2.3 What a deterministic test should assert

Compare **meaningful invariants** rather than every incidental number. A test
asserting an exact float from a physics chain will fail on any legitimate
retune, and will be deleted by whoever is next in a hurry — which loses the
coverage entirely.

| Assert | Do not assert |
|---|---|
| The ball crossed the net | Its apex was `2.4413` |
| A dig occurred | The dig's exact quality |
| Two blockers did not occupy one space | Their precise separation |
| Contact count is 3 | The contact times |

---

## 3. Testing layers

### 3.1 The five kinds

- **unit-like checks** — one model or calculation;
- **contract checks** — producer output matches consumer expectations;
- **integration checks** — a real entry point reaches the intended system;
- **parser / resource scan** — all scripts and paths load;
- **manual playback** — timing and readability feel correct.

### 3.2 The division of labour

Automated tests cannot decide whether a rally looks natural. Manual viewing
cannot reliably prove edge cases or deterministic behaviour. **Use both**; see
[P3-C1 §3.2](01_safe_change_workflow.md).

### 3.3 The slowest gate, and why it exists

`_test_world_aging` runs twenty seasons of the world and counts what survives.
It is the only check that will notice a generation change leaking talent, and it
has caught a one-line ceiling bug that a thousand other checks did not.

**Know it exists before changing anything in `player_generator.gd`.**

---

## 4. The balance probe

### 4.1 What it is for

```bash
godot --headless --path . --script res://tools/run_rally_balance_probe.gd
```

Its own header states the problem it solves:

> "every attempt to fix it has been measured with a different private probe, so
> no two attempts have been comparable. This is one reading with every number
> that decides whether the fit is done."

**One instrument, so two attempts can be compared.** Resist the urge to write a
private probe for your change; add to this one instead.

### 4.2 Reading it

It reports rates the sport has real values for — kill, dig, stuff, serve error,
ace, reception quality, block touch, contacts per rally. Some bands are
**gated** (a failure is a failure) and some are **advisory** (an observation to
watch).

### 4.3 Byte-identical is a result

If a change should not move the rally, run the probe before and after and expect
**identical** output. `CLAUDE.md` records several passes verified exactly this
way — a movement-contract pass whose nineteen figures were byte-identical across
twenty-four commits.

> **This is the strongest evidence available for a refactor.** "I did not change
> behaviour" is a claim; identical probe output is a measurement.

---

## 5. Git as a safety tool

### 5.1 Before and after

Before editing:

```bash
git status --short
```

After editing:

```bash
git diff --check      # whitespace errors
git diff --stat       # scope: is this the size you expected?
git diff -- path/to/file.gd
```

`--stat` is the important one. **If the scope surprises you, stop** — that is
stop condition 5.1 from the previous chapter.

### 5.2 Do not discard work you did not create

> Do not discard modifications merely because you did not create them in the
> current session. **They may be unfinished user work.**

This is a real hazard here, not a hypothetical: this repository is worked on by
several sessions at once. Symptoms you may meet:

- files modified that you did not touch;
- conflict markers appearing with **no** merge or rebase in progress
  (`git status` shows nothing in flight);
- markers labelled `ours` / `theirs` rather than git's usual `HEAD` / branch —
  the signature of `git merge-file` rather than a normal merge;
- the remote moving between your fetch and your push.

### 5.3 What to do about it

1. **Back up the affected files** before touching anything.
2. **Resolve only what is yours.** If both sides of a conflict are someone
   else's work, leave it and say so.
3. **Check whether the incoming side is stale** — it may be an older copy of
   your own file.
4. **Stage explicitly**, never `git add -A`, and confirm no markers are staged:
   ```bash
   git diff --cached | grep -c '^+<<<<<<<'
   ```

### 5.4 Before pushing

```bash
git fetch origin <branch>
git merge-base --is-ancestor origin/<branch> HEAD && echo "fast-forward"
```

A branch that moved under you needs integrating, not forcing.

---

## 6. A good regression test

### 6.1 The four properties

A good regression test:

1. **fails for the original defect** — verify this by running it before the fix;
2. **passes after the fix**;
3. **uses the smallest stable setup**;
4. **explains the gameplay contract through its assertions**.

### 6.2 Property 1 is the one people skip

A test written after the fix, never seen to fail, may assert nothing at all. The
face-parts case in
[P2-C3 §1.3](../part_02_gdscript/03_collections_types_and_null.md) is exactly
this: an assertion that looked correct, passed, and had silently retargeted onto
a different feature.

**If you did not watch it fail, you do not know it tests anything.**

### 6.3 Property 4, in practice

```gdscript
_check(
	(lighter + 0.05) / (darker + 0.05) >= 1.6,
	"%s's kit separates from the court floor" % region_name,
)
```

The message names the **contract** — a kit separates from the floor — not the
mechanism. When it fails, the reader learns what is wrong with the game, not
what is wrong with the arithmetic.

---

## 7. Common mistakes

| Mistake | Consequence |
|---|---|
| Debugging from the most visible moment | You investigate a symptom, not an origin |
| Asserting an exact float | Fails on any legitimate retune; gets deleted |
| Writing a private probe | Your result is not comparable with anyone's |
| Never watching a test fail | It may assert nothing |
| `git add -A` in a shared tree | You commit someone else's half-finished work |
| Forcing a push over a moved remote | You discard whatever moved it |

---

## 8. Check yourself

1. The ball is visibly wrong at `t=10`. Where do you look? *(For the first frame of disagreement, likely much earlier.)*
2. Same seed, different rally, and you edited the resolver. Bug? *(No.)*
3. You refactor and want to prove nothing moved. What is the strongest evidence? *(Byte-identical balance probe output, before and after.)*
4. You find conflict markers and no merge in progress. First action? *(Back up the files; determine which side is yours; do not resolve another author's.)*
5. Why must a regression test be seen to fail first? *(Otherwise it may assert nothing — as a passing, silently retargeted assertion once did.)*

---

## Where this leads

- [P4-C5 Migration and Visible Proof](../part_04_match_engine/05_migration_and_visible_proof.md) — shadow systems as a testing strategy
- [P7-C5 Rendering, Probes and Validation](../part_07_art_and_assets/05_rendering_probes_and_validation.md) — the same discipline for things you can only check by looking
- [VALIDATION.md](../VALIDATION.md) — the command reference
