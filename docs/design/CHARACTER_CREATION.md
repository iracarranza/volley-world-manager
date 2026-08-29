# Character creation

Who the manager is, what volleyball they value, where they come from, and what kind of club life they intend to build.

## Core rule

Character creation establishes **preferences and starting circumstances, not commandments or manager stat bonuses**. The player should be able to make meaningful choices without already knowing volleyball terminology. Technical depth remains in the simulation; creation teaches the visible ideas behind it.

The intended top-level structure is moving toward:

1. **YOU** — name, appearance, background.
2. **VOLLEYBALL** — what should your volleyball look like?
3. **ORIGIN / PLACE** — where are you from, and where are you beginning your career?
4. **FOUNDATION / CLUB** — what institution are you inheriting or building?
5. **MANAGEMENT** — what deserves your attention, what do you delegate, and what kind of club do you build?
6. **SIGNATURE** — names and review.

The exact top-level count can still change. The important separation is that tactical volleyball, geography, club circumstances, and management identity are not collapsed into one questionnaire.

---

# 01 — YOU

## Appearance

The manager uses the same `PlayerActor3D` visual language as volis. The editor exposes body type, Vegi variety where applicable, colourway, coat/marking, face, height, arm proportion, leg proportion, handedness, and manager name.

A body is **what you look like, not what you are good at**. Manager geometry never enters the volleyball simulator.

The two limb axes are proportions rather than independent measurements so their visual character survives height changes. The UI must respect the rig's real clamps rather than exposing slider ranges that silently collapse to the same body.

## Background

Background remains intended as a starting-position redistribution rather than a bonus. Current concepts are:

- **You played** — stronger familiarity with one positional population, weaker knowledge elsewhere; first club connected to playing history.
- **You coached youth** — younger starting squad and unusually good knowledge of that roster, but weaker knowledge of the wider world.
- **You analysed** — broader early scouting coverage rather than a stronger individual scouting modifier.
- **You paid for it** — founding route: resources to begin, little standing or established trust.

These effects are designed but not fully implemented. The live builder currently defaults saves to `played` unless supplied elsewhere.

---

# 02 — VOLLEYBALL

## Purpose

The old philosophy page exposes several abstract tactical axes simultaneously. It is both too technical for a newcomer and too vague for an experienced player: labels such as `Outlast / Adapt / Finish` do not tell a newcomer what will happen on court, while `Middles / Spread / Pins` assumes positional and tactical knowledge before the player has met a squad.

The replacement should be a **nested page-by-page visual sequence inside 02 — VOLLEYBALL**.

Only one tactical question is presented at a time. Each page contains:

- the question as the main header;
- three plain, sentence-case tactical labels;
- a short accessible description for each;
- a selectable visual preview;
- an explicit confirmation before advancing.

The label serves experienced players. The description serves newcomers. The preview makes the idea visible to both.

Example interaction:

```text
02 — VOLLEYBALL                         1 / 6

YOUR TEAM GETS A GOOD FIRST TOUCH. HOW SHOULD THEY ATTACK?

[ Quick attacks ]
[ Read the blockers ]
[ Trust your hitters ]

            [ looping demonstration ]

Read the blockers
Watch how the block develops, then attack the space it leaves open.

                    [ THIS FEELS RIGHT ]
```

Selecting another answer changes the demonstration. Selection alone does not advance the page.

## Preview authority

Individual answer previews should be **authored deterministic volleyball vignettes**, not randomly generated rallies.

Their job is to teach one tactical distinction clearly. They may use deliberately exaggerated or statistically unusual situations — for example, three blockers committing to the wrong threat — provided the situation remains physically and legally possible volleyball.

The preview should author circumstances and tactical decisions, not fake ball physics. Production movement, contact, trajectory, net legality, and timing remain authoritative. This prevents character creation from becoming a second puppet-animation version of volleyball that can depict things the actual match simulator cannot reproduce.

A useful implementation model is:

```text
AUTHORED
initial positions
reception quality
available threats
intended tactical decision
opponent commitment / information state

SIMULATION-AUTHORITATIVE
movement
contacts
ball flight
net legality
attack
landing / continuation
```

The examples should sit near the outer edge of plausible situations because tactical teaching benefits from clarity. **Unlikely but legal is useful; physically impossible is not.**

The footage may briefly slow or replay the decisive moment. It should read as a tactical illustration performed by the game world, not as supposedly random match footage.

## The six tactical questions

### Q1 — Good-ball attack

**Question:**
> Your team gets a good first touch. How should they attack?

**Quick attacks**  
Attack quickly, before the defense has time to organize.

Preview: a very clean reception gives the setter immediate access to a fast attack. The attacker arrives before the opposing block can form. The visual lesson is that **time itself created the advantage**.

**Read the blockers**  
Watch how the block develops, then attack the space it leaves open.

Preview: several attacking threats remain credible. The opposing block commits conspicuously toward one threat — an exaggerated triple commitment is acceptable — and the setter releases the ball to the uncovered attacker. The visual lesson is that **information created the advantage**.

**Trust your hitters**  
Create favorable matchups and let your attackers beat the defense.

Preview: the defense does not make a glaring mistake. The setter creates or recognizes a favorable matchup and gives the attacker a ball against a formed but beatable block. The visual lesson is that **the matchup and hitter created the advantage**.

This replaces the old `Middles / Spread / Pins` creation choice. Which positions actually receive attack volume should depend later on roster, setter, matchup, and tactical implementation rather than being declared before the player has met the squad.

---

### Q2 — Serving

**Question:**
> How should your team serve?

**Controlled serves**  
Prioritize keeping the serve in and making the opponent play the rally.

Preview: a controlled serve clears safely and reaches a receiver in a playable position. The opponent gets a reasonable first touch. The example must not frame this as a bad outcome: the team deliberately traded some direct pressure for reliability.

**Target the reception**  
Serve into difficult spaces and toward receivers you think you can disrupt.

Preview: the serve itself can look ordinary. Its placement attacks a seam, weak receiver, or uncomfortable responsibility boundary. The resulting first contact pulls the opponent away from ideal attacking structure. The lesson is that **placement damaged the next action even without an ace**.

**Aggressive serves**  
Accept more serving errors for a better chance of forcing a poor reception or winning the point immediately.

Preview: use two very short examples if necessary. One aggressive serve overwhelms reception or produces an ace; another misses. The tradeoff must be visible so `Aggressive serves` does not read as simply `better serves`.

These are not merely low / medium / high power. They distinguish consistency, targeting/information, and high-risk direct pressure.

### Pre-serve presentation backlog

Viewing a rally should eventually include the lead-up to the serve rather than beginning at launch:

- players settle into their positions;
- the server receives/holds the ball;
- the server waits for the referee whistle;
- after the whistle, the voli performs an individual serve routine;
- the routine leads naturally into toss/approach/contact.

Serve routines can become a small source of voli individuality: bounce count, pause length, breathing/reset behavior, preparation and approach habits. They are presentation/character behavior rather than disguised outcome modifiers.

Routine rally pacing must remain manageable through presentation speed and skipping. The same pre-serve language can introduce the three Q2 demonstrations before their tactical intentions diverge.

---

### Q3 — Defense

**Question:**
> How should your team defend attacks?

**Floor defense**  
Use the block to guide attacks toward spaces your defenders are prepared to cover.

Preview: a strong opposing outside attack meets a dense, well-shaped double block that removes the hitter's preferred/cross-court space while deliberately conceding a weaker line. The hitter takes that line and finds a defender already waiting for it, producing a controlled dig.

The critical teaching point is: **the block did not fail; it made the attack predictable.** Use a double rather than a triple as the canonical example so this option does not visually imply greater net commitment than `Commit the block`.

**Read the attack**  
Watch how the play develops and let blockers and defenders adjust before committing.

Preview: the opponent begins with several credible options. The defense remains relatively neutral until the set/approach reveals useful information, then the block and floor defenders adjust together. The lesson is that **delayed commitment preserves information**.

**Commit the block**  
Send blockers aggressively toward the expected attack and try to stop it at the net.

Preview: a predictable attacking situation allows blockers to commit early and form a dominant block. A brief contrasting example may show the same early commitment being punished when the setter goes elsewhere. The lesson is that **earlier commitment can build a stronger block at the cost of making the decision with less information**.

All competent versions still use both blocking and floor defense. The question is where the defensive system spends commitment when it cannot cover everything perfectly.

---

### Q4 — Transition offense

**Question:**
> Your team keeps a difficult attack alive. What should happen next?

The exact labels remain subject to wording polish, but the tactical distinction is settled:

**Reset the play**  
Use the next touches to regain control and structure before asking for another difficult attack.

Preview: a difficult dig leaves the team disorganized. Rather than forcing an immediate swing, the team controls the next action, reorganizes, and restores a recognizable attacking shape.

**Find the opportunity**  
Attack when the defensive situation gives you a useful option, without forcing one that is not there.

Preview: the same difficult defensive origin produces a developing transition. The setter/players recognize which attackers are genuinely available and exploit a viable opening rather than automatically resetting or forcing speed.

**Attack in transition**  
Look to turn defensive touches into attacks as quickly as possible.

Preview: the team treats the dig as the beginning of offense. Available attackers move immediately and the next playable contact is converted into an attacking opportunity before the opponent fully resets.

This is the successor to the useful part of the old `Reset / Read / Go Again` axis. The preview should use comparable defensive origins so the continuation, rather than the quality of the dig, explains the difference.

---

### Q5 — Imperfect first contact

**Question:**
> The first contact pulls your team out of position. How should they respond?

The exact labels remain subject to wording polish. The settled tactical distinction is:

**Recover the structure**  
Prioritize restoring enough shape to run a controlled, recognizable attack.

Preview: reception pulls the setter/team away from ideal position. Players use the remaining contacts to recover spacing and produce a safer structured attack rather than treating the bad reception as an automatic lost rally.

**Use what's available**  
Adapt the attack to the players and spaces the first contact actually leaves available.

Preview: the intended attack is unavailable, but another player or route remains viable. The team abandons the original pattern and builds around the option that survived the reception.

**Keep the pressure on**  
Accept a more difficult attacking situation rather than giving the opponent an easy ball back.

Preview: the team is clearly out of system but still chooses an assertive attack from an imperfect position. The example should also communicate the additional risk rather than presenting aggression as universally superior.

This question is deliberately distinct from Q4. Q4 begins with **defense and transition**; Q5 begins with **serve reception disrupting the intended side-out offense**. Both are important because team identity becomes most visible when the ideal pattern breaks down.

---

### Q6 — Offensive construction

This question is about **how attacks create opportunities**, not which positions should receive the most sets. Positional distribution remains a later squad-aware tactical decision.

**Question:**
> How should your attacks create opportunities?

**Combination offense**  
Use multiple attacking threats together to move, occupy, or confuse the block.

Preview: multiple attackers present credible, coordinated threats. Their timing/paths force incompatible blocker responsibilities and create the eventual opening. The scorer is not simply the pre-declared star; the opportunity comes from the combination.

**Flexible offense**  
Keep several options available and choose the attack that develops best.

Preview: attackers preserve several viable routes while the setter waits for enough information to choose among them. This differs from Q1's `Read the blockers`: Q1 asks what advantage the offense seeks on a good ball, while Q6 asks how the attacking threats are structurally related to one another.

**Isolation offense**  
Create a favorable one-on-one or one-on-two opportunity and let the hitter solve it.

Preview: other threats occupy enough defensive attention to isolate the intended attacker against a manageable block. The attack succeeds because the system created a favorable individual contest rather than because several attackers complete a combination at the point of decision.

`Combination / Flexible / Isolation` is therefore a club's broad offensive construction preference. `Middle / pin / individual hitter volume` remains downstream of the actual squad.

---

## Completed-volleyball showcase

After Q1–Q6, the game may offer a short **YOUR VOLLEYBALL** montage. Unlike the individual teaching vignettes, this is a good place for deterministic procedural simulation to combine the selected tendencies.

The authored previews establish the vocabulary. The combined showcase demonstrates how those preferences interact without promising that every choice succeeds. An aggressive serving identity, for example, may legitimately show one serve creating a poor reception and another missing.

Character creation shows what the manager values; the simulation still decides what actually happens.

## Regional fit from the volleyball page

After completing the six questions, offer an optional action such as:

> **See where your volleyball fits**

This is not a recommendation of the objectively best region. Regional alignment means familiarity/cultural correspondence, not quality. A low-alignment career can be intentionally interesting.

The viewer can surface the closest traditions and allow exploration of all regions. The existing alignment concept can support this, but the presentation should explain correspondence rather than dumping a percentage without context.

## Regional montages

Viewing a region either from the optional volleyball-fit viewer or from the actual region picker should use a shared **regional profile/montage presentation**.

A regional montage is mostly authored/certified rather than random. Its job is to communicate a volleyball culture reliably, so it can combine several short moments:

```text
serve receive
CUT
training / movement pattern
CUT
transition or attacking identity
CUT
defensive identity
CUT
venue / club / regional environment
```

The montage should include the region's environmental/material language as well as its volleyball. Regional office/facility materials therefore become part of world recognition rather than isolated office decoration.

The same viewer has two contexts:

- **From VOLLEYBALL:** `How does my philosophy compare with this tradition?` Emphasize tactical correspondence.
- **From ORIGIN / PLACE:** `What is it like to begin a career here?` Add major/minor status, clubs, academy context, resources, institutional conditions, and the player's alignment.

This avoids duplicating region presentations while allowing each top-level step to ask a different question.

## Progressive disclosure

Do not remove volleyball terminology from VWM. Layer it.

1. **Label:** plain tactical term for knowledgeable players.
2. **Description:** consequence in ordinary language.
3. **Preview:** visible volleyball example.
4. **Optional detail / encyclopedia:** technical explanation, terminology and deeper consequences.

The intended learning sequence is:

> **See it. Choose it.** — character creation  
> **Understand it.** — encyclopedia / optional detail  
> **Learn when it works.** — simulation and management

---

# Tactical concepts deliberately moved out of 02 — VOLLEYBALL

## Attack distribution

`Middles / Spread / Pins` should not be an opening identity question. It is important, but it should be decided after seeing the squad. The manager's attack volume should emerge from philosophy, personnel, setter, matchups and later tactical implementation.

## Tactical freedom / player autonomy

How strictly players follow a plan versus solve situations themselves affects coaching, development and relationships as well as rallies. It belongs with management/club identity rather than being another opening tactical axis.

A future management choice could distinguish:

- **Defined roles** — clear responsibilities executed consistently.
- **Guided freedom** — a structure with permission to solve developing situations.
- **Player-led decisions** — greater authority to depart from the plan when players see a better solution.

## Specialists versus versatility

This is important enough for character/club identity precisely because it extends beyond tactics. It affects recruitment, development, substitution philosophy, retraining, staff recommendations and the club's eventual reputation.

A future management choice could distinguish:

- **Specialists** — narrow responsibilities and exceptional ability within them.
- **Role flexibility** — players cover neighboring responsibilities when needed.
- **Versatile players** — players are developed/recruited to contribute across several roles and situations.

These choices should not be hidden stat bonuses. They should influence what the club attends to and how its behavior is described, while repeated actual decisions eventually matter more than what the player declared during creation.

---

# 03 — ORIGIN / PLACE

The existing builder asks tier first and then region. That remains a strong structure because major/minor status is one of the largest facts about a save.

A manager's **home region** and **working/club region** should ultimately be separate. A Landavoli managing in Taktikã is an ordinary and interesting career position. `CareerManager` already stores manager region separately from career/club region, but the live creation UI currently uses one selection for both.

Region affects naming traditions and can eventually contribute a small scouting-familiarity term for volis from the manager's home region. It should not become a manager stat bonus.

The region picker should now reuse the regional montage/profile system described under VOLLEYBALL rather than relying primarily on compressed signatures such as `work · tempo` or `first contact`.

The PLACE-context profile should answer:

- What does volleyball here tend to look like?
- Is this a major or minor region?
- What is the club/institutional landscape?
- Is there a regional academy/Sixnet pathway?
- What does beginning a career here mean?
- How familiar or unfamiliar is the manager's chosen volleyball in this tradition?

Alignment is a starting relationship, not a correctness score.

---

# 04 — FOUNDATION / CLUB

The current distinction remains useful:

- **Take over a club** — inherit a squad somebody else built and an institution already in motion.
- **Found your own** — begin with less standing/resources and a younger/newly assembled organization.

Academies are regional representative selectors and are not player-managed clubs. Character creation must not regress to an academy-versus-club choice.

The stated design that founding is the hard route associated with major-region opportunity should be reconciled with implementation: the live builder has historically exposed both Established and Founded regardless of region unless separately guarded.

---

# 05 — MANAGEMENT

This is the missing identity dimension after separating tactical volleyball from broader club philosophy.

The key question is:

> **How do you actually manage your working life and what kind of institution do you try to build?**

This page should eventually cover broad principles rather than a long checklist during onboarding. Likely dimensions include:

- personal involvement / delegation default;
- tactical freedom / player autonomy;
- specialists versus versatility;
- a small number of professional managerial principles such as long-term development, wellbeing, continuity, direct communication, staff trust, opportunities for overlooked volis, institutional investment, or curiosity about other volleyball cultures.

A useful broad responsibility default remains:

- **Hands-on** — bring routine decisions to me; I want to see how the club works.
- **Together** — staff advise me; bring decisions that matter.
- **Trust my staff** — handle routine work; bring exceptions, uncertainty and important moments.

These are presentation/delegation defaults, **not difficulty modes**. Fine-grained staff responsibilities belong in the club interface later.

Management principles should primarily affect information surfacing, staff recommendations, expectations, relationship interpretation and how the manager's history is described. Repeated behavior should eventually outweigh declared creation principles.

---

# 06 — SIGNATURE

The final review names the career/organization and summarizes the person, volleyball, place, club and management choices the player has made. It should not reduce the completed volleyball identity back into seven unexplained numeric axes.

A short deterministic description or title may summarize the strongest tendencies, but the individual choices remain inspectable.

---

# Where the manager appears

Answering `who am I` matters only if the answer survives creation.

- **The journal is yours.** It should identify the person keeping it, not only the club.
- **The board is in your hand.** Tactical marks belong to the manager the player created.
- **Volis and other managers address you.** Textual interactions can use the manager's identity.
- **Declared principles become history only through behavior.** The world should eventually notice whether the manager actually acts consistently with the identity they selected.

---

# Implementation status / seams

- `ManagerProfile` exists and carries region, background, name and appearance.
- `PlayerActor3D` already provides the manager appearance pipeline.
- The live new-career builder currently uses five top-level steps: YOU, PHILOSOPHY, ORIGIN, FOUNDATION, SIGNATURE.
- The current philosophy implementation uses seven continuous `TeamPrinciples` axes and preset shortcuts. The redesigned six-question VOLLEYBALL sequence should translate player-facing answers into simulation principles rather than exposing one slider per question.
- Exact numerical mappings from the six answers should be designed **after** the question set, so implementation does not force the player-facing questions back into the old seven-axis shape.
- Region-following philosophy behavior and regional alignment are useful existing seams and should be retained/reinterpreted rather than discarded.
- Manager home region and working region are already separately representable in career state, but the second picker is not built.
- Manager-region scouting familiarity is planned but not built.
- Background effects are designed but not fully built/asked in the live UI.
- Management principles/responsibilities are design work, not yet claimed as implemented.

# Deliberately unresolved

- Exact mappings from Q1–Q6 answers into `TeamPrinciples` and any future tactical dimensions.
- Final wording for Q4 and Q5 labels; their tactical distinctions are settled, their copy is not.
- Whether MANAGEMENT is a separate top-level page or folded into FOUNDATION if it remains sufficiently small.
- Whether the manager ages, retires, or can be sacked; those depend on longer-term career/board structure.
- Whether background is visible to other clubs and affects willingness to work with the manager.
- Whether later saves in the same persistent world can introduce a different manager.
