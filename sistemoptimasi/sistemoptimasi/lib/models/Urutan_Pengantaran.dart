import 'paket_model.dart';

class UrutanPengantaranModel {
  final int? urutanId;
  final int? nomorUrutan;
  final String? status;
  final PaketModel paket;

  UrutanPengantaranModel({
    this.urutanId,
    this.nomorUrutan,
    this.status,
    required this.paket,
  });

  factory UrutanPengantaranModel.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('paket') && json['paket'] != null) {
      return UrutanPengantaranModel(
        urutanId: json['urutan_id'] ?? json['id'],
        nomorUrutan: json['nomor_urutan'],
        status: json['status'],
        paket: PaketModel.fromJson(json['paket']),
      );
    }

    // Jika format datang dari DRS detail (DrsDetailItemDto)
    return UrutanPengantaranModel(
      urutanId: json['id'],
      nomorUrutan: json['nomorUrutan'] ?? json['nomor_urutan'],
      status: json['statusPengantaran'] ?? json['status'],
      paket: PaketModel.fromJson(json),
    );
  }
}
