import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/processing_request_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/image_service.dart';
import '../services/request_service.dart';
import '../services/storage_service.dart';
import '../utils/error_messages.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  final _uuid = const Uuid();
  CameraController? _controller;
  bool _isCameraReady = false;
  bool _isProcessing = false;
  String? _statusMessage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('No camera detected on this device.');
      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(backCamera, ResolutionPreset.high, enableAudio: false);
      _controller = controller;
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _isCameraReady = true;
        _statusMessage = 'Camera ready. Tap the shutter when you are ready.';
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = formatFriendlyError(error, fallback: 'Unable to access the camera.');
      });
    }
  }

  Future<void> _captureAndUpload() async {
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) return;
    final user = ref.read(authProvider).asData?.value;
    if (user == null) {
      setState(() {
        _errorMessage = 'You must be signed in to submit a request.';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Capturing image…';
      _errorMessage = null;
    });

    try {
      final tempFile = await ImageService(_controller!).captureAndCompress();
      setState(() {
        _statusMessage = 'Uploading image…';
      });
      final requestId = _uuid.v4();
      final downloadUrl = await StorageService().uploadImage(user.userId, requestId, tempFile);
      setState(() {
        _statusMessage = 'Creating processing request…';
      });
      final request = ProcessingRequestModel(
        requestId: requestId,
        ownerUserId: user.userId,
        targetDeviceId: user.pairedDeviceId ?? 'unpaired-device',
        status: ProcessingStatus.pending,
        createdAt: DateTime.now().toUtc(),
        imageUrl: downloadUrl,
      );
      await RequestService().createRequest(request);
      
      // Trigger server processing
      setState(() {
        _statusMessage = 'Starting OCR processing…';
      });
      try {
        await ApiService().processRequest(requestId);
      } catch (e) {
        // Log but don't fail - request is created, server might process it later
        debugPrint('Failed to trigger processing: $e');
      }
      
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Request submitted! Check history for progress.';
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Image submitted. We will notify you when processing completes.'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (error) {
      final message = formatFriendlyError(error, fallback: 'Unable to submit your request.');
      if (!mounted) return;
      setState(() {
        _errorMessage = message;
      });
      showFriendlyErrorSnackBar(context, error, fallback: message);
    } finally {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final previewSize = _controller?.value.previewSize;
    final double aspectRatio = previewSize != null ? previewSize.width / previewSize.height : 1.0;
    final cameraPreview = _controller?.value.isInitialized == true
        ? AspectRatio(
            aspectRatio: aspectRatio,
            child: CameraPreview(_controller!),
          )
        : const SizedBox(
            height: 300,
            child: Center(child: CircularProgressIndicator()),
          );

    return Scaffold(
      appBar: AppBar(title: const Text('Capture text')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Colors.black,
                  child: cameraPreview,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_statusMessage != null)
              Text(_statusMessage!, style: const TextStyle(fontSize: 16)),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
              ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isCameraReady && !_isProcessing ? _captureAndUpload : null,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.camera_alt),
              label: const Text('Capture & submit'),
            ),
          ],
        ),
      ),
    );
  }
}
