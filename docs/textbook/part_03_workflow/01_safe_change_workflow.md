# P3-C1 — Safe Change Workflow

Status: **VERIFIED** project workflow guidance
Keywords: scope, trace, contract, vertical slice, validation, measurement, predecessor, stop condition
Primary sources: [VALIDATION.md](../VALIDATION.md); `tests/test_runner.gd`; `CLAUDE.md`; `docs/FAILURE_MODES.md`

## Prerequisites

- [P1-C4 Following a User Action](../part_01_project/04_following_a_user_action.md) — tracing a call path
- [P2-C1 GDScript Basics §4](../part_02_gdscript/01_gdscript_basics.md) — the six-question contract

## Learning goals

After this chapter you should be able to:

1. turn a vague intention into a goal with an observable consequence;
2. make a **vertical slice** rather than a pile of unused abstractions;
3. validate in layers, and know what each layer can and cannot prove;
4. record a measurement so that the next person can use it;
5. recognise the four stop conditions before they cost you a day.

## Vocabulary

| Term | Meaning |
|---|---|
| **Vertical slice** | A change connecting data, calculation, result and visible evidence. |
| **Contract** | The agreed shape of data between two layers. |
| **Predecessor** | The measurement taken *before* a change, on a named commit. |
| **Attributable delta** | A difference you can explain, because both ends were measured. |
| **Sampling gate** | A check emitting a variable number of assertions. |
| **Stop condition** | A signal that you should stop and investigate rather than continue. |

---

## 1. The six-step loop

### 1.1 State one observable goal

Weak: "improve rallies."

Strong: "during serve reception, choose among players using their current
positions and ball arrival time."

The test of a goal is whether you can name **what a person would see** if it
worked. A goal you cannot observe cannot be validated, and will be declared done
by whoever gets tired first.

### 1.2 Trace current behaviour

Find the input callback, manager call, simulation function, result model and
playback consumer. **Write down exact source symbols**, not descriptions.

Use the runtime trace method from
[P1-C2 §5](../part_01_project/02_godot_project_and_runtime.md): this codebase
contains superseded paths that still parse, so a plausible function is not
evidence.

### 1.3 Identify the contract

List inputs, outputs, types, metadata keys, side effects and deterministic
expectations. **For playback, verify what the consumer actually reads** rather
than inventing a schema — the consumer is the authority on its own inputs.

### 1.4 Make the smallest vertical change

A vertical change connects data, calculation, result, and visible or testable
evidence. It is better than adding several unused abstractions at once.

> **Why vertical beats broad.** An unused abstraction cannot be wrong yet, so it
> accumulates confidence it has not earned. A thin slice that reaches the screen
> is falsifiable on day one.

### 1.5 Validate in layers

Run focused tests, full tests, the parser scan, and a relevant manual scenario.
Use a fixed seed when working on simulation. §3 covers what each layer proves.

### 1.6 Update status and evidence

If a feature is only foundational, label it **PARTIALLY IMPLEMENTED**. Update
`source_manifest.json` if a documented symbol moves — the textbook validator
will fail otherwise, and it is a real check:

```bash
godot --headless --path . --script res://docs/textbook/tools/validate_textbook.gd
```

---

## 2. The change worksheet

### 2.1 The form

```text
Goal:
Current call path:
Files expected to change:
Contract preserved or changed:
Focused test:
Manual visible sign:
Known non-goals:
Predecessor measurement (commit + number):
```

### 2.2 The two lines people skip

**"Known non-goals"** is how a change stays small. Writing down what you are
*not* doing converts scope creep from a drift into a decision.

**"Predecessor measurement"** is the difference between a delta that means
something and a number nobody can use — see §4.

---

## 3. Validating in layers

### 3.1 What each layer proves

| Layer | Command or action | Proves | Cannot prove |
|---|---|---|---|
| Parser scan | `--import` | Everything loads | Anything about behaviour |
| Focused test | one check in `tests/` | One contract holds | Nothing about the whole |
| Full suite | `--script res://tests/test_runner.gd` | No known invariant broke | That the change is right |
| Balance probe | `run_rally_balance_probe.gd` | The rally population moved (or did not) | Which change moved it |
| Textbook validator | `validate_textbook.gd` | Documented symbols exist | That the prose is correct |
| Manual playback | watching it | It reads correctly | Edge cases, determinism |

### 3.2 The two that need each other

Automated tests cannot decide whether a rally **looks natural**. Manual viewing
cannot reliably prove **edge cases or determinism**. A change to anything a
viewer sees needs both, and Part 7 is built entirely around that division.

### 3.3 Reading the suite output

**Read the FAIL line, not the total.** Sampling gates emit a variable number of
assertions, so the count moves when nothing is broken and can even fall when a
change is correct.

The current baseline and its two known, pre-existing failures are recorded at
the top of `CLAUDE.md`. A **third** failure is a regression; those two are not.

---

## 4. Measurement discipline

This project has an unusually strict convention about numbers, and it exists
because of repeated, documented failures.

### 4.1 The three rules

1. **A number is worth the commit it was measured on.** Always name the commit.
2. **Measure the predecessor.** A delta with only one end is not attributable.
3. **Record it where the next reader looks** — `CLAUDE.md` for the suite,
   `docs/review/` for a probe.

### 4.2 What happens without them

`CLAUDE.md` documents the failures directly:

- a pass that wrote seventeen checks and could not compute its delta, because
  the pass before it never recorded its number — leaving two readings that
  "say opposite things and there is no way to choose between them now";
- a baseline line that said "0 fail" for a week after that stopped being true,
  which told every reader to treat two known failures as their own regression;
- a figure predicted while a run was still going, removed before commit even
  though it turned out correct, because "an unmeasured guess that happens to
  land is not evidence."

### 4.3 Reading a delta

| Delta | Usually means |
|---|---|
| Exactly the checks you wrote | No sampling population moved |
| More than you wrote | A gate is drawing more samples — behaviour changed |
| Fewer, or negative | Behaviour changed, and some gate draws fewer |
| Zero, with checks written | Look again — one of those is wrong |

**None of these prove correctness.** They tell you whether something moved.

---

## 5. Stop conditions

Stop and investigate when:

### 5.1 Unrelated files change

Either your change is broader than you thought, or another process is writing to
the tree. Both are worth finding out before you commit.

### 5.2 Deterministic tests become unstable

Same seed, different result, resolver unchanged ⇒ hidden state or unseeded
randomness. See [P3-C2 §2](02_debugging_testing_and_git.md).

### 5.3 A UI script begins owning simulation state

The coupling rule is breaking. The value is on the wrong side of the line — see
[P1-C3 §5](../part_01_project/03_repository_map.md).

### 5.4 A "temporary" fallback hides invalid data

A `.get(key, 0.0)` added to stop a crash has converted a missing key into a
plausible wrong number. That is worse than the crash, because it will not be
found. See [P2-C3 §2.2](../part_02_gdscript/03_collections_types_and_null.md).

---

## 6. Worked example

*Goal: a defender's higher `lateral_speed` should let them reach a ball they
previously could not.*

1. **Observable goal.** A specific seeded rally where the dig now happens.
2. **Trace.** `RallySimulator.resolve` → movement estimate →
   `CoverageCalculator` claim → dig resolution. Write the symbols down.
3. **Contract.** Does the movement profile already read `lateral_speed`? If yes,
   this is a tuning change. If no, it is a plumbing change — a much larger one.
4. **Predecessor.** Run the suite and the balance probe **now**, and record both
   with the commit hash.
5. **Vertical slice.** Change the one term; do not also add the abstraction that
   would let you change five terms later.
6. **Validate.** Suite (FAIL line), balance probe (did dig rate move, and by how
   much?), then watch the seeded rally.
7. **Record.** Write the before and after into `docs/review/`, both with commits.

Step 4 is the one that gets skipped, and it is the one that makes step 6
meaningful.

---

## 7. Common mistakes

| Mistake | Consequence |
|---|---|
| Goal with no observable consequence | Cannot be validated; declared done arbitrarily |
| Building abstractions before a slice | Unfalsifiable code accumulating confidence |
| Measuring only after the change | Delta is not attributable |
| Reading the total instead of the FAIL line | False alarm, or false comfort |
| Quoting a number without its commit | Unusable by the next reader |
| Adding a default to stop a crash | A wrong number that never surfaces |

---

## 8. Check yourself

1. Turn "make blocking better" into an observable goal. *(e.g. "a blocker who reads the set early closes to the ball's side before takeoff, visible in a named seeded rally".)*
2. Why is a vertical slice safer than three new abstractions? *(It is falsifiable immediately; unused code accumulates unearned confidence.)*
3. The suite count fell by two and you added four checks. Broken? *(Not necessarily — behaviour changed and some sampling gate draws fewer. Read the FAIL line.)*
4. You forgot to measure before changing. What can you still say? *(That the FAIL line did or did not grow. Not the delta.)*
5. You add `.get("duration", 0.0)` to stop a crash. What have you done? *(Converted a missing key into a contact that takes no time.)*

---

## Where this leads

- [P3-C2 Debugging, Testing and Git](02_debugging_testing_and_git.md) — the tools this loop calls for
- [VALIDATION.md](../VALIDATION.md) — every command, in one place
- [`FAILURE_MODES.md`](../../FAILURE_MODES.md) — read §0 before shipping any threshold
