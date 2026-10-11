# Primalis Online — Prototype Test Plan

## Automated/runtime status
Godot is not installed in the current execution environment, so the scene and scripts have **not** been launched or validated by the Godot parser yet. A successful GitHub commit is not proof that the game runs.

## Checks to perform in Godot 4
- [ ] Import the repository and confirm `project.godot` opens without parse/import errors.
- [ ] Run the main scene and confirm the ground, lighting, dinosaur placeholder, and camera appear.
- [ ] Confirm the player stays on the ground and does not fall through it.
- [ ] Test W/A/S/D and arrow keys.
- [ ] On PC, hold the right mouse button and move the mouse to look around; verify the camera pitch stays within limits.
- [ ] On mobile, drag on the right half of the screen above the bottom controls to adjust view; ensure it does not interfere with the USAR and movement buttons.
- [ ] Check the added snout and arms from several angles and confirm they do not interfere with movement/collision.
- [ ] Walk and stop repeatedly; confirm legs and arms swing while moving, return to rest when idle, and the tail sways subtly.
- [ ] On an Android device, test that all four on-screen buttons respond to press and release.
- [ ] Confirm the HUD values update while the scene is running.
- [ ] Wait for hunger and thirst to drain; verify health starts draining only after either reaches zero.
- [ ] Test portrait and landscape layouts; adjust touch buttons if they overlap or fall off-screen.
- [ ] Test on a low-end Android device and reduce shadows/scene complexity if frame rate is poor.

## Known limitations
- The dinosaur is assembled from primitive meshes with simple procedural limb and tail motion; it is not a rigged or skeletal animation.
- Basic trees, rocks, a visual pond, and simple plant pickups are generated procedurally. Food and water use proximity checks rather than physical collision areas; verify them in Godot before relying on the interaction flow.
- Touch buttons are basic directional buttons, not a virtual analog stick.
- Survival values are prototype variables and do not persist between sessions.
- Multiplayer, accounts, server persistence, and Play Store export are not implemented.


## Food and water interaction checks
- [ ] Walk within 3 world units of a plant and confirm the prompt changes to the food action.
- [ ] Press USAR and confirm hunger rises by 30 points (capped at 100) and the plant disappears.
- [ ] Walk near the pond marker and confirm the water prompt appears.
- [ ] Press USAR and confirm thirst rises by 38 points (capped at 100); water remains reusable.
- [ ] Confirm the prompt updates as the player moves away from an item.
