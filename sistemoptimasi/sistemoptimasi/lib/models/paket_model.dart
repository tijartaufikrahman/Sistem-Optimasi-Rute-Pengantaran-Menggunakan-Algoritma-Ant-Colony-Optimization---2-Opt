class PaketModel {
  final int id;
  final String? noKiriman;
  final String? recipientName;
  final String? telepon;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? status;

  PaketModel({
    required this.id,
    this.noKiriman,
    this.recipientName,
    this.telepon,
    this.address,    
    this.latitude,
    this.longitude,
    this.status,
  });

  factory PaketModel.fromJson(Map<String, dynamic> json) {
    return PaketModel(
      id: json["id"] ?? json["manifestId"] ?? 0,
      noKiriman: json["nomorKiriman"] ?? json["no_kiriman"] ?? json["noKiriman"],
      recipientName: json["namaPenerima"] ?? json["recipient_name"] ?? json["recipientName"],
      telepon: json["teleponPenerima"] ?? json["telepon"] ?? json["telepon_penerima"],
      address: json["alamatTujuan"] ?? json["address"] ?? json["alamat"],
      status: json["statusPengantaran"] ?? json["statusKiriman"] ?? json["status"],
      latitude: json["latitude"] != null ? (json["latitude"] as num).toDouble() : null,
      longitude: json["longitude"] != null ? (json["longitude"] as num).toDouble() : null,
    );
  }
}
