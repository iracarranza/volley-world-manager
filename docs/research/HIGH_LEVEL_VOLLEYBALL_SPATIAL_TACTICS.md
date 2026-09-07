# High-Level Volleyball Spatial Tactics — Sport Model Reference

Executes `docs/research/HIGH_LEVEL_VOLLEYBALL_SPATIAL_TACTICS_RESEARCH_PROMPT.md`.

Volleyball evidence only. No VWM design, abstraction, attribute or implementation
conclusions are drawn here, and nothing below was shaped to fit existing repo
behaviour.

---

# 1. Executive findings

**F1. Elite spatial organisation is principle-based, not formation-based, and
this is measured rather than asserted.** The strongest single result in the
literature: attack coverage in high-level men's volleyball produced **23 distinct
structures** across a World League sample, and **29** in the women's equivalent —
against a coaching literature that recognised **two** (2:3 and 3:2). The authors
describe it as "organisation on the edge of chaos" and conclude that rigid
systematisation is impracticable. Any model that emits one canonical shape per
phase is reproducing the textbook, not the sport. [S1][S2][S3]

**F2. The generative variable is time, not position.** Attack tempo is repeatedly
identified as *the* crucial variable of the setter's tactical action, and quicker
attacks measurably **reduce** the complexity of the coverage structure that forms
behind them. Players are not choosing a shape; they are choosing what they can
reach in the time available, and the shape is the residue. [S1][S4]

**F3. Reception quality is the gate on the entire offensive geometry.** Reception
efficacy is one of the best predictors of setting efficacy in both sexes, and
reception zone is significantly related to setting zone, which is significantly
related to attack quality. Serve criteria did **not** determine set efficacy —
the serve acts *through* reception, not around it. [S5][S6]

**F4. Six named "game complexes" are the field's organising spine**, and they cut
the rally differently from the way coaching diagrams do: K0 serve, KI side-out,
KII side-out transition, KIII transition-of-transition, KIV attack coverage,
KV freeball/downball. Coverage and freeball are treated as *first-class phases
with their own spatial logic*, not as afterthoughts of the attack. [S7][S3]

**F5. Off-system play is a regularity, not an exception.** It emerges as a
structural feature of KI, KII, KIII and KIV alike, and is *central* in coverage
and freeball situations. The literature's explicit recommendation is that
coaches stop treating off-system as a failure state. [S3][S7]

**F6. The later complexes are spatially harder for a measured reason.** KII, KIII
and KIV are associated with no-continuity outcomes because the defensive actions
that initiate them **happen closer to the net with less reaction time** than a
serve reception does. This is a spatial-temporal claim, and it explains why
transition defence is not simply "defence again". [S7]

**F7. Commit blocking has a measured cost that contradicts its intuition.** Use of
the commit block **hinders** formation of double and triple blocks at the wings
and does **not** increase block effectiveness or opponent spike error. [S8]

**F8. Perceptual expertise is a gaze-allocation difference, not a reaction-speed
difference.** Experts fixate the **setter and spiker**; novices fixate the
**ball**. Experts use fewer, longer fixations. Blockers predict set direction
better when gaze rests on the ball and the **setter's wrists** rather than the
setter's head. [S9][S10][S11]

**F9. A real perceptual occlusion exists in the six-player system**: jumping
blockers obscure the view of the defender in zone 1, the zone nearest the
spiker. Defensive positioning is partly a problem of *seeing*, and coaching
doctrine independently says never to stand directly behind your own blocker.
[S9][S12]

**F10. Men's and women's volleyball differ enough that generalising across them
is unsafe.** Median rally length 5.1 s (women) vs 4.3 s (men); 75th percentile
10.2 s vs 7.9 s; serve error+ace 14.0% vs 18.1%. Women's play sits more in KIII
and KV. Attack tempo and attack type differ significantly. [S13][S14]

**F11. The prompt's three conflict types are not equally evidenced.** Claim
conflict is addressed extensively but almost entirely as coaching doctrine;
target conflict appears indirectly as crowding; **route conflict is essentially
unaddressed in the literature I could reach.** See §11 and §17.

**F12. Metric spatial data on indoor six-player positioning barely exists in the
public literature.** Volleyball tracking research concentrates on the **ball**
(2–4 mm accuracy, 180 Hz, 12-camera referee systems) and on **beach** volleyball
players. Almost every "distance" in this document is therefore zonal or doctrinal,
not measured. This is the single largest gap. [S15][S16]

---

# 2. Evidence, method and source quality

## 2.1 Method actually used, and its limitation

This document was produced under a **hard environment constraint that materially
weakened it, and that constraint is stated first because it conditions every
citation below.**

The session's organisation egress policy blocked outbound HTTPS to every academic
and federation host attempted — `pmc.ncbi.nlm.nih.gov`, `nature.com`,
`frontiersin.org`, `fivb.org`, `goldmedalsquared.com` and others — via both the
fetch tool and `curl`. The proxy documentation classes these as policy denials
and directs that they be reported rather than routed around, which is what has
been done.

**Consequence: no source in this document was read in full text.** Every finding
is drawn from search-engine-surfaced abstracts and summaries. An automated
research harness was also attempted first; it fetched 11 sources but failed to
extract any claims, and was abandoned after roughly 2.6M tokens produced nothing
usable.

What this means for the reader:

- Sample sizes, percentages and study designs quoted below are **as reported in
  abstracts/summaries**, not verified against method sections.
- Where a number appears without a sample, assume it is unverified.
- **No claim here should be treated as replacing reading the primary source.**
- Section §14's sparseness is partly this constraint and partly a real gap in the
  field (§12 / F12). The two causes are distinguished where possible.

## 2.2 Source-quality tiers used

| Tier | Meaning |
|---|---|
| **A** | Peer-reviewed match analysis with stated sample, high-level competition |
| **B** | Peer-reviewed sports science, but lab/occlusion or non-elite sample |
| **C** | Federation/established coaching education material |
| **D** | Coaching website or practitioner blog — doctrine, not measurement |

Every claim below carries a tier. **Tier D claims are doctrine and are labelled
as such even when they are near-universal in coaching**, because near-universal
is not the same as measured — the prompt asks specifically for this distinction.

## 2.3 Court coordinate convention

All coordinates in this document use:

```
                    OPPONENT
     ┌───────────────────────────────────┐  y = 18.0 m  (opponent end line)
     │   Z4        Z3        Z2          │
     │                                   │  y = 12.0 m  (opponent 3 m line)
     │   Z5        Z6        Z1          │
     ├───────────────────────────────────┤  y =  9.0 m  (NET)
     │   Z4        Z3        Z2          │  y =  6.0 m  (own 3 m line)
     │                                   │
     │   Z5        Z6        Z1          │
     └───────────────────────────────────┘  y =  0.0 m  (own end line)
   x = 0.0 m                          x = 9.0 m
```

- Court 9.0 m × 18.0 m; each side 9.0 m × 9.0 m; attack line at 3.0 m from net.
- `x` runs left→right as seen from own end line; `y` runs own end line → net.
- Zones are the FIVB numbering: 1 right-back, 2 right-front, 3 middle-front,
  4 left-front, 5 left-back, 6 middle-back.
- "Depth" = distance from the net (9.0 − y on own side).
- Where a source gives only a zone, **the zone is reported, not converted to
  metres.** Inventing coordinates from zones is the precision-fabrication the
  prompt forbids.

---

# 3. Serve receive

## 3.1 What is structurally invariant

**Passer count is a choice, not a constant.** Three passers (two OH + libero) is
the elite default, but the literature and coaching material both treat 2-, 4- and
5-passer arrangements as live options rather than developmental stages. [C/D]

**The setter is removed from reception in every elite system.** This is the one
near-invariant of elite serve receive and it is what stacking exists to
accomplish. [C]

**Reception responsibility is not evenly divided and is not evenly *good*.** A
notable measured result: the receiving player variable **did not predict server
efficacy** in high-level men's volleyball, with reception efficacy similar
between attacker-receivers and the libero. [A, S17] This directly undercuts the
common assumption that the libero is a reliably better passer at elite level —
it may be true at lower levels while being washed out at the top.

## 3.2 What is conditional

**Serve type dominates reception outcome.** Reception efficiency differs sharply
by serve type: **jump serve 5% efficiency / 9% error; float serve 19% efficiency /
5% error** (as reported in summary; population not verified). [A?, S18] The
float/jump distinction is a larger effect than most positional choices.

**Reception *zone* changes what offense is possible.** Attack construction from an
outside-hitter reception near the setter, in zones 2/3/4, presents an off-system
characteristic. [A, S19] So a "good" pass from the wrong place still degrades the
attack — quality and location are separate variables.

**Serve targeting is spatially specific and measured.** Most effective serve from
Zone 1 → area 5 (**32% sideout, 2.24 reception score**); from zones 1/5 the
down-the-line serve to 5/1 is most effective; **Zone 6 is the least effective
origin**, with opponent reception and sideout scores highest against it. [A?/D,
S20] Sample not verified — treat as indicative.

**Seams are attacked deliberately.** Short serves into a seam force a passer
forward into the front row and produce crowding. [D, S21]

## 3.3 Seam ownership — the most specific doctrine found

The clearest actionable rule located anywhere in this research:

> **The player closest to the serve's origin takes the short seam; the player
> further from the origin takes the deep seam.** [D, S22]

This is doctrine, not measurement, but it is *generative* — it derives seam
ownership from serve geometry rather than assigning it by name, which is exactly
the kind of rule the prompt asks to recover. A secondary rule, "shortest distance
takes it", is weaker because it is circular under uncertainty.

## 3.4 What is not established

- No verified metric passer depths, widths or inter-passer distances at elite
  level. Coaching diagrams imply them; no measured distribution was located.
- No evidence located on receiver handedness/body orientation effects.
- The claim that a 2.3/3.0 passing average "lets the setter run the full offense"
  is **Tier D and unsupported** by any measurement located. It also cannot
  transfer across rating scales.

---

# 4. Serving-team transition (K0 → defence)

This is the **thinnest-evidenced phase in the entire prompt.** Named as its own
research target, it returned essentially no dedicated peer-reviewed work.

What can be said:

- The serving team is **exempt from overlap constraints at contact** (FIVB 7.4) —
  it may stand anywhere. The receiving team is not. This is a genuine structural
  asymmetry that a sport model must represent. [C, S23]
- The server must transition from behind the end line into a defensive role, and
  in most systems into back-court defence. No measured route, timing or
  displacement was located.
- Whether elite teams pre-position by expected reception quality is **plausible
  and undocumented** in what could be reached.

**Recorded as an open question (§19), not filled with plausible-sounding
doctrine.**

---

# 5. Blocking

## 5.1 System taxonomy

Two base positional systems — **bunch** and **spread** — and three decision
systems — **front, read, commit**. [C/D, S24]

- **Read**: blocker starts near the net facing the opposing setter, hands up,
  reacting after set direction becomes visible.
- **Commit**: middle jumps with the quick hitter's takeoff regardless of the set.

## 5.2 The measured result that matters

**Commit blocking hinders the formation of double and triple blocks at the wings
and does not increase block effectiveness or opponent spike error.** [A, S8]

This is a rare case of match analysis contradicting a widely-taught option, and
it is a *spatial* finding: committing the middle removes a body from the wing
closing problem.

Related: **man-to-man blocking increases block-out and block continuity; zone
blocking increases block points.** [A, S8] These are different objectives, not
better/worse systems.

## 5.3 Reception quality constrains blocker positioning

The blocker's real information source is the opponent's reception. Setter
tactical-action analysis shows the chain explicitly: closed opponent block +
ideal setting zone + jump set + middle simulation → quick attacks; open block +
receptions in zones 4 and 1 + non-ideal setting zone + no middle simulation →
slow attacks. [A, S4] A blocker reading reception quality is reading the *set
options that remain*, which is a narrower and more tractable problem than reading
the setter.

## 5.4 What blockers can adjust to, and when

See §13 for the full timeline. The key constraint: read blocking is only viable
if the set is visible early enough to move and close. Against a first-tempo
attack it largely is not, which is why the commit option exists at all despite
§5.2.

## 5.5 Not established

- No verified inter-blocker gap distances in cm/m.
- No verified single/double/triple block frequency distribution at elite level.
- Bunch vs spread prevalence at elite level: **not located.**

---

# 6. Floor defence

## 6.1 Systems

Perimeter, middle-up, rotational, and combined. [C/D]

- **Perimeter**: ≥3 defenders on the court lines; protects deep corners and
  hard-driven cross-court.
- **Rotational**: slides players to cover tips behind the block and deep line;
  also eases setter transition out of defence.

## 6.2 The evidence gap, stated plainly

**No peer-reviewed study measuring the relative effectiveness of these defensive
systems at high level was located.** Search explicitly surfaced coaching material
only. Given the confidence with which coaching sources assert system superiority,
this absence is itself a finding and belongs in §17.

## 6.3 Principles that are at least coherent and widely held

- Defenders **must not stand directly behind their own blockers** — they cannot
  see the hitter. [C/D, S12] This is corroborated by the independent perceptual
  finding that jumping blockers occlude zone 1. [B, S9]
- Positioning must be **complete before the attacker contacts the ball**; a
  defender still moving at contact is late. [C/D, S12]
- Blockers **call line or angle** so defenders can position accordingly. [C/D,
  S12] — this is a *block-defence coupling* rule, and it is the clearest
  statement located that the two are one system rather than two.
- One defender — middle-back or setter — plays behind the block near the 3 m
  line in some systems. [D]

## 6.4 Not established

- Metric defender depths and widths.
- How positioning differs behind a single vs double vs triple block, measurably.
- Defence against specific attack types (slide, pipe, setter attack) —
  **doctrine only**.

---

# 7. Attack coverage (KIV)

**The best-evidenced spatial phase in this document.**

## 7.1 Prevalence and variability

| Finding | Value | Population |
|---|---|---|
| Coverage as share of ball possessions | **3.89%** | Men, 2011 World League [A, S1] |
| Distinct structures observed (men) | **23** | Men, 2011 World League [A, S1] |
| Distinct structures observed (women) | **29** | Women, high-level [A, S2] |
| Coverage actions analysed | **1,415** over 15 matches | Men, 2010 Pan-Am Cup [A, S25] |
| Most frequent structures | **1-3-1** and **1-2-2** | Men, Pan-Am [A, S25] |
| Context of those structures | culmination of **third-tempo wing attack** | Men, Pan-Am [A, S25] |

## 7.2 What makes coverage effective

The most effective systems had: **three coverage lines**, **fewer than five
players** covering the spiker, and **at least one player in the first coverage
line.** [A, S25]

The "fewer than five" result is counter-intuitive and important: **maximal
coverage is not optimal coverage**, because bodies committed to coverage are
bodies unavailable for transition. This is corroborated independently by the
network analysis finding that freeing more players to attack becomes a
disadvantage precisely when the block is effective and coverage is suddenly
needed. [A, S3] Coverage and transition are a genuine trade-off, measured from
two directions.

## 7.3 The generative principle

Coverage structure **depends on momentary constraints**, and **quick attack
tempos constrain the emergence of complex structures.** [A, S1] The shape is
produced by how much time the covering players had, and by where the attack came
from — attack zone and tempo both show significant associations with structure.

**Coverage should therefore be modelled as an outcome of available time and
starting positions, not as a selected formation.** That is the literature's own
conclusion, not an inference.

## 7.4 Not established

- Coverer distance/depth from the hitter in metres — **not located**.
- Setter involvement in coverage after setting — doctrine only.
- Which named players occupy which line, at elite level, measurably.

---

# 8. Offensive transition

## 8.1 What is evidenced

**Attack tempo is the crucial variable of the setter's tactical action.** [A, S4]
The full measured pattern:

| Antecedents | Consequence | Then |
|---|---|---|
| Closed block, ideal setting zone, jump set, middle simulation, block anticipation | **Quick attack** | Debilitated block opposition |
| Open block, reception in zones 4/1, non-ideal setting zone, no middle simulation, non-anticipative block | **Slow attack** | Cohesive block opposition |

This is a feedback loop, and it is the clearest causal chain in the whole
document: reception location → setting zone → tempo → block state → attack
outcome.

**Setter distribution is shaped by situational constraints** — distance to
attackers and to blockers — described in ecological-dynamics terms. [A, S26]

**Best predictors of setting efficacy (both sexes): reception efficacy, setting
technique, set tempo.** [A, S6]

## 8.2 Not established

- Hitter transition routes and approach start points: **no measured geometry
  located.**
- Approach corridor spacing between hitters: **not located** — this is part of
  the route-conflict gap in §11.
- Middle transition off the block: doctrine only.

---

# 9. Continuation, scramble and broken play

## 9.1 The central measured finding

**Off-system play is a regularity of the game**, emerging in KI, KII, KIII and
KIV, and is *central* in coverage and freeball complexes. The literature's
explicit recommendation is that coaches devise strategy to turn off-system into an
advantage rather than treating it as breakdown. [A, S3][S7]

**KII, KIII and KIV are associated with no continuity** because the defensive
actions initiating them occur **closer to the net with less reaction time**.
[A, S7] This is the spatial reason broken play is hard: the ball arrives sooner
and nearer, so less repositioning is possible before the next contact.

## 9.2 Not established

Nearly everything the prompt asks for in this section:

- Who sets when the setter digs — **doctrine only**, no measured substitution rule.
- Joust, overpass, pancake, displaced-player recovery — no spatial research
  located.
- Priority rules when two players pursue the same ball — see §11.

This is a genuine and large hole in the sport's literature, not merely in my
access to it. Match analysis codes *outcomes* of broken play; it rarely codes the
*spatial reconstruction* that produced them.

---

# 10. Free ball and down ball (KV)

Treated in the literature as a **first-class complex** with its own network
signature, not as a trivial case. [A, S3]

- Analysed together with coverage in a women's World Grand Prix 2015 sample:
  **8 matches, 1,264 rallies.** [A, S3]
- **KI and KV are most closely associated with in-system offense**; KII, KIII and
  KIV with no continuity. [A, S7] Free ball is therefore spatially closer to
  serve reception than to transition defence — it affords time.
- Off-system remains central even here. [A, S3]

Not established: first-contact responsibility conventions, setter positioning on
free ball, attacker release timing — **doctrine only**.

---

# 11. Teammate spacing, interference and priority

The prompt flags this as especially important. **It is the weakest-evidenced
major section, and the gap is in the sport's literature, not only in my access.**

## 11.1 The three conflict types, assessed separately

| Type | Definition | Evidence found |
|---|---|---|
| **Claim conflict** | Two players attempt the same ball | Extensive doctrine, no measurement |
| **Target conflict** | Two players want the same location | Indirect only, via "crowding" |
| **Route conflict** | Different destinations, intersecting paths | **Essentially nothing** |

**Route conflict is the significant absence.** The concept that two players may
have correct, different destinations and still interfere *en route* is not
something the volleyball literature appears to name. Approach corridors are
discussed as technique, not as shared-space constraints. This is recorded as an
open research question (§19) rather than filled in.

## 11.2 Claim conflict — doctrine, clearly labelled

All Tier D:

- Closest player takes it. [S22]
- **Short seam to the player nearer the serve origin; deep seam to the player
  further away.** [S22] — the one geometrically generative rule found.
- "Mine" / "help" calls; **when someone calls, everyone else backs off.** [S27]
- Better practice is to **pre-assign responsibility between rallies** so calling
  becomes unnecessary; seam failures are framed as *understanding* failures
  rather than communication failures. [S27]

That last point matters conceptually: elite coordination is described as
**anticipatory role assignment**, with vocal calling as a fallback — not as
real-time collision avoidance.

## 11.3 Target conflict — indirect evidence

Short seam serves are said to force a passer into the front row and **cause
crowding and confusion**. [D, S21] This is the clearest statement that two
players occupying overlapping useful space is a *failure state deliberately
induced by the opponent* — i.e. crowding is a weapon, which implies it is costly.

## 11.4 What is entirely missing

- **No measured collision or near-miss frequency at any level.**
- **No measured inter-player separation distributions.**
- No study characterising whether elite coordination is avoidance, claim
  resolution, anticipatory spacing or route selection. The doctrine leans
  strongly toward *anticipatory role assignment*, but this is inference from
  coaching emphasis, not a finding.

---

# 12. Rotation-specific consequences

## 12.1 Rules-required pre-serve geometry (invariant, Tier C)

**Overlap constraints apply at exactly one instant: the server's contact.**
[S23][S28]

- Only the **receiving** team is constrained; the serving team may stand anywhere
  (FIVB 7.4).
- Relationships exist **only** between a front-row player and the back-row player
  directly behind, and between adjacent players in the same row.
- **Diagonal players have no positional relationship at all.**
- Foot rule: a front-row player needs part of one foot closer to the centre line
  than the back-row player behind her; a side player needs part of one foot
  closer to her sideline than her row's middle player.
- Violation is a positional fault (Rule 7.5): point and serve to the opponent.

## 12.2 The consequence that shapes everything

> "Teams obey the rotation rules for exactly one second per rally and then play
> real volleyball the rest of the time." [D, S28]

Pre-serve geometry is therefore a **constraint-satisfaction problem at a single
instant**, followed by immediate release. Stacking and switching exist to satisfy
the instant while placing the setter near the net and passers in their lanes.

**This is a clean separation the prompt asked for: rules-required pre-serve
geometry and tactical post-contact geometry are different objects with different
governing logic.**

## 12.3 Not established

- Rotation-by-rotation reception geometry at elite level, measured.
- Rotation-specific weak points, measured. (Widely asserted; not located as
  measurement.)

---

# 13. Temporal and perceptual decision sequence

Reconstructed from the perceptual literature [B] and the tactical-action
literature [A]. Confidence is marked per row.

| Stage | What is available | What can be committed | Confidence |
|---|---|---|---|
| Pre-serve | Rotation, opponent tendencies, server identity | Legal alignment; passer lanes; setter hidden | High (rules) |
| Server contact | Serve type, origin zone, trajectory start | Overlap released; all movement legal | High (rules) |
| Early flight | Depth/width read, float vs topspin | Passer claim; seam ownership resolves | Doctrine |
| Reception contact | Actual pass quality and location | **Set options collapse to a subset** | High [S5][S6] |
| Pass trajectory readable | Setter's distance to ideal zone | Blockers narrow from all options to likely | High [S4] |
| Setter body cues, pre-release | Hands, trunk, legs; **wrists most diagnostic** | Blocker weight shift; read-block viability | High [B, S9] |
| Set release | Direction, tempo, height | Block closes; floor defence moves to attack-specific | High |
| Hitter approach | Approach angle, shoulder orientation | Defender final adjustment | Doctrine |
| Hitter contact | Arm swing, contact point | **Nothing further — positioning must be complete** | Doctrine [S12] |
| Block touch | Deflection direction | Coverage/transition reconstruct | Low |

## 13.1 The two hard perceptual constraints

1. **Blockers occlude the zone-1 defender's view of the spiker.** [B, S9] Some
   defenders are structurally denied the cue everyone else is told to read.
2. **Later complexes compress the timeline**: KII/KIII/KIV defensive actions
   begin closer to the net with less reaction time. [A, S7]

## 13.2 Hindsight guard

The prompt warns against hindsight geometry. The literature supports one strong
statement here: positioning must be **complete before hitter contact** [S12], and
what a defender knows before that moment is bounded by the setter's release plus
the approach — **not** by the eventual ball direction. Any model in which
defenders position on the actual attack direction is using information that did
not exist.

---

# 14. Static structure vs adaptive intelligence

Applying the prompt's A–E taxonomy. The evidence supports a **modification**,
given in §14.2.

| Class | Examples supported by evidence |
|---|---|
| **A. Stable team structure** | Legal pre-serve alignment; setter excluded from reception; base defensive system; bunch/spread base |
| **B. Context-conditioned team rule** | Read vs commit choice; serve target by origin zone; formation adjustment to serve type; seam ownership by serve origin |
| **C. Individual read** | Gaze allocation to setter/wrists; defender reading approach and shoulders; passer depth adjustment |
| **D. Interpersonal coordination** | Blocker calling line/angle to position defenders; "mine"/"help"; pre-assigned seam responsibility |
| **E. Emergency adaptation** | Off-system setting; coverage structure emerging under time pressure; scramble |

## 14.2 Proposed modification to the taxonomy

The evidence supports splitting **E** into two genuinely different things, and
the coverage literature is the reason:

- **E1 — Constrained emergence.** Structure is not chosen but *falls out* of time
  and starting positions. Attack coverage is the documented case: 23/29
  structures, tempo-constrained complexity, "edge of chaos". Nobody is improvising;
  everybody is doing the only reachable thing. [S1][S2]
- **E2 — Genuine improvisation.** Role substitution after the setter digs;
  pursuit off court. Almost entirely undocumented.

The distinction matters because E1 is *predictable from constraints* while E2 is
not, and conflating them makes the sport look more chaotic than it is. **The
"chaos" in the coverage literature is E1 — lawful variety, not disorder.**

---

# 15. Expertise and game intelligence

All Tier B (lab/occlusion/eye-tracking).

| Finding | Detail | Source |
|---|---|---|
| Fixation pattern | Elite use **fewer fixations of longer duration** | [S10][S11] |
| Cue location | Experts fixate **setter and spiker**; novices fixate **ball** | [S9] |
| Diagnostic cue | Gaze on ball + **setter's wrists** predicts pass direction better than gaze on head | [S9] |
| Mechanism | "Visual pivots" allow simultaneous extraction from hands, trunk, legs | [S9] |
| Prediction | Experts faster **and** more accurate on set direction | [S10] |
| Reception link | Visual skills associate with serve-reception performance in elite male OH | [S29] |

**Synthesis: elite spatial intelligence manifests primarily as better cue
selection and earlier information extraction — not as faster movement.** The
consistent pattern across studies is *where and how long they look*, not how
quickly they react. No located study attributes elite advantage to superior
starting position alone.

**Caveat that limits all of the above:** these are largely video-based,
lab-adjacent paradigms. Whether the gaze advantage transfers to six-player
in-situ positioning quality is not established by anything located, and one study
was explicitly in-situ while others were not.

---

# 16. Quantitative spatial library

Only values actually located are listed. **Blank cells are not estimated.**

| # | Phase | Role | Condition | Finding | Value | Pop. | Tier | Limitation |
|---|---|---|---|---|---|---|---|---|
| Q1 | KIV | All | Elite men | Coverage share of possessions | 3.89% | M, World League 2011 | A | Abstract only |
| Q2 | KIV | All | Elite men | Distinct structures | 23 | M, WL 2011 | A | Abstract only |
| Q3 | KIV | All | Elite women | Distinct structures | 29 | W, high-level | A | Abstract only |
| Q4 | KIV | All | Pan-Am | Coverage actions analysed | 1,415 / 15 matches | M, 2010 | A | Abstract only |
| Q5 | KIV | All | 3rd-tempo wing | Most frequent structures | 1-3-1, 1-2-2 | M | A | Context-specific |
| Q6 | KIV | All | Effectiveness | Optimal shape | 3 lines, <5 coverers, ≥1 first line | M | A | Abstract only |
| Q7 | KI | Passer | Jump serve | Reception efficiency / error | 5% / 9% | unclear | A? | Population unverified |
| Q8 | KI | Passer | Float serve | Reception efficiency / error | 19% / 5% | unclear | A? | Population unverified |
| Q9 | K0 | Server | From Z1 → area 5 | Sideout / reception score | 32% / 2.24 | unclear | A?/D | Sample unverified |
| Q10 | K0 | Server | Origin zone | Least effective origin | Zone 6 | unclear | A?/D | Sample unverified |
| Q11 | All | — | Rally length, women | 25/50/75/100th pct | 3.9 / 5.1 / 10.2 / 43.9 s | W, Spanish high-level | A | Single league |
| Q12 | All | — | Rally length, men | 25/50/75/100th pct | 3.2 / 4.3 / 7.9 / 29.1 s | M, Spanish high-level | A | Single league |
| Q13 | K0 | Server | Serve error + ace | Men vs women | 18.1% vs 14.0% | Olympic | A | — |
| Q14 | KI–KIII | Chain | World Champs | Actions analysed | 4,113 (1,371×3), 12 teams | Elite | A | Abstract only |
| Q15 | KIV/KV | All | WGP 2015 | Rallies analysed | 1,264 / 8 matches | W | A | Abstract only |
| Q16 | — | Ball | Referee system | Tracking accuracy / rate | 2–4 mm / 180 Hz | — | A | **Ball, not players** |

## 16.1 What the library conspicuously lacks

**Not one metric inter-player distance, passer depth, blocker gap, coverer radius
or defender coordinate was located at elite indoor level.** Q16 exists to make the
point: the sport can track a *ball* to 2–4 mm and does not publish where its six
*players* stand.

---

# 17. Contradictions and uncertainty

**C1 — Formation taxonomy vs measured variety.** Coaching literature recognises
two coverage systems; match analysis finds 23 and 29. The coaching taxonomy is
not a simplification of the measured reality, it is a **different claim about the
sport**, and the measurement wins. [S1][S2]

**C2 — Commit blocking.** Widely taught; measured to hinder wing double/triple
blocks without improving effectiveness or forcing spike error. [S8]

**C3 — Libero passing superiority.** Assumed universally; **reception efficacy was
similar between attacker-receivers and libero** in elite men, and receiver
identity did not predict server efficacy. [S17] May be a level-dependent effect.

**C4 — Defensive system effectiveness.** Asserted confidently by coaching sources;
**no high-level peer-reviewed comparison located.** Treat perimeter-vs-rotational
superiority claims as unevidenced.

**C5 — "Maximal coverage is best."** Contradicted: fewer than five coverers was
associated with the most effective structures, and over-committing to attack
availability becomes a liability against an effective block. [S25][S3]

**C6 — Men's/women's generalisation.** Rally length, serve risk, attack tempo and
complex distribution all differ significantly. Findings from one should not be
transferred to the other. [S13][S14]

**C7 — Flagged folklore.** The following are common and **unsupported by anything
located**: specific passer-average thresholds enabling "full offense"; specific
coverage distances; rotation-specific weak-point claims; defensive system
superiority; most scramble priority rules.

**C8 — My own access limitation** (§2.1) means C1–C7 rest on abstracts. Where a
contradiction matters for a decision, read the primary source.

---

# 18. High-confidence volleyball invariants

Claims I would defend as well-supported:

1. Overlap constraints bind at the instant of serve contact only; the serving
   team is exempt; diagonals are unconstrained. **(Rules — certain.)**
2. Elite serve receive removes the setter from reception. **(Universal doctrine.)**
3. Reception quality and reception *zone* jointly constrain the set, and the set
   constrains the attack. **(Multiple A-tier studies.)**
4. Attack tempo is the primary organising variable of offensive structure, and
   faster tempo yields simpler emergent structures behind it. **(A-tier.)**
5. Attack coverage is principle-based with high structural variety; it is not a
   selectable formation. **(A-tier, two populations.)**
6. Coverage and transition trade off against each other; maximal coverage is not
   optimal. **(A-tier, two independent directions.)**
7. Later complexes (KII/KIII/KIV) afford less time and space than serve reception,
   and this is why they produce less continuity. **(A-tier.)**
8. Expert perceptual advantage is cue-selection and gaze-allocation based, centred
   on the setter. **(B-tier, consistent across studies.)**
9. Defensive positioning must be complete before hitter contact. **(Doctrine, but
   consistent with the perceptual timeline.)**
10. Men's and women's high-level volleyball differ enough to require separate
    treatment. **(A-tier.)**

---

# 19. Open research questions

**O1. Route conflict.** Does the sport have a concept for two players with
different correct destinations whose paths interfere? Nothing located. Highest-
value gap for any spatial model.

**O2. Metric spacing.** No public distribution of inter-player distances at elite
indoor level. Tracking technology plainly exists (Q16).

**O3. Collision and near-miss frequency.** Never measured, at any level, in
anything located.

**O4. Serving-team post-serve organisation.** An entire phase with essentially no
dedicated research (§4).

**O5. Broken-play spatial reconstruction.** Outcomes are coded; the spatial
reorganisation producing them is not (§9.2).

**O6. Defensive system effectiveness at elite level.** (C4.)

**O7. Does the perceptual expertise advantage transfer to six-player positioning?**
Lab paradigms dominate; in-situ six-player evidence is thin.

**O8. Rotation-specific geometry, measured** rather than diagrammed.

**O9. Coverage line distances.** The structures are counted; their geometry is not
reported.

---

# 20. Source list

Access note: **none of these was retrievable in full text in this environment**
(§2.1). Identifiers are given so a reader with access can go to the primary text.

| ID | Source | Tier |
|---|---|---|
| S1 | *Attack Coverage in High-Level Men's Volleyball: Organization on the Edge of Chaos?* PubMed 26557208 / PMC4633260 | A |
| S2 | *The Importance of Loosely Systematized Game Phases in Sports: Attack Coverage Systems in High-Level Women's Volleyball.* Montenegrin J Sports Sci Med, artid=108 | A |
| S3 | *Systemic Mapping of High-Level Women's Volleyball using SNA: Attack Coverage, Freeball, and Downball.* MJSSM artid=132 / RG 314155827 | A |
| S4 | *Analysis of the setter's tactical action in high-level women's volleyball.* RG 268298297 | A |
| S5 | *A Comprehensive Analysis of the Serve Reception Zone, Set Zone and Attack Quality of Top-Level Volleyball Players.* Eur J Human Movement 735 / RG 361691882 | A |
| S6 | *Characteristics of Serve, Reception and Set That Determine Setting Efficacy in Men's Volleyball.* Front Psychol 10.3389/fpsyg.2020.00222 / PMC7040554 | A |
| S7 | *Interaction network analysis of the six game complexes in high-level volleyball (Eigenvector Centrality).* PLOS One 10.1371/journal.pone.0203348; *The Sequencing of Game Complexes in Women's Volleyball*, PMC7204995 | A |
| S8 | *Relationship between the use of commit-block and the numbers of blockers and block effectiveness* (Afonso et al.), RG 233687089; *Relationship between Block Constraints and set outcome in Elite Male Volleyball*, RG 230867271 | A |
| S9 | *Expert Performance in Action Anticipation: Visual Search Behavior in Volleyball Spiking Defense.* Behav Sci 10.3390/bs14030163 / PMC10968438 | B |
| S10 | *Response Time, Visual Search Strategy, and Anticipatory Skills in Volleyball Players.* Piras et al., J Ophthalmol 2014:189268 / PubMed 24876946 | B |
| S11 | *Decision-making and dynamics of eye movements in volleyball experts.* Sci Rep s41598-020-74487-x; *Expertise-driven temporal gaze dynamics during anticipation in volleyball*, PLOS One 0334702 | B |
| S12 | *The Block-Defense Relationship for a 2-Player Block.* Volleyball Canada coach development | C |
| S13 | *Comparison of Rally Length between Women and Men in High-Level Spanish Volleyball.* PMC10694729 / J Human Kinetics | A |
| S14 | *Evidence for Differences in Men's and Women's Volleyball Games Based on Skills Effectiveness in Four Consecutive Olympic Tournaments.* Kountouris et al. 2015 | A |
| S15 | *Volleyball Game Analysis Using Computer Vision Algorithms.* SCORES24 / RG 387232477 | B |
| S16 | *Tracking of Ball and Players in Beach Volleyball Videos.* PLOS One 10.1371/journal.pone.0111730 | B |
| S17 | *Variables that Predict Serve Efficacy in Elite Men's Volleyball with Different Quality of Opposition Sets.* PMC5873346 | A |
| S18 | Reception efficiency by serve type — surfaced in summary; **primary source not isolated** | A? |
| S19 | *Is it possible for the reception and the player-receiver to influence the offensive construction in volleyball?* Int J Perf Analysis Sport 23(4), 10.1080/24748668.2023.2229204 | A |
| S20 | Serve origin/target effectiveness — *Everything You Ever Wanted To Know About Serve Zones*, smartervolley; **sample unverified** | A?/D |
| S21 | *Volleyball serving tips: Target the seams.* The Art of Coaching Volleyball | D |
| S22 | *Whose Ball? Seam Responsibilities in Serve Receive & Defense.* coachingvb.com | D |
| S23 | FIVB Rule 7.4 / 7.5 as reported by rotation references | C |
| S24 | *Understanding Blocking Systems.* AVCA; *A review of blocking in volleyball: from notational analysis to biomechanics*, RG 26630208 | C/A |
| S25 | *What are the Most Widely Used and Effective Attack Coverage Systems in Men's Volleyball?* PubMed 29922383 / PMC6006527 | A |
| S26 | *Setting distribution analysis in elite-level men's volleyball: an ecological approach.* Research, Society and Development 11994 | A |
| S27 | *On player communication* / *To call the ball or not to call the ball.* coachingvb.com | D |
| S28 | *Volleyball Overlap Rules (FIVB 7.4) — Explained Simply*; *Volleyball Stacking & Switching Explained* | C/D |
| S29 | *Associations between visual skills and serve reception performance in elite male volleyball outside hitters.* PubMed 42389757 / PMC13318771 | B |

---

# Completion audit

Against the prompt's required checklist.

| Check | Status |
|---|---|
| Missing roles | **Partial gap.** Opposite and middle are under-covered relative to setter/libero/OH — reflects the literature's own focus, now stated. |
| Missing rotations | **Gap.** Rotation-by-rotation geometry not measured anywhere located (O8). |
| Men's/women's differences | **Covered** (§1 F10, §16 Q11–Q13, §17 C6). |
| Ideal-system bias | **Actively resisted.** Off-system documented as a regularity (§9.1), not an exception. |
| First-ball bias | **Resisted.** KIV and KV given first-class sections; §9 states the timeline compression that makes later complexes different. |
| Missing broken-play behaviour | **Gap, and named as such** (§9.2, O5) rather than filled with doctrine. |
| Hindsight/perception errors | **Guarded** (§13.2): positioning completes before hitter contact; blockers occlude zone 1. |
| Unsupported coaching folklore | **Flagged** (§17 C7) and tier-labelled throughout. |
| Over-rigid coordinate claims | **Avoided.** Zones are not converted to metres; §16.1 states the absence explicitly. |
| Unexamined teammate-conflict semantics | **Examined and found wanting** (§11.1) — route conflict essentially absent from the literature. |

## Saturation statement

**Saturation was not reached, and claiming it would be false.**

Searching converged for attack coverage, game-complex structure, the
reception→set→attack chain, and perceptual expertise — additional queries
returned the same studies. It did **not** converge for serving-team transition,
broken-play spatial reconstruction, teammate route conflict, or any metric
spacing, because in those areas the searches converged on *absence*.

Two distinct causes, which must not be conflated:

1. **Field-level absence** — route conflict, collision frequency, metric spacing,
   elite defensive-system comparison. More searching will not fix these.
2. **Access-level absence** — §2.1. Full texts were unreachable; values quoted
   from abstracts may be refined or corrected by the primary sources, and some
   sections (especially §16) would likely be materially richer with full-text
   access.

A follow-up pass with journal access should re-derive §16 first.
