# Filling the six, and drawing what connects them

Two questions from the lock-in board, neither of which should be built yet, and
one of which cannot be.

## 1. The manager who does not want to place six cards

The ask: a way to fill a lineup for players who do not want to make the micro
decisions — without it becoming either **optimisation** or **crude
simplification**. Both traps are real and they are the same trap from two ends:

- An *optimise* button deletes the decision. If there is a best six and the
  game knows it, then placing cards was never a decision, it was data entry
  the game was making you do.
- A *simple mode* says the decision did not matter. It teaches a manager that
  the thing this screen exists for is optional, which is worse than not having
  the screen.

### The way out is that there is no best six

The axes genuinely conflict. `RotationStrength` measures it: on the seeded six,
the rotation with the best block (R2, 69.7) is not the one with the best floor
(R5/R6, 75.0), and Setting / Control peaks in R1 where Block is middling. You
cannot have all of them, and **that is what makes a lineup a decision rather
than a puzzle**.

So the board should not answer *what is the best six*. It should answer *what
is the six if you want this* — and then say what it cost.

> Strongest blocking pair → Ivo and Toma at the net together
> Block 66.0 → 71.4 · Floor 71.8 → 66.9 · exposure 4.0 → 6.8

That is not optimisation, because there is no single objective being maximised;
it is a menu of objectives that trade against each other. And it is not
simplification, because the cost is printed. A manager who uses it every week
still learns the shape of the trade — arguably faster than one placing cards by
hand, because the counterfactual is right there.

### The unit is a **constraint**, not a lineup

This is the part worth getting right, and the prompts in the original ask
already have it: *"strongest blocking pair"*, *"strongest back row trio"* are
not lineups. They are **partial commitments**, which is the shape a real
coaching decision takes — a coach decides who blocks together and lets the rest
follow.

Constraints are the better unit on every count:

| | a generated lineup | a constraint |
|---|---|---|
| what it takes from you | the whole decision | one part of it |
| what it teaches | nothing; it is an answer | the cost of that one choice |
| composability | replaces itself | stack two or three and stop |
| when it is wrong | you undo all of it | you drop one and keep the rest |

So the section is a short list of things you can **pin**, and the board fills
the rest around whatever is pinned. Pin nothing and it is a suggestion engine;
pin everything and you have placed six cards by hand; the interesting use is in
between, which is where a manager who does not want to micro-manage actually
lives.

### And the pin that makes it strategic rather than clerical

**"Strongest blocking pair" is not a question about two volis. It is a question
about how often they are at the net together.**

Under a cyclic rotation, two volis pinned to *adjacent* slots share the front
row in four rotations of six. Pinned *opposite* each other, they are never both
at the net — you get a competent wall in all six rotations and a great one in
none. Same two players, opposite strategies, and the difference is visible in
the spread row that already exists.

That is the whole argument for building this on top of `RotationStrength`
rather than beside it. The constraint is not *who*; it is *who, together, and
how often* — and the second half is a real strategic choice with a number
attached.

### On the name

"Roster Customization" is accurate and belongs to a different object — it is a
settings-menu phrase, and this board is a whiteboard, not a preferences pane.
In the board's own voice the section is the thing you write in the corner
before you fill in the slots. **"Fill the six"** sits beside "Lock in the six"
and says what it does. The prompts themselves are the interface; they do not
need a category heading that is grander than they are.

## 2. Lines between markers, the way a tactical board draws partnerships

### It cannot be built, and that is the finding

There is **no player-to-player quantity in the model at all**. What exists:

- `VolleyballPlayer.position_familiarity` — a voli and a *slot*
- `Team.tactical_familiarity` — one number for the whole squad

Nothing connects two volis. So lines would not be visualising a relationship;
they would be inventing one and then drawing it, which is the failure mode this
repository has a document about. A line between two markers is a claim, and
right now the claim would have no referent.

### But it would read, if there were something to draw

The worry — *does it work with only six markers* — resolves once you notice
that volleyball's connection graph is not free-form. Six markers admit fifteen
pairs and drawing fifteen edges is a hairball. Volleyball does not want fifteen:

- **setter → hitter**, which is the connection that decides sets, and which is
  a *star*: one centre, three front-row spokes
- **the blocking pair**, which is adjacency at the net: two edges

That is five lines on six markers, and it reads.

The reason it reads is the constraint that makes it true: **draw one rotation at
a time.** The abstract six is a hairball; a rotation is a star plus a net pair.
And stepping R1 → R6 and watching the star change shape is the clearest
possible statement of what rotation order *is* — which is exactly what the
rotation panel says in numbers and cannot say in a picture.

### So the order of work is the reverse of the ask

1. **A pair quantity first.** The cheapest honest one is setter–hitter
   familiarity: a per-pair figure that grows when they play together and decays
   when they do not. It has somewhere to go immediately — `SETTER_DECISION.md`
   already weighs who to set, and "who this setter has actually been setting"
   belongs in that weighing.
2. **Then lines, per rotation**, on the court diagram that already exists.
3. **Then the same lines in the tactical planner**, where they answer a
   different question: not *who does my setter reach* but *who am I asking to
   work together this week*.

Drawing the lines first would produce a picture of nothing, and a picture of
nothing is very hard to notice being wrong.
