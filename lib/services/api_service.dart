// lib/services/api_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  CONFIGURATION
// ─────────────────────────────────────────────────────────────────────────────

class ApiConfig {
  static const String baseUrl = 'https://gradexbackend.onrender.com/api';
  static const Duration timeout = Duration(seconds: 15);
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
  }

  static Future<bool> hasTokens() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BASE HTTP CLIENT
// ─────────────────────────────────────────────────────────────────────────────

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

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

  Future<Map<String, dynamic>> _handleResponse(
    http.Response response, {
    Future<http.Response> Function()? retryRequest,
  }) async {
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    if (response.statusCode == 401 && retryRequest != null) {
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        final retried     = await retryRequest();
        final retryBody   = jsonDecode(retried.body) as Map<String, dynamic>;
        if (retried.statusCode >= 200 && retried.statusCode < 300) {
          return retryBody;
        }
      }
      await TokenStorage.clearTokens();
      throw const UnauthorizedException();
    }

    final message = body['message'] as String? ?? 'Request failed';
    throw ApiException(message, statusCode: response.statusCode);
  }

  Future<bool> _tryRefreshToken() async {
    try {
      final refreshToken = await TokenStorage.getRefreshToken();
      print("=== REFRESH token exists: ${refreshToken != null}");
      if (refreshToken == null) return false;

      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(ApiConfig.timeout);
        print("=== REFRESH status: ${response.statusCode}");
        print("=== REFRESH body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await TokenStorage.saveTokens(
          accessToken:  data['accessToken']  as String,
          refreshToken: data['refreshToken'] as String,
        );
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<Map<String, dynamic>> get(String path) async {
    final uri     = Uri.parse('${ApiConfig.baseUrl}$path');
    final headers = await _headers();
    late http.Response response;
    try {
      response = await http.get(uri, headers: headers).timeout(ApiConfig.timeout);
    } on SocketException {
      throw const ApiException('No internet connection.');
    } on HttpException {
      throw const ApiException('Network error.');
    }
    return _handleResponse(
      response,
      retryRequest: () async {
        final h = await _headers();
        return http.get(uri, headers: h).timeout(ApiConfig.timeout);
      },
    );
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool requiresAuth = true,
  }) async {
    final uri     = Uri.parse('${ApiConfig.baseUrl}$path');
    final headers = await _headers(requiresAuth: requiresAuth);
    late http.Response response;
    try {
      response = await http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(ApiConfig.timeout);
    } on SocketException {
      throw const ApiException('No internet connection.');
    } on HttpException {
      throw const ApiException('Network error.');
    }
    return _handleResponse(
      response,
      retryRequest: requiresAuth
          ? () async {
              final h = await _headers();
              return http
                  .post(uri, headers: h, body: jsonEncode(body))
                  .timeout(ApiConfig.timeout);
            }
          : null,
    );
  }

  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri     = Uri.parse('${ApiConfig.baseUrl}$path');
    final headers = await _headers();
    late http.Response response;
    try {
      response = await http
          .put(uri, headers: headers, body: jsonEncode(body))
          .timeout(ApiConfig.timeout);
    } on SocketException {
      throw const ApiException('No internet connection.');
    } on HttpException {
      throw const ApiException('Network error.');
    }
    return _handleResponse(
      response,
      retryRequest: () async {
        final h = await _headers();
        return http
            .put(uri, headers: h, body: jsonEncode(body))
            .timeout(ApiConfig.timeout);
      },
    );
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final uri     = Uri.parse('${ApiConfig.baseUrl}$path');
    final headers = await _headers();
    late http.Response response;
    try {
      response = await http.delete(uri, headers: headers).timeout(ApiConfig.timeout);
    } on SocketException {
      throw const ApiException('No internet connection.');
    } on HttpException {
      throw const ApiException('Network error.');
    }
    return _handleResponse(
      response,
      retryRequest: () async {
        final h = await _headers();
        return http.delete(uri, headers: h).timeout(ApiConfig.timeout);
      },
    );
  }
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