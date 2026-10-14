import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

/// A structured error from the AI service (see apps/ai_service/app/errors.py).
/// [message] is already written for a user to read.
class AiServiceException implements Exception {
  final String errorType;
  final String message;
  final String? reason;

  AiServiceException(this.errorType, this.message, {this.reason});

  @override
  String toString() => message;
}

/// Talks to apps/ai_service (see apps/ai_service/PRD.md for what each
/// endpoint does and does not do yet).
class AiService {
  final String baseUrl;

  AiService({this.baseUrl = aiServiceBaseUrl});

  static const Duration _requestTimeout = Duration(minutes: 3);

  Future<Map<String, String>> _authHeader() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw AiServiceException(
        'NOT_SIGNED_IN',
        'You need to be signed in to do this.',
      );
    }
    final token = await user.getIdToken();
    return {'Authorization': 'Bearer $token'};
  }

  Future<Map<String, dynamic>> _send(http.MultipartRequest request) async {
    try {
      final streamed = await request.send().timeout(_requestTimeout);
      final response = await http.Response.fromStream(
        streamed,
      ).timeout(_requestTimeout);
      return _decode(response);
    } on AiServiceException {
      rethrow;
    } catch (e) {
      throw AiServiceException(
        'NETWORK_ERROR',
        "Couldn't reach the AI service. Is it running, and is the address "
            "in api_config.dart correct for how you're running the app?",
      );
    }
  }

  Future<Map<String, dynamic>> _get(String path) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl$path'), headers: await _authHeader())
          .timeout(_requestTimeout);
      return _decode(response);
    } on AiServiceException {
      rethrow;
    } catch (e) {
      throw AiServiceException(
        'NETWORK_ERROR',
        "Couldn't reach the AI service. Is it running, and is the address "
            "in api_config.dart correct for how you're running the app?",
      );
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    late final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw AiServiceException(
        'BAD_RESPONSE',
        'The AI service sent back something unexpected.',
      );
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    throw AiServiceException(
      (body['error_type'] as String?) ?? 'UNKNOWN_ERROR',
      (body['message'] as String?) ??
          (body['detail'] as String?) ??
          'Something went wrong (HTTP ${response.statusCode}).',
      reason: body['reason'] as String?,
    );
  }

  /// POST /v1/twins - a full-body photo -> a saved digital twin.
  Future<Map<String, dynamic>> createDigitalTwin(
    Uint8List bytes,
    String filename,
  ) async {
    final request =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/v1/twins'))
          ..headers.addAll(await _authHeader())
          ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: filename),
          );
    return _send(request);
  }

  /// GET /v1/twins - this user's twins, newest first.
  Future<List<dynamic>> listTwins() async {
    final body = await _get('/v1/twins');
    return body['twins'] as List<dynamic>;
  }

  /// POST /v1/wardrobe - a garment/hijab photo -> a saved wardrobe item.
  /// [category] must be one of wardrobeCategories (config/wardrobe_options.dart).
  /// [style] is required for category "Hijab" (shawl/pashmina/instant/khimar)
  /// and ignored otherwise - see app/config.py WARDROBE_CATEGORIES/HIJAB_STYLES.
  Future<Map<String, dynamic>> uploadWardrobeItem(
    Uint8List bytes,
    String filename, {
    required String category,
    String? style,
  }) async {
    final request =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/v1/wardrobe'))
          ..headers.addAll(await _authHeader())
          ..fields['category'] = category
          ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: filename),
          );
    if (style != null) request.fields['style'] = style;
    return _send(request);
  }

  /// GET /v1/wardrobe - this user's wardrobe items, newest first.
  Future<List<dynamic>> listWardrobe() async {
    final body = await _get('/v1/wardrobe');
    return body['items'] as List<dynamic>;
  }
}
