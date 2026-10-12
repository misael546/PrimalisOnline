# Primalis Online — World and Session Design

## Core experience
Mobile-first third-person dinosaur survival: roam a prehistoric wilderness, find water and food, hunt or flee from other species and manage health, hunger, thirst and stamina.

## World
- 2.4 km × 2.4 km continuous ground plane; intended playable bounds approximately X/Z ±1 km.
- One winding main river and two tributaries; drinkable riverbank and a starter pond.
- External CC0 tree, rock, shrub, grass and food assets stream in 180 m chunks around the player.
- Dinosaurs spawn in the current exploration region and wander around local territory.
- Use external licensed models/materials only for dinosaur skins and environment art; do not draw replacement skins for this project.

## Interface
- Opening screen displays exactly one session entry, **Servidor 01 · Isla Primordial**, marked LOCAL / SIN SERVIDOR DE RED.
- Entering that entry starts the local game on the device.
- Play HUD: survival bars, interaction prompt, movement buttons, camera drag, sprint, attack and use; minimap shows rivers and player coordinates.

## Server roadmap
Current state is local/offline single-player only. There is no network process or actual multiplayer implementation. Later steps: real server runtime/host, server-authoritative movement and combat, player and wildlife state replication, reconnect behavior, validation/rate limits, and server persistence. Do not mark the entry online until a real client/server connection test passes.

## Technical principles
Godot 4; Android-first input and performance. Prefer free and correctly licensed assets. Automated checks are not a substitute for checking appearance, controls and frame rate on a physical phone.
