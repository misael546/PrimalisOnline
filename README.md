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

## Get an Android test APK
The repository now includes an Android export preset and a GitHub Actions workflow. To build an APK:
1. Open the repository's **Actions** tab: https://github.com/misael546/PrimalisOnline/actions
2. Select **Build Android APK**.
3. Press **Run workflow** (or wait for the workflow triggered by a code change).
4. Open the completed run and download the **PrimalisOnline-Android-APK** artifact.
5. Extract the downloaded ZIP and install PrimalisOnline.apk on your Android device. If Android blocks installation, allow installation from the browser/file manager you used to download it.

The workflow attempts a debug APK export with Godot 4.4.1. The first build must finish successfully before an APK can be downloaded. This is a test build, not a Play Store release. Installation and gameplay still need real-device verification.

## Open on a Windows PC
1. Download the standard **Godot 4 stable** build from https://godotengine.org/download/windows/ (not the .NET build).
2. Extract the downloaded archive and launch the Godot executable.
3. In the Project Manager, choose **Import** and select this repository's project.godot file.
4. Wait for the initial import to finish.
5. Select the project and press **F6** to run the current main scene, or **F5** to run the configured project main scene.
6. If the Play button is disabled, first check that the project finished importing and that scenes/main.tscn exists.

## Development approach
Prioritize a stable, lightweight vertical slice before expanding the world or adding networking. Validate startup, movement, camera, touch controls, and survival interactions before adding more systems. Android export and Google Play release require separate validation on a compatible toolchain/device.
