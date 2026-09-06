import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/user_role.dart';

class AuthenticatedUser {
  const AuthenticatedUser({
    required this.name,
    required this.role,
    required this.token,
  });

  final String name;
  final UserRole role;
  final String token;
}

class AuthApi {
  String get _baseUrl =>
      kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000';

  Future<AuthenticatedUser> register({
    required String name,
    required String lastName,
    required String phone,
    required String password,
    required UserRole role,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/users/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'last_name': lastName,
        'phone': phone,
        'password': password,
        'role': role.name,
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw AuthApiException(_errorMessage(response));
    }
    return AuthenticatedUser(name: name, role: role, token: '');
  }

  Future<AuthenticatedUser> login({
    required String phone,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'password': password}),
    );
    if (response.statusCode != 200) {
      throw AuthApiException(_errorMessage(response));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final user = data['user'] as Map<String, dynamic>;
    final token = data['access_token'] as String;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('routb_access_token', token);
    return AuthenticatedUser(
      name: user['name'] as String,
      role: user['role'] == UserRole.driver.name
          ? UserRole.driver
          : UserRole.passenger,
      token: token,
    );
  }

  Future<void> logout() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('routb_access_token');
  }

  String _errorMessage(http.Response response) {
    try {
      return (jsonDecode(response.body) as Map<String, dynamic>)['detail']
              as String? ??
          'No se pudo completar la solicitud';
    } on FormatException {
      return 'No se pudo completar la solicitud';
    }
  }
}

class AuthApiException implements Exception {
  const AuthApiException(this.message);
  final String message;
}
