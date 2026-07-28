---
name: flutter-camera-and-mlkit-ocr
description: Integrate the camera package and Google ML Kit text recognition for on-device OCR scanning of receipts. Covers camera controller lifecycle, preview widget, image capture, and text block extraction.
metadata:
  version: "1.0.0"
---
# Flutter Camera and ML Kit OCR

## Contents
- [Core Concepts](#core-concepts)
- [Workflow](#workflow)
- [Code Examples](#code-examples)

## Core Concepts
- **Camera Package:** Controls the device camera, manages streams, and captures images (`XFile`).
- **Google ML Kit Text Recognition:** Processes images on-device to extract `Text` which contains `TextBlock`, `TextLine`, and `TextElement`.
- **Lifecycle Management:** Properly initializing and disposing of the `CameraController` and `TextRecognizer` is critical to prevent memory leaks and camera lockups.
- **InputImage:** The format required by ML Kit, which can be created directly from an `XFile` path.

## Workflow
### Task Progress
- [ ] Add `camera` and `google_mlkit_text_recognition` to `pubspec.yaml`.
- [ ] Configure Android `AndroidManifest.xml` and iOS `Info.plist` for camera access.
- [ ] Initialize the available cameras list in `main()`.
- [ ] Create a `StatefulWidget` to manage the `CameraController`.
- [ ] Display the `CameraPreview`.
- [ ] Capture an image and pass its path to `InputImage.fromFilePath`.
- [ ] Process the image using `TextRecognizer` and extract text blocks.
- [ ] Dispose of the controller and recognizer when done.

## Code Examples

### pubspec.yaml Dependencies
```yaml
dependencies:
  camera: ^0.11.0+1
  google_mlkit_text_recognition: ^0.13.0
```

### Permissions Setup
**Android (`android/app/src/main/AndroidManifest.xml`):**
```xml
<uses-permission android:name="android.permission.CAMERA"/>
```
**iOS (`ios/Runner/Info.plist`):**
```xml
<key>NSCameraUsageDescription</key>
<string>This app requires access to the camera to scan receipts.</string>
```

### Camera and OCR Implementation
```dart
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ReceiptScanner extends StatefulWidget {
  final List<CameraDescription> cameras;

  const ReceiptScanner({super.key, required this.cameras});

  @override
  State<ReceiptScanner> createState() => _ReceiptScannerState();
}

class _ReceiptScannerState extends State<ReceiptScanner> {
  late CameraController _controller;
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    _controller = CameraController(widget.cameras[0], ResolutionPreset.max);
    try {
      await _controller.initialize();
      if (!mounted) return;
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _scanReceipt() async {
    if (!_controller.value.isInitialized) return;

    try {
      final XFile file = await _controller.takePicture();
      final inputImage = InputImage.fromFilePath(file.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      String scannedText = '';
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          scannedText += '${line.text}\n';
        }
      }
      
      debugPrint('Scanned: $scannedText');
      // Process scanned text...
    } catch (e) {
      debugPrint('OCR Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      body: Stack(
        children: [
          CameraPreview(_controller),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton(
                onPressed: _scanReceipt,
                child: const Text('Scan'),
              ),
            ),
          )
        ],
      ),
    );
  }
}
```
