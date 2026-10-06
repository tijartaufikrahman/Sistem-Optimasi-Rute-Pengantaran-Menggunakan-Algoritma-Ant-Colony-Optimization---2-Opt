// import 'package:sisopt/models/Urutan_Pengantaran.dart';

// class JadwalPengantaranModel {
//   final int jadwalId;
//   final int userId;
//   final DateTime tanggal;
//   final int total;
//   final List<UrutanPengantaranModel> data;

//   JadwalPengantaranModel({
//     required this.jadwalId,
//     required this.userId,
//     required this.tanggal,
//     required this.total,
//     required this.data,
//   });

//   factory JadwalPengantaranModel.fromJson(Map<String, dynamic> json) {
//     return JadwalPengantaranModel(
//       jadwalId: json['jadwal_id'],
//       userId: json['user_id'],
//       tanggal: DateTime.parse(json['tanggal']),
//       total: json['total'],
//       data: (json['data'] as List)
//           .map((e) => UrutanPengantaranModel.fromJson(e))
//           .toList(),
//     );
//   }
// }
