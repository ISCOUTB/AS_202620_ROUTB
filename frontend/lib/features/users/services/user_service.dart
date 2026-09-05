import 'package:http/http.dart' as http;

import 'dart:convert';

import 'package:flutter/foundation.dart';

class UserService {
  Future<bool> registerUser({
    required String name,
    required String lastName,
    required String phone,
    required String password,
  }) async {
    final url = Uri.parse('http://127.0.0.1:8000/users/');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'last_name': lastName,
          'phone': phone,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('Usuario registrado con éxito: ${response.body}');
        return true;
      } else {
        debugPrint('Error en el registro: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Error de conexión: $e');
      return false;
    }
  }
}
