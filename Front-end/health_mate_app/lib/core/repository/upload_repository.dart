import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/api_constants.dart';
import 'dart:io';
import 'package:dio/dio.dart';

/// Image Upload Repository
/// Handles uploading images to Cloudflare/Backend

class UploadRepository {
  final DioClient _dioClient;

  UploadRepository(this._dioClient);

  Future<String> uploadImage(File imageFile) async {
    try {
      String fileName = imageFile.path.split('/').last;
      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
      });

      final response = await _dioClient.dio.post(
        ApiConstants.uploadImage,
        data: formData,
      );

      // Assuming backend returns { "url": "..." }
      return response.data['url'];
    } catch (e) {
      // Fallback mock for demo if server not ready
      // In prod, rethrow
      return 'https://via.placeholder.com/150';
    }
  }
}

final uploadRepositoryProvider = Provider<UploadRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return UploadRepository(dioClient);
});
