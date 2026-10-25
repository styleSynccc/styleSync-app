import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../config/generation_config.dart';

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
  final http.Client? client;
  final Future<String?> Function()? tokenProvider;
  final Duration listTimeout;
  final Duration authenticationTimeout;

  AiService({
    this.baseUrl = aiServiceBaseUrl,
    this.client,
    this.tokenProvider,
    this.listTimeout = const Duration(seconds: 30),
    this.authenticationTimeout = const Duration(seconds: 15),
  });

  static const Duration _requestTimeout = Duration(minutes: 3);
  static const Duration _tryOnTimeout = Duration(minutes: 45);

  Future<String?> _firebaseToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw AiServiceException(
        'NOT_SIGNED_IN',
        'You need to be signed in to do this.',
      );
    }
    return user.getIdToken();
  }

  Future<Map<String, String>> _authHeader() async {
    try {
      final token = await (tokenProvider ?? _firebaseToken)().timeout(
        authenticationTimeout,
      );
      if (token == null || token.isEmpty) {
        throw AiServiceException(
          'NOT_SIGNED_IN',
          'Please sign in again to use the AI features.',
        );
      }
      return {'Authorization': 'Bearer $token'};
    } on TimeoutException {
      throw AiServiceException(
        'AUTH_TIMEOUT',
        'Could not verify your sign-in. Check your internet connection and try again.',
      );
    }
  }

  Future<Map<String, dynamic>> _send(
    http.MultipartRequest request, {
    Duration timeout = _requestTimeout,
  }) async {
    try {
      final streamed = await (client?.send(request) ?? request.send()).timeout(
        timeout,
      );
      final response = await http.Response.fromStream(
        streamed,
      ).timeout(timeout);
      return _decode(response);
    } on TimeoutException {
      throw AiServiceException(
        'REQUEST_TIMEOUT',
        'The request timed out. If you were generating an outfit, it may still '
            'be processing. Avoid immediately submitting it again.',
      );
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
      final headers = await _authHeader();
      final uri = Uri.parse('$baseUrl$path');
      final response =
          await (client?.get(uri, headers: headers) ??
                  http.get(uri, headers: headers))
              .timeout(listTimeout);
      return _decode(response);
    } on TimeoutException {
      throw AiServiceException(
        'REQUEST_TIMEOUT',
        'The AI service is not responding. Check that your phone and computer '
            'can connect on the same Wi-Fi and the StyleSync API is running, then tap Refresh.',
      );
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

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> payload, {
    Duration timeout = _requestTimeout,
  }) async {
    try {
      final headers = {
        ...await _authHeader(),
        'Content-Type': 'application/json',
      };
      final uri = Uri.parse('$baseUrl$path');
      final body = jsonEncode(payload);
      final response =
          await (client?.post(uri, headers: headers, body: body) ??
                  http.post(uri, headers: headers, body: body))
              .timeout(timeout);
      return _decode(response);
    } on TimeoutException {
      throw AiServiceException(
        'REQUEST_TIMEOUT',
        'The generation request timed out. It may still be processing. '
            'Avoid immediately submitting it again.',
      );
    } on AiServiceException {
      rethrow;
    } catch (_) {
      throw AiServiceException(
        'NETWORK_ERROR',
        "Couldn't reach the AI service. Make sure both the StyleSync API "
            'and virtual try-on worker are running.',
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

  /// Transfer an inspiration outfit onto a saved twin using hosted Try-On Max.
  Future<Map<String, dynamic>> createInspoMirror({
    required String twinId,
    required Uint8List bytes,
    required String filename,
  }) async {
    final request =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/v1/inspo'))
          ..headers.addAll(await _authHeader())
          ..fields['twinId'] = twinId
          ..fields['confirmedCredits'] = '$maxQualityCreditsPerImage'
          ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: filename),
          );
    return _send(request, timeout: const Duration(minutes: 22));
  }

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

  /// Combine a twin with clothing, shoes, and an optional accessory.
  Future<Map<String, dynamic>> tryOn({
    required String twinId,
    required List<String> garmentItemIds,
  }) {
    return _postJson('/v1/tryon', {
      'twinId': twinId,
      'garmentItemIds': garmentItemIds,
      'confirmedCredits': maxQualityCreditCost(garmentItemIds.length),
    }, timeout: _tryOnTimeout);
  }
}
