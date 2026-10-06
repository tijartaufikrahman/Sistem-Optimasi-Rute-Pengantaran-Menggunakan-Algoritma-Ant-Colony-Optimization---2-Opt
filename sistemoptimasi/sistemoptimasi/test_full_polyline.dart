import 'dart:convert';
import 'dart:io';

List<List<double>> decodePolyline(String encoded) {
  List<List<double>> poly = [];
  int index = 0, len = encoded.length;
  int lat = 0, lng = 0;

  while (index < len) {
    int b, shift = 0, result = 0;
    do {
      if (index >= len) return poly;
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lat += dlat;

    shift = 0;
    result = 0;
    do {
      if (index >= len) return poly;
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lng += dlng;

    final double pLat = lat / 1e6;
    final double pLng = lng / 1e6;

    if (pLat >= -90.0 && pLat <= 90.0 && pLng >= -180.0 && pLng <= 180.0) {
      poly.add([pLng, pLat]);
    }
  }
  return poly;
}

List<List<double>> decodeLegsPolyline(String polylineStr) {
  List<List<double>> allCoords = [];
  final parts = polylineStr.split('|');
  print("Total legs: ${parts.length}");
  for (int i = 0; i < parts.length; i++) {
    final clean = parts[i].trim();
    if (clean.isNotEmpty) {
      final legCoords = decodePolyline(clean);
      print("Leg $i: ${legCoords.length} points");
      if (legCoords.isNotEmpty) {
        print("  Leg $i first: lng=${legCoords.first[0]}, lat=${legCoords.first[1]}");
        print("  Leg $i last: lng=${legCoords.last[0]}, lat=${legCoords.last[1]}");
        allCoords.addAll(legCoords);
      }
    }
  }
  return allCoords;
}

void main() async {
  final client = HttpClient();
  client.badCertificateCallback = (cert, host, port) => true;
  final req = await client.postUrl(Uri.parse("https://localhost:7191/api/drs/2/optimize"));
  req.headers.contentType = ContentType.json;
  req.write("{}");
  final resp = await req.close();
  final body = await resp.transform(utf8.decoder).join();
  final data = jsonDecode(body);
  final polyStr = data["polylineFull"] as String? ?? "";
  print("Polyline string length: ${polyStr.length}");

  final coords = decodeLegsPolyline(polyStr);
  print("Total all coords: ${coords.length}");

  // Check any outliers (jauh dari Bandung)
  int outlierCount = 0;
  for (int i = 0; i < coords.length; i++) {
    final c = coords[i];
    final lng = c[0];
    final lat = c[1];
    // Bandung bounding box: lat -7.2 to -6.7, lng 107.4 to 107.8
    if (lat < -7.2 || lat > -6.7 || lng < 107.4 || lng > 107.8) {
      print("OUTLIER at index $i: lng=$lng, lat=$lat");
      outlierCount++;
      if (outlierCount > 5) break;
    }
  }
  if (outlierCount == 0) {
    print("ALL POINTS ARE PERFECTLY WITHIN BANDUNG!");
  }
}
