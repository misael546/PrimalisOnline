# Primalis Online — Online Architecture and First Milestone

## Product decision

Primalis Online is moving toward online-first play. The public Godot Web export remains at the existing GitHub Pages URL; GitHub is the source of truth for code, CI, and exports; the user's PC is the planned authoritative game server. Android packaging is deferred as a release deliverable until the game is complete, although CI may continue creating test APK artifacts to catch regressions.

## Target architecture

- **Web client:** Godot WebAssembly/WebGL export from GitHub Pages. It owns presentation, camera, local input, and interpolation only.
- **Android client:** later, the same game client and protocol, with the Android Internet permission enabled.
- **Dedicated server:** Godot headless process on the home PC. It owns account sessions, player state, combat validation, wildlife simulation, world state, and persistence.
- **Transport:** JSON messages over WebSocket. Use secure WSS for public connections from the HTTPS GitHub Pages page. During local development, ws://127.0.0.1:9080 is intentionally loopback-only. A trusted TLS tunnel or reverse proxy can terminate WSS and forward to the local server once real end-to-end gameplay is ready. The online menu accepts a server address and stores it in client-local settings; browser connections reject ws:// and require wss://.
- **Persistence (current foundation):** the server writes one sanitized JSON save per anonymous character identity and a separate shared-world JSON file for herbivore state and plant regrowth cooldowns. Each store uses a temporary write plus a previous-save backup, validates a schema version, and sanitizes values when loading. Remaining cooldown durations are saved, so the world pauses while the server is offline. This dependency-free approach keeps setup free and simple; migrate to SQLite only if measured concurrency/query needs justify the extra dependency and operations. No database, administration or editor ports are exposed to the Internet.

## Implemented in this milestone

The headless server validates message envelopes, rate-limits clients, accepts an anonymous identity token generated locally by each client, and stores only its SHA-256 hash. Stable character identities restore saved location and survival values; duplicate simultaneous sessions are rejected. The server autosaves every five seconds and after actions, hits, and disconnects. Per-character JSON files clamp data to valid ranges and keep a previous-save backup. A new shared `scripts/world_terrain.gd` owns the exact seeded height formula and all three river paths; both the rendered world and headless server use it. Server-authoritative movement checks ground-height changes on each movement step. The server also controls health, hunger, thirst, stamina, drinking near the pond, eating near defined plants or hunted carcasses, plant regrowth cooldowns, player bites, and ten herbivores with roaming, fleeing, health, death, meat availability and timed respawn. Wildlife states are included in world snapshots; clients interpolate only the replicated state. The online menu routes USE/ATTACK controls to server-owned actions.

**This remains a development foundation, not a finished public survival game.** The anonymous token is not a recoverable account: clearing client data or losing the device can lose access to that character. Public service must use WSS, and the current PC server still listens in plain WebSocket mode behind a trusted TLS terminator. Full terrain collider/edge collision and underwater/swimming rules, advanced wildlife AI and animal-to-player attacks, account recovery/device linking, persistence of wildlife and plant cooldowns across server restarts, SQLite migration, public WSS configuration, and load/security certification remain unfinished.



## Run the prototype on a development PC

Install the project's Godot 4.4.1 version, open a terminal in the repository root, then run:

    godot --headless --path . --script res://server/server_bootstrap.gd -- --port=9080 --bind-address=127.0.0.1

Expected startup log:

    PRIMALIS_SERVER_READY host=127.0.0.1 port=9080 protocol=1 max_clients=32

On Windows, the helper server/start-server-windows.bat runs the headless command without opening the Godot editor. By default it listens on 127.0.0.1:9080. Set GODOT_BIN to the full path of godot.exe if it is not on PATH. Stop the server with Ctrl+C. To allow another device on the same LAN to connect for development only, set PRIMALIS_BIND_ADDRESS=0.0.0.0 before launching and restrict access through the local firewall. Do not expose this plain-WS development endpoint to the public Internet. Public hosting must terminate TLS and use wss://.

## Verification

Run the focused local multiplayer session smoke test:

    godot --headless --path . --script res://tests/online_protocol_smoke_test.gd

CI runs this test for Web and Android workflow builds. A passing smoke test proves only that the prototype transport starts and completes a loopback handshake; it does not prove accounts, game synchronization, security review, browser graphics, performance on a phone or public reachability.

## Next milestones

1. Add server-authoritative terrain collision tied to the streamed island's height and river geometry.
2. Simulate and replicate wildlife on the server, including bite damage, death, respawn and resource drops.
3. Add account registration, recovery and device linking only after password/session security is designed; never store plaintext passwords or commit secrets.
4. Replace prototype JSON files with versioned SQLite storage when measured server population, queries or concurrent writes justify it.
5. Persist plant/resource cooldowns and add inventory, progression and broader survival interactions.
6. Configure public WSS only after local gameplay and persistence are verified; never expose plain WebSocket or management ports.
7. Test reconnects, malformed packets, rate limits, data recovery, multi-client behavior and load before publishing a playable online game.
