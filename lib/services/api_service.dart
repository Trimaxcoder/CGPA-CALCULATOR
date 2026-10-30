// lib/services/api_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../stores/announcement_store.dart';
import 'class_socket.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  CONFIGURATION
// ─────────────────────────────────────────────────────────────────────────────

class ApiConfig {
  static const String baseUrl = 'https://gradexbackend.onrender.com/api';
  static const Duration timeout = Duration(seconds: 15);
  // The token refresh gets a shorter limit so a slow server can't stack
  // 15s (request) + 15s (refresh) + 15s (retry) on a single call.
  static const Duration refreshTimeout = Duration(seconds: 10);
  static const String anthropicApiKey = 'your-anthropic-api-key-here';
}

// ─────────────────────────────────────────────────────────────────────────────
//  CUSTOM EXCEPTIONS
// ─────────────────────────────────────────────────────────────────────────────

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException([
    String msg = 'Session expired. Please log in again.',
  ]) : super(msg, statusCode: 401);
}

// ─────────────────────────────────────────────────────────────────────────────
//  TOKEN STORAGE
// ─────────────────────────────────────────────────────────────────────────────

class TokenStorage {
  static const _accessKey  = 'access_token';
  static const _refreshKey = 'refresh_token';

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKey,  accessToken);
    await prefs.setString(_refreshKey, refreshToken);
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessKey);
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshKey);
  }

  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
    await AnnouncementStore().clear();
  }

  static Future<bool> hasTokens() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BASE HTTP CLIENT
// ─────────────────────────────────────────────────────────────────────────────

/// Outcome of a token refresh attempt.
/// [rejected] means the server said the refresh token is invalid (log out).
/// [unavailable] means we couldn't find out (timeout, offline, server asleep)
/// and the user must NOT be logged out because of it.
enum _RefreshResult { ok, rejected, unavailable }

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  static const _timeoutMessage =
      'Server is taking too long to respond. Please try again.';
  static const _unavailableMessage =
      'Could not reach the server. Please try again.';

  // Shared in-flight refresh, so several 401s at once trigger only one refresh.
  Future<_RefreshResult>? _refreshing;

  Future<Map<String, String>> _headers({bool requiresAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept':       'application/json',
    };
    if (requiresAuth) {
      final token = await TokenStorage.getAccessToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // ── Sending ────────────────────────────────────────────────────────────────

  /// Sends one request and turns every network failure into an ApiException
  /// with a readable message.
  Future<http.Response> _send(
    String method,
    Uri uri,
    Map<String, String> headers, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final Future<http.Response> request;
      switch (method) {
        case 'GET':
          request = http.get(uri, headers: headers);
          break;
        case 'POST':
          request = http.post(uri, headers: headers, body: jsonEncode(body));
          break;
        case 'PUT':
          request = http.put(uri, headers: headers, body: jsonEncode(body));
          break;
        case 'DELETE':
          request = http.delete(uri, headers: headers);
          break;
        default:
          throw ArgumentError('Unsupported method: $method');
      }
      return await request.timeout(ApiConfig.timeout);
    } on TimeoutException {
      throw const ApiException(_timeoutMessage);
    } on SocketException {
      throw const ApiException('No internet connection.');
    } on HttpException {
      throw const ApiException('Network error.');
    } on http.ClientException {
      // Covers failures on web and TLS/handshake errors on mobile.
      throw const ApiException('No internet connection.');
    }
  }

  /// One entry point for get/post/put/delete.
  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    final uri     = Uri.parse('${ApiConfig.baseUrl}$path');
    final headers = await _headers(requiresAuth: requiresAuth);
    final response = await _send(method, uri, headers, body: body);

    return _handleResponse(
      response,
      retryRequest: requiresAuth
          ? () async {
              final h = await _headers();
              return _send(method, uri, h, body: body);
            }
          : null,
    );
  }

  // ── Responses ──────────────────────────────────────────────────────────────

  /// Decodes a JSON object body, or returns null if it isn't one
  /// (e.g. an HTML error page from a sleeping or crashing server).
  Map<String, dynamic>? _tryDecode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  ApiException _errorFrom(http.Response response) {
    final body = _tryDecode(response.body);
    final message = body?['message'] as String?;
    if (message != null && message.isNotEmpty) {
      return ApiException(message, statusCode: response.statusCode);
    }
    if (response.statusCode >= 500) {
      return ApiException(
        'Server is unavailable right now. Please try again shortly.',
        statusCode: response.statusCode,
      );
    }
    return ApiException('Request failed', statusCode: response.statusCode);
  }

  bool _isSuccess(http.Response r) =>
      r.statusCode >= 200 && r.statusCode < 300;

  Map<String, dynamic> _successBody(http.Response response) {
    final body = _tryDecode(response.body);
    if (body == null) {
      throw ApiException(
        'Unexpected response from server.',
        statusCode: response.statusCode,
      );
    }
    return body;
  }

  Future<Map<String, dynamic>> _handleResponse(
    http.Response response, {
    Future<http.Response> Function()? retryRequest,
  }) async {
    if (_isSuccess(response)) return _successBody(response);

    if (response.statusCode == 401 && retryRequest != null) {
      final result = await _tryRefreshToken();

      switch (result) {
        case _RefreshResult.ok:
          final retried = await retryRequest();
          if (_isSuccess(retried)) return _successBody(retried);
          if (retried.statusCode == 401) {
            await TokenStorage.clearTokens();
            throw const UnauthorizedException();
          }
          // Some other failure (e.g. 500): report it, don't log the user out.
          throw _errorFrom(retried);

        case _RefreshResult.rejected:
          await TokenStorage.clearTokens();
          throw const UnauthorizedException();

        case _RefreshResult.unavailable:
          // Couldn't reach the server to refresh. Keep the tokens so the
          // user isn't logged out just because the server was slow.
          throw const ApiException(_unavailableMessage);
      }
    }

    throw _errorFrom(response);
  }

  // ── Token refresh ──────────────────────────────────────────────────────────

  Future<_RefreshResult> _tryRefreshToken() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<_RefreshResult> _doRefresh() async {
    try {
      final refreshToken = await TokenStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        return _RefreshResult.rejected;
      }

      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(ApiConfig.refreshTimeout);

      if (response.statusCode == 200) {
        final data = _tryDecode(response.body);
        final access  = data?['accessToken']  as String?;
        final refresh = data?['refreshToken'] as String?;
        if (access == null || refresh == null) return _RefreshResult.unavailable;

        await TokenStorage.saveTokens(
          accessToken:  access,
          refreshToken: refresh,
        );
        return _RefreshResult.ok;
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        return _RefreshResult.rejected;
      }
      return _RefreshResult.unavailable; // 5xx, 502 from a waking server, etc.
    } catch (_) {
      return _RefreshResult.unavailable; // timeout, offline, anything else
    }
  }

  // ── Public API (unchanged signatures) ──────────────────────────────────────

  Future<Map<String, dynamic>> get(String path) => _request('GET', path);

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool requiresAuth = true,
  }) =>
      _request('POST', path, body: body, requiresAuth: requiresAuth);

  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body,
  ) =>
      _request('PUT', path, body: body);

  Future<Map<String, dynamic>> delete(String path) => _request('DELETE', path);
}

// ─────────────────────────────────────────────────────────────────────────────
//  AUTH SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class AuthService {
  final _client = ApiClient();

  /// Register a new user.
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required Map<String, dynamic> profile,
    Map<String, dynamic>? grading,
  }) async {
    final data = await _client.post('/auth/register', {
      'email':    email,
      'password': password,
      'profile':  profile,
      if (grading != null) 'grading': grading,
    }, requiresAuth: false);
    await TokenStorage.saveTokens(
      accessToken:  data['accessToken']  as String,
      refreshToken: data['refreshToken'] as String,
    );
    return data['user'] as Map<String, dynamic>;
  }

  /// Log in with email and password.
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final data = await _client.post('/auth/login', {
      'email':    email,
      'password': password,
    }, requiresAuth: false);
    await TokenStorage.saveTokens(
      accessToken:  data['accessToken']  as String,
      refreshToken: data['refreshToken'] as String,
    );
    return data['user'] as Map<String, dynamic>;
  }

  /// Log out.
  Future<void> logout() async {
    try {
      await _client.post('/auth/logout', {});
    } catch (_) {}
    ClassSocket().disconnect();
    await AnnouncementStore().clear(); 
    await TokenStorage.clearTokens();
  }

  /// Get the current user's data.
  Future<Map<String, dynamic>> getMe() async {
    final data = await _client.get('/auth/me');
    return data['user'] as Map<String, dynamic>;
  }

  /// True if the device has a stored access token.
  Future<bool> isLoggedIn() => TokenStorage.hasTokens();

  // ── Forgot password ────────────────────────────────────────────────────────
  /// Sends a password reset email to [email].
  Future<void> forgotPassword({required String email}) async {
    await _client.post(
      '/auth/forgot-password',
      {'email': email},
      requiresAuth: false,
    );
  }

  // ── Reset password ─────────────────────────────────────────────────────────
  /// Resets the password using the [token] from the email link
  /// and the user's chosen [newPassword].
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await _client.post(
      '/auth/reset-password',
      {'token': token, 'newPassword': newPassword},
      requiresAuth: false,
    );
  }

  // ── Google Sign-In ─────────────────────────────────────────────────────────
  /// Sends the Google [idToken] to your backend and saves the returned tokens.
  Future<Map<String, dynamic>> loginWithGoogle({
    required String idToken,
  }) async {
    final data = await _client.post(
      '/auth/google',
      {'idToken': idToken},
      requiresAuth: false,
    );
    await TokenStorage.saveTokens(
      accessToken:  data['accessToken']  as String,
      refreshToken: data['refreshToken'] as String,
    );
    return data['user'] as Map<String, dynamic>;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PROFILE SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class ProfileService {
  final _client = ApiClient();

  Future<Map<String, dynamic>> getProfile() async {
    final data = await _client.get('/profile');
    return data['profile'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> fields,
  ) async {
    final data = await _client.put('/profile', fields);
    return data['profile'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateGrading(
    List<Map<String, dynamic>> rules,
  ) async {
    final data = await _client.put('/profile/grading', {'rules': rules});
    return data['grading'] as Map<String, dynamic>;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _client.put('/profile/change-password', {
      'currentPassword': currentPassword,
      'newPassword':     newPassword,
    });
  }

  Future<void> deleteAccount() async {
    await _client.delete('/profile');
    ClassSocket().disconnect();
    await TokenStorage.clearTokens();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  COURSE SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class CourseService {
  final _client = ApiClient();

  Future<List<Map<String, dynamic>>> getCourses({
    int? year,
    int? semester,
  }) async {
    var path = '/courses';
    final params = <String>[];
    if (year     != null) params.add('year=$year');
    if (semester != null) params.add('semester=$semester');
    if (params.isNotEmpty) path += '?${params.join('&')}';
    final data = await _client.get(path);
    return List<Map<String, dynamic>>.from(data['courses'] as List);
  }

  Future<Map<String, dynamic>> addCourse({
    required String name,
    String title = '',
    required int score,
    required int unit,
    required int year,
    required int semester,
    String clientId = '',
  }) async {
    final data = await _client.post('/courses', {
      'name':     name,
      'title':    title,
      'score':    score,
      'unit':     unit,
      'year':     year,
      'semester': semester,
      'clientId': clientId,
    });
    return data['course'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateCourse({
    required String id,
    required String name,
    String title = '',
    required int score,
    required int unit,
    required int year,
    required int semester,
  }) async {
    final data = await _client.put('/courses/$id', {
      'name':     name,
      'title':    title,
      'score':    score,
      'unit':     unit,
      'year':     year,
      'semester': semester,
    });
    return data['course'] as Map<String, dynamic>;
  }

  Future<void> deleteCourse(String id) async {
    await _client.delete('/courses/$id');
  }

  Future<int> deleteAllCourses() async {
    final data = await _client.delete('/courses');
    return (data['deleted'] as int?) ?? 0;
  }

  Future<List<Map<String, dynamic>>> syncCourses(
    List<Map<String, dynamic>> localCourses, {
    List<String> deletedServerIds = const [],
  }) async {
    final data = await _client.post('/courses/sync', {
      'courses': localCourses,
      'deletedServerIds': deletedServerIds,
    });
    return List<Map<String, dynamic>>.from(data['courses'] as List);
  }
}