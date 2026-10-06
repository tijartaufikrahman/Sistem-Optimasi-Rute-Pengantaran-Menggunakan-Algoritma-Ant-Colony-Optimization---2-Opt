import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/user_model.dart';

class AuthService {

  Future<UserModel> login(
    String username,
    String password,
  ) async {
    final baseUrl = await ApiConfig.getApiUrl();
    print("BASE URL: $baseUrl");

    final url = Uri.parse("$baseUrl/api/auth/login");

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "email": username.trim(),
        "password": password.trim(),
      }),
    );

    print("STATUS: ${response.statusCode}");
    print("BODY: ${response.body}");

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // Cek apakah response dibungkus ApiResponse (success, message, data)
      if (data is Map<String, dynamic>) {
        if (data.containsKey("data") && data["data"] != null) {
          final userData = Map<String, dynamic>.from(data["data"] as Map);
          return UserModel.fromJson(userData);
        }
        return UserModel.fromJson(data);
      }

      throw Exception("Format data login tidak valid");
    } else {
      try {
        final err = jsonDecode(response.body);
        final msg = err['message'] ?? err['Message'] ?? "Login gagal";
        throw Exception(msg);
      } catch (e) {
        if (e is Exception && !e.toString().contains("FormatException")) {
          rethrow;
        }
        throw Exception("Login gagal: periksa email dan password");
      }
    }
  }

}
