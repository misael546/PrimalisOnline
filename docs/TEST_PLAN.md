# Primalis Online — Prototype Test Plan

## Automated/runtime status
Godot is not installed in the current execution environment, so the scene and scripts have **not** been launched or validated by the Godot parser yet. A successful GitHub commit is not proof that the game runs.

## Checks to perform in Godot 4
- [ ] Import the repository and confirm `project.godot` opens without parse/import errors.
- [ ] Run the main scene and confirm the ground, lighting, dinosaur placeholder, and camera appear.
- [ ] Confirm the player stays on the ground and does not fall through it.
- [ ] Test W/A/S/D and arrow keys.
- [ ] On an Android device, test that all four on-screen buttons respond to press and release.
- [ ] Confirm the HUD values update while the scene is running.
- [ ] Wait for hunger and thirst to drain; verify health starts draining only after either reaches zero.
- [ ] Test portrait and landscape layouts; adjust touch buttons if they overlap or fall off-screen.
- [ ] Test on a low-end Android device and reduce shadows/scene complexity if frame rate is poor.

## Known limitations
- The dinosaur is assembled from primitive meshes and has no animations.
- Basic trees, rocks, and a visual pond are now generated procedurally. They are decorative only: there are no collision shapes for props, water drinking, food interactions, or other animals yet.
- Touch buttons are basic directional buttons, not a virtual analog stick.
- Survival values are prototype variables and do not persist between sessions.
- Multiplayer, accounts, server persistence, and Play Store export are not implemented.
