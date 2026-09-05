# P7-C5 — Rendering, Probes and Validation

Status: **VERIFIED**
Keywords: probe, harness, headless, user data directory, xvfb, gl_compatibility, gate, contact sheet, regression
Primary sources: `tools/` (296 scripts, 59 scene harnesses); `tools/validate_voli_body_construction.gd`; `tools/probe_garment_clearance.gd`; `tools/run_voli_portfolio.gd`; `tests/test_runner.gd`

## Prerequisites

- [P3-C2 Debugging, Testing and Git](../part_03_workflow/02_debugging_testing_and_git.md) — the suite and the seed discipline
- [P7-C1](01_the_voli_body.md) – [P7-C4](04_faces_and_expressions.md) — the things you are about to verify

## Learning goals

After this chapter you should be able to:

1. run any probe or render harness and find its output;
2. choose the right instrument for a visual claim;
3. read a probe table and say whether it passes;
4. recognise when a probe is measuring the wrong thing;
5. leave a change verified rather than asserted.

## Vocabulary

| Term | Meaning |
|---|---|
| **Probe** | A tool that *measures* and prints a table. Headless-safe, gateable. |
| **Render harness** | A tool that *photographs* and writes PNGs. Needs a rendering context. |
| **Gate** | An assertion in `tests/test_runner.gd` that fails the suite. |
| **Validator** | A standalone script that checks structural invariants and exits non-zero. |
| **`user://`** | Godot's writable user data directory. Where renders land. |
| **Contact sheet** | One image with many subjects, for comparison at a glance. |
| **Plate** | One scenario in a portfolio: its own camera, spacing and per-subject facing. |

## 1. The three instruments, and when each is right

| Instrument | Answers | Runs headless | Fails a build |
|---|---|---|---|
| **Gate** (`test_runner.gd`) | "Is this invariant still true?" | Yes | Yes |
| **Validator** (`validate_*.gd`) | "Is this structure well-formed?" | Yes | Yes (exit 1) |
| **Probe** (`probe_*.gd`) | "What are the numbers?" | Yes | No — you read it |
| **Render harness** (`*.tscn`) | "What does it look like?" | **No** | No — you look at it |

**Choosing wrongly is the most common mistake in this part.** A gate cannot tell
you a leek looks like a headdress, and a screenshot cannot tell you a clearance
went negative on a body you did not photograph.

## 2. Running things

### 2.1 Always import after adding a script with a `class_name`

```bash
godot --headless --path . --import
```

Skipping this produces a stale class cache, which has previously turned into
roughly 200 script errors that had nothing to do with the actual change.

### 2.2 The suite

```bash
godot --headless --path . --script res://tests/test_runner.gd
```

Read the **FAIL line**, not the total. The count moves for reasons unrelated to
correctness — sampling gates emit a variable number of checks — and `CLAUDE.md`
records several passes where reading the total misled someone.

### 2.3 A validator

```bash
godot --headless --path . --script res://tools/validate_voli_body_construction.gd
```

Prints `VOLI BODY CONSTRUCTION: PASS (…)` or `FAIL (n)` and exits accordingly.

### 2.4 A probe with a rendering context

Some probes need real meshes built, so they cannot be `--headless`:

```bash
godot --path . --rendering-method gl_compatibility res://tools/garment_clearance.tscn
godot --path . --rendering-method gl_compatibility res://tools/sole_contact.tscn
```

### 2.5 A render harness

```bash
godot --path . res://tools/voli_portfolio.tscn
godot --path . res://tools/venue_probe.tscn
```

> **Platform note.** Tool headers document the Linux invocation
> `xvfb-run -a godot …` because CI runs on Linux without a display.
> **On macOS `xvfb-run` does not exist and is not needed** — drop it. A command
> that silently does nothing because `xvfb-run` was not found is easy to mistake
> for a tool that ran and produced no output.

### 2.6 Where the PNGs go

Renders write to `user://`, which on macOS resolves to:

```
~/Library/Application Support/Godot/app_userdata/Volley World Manager/
```

**Check the file's timestamp before believing it.** A stale PNG from an earlier
run looks exactly like a fresh one, and reading an old image is a genuine and
easy way to reach a confident wrong conclusion.

## 3. Reading a probe table

`probe_garment_clearance.gd` prints:

```text
body     garment            limb r     hull limb+ink  shell in     clear
Vegi     SleeveRight        0.0547    0.018   0.0727    0.0904    0.0178
Avi      SleeveRight        0.0432    0.018   0.0612    0.0744    0.0131
Simi     SleeveRight        0.0614    0.018   0.0794    0.1019    0.0225
```

The tool explains its own arithmetic:

> `clear` = shell's narrow radius − (limb radius + the limb's ink hull). Below
> zero the limb's outline is outside the garment and renders through it.

So: **every row must be positive.** The working range is about 13 mm to 23 mm.

> **What the table does not say.** This probe iterates the six body *types* and
> builds one `Vegi`, whose produce is whatever `produce_for(1)` returns —
> **`Pepper`**. The other four produce are never built. Sleeves are sized from
> the limb spec, which every produce shares, so that costs nothing; but the
> collar seats on the *drawn torso*, which differs per produce. A `Stalk` collar
> has never been measured by this probe.

That paragraph is the most important thing in this chapter. **A green table
proves what it sampled, not what you inferred.** Before trusting one, ask what
population it drew from.

## 4. Portfolios: photographing a claim from more than one angle

`run_voli_portfolio.gd` renders plates, each "a *scenario* rather than another
row" with its own camera, spacing and per-subject facing. Its header states the
rule:

> "a pose that only works head-on is a pose that does not work."

The angles are deliberately not shared. Note the corollary for *your* inspection:
the plate's authored yaws are part of the test, so if you temporarily zero them
to look at something straight on — a reasonable thing to do — **restore them
before committing**, or you have quietly removed the test.

### 4.1 Worked example: the verification that caught a real defect

A crown was rebuilt so its blades folded outward. Head-on it read correctly.
At the plate's authored yaw of 70° the whole bundle collapsed into vertical
spikes, because every blade bent in the same plane. One angle passed; the other
failed; only rendering both revealed it.

**Verify at the flattering angle and at the authored one.**

## 5. The validation ladder

For a visual change, in order:

1. **Import** — `--import`, if a `class_name` moved.
2. **Validate structure** — the relevant `validate_*.gd`.
3. **Measure** — the relevant `probe_*.gd`; confirm the population it sampled.
4. **Render** — the relevant harness, at more than one angle.
5. **Look at it.** This step is not optional and cannot be delegated to a gate.
6. **Run the suite** — confirm the FAIL line has not grown.
7. **Record the numbers** where the next reader will find them.

Steps 3 and 5 answer different questions. A change can be numerically perfect
and read as the wrong vegetable.

## 6. Recording what you measured

`CLAUDE.md` carries the suite baseline and it is worth understanding *why* the
file spends a page on the subject:

- a number is only worth **the commit it was measured on**, which is why one is
  always named;
- the count moves for reasons unrelated to correctness, so **read the FAIL
  line**;
- a delta is only attributable if the **predecessor was recorded** — several
  passes are documented where two readings support opposite conclusions and
  there is no way to choose between them now;
- the baseline line once said "0 fail" for a week after that stopped being
  true, which told every reader to treat two known failures as their own
  regression.

> **Habit.** When you quote a number, quote the commit. When you quote a delta,
> quote both ends.

## 7. Common mistakes

**Reasoning instead of rendering.** Six consecutive versions of one crown were
adjusted by argument; a single photograph settled it.

**Reading a stale PNG.** Check the timestamp.

**Using `xvfb-run` on macOS.** The command fails, nothing renders, and the
previous run's images are still sitting there — see the previous mistake.

**Trusting a green probe over its sample.** Ask which population it built.

**Zeroing a plate's yaws and committing it.** You have deleted a test.

**Widening a threshold to clear a failure.** When a gate fails broadly, suspect
the gate and re-measure its distribution — the kit gate shipped at 3:1 and
failed twelve of fourteen kits because the figure came from a different pass.

## 8. Check yourself

1. Which instrument tells you a body reads as the wrong vegetable? *(A render, looked at. Nothing else can.)*
2. A clearance table is all positive. Which bodies is that a claim about? *(The six types, and exactly one produce — `Pepper`.)*
3. Why read the FAIL line rather than the total? *(Sampling gates emit variable counts; the total moves without anything breaking.)*
4. You add a `class_name` and get 200 unrelated errors. First move? *(`--import`.)*
5. You zero a portfolio's yaws to inspect a change. What must you do before committing? *(Restore them — the yaws are the test.)*

## Where this leads

- [P3-C1 Safe Change Workflow](../part_03_workflow/01_safe_change_workflow.md) — the same discipline for non-visual work
- [`VALIDATION.md`](../VALIDATION.md) — the project-wide checklist
- [`FAILURE_MODES.md`](../../FAILURE_MODES.md) — every mistake above, and the ones not yet made here
