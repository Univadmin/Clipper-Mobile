import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class CameraScannerPage extends StatefulWidget {
  const CameraScannerPage({super.key});

  @override
  State<CameraScannerPage> createState() => CameraScannerPageState();
}

class CameraScannerPageState extends State<CameraScannerPage>
    with WidgetsBindingObserver {
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );
  bool _recognizerClosed = false;
  int _cameraGeneration = 0;
  CameraController? _cameraController;
  Future<void>? _initFuture;
  String? _error;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initFuture = _initCamera();
  }

  Future<void> _initCamera() async {
    final generation = ++_cameraGeneration;
    CameraController? controller;
    try {
      final cameras = await availableCameras();
      if (!mounted || generation != _cameraGeneration) return;
      if (cameras.isEmpty) {
        setState(() => _error = 'Cihazda kamera bulunamadı.');
        return;
      }
      final selected = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      controller = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await controller.initialize();
      if (!mounted || generation != _cameraGeneration) {
        await controller.dispose();
        return;
      }
      setState(() {
        _error = null;
        _cameraController = controller;
      });
    } catch (_) {
      await controller?.dispose();
      if (mounted && generation == _cameraGeneration) {
        setState(
          () => _error =
              'Kamera açılamadı. Kamera iznini ayarlardan kontrol edin.',
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _cameraGeneration++;
      final camera = _cameraController;
      _cameraController = null;
      unawaited(camera?.dispose());
    } else if (state == AppLifecycleState.resumed && mounted) {
      setState(() => _initFuture = _initCamera());
    }
  }

  void _closeRecognizer() {
    if (!_recognizerClosed) {
      _recognizerClosed = true;
      unawaited(_textRecognizer.close());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraGeneration++;
    unawaited(_cameraController?.dispose());
    // An in-flight OCR call closes its recognizer in finally.
    if (!_processing) _closeRecognizer();
    super.dispose();
  }

  Future<void> _scan() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized || _processing) {
      return;
    }

    setState(() {
      _processing = true;
      _error = null;
    });

    XFile? capturedFile;
    try {
      // Her taramada yeni bir dosya oluştur
      capturedFile = await controller.takePicture();

      // Dosyayı işle - her seferinde yeni bir InputImage oluştur
      final inputImage = InputImage.fromFilePath(capturedFile.path);
      final recognised = await _textRecognizer.processImage(inputImage);

      // İşlem sonrası dosyayı hemen temizle (cache'i önlemek için)
      try {
        final file = File(capturedFile.path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Dosya silme hatası kritik değil
      }

      if (!mounted) return;

      // Sonucu al ve kontrol et
      final resultText = recognised.text.trim();

      // Empty results can be retried without leaving the camera screen.
      if (resultText.isEmpty) {
        setState(() {
          _processing = false;
          _error = 'Metin algılanamadı, tekrar deneyin.';
        });
        return;
      }

      // State'i temizle ve sonucu döndür
      setState(() {
        _processing = false;
      });

      if (mounted) {
        Navigator.of(context).pop(resultText);
      }
    } catch (e) {
      // Hata durumunda dosyayı temizle
      if (capturedFile != null) {
        try {
          final file = File(capturedFile.path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {
          // Dosya silme hatası kritik değil
        }
      }

      if (mounted) {
        setState(() {
          _processing = false;
          _error =
              'Metin okunamadı. Işığı ve netliği kontrol edip tekrar deneyin.';
        });
      }
    } finally {
      if (!mounted) _closeRecognizer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Metni Tara')),
      body: _error != null
          ? Center(child: Text(_error!))
          : FutureBuilder<void>(
              future: _initFuture,
              builder: (context, snapshot) {
                if (_cameraController == null ||
                    snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                return Stack(
                  children: [
                    Positioned.fill(child: CameraPreview(_cameraController!)),
                    if (_processing)
                      Container(
                        color: Colors.black45,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                  ],
                );
              },
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton.icon(
          icon: const Icon(Icons.document_scanner_outlined),
          label: Text(_error != null ? 'Yeniden dene' : 'Metni Tara'),
          onPressed: _processing
              ? null
              : _cameraController == null
              ? (_error == null
                    ? null
                    : () => setState(() {
                        _error = null;
                        _initFuture = _initCamera();
                      }))
              : (_cameraController!.value.isInitialized ? _scan : null),
        ),
      ),
    );
  }
}
