# Primalis Online — External Asset Register

The Android workflow downloads public third-party art assets during build and checks basic file formats before Godot import.

## Dinosaur models and skins
- Gobkit Free Dinosaur pack: T-Rex, Stegosaurus, Triceratops, Ankylosaurus, Pachycephalosaurus and Oviraptor.
- Source: https://gobkit.com/api/free and https://gobkit.itch.io/gobkit-free-dinosaur-pack
- Licence: CC0 1.0 per the published pack manifest.
- Original imported skin/materials are preserved. The assets are stylized low-poly, not photorealistic or equivalent to The Isle's detailed models.

## Environment models
The Android workflow downloads CC0 GLBs from Gobkit's Nature Kit: TreeHigh001/002, Bush001/002, Grass001/002/003, Rock001/002/003, and MountainFar001/002/003.
Source/licence: https://gobkit.com/api/free — CC0 1.0 according to the published asset manifest. Assets are positioned and normalized; source materials are retained.

## Ground and sky
- Forest Ground 01 diffuse, OpenGL normal and roughness maps from https://polyhaven.com/a/forrest_ground_01.
- Kloppenheim 06 Pure Sky 1K HDRI from https://polyhaven.com/a/kloppenheim_06_puresky.
- Licence: CC0 1.0 as stated by Poly Haven. Download URLs are pinned in `.github/workflows/android-apk.yml`.

## World implementation 0.2.1
- The playable ground spans approximately 4.6 × 4.6 km; the ground mesh spans 4.8 × 4.8 km. Procedural rolling terrain is generated as a triangulated mesh with matching static collision.
- Three winding river channels cross the map, with depressed terrain around the banks and river surfaces rendered from the existing water shader.
- External scenery is streamed in deterministic 220 m chunks; a 3 × 3 chunk neighbourhood is retained near the player to constrain mobile memory and draw calls.
- A 32-model ring of external Gobkit mountains marks the far edge of the playable world.
- The minimap follows the full playable world and draws the three river lines.
- Main menu has one local-only entry. No real online server, authentication, multiplayer synchronization, matchmaking or network persistence exists yet; the interface does not present the local session as an online server.

## Automated checks and limits
CI verifies resource presence/import, T-Rex and herbivore rig/animation/bounds, ground scale, river meshes, active chunks, interaction controls, combat visibility, food/water and respawn flows, and Android APK integrity/package/version/CPU support. Headless CI does not validate visuals or performance on the user's physical phone. The low-poly asset pack remains a prototype compromise compared with The Cursed Dinosaur Isle; the river and pond water still use the existing shader. Actual phone visuals and performance must be checked on device.
