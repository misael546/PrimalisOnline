# Primalis Online — Prototype Test Plan

## Automated/runtime status
Godot is not installed in the assistant's editing environment. GitHub Actions imports the project and runs a five-frame headless startup smoke test before attempting Android export. The Android export still needs a successful run, and a successful APK export does not prove the game behaves correctly on a real phone.

## APK build checks
- [ ] Open the repository Actions tab and run **Build Android APK**.
- [ ] Confirm the Godot import step finishes without script/resource errors.
- [ ] Confirm the Android export step succeeds and the APK artifact is uploaded.
- [ ] Download and extract the artifact ZIP.
- [ ] Install the debug APK on an Android device and launch it.
- [ ] Confirm the app opens in landscape without a black screen or immediate crash.
- [ ] Confirm the ground, dinosaur, camera, HUD, and touch controls appear.
- [ ] Verify health, hunger, thirst, and stamina bars track their numbers, stay legible at smaller landscape sizes, and do not overlap the interaction prompt.

## Startup checks
- [ ] Import the folder/repository by selecting its project.godot file in Godot 4.
- [ ] Wait for project import to finish; check the editor's error panel before pressing Play.
- [ ] Confirm scenes/main.tscn exists and is configured as the main scene in project.godot.
- [ ] Run the main scene with F6 or the project with F5 on desktop.
- [ ] Confirm the scene displays the ground, lighting, dinosaur placeholder, camera, and HUD.

## Controls and world
- [ ] Confirm the player stays on the ground and does not fall through it.
- [ ] Walk into a tree trunk and a rock; confirm their collision bodies block the player without trapping or launching them.
- [ ] Check the combined tree canopy mesh from several angles for missing faces, odd shading, and acceptable foliage density; check that trunks remain solid obstacles.
- [ ] Walk toward each edge of the 80x80 ground; confirm invisible boundary walls prevent falling out of the playable area.
- [ ] Test W/A/S/D and arrow keys on desktop.
- [ ] On PC, hold the right mouse button and move the mouse to orbit the camera; verify horizontal orbit and pitch limits.
- [ ] Move forward, backward, and sideways after turning the camera; confirm movement follows the camera-facing direction and the dinosaur turns toward travel.
- [ ] On mobile, drag on the right half of the screen above the bottom controls to orbit the camera; ensure it does not interfere with USAR and movement buttons.
- [ ] Check the snout and arms from several angles and confirm they do not interfere with movement/collision.
- [ ] Walk and stop repeatedly; confirm legs and arms swing while moving, return to rest when idle, and the tail sways subtly.
- [ ] On Android, test that all four movement buttons respond to press and release.
- [ ] Hold CORRER while moving; verify speed increases and stamina drains only during sprint.
- [ ] Release CORRER while still moving; verify stamina recovers slowly without slowing normal walking.
- [ ] Stop moving; verify stamina recovers faster, including after stamina reaches zero while sprint was held.
- [ ] Verify sprint cannot continue once stamina reaches zero, does not stutter back on while the button remains held, and becomes available again after releasing and pressing CORRER.
- [ ] Test landscape layout at multiple window sizes; verify the HUD and touch buttons scale and remain visible without overlap.
- [ ] Test on a low-end Android device and reduce shadows/scene complexity if frame rate is poor.
- [ ] Inspect the procedural dinosaur from front, side, and rear; check mesh seams, normals, proportions, feet contact, and camera framing.
- [ ] Verify the forest-floor shader renders on Android and does not produce shader compilation errors.
- [ ] Measure frame rate and memory after the forest canopy density increase.

## Survival and interactions
- [ ] Confirm HUD values update while the scene is running.
- [ ] Wait for hunger and thirst to drain; verify health starts draining only after either reaches zero.
- [ ] Walk within 3 world units of a plant and confirm the food prompt appears.
- [ ] Press USAR and confirm hunger rises by 30 points (capped at 100) and the plant disappears.
- [ ] Wait 45 seconds after eating a plant; confirm it reappears and can be collected again.
- [ ] Walk to the pond's center and shallow edges; confirm the water prompt appears without needing to stand on one exact point.
- [ ] Press USAR near the pond and confirm thirst rises by 38 points (capped at 100); water remains reusable and the prompt says to press USAR when in range.
- [ ] Confirm the prompt updates as the player moves away from an item.
- [ ] Verify three wild herbivores spawn away from the player, pond, trees, and rocks.
- [ ] Watch herbivores wander and animate their legs/tails; approach within 7 units and confirm they flee without getting stuck at the world edge.
- [ ] Let hunger or thirst reach zero; verify health drains, the player respawns after death, and survival stats reset to playable values.

## Known limitations
- The dinosaur now uses custom procedural tapered meshes and simple limb/tail motion, not a production rig or imported skeletal animation. Its anatomy and silhouette still need visual review in-game.
- Trees, rocks, a visual pond, and plant pickups are generated procedurally. The ground uses an original procedural forest-floor shader; it is not a downloaded PBR texture set. Food and water use proximity checks rather than physical interaction areas.
- Touch buttons are basic directional buttons, not a virtual analog stick.
- Survival values do not persist between sessions.
- Multiplayer, accounts, server persistence, and Play Store release signing are not implemented.
