# Accommodations: food, flavour, and lodging

Draft. Nothing here is built. This is the design being written down while the
simulation work it sits on top of is still in flight, so that when it is built
the shape is already argued rather than improvised.

## Why this exists at all

The player-facing case for this game is not that the volleyball model is
correct. It is that these are *your* players. The body-type work — Feli, Avi,
Vegi and the produce silhouettes — is the first thing that spent design budget
on making a roster feel inhabited rather than tabulated. Accommodations is the
second: a system whose entire output is *how the people you are responsible for
are living*.

That framing sets a hard constraint on the mechanics below. **Every number in
this system must be legible as care or neglect.** A player is not a stat block
receiving a nutrition modifier; they are someone who has been eating the same
grey paste for six weeks and has started to mind. If a mechanic cannot be read
that way at the table, it does not belong here — it belongs in training.

## 1. Food tiers

A base meal is chosen per-week (or per-trip; see lodging). Tiers vary along
three axes that deliberately do **not** move together, so there is no dominant
choice:

| tier | nutrition | morale | cost |
| --- | --- | --- | --- |
| Supergruel | high | very low | very low |
| Field rations | moderate | low | low |
| Canteen standard | moderate | moderate | moderate |
| Prepared table | moderate-high | high | high |
| Vollyslommy | low | very high | very high |

The two ends are the interesting ones and they are deliberately *both* bad
choices taken alone. Supergruel is nutritionally complete and joyless: it will
hold physical condition together and grind morale down. Vollyslommy is
gluttonous, beloved, and does not feed an athlete — a squad living on it is
happy and slowly getting worse.

The design intent is that neither extreme is a trap to be discovered once and
avoided forever. **Supergruel is correct during a brutal fixture congestion**
when condition matters more than mood, and **Vollyslommy is correct after a
cup exit** when the room needs rescuing. The system should reward reading the
season, not finding the best row.

## 2. Flavouring pastes

Pastes are mixed into a base meal at a chosen ratio. At least eight, and they
are the part of this system that carries identity rather than optimisation.

Sketch of the axis each should occupy — the point is coverage, not these exact
names: a sharp ferment, a bitter herb, a heavy sweet, a fatty savoury, a sour
citrus, a numbing spice, a smoky char, a clean umami.

Three rules make the paste layer more than a second tier list:

**Ratio costs, non-linearly.** A trace is cheap; a heavy mix costs
disproportionately. So a squad-wide indulgence is a real budget decision, and
targeting one player's preference is affordable.

**Preference is per-player, and it comes from two sources.** The design
question raised was body type *or* region of origin. It should be **both, and
they should be allowed to disagree** — that disagreement is where characters
come from. `home_region` and `club_region` already exist on `VolleyballPlayer`
and are already surfaced in the roster bio panel, as does the body type. A Vegi
raised in one region and playing in another has a *culinary* history as well as
a professional one.

Concretely: region supplies a familiarity — the taste of home, comforting,
morale-positive at moderate ratios. Body type supplies a physiological
tolerance — how much of it they can take before it stops being pleasant. A
player whose region loves a paste their body type tolerates poorly is a player
with a favourite food that does not love them back, and that is a more
interesting person than either input alone.

**Palate fatigue.** Holding a ratio constant decays its morale return toward
zero and then past it. This is the mechanic that stops the system from being
solved once. It should decay on the *specific ratio*, not the paste — so
varying the mix is a real answer, and rotating pastes entirely is a stronger
one. Recovery while a ratio is unused should be slower than the decay, so a
beloved paste over-used is a resource genuinely spent.

## 3. Lodging

Less developed, deliberately — food is the richer vein and should be built
first.

The axis that matters is **home versus foreign**. Domestic lodging is a
standing cost with a small, stable effect. Travel lodging is where the drama
is: an away trip into an unfamiliar region, with the quality of the stay
mediating how much the travel costs the squad.

The hook back into the existing model is `home_region` again. A player billeted
somewhere close to where they were raised should feel differently about the
trip than one taken somewhere alien — and the Sixnet regional structure already
gives the world enough geography for that to mean something.

Other candidates, unresolved: travel *method* (a long coach journey versus
flying), room allocation (who shares with whom — which is where this system
touches mentoring, below), and recovery facilities at the venue.

## 4. What this connects to

Accommodations should not be a closed loop. The three neighbouring systems
sketched alongside it:

- **Mentoring and partnership.** Pairing players socially. The obvious contact
  point with this document is room allocation on away trips, and a shared table
  — a mentor pairing that eats together should mean something.
- **Sponsorships.** Players representing interests, for morale, club culture,
  and money. The natural tension with this system is a food sponsor: cheap
  catering that pays you, and costs the room.
- **Club culture.** The aggregate the two above feed. Accommodations is the
  most legible weekly input into it.

## 5. Deliberately unresolved

- Whether meal choice is squad-wide, per-group, or per-player. Per-player is
  the most expressive and the most tedious; the likely answer is squad-wide
  with per-player exceptions, but that should be decided against a real UI.
- Whether nutrition feeds the fatigue model directly or sits beside it. The
  staged fatigue design (tiredness → forced errors → unforced errors) is not
  built yet, and this should hook into it rather than duplicate it.
- Whether palate fatigue is visible to the player as a number or has to be read
  from behaviour. Reading it from behaviour is better for the fiction and worse
  for usability; a confidence-graded hint, like the roster thought-bubble idea,
  may be the middle.
