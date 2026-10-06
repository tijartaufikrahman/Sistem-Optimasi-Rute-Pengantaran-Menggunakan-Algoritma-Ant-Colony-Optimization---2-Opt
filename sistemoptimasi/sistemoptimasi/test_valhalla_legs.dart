import 'dart:convert';
import 'dart:io';

void main() async {
  final client = HttpClient();
  final req = await client.postUrl(Uri.parse("http://62.171.169.192:8003/route"));
  req.headers.contentType = ContentType.json;
  req.write(jsonEncode({
    "locations": [
      {"lat": -6.88829955, "lon": 107.61561294},
      {"lat": -6.894125, "lon": 107.618451},
      {"lat": -6.892415, "lon": 107.604128}
    ],
    "costing": "auto"
  }));
  final resp = await req.close();
  final body = await resp.transform(utf8.decoder).join();
  final doc = jsonDecode(body);
  final legs = doc["trip"]["legs"] as List;
  print("Legs count: ${legs.length}");
  for (int i = 0; i < legs.length; i++) {
    final s = legs[i]["shape"] as String;
    print("Leg $i shape prefix: ${s.substring(0, 30)}");
  }
}
