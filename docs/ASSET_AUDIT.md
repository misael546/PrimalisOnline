# Primalis Online — External Asset Register

Primalis Online uses external visual assets rather than assistant-created dinosaur, foliage, terrain or sky artwork. The Android workflow downloads these resources during the build, checks basic file formats, imports them through Godot, and embeds them in the APK.

## Dinosaur models and skins

- **Gobkit Free Dinosaur pack:** T-Rex, Stegosaurus, Triceratops, Ankylosaurus, Pachycephalosaurus and Oviraptor.
- Assets: GLB models with their original materials/skins and animation data (idle, attack, dead, walk).
- Source and published licence: https://gobkit.com/api/free and https://gobkit.itch.io/gobkit-free-dinosaur-pack
- Licence: **CC0 1.0** according to the published pack manifest. The assets may be redistributed and modified under CC0.
- Style limitation: these are stylized low-poly dinosaurs, not realistic scans or equivalent to The Isle's PBR models. Their original baked materials are used; no new skins were drawn for this project.

## Environment models

The Android workflow downloads the CC0 GLB environment assets from the Gobkit Nature Kit:
- Trees: `TreeHigh001.glb`, `TreeHigh002.glb`
- Shrubs/food plants: `Bush001.glb`, `Bush002.glb`
- Ground vegetation: `Grass001.glb`, `Grass002.glb`, `Grass003.glb`
- Rocks: `Rock001.glb`, `Rock002.glb`, `Rock003.glb`
- Distant background: `MountainFar001.glb`, `MountainFar002.glb`, `MountainFar003.glb`

Source and published licence: https://gobkit.com/api/free — **CC0 1.0** per manifest. Imported mesh materials remain from their source assets; the project only positions, rotates and normalizes their scale.

## Terrain texture and sky

- **Forest Ground 01** from Poly Haven: 1K base-colour/diffuse, OpenGL normal and roughness maps. Source: https://polyhaven.com/a/forrest_ground_01
- **Kloppenheim 06 (Pure Sky)** from Poly Haven: 1K HDRI panorama. Source: https://polyhaven.com/a/kloppenheim_06_puresky
- Licence: **CC0 1.0** as stated by Poly Haven. Direct download locations are pinned in `.github/workflows/android-apk.yml`.
- The 1K files were selected to limit mobile memory use compared with larger texture/HDRI versions.

## Technical integration

- Imported GLBs are normalized using a separate parent wrapper node. This preserves the source model's imported root transform instead of overwriting its scale after calculating bounds.
- The T-Rex visual is target-normalized to about 2.1 m high and checks bounds in CI.
- Playable collision bounds are roughly 164 × 164 m; the textured ground extends to 300 × 300 m and an external mountain belt stands beyond the playable edge. It should read as a broader forest region instead of a tiny floating island.
- The scene now uses external models for trees, shrubs, grass, rocks, mountains, and all dinosaur species. The water/pond effect and HUD remain simple gameplay presentation elements, not third-party landscape/character art.

## Automated checks

The headless audit checks:
- T-Rex asset load, animation and normalized height bounds.
- Third-person camera distance.
- PBR diffuse, normal and roughness maps and HDRI resource presence.
- Five imported herbivore species and their normalized mesh heights.
- Minimum counts of trees, rocks, shrubs, grass clumps and distant mountains.
- Touch movement, attack direction/line of sight, food/water interaction and respawn timers.
- Signed APK integrity, alignment, package/version and ARMv7/ARM64 support.

## Limits not yet verified

Build checks cannot fully validate the exact look or frame rate on a physical phone. The Android device still needs manual checking for framing, lighting, texture display, input feel and performance. Do not describe this low-poly resource pack as photorealistic.
