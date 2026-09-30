# PALISADE — full-screen flags, richer backgrounds, and natural character animation

**Status: executed locally as v0.9.3.4 on September 29, 2026; uncommitted and unpublished.** See [the implementation and validation report](../PRESENTATION_2026-09-29.md). The following is the original implementation scope. The latest verified release is v0.9.3.3 at `2268c35`. Recheck the current checkout, working tree, GitHub, and live version before editing; preserve any newer work. Use the next available patch subversion (v0.9.3.4 if v0.9.3.3 is still current). Keep the release record accurate about what is local, published, and verified.

## Objective

Make the presentation feel more polished and cohesive while retaining PALISADE's stylized, outlined, low-poly look. Flag backgrounds should become full-screen flag designs. Existing scenic backgrounds should gain depth, atmosphere, and stronger composition. Player movement should feel grounded and natural while remaining responsive. Keep these three slices independently reviewable and reversible.

## 1. Make Flag Case backgrounds fill the screen

Currently, each flag is an object on a pole against a separate sky. Replace that composition with the flag itself filling the entire background canvas behind the menus and character. No pole, small floating flag, surrounding scenic backdrop, letterboxing, or exposed edges. This applies to every Flag Case background, not its tracer cosmetics.

Support portrait phones, landscape phones, tablets, desktop, and installed fullscreen layouts. Define a deliberate responsive composition rather than stretching a landscape flag until its symbols become distorted. Preserve colors, stripe order, recognizable emblems, and the identity of every design. Use proportional scaling with intentional cropping or layout adaptation where needed; keep distinctive symbols visible where practical. Screen coverage must hold throughout any waving animation. Test simple stripes, crosses, diagonal patterns, and emblem-heavy designs as well as the whole flag catalog.

Keep menu text and the player readable using a restrained overlay or vignette, without muddying the flag or obscuring its identity. Preserve the existing rarity distinction: Common/Rare/Epic are static, Legendary/Gold have a restrained moving treatment. Respect reduced motion. Update Locker thumbnails to represent the new full-screen composition. Prefer the existing deterministic flag drawing for accurate designs; do not regenerate flags as approximate AI illustrations.

## 2. Back up and improve the scenic backgrounds

Before changing existing non-flag backgrounds, create an explicit, restorable backup of their source and any supporting assets. Record the baseline commit, background IDs/names, relevant dependencies, representative screenshots, and exact restore steps in a dated manifest under a development-only backup directory. Keep the backup out of the shipped asset list and offline cache. A Git reference alone is not the entire requested backup. Preserve the original files and identities so individual backgrounds can be restored without reverting unrelated game work.

Inventory the current scenery and identify what makes each scene feel flat, sparse, or visually awkward. Improve foreground/midground/background separation, lighting, atmosphere, silhouettes, material cues, and composition around the character. Use richer detail selectively; preserve negative space behind important UI, the recognizable theme of each scene, and a coherent art style across the collection. Avoid making everything brighter, busier, blurrier, or heavily animated just to suggest polish.

Evaluate the existing cached Canvas approach first. Build representative comparisons for a warm outdoor scene, a dark/moody scene, and a more elaborate effect-heavy scene before applying the chosen treatment across the remaining backgrounds. Prefer shared improvements where they help, but retain scene-specific character. Complete a considered pass across the existing scenic catalog, documenting any scene retained because the baseline already works better.

If the desired depth is impractical or too costly with procedural drawing, use pre-generated imagery or a hybrid of cached artwork and small animated layers. This is an allowed implementation option, not a requirement to replace the renderer. If generating art, use the available image-generation tool and follow its skill workflow. Match the game's stylized visual language rather than switching to photorealism. Do not bake UI, text, or the player into background artwork. Plan portrait and landscape composition deliberately, export optimized assets with documented sizes, and account for initial download, decode memory, offline availability, and missing-asset fallback. Keep existing background IDs, rarity, ownership, and equip behavior intact.

## 3. Make player animation feel more natural

Inspect the current animation in the lobby, Locker, gameplay, and remote-player rendering before changing it. Capture short before clips covering idle, walking, sprinting, aiming while moving, turning, stopping, and the existing weapon actions. Identify the observed problems instead of assuming more movement will look better.

Refine weight shift, stride, foot lift and contact, knee/elbow motion, torso/head stability, and transitions so the character feels grounded. Reduce foot sliding, rigid marching, abrupt pose changes, excessive bobbing, and awkward weapon/arm positioning wherever they actually occur. Walking cadence should follow movement, settle naturally when stopping, and remain sensible while strafing or moving against the aim direction. Idle motion should be subtle. Keep input and aiming responsive; visual easing must not delay gameplay controls.

Preserve PALISADE's proportions and silhouette. Maintain two-handed weapon grips, stock/shoulder alignment, cosmetic attachments, and correct muzzle/projectile origins throughout motion. Check every class and held-weapon type, covered faces, large headgear, capes/skirts, special-effect skins, and downed poses. Extend the existing pose and rendering systems where practical; do not replace the whole renderer or add an animation engine without demonstrated need. Keep pose-cache quantization, worker rendering, and memory limits in mind so smoother motion does not multiply cached poses uncontrollably.

This is presentation work. Do not alter damage, fire rates, movement speed, collision, hitboxes, abilities, rewards, or host movement enforcement. If an animation change affects the shared muzzle calculation or network presentation, validate that coupling explicitly.

## Implementation and validation

Start with `dev/src/js/18b-backgrounds.js` (`BGS`, `flagScene`, `drawBg`, and caches), `dev/src/js/16-characters.js` (character painters, gait, weapon positioning, pose caches/workers), and the lobby stage integration. Inspect callers and movement/aim inputs before editing. Work from source and rebuild through the normal build pipeline; preserve CSP and offline support.

Use focused checks per slice: flag/background catalog and equip checks for backgrounds; character, cosmetic-fit, muzzle-alignment, and a short host/guest presentation check for animation. Include targeted firearm validation only if the relevant shared weapon path changes. Do not run a full combat suite for an art-only change. Add regression coverage for meaningful failure modes rather than subjective beauty or implementation details.

Provide matched before/after screenshots for flag and scenic backgrounds, plus short animation comparisons. Check phone portrait, phone landscape, and desktop. Exercise reduced motion, all background IDs, cosmetic compatibility, and remote players. Measure representative frame costs and memory/cache behavior against the saved baseline; report asset download/decode costs if images are introduced. Do not claim physical-phone performance from viewport emulation alone.

## Completion criteria

- Every flag background covers the full screen across supported aspect ratios, remains recognizable, and leaves UI/player presentation readable.
- The original scenic backgrounds have a verified restore path, and the refreshed collection retains consistent style with clearer depth and composition.
- Character motion visibly improves in the demonstrated states without breaking grips, muzzle origins, cosmetics, responsiveness, or multiplayer presentation.
- Focused checks pass, performance tradeoffs and remaining real-device limits are recorded, and no player ownership/progression is changed.
- Update the project status, blueprint, and READMEs with the actual version, art approach, backup/restore instructions, test evidence, and remaining work. Preserve the existing deferred reward/import/identity backlog.

Keep the changes local and reviewable. Publishing and any live-service change remain separate actions that Big U handles or explicitly authorizes. No Supabase migration is expected for this presentation work.
