# Primalis Online — Prototype Test Plan

## Automated/runtime status
Godot is not installed in the current execution environment, so the scene and scripts have **not** been launched or validated by the Godot parser. GitHub commits and static review do not prove the game runs.

## Startup checks (do these first)
- [ ] Import the folder/repository by selecting its `project.godot` file in Godot 4.
- [ ] Wait for project import to finish; check the editor's error panel before pressing Play.
- [ ] Confirm `scenes/main.tscn` exists and is configured as the main scene in `project.godot`.
- [ ] Run the main scene with F6 or the project with F5 on desktop.
- [ ] Confirm the scene displays the ground, lighting, dinosaur placeholder, camera, and HUD.
- [ ] On Android, verify the editor supports running this project on the device; do not treat successful import as proof of runtime compatibility.

## Controls and world
- [ ] Confirm the player stays on the ground and does not fall through it.
- [ ] Test W/A/S/D and arrow keys on desktop.
- [ ] On PC, hold the right mouse button and move the mouse to orbit the camera; verify horizontal orbit and pitch limits.
- [ ] Move forward, backward, and sideways after turning the camera; confirm movement follows the camera-facing direction and the dinosaur turns toward travel.
- [ ] On mobile, drag on the right half of the screen above the bottom controls to orbit the camera; ensure it does not interfere with USAR and movement buttons.
- [ ] Check the snout and arms from several angles and confirm they do not interfere with movement/collision.
- [ ] Walk and stop repeatedly; confirm legs and arms swing while moving, return to rest when idle, and the tail sways subtly.
- [ ] On Android, test that all four on-screen buttons respond to press and release.
- [ ] Test landscape layout at multiple window sizes; verify the HUD and touch buttons scale and remain visible without overlap.
- [ ] Test on a low-end Android device and reduce shadows/scene complexity if frame rate is poor.

## Survival and interactions
- [ ] Confirm HUD values update while the scene is running.
- [ ] Wait for hunger and thirst to drain; verify health starts draining only after either reaches zero.
- [ ] Walk within 3 world units of a plant and confirm the food prompt appears.
- [ ] Press USAR and confirm hunger rises by 30 points (capped at 100) and the plant disappears.
- [ ] Walk near the pond marker and confirm the water prompt appears.
- [ ] Press USAR and confirm thirst rises by 38 points (capped at 100); water remains reusable.
- [ ] Confirm the prompt updates as the player moves away from an item.

## Known limitations
- The dinosaur uses primitive meshes and simple procedural limb/tail motion, not a rigged skeletal animation.
- Trees, rocks, a visual pond, and plant pickups are generated procedurally. Food and water use proximity checks rather than physical interaction areas.
- Touch buttons are basic directional buttons, not a virtual analog stick.
- Survival values do not persist between sessions.
- Multiplayer, accounts, server persistence, and Play Store export are not implemented.
