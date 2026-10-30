import 'dart:io';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../models/scan_result_model.dart';

/// Sends media to the DeepShield analysis API. No local heuristic is used.
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

  Future<ScanResultModel> scanVideo(
    File file, {
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      final filename = file.uri.pathSegments.isEmpty
          ? 'video'
          : Uri.decodeComponent(file.uri.pathSegments.last);
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: filename),
      });
      final stopwatch = Stopwatch()..start();
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.detectVideo,
        data: form,
        options: Options(
          contentType: Headers.multipartFormDataContentType,
          sendTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 3),
        ),
        onSendProgress: onProgress,
      );
      final data = response.data;
      if (data == null) {
        throw Exception('The analysis server returned an empty response.');
      }

      final prediction = (data['prediction'] as String? ?? '').toUpperCase();
      final fakeProbability = (data['fake_probability'] as num?)?.toDouble();
      if (!{'REAL', 'FAKE'}.contains(prediction) || fakeProbability == null) {
        throw Exception(
            'The analysis server returned an invalid video result.');
      }
      stopwatch.stop();
      final framesAnalyzed = (data['frames_analyzed'] as num?)?.toInt() ?? 0;
      final noFaceFrames = (data['no_face_frames'] as num?)?.toInt() ?? 0;
      final flagged = prediction == 'FAKE';
      final recommendation = flagged
          ? 'The sampled frames received a deepfake signal. This estimate is not proof; check the original source and other evidence before sharing.'
          : 'No strong deepfake signal was found in the sampled frames. This does not prove the video is authentic; check the original source before relying on it.';
      return ScanResultModel(
        id: const Uuid().v4(),
        scanType: ScanType.video,
        target: filename,
        threatLevel: flagged ? ThreatLevel.high : ThreatLevel.medium,
        confidenceScore: fakeProbability,
        isSafe: false,
        reasons: [
          flagged
              ? 'The video detector found a deepfake signal in the sampled frames.'
              : 'The video detector found no strong deepfake signal in the sampled frames.',
          'Analyzed $framesAnalyzed sampled frames using ${data['aggregation_method'] ?? 'frame aggregation'}.',
          if (noFaceFrames > 0)
            '$noFaceFrames sampled frames had no detected face; those frames were checked as full images.',
        ],
        recommendation: recommendation,
        scanDurationMs: stopwatch.elapsedMilliseconds,
        scannedAt: DateTime.now(),
        extraData: {
          ...data,
          'model_task': 'video_deepfake_detection',
          'confidence_is_calibrated': false,
        },
      );
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
