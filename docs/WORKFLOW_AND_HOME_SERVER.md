# Primalis Online — agreed workflow and home server plan

This is the handoff note for future chats. The repository is the persistent source of truth: read this file and `PROJECT_RULES.md`, then inspect the latest commit and GitHub Actions before editing anything. Do not assume the status below is current if newer commits exist.

## Decision: one continuously improved game

The project will have one canonical source at `misael546/PrimalisOnline` and one public browser address:

https://misael546.github.io/PrimalisOnline/

Do not create version-named game folders, duplicate Pages sites or separate public builds for routine fixes. Git commits and CI run IDs are internal engineering history, not separately published games. Android needs an increasing internal `versionCode` so Android will accept a later APK over an earlier install; it must not become a visible game version in the game's UI.

## Safe change → test → publish flow

1. Work from the latest `main` source. Use a short-lived branch and pull request for risky/large changes, not another public Pages site. If another chat or contributor has moved `main`, inspect and preserve those changes.
2. Run Godot import, headless startup, asset/model checks, survival/combat/controls regression tests, and Web export validation. Run Android export/package/signature validation when shared gameplay or engine code changes.
3. Deploy to the existing Pages address only after required checks are green. A failed build must not replace the last successful deployment; fix the root cause before retrying.
4. Add a browser E2E smoke test when possible (launch the actual exported Web build, assert no console/runtime errors and verify input/UI/asset load). Headless Godot tests validate logic, not how graphics look on the user's GPU.
5. Automate and verify cache-busting for HTML, JavaScript, WASM and PCK files. Keep the same public URL; revalidate/no-cache HTML where supported and content-hash referenced payloads or use an equivalent tested strategy. Do not assume Ctrl+F5 alone fixed stale files. GitHub Pages may not offer arbitrary response-header control, so verify what the deployed setup actually sends.
6. Once CI succeeds, check the public URL in a fresh browser session. For graphics/frame-rate issues on the user's device, request a screenshot or console log only when needed; never claim device verification without evidence.

## Professional external assets

The user does not want assistant-generated art or hastily chosen low-quality placeholder skins. Search and inspect reusable resources from the internet. Confirm exact licence/redistribution rights (not just “free”), texture quality, original materials, proportions, topology, rig and animation clips before integration. Aim for a coherent, naturalistic environment and dinosaur roster: terrain/ground maps, rocks, trees, shrubs, vegetation, water and sky should match each other. Preserve artists' materials and record resource URL + licence in `docs/ASSET_AUDIT.md`. If an asset looks cheap or plastic, reject it and keep researching rather than lowering the bar because it costs nothing.

## Diagnosing oversized dinosaurs and falls

Check real imported mesh bounds, transforms in the full hierarchy, skeleton/animation scale, normalization wrapper, root/floor offset, collision capsule and camera framing together. Test every dinosaur archetype, not just the T-Rex. The visible terrain and collision mesh must match. River/shore surfaces must follow the sampled land height, rather than being large flat ribbons through valleys. A fall-recovery teleport is a safety net, not a replacement for correcting the terrain/collision defect itself.

## PC as a low-resource home server

### Target layout
- **GitHub:** source code, review history, CI, Web export, Pages and downloadable Android test APKs.
- **Browser client:** static files from the one GitHub Pages address.
- **Home PC:** a separate headless, authoritative Godot server process; no world rendering, desktop UI or editor window in the server process.
- **Database:** start with a local SQLite file for a small test group. Only the server process can access it. Never expose a database port or let browser clients connect directly to the database. Consider PostgreSQL only when concurrent writes/traffic justify its operational cost.

### Implementation sequence
1. Add an explicit server entry point that runs headless and does not instantiate the client camera, scene scenery or HUD.
2. Implement browser-compatible networking. Godot Web clients need a supported path such as WebSocket/WebSocketMultiplayerPeer or a compatible gateway; do not assume ENet/native transport works from WebAssembly.
3. Make the server authoritative for movement, health, survival values, attacks, wildlife state and persistence. Clients send input/intent, never trusted saved state. Validate message sizes/content, rate-limit requests and handle disconnect/reconnect.
4. Test browser and server on the same LAN. Only then expose a public endpoint with TLS/WSS using a tunnel/reverse proxy or router forwarding after checking ISP/CGNAT. Never expose database, editor, admin, RDP or other management ports.
5. Persist compact state to SQLite at controlled intervals/on important state changes. Back up saves, limit tick/update/save rate, avoid expensive work per frame, and measure CPU/RAM with a few simultaneous clients.
6. Run the server as a separate process/task which can be started/stopped without affecting normal PC use. The PC must stay on and connected for external players to access it. Do not claim multiplayer until real browser clients connect and state sync, combat, reconnect and persistence work end to end.

## Product-direction update (2026-10-18)

The user has explicitly chosen an online-first game. The intended player session must connect to the authoritative server; do not preserve an offline single-player mode as the normal player experience or mislabel a local session as online. Local-only execution may be used for clearly labeled engineering tests during migration.

- Keep the single public browser URL and use GitHub as source of truth, web export, and CI.
- Host the authoritative game server as a separate headless Godot process on the user's PC.
- Use browser-compatible WebSocket transport and WSS at the public endpoint; do not expose SQLite or management ports.
- Defer the final Android APK as a release deliverable until the game is complete. CI test APK artifacts may remain enabled to catch regressions.
- A draft implementation branch, online/server-foundation, currently builds on draft PR #1's material/runtime fixes. Check PR #2 and its Actions before building on it; the transport smoke test must pass before claiming the server foundation is verified.
- The transport prototype is not yet authentication, playable multiplayer, or persistence. Normal gameplay must not switch to an “online” flow until real client-server state changes are integrated and tested.

## Handoff status snapshot (2026-10-13; re-check before using)

The first visual/physics pass has been committed and newer commits have since added natural lighting/material handling. The most recent observed commit was `c64f5e0749ed7b44c11ef9b8a9c68d240a6341aa` (“Avoid null override material queries on imported GLB surfaces”), but other work may already have advanced `main`.

The latest observed Browser Preview run was https://github.com/misael546/PrimalisOnline/actions/runs/38414825257 and the latest observed Android build was https://github.com/misael546/PrimalisOnline/actions/runs/38414826267. Both still failed at headless startup: Godot logged `ERROR: Parameter "material" is null.` from material shader-parameter inspection after loading the external dinosaur models. Do not publish the current code until this remaining error is fixed and both workflows pass. The public Pages URL should continue serving the last successful deployment while these checks fail.

The game still has no implemented remote multiplayer or database. Visual quality must be evaluated after a successful web deployment; automated headless tests are not enough to say the graphics look right.

## Prompt for the next chat

Continue the existing project `misael546/PrimalisOnline`. Read `PROJECT_RULES.md` and this file, inspect the current `main` head and latest Actions runs, and preserve any work newer than this snapshot. Fix the current material-null startup failure first; require passing Web and Android CI before publishing. Keep one public game URL without visible numbered releases, systematically fix browser caching, choose professional existing assets only after licence/quality review, then work toward a headless PC server + browser WSS transport + SQLite.
