# Primalis Online — World and Online Session Design

## Core experience

Online-first third-person dinosaur survival. Players share a persistent prehistoric island, roam and explore, find food and water, hunt or flee from other species, manage health/hunger/thirst/stamina, and interact with other real players.

Normal player sessions require a reachable game server. Offline play is reserved for clearly labeled development tests, not a hidden fallback that looks like an online session.

## Player flow (target)

1. Load the client and connect to the configured secure WebSocket endpoint.
2. Register or sign in to a server account.
3. Select an available dinosaur species and load the character saved to that account.
4. Spawn at a server-approved position and receive nearby player, terrain-region, and wildlife state.
5. Play and save progression through the server; reconnect to the same character later.

The client owns presentation, camera, local controls, and interpolation. The server owns identity, movement validation, combat outcomes, survival stats, wildlife, world events, and saved state.

## World

- Continuous terrain approximately 4.6 km × 4.6 km with intended playable bounds around X/Z ±2.3 km, subject to later map/gameplay tuning.
- One winding main river plus two tributaries, drinkable shorelines, and a starter pond.
- World scenery streams in 220 m chunks around each active player.
- The current environment uses licensed CC0 dinosaur and environment models, PBR ground textures, and sky HDRI documented in docs/ASSET_AUDIT.md.
- Planned biomes include forest, open grassland, rocky highlands, marshes, beaches, and hidden caves. Add these after stable world streaming and collision tests.

## Survival and wildlife

- Baseline needs: health, hunger, thirst, and stamina.
- Food and water interactions must be validated by the server, not trusted from a client message.
- Dinosaur archetypes should differ in health, speed, stamina, bite/impact damage, turning, and defensive advantages.
- Wildlife should seek food/water, roam, flee or defend as appropriate, and be simulated on the server with interest management so distant creatures do not consume unnecessary CPU.
- Planned progression: growth, nests, eggs, reproduction, pack/herd behaviors, climate, day/night, and world events.

## Online architecture

- **GitHub:** canonical code, review history, tests, web exports, and CI.
- **Godot Web client:** one public GitHub Pages URL for browser play.
- **Home PC:** dedicated headless authoritative server, kept separate from rendering and editor UI.
- **Transport:** browser-compatible WebSocket; public HTTPS website must use WSS, normally terminated by a trusted TLS tunnel or reverse proxy.
- **Persistence:** server-only versioned JSON saves with backups are the current dependency-free base for characters and shared-world resources. Migrate to SQLite only when measured concurrency/query needs justify it. Never expose save files, database or management ports to clients.
- **Android:** use the same server, identity, protocol, and saved world. A release APK is deferred until core gameplay is complete and tested.

## Current implementation status

The `online/server-foundation` branch has a headless authoritative WebSocket server and online-first client, stable anonymous per-install identities, server-saved characters, a shared seeded terrain authority, guarded movement, health/hunger/thirst/stamina, validated drinking/eating/bites, ten roaming and fleeing herbivores, hunting/carcass eating/respawn, player/wildlife snapshots, and JSON persistence for both character state and shared-world resource cooldowns/wildlife state with recovery backups. Automated tests cover save recovery/sanitization, terrain determinism, two clients, movement, stamina, survival actions, PvP damage, hunting, carcass use, and wildlife respawn. This is still a development foundation: there is no recoverable account system or public WSS endpoint; terrain/shore collision and swimming need refinement; animal behavior/progression/inventory need expansion; and load/security/device tests remain.

## Milestones

1. Validate the headless WebSocket transport through CI.
2. Configure a real WSS endpoint and add client connection/reconnect states.
3. Implement account registration/sign-in, password hashing, session validation, and unique display names.
4. Move spawn, movement, collision, survival stats, attacks, death, and respawn to server authority.
5. Synchronize nearby players and wildlife; add reconnect and persistence tests.
6. Add world chunk interest management, SQLite migrations/backups, operational logs, and server restart recovery.
7. Expand species, behaviors, biomes, growth, social systems, weather, and events.
8. Run browser end-to-end, multi-client, load, security, and physical-device tests before calling the game complete.
