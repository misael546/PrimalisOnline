# Primalis Online

Mobile-first 3D dinosaur survival prototype for Android, built with Godot 4.4.1 and licensed external assets.

## World update 0.3.0 (visual and physics rebuild, first pass)
- Continuous terrain plane of **4.6 km × 4.6 km**, rebuilt with 256 × 256 terrain cells (about 18 m spacing) and gentler rolling hills.
- Three narrower winding river channels follow the terrain-height function instead of being drawn at one fixed global height.
- 220 m world chunks stream around the player. The existing CC0 vegetation set now includes a third source tree model plus denser tree and ground-cover placement.
- Existing third-party dinosaur materials and animation clips remain sourced from Gobkit CC0. The T-Rex display height is reduced from 2.1 m to 1.8 m.
- Player and wildlife now have a fail-safe recovery if they fall below terrain or escape the playable bounds.
- Third-person camera pulled back, mobile movement/attack/use/sprint buttons, health/hunger/thirst/stamina, local coordinates and a river/player minimap.
- One menu entry: **Mundo local 01 · Isla Primordial** It starts an offline, local single-player session.

## Browser test
A Web export is built by GitHub Actions for Chromium/Firefox using WebAssembly and WebGL 2.0. The game uses Godot's Compatibility renderer; browser memory and performance still need real-browser testing. The workflow uploads a downloadable `PrimalisOnline-Web` artifact and attempts GitHub Pages deployment. If Pages is not enabled in repository Settings, the export remains downloadable until Pages is enabled and the workflow is run again.

## Server status
The menu label is deliberately honest: **no network server exists yet**. Accounts, authoritative server simulation, multiplayer synchronization, matchmaking and online persistence are not implemented. The single entry is a local test session, not a fake online server. A real server requires a host process and end-to-end networking work before it can be enabled.

## External art and licences
Dinosaur models/skins and environment GLBs are from Gobkit packs published as CC0 1.0. Forest Ground 01 PBR maps and Kloppenheim 06 sky HDRI are from Poly Haven CC0. No custom dinosaur skins or new visual artwork are drawn for this update. The river ribbon geometry is assembled in code and uses the pre-existing pond water shader over the external terrain-textured banks; it is not an imported river model or a downloaded water texture. Source list and limits: [docs/ASSET_AUDIT.md](docs/ASSET_AUDIT.md).

## Verification and limitations
CI checks asset downloads/imports, headless startup, dinosaur models/animations and heights, terrain mesh density/collision, river surface heights, fall recovery, nearby chunk generation, local menu entry, core survival interactions, and APK packaging/signature. Those checks cannot certify the river appearance, frame rate, memory use or graphics on the user's physical phone. The models remain low-poly and are not equivalent to The Isle's character art. This is a signed debug/test APK, not a Play Store release.

## Get an Android test APK
1. Open [GitHub Actions](https://github.com/misael546/PrimalisOnline/actions).
2. Open the latest successful **Build Android APK** run.
3. Download **PrimalisOnline-Android-APK**, unzip it, then install `PrimalisOnline.apk`.

To import on Windows, download the standard [Godot 4 stable build](https://godotengine.org/download/windows/), import `project.godot` and run with F5.
