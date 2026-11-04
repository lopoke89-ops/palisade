# THE UNDERSTRIP: mood boards (M0)

**Status:** M0 draft for the director's sign-off (work order section 3: "before any skin or region art is made, the director signs off a one-page mood board per item"). These are written boards: silhouette, palette, the parts to draw, motion, and the section 3 check. Picture boards (sketches over the palettes) can follow for any item the director wants to see before M3.

**Conventions every item follows**
- **For skins, tiers set the motion budget**, as the milestone outfits do (tracers, kill effects and animated backgrounds always move): rare and epic are still; legendary gets one moving effect; gold gets the best effects (an aura from `16b-auras.js`, as the Gold milestone outfits have).
- **Skins are their own models** (the Tung Tung Tung Sahur pattern: its own branch in `16-characters.js`), so each needs all four Locker angles, a lobby-stage pose, idle / walk / shoot, the see-through and fade copies (stealth, the Locker), and an entry in every hat's compatibility list.
- **A skin whose model includes a hat** (the Gunslinger, the Sheriff, King of the Strip's pompadour) hides worn headgear, as the Sahur does for most hats. Each board says which.
- **Palettes are starting hexes**; the art pass may shift them for contrast against each region's floor.

---

## Skins

### 1. HIGH ROLLER · epic · Vegas
- **Silhouette:** a slim suit; the checkerboard reads at phone size.
- **Palette:** `#f2f0ea` white check · `#141414` black check · `#c4161c` pocket square · `#1a1a1a` / `#e8e4da` two-tone shoes · skin as the base figure.
- **Parts:** a black-and-white checkerboard suit (at least 4 × 4 checks on the torso so it reads small), black tie, red pocket square, two-tone spectator shoes, slicked hair.
- **Motion:** none (epic).
- **Headgear:** all hats.
- **Section 3:** ✔ original; no casino brand.

### 2. THE VISITOR · gold · alien
- **Silhouette:** tall, thin limbs, a big head: 1.15× the base figure's height, the tallest skin in the game.
- **Palette:** `#9aa3a8` grey skin · `#0b0b10` eyes · `#b8a8ff` psychic glow · `#e9f2ff` highlight.
- **Parts:** a smooth grey body, oversized black almond eyes, no clothes beyond a faint containment-suit seam, three long fingers.
- **Motion:** gold: a slow violet aura ring at the feet (the `16b-auras.js` way), and the eyes catch light as it turns.
- **Headgear:** hats sit higher (the head's taller); hoods and helmets off.
- **Section 3:** ✔ generic grey alien; nothing from a film or a real agency.
- **Also:** a guaranteed drop on the first finale kill.

### 3. KING OF THE STRIP · legendary · Vegas · ⚠ highest legal risk
- **Silhouette:** a high pompadour, a wide collar, a short cape.
- **Palette:** `#f8f6f0` jumpsuit · `#e2b436` gold trim and shades · `#5aa0ff` rhinestone glints · `#1a1410` hair.
- **Parts:** a white rhinestone jumpsuit with a high collar and flared legs, a short cape, a big belt buckle with **our own** design (a playing-card spade), gold shades, sideburns, the pompadour as part of the model.
- **Motion:** legendary: rhinestones glint in sequence across the suit.
- **Headgear:** the pompadour is the hat: worn headgear hidden.
- **Section 3:**
  - ✖ never the name "Elvis", his face or likeness, song titles or lyrics, or "TCB" lightning bolts.
  - ✖ no quiff-and-lip sneer combination that reads as one real person; the face stays the base figure's.
  - ✔ a generic lounge-singer impersonator.
  - The director signs this one off separately.

### 4. EL GENERALISSIMO · epic · Vegas
- **Silhouette:** a peaked cap, epaulettes, a sash across the chest.
- **Palette:** `#3d4a2f` tunic · `#c9a13a` braid and medals · `#8a1c2b` sash · `#1a1a14` boots.
- **Parts:** a peaked cap with an **invented** badge (a gold falcon over a die), epaulettes, a sash, a chest of invented medals (simple coloured bars and stars), riding boots, a moustache.
- **Motion:** none.
- **Headgear:** the cap is part of the model: worn headgear hidden.
- **Section 3:**
  - ✖ resembling any real dictator.
  - ✖ regime symbols, real flags, real rank badges, eagles in heraldic poses that read as a real state's.
  - ✔ an invented operetta generalissimo.

### 5. THE PIT BOSS · rare · Vegas
- **Silhouette:** a broad casino floor boss in a torn suit.
- **Palette:** `#2a2a30` suit · `#e2b436` chips · `#c8c3b8` shirt · `#7a1a1a` tie.
- **Parts:** a dark suit torn at one shoulder, an earpiece with a coil cord, a loosened tie, a pocket full of chips that show at the hip.
- **Motion:** none.
- **Headgear:** all hats.
- **Section 3:** ✔ original.

### 6. THE CUSTODIAN · legendary · shelter
- **Silhouette:** a boxy robot shell round the player, wider than any other skin.
- **Palette:** `#9bbf5a` olive casing · `#d97a2b` orange hazard stripes (D4's shelter colours) · `#2a2e24` joints · `#ff3a2a` lens.
- **Parts:** a boxy casing worn as a suit, the mop arm holstered on the back, one cracked round lens for a face, hazard stripes at the edges.
- **Motion:** legendary: the cracked lens flickers red now and then.
- **Headgear:** the casing is the head: worn headgear hidden.
- **Section 3:** ✔ our own shelter brand.

### 7. SHELTER DWELLER · rare · shelter
- **Silhouette:** a plain one-piece jumpsuit with a belt.
- **Palette:** `#7d8a4a` olive · `#d97a2b` orange piping · `#e8dfc4` patch · `#3a3326` belt.
- **Parts:** an olive jumpsuit with orange piping, a round shoulder patch reading "7" over "DCDA" (the Desert Civil Defence Authority, D4), a belt of ration packs.
- **Motion:** none.
- **Headgear:** all hats.
- **Section 3:**
  - ✖ blue-and-yellow, a numbered "vault" back print, a gear logo, or any wrist computer.
  - ✔ olive and orange, our own patch.

### 8. THE GUNSLINGER · rare · western
- **Silhouette:** a long dust coat that flares as you walk; a flat-brim hat.
- **Palette:** `#8a6a45` coat · `#3a2c1e` hat · `#c8a46a` bandolier · `#5a3a26` boots.
- **Parts:** a long dust coat, a flat-brim hat as part of the model, a bandolier, a neckerchief.
- **Motion:** none (the coat's flare is the walk cycle, not an effect).
- **Headgear:** the hat is the model's: worn headgear hidden.
- **Section 3:** ✔ archetype; no Native American dress.

### 9. THE SHERIFF · epic · western
- **Silhouette:** a tall hat, a waistcoat, a star.
- **Palette:** `#e8dcc0` shirt · `#4a3626` waistcoat · `#d8c070` star · `#2a1e14` hat.
- **Parts:** a waistcoat over a pale shirt, a five-point star badge, a big moustache, a tall hat as part of the model.
- **Motion:** none.
- **Headgear:** hidden.
- **Section 3:** ✔ archetype; the star has no real department's name.

### 10. THE CARD SHARP · legendary · western
- **Silhouette:** a riverboat gambler; a fan of cards in the off hand.
- **Palette:** `#6a1f2a` brocade vest · `#e8e0cc` shirt · `#1a1a1a` coat · `#c9a13a` sleeve garters.
- **Parts:** a brocade waistcoat, a ruffled shirt with sleeve garters, a short coat, a thin moustache, a card fan in the off hand (it stays in the hand when shooting).
- **Motion:** legendary: the card fan shuffles every few seconds while idle.
- **Headgear:** all hats.
- **Section 3:** ✔ archetype; generic card faces.

---

## Regions

### Region 1 · THE FLOOD TUNNELS
- **Mood:** wet concrete, flood debris, the casino's waste: claustrophobic but grimy-warm.
- **Palette:** `#2b2d2a` concrete · `#3a3f3b` wet concrete · `#1d3848` water (the game's own water) · `#e7a24a` work lamps · `#ff5ad8` / `#4fd2ff` neon through grates.
- **Props:** dumped slot machines, overflow pipes, graffiti (our own tags: no real crew names or slurs), flood lines on the walls, grates with neon above.
- **Lighting:** dark between lamps; pools of warm lamp light; pink-blue neon spill.
- **Section 3:**
  - ✖ no people shown living in the tunnels: no bedding, no camps, no unhoused people as enemies or jokes.
  - ✖ no real casino names on dumped machines (Palisade Falls only).

### Region 2 · SHELTER 7 (D4: run by the Desert Civil Defence Authority, olive and orange)
- **Mood:** Cold War steel, sealed for decades, still running.
- **Palette:** `#5a6248` olive steel · `#d97a2b` hazard orange · `#e8dfc4` cream signage · `#f2f6e8` fluorescents · `#ff3a2a` emergency red.
- **Props:** bunk rooms, ration stores, blast doors with our "7" stencil, propaganda posters for the DCDA ("A READY CITIZEN IS A SAFE CITIZEN", invented slogans), a mascot of our own (a cheerful desert tortoise in a helmet).
- **Lighting:** flickering fluorescents on timers; red emergency light after the Custodian's transition.
- **Section 3:** ✖ no gear logo, no numbered blue-and-yellow, no thumbs-up mascot; the tortoise replaces any boy mascot.

### Region 3 · AREA 67
- **Mood:** white labs giving way to alien growth.
- **Palette:** `#dfe6e8` lab white · `#8fa0a6` steel · `#7cff6b` specimen green · `#b8a8ff` alien violet · `#0b1012` the dark.
- **Props:** specimen tanks, gurneys, containment doors with our own "67" hazard sign, alien growth over the concrete (veins, bioluminescent pods).
- **Lighting:** cold even lab light that fails as the growth spreads; bioluminescence in the dark rooms.
- **Section 3:** ✖ no real military insignia, agency seals or US government logos.

---

## The other 20 items (section 9.3)

Names that clashed with the catalogue are renamed here and in `tables/case_items.csv`.

| Item | Tier | Look | Motion | Section 3 |
|---|---|---|---|---|
| **Tinfoil Hat** (hat) | common | a crumpled foil cone, catches light | still | ✔ |
| **Dealer's Eyeshade** (hat; was "Dealer's visor": `hat:visor` is the Cyber Visor) | common | a green translucent eyeshade | still | ✔ |
| **Antenna Headband** (hat) | rare | two bobbing antennae with balls | the antennae bob as you move | ✔ |
| **Showgirl Plume Crest** (hat) | epic | a tall feather crest, pink and white | sways | ✔ |
| **Neon Halo** (hat; `hat:halo` is taken, key `neonhalo`) | legendary | a ring of casino-sign tube over the head | flickers like a failing sign | ✔ |
| **Poker Chips** (tracer) | common | chips tumble behind the shot | tumbling | ✔ |
| **Neon Tube** (tracer; was "Neon strip": the trail "Neon" exists) | rare | a pink-and-blue neon tube | buzzes | ✔ |
| **Jackpot Coins** (tracer) | rare | gold coins spill behind | spinning | ✔ |
| **Tractor Beam** (tracer) | epic | a pale green beam that wobbles | wobble | ✔ |
| **Saucer Bolt** (tracer; was "Plasma bolt": `trail:plasma` exists) | epic | a fat green bolt with a ring round it | the ring spins | ✔ |
| **Bust** (kill effect) | common | cards scatter and flip face down | 0.8 s | ✔ generic cards |
| **Showgirl Plumes** (kill effect; was "Showgirl confetti": `fx:confetti` exists) | rare | feathers and sequins burst | 1 s | ✔ |
| **Jackpot!** (kill effect) | epic | a slot machine pays three 7s, coins burst | 1.2 s | ✔ our own machine, no real brand |
| **Dissolved** (kill effect) | legendary | green goo melts the body to a puddle | 1.2 s | ✔ |
| **Abducted** (kill effect) · **the showpiece** | gold | a beam lifts the body up and out | 1.5 s | ✔ |
| **The Flood Tunnels** (background) | common | dripping concrete, a lit grate above | drips | ✔ no people living there |
| **Casino Vault Door** (background) | rare | gold light through a huge round door | light shifts | ✔ |
| **Area 67 Fence at Dusk** (background) | rare | searchlights and a hovering light | searchlights sweep | ✔ invented signs only |
| **The Strip at Night** (background) | epic | a retro neon skyline | signs blink | ✔ generic signs; not the real welcome sign |
| **Specimen Hall** (background) | epic | tanks glowing in a dark lab | tanks pulse | ✔ |

Every item stays within the existing per-effect drawing budget (`caseperf.js`); the animated backgrounds follow the four animated winter scenes' budget.

## For the director
- [ ] Each skin's board, against section 3 (King of the Strip signed off on its own).
- [ ] The three region boards.
- [ ] The renamed items (Dealer's Eyeshade, Neon Halo's key, Neon Tube, Saucer Bolt, Showgirl Plumes).
- [ ] Tier changes from the work order's 9.3 table: two hats are common (Tinfoil, Eyeshade), because a case with no common items breaks its odds (see the README).
