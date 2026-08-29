# Character and save creation

Who the manager is, what volleyball they value, where they come from, what institution they enter, how they intend to manage, and how that completed start becomes a save.

This file is the canonical character/save-creation specification. Focused addenda should be folded here rather than allowed to diverge.

## Core rules

Character creation establishes **preferences and starting circumstances, not commandments or manager stat bonuses**. The player should be able to make meaningful choices without already knowing volleyball terminology. Technical depth remains in the simulation; creation teaches the visible ideas behind it.

The interaction should match the kind of thing being chosen:

- **Distinct alternatives** → cards.
- **Continuous tendencies** → stepped controls.
- **Places** → map/list navigation.
- **Existing institutions/opportunities** → factual profiles.
- **Appearance** → direct editor.
- **Finalization** → review and confirmation.

Consistency comes from the visual language, factual voice and causal rules, not from forcing every section into the same three-card questionnaire.

UI voice follows one rule:

> **The game asks plainly. The player may answer conversationally. The world reports what is true.**

Player-owned actions may therefore say things such as `Yup, this is me!`, `That sounds right.`, `Yup, this is home.`, `I'll start here.`, `Show me the openings.`, `Let's build one.`, `I'll take the job.`, `Yup, that's how I'll manage.`, or `Let's get to work.` World/UI description should remain concrete and should not synthesize facts into emotional or strategic meaning on the player's behalf.

The settled top-level character-creation flow is:

1. **YOU** — appearance, background and professional standing.
2. **VOLLEYBALL** — six visible tactical preferences.
3. **PLACE** — home region and working region.
4. **CLUB** — inherit an existing institution or found a new one.
5. **MANAGEMENT** — three starting management tendencies.
6. **SIGNATURE** — review, light personalization and final confirmation.

A separate minimal **SAVE SETUP** follows the completed character start. It handles save/session facts, not manager identity.

`Surprise me!` may appear where randomization is meaningful. It should select a real option, reveal it, and never auto-advance. VOLLEYBALL may randomize one question or all six; other creation steps may use the same pattern where appropriate.

---

# 01 — YOU

## 01A — Who are you?

The manager uses the same `PlayerActor3D` visual language as volis. The editor exposes:

- manager name;
- body type;
- Vegi variety where applicable;
- colourway;
- coat/marking;
- face;
- height;
- arm proportion;
- leg proportion;
- handedness.

Appearance is visual only. Manager geometry never enters the volleyball simulator.

### Canonical viewer reuse

The appearance editor must reuse the **roster screen's manually rotatable voli viewer** rather than creating a character-creation-only preview surface.

The roster viewer is the canonical body-inspection interaction. Character creation should instantiate the manager actor inside that same viewer and place the appearance controls around it.

Required behavior:

- manual drag/rotation exactly as the roster viewer supports it;
- the same camera framing and body-scale assumptions unless creation genuinely needs an additional framing mode;
- live update as appearance parameters change;
- no separate auto-spin-only preview implementation;
- no duplicate character-rendering path that can drift from roster presentation.

If the roster viewer later gains zoom, camera presets, lighting improvements or other body-inspection features, character creation should inherit them wherever appropriate.

The two limb axes are proportions rather than independent measurements so their visual character survives height changes. The UI must respect the rig's real clamps rather than exposing slider ranges that silently collapse to the same body.

Home region is not selected until PLACE, so 01 must not silently choose geography merely to generate a name. Manual naming works immediately. Regional-name suggestions can become available after HOME is known if the field is blank or the player requests them.

Confirmation: **Yup, this is me!**

## 01B — What did you do before this?

Background defines the **kind of prior knowledge and relationships** the manager has. It is not a competence bonus.

### You played

Prior information leans toward players, competitive relationships and people known through playing.

### You coached

Prior information leans toward training histories, staff relationships, development context and coaching contacts.

Use `You coached`, not `You coached youth`, unless a real youth structure later gives the narrower distinction mechanical meaning.

### You analysed

Prior information leans toward match records, tactical observations and broader but less-personal club/team knowledge.

### You're new to this

No prior professional volleyball career. This is a genuine outsider/journeyman-style harder start rather than a disguised equal alternative.

A newcomer may begin with:

```text
Professional standing     None
Existing contacts         Very few
Prior volleyball records  None
Job access                Limited

A harder way to begin.
```

Do not compensate with a hidden bonus merely to equalize starts. The human player may be new to volleyball without choosing this fictional background; `You're new to this` is a roleplay/career-position choice, not an onboarding mode.

Suitable confirmation: **I'm okay with that.**

`You paid for it` is removed from biography. Founding belongs in CLUB and professional standing is distinct from club capital.

## 01C — How established were you?

Played, Coached and Analysed reveal a stepped control:

```text
●──────────●──────────●
Obscure    Known      Established
```

### Obscure

A legitimate career with little wider recognition: few relationships, narrow prior information, lower-status openings and little portable reputation. This does not imply low competence.

### Known

The default middle position: some contacts, ordinary recognition, a normal vacancy range and moderate prior information.

### Established

A broad professional network, wider credible information, stronger openings and potentially greater institutional expectations. It does not improve tactical decision-making by fiat.

The decomposition is:

```text
BACKGROUND → what kind of prior knowledge/relationships exist
STANDING   → how broad the network, reputation, information and job access are
```

Background and standing affect what the manager plausibly knows and who plausibly knows them. They must not regenerate or alter an existing club to fit the player. The world exists before the manager arrives.

`Surprise me!` may randomize background + standing and reveal the result before confirmation.

General confirmation: **That sounds right.**

---

# 02 — VOLLEYBALL

## Purpose

VOLLEYBALL asks what the player's volleyball should look like before they have met a squad. It uses six nested visual questions rather than exposing abstract simulation axes directly.

Each page contains:

- one plain tactical question;
- three distinct choices;
- a short accessible description;
- a selectable looping visual preview;
- explicit confirmation before advancing.

Selection changes the demonstration but does not auto-advance.

## Preview authority

Individual answer previews are **authored deterministic volleyball vignettes**, not randomly generated rallies.

Their job is to teach one tactical distinction clearly. They may exaggerate unlikely but legal situations, provided they preserve physical and legal volleyball.

Author circumstances and tactical decisions, not fake physics:

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

The rule is:

> **Preset previews exaggerate tactical decision while preserving volleyball legality.**

Production actors, court, animations, ball physics and ideally production simulation vocabulary should be reused. Character creation must not become a second puppet-animation interpretation of volleyball.

## Q1 — Good-ball attack

**Question:**
> Your team gets a good first touch. How should they attack?

### Quick attacks
Attack quickly, before the defense has time to organize.

Preview: a clean reception gives immediate access to a fast attack that arrives before the block is fully formed. **Time created the advantage.**

### Read the blockers
Watch how the block develops, then attack the space it leaves open.

Preview: several threats remain credible; the block visibly commits toward one and the setter releases elsewhere. **Information created the advantage.**

### Trust your hitters
Create favorable matchups and let your attackers beat the defense.

Preview: the defense has not made a glaring mistake. The setter creates or recognizes a favorable contest and lets the hitter solve a formed but beatable block. **The matchup and hitter created the advantage.**

Attack distribution (`Middles / Spread / Pins`) is deliberately not chosen here. Volume belongs downstream of actual roster, setter, matchup and tactical implementation.

## Q2 — Serving

**Question:**
> How should your team serve?

### Controlled serves
Prioritize keeping the serve in and making the opponent play the rally.

### Target the reception
Serve into difficult spaces and toward receivers you think you can disrupt.

### Aggressive serves
Accept more serving errors for a better chance of forcing poor reception or winning immediately.

These are not low / medium / high power. They distinguish reliability, targeting/information and high-risk direct pressure. `Target the reception` is a different objective, not the midpoint between controlled and aggressive serving.

An aggressive preview should make the tradeoff visible, potentially by showing one pressure result and one miss rather than presenting aggression as simply superior.

### Pre-serve presentation backlog

A viewed rally should eventually include the lead-up to serve:

- players settle;
- the server receives/holds the ball;
- waits for the referee whistle;
- performs an individual serve routine after the whistle;
- moves naturally into toss/approach/contact.

Serve routines may differ by bounce count, pause length, breathing/reset behavior, preparation and approach habits. These are presentation/character traits, not hidden outcome modifiers. Presentation speed/skip must keep routine rally pacing manageable.

## Q3 — Defense

**Question:**
> How should your team defend attacks?

### Floor defense
Use the block to guide attacks toward spaces defenders are prepared to cover.

Canonical preview: a well-shaped double removes the hitter's preferred space while intentionally conceding a weaker route to a waiting floor defender. The lesson is that **the block did not fail; it made the attack predictable.**

### Read the attack
Preserve information and allow blockers/defenders to adjust before committing.

### Commit the block
Send blockers aggressively toward the expected attack and try to stop it at the net.

A contrasting example may show early commitment punished when the setter goes elsewhere. All competent versions still use blocking and floor defense; the distinction is where the system spends commitment.

## Q4 — Transition offense

**Question:**
> Your team keeps a difficult attack alive. What should happen next?

### Reset the play
Use the next touches to regain control and structure before asking for another difficult attack.

### Find the opportunity
Attack when the developing defensive situation gives a useful option, without forcing one that is not there.

### Attack in transition
Look to turn defensive touches into attacks as quickly as possible.

The previews should begin from comparable difficult defensive origins so the continuation, not the quality of the dig, explains the difference.

**Copy note:** exact Q4 labels may still receive wording polish; the tactical distinction is settled.

## Q5 — Imperfect first contact

**Question:**
> The first contact pulls your team out of position. How should they respond?

### Recover the structure
Prioritize restoring enough shape to run a controlled, recognizable attack.

### Use what's available
Adapt the attack to the players and spaces the first contact actually leaves available.

### Keep the pressure on
Accept a more difficult attacking situation rather than giving the opponent an easy ball back.

This differs from Q4: Q4 begins with defense/transition; Q5 begins with serve reception disrupting intended side-out offense.

**Copy note:** exact Q5 labels may still receive wording polish; the tactical distinction is settled.

## Q6 — Offensive construction

**Question:**
> How should your attacks create opportunities?

### Combination offense
Use multiple attacking threats together to move, occupy or confuse the block.

### Flexible offense
Keep several options available and choose the attack that develops best.

### Isolation offense
Create a favorable one-on-one or one-on-two opportunity and let the hitter solve it.

Q6 describes how threats are structurally related, not which position receives the most sets.

## Completed-volleyball showcase

After Q1–Q6, show a short **YOUR VOLLEYBALL** montage. Unlike the individual teaching vignettes, this may use deterministic procedural simulation to combine the selected tendencies.

The montage does not promise success. An aggressive-serving identity may legitimately show a damaging serve and a miss. Character creation shows what the manager values; the simulation decides what happens.

A suitable confirmation is **Yup, that's my volleyball.**

## Regional tactical presets

Regional tactical identities are weighted tendencies/distributions, not six absolute questionnaire answers and not character classes.

Information hierarchy:

1. **Regional tradition** — broad, relatively stable public knowledge.
2. **Club identity** — regionally influenced but historically/managerially variable.
3. **Current match tactics** — volatile and learned from current evidence.

During Q1–Q6, regional examples are optional secondary information. After Q6, an action such as **See how the regions play** may introduce the world map before PLACE.

Do not collapse correspondence into a quality or fit score. Tactical familiarity and geographic distance are separate facts.

## Progressive disclosure

Do not remove volleyball terminology from VWM. Layer it:

1. **Label** — plain tactical term.
2. **Description** — consequence in ordinary language.
3. **Preview** — visible volleyball example.
4. **Optional detail / encyclopedia** — technical explanation and deeper consequences.

The learning sequence is:

> **See it. Choose it.** — creation  
> **Understand it.** — optional detail / encyclopedia  
> **Learn when it works.** — simulation and management

---

# 03 — PLACE

Major/minor classification remains visible for both home and working-region selection. Major/minor describes institutional/economic status, not geographic size and not Sixnet eligibility.

Use a reusable rotatable world map/globe long-term, plus an accessible grouped Major/Minor list. The current calculated/topographical map may remain a development seam rather than being mistaken for final world geography/art.

## 03A — Where are you from?

Selecting a region recenters the world surface and opens the regional profile/montage.

Confirmation: **Yup, this is home.**

## 03B — Where does your career begin?

Reuse the same map with HOME visibly marked. There is no separate `begin at home` action; choosing HOME again naturally means staying there.

Before the player confirms a working region, show vacancy facts:

```text
SPËDDIGH
Major region

Open manager positions      3
Open to your standing       1
```

Current solution: the player chooses the region in which they intend to begin and then sees actual viable vacancies in CLUB.

Long-term target: support a genuinely unemployed start in which the manager searches/applies dynamically across the world.

Confirmation: **I'll start here.**

After HOME and WORK are selected, expose **geographic distance** and **tactical familiarity** separately. Geographic distance should eventually derive from actual world geography; tactical familiarity derives from Q1–Q6 compared with weighted regional tradition. Do not infer culture, language, comfort or emotional meaning from distance unless those systems actually exist.

The same world surface should later support encyclopedia browsing, transfers, visits, Sixnet/academy geography and records.

---

# 04 — CLUB

CLUB asks how the manager enters an institution:

> **A job opening asks which institution you are willing to inherit. Founding asks what institution you are willing to begin.**

Academies are regional representative selectors, not player-managed clubs. Creation must not regress to an academy-versus-club route.

## 04A — Entry route

Where both routes exist:

### Look for a job
Start as manager of an existing club.

Action: **Show me the openings.**

### Found a club
Start a new institution in the selected region.

Action: **Let's build one.**

If founding is unavailable in a particular context, do not show a dead disabled option merely to explain its absence.

---

# 04J — EXISTING-CLUB / JOB ROUTE

## 04J-1 — Job openings

Question:
> **Where do you want to work?**

The player chooses among actual managerial vacancies compatible with region and professional standing, not every club in the region.

A vacancy profile should report facts in distinct areas.

### Vacancy identity

Club, region, vacancy status and, where world history supports it, reason/duration of vacancy.

### SPORT

Measured sporting position: circuit/competition standing, interregional record, regional-strength contribution, academy selections or other settled competition metrics.

A club contributes evidence toward regional standing; the club itself does not qualify for Sixnet.

### CLUB

Operating condition: finances, contracted squad, roster depth, training facilities, staffing and other institutional resources.

### VOLI LIFE

Voli living conditions are first-class club metrics rather than flavor and should not collapse into one wellbeing score. Relevant dimensions include:

- food quality and, where useful, familiarity/variety;
- housing quality and privacy/crowding;
- free time;
- training load;
- medical/recovery/care provision;
- social structure, e.g. communal ↔ independent;
- stability of routines, housing and staff arrangements.

Some dimensions should create real tradeoffs rather than all improving monotonically with wealth: training time ↔ free time, private rooms ↔ capacity/cost, individualized food ↔ operational complexity, communal scheduling ↔ autonomy.

Different volis may value these dimensions differently.

### CLUB PRIORITIES

Separate what the institution values from what it currently achieves.

### BOARD EXPECTATIONS

Keep three concepts distinct:

```text
CURRENT CONDITION → what is true now
CLUB PRIORITY      → what the institution tends to value
BOARD EXPECTATION  → what the manager is accountable for
```

Expectations may be sporting, institutional or voli-living, but every displayed expectation must correspond to an actual measured/enforced system. Not every club is judged on every metric.

> **Club success is plural, but club expectations are specific.**

### Squad information

`View squad` shows names, ages, positions, contracts and public career information. It does not grant omniscient hidden ability/personality knowledge.

Background shapes the type of deeper evidence plausibly known; standing shapes breadth:

- Played → personal/player recognition and competitive relationships.
- Coached → development/staff knowledge.
- Analysed → match/tactical evidence.
- Established → broader coverage.
- Newcomer → mostly public facts.

### Club volleyball

Show current club tactical tendencies side-by-side with the player's Q1–Q6 preferences without synthesizing a verdict. The discrepancy itself is information.

### Accepting the vacancy

If creation guarantees the selected appointment, avoid `Apply for this job.` Use **I want this job.** for selection and a compact factual appointment review followed by **I'll take the job.**

Later career employment may use genuine applications/rejections once that system exists.

Do not ask the player to choose releases, transfer targets, starters or detailed tactical volume plans during creation. Those are first-day management decisions.

---

# 04F — FOUNDING ROUTE

Founding should not become a giant facilities/economics questionnaire or begin with a nonfunctional blank club. The player chooses a few consequential circumstances/priorities; the world generates a viable but imperfect institution from them.

The club must begin with enough volis, staff and infrastructure for normal club loops to function. Difficulty comes from compromises, limited resources, thin depth, low standing and lack of history—not withholding core gameplay.

## 04F-1 — Starting place

WORK region is already known, so do not ask for region again. Offer a few legitimate generated founding situations/sites inside the region.

Each is a bundle of world facts rather than a facilities rating, potentially including:

- district/local location;
- available training space;
- accommodation availability;
- operating cost;
- travel position;
- local volleyball/institutional context.

Example:

```text
Vål district
Existing training hall
Shared accommodation available
Higher operating cost

North coast
Basic municipal court
Cheap housing
Longer travel

Tressa outskirts
Converted warehouse court
Moderate housing
Growing local volleyball scene
```

Long-term geography may make these richer; initial implementation only needs coherent generated situations.

## 04F-2 — Starting backing

Question:
> **How is the club starting out?**

Provisionally use a small discrete resource magnitude:

- **Bare start** — very limited resources, but core operations function.
- **Modest backing** — stable small-club resources.
- **Strong backing** — substantial initial financing/infrastructure.

Professional standing and club capital are separate. An Established manager can found a tiny club; an Obscure manager can have external backing.

Show factual consequences such as starting funds, training space, accommodation, care provision and staff capacity. No hidden bonuses.

### OPEN 04-1 — What does founding backing actually come from?

`Bare / Modest / Strong` is **not yet a complete institutional design**.

The source of backing may matter: civic/government support, private backing, member ownership, manager capital or another arrangement. Different sources may create different obligations, restrictions, expectations, persistence or risk.

The unresolved design question is:

> **Who or what is backing the club, and what does that support require in return?**

Do not implement `Strong backing` as a strictly dominant free-money option before this is resolved.

## 04F-3 — Early club priorities

This is the founding route's principal identity choice. Existing clubs inherit their conditions/priorities; a founder establishes the first allocation of scarce resources and attention.

Actual starting conditions derive from:

```text
starting site
+ backing/resources
+ selected priorities
→ feasible starting conditions
```

A priority directs resources/effort; it does not guarantee an `Excellent` rating.

### One sporting emphasis

Provisionally choose one:

- **Competitive results** — greater early emphasis on people/resources capable of winning now.
- **Player development** — greater emphasis on development and future representative value.
- **Squad continuity / sustainable building** — greater emphasis on retention, continuity and institutional stability.

These are priorities, not permanent club classes.

### Two living/institutional priorities

Choose two from a concise set such as:

- Good food
- Comfortable housing
- More free time
- Strong care
- Better training
- Privacy
- Communal club life

The preview should update projected VOLI LIFE conditions and expose tradeoffs. A Bare start prioritizing food might reach Good food while accepting shared housing/basic care. The same priority under stronger backing may achieve a higher condition.

There should be no universal rich-club endpoint where every dimension is maximized.

## 04F-4 — Initial squad and staff generation

Do not recruit an entire roster or hire every staff member during creation.

Generate a plausible founding squad from:

- region;
- site/resources;
- available/free-agent population;
- sporting priority;
- manager background, standing and network;
- selected volleyball;
- labor-market conditions.

The squad must be viable but imperfect, not an optimized translation of Q1–Q6.

The intended opening management problem is:

> **This is my volleyball. These are the people I've managed to assemble. How do I reconcile the two?**

Offer `View starting squad`. The player may go back/reroll the setup rather than drafting a full roster in onboarding.

Background affects the causal route by which people are known/available, not raw bonuses. Staff should be generated similarly: minimum viable coverage according to resources/network, with remaining vacancies exposed as early-game work.

## 04F-5 — Club identity

A founded club is named and visually constituted here. Existing clubs already have institutional identity and do not pass through a redesign step.

### Name

Allow manual entry plus regionally appropriate generated suggestions because geography is now known.

### Generated visual package

Generate a coherent lightweight package containing at minimum:

- primary colour;
- secondary colour;
- optional accent colour;
- crest;
- home kit;
- change/light kit.

Example:

```text
VÅL NYR VC

PRIMARY       [colour]
SECONDARY     [colour]
ACCENT        [colour]

CREST         [generated crest]
HOME          [generated kit]
CHANGE        [generated kit]

[ Reroll identity ]
[ Customize ]
```

`Reroll identity` regenerates the package coherently rather than independently randomizing unrelated parts.

Region must not deterministically assign club colours. Regional graphic traditions may exert a light influence, but clubs need substantial independent identities.

### Bounded customization

`Customize` should use a bounded parameter editor rather than an unrestricted image editor.

Potential controls:

**Colours** — primary, secondary, accent.

**Crest** — overall shape, central mark/symbol, division/pattern, border treatment, initials/name treatment where supported.

**Home kit** — base colour arrangement, trim/collar treatment, one major pattern family such as plain, stripe, panel, band or sleeve treatment.

**Change kit** — same grammar while guaranteeing sufficient distinction from home.

Shorts/socks or other garment elements should only become creation controls if they are visually meaningful in the actual match renderer.

The same identity parameters should drive production-facing club visuals wherever practical: match kits, standings, office signage, competition UI, club pages and other institutional surfaces. Avoid creation-only fake art disconnected from the production renderer.

### Existing clubs

A manager taking a job inherits the institution's name, crest, colours, kits and history.

Becoming manager does not automatically grant a redesign. A later new-kit cycle, crest modernization, anniversary identity, board-approved rebrand or ownership change may eventually exist as separate club-history systems.

### OPEN 04-2 — How deep should the crest/kit generation grammar be?

The structural direction above is settled. The exact reusable visual grammar is intentionally unresolved:

- number and shape of crest templates;
- symbol/mark families;
- pattern/division families;
- typography/initial treatment;
- kit pattern families;
- colour contrast/accessibility rules;
- amount of regional influence;
- whether shorts/socks are exposed;
- procedural anti-repetition/plausibility rules.

This should be designed as a reusable club-identity system rather than improvised inside character creation.

## 04F-6 — Founding review

Show the institution factually before creation:

```text
NEW CLUB

Vål Nyr VC
Spëddigh · Vål district

START
Backing             Modest
Training             Basic
Squad                10 volis
Staff                3 filled · 1 vacant

EARLY PRIORITIES
Player development
Good food
Free time

VOLI LIFE
Food                 Good
Housing privacy      Low
Free time            Good
Training load        Moderate
Care                 Basic

VOLLEYBALL
[Q1–Q6 summary]

[ View squad ]
[ View club ]
```

Confirmation: **Let's start this club.**

Founding priorities are not permanent promises. They establish initial allocation, conditions, reputation and historical origin. Repeated managerial behavior should eventually outweigh the founding declaration.

---

# 05 — MANAGEMENT

Purpose:

> **How do you want to manage?**

MANAGEMENT does not define tactics, biography, club resources or a permanent personality class. It defines three starting tendencies that may seed defaults and expectations while later behavior remains authoritative.

These are continuous tendencies, so use five-position stepped controls rather than three categorical cards or branching submenus. The UI names the two endpoints and midpoint; intermediate positions mean `leans toward`, not additional archetypes.

Internally values may be something like `0 / .25 / .5 / .75 / 1`; do not author 125 bespoke manager classes from the 5³ possible numeric combinations.

## 05A — Structure and autonomy

Question:
> **How much structure do you give your volis?**

```text
Defined roles
●────●────●────●────●
                  Player-led decisions

            Guided freedom
```

- **Defined roles** — stronger expectation that players follow assigned responsibilities and established solutions.
- **Guided freedom** — clear framework with room for situational interpretation.
- **Player-led decisions** — greater expectation that volis use their own judgment within the team's overall approach.

Possible downstream systems: instruction interpretation, role training, coaching language, player latitude and reactions to repeated overrides. No hidden global bonus.

## 05B — Squad construction

Question:
> **What kind of squad do you want to build?**

```text
Specialists
●────●────●────●────●
                  Versatile players

            Role flexibility
```

- **Specialists** — preference for clearly defined role-specific strengths.
- **Role flexibility** — preference for useful adjacent-role coverage.
- **Versatile players** — preference for broad role coverage/adaptability.

Possible downstream systems: recruitment recommendations, scouting filters, retraining suggestions, bench construction, substitution options, contract valuation and evolving roster identity.

## 05C — Responsibility and delegation

Question:
> **How much do you keep in your own hands?**

```text
Manager-led
●────●────●────●────●
                  Delegated

        Shared responsibility
```

- **Manager-led** — manager retains more day-to-day sporting/institutional decisions; staff primarily advise.
- **Shared responsibility** — manager and staff divide responsibility more evenly.
- **Delegated** — department leads/trusted staff are expected to own more operational work.

This seeds the later responsibilities system; it does not replace it.

## Responsibilities belong in-game

Character creation defines **preference**. The live club screen defines **assignment**.

A responsibilities screen may include:

```text
RESPONSIBILITIES

Training schedule          Manager
Individual development     Assistant coach
Recruitment shortlists     Scout
Contract discussions       Manager
Medical return-to-play     Medical staff
Accommodation issues       Operations
Media                      Manager
```

05C may preconfigure valid defaults:

- Manager-led → more manager-owned responsibilities.
- Shared → mixed distribution.
- Delegated → more work assigned to competent existing staff.

The player may change these immediately. Creation must not promise delegation to nonexistent staff; a Bare-start founder may need to retain tasks despite a delegation preference.

General rule:

> **05 defines preference. The club screen defines assignment.**

## Behavior outweighs declaration

All three MANAGEMENT choices establish starting tendencies, recommendations/defaults and perhaps early expectations. They are not permanent personality tags.

A manager who selects Player-led decisions but repeatedly intervenes should eventually be understood through those interventions. A manager who selects Delegated but takes every responsibility back should not remain permanently described by the creation choice. Likewise, a Specialists preference can later become a versatile roster through actual decisions.

A suitable confirmation is **Yup, that's how I'll manage.**

---

# 06 — SIGNATURE

SIGNATURE is the shortest character-creation section. It does not introduce another tactical, biographical, institutional or managerial axis.

Purpose:

> **review, personalize lightly, confirm, enter the world.**

## 06A — Final identity check

Show manager and institution together.

Founder example:

```text
[ manually rotatable manager viewer ]

MANAGER NAME
Founder / Manager

HOME
Bompaçao

WORK
Spëddigh

CLUB
Vål Nyr VC

[ crest ]
[ home kit ] [ change kit ]
```

For an existing-club start, use `Manager` and display the inherited club identity.

This is a review surface, not another editor. Return to earlier controls through explicit edit navigation.

## 06B — Starting profile

Condense meaningful choices into factual labels:

```text
BACKGROUND
Former analyst
Known

VOLLEYBALL
Quick attacks
Target reception
Read the attack
Attack in transition
Use what's available
Combination offense

MANAGEMENT
Structure         Guided
Squad building    Specialist-leaning
Responsibility    Shared
```

Do not synthesize this into authored prose such as `A thoughtful, flexible tactician.` If save files or encyclopedia pages need shorthand, derive it from explicit labels rather than invented personality narration.

## 06C — Edit shortcuts

```text
[ Edit YOU ]
[ Edit VOLLEYBALL ]
[ Edit PLACE ]
[ Edit CLUB ]
[ Edit MANAGEMENT ]
```

Edits that invalidate downstream choices must be handled explicitly. Changing WORK region may invalidate a vacancy or founding site; impossible downstream selections must not be silently preserved.

## 06D — Optional non-mechanical details

SIGNATURE may host lightweight optional presentation details such as manager signature/mark, club motto or preferred short club name where applicable. Keep them non-mechanical.

Save naming is primarily a SAVE SETUP concern below rather than a new character-identity axis.

## 06E — Confirm the start

This confirms an already-complete character/start. Plain **Start career** is acceptable; conversational player-owned language such as **I'm ready to begin.** or **Let's get to work.** is also valid.

No additional philosophy question belongs here.

---

# SAVE SETUP — minimal session/world setup

SAVE SETUP is separate from the six character-creation sections.

Core rule:

> **Character creation chooses the manager and starting circumstances. Save setup chooses save/session facts. The first day handles actual club management.**

Do not turn save setup into a second game-design questionnaire.

## Canonical world start

New saves should begin from the same canonical world date/state unless the game later intentionally supports alternate starts.

The world itself may contain seeded variation, but the player should not need to configure a large procedural-world panel before playing. Canonical institutions, regional structure, competition framework and start date remain recognizable across saves; a seed can control bounded generated details where generation is appropriate.

This preserves a shared VWM world while still allowing reproducible variation.

## Save name

Auto-generate a useful name from existing facts, for example manager + club + season/year, and allow editing.

The save name is metadata, not world fiction and not a gameplay choice.

## Seed / reproducibility

Every save should have a reproducible seed whether or not the normal UI emphasizes it.

Default behavior:

- generate a seed automatically;
- keep it visible in an **Advanced** disclosure or save details;
- allow copy;
- allow manual entry before starting when the player deliberately wants to reproduce/share a start.

The seed should govern only systems that are actually seed-driven. It must not falsely imply that authored world facts are random.

This is especially useful for testing, bug reproduction and sharing starts.

## No generic difficulty selector by default

Do not add an opaque `Easy / Normal / Hard` setting simply because save setup exists.

Career difficulty already emerges from visible causal choices and world facts: newcomer status, professional standing, vacancy quality, founding backing, club condition, roster depth and other modeled circumstances.

If the game later needs accessibility, forgiveness or simulation-assistance settings, expose the specific behavior being changed rather than hiding several unrelated changes under one difficulty label.

## Presentation/preferences are not save identity

Match presentation speed, audio, graphics, accessibility options and similar preferences should normally remain global/user settings rather than being treated as immutable facts about one career.

Autosave policy may be configured near save creation if useful, but should still be understood as a save-management preference rather than a character/world choice.

Do not ask the player to choose tactical responsibilities, lineups, recruitment targets, housing responses, staff assignments or other real club decisions here. Those belong after the world becomes live.

## Minimal screen

A minimal implementation can therefore be:

```text
SAVE SETUP

Save name
[ Ira Carranza — Vål Nyr VC — 2026 ]

World start
Canonical start

[ Advanced ▸ ]
  Seed    7F3A-19D2-...
  [ Copy ] [ Enter seed ]

[ Begin career ]
```

This is intentionally small.

---

# Transition into Day 1

After final confirmation and SAVE SETUP, enter the actual club world rather than another onboarding wizard.

The first live day should expose real consequences of the chosen start:

- inherited or generated squad;
- actual staff and vacancies;
- board expectations where applicable;
- VOLI LIFE conditions;
- current facilities/resources;
- current club tactics versus the manager's preferences;
- responsibilities that are currently assigned and changeable;
- immediate calendar/competition obligations.

The player can then make real management decisions in context.

This is a hard boundary: creation declares starting identity/circumstances; live play changes the institution.

---

# Where the manager appears

Answering `who am I` matters only if the answer survives creation.

- **The journal is yours.** It identifies the person keeping it, not only the club.
- **The board is in your hand.** Tactical marks belong to the manager the player created.
- **Volis and other managers address you.** Text interactions can use the manager's identity.
- **The same manager body is viewable consistently.** Character creation and roster-style inspection use the same rotatable viewer language.
- **Declared principles become history only through behavior.** The world eventually notices what the manager actually does.

---

# Implementation seams / status

- `ManagerProfile` exists and carries manager identity data including region/background/name/appearance.
- `PlayerActor3D` provides the manager appearance pipeline.
- The roster screen's manually rotatable voli viewer should be reused as the canonical 01 appearance viewer rather than duplicated.
- The live new-career builder historically used fewer top-level steps and older philosophy/background assumptions; this document describes the intended redesigned flow, not a claim that every step is already implemented.
- The current/older philosophy implementation uses `TeamPrinciples` axes and preset seams. Q1–Q6 should translate into simulation principles without exposing one raw axis per question.
- Exact mappings from Q1–Q6 into simulation values should be designed after the player-facing questions and should not force the UI back into the old axis shape.
- Manager home region and working region are separately representable in career state; the full two-picker UI remains an implementation seam.
- Regional alignment/familiarity should be retained as information, not converted into a correctness score.
- Background/standing should affect evidence, network and job access rather than manager-stat bonuses.
- MANAGEMENT is structurally settled; exact thresholds/default strengths remain tunable.
- SAVE SETUP should remain thin even if the underlying save metadata grows.

# Explicitly unresolved

These items remain intentionally unresolved and should not be silently filled in during implementation:

1. **OPEN 04-1 — founding backing source and obligations.** Who/what provides backing, and what does it require in return?
2. **OPEN 04-2 — crest/kit generation grammar depth.** Exact crest templates, marks, pattern families, contrast rules, regional influence, garment scope and procedural anti-repetition rules.
3. Exact mappings from Q1–Q6 into `TeamPrinciples` and any future tactical dimensions.
4. Final wording polish for Q4 and Q5 labels; their tactical distinctions are settled.
5. Exact five-step numeric implementation/threshold effects for MANAGEMENT.
6. Whether the manager ages, retires or can be sacked; those depend on longer-term career/board structure.
7. Whether background is visible to other clubs and affects willingness to work with the manager.
8. Whether later saves in the same persistent world can introduce a different manager.

The character-creation structure itself is otherwise considered settled enough to implement and iterate visually.