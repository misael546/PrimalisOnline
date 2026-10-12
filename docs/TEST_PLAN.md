# Primalis Online — Test Plan

## Automated checks
- [x] Godot headless import/startup and Android APK packaging.
- [x] Required external GLB, PBR and HDRI asset validation.
- [x] T-Rex model load, animation, normalized size and third-person camera distance.
- [x] Continuous terrain at least 2 km across.
- [x] Main river plus two tributary channels generated.
- [x] Streaming chunks populated around the player.
- [x] One local-only session entry exists; it does not auto-start gameplay before selection.
- [x] Core test coverage for touch movement, facing/line-of-sight bite attacks, food/water, respawn and survival values.
- [x] APK signature, alignment, package name, version and ARMv7/ARM64 export checks.

## Phone checks still required
- [ ] Install latest APK and verify landscape launch without black screen/crash.
- [ ] View T-Rex from front, side and rear; make sure the full body/feet remain visible.
- [ ] Follow the main river and two tributaries, inspect water seams/banks and verify drinking near shore.
- [ ] Travel across multiple chunks; inspect missing props, duplicated objects, invisible collisions, stutters and memory growth.
- [ ] Walk into trees/rocks and test movement/camera/buttons at the target screen size.
- [ ] Play for at least 5–10 minutes and monitor frame rate/heat/memory.
- [ ] Check minimap/coordinates/HUD overlap on the user's actual phone.
- [ ] Verify outer boundary is blocked at about ±1 km.

## Server and limitations
- [x] Single menu entry is explicitly labeled local/offline.
- [ ] Real multiplayer/server deployment is not in this milestone; no server authority, accounts, matchmaking or persistence exists.
- River geometry is code-built and uses the pre-existing water shader. Low-poly external assets are not equal to The Isle's more realistic visuals. CI cannot certify physical-device visual quality/performance.
