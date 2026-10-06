class KantorModel {

  final int id;
  final String nama;
  final String kodePos;
  final String alamat;
  final double latitude;
  final double longitude;

  KantorModel({
    required this.id,
    required this.nama,
    required this.kodePos,
    required this.alamat,
    required this.latitude,
    required this.longitude,
  });

  factory KantorModel.fromJson(Map<String, dynamic> json) {
    return KantorModel(
      id: json['id'],
      nama: json['nama'] ?? '',
      kodePos: json['kodePos'] ?? '',
      alamat: json['alamat'] ?? '',
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
    );
  }
}
