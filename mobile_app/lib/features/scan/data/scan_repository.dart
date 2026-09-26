import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../models/scan_result_model.dart';

/// Sends photos to the DeepShield analysis API. No local heuristic is used.
class ScanRepository {
  ScanRepository(this._dio);

  final Dio _dio;

  Future<ScanResultModel> scanFile(
    File file, {
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      final filename = file.uri.pathSegments.isEmpty
          ? 'photo'
          : Uri.decodeComponent(file.uri.pathSegments.last);
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: filename),
      });
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.scanImage,
        data: form,
        options: Options(contentType: Headers.multipartFormDataContentType),
        onSendProgress: onProgress,
      );
      final data = response.data;
      if (data == null) {
        throw Exception('The analysis server returned an empty response.');
      }
      return ScanResultModel.fromJson(data);
    } on DioException catch (error) {
      throw Exception(DioClient.parseError(error));
    }
  }

  Future<ScanResultModel> scanUrl(String url) async {
    throw Exception('URL analysis is not part of the photo detection MVP yet.');
  }

  Future<ScanResultModel> scanQr(String extractedUrl) async {
    throw Exception('QR analysis is not part of the photo detection MVP yet.');
  }
}
