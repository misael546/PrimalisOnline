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

## World implementation 0.2.0
- Ground mesh and collision plane are 2,400 × 2,400 m; boundary walls lie at approximately ±1,000 m on X/Z.
- Three winding river channels run across the map. River surfaces use the existing `materials/water_pond.gdshader`; river banks use the already downloaded external forest-ground PBR maps. River geometry is generated at runtime, not an imported model.
- External scene objects load in deterministic 180 m chunks around the player. A one-chunk neighbourhood is kept active; distant chunks are removed to limit mobile load.
- A 24-model ring of external Gobkit mountains sits beyond the playable border.
- Menu has a single entry labelled Local / no network server. No online server, user accounts, multiplayer sync, matchmaking or persistent storage is present.
- The minimap is schematic UI code and displays the global river lines plus the player's location.

## Automated checks and limits
CI verifies resource presence/import, T-Rex and herbivore rig/animation/bounds, ground scale, river meshes, active chunks, interaction controls, combat visibility, food/water and respawn flows, and Android APK integrity/package/version/CPU support. Headless CI does not validate visuals or performance on the user's physical phone. The low-poly asset pack is a prototype compromise; water still uses the old shader.
