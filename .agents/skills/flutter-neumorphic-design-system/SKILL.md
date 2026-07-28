---
name: flutter-neumorphic-design-system
description: Implement a complete Neumorphic design system using flutter_neumorphic_plus. Covers theme setup, core widgets (Neumorphic, NeumorphicButton, NeumorphicText), and building reusable neumorphic components.
metadata:
  version: "1.0.0"
---
# Flutter Neumorphic Design System

## Contents
- [Core Concepts](#core-concepts)
- [Workflow](#workflow)
- [Code Examples](#code-examples)

## Core Concepts
- **FlutterNeumorphicApp:** Replaces `MaterialApp` to provide the design system context.
- **NeumorphicThemeData:** Configures the base colors (e.g., `#E0E5EC` for light mode), light source, and default depth/intensity.
- **NeumorphicStyle:** Defines the look of individual widgets using properties like `depth`, `intensity`, `surfaceIntensity`, `lightSource`, and `shape` (convex, concave, flat, emboss).
- **Core Widgets:** `Neumorphic`, `NeumorphicButton`, `NeumorphicText`, `NeumorphicIcon`, `NeumorphicRadio`, `NeumorphicSwitch`.

## Workflow
### Task Progress
- [ ] Add `flutter_neumorphic_plus` to `pubspec.yaml`.
- [ ] Replace `MaterialApp` with `FlutterNeumorphicApp`.
- [ ] Define the light and dark `NeumorphicThemeData`.
- [ ] Create a reusable generic Neumorphic Card component.
- [ ] Create a Neumorphic Button.
- [ ] Create Neumorphic input fields (using an inner/embossed style).

## Code Examples

### pubspec.yaml Dependencies
```yaml
dependencies:
  flutter_neumorphic_plus: ^3.3.0
```

### App Setup and Theme
```dart
import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const FlutterNeumorphicApp(
      title: 'Neumorphic Receipt App',
      themeMode: ThemeMode.light,
      theme: NeumorphicThemeData(
        baseColor: Color(0xFFE0E5EC),
        lightSource: LightSource.topLeft,
        depth: 10,
        intensity: 0.8,
      ),
      darkTheme: NeumorphicThemeData(
        baseColor: Color(0xFF3E3E3E),
        lightSource: LightSource.topLeft,
        depth: 8,
        intensity: 0.5,
      ),
      home: HomeScreen(),
    );
  }
}
```

### Neumorphic Card and Button
```dart
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeumorphicTheme.baseColor(context),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Neumorphic(
              style: NeumorphicStyle(
                shape: NeumorphicShape.flat,
                boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(12)),
                depth: 8,
                lightSource: LightSource.topLeft,
              ),
              padding: const EdgeInsets.all(20),
              child: const Text('Neumorphic Card Component'),
            ),
            const SizedBox(height: 30),
            NeumorphicButton(
              onPressed: () {
                // Handle press
              },
              style: NeumorphicStyle(
                shape: NeumorphicShape.convex,
                boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(8)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: const NeumorphicText(
                'Scan Receipt',
                style: NeumorphicStyle(
                  depth: 4,
                  color: Colors.blueGrey,
                ),
                textStyle: NeumorphicTextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Neumorphic Input Field (Embossed)
```dart
class NeumorphicInputField extends StatelessWidget {
  const NeumorphicInputField({super.key});

  @override
  Widget build(BuildContext context) {
    return Neumorphic(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      style: NeumorphicStyle(
        depth: -4, // Negative depth for inner shadow (emboss)
        boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(10)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: 'Enter total amount',
        ),
      ),
    );
  }
}
```
