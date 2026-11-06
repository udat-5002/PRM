import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  // Mặc định: Localhost cho Windows / Web, 10.0.2.2 cho Android Emulator
  String baseUrl = !kIsWeb && Platform.isAndroid
      ? 'http://10.0.2.2:5000'
      : 'http://localhost:5000';

  String? _token;

  void setToken(String? token) {
    _token = token;
  }

  String? get token => _token;

  Map<String, String> _headers() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Uri _uri(String path, [Map<String, dynamic>? queryParameters]) {
    final uriStr = '$baseUrl$path';
    final uri = Uri.parse(uriStr);
    if (queryParameters != null && queryParameters.isNotEmpty) {
      return uri.replace(
        queryParameters: queryParameters.map(
          (key, value) => MapEntry(key, value.toString()),
        ),
      );
    }
    return uri;
  }

  dynamic _processResponse(http.Response response) {
    final bodyStr = utf8.decode(response.bodyBytes);
    dynamic data;
    if (bodyStr.isNotEmpty) {
      try {
        data = jsonDecode(bodyStr);
      } catch (_) {
        data = bodyStr;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    String errorMsg = 'Lỗi kết nối máy chủ (${response.statusCode})';
    if (data is Map && data.containsKey('message')) {
      errorMsg = data['message'].toString();
    } else if (data is String && data.isNotEmpty) {
      errorMsg = data;
    }
    throw ApiException(response.statusCode, errorMsg);
  }

  Future<dynamic> get(String path, [Map<String, dynamic>? query]) async {
    try {
      final response = await http.get(_uri(path, query), headers: _headers());
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(500, 'Không thể kết nối đến máy chủ: $e');
    }
  }

  Future<dynamic> post(String path, dynamic body) async {
    try {
      final response = await http.post(
        _uri(path),
        headers: _headers(),
        body: jsonEncode(body),
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(500, 'Không thể kết nối đến máy chủ: $e');
    }
  }
}
