import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Screen OCR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const platform = MethodChannel('screen_capture');
  bool _isRunning = false;
  String _status = 'ရပ်နေတယ်';
  Timer? _timer;
  String _lastText = '';

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _startCapture() async {
    try {
      final bool granted =
          await platform.invokeMethod('requestPermission') ?? false;
      if (!granted) {
        setState(() => _status = 'Permission မရဘူး');
        return;
      }
      setState(() {
        _isRunning = true;
        _status = '🔴 Run နေတယ်';
      });
      _timer = Timer.periodic(const Duration(seconds: 3), (_) {
        _captureAndOCR();
      });
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  Future<void> _captureAndOCR() async {
    try {
      final String? imagePath =
          await platform.invokeMethod('captureScreen');
      if (imagePath == null) return;
      final String text = await FlutterTesseractOcr.extractText(
        imagePath,
        language: 'mya+eng',
      );
      if (text.trim().isEmpty) return;
      if (text.trim() == _lastText.trim()) return;
      _lastText = text;
      await _saveText(text);
      File(imagePath).delete().catchError((_) => File(imagePath));
      setState(() => _status = '🔴 Run နေတယ် — ${text.length} လုံး');
    } catch (e) {
      debugPrint('OCR error: $e');
    }
  }

  Future<void> _saveText(String text) async {
    final dir = Directory('/sdcard/ScreenOCR');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final now = DateFormat('HH:mm:ss').format(DateTime.now());
    final file = File('${dir.path}/$today.txt');
    await file.writeAsString(
      '\n--- $now ---\n$text\n',
      mode: FileMode.append,
    );
  }

  Future<void> _stopCapture() async {
    _timer?.cancel();
    await platform.invokeMethod('stopCapture');
    setState(() {
      _isRunning = false;
      _status = 'ရပ်သွားပြီ';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Screen OCR')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_status, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isRunning ? _stopCapture : _startCapture,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 40, vertical: 20),
                backgroundColor: _isRunning ? Colors.red : Colors.green,
              ),
              child: Text(
                _isRunning ? 'STOP' : 'START',
                style: const TextStyle(fontSize: 24, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            const Text('ဖိုင်သိမ်း — /sdcard/ScreenOCR/'),
          ],
        ),
      ),
    );
  }
}
