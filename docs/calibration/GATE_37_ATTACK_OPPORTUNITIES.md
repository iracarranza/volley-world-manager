# Gate 37: Attack Opportunities

Review date: 2026-07-30

Status: **PASS; SHADOW ONLY**

`ShadowAttackSystem` generates legal non-decoy hitter options from the active
lineup and play. Every option has a lane, tempo, contact time, perceived start
position, approach margin, and tactical priority. When no called assignment is
available, it creates legal role-neutral fallback lanes without selecting the
active setter or libero.

Attack and block contacts now have action-specific jump envelopes. Approach
timing, explosiveness, jump reach, current movement, body state, fatigue, and
set duration determine whether a hitter can enter the contact window. These
rules remain shadow-only unless the later rollout gates promote the contact.
