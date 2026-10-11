# Primalis Online

**Primalis Online** is an independent, mobile-first 3D dinosaur survival game project. The goal is to build a playable prototype using free tools, then evaluate the path to Android and Google Play.

## Current direction
- Third-person 3D survival in a prehistoric environment.
- A controllable starter placeholder character.
- Health, hunger, thirst, and stamina prototype variables.
- Touch-first Android controls, with keyboard support for development.
- Multiplayer is a future goal and is not implemented yet.
- Prefer free tools and original or properly licensed assets.

## Project status
Early prototype. Do not assume a feature works until it has been run and checked in Godot 4.

## Open on a Windows PC
1. Download the standard **Godot 4 stable** build from https://godotengine.org/download/windows/ (not the .NET build).
2. Extract the downloaded archive and launch the Godot executable.
3. In the Project Manager, choose **Import** and select this repository's `project.godot` file.
4. Wait for the initial import to finish.
5. Select the project and press **F6** to run the current main scene, or **F5** to run the configured project main scene.
6. If the Play button is disabled, first check that the project finished importing and that `scenes/main.tscn` exists.

## Open on Android
Godot's Android editor and device support can vary by device and version. If the editor opens but cannot run the project, use a Windows/Linux/macOS PC to validate the prototype first. The project is configured for landscape orientation and the mobile-friendly Compatibility renderer, but that does not replace a real Android runtime test.

## Development approach
Prioritize a stable, lightweight vertical slice before expanding the world or adding networking. Validate startup, movement, camera, touch controls, and survival interactions before adding more systems. Android export and Google Play release require separate validation on a compatible toolchain/device.
