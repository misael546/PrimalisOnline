# Primalis Online

Mobile-first 3D dinosaur survival prototype for Android, built with Godot 4.4.1 and licensed external assets.

## World update 0.3.2 (PBR lighting for source dinosaur and environment materials)
- Continuous terrain plane of **4.6 km × 4.6 km**, rebuilt with 256 × 256 terrain cells (about 18 m spacing) and gentler rolling hills.
- Three narrower winding river channels follow the terrain-height function instead of being drawn at one fixed global height.
- 220 m world chunks stream around the player. The existing CC0 vegetation set now includes a third source tree model plus denser tree and ground-cover placement.
- Existing third-party dinosaur materials and animation clips remain sourced from Gobkit CC0. The T-Rex display height is normalized to 1.8 m using skeleton rest-pose bounds, rather than an incomplete skinned-mesh AABB.
- Player and wildlife now have a fail-safe recovery if they fall below terrain or escape the playable bounds.
- The external Poly Haven sky is combined with ACES tone mapping, restrained ambient light, distance fog and tuned warm sunlight/shadow distance for stronger environmental depth.
- Original GLB color textures and source colors are preserved, while unlit material flags are converted to per-pixel lighting and excessive shine is reduced to make dinosaurs and environment props respond to real scene light.
- Third-person camera pulled back, mobile movement/attack/use/sprint buttons, health/hunger/thirst/stamina, local coordinates and a river/player minimap.
- The main menu is online-first and does not start a normal offline player session. It requires a configured server URL, connects through the shared WebSocket protocol, and loads an anonymous persistent character stored by the authoritative server. The character can move, eat near server-defined plants, drink at the pond, and bite other nearby players; while the URL is blank, the menu states that the server is not configured.

## Browser test
A Web export is built by GitHub Actions for Chromium/Firefox using WebAssembly and WebGL 2.0. The game uses Godot's Compatibility renderer; browser memory and performance still need real-browser testing. The workflow uploads a downloadable `PrimalisOnline-Web` artifact and attempts GitHub Pages deployment. If Pages is not enabled in repository Settings, the export remains downloadable until Pages is enabled and the workflow is run again.

## Online server status
The `online/server-foundation` branch contains a headless Godot WebSocket server, reconnecting client, online-first menu, anonymous per-install identity, server-authoritative movement/survival, persistent per-character JSON saves with backups, eating plants or hunted meat, drinking at the pond, player bites, and server-simulated herbivores with roaming, fleeing, health, hunting, carcass availability and timed respawn. The client never sends trusted position or vitals. CI checks persistence, data clamping, two clients, movement, sprint exhaustion, eating, drinking, PvP damage, hunting, meat consumption and wildlife respawn. This remains a development foundation, not a finished public survival game: recoverable accounts, advanced wildlife AI, authoritative terrain collision, wildlife/resource persistence across server restarts, WSS endpoint, SQLite migration and load/security certification remain pending. The anonymous identity is stored on the client and cannot yet be recovered if local data is lost. See [docs/ONLINE_ARCHITECTURE.md](docs/ONLINE_ARCHITECTURE.md) and [server/start-server-windows.bat](server/start-server-windows.bat).

## External art and licences
Dinosaur models/skins and environment GLBs are from Gobkit packs published as CC0 1.0. Forest Ground 01 PBR maps and Kloppenheim 06 sky HDRI are from Poly Haven CC0. No custom dinosaur skins or new visual artwork are drawn for this update. The river ribbon geometry is assembled in code and uses the pre-existing pond water shader over the external terrain-textured banks; it is not an imported river model or a downloaded water texture. Source list and limits: [docs/ASSET_AUDIT.md](docs/ASSET_AUDIT.md).

## Verification and limitations
CI checks asset downloads/imports, headless startup, dinosaur models/animations and heights, terrain mesh density/collision, river surface heights, fall recovery, streamed chunk generation, online-menu startup, protocol validation, two-client session replication, server-authoritative movement and sprint exhaustion. The Android workflow still exports a signed debug/test APK strictly as an internal compatibility check; it is not a release APK. CI cannot certify graphics, frame rate, memory use, heat or touch behavior on the user's physical phone. The models remain low-poly and are not equivalent to The Isle's character art.

## Android packaging
The final Android release APK is deliberately deferred until the online game is complete and passes gameplay, reconnect, persistence, security and device-performance tests. The current debug APK artifact exists only so CI can verify export compatibility; it is not the planned release build.

To import on Windows, download the standard [Godot 4 stable build](https://godotengine.org/download/windows/), import `project.godot` and run with F5.
