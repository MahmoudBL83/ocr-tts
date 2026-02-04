import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class ImageService {
  final CameraController controller;

  ImageService(this.controller);

  Future<File> captureAndCompress() async {
    final rawFile = await controller.takePicture();
    final tempDir = await getTemporaryDirectory();
    final targetPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

    final compressed = await FlutterImageCompress.compressAndGetFile(
      rawFile.path,
      targetPath,
      quality: 75,
      keepExif: true,
    );

    if (compressed != null) {
      return File(compressed.path);
    }
    return File(rawFile.path);
  }
}
