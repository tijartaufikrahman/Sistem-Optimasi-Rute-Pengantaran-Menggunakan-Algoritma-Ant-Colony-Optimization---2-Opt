import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class KantorService {
  // Default koordinat kantor pos (Bandung) agar tidak pernah 0,0 (ujung dunia)
  double depotLat = -6.88829955;
  double depotLon = 107.61561294;

  Future<Map<String, dynamic>> getKantor() async {
    String baseUrl = await ApiConfig.getApiUrl();

    // 1. Coba endpoint utama /api/kantor
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/kantor"),
      );
      if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
        return jsonDecode(response.body);
      }
    } catch (_) {}

    // 2. Fallback endpoint lama /api/lokasi-kantor/getKantor
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/lokasi-kantor/getKantor"),
      );
      if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
        return jsonDecode(response.body);
      }
    } catch (_) {}

    return {
      "latitude": -6.88829955,
      "longitude": 107.61561294,
    };
  }

  Future<void> loadKantor() async {
    try {
      final data = await getKantor();

      final rawLat = data["latitude"] ?? data["Latitude"];
      final rawLon = data["longitude"] ?? data["Longitude"];

      double? parsedLat;
      double? parsedLon;

      if (rawLat is num) parsedLat = rawLat.toDouble();
      if (rawLat is String) parsedLat = double.tryParse(rawLat);

      if (rawLon is num) parsedLon = rawLon.toDouble();
      if (rawLon is String) parsedLon = double.tryParse(rawLon);

      if (parsedLat != null && parsedLat != 0.0) {
        depotLat = parsedLat;
      }
      if (parsedLon != null && parsedLon != 0.0) {
        depotLon = parsedLon;
      }

      print("✅ DEPOT LOADED: Lat=$depotLat, Lon=$depotLon");
    } catch (e) {
      print("⚠️ ERROR LOAD KANTOR: $e, using default depot ($depotLat, $depotLon)");
    }
  }
}
