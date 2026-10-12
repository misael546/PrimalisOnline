# Primalis Online — Visual Asset Audit

## Current in-repository visual work

- **Dinosaur:** procedural tapered meshes generated in `scripts/player.gd`; original starter primitive parts are replaced at runtime. This is an interim custom model, not a scan or a production-quality rigged dinosaur.
- **Terrain:** original procedural forest-floor shader in `materials/ground_forest.gdshader`; no downloaded texture files or external shader dependencies.
- **Forest:** generated tree trunks, overlapping foliage meshes, and rocks in `scripts/main.gd`.
- **Water:** simple translucent pond material; still needs a dedicated water shader and shoreline detail.

## External asset candidates to evaluate

Only integrate an external asset after checking its actual download terms, license, attribution requirement, redistribution permission, file format, texture dependencies, skeleton/animation compatibility, and mobile cost. A download button or free account is not proof of a permissive license.

- Poly Haven asset library: https://polyhaven.com/ — assets are published under CC0; evaluate individual assets and download pages before use. Candidate surface references: https://polyhaven.com/a/forest_floor and https://polyhaven.com/a/forest_leaves_02.
- Sketchfab model search: https://sketchfab.com/3d-models — licenses vary per model. Prefer CC0 or CC BY models with downloadable GLB/GLTF, a usable rig, and explicit commercial-use terms. Record the exact model page and creator before adding it.

No third-party model or texture is currently bundled based on these links. Do not claim otherwise.

## Specific public-domain dinosaur candidates reviewed (not yet integrated)

These listings state CC0/public-domain terms and provide GLB downloads. They are worth testing in a separate import branch, but their pages do not establish that they include a usable skeleton or locomotion clips; verify inside Godot before replacing the current controller.

- Small feathered raptor, about 1.0 MB: https://www.innerscene.com/tools/library/3d-parts/small-feathered-raptor-dinosaur-d1041a65
- Stegosaur, about 897 KB: https://www.innerscene.com/tools/library/3d-parts/stegosaur-dinosaur-f775834c
- Long-neck sauropod, about 807 KB: https://www.innerscene.com/tools/library/3d-parts/long-neck-sauropod-dinosaur-c74c8916

The first is feathered and may not match the game's intended realistic style. None of these assets has been downloaded or included in the repository yet. Test import, visual quality, dimensions, orientation, material rendering on Android, and licensing metadata before use.

## Visual acceptance targets

- Dinosaur anatomy reads as a coherent species at gameplay distance: torso/neck/tail proportions, legs and feet, jaw, eye placement, and silhouette.
- Prefer a rigged GLB/GLTF with real locomotion animations over many disconnected primitive shapes.
- Use authored or licensed PBR textures; avoid stretching a single texture across the entire creature.
- Ground should have layered soil, moss, leaf litter, and subtle roughness variation; vegetation needs varied silhouettes and color.
- Keep mobile texture sizes, material count, transparency, shadow casters, and polygon count under control.

## Remaining validation

- Run Godot import and headless startup smoke tests after each code change.
- Confirm APK export and artifact upload in Actions.
- Test actual frame rate, controls, camera, collisions, lighting and materials on a physical Android device; CI cannot substitute for this.
