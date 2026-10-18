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
- Product direction is online-first: the intended gameplay entry must connect to the authoritative server; do not launch offline local gameplay as if it were online. Temporary offline sessions may exist only as clearly labeled developer tests during migration. Do not present multiplayer as playable until connection, movement/combat synchronization, reconnects, and persistence pass end-to-end tests.
- No passwords, secrets or private keys in the repository.

## Every update
1. Inspect relevant source before edits.
2. Find related root causes rather than just the visible symptom.
3. Run relevant automated tests/builds and inspect the real results.
4. Report what changed, what passed and what still needs phone testing.
5. Do not claim device verification or a Play Store-ready release without evidence.


## Single-game workflow (agreed)
- Keep one canonical game in `main` and one public browser URL: https://misael546.github.io/PrimalisOnline/.
- Do not publish version-named copies, duplicate Pages sites, or separate public folders for routine fixes. Commits are internal history, not separate games.
- Keep the current live build online unless a replacement passes import, headless startup, gameplay regression, browser export and deployment checks. If CI fails, leave the last successful website live and fix the cause first.
- Use temporary branches/pull requests for risky changes; inspect the latest branch head before writes so work from another chat or contributor is not overwritten.
- Test and automate cache-busting for HTML, JavaScript, WASM and PCK assets. Keep the same public URL; never rely only on a browser refresh. GitHub Pages may limit response-header control, so verify the deployed strategy.
- Android still needs an increasing internal `versionCode` for later APKs to replace earlier installs. This is package metadata only, not a visible game version or a second copy of the game.
- After each change, inspect the actual Actions logs, fix the root cause, add regression coverage and report what still needs actual-device testing.

## Visual asset rules
- Do not create replacement dinosaur skins or select assets only because they are free.
- Search existing resources and inspect licence, redistribution terms, texture/material quality, proportions, rig and animations before adoption. Prefer coherent naturalistic assets for dinosaurs, terrain, rocks, vegetation and water; preserve original source materials.
- Record every adopted asset and explicit licence in `docs/ASSET_AUDIT.md`. If a free model looks like a weak placeholder, reject it and keep searching.

## Home PC server plan
- Keep GitHub as the source of truth for code, continuous integration, Web export, Pages and Android test artifacts.
- Host a separate lightweight headless Godot server process on the user's PC; it should not render the game world or open the editor, so the PC remains usable.
- Browser clients require a browser-compatible network transport and secure WebSockets (`wss://`) when the site is served over HTTPS. Do not assume native-only networking will work in the browser.
- Start persistence with a local SQLite file for a small test group. Only the server process reads/writes it; never expose a database port or connect a browser directly to the database. Consider PostgreSQL only if traffic/concurrent writes justify it.
- Test the LAN first, then add a reachable public endpoint and TLS after checking router/ISP/CGNAT. Keep admin/editor/remote-desktop ports private, back up saved data, validate client inputs and never commit secrets.
- The session stays labelled local/offline until real browser clients connect and movement, combat, reconnect and persistence pass end-to-end tests.
