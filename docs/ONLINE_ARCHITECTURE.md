# Primalis Online — Online Architecture and First Milestone

## Product decision

Primalis Online is moving toward online-first play. The public Godot Web export remains at the existing GitHub Pages URL; GitHub is the source of truth for code, CI, and exports; the user's PC is the planned authoritative game server. Android packaging is deferred as a release deliverable until the game is complete, although CI may continue creating test APK artifacts to catch regressions.

## Target architecture

- **Web client:** Godot WebAssembly/WebGL export from GitHub Pages. It owns presentation, camera, local input, and interpolation only.
- **Android client:** later, the same game client and protocol, with the Android Internet permission enabled.
- **Dedicated server:** Godot headless process on the home PC. It owns account sessions, player state, combat validation, wildlife simulation, world state, and persistence.
- **Transport:** JSON messages over WebSocket. Use secure WSS for public connections from the HTTPS GitHub Pages page. During local development, ws://127.0.0.1:9080 is intentionally loopback-only. A trusted TLS tunnel or reverse proxy can terminate WSS and forward to the local server once real end-to-end gameplay is ready. The online menu accepts a server address and stores it in client-local settings; browser connections reject ws:// and require wss://.
- **Database:** start with SQLite stored on the server PC and accessible only to the server process. No database, administration or editor ports should be exposed to the Internet.

## Implemented in this milestone

The code adds a headless server entry point, versioned JSON protocol, packet validation, message-rate limiting, handshake, and server-assigned temporary player sessions. A server tick computes player X/Z movement and basic survival drains; snapshots replicate players and their server-owned values. Sprint exhaustion cannot restart until the player releases sprint. The reusable client sends movement intent, handles retry/backoff, and the two-client smoke test verifies that clients see the same player list, server movement changes a character's position, and the sprint exhaustion rule works. The game menu now enters a labeled online development session after the server accepts it.

**This is an early online gameplay milestone, not a complete online game.** Temporary character IDs and X/Z movement/survival stats are server-owned and tested with two clients. Accounts/password authentication, saved characters, server-side terrain collision, attack validation, food/water interactions, network-simulated wildlife, character progression, persistence and a configured public WSS endpoint remain unfinished. This online development session explicitly disables local-only attack/resource actions until server-authoritative versions are implemented. Do not advertise this as a finished multiplayer survival game until full gameplay, persistence, security and public endpoint tests pass.

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

1. Configure the public WSS endpoint without committing host secrets, and implement client connection states and reconnect/backoff.
2. Replace the local-only menu entry with login/session flow only after the transport endpoint can be configured safely.
3. Add registration/login, password hashing and session tokens. Never store plaintext passwords or put secrets in client builds.
4. Make the server authoritative for player movement, collision, health, hunger, thirst, attacks and death.
5. Synchronize nearby players and server-owned wildlife; add server-side world/chunk interest management.
6. Persist accounts/characters/inventory in server-side SQLite with migrations, backups and bounded save intervals.
7. Test multiple clients, reconnects, invalid packets, rate limiting and data persistence before publishing a playable online build.
