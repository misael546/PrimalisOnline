# Primalis Online — External Asset Register

The Android workflow downloads public third-party art assets during build and checks basic file formats before Godot import.

## Dinosaur models and skins
- Gobkit Free Dinosaur pack: T-Rex, Stegosaurus, Triceratops, Ankylosaurus, Pachycephalosaurus and Oviraptor. Original source materials are retained; this project does not paint replacement skins.
- Source: https://gobkit.com/api/free and https://gobkit.itch.io/gobkit-free-dinosaur-pack
- Licence: CC0 1.0 per the published pack manifest.
- Original imported skin/materials are preserved. The assets are stylized low-poly, not photorealistic or equivalent to The Isle's detailed models.

## Environment models
The Android workflow downloads CC0 GLBs from Gobkit's Nature Kit: TreeHigh001/002/003, Bush001/002, Grass001/002/003, Rock001/002/003, and MountainFar001/002/003.
Source/licence: https://gobkit.com/api/free — CC0 1.0 according to the published asset manifest. Assets are positioned and normalized; source materials are retained.

## Ground and sky
- Forest Ground 01 diffuse, OpenGL normal and roughness maps from https://polyhaven.com/a/forrest_ground_01.
- Kloppenheim 06 Pure Sky 1K HDRI from https://polyhaven.com/a/kloppenheim_06_puresky.
- Licence: CC0 1.0 as stated by Poly Haven. Download URLs are pinned in `.github/workflows/android-apk.yml`.

## World implementation 0.3.1
- The playable ground spans approximately 4.6 × 4.6 km; a 256 × 256 cell terrain grid reduces the sampling interval from 28.75 m to about 17.97 m. Static collision is generated from the same mesh.
- The terrain uses lower-amplitude, broader noise for gentler hills. Three narrower river ribbons are built after all paths and terrain noise are initialized; each vertex follows the terrain-height function rather than a fixed global Y.
- Water has a lower metallic/specular response and subtler waves. External scenery continues streaming in deterministic 220 m chunks; vegetation density and source tree variety have been increased.
- The CC0 HDRI is paired with ACES tone mapping, restrained ambient energy, distance fog, and a warm sun light with tuned shadow distance.
- Player and wildlife attempt recovery if below terrain or outside the playable bounds. Automated regression checks exercise both cases.
- A 32-model ring of external Gobkit mountains marks the far edge of the playable world.
- The minimap follows the full playable world and draws the three river lines.
- Main menu has one local-only entry. No real online server, authentication, multiplayer synchronization, matchmaking or network persistence exists yet; the interface does not present the local session as an online server.

## Automated checks and limits
CI verifies resource presence/import, T-Rex and herbivore rig/animation/bounds, ground scale, river meshes, active chunks, interaction controls, combat visibility, food/water and respawn flows, and Android APK integrity/package/version/CPU support. Headless CI does not validate visuals or performance on the user's physical phone. The low-poly asset pack remains a prototype compromise compared with The Cursed Dinosaur Isle; the river and pond water still use the existing shader. Actual phone visuals and performance must be checked on device.

## Browser export 0.2.2
- Dedicated Godot Web preset exports `build/web/index.html` for WebAssembly/WebGL 2.0; browser threads are disabled to avoid cross-origin isolation headers.
- A separate workflow validates the web export, uploads a downloadable `PrimalisOnline-Web` artifact, then attempts GitHub Pages deployment if repository Pages hosting is enabled.
- Browser gameplay and performance still require a real browser session; headless engine tests do not replace that check.
