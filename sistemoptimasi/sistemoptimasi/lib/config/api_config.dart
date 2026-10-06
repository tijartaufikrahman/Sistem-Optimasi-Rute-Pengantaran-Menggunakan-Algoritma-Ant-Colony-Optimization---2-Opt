import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiConfig {
  static const String firebaseUrl =
      "https://catatan-harian-bcc18-default-rtdb.asia-southeast1.firebasedatabase.app/tes/url.json";

  static String? _cachedUrl;

  static Future<String> getApiUrl({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedUrl != null && _cachedUrl!.isNotEmpty) {
      return _cachedUrl!;
    }

    try {
      final response = await http.get(
        Uri.parse(firebaseUrl),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _cachedUrl = data.toString().trim();
        return _cachedUrl!;
      }
    } catch (_) {
      if (_cachedUrl != null && _cachedUrl!.isNotEmpty) {
        return _cachedUrl!;
      }
    }

    throw Exception("Gagal mengambil URL API");
  }
}
