# reciept_logging

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

## Prerequisites & FVM Setup

This project uses **FVM (Flutter Version Management)** to enforce a consistent Flutter SDK version across team members.

### 1. Install FVM globally (First-time setup)
```bash
dart pub global activate fvm
```
Ensure your pub cache bin directory (`%LOCALAPPDATA%\Pub\Cache\bin` on Windows or `~/.pub-cache/bin` on macOS/Linux) is added to your environment `PATH`.

### 2. Set Up Project Flutter SDK
After cloning this repository, navigate to the project directory and run:
```bash
fvm install
```
This installs and links the pinned Flutter SDK version (`3.44.8`) specified in `.fvmrc`.

### 3. VS Code Configuration
The project includes `.vscode/settings.json` configured to use `.fvm/flutter_sdk`. If prompted by VS Code, select the FVM SDK.

### 4. Running Commands
Prefix all `flutter` commands with `fvm`:
```bash
fvm flutter pub get
fvm flutter run
```


For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
