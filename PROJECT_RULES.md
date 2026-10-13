# Primalis Online — Project Rules

## Independence
- This repository is exclusively for Primalis Online.
- Never reuse files/assets from unrelated projects.
- Keep the project name Primalis Online.

## Cost and licensing
- Prefer free tools and services. No paid APIs or hosting without explicit approval.
- Use original, public-domain or correctly licensed assets and record source/licence.
- Preserve third-party dinosaur skins/materials; do not draw custom replacement skins unless explicitly requested.

## Engineering
- Target Godot 4, Android first.
- The target product is an original mobile dinosaur-survival game inspired by the broad genre and exploration scale of The Cursed Dinosaur Isle, not a pixel-for-pixel copy: huge traversable world, winding rivers, rolling terrain, wildlife, survival needs and mobile HUD.
- Use third-party art only with documented reusable licensing; the assistant may implement systems but must not falsely present generated meshes as sourced art or claim photorealistic fidelity.
- Use streamed world chunks to control memory/performance as the world grows.
- The menu may show one local/offline server entry for now, but it must never claim a real network server is online until working client/server connections are tested.
- No passwords, secrets or private keys in the repository.

## Every update
1. Inspect relevant source before edits.
2. Find related root causes rather than just the visible symptom.
3. Run relevant automated tests/builds and inspect the real results.
4. Report what changed, what passed and what still needs phone testing.
5. Do not claim device verification or a Play Store-ready release without evidence.
