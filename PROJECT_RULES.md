# Primalis Online — Project Rules

## Independence
- This repository is exclusively for Primalis Online.
- Never copy, merge, or reuse project files/assets from Tekaym Online, DarkPixel Online, NeonCore, or VideoGPT Studio.
- Keep this project name as **Primalis Online**.

## Cost and licensing
- Prefer free, open-source tools and services.
- Do not introduce paid APIs, subscriptions, or hosting dependencies without explaining the cost and receiving approval.
- Use original, public-domain, or properly licensed assets. Record attribution and license terms for external assets.
- Never claim a third-party asset is free to use without checking its license.

## Engineering
- Target Godot 4 unless a documented technical reason requires changing engines.
- Keep the first playable slice small, mobile-conscious, and easy to test.
- Preserve working functionality when updating files.
- Avoid adding multiplayer until local movement, camera, UI, and survival systems are stable.
- Never store credentials, private keys, or secrets in the repository.
- Keep source, design documents, assets, and tests organized.

## Every update
1. Inspect the relevant files and current project state before changing code.
2. Check for related root causes rather than fixing only the visible symptom.
3. Make focused changes and test what is possible.
4. Clearly report what was changed, what was actually tested, and what remains unverified.
5. Do not claim the game runs on Android or exports to Google Play unless that has been verified on a suitable device/toolchain.

## Product direction
- 3D dinosaur survival, viewed from third person.
- Designed for mobile touch input first, with PC keyboard support during development.
- Planned survival needs: health, hunger, thirst, stamina.
- Begin with a small playable area and one controllable dinosaur before adding large maps, many species, or online multiplayer.
- Multiplayer and persistence are future goals, not implemented features unless code and tests confirm them.
