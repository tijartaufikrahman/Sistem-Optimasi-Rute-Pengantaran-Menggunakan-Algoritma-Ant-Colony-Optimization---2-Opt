class PodModel {
  final int? id;
  final int? kirimanId;
  final String? namaPenerima;
  final DateTime? waktuPengantaran;
  final String? koordinat;
  final double? latitude;
  final double? longitude;
  final String? fotoBukti;
  final String? nomorKiriman;
  final String? telepon;
  final String? alamatPenerima;
  final String? kirimanStatus;
  final String? kirimanNamaPenerima;

  PodModel({
    this.id,
    this.kirimanId,
    this.namaPenerima,
    this.waktuPengantaran,
    this.koordinat,
    this.latitude,
    this.longitude,
    this.fotoBukti,
    this.nomorKiriman,
    this.telepon,
    this.alamatPenerima,
    this.kirimanStatus,
    this.kirimanNamaPenerima,
  });

  factory PodModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> kirimanMap = {};
    if (json['kiriman'] is Map) {
      kirimanMap = Map<String, dynamic>.from(
        json['kiriman'] as Map,
      );
    }

    return PodModel(
      id: json['id'],
      kirimanId: json['kirimanId'],
      namaPenerima: json['namaPenerima'],
      waktuPengantaran: json['waktuPengantaran'] != null
          ? DateTime.tryParse(
              json['waktuPengantaran'].toString(),
            )
          : null,
      koordinat: json['koordinat'],
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
      fotoBukti: json['fotoBukti'],
      nomorKiriman: json['nomorKiriman'],
      telepon: json['telepon'],
      alamatPenerima: json['alamatPenerima'],
      kirimanStatus: kirimanMap['status'],
      kirimanNamaPenerima: kirimanMap['namaPenerima'],
    );
  }
}
