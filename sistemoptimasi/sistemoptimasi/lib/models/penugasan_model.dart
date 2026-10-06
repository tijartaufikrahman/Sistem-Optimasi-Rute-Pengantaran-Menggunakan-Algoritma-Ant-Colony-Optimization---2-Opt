class PenugasanModel {
  final int id;
  final DateTime tanggal;
  final String namaKurir;
  final String kodePenugasan;
  final int jumlahPaket;
  final String? status;
  final double totalBeratKiriman;
  final bool hasOptimasi;

  PenugasanModel({
    required this.id,
    required this.tanggal,
    required this.namaKurir,
    required this.kodePenugasan,
    required this.status,
    required this.jumlahPaket,
    required this.totalBeratKiriman,
    this.hasOptimasi = false,
  });

  factory PenugasanModel.fromJson(Map<String, dynamic> json) {    
    DateTime parseDate(dynamic d) {
      if (d == null) return DateTime.now();
      try {
        return DateTime.parse(d.toString());
      } catch (_) {
        return DateTime.now();
      }
    }

    final rawStatus = json['statusDRS'] ?? json['status'] ?? 'Assigned';
    final hasOpt = json['hasOptimasi'] == true ||
        rawStatus.toString().toLowerCase() == 'sudah dioptimasi';

    return PenugasanModel(
      id: json['id'] ?? json['Id'] ?? 0,
      tanggal: parseDate(json['tanggalTugas'] ?? json['tanggal']),
      namaKurir: json['namaOranger'] ?? json['namaKurir'] ?? '-',
      kodePenugasan: json['noDRS'] ?? json['kodePenugasan'] ?? '-',
      jumlahPaket: json['totalKiriman'] ?? json['jumlahPaket'] ?? 0,
      status: rawStatus,
      totalBeratKiriman: ((json['total_berat_kiriman'] ?? json['totalBeratKiriman'] ?? 0) as num).toDouble(),
      hasOptimasi: hasOpt,
    );
  }
}
