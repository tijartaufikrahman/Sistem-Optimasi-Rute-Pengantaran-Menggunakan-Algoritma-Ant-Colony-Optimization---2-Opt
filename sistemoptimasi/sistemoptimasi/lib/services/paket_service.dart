import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sisopt/models/Urutan_Pengantaran.dart';
import '../models/paket_model.dart';
import '../models/penugasan_model.dart';
import '../models/pod_model.dart';
import '../config/api_config.dart';
import '../services/storage_service.dart';

class PaketService {
  final StorageService _storage =StorageService();
   
  Future<List<PaketModel>> getPaket() async {

    String apiUrl = await ApiConfig.getApiUrl();

    final response = await http.get(
      Uri.parse("$apiUrl/api/paket"),
    );

    if (response.statusCode == 200) {

      final List data = jsonDecode(response.body);

      return data.map((e) => PaketModel.fromJson(e)).toList();

    } else {
      throw Exception("Gagal mengambil data paket");
    }
  }
  
  Future<List<UrutanPengantaranModel>> getPaketByKurir({int penugasanId = 4}) async {
    String baseUrl = await ApiConfig.getApiUrl();

    // 1. Coba ambil dari /api/drs/{id}
    try {
      final resDrs = await http.get(Uri.parse("$baseUrl/api/drs/$penugasanId"));
      if (resDrs.statusCode == 200) {
        final json = jsonDecode(resDrs.body);
        if (json is Map && json['kirimanList'] is List) {
          final list = json['kirimanList'] as List;
          return list.map((e) => UrutanPengantaranModel.fromJson(e)).toList();
        }
      }
    } catch (e) {
      print("Error fetch drs by id: $e");
    }

    // 2. Fallback ke endpoint lama jika ada
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/manajemen-antaran/by-penugasan-id/$penugasanId"),
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['data'] != null && json['data'] is List) {
          return (json['data'] as List)
              .map((e) => UrutanPengantaranModel.fromJson(e))
              .toList();
        }
      }
    } catch (_) {}

    return [];
  }

  Future<List<PenugasanModel>> getPenugasan({required String tglAwal, required String tglAkhir}) async {
    String baseUrl = await ApiConfig.getApiUrl();

    int? userId = await _storage.getUserId();
    if (userId == null) {
      throw Exception("User belum login");
    }

    // 1. Ambil dari REST API DRS: GET /api/drs?orangerId={userId}&tglAwal={tglAwal}&tglAkhir={tglAkhir}
    try {
      final urlDrs = Uri.parse('$baseUrl/api/drs?orangerId=$userId&tglAwal=$tglAwal&tglAkhir=$tglAkhir');
      final res = await http.get(urlDrs);
      if (res.statusCode == 200) {
        List<dynamic> data = json.decode(res.body);
        return data.map((item) => PenugasanModel.fromJson(item)).toList();
      }
    } catch (e) {
      print("Fetch DRS failed, trying fallback: $e");
    }

    // 2. Fallback
    final url = Uri.parse('$baseUrl/api/manajemen-antaran/penugasan?tglAwal=$tglAwal&tglAkhir=$tglAkhir&user_id=$userId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => PenugasanModel.fromJson(json)).toList();
      } else {
        throw Exception('Gagal memuat data penugasan DRS');
      }
    } catch (e) {
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  Future<bool> approveDrs({required int drsId}) async {
    String baseUrl = await ApiConfig.getApiUrl();
    int? userId = await _storage.getUserId();

    final response = await http.post(
      Uri.parse("$baseUrl/api/drs/$drsId/approve"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"orangerId": userId ?? 0}),
    );

    return response.statusCode == 200;
  }

  Future<Map<String, dynamic>> checkKiriman({required int drsId, required String nomorKiriman}) async {
    String baseUrl = await ApiConfig.getApiUrl();
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/drs/$drsId/check-kiriman?no=${Uri.encodeComponent(nomorKiriman.trim())}"),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {"success": true, "message": data['message'], "data": data['data']};
      } else {
        return {"success": false, "message": data['message'] ?? "Kiriman tidak valid"};
      }
    } catch (e) {
      return {"success": false, "message": "Gagal terhubung ke server: $e"};
    }
  }

  Future<Map<String, dynamic>> batchSubmitKiriman({
    required int drsId,
    required List<String> nomorKirimanList,
  }) async {
    String baseUrl = await ApiConfig.getApiUrl();
    int? userId = await _storage.getUserId();

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/drs/$drsId/batch-submit-kiriman"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "nomorKirimanList": nomorKirimanList,
          "orangerId": userId ?? 0,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {"success": true, "message": data['message']};
      } else {
        return {"success": false, "message": data['message'] ?? "Gagal menyimpan kiriman ke DRS"};
      }
    } catch (e) {
      return {"success": false, "message": "Terjadi kesalahan koneksi: $e"};
    }
  }

  Future<Map<String, dynamic>> scanKiriman({required int drsId, required String nomorKiriman}) async {
    String baseUrl = await ApiConfig.getApiUrl();
    int? userId = await _storage.getUserId();

    final response = await http.post(
      Uri.parse("$baseUrl/api/drs/$drsId/scan-kiriman"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "nomorKiriman": nomorKiriman.trim(),
        "orangerId": userId ?? 0,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return {"success": true, "message": data['message'], "data": data['data']};
    } else {
      return {"success": false, "message": data['message'] ?? "Gagal mengambil kiriman"};
    }
  }

  Future<bool> closingDrs({required int drsId}) async {
    String baseUrl = await ApiConfig.getApiUrl();
    int? userId = await _storage.getUserId();

    final response = await http.post(
      Uri.parse("$baseUrl/api/drs/$drsId/closing"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"orangerId": userId ?? 0}),
    );

    return response.statusCode == 200;
  }

  Future<PodModel?> cekPod({
    required int kirimanId,
    String? baseUrl,
  }) async {
    baseUrl ??= await ApiConfig.getApiUrl();
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/pod/cek-by-kiriman"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"kirimanId": kirimanId}),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json is Map && json['status'] == true && json['data'] is Map) {
          return PodModel.fromJson(
            Map<String, dynamic>.from(json['data'] as Map),
          );
        }
      }
      return null;
    } catch (e) {
      print("Gagal cek POD: $e");
      return null;
    }
  }

  Future<bool> isPhotoAvailable(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      return response.statusCode == 200;
    } catch (e) {
      print("Gagal cek foto POD: $e");
      return false;
    }
  }

  Future<bool> selesaikanPenugasan({required int jadwalId,}) async {
    String baseUrl = await ApiConfig.getApiUrl();
    print(baseUrl);
    try {
      final response = await http.put(
        Uri.parse("$baseUrl/api/manajemen-antaran/selesaikan-penugasan/$jadwalId"),
        headers: {
          "Content-Type": "application/json",
        },
      );
          
      if (response.statusCode == 200) {
        return true;
      }

      return false;
    } catch (e) {
      throw Exception("Gagal menyelesaikan penugasan: $e");
    }
  }
  Future<Map<String, dynamic>> updateLokasiPaket({
    required int idKiriman,
    required double latitude,
    required double longitude,
  }) async {
    String baseUrl = await ApiConfig.getApiUrl();
    try {
      final response = await http.put(
        Uri.parse("$baseUrl/api/paket/update-lokasi"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "idKiriman": idKiriman,
          "latitude": latitude,
          "longitude": longitude,
        }),
      );
      final data = jsonDecode(response.body);
      return Map<String, dynamic>.from(data);
    } catch (e) {
      print("Gagal update lokasi paket: $e");
      return {"message": "Gagal terhubung ke server"};
    }
  }

  Future<bool> updateKoordinat({
    required int urutanId,
    required double latitude,
    required double longitude,
  }) async {
    String baseUrl = await ApiConfig.getApiUrl();
    try {
      final response = await http.put(
        Uri.parse("$baseUrl/api/manajemen-antaran/update-koordinat"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "urutan_id": urutanId,
          "latitude": latitude,
          "longitude": longitude,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Gagal update koordinat: $e");
      return false;
    }
  }

  Future<bool> updateStatusPengiriman({
    required int urutanId,
    required String status,
    required String namaPenerima,
    required String penerimaStatus,

    File? podPhoto,
    double? podLatitude,
    double? podLongitude,
    DateTime? podDateTime,
  }) async {

    String baseUrl = await ApiConfig.getApiUrl();

    try {

      final request = http.MultipartRequest(
        "POST",
        Uri.parse(
          "$baseUrl/api/manajemen-antaran/update-status-pengiriman",
        ),
      );

      request.fields["UrutanId"] =
          urutanId.toString();

      request.fields["Status"] =
          status;

      request.fields["NamaPenerima"] =
          namaPenerima;

      request.fields["StatusPenerima"] =
          penerimaStatus;

      if (podLatitude != null) {
        request.fields["PodLatitude"] =
            podLatitude.toString();
      }

      if (podLongitude != null) {
        request.fields["PodLongitude"] =
            podLongitude.toString();
      }

      if (podDateTime != null) {
        request.fields["PodDateTime"] =
            podDateTime.toIso8601String();
      }

      if (podPhoto != null) {

        request.files.add(
          await http.MultipartFile.fromPath(
            "PodPhoto",
            podPhoto.path,
          ),
        );
      }

      print("===== FIELDS =====");
      print(request.fields);

      print("===== FILE =====");
      print(podPhoto?.path);

      final response = await request.send();
      final respStr = await response.stream.bytesToString();

      print("===== UPDATE STATUS RESPONSE =====");
      print("STATUS CODE: ${response.statusCode}");
      print("BODY: $respStr");

      if (response.statusCode == 200) {
        return true;
      } else {
        String msg = "Gagal update status (${response.statusCode})";
        try {
          final jsonResp = jsonDecode(respStr);
          if (jsonResp is Map && jsonResp['message'] != null) {
            msg = jsonResp['message'].toString();
          }
        } catch (_) {}
        throw Exception(msg);
      }
    } catch (e) {
      print("Error updateStatusPengiriman: $e");
      rethrow;
    }
  }
}
