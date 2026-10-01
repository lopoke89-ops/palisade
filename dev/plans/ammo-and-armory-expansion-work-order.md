# PALISADE: special ammo and Armory expansion work order

## Goal

Add four special ammunition choices to the midgame Armory and extend the existing upgrade tracks by four levels. Special ammo should give players a reason to change tactics between raids without letting pellet count, fire rate, or the Sniper's second ammo slot multiply effects out of control. Keep the Armory usable on phones, with clear prices, equipped ammo, skill bonuses, and upgrade progress.

The numbers below are starting targets for playtesting.

## Requested rules

- Offer **Armor Piercing, Incendiary, Explosive, and Lightning** ammunition at the Armory in **solo and co-op 5-raid, 10-raid, Endless, and Blitzkrieg Rush** matches only. These ammo mods do not appear or apply in Base Battle or Free-for-all. The existing Armory upgrade tracks remain available in their current modes.
- A player may equip **one** ammo type at a time. The **Sniper may equip two different types**, never more than two. Both equipped types affect each qualifying shot.
- The first ammo purchase costs **150 salvage**. Replacing an equipped type costs **75 salvage**. A Sniper buying a second slot's ammo pays **150 salvage**; replacing either occupied slot costs **75 salvage**. Re-equipping the same type is free and does not duplicate an effect. Purchases and equipped choices last for the current match.
- Each ammo type has four account skill-tree tiers, gated by **5, 10, 15, and 20 lifetime skill points earned** (`sp_total`). The tier must also be bought with unspent skill points. This uses the game's existing skill-point currency; it does not cost match salvage.
- Add levels **5–8** to Damage, Fire Rate, Range, Armor, Grenades, and the shared Delgado upgrade. Core Repair remains a repeatable service, so it has no level cap to extend.
- **Interpretation of “raise the max boost 25%”:** each upgrade track's level-8 cap is 25% higher than its current level-4 cap. Keep levels 1–4 at their present values and distribute the extra power across levels 5–8. The detailed caps are below.

## Proposed ammunition balance

One “block” means one world tile. A bullet's ordinary direct damage, falloff, class traits, and existing skill bonuses are resolved before the ammo effect. Ammo and the shooter's verified skill tier are captured when the shot is fired. Damage-over-time kills credit the shooter.

| Ammo | Base effect at purchase | Skill tiers at 5 / 10 / 15 / 20 lifetime SP |
| --- | --- | --- |
| **Armor Piercing** | A frontal hit deals **50% of normal direct damage** through a riot shield instead of being stopped. Rear and side hits retain normal damage. No bonus against unshielded targets. | Frontal shield damage becomes **60% / 70% / 85% / 100%**. The Sniper's existing wall piercing remains separate; a shield hit does not create a second damage event. |
| **Incendiary** | A direct hit burns the target for **10 HP per second for 3 seconds** (30 HP potential). Further hits refresh the timer; they do not stack DPS. | Burn duration becomes **3.5 / 4 / 4.5 / 5 seconds**. DPS stays at 10, so the effect remains easy to read. |
| **Explosive** | A direct hit causes a small blast: **8 extra damage** to the struck enemy and up to 8 to other enemies within **1.25 blocks**, falling to zero at the edge. | Peak blast damage becomes **10 / 12 / 14 / 16**. Radius stays 1.25 blocks. |
| **Lightning** | A direct hit slows the target and the **three closest other enemies within 3 blocks** by **25% for 2 seconds**. No damage is added. | Slow strength becomes **30% / 35% / 40% / 45%**. Radius, target limit, and duration stay fixed. |

Recommended common limits:

- Apply Incendiary, Explosive, and Lightning **once per fired round per target**. A shotgun blast counts as one round for these effects even though its seven pellets still deal normal pellet damage. Burst and automatic rounds count separately; they refresh a status rather than stack it. Limit explosive procs to **one per shooter and target every 0.4 seconds** so rapid fire does not dominate area damage.
- A burn or slow from another shooter refreshes the timer and uses the stronger active effect; it does not add a second stack. A target can be burning and slowed at the same time.
- Explosive ammo affects enemies only. It does not damage walls, cores, allies, or the shooter, ignite terrain, trigger grenade perks, or cause chain explosions. Incendiary ammo burns enemies only; it does not create Firebrand/Molotov ground fire or set walls alight.
- Lightning selects living, targetable enemies by distance from the struck target, then stable ID for ties. It does not jump onward from chained targets. Bosses can be burned and slowed, but slow applies to movement only and is capped at **20%** on bosses so attack timing remains legible. Burrowed or otherwise untargetable enemies are excluded.
- For Sniper combinations, apply the direct hit once, then apply each of the two distinct effects once. Armor Piercing can enable a shield hit that also applies the other selected effect. The Sniper cannot equip the same ammo twice.

## Proposed Armory upgrade balance

Existing levels 1–4 and their prices stay as they are. The new tiers are intentionally expensive enough to be late-run decisions in Endless and Blitzkrieg Rush. The cap increase is measured against each track's **current** level-4 boost.

| Upgrade | Current level-4 cap | Proposed level-8 cap | Levels 5–8, each purchase | Proposed costs for levels 5 / 6 / 7 / 8 |
| --- | --- | --- | --- | --- |
| **Damage** | +80% bullet damage | **+100%** | +5 percentage points of base bullet damage | **175 / 225 / 290 / 370 salvage** |
| **Fire Rate** | 40% shorter shot cooldown | **50% shorter cooldown** | 2.5 percentage points shorter cooldown | **175 / 225 / 290 / 370 salvage** |
| **Range** | +48% reach; bullet speed also rises | **+60% reach**, with bullet speed capped at +50% | +3 points of reach; +2.5 points of speed | **140 / 185 / 240 / 310 salvage** |
| **Armor** | +60% maximum health | **+75% maximum health** | +3.75 percentage points of base health | **175 / 225 / 290 / 370 salvage** |
| **Grenades** | +4 grenade stock; +32% blast power and +20% throw-blast radius | **+5 stock, +40% blast power, +25% throw-blast radius** | +2 points blast power and +1.25 points radius at each new level; the fifth stock grenade arrives at level 8 | **140 / 185 / 240 / 310 salvage** |
| **Delgado** (shared, co-op) | +60% damage, range, and fire rate | **+75% to each** | +3.75 percentage points to each stat | **200 / 270 / 350 / 450 salvage** |

Fire Rate should keep the existing cooldown formula and a safe minimum cooldown; “50% shorter” means twice the base firing rate before other modifiers, not an additional 50% multiplier on the current level-4 rate. Preserve the Soldier's current burst-size cap of nine bullets and minimum burst gap, so buying levels 5–8 improves damage and cadence without making bursts longer. Round Armor's resulting HP only once, after all bonuses. Grenade stock increases only at level 8, while each new level still improves blast. Delgado's boost remains shared and purchasable by any crew member.

## Implementation work

1. **Match state and purchasing.** Add equipped ammo slots to player state and one host-validated purchase/switch action. Check the same phase, distance, life, Lockdown, and salvage rules as other Armory purchases. Reject duplicates, a third Sniper ammo, a second non-Sniper ammo, invalid slot indices, and unaffordable requests without charging salvage. Show the 150/75 price before confirmation. On a class change, reduce to one slot for non-Snipers using a documented deterministic rule (keep slot one); switching back to Sniper must not restore a hidden second slot for free.
2. **Combat.** Capture equipped ammo when a bullet is fired so changing ammo before impact does not alter an in-flight shot. Resolve shield penetration in the existing front-angle check, then apply fire, explosive, or lightning effects on valid hits. Add one status update path for burn and slow with shooter credit, refresh rules, target limits, expiry, and visual indicators. Preserve hit feedback, shot trails, class abilities, grenades, and existing damage calculations.
3. **Skill tree and account authority.** Append four ammo nodes after the existing `SKILLS` order so old skill strings retain their meaning. Suggested point prices per node are **1 / 2 / 3 / 4 SP** for tiers 1–4. Show the `sp_total` gate and next cost in the UI. These nodes affect ammo only in the four eligible solo/co-op modes. Update the live-backed `private.skill_defs`, `public.skill_buy`, and any required output/validation through a reviewed migration based on the current deployed function text; the server must enforce both the lifetime-SP gate and the unspent-SP cost. Verify `skill_respec` refunds exactly the SP spent on these nodes and leaves `sp_total` unchanged. Confirm the host never applies more ammo skill than the server verifies for a guest.
4. **Eight-level Armory tracks.** Replace every hard-coded level-4 limit and four-pip display with data-driven caps, including Armory button labels, HUD affordability cues, purchase validation, rejoin restoration, result summaries, and the Delgado display. Keep the five-digit `upS` format if one digit per track still covers 0–8; validate the range instead of assuming 0–4. Preserve existing levels and prices for ongoing matches where possible.
5. **Network and reconnect.** The host remains authoritative for salvage, slot limits, damage, status effects, and skill levels. Send equipped ammo and active enemy statuses in snapshots; add only the visual events guests need. Preserve choices through a same-match reconnect and prevent reconnect, repeated clicks, or forged guest packets from bypassing prices or slot limits. Update the protocol only if the packet shape changes, and reject incompatible peers cleanly.
6. **Modes and presentation.** Show ammo rows only in solo and co-op 5-raid, 10-raid, Endless, and Blitzkrieg Rush matches, during their normal Armory build phases. Hide them in Base Battle and Free-for-all, and reject ammo purchase packets in those modes on the host even if a guest sends one. Ammo effects must never apply to rival players. This restriction applies to ammo only; the existing personal Armory tracks still work in Base Battle. Show ammo icons/colors that remain readable beside cosmetic tracers, and label the Sniper's two slots clearly on touch, mouse, and controller.
7. **Validation.** Add focused tests for every purchase path, pricing, slot cap, class switch, Lockdown, no duplicate charge, skill gates and respec, shotgun multi-pellet hits, rapid-fire status refresh, Sniper dual effects, shield angles, kill credit, boss slow cap, rejection of ammo in both PvP modes, reconnect, and guest authority. Run existing combat, Armory, account, multiplayer, and HUD tests plus a six-player stress scene with explosive/lightning effects. Playtest solo and online co-op in 5-raid, 10-raid, Endless, and Blitzkrieg Rush; verify that Base Battle keeps its ordinary Armory upgrades without ammo. Tune the proposed numbers if the new ammo or level-8 tracks crowd out ordinary upgrades.

## Acceptance criteria

- A normal class can equip exactly one ammo type, and Sniper can equip exactly two distinct types. Prices charged match the displayed 150/75 rules on host and guest clients.
- Armor Piercing reliably damages a frontal riot shield while ordinary ammo remains blocked. Incendiary deals 10 HP per second at base with no stacking. Explosive damages the struck enemy and nearby enemies only. Lightning reaches no farther than 3 blocks and slows no more than three nearby enemies plus the struck target.
- Skill tiers unlock at the stated lifetime-SP milestones and cannot be bought early, granted by a client packet, or refunded twice. Ammo effects use the verified tier.
- Each standard Armory upgrade and Delgado reaches level 8 with the proposed cap; existing levels 1–4, core repair, class rules, and match flow still work.
- All four eligible match lengths work in solo and online co-op. Ammo stays absent and has no combat effect in Base Battle and Free-for-all. Reconnect, modifiers, bosses, walls, rewards, and mobile/controller layouts pass the relevant tests and a short manual playtest.
