import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:sisopt/services/kantor_service.dart';


import '../../services/paket_service.dart';
import '../../models/Urutan_Pengantaran.dart';
import '../../config/api_config.dart';
import '../paketsaya/detail_pengantaran_view.dart';
import 'edit_lokasi_view.dart';

class OptimasiRuteV2 extends StatefulWidget {
  final int penugasanId;
  final String? status; // Status penugasan (null/aktif = bisa diedit, "selesai" = read-only)
  final List<UrutanPengantaranModel>? initialPaketList;

  const OptimasiRuteV2({
    super.key,
    required this.penugasanId,
    this.status,
    this.initialPaketList,
  });

  @override
  State<OptimasiRuteV2> createState() => _OptimasiRuteV2State();
}

class _OptimasiRuteV2State extends State<OptimasiRuteV2> {
  // URL API
  late String baseUrl;
  
  static final Map<int, Uint8List> _pinCache = {};
  static Uint8List? _depotPinCache;

  // Lifecycle & Map State
  bool _isDisposed = false;
  bool _isMapLoaded = false;

  void _safeSetState(VoidCallback fn) {
    if (mounted && !_isDisposed) {
      setState(fn);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    mapboxMap = null;
    pointManager = null;
    super.dispose();
  }

  // Loading
  bool isOptimizing = false;
  String loadingText = "Memproses rute...";

  double totalDistance = 0;
  double totalDuration = 0;
  List segments = [];

  int tambahanMenit = 5; // Nilai waktu berhenti per titik (5 menit)

  List<UrutanPengantaranModel> currentList = [];
  int selectedTab = 0; // 0 = urutan, 1 = ada lokasi, 2 = blm optimasi, 3 = tidak ada
  bool isSaving = false; // Sedang menyimpan urutan hasil optimasi
  bool isClosing = false; // Sedang melakukan closing tugas penugasan

  // Urutan hasil optimasi yang BELUM disimpan (paketId -> urutan)
  final Map<int, int> _localOrder = {};

  bool isValidCoordinate(String? lat, String? lon) {
    if (lat == null || lon == null) return false;
    final latStr = lat.trim();
    final lonStr = lon.trim();

    if (latStr.isEmpty || lonStr.isEmpty) return false;
    if (latStr.toLowerCase() == "null" || lonStr.toLowerCase() == "null") return false;

    final dLat = double.tryParse(latStr);
    final dLon = double.tryParse(lonStr);
    if (dLat == null || dLon == null) return false;
    if (dLat == 0 || dLon == 0) return false;
    return true;
  }

  List<UrutanPengantaranModel> get paketValid {
    return _paketList.where((e) {
      final p = e.paket;
      return isValidCoordinate(p.latitude.toString(), p.longitude.toString());
    }).toList();
  }

  /// Items dengan nomor urutan (sudah masuk rute optimasi).
  /// Jika baru dioptimasi (belum disimpan), urutan diambil dari _localOrder.
  List<UrutanPengantaranModel> get paketUrutanPengantaran {
    if (_localOrder.isNotEmpty) {
      final items = _paketList
          .where((e) => _localOrder.containsKey(e.paket.id))
          .toList()
        ..sort((a, b) => (_localOrder[a.paket.id] ?? 0)
            .compareTo(_localOrder[b.paket.id] ?? 0));
      return items;
    }
    return _paketList
        .where((e) => e.nomorUrutan != null && e.nomorUrutan! > 0)
        .toList()
      ..sort((a, b) => (a.nomorUrutan ?? 0).compareTo(b.nomorUrutan ?? 0));
  }

  /// Items dengan koordinat valid tapi BELUM punya nomor urutan (belum dioptimasi)
  List<UrutanPengantaranModel> get paketBelumOptimasi {
    return _paketList.where((e) {
      final p = e.paket;
      final isValid = isValidCoordinate(p.latitude.toString(), p.longitude.toString());
      final hasUrutan = e.nomorUrutan != null && e.nomorUrutan! > 0;
      final hasLocal = _localOrder.containsKey(e.paket.id);
      return isValid && !hasUrutan && !hasLocal;
    }).toList();
  }

  /// Items tanpa koordinat valid
  List<UrutanPengantaranModel> get paketTidakAdaLokasi {
    return _paketList.where((e) {
      final p = e.paket;
      return !isValidCoordinate(p.latitude.toString(), p.longitude.toString());
    }).toList();
  }

  /// Apakah sudah pernah dioptimasi (dari backend atau hasil optimasi lokal)?
  bool get sudahDioptimasi =>
      _localOrder.isNotEmpty ||
      _paketList.any((e) => e.nomorUrutan != null && e.nomorUrutan! > 0) ||
      (_savedPolyline != null && _savedPolyline!.trim().isNotEmpty) ||
      segments.isNotEmpty ||
      (widget.status?.toLowerCase().contains("optimasi") == true);

  /// Jarak detail: "300 meter" / "1 km 30 m" / "2 km"
  String formatDistance(double km) {
    final totalMeters = (km * 1000).round();
    if (totalMeters < 1000) {
      return "$totalMeters meter";
    }
    final kmPart = totalMeters ~/ 1000;
    final mPart = totalMeters % 1000;
    if (mPart == 0) {
      return "$kmPart km";
    }
    return "$kmPart km $mPart m";
  }

  /// Waktu detail: "40 detik" / "1 menit 23 detik" / "1 jam 5 menit 30 detik"
  String formatDuration(double seconds) {
    final totalSeconds = seconds.round();
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;

    if (h > 0) {
      if (m > 0 && s > 0) return "$h jam $m menit $s detik";
      if (m > 0) return "$h jam $m menit";
      if (s > 0) return "$h jam $s detik";
      return "$h jam";
    }
    if (m > 0) {
      if (s > 0) return "$m menit $s detik";
      return "$m menit";
    }
    return "$s detik";
  }

  /// Format estimasi waktu total menjadi "X jam Y menit"
  String _formatEstimasiWaktu(double totalDetik) {
    final totalMenit = (totalDetik / 60).round();
    final jam = totalMenit ~/ 60;
    final menit = totalMenit % 60;
    if (jam > 0 && menit > 0) {
      return "$jam jam $menit menit";
    }
    if (jam > 0) {
      return "$jam jam";
    }
    return "$menit menit";
  }

  final PaketService _service = PaketService();
  final KantorService _kantorService = KantorService();
  
  List<UrutanPengantaranModel> _paketList = [];
  MapboxMap? mapboxMap;
  PointAnnotationManager? pointManager;

  bool isLoading = true;

  // Data hasil optimasi dari DRS API
  String? _savedPolyline;

  @override
  void initState() {
    super.initState();
    // Jika data paket sudah dibawa dari halaman penugasan/paket saya, langsung tampilkan seketika (0 ms)
    if (widget.initialPaketList != null && widget.initialPaketList!.isNotEmpty) {
      _paketList = List.from(widget.initialPaketList!);
      currentList = paketUrutanPengantaran.isNotEmpty ? paketUrutanPengantaran : paketValid;
      if (currentList.isEmpty && _paketList.isNotEmpty) {
        currentList = _paketList;
      }
      selectedTab = (paketUrutanPengantaran.isNotEmpty) ? 0 : 1;
    }

    init();
    MapboxOptions.setAccessToken(
      "pk.eyJ1IjoidGlqYXJ0YXVfaWtyNSIsImEiOiJjbWg0OXBvd2cxazM3ZjFzYno3NXIwNjdpIn0.dA76Kzi_oYOARmqdVdGH-Q",
    );
  }

  Future<void> init() async {
    try {
      baseUrl = await ApiConfig.getApiUrl();
    } catch (e) {
      print("Error ApiConfig: $e");
    }

    // Load kantor / depot di background tanpa memblokir pemuatan rute
    _kantorService.loadKantor().catchError((e) => print("loadKantor error: $e"));

    if (!mounted || _isDisposed) return;
    await _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted || _isDisposed) return;

    List<UrutanPengantaranModel> list = [];
    bool hasOptimasiFromApi = false;
    double? loadedDistance;
    double? loadedDuration;
    List? loadedSegments;
    String? loadedPolyline;

    // 1. Ambil dari API POST: POST /api/drs/{id}/hasil-optimasi
    try {
      final resOpt = await http.post(
        Uri.parse("$baseUrl/api/drs/${widget.penugasanId}/hasil-optimasi"),
        headers: {
          "Content-Type": "application/json",
          "ngrok-skip-browser-warning": "true",
        },
      ).timeout(const Duration(seconds: 10));

      if (resOpt.statusCode == 200 && resOpt.body.trim().isNotEmpty) {
        final json = jsonDecode(resOpt.body);
        if (json is Map) {
          final rawHasOpt = json['hasOptimasi'] ?? json['HasOptimasi'];
          hasOptimasiFromApi = rawHasOpt == true;

          final rawKiriman = json['kirimanList'] ?? json['KirimanList'];
          if (rawKiriman is List) {
            list = rawKiriman.map((e) => UrutanPengantaranModel.fromJson(e)).toList();
          }

          final rawSegments = json['segments'] ?? json['Segments'];
          if (rawSegments is List) {
            loadedSegments = rawSegments;
          }

          final rawJarak = json['totalJarakKm'] ?? json['TotalJarakKm'];
          if (rawJarak != null) {
            loadedDistance = (rawJarak as num).toDouble();
          }

          final rawMenit = json['totalEstimasiMenit'] ?? json['TotalEstimasiMenit'];
          if (rawMenit != null) {
            loadedDuration = (rawMenit as num).toDouble() * 60;
          }

          final rawPoly = json['polylineFull'] ?? json['PolylineFull'];
          if (rawPoly != null && rawPoly.toString().trim().isNotEmpty) {
            loadedPolyline = rawPoly.toString().trim();
          }

          final rawDepot = json['depot'] ?? json['Depot'];
          if (rawDepot is Map) {
            final lat = rawDepot['latitude'] ?? rawDepot['Latitude'];
            final lon = rawDepot['longitude'] ?? rawDepot['Longitude'];
            if (lat != null && lon != null) {
              _kantorService.depotLat = (lat as num).toDouble();
              _kantorService.depotLon = (lon as num).toDouble();
            }
          }
        }
      }
    } catch (e) {
      print("Info: Endpoint POST /api/drs/${widget.penugasanId}/hasil-optimasi: $e");
    }

    // 2. Fallback jika list masih kosong: GET /api/drs/{id}
    if (list.isEmpty) {
      try {
        final resDrs = await http.get(
          Uri.parse("$baseUrl/api/drs/${widget.penugasanId}"),
          headers: {"ngrok-skip-browser-warning": "true"},
        ).timeout(const Duration(seconds: 10));

        if (resDrs.statusCode == 200 && resDrs.body.trim().isNotEmpty) {
          final jsonDrs = jsonDecode(resDrs.body);
          if (jsonDrs is Map) {
            final rawHasOpt = jsonDrs['hasOptimasi'] ?? jsonDrs['HasOptimasi'];
            hasOptimasiFromApi = rawHasOpt == true;

            final rawKiriman = jsonDrs['kirimanList'] ?? jsonDrs['KirimanList'];
            if (rawKiriman is List) {
              list = rawKiriman.map((e) => UrutanPengantaranModel.fromJson(e)).toList();
            }

            final rawSegments = jsonDrs['segments'] ?? jsonDrs['Segments'];
            if (rawSegments is List && (loadedSegments == null || loadedSegments.isEmpty)) {
              loadedSegments = rawSegments;
            }

            final rawJarak = jsonDrs['totalJarakKm'] ?? jsonDrs['TotalJarakKm'];
            if (rawJarak != null && loadedDistance == null) {
              loadedDistance = (rawJarak as num).toDouble();
            }

            final rawMenit = jsonDrs['totalEstimasiMenit'] ?? jsonDrs['TotalEstimasiMenit'];
            if (rawMenit != null && loadedDuration == null) {
              loadedDuration = (rawMenit as num).toDouble() * 60;
            }

            final rawPoly = jsonDrs['polylineFull'] ?? jsonDrs['PolylineFull'];
            if (rawPoly != null && rawPoly.toString().trim().isNotEmpty && loadedPolyline == null) {
              loadedPolyline = rawPoly.toString().trim();
            }
          }
        }
      } catch (e) {
        print("Fallback GET /api/drs error: $e");
      }
    }

    // 3. Fallback kedua jika masih kosong: GET /api/manajemen-antaran
    if (list.isEmpty) {
      try {
        final res = await http.get(
          Uri.parse("$baseUrl/api/manajemen-antaran/by-penugasan-id/${widget.penugasanId}"),
          headers: {"ngrok-skip-browser-warning": "true"},
        ).timeout(const Duration(seconds: 10));

        if (res.statusCode == 200 && res.body.trim().isNotEmpty) {
          final json = jsonDecode(res.body);
          final dataList = json["data"];
          list = (dataList is List ? dataList : [])
              .map((e) => UrutanPengantaranModel.fromJson(e))
              .toList();
        }
      } catch (e) {
        print("Fallback endpoint error: $e");
      }
    }

    if (!mounted || _isDisposed) return;

    _safeSetState(() {
      _localOrder.clear();
      if (list.isNotEmpty) {
        _paketList = list;
      }
      if (loadedDistance != null) {
        totalDistance = loadedDistance;
      }
      if (loadedDuration != null) {
        totalDuration = loadedDuration;
      }
      if (loadedSegments != null) {
        segments = loadedSegments;
      }
      if (loadedPolyline != null) {
        _savedPolyline = loadedPolyline;
      }

      final bool isOptimized = hasOptimasiFromApi || sudahDioptimasi;
      if (isOptimized && paketUrutanPengantaran.isNotEmpty) {
        currentList = paketUrutanPengantaran;
        selectedTab = 0;
      } else if (paketValid.isNotEmpty) {
        currentList = paketValid;
        selectedTab = 1;
      } else {
        currentList = _paketList;
        selectedTab = 1;
      }
      isLoading = false;
    });

    // Jika peta sudah selesai dimuat, langsung render sesuai statusnya
    if (_isMapLoaded && mapboxMap != null) {
      await _renderMapContent();
    }
  }

  /// ==========================================
  /// RENDER DISPATCHER TUNGGAL: BEBAS FLICKER & TANPA DUPLIKASI
  /// ==========================================
  Future<void> _renderMapContent() async {
    if (mapboxMap == null || pointManager == null || !_isMapLoaded || !mounted || _isDisposed) return;

    if (sudahDioptimasi) {
      await _renderOptimizedRoute();
    } else {
      await _renderUnoptimizedPoints();
    }
  }

  /// Helper: decode polyline langsung dari list segments tanpa resiko terpotong delimiter
  List<List<double>> _decodeSegmentsPolyline(List<dynamic> segList) {
    List<List<double>> allCoords = [];
    for (var seg in segList) {
      String shape = "";
      if (seg is Map) {
        shape = (seg["polylineSegmen"] ??
                seg["PolylineSegmen"] ??
                seg["polyline_segmen"] ??
                seg["shape"] ??
                "")
            .toString()
            .trim();
      }
      if (shape.isNotEmpty) {
        try {
          final legCoords = _decodePolyline(shape);
          if (legCoords.isNotEmpty) {
            allCoords.addAll(legCoords);
          }
        } catch (e) {
          print("⚠️ Warning decode segment polyline: $e");
        }
      }
    }
    return allCoords;
  }

  /// Helper: decode polyline yang bisa mengandung delimiter ';' atau pemisah leg
  List<List<double>> _decodeLegsPolyline(String polylineStr) {
    List<List<double>> allCoords = [];
    final delimiter = polylineStr.contains(';') ? ';' : null;
    final parts = delimiter != null ? polylineStr.split(';') : [polylineStr];
    for (var p in parts) {
      final clean = p.trim();
      if (clean.isNotEmpty) {
        try {
          final legCoords = _decodePolyline(clean);
          if (legCoords.isNotEmpty) {
            allCoords.addAll(legCoords);
          }
        } catch (e) {
          print("⚠️ Warning decode leg polyline: $e");
        }
      }
    }
    return allCoords;
  }

  /// ==========================================
  /// 1. RENDER RUTE SUDAH OPTIMASI (INSTAN & BATCH)
  /// ==========================================
  Future<void> _renderOptimizedRoute() async {
    if (mapboxMap == null || pointManager == null || !_isMapLoaded || !mounted || _isDisposed) return;

    try {
      // 1. Bersihkan layer circle titik biru agar tidak ada sisa titik acak
      try {
        if (await mapboxMap!.style.styleLayerExists("paket-layer")) {
          await mapboxMap!.style.removeStyleLayer("paket-layer");
        }
        if (await mapboxMap!.style.styleSourceExists("paket-source")) {
          await mapboxMap!.style.removeStyleSource("paket-source");
        }
      } catch (_) {}

      final validList = paketUrutanPengantaran.isNotEmpty ? paketUrutanPengantaran : paketValid;
      final List<PointAnnotationOptions> annotations = [];

      // 2. Siapkan Pin Depot
      final depotIcon = await _createDepotPin();
      annotations.add(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(
              _kantorService.depotLon,
              _kantorService.depotLat,
            ),
          ),
          image: depotIcon,
          iconSize: 1.4,
        ),
      );

      // 3. Siapkan Pin Nomor Urutan secara paralel (hemat waktu drastis)
      final pinFutures = <Future<PointAnnotationOptions?>>[];
      for (int i = 0; i < validList.length; i++) {
        final p = validList[i].paket;
        final lat = double.tryParse(p.latitude.toString());
        final lon = double.tryParse(p.longitude.toString());
        if (lat == null || lon == null) continue;
        final orderNum = i + 1;
        pinFutures.add(() async {
          final icon = await _createPin(orderNum);
          return PointAnnotationOptions(
            geometry: Point(coordinates: Position(lon, lat)),
            image: icon,
            iconSize: 1.3,
          );
        }());
      }

      final resolvedPins = await Future.wait(pinFutures);
      if (!mounted || _isDisposed) return;

      for (var pin in resolvedPins) {
        if (pin != null) annotations.add(pin);
      }

      // Hapus pin lama & buat sekaligus dalam 1 panggilan platform channel
      await pointManager!.deleteAll();
      if (annotations.isNotEmpty) {
        await pointManager!.createMulti(annotations);
      }

      // 4. Render Polyline Rute
      List<List<double>> allCoords = [];
      if (segments.isNotEmpty) {
        allCoords = _decodeSegmentsPolyline(segments);
      }
      if (allCoords.isEmpty && _savedPolyline != null && _savedPolyline!.trim().isNotEmpty) {
        allCoords = _decodeLegsPolyline(_savedPolyline!);
      }

      if (allCoords.isNotEmpty) {
        await _renderRouteMainLayer(allCoords);
        await _fitRoute(allCoords);
      } else {
        await _fitAllMarkers();
      }
    } catch (e) {
      print("Error _renderOptimizedRoute: $e");
    }
  }

  /// ==========================================
  /// 2. RENDER TITIK BELUM DIOPTIMASI
  /// ==========================================
  Future<void> _renderUnoptimizedPoints() async {
    if (mapboxMap == null || pointManager == null || !_isMapLoaded || !mounted || _isDisposed) return;

    try {
      // Hapus layer rute jika ada
      try {
        if (await mapboxMap!.style.styleLayerExists("route_main")) {
          await mapboxMap!.style.removeStyleLayer("route_main");
        }
        if (await mapboxMap!.style.styleSourceExists("route_main")) {
          await mapboxMap!.style.removeStyleSource("route_main");
        }
      } catch (_) {}

      final List<Map<String, dynamic>> features = [];
      for (var item in _paketList) {
        final p = item.paket;
        final lat = double.tryParse(p.latitude.toString());
        final lng = double.tryParse(p.longitude.toString());
        if (lat != null && lng != null) {
          features.add({
            "type": "Feature",
            "geometry": {
              "type": "Point",
              "coordinates": [lng, lat]
            }
          });
        }
      }

      try {
        if (await mapboxMap!.style.styleLayerExists("paket-layer")) {
          await mapboxMap!.style.removeStyleLayer("paket-layer");
        }
        if (await mapboxMap!.style.styleSourceExists("paket-source")) {
          await mapboxMap!.style.removeStyleSource("paket-source");
        }
      } catch (_) {}

      final geoJson = {
        "type": "FeatureCollection",
        "features": features,
      };

      await mapboxMap!.style.addSource(
        GeoJsonSource(id: "paket-source", data: jsonEncode(geoJson)),
      );
      await mapboxMap!.style.addLayer(
        CircleLayer(
          id: "paket-layer",
          sourceId: "paket-source",
          circleRadius: 6,
          circleColor: const Color(0xff02A8F4).toARGB32(),
        ),
      );

      // Depot Pin
      await pointManager!.deleteAll();
      final depotIcon = await _createDepotPin();
      await pointManager!.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(_kantorService.depotLon, _kantorService.depotLat),
          ),
          image: depotIcon,
          iconSize: 1.4,
        ),
      );

      await _fitAllMarkers();
    } catch (e) {
      print("Warning _renderUnoptimizedPoints: $e");
    }
  }

  /// ==========================================
  /// 🔥 PROSES UTAMA: OPTIMASI KE /api/drs/{id}/optimize
  /// Parameter ACO + 2-Opt
  /// ==========================================
  Future<void> _optimasiRute() async {
    if (mapboxMap == null || pointManager == null) {
      _showSnackBar("Peta belum siap, coba lagi sebentar lagi.", isError: true);
      return;
    }

    final baseList = paketValid;
    if (baseList.isEmpty) {
      _showSnackBar("Tidak ada kiriman dengan titik lokasi valid.", isError: true);
      return;
    }

    _safeSetState(() {
      isOptimizing = true;
      loadingText = "Menghitung rute optimal (ACO + 2-Opt)...";
    });

    try {
      final optRes = await http.post(
        Uri.parse("$baseUrl/api/drs/${widget.penugasanId}/optimize"),
        headers: {"Content-Type": "application/json"},
      );

      if (optRes.statusCode != 200) {
        throw Exception("Optimasi gagal (${optRes.statusCode}): ${optRes.body}");
      }

      final optData = jsonDecode(optRes.body);
      if (optData is! Map || optData['success'] != true) {
        throw Exception(optData is Map ? (optData['message'] ?? "Optimasi gagal") : "Optimasi gagal");
      }

      final orderedDetailIds = (optData["orderedDetailIds"] ?? []) as List;
      final polylineStr = (optData["polylineFull"] ?? "") as String;
      final double totalDist = (optData["totalDistanceKm"] ?? 0).toDouble();
      final double totalMenit = (optData["totalDurationMenit"] ?? 0).toDouble();
      final segList = (optData["segments"] ?? []) as List;

      _safeSetState(() {
        loadingText = "Menyusun urutan pengantaran...";
      });

      final localOrder = <int, int>{};
      final newList = <UrutanPengantaranModel>[];

      for (int i = 0; i < orderedDetailIds.length; i++) {
        final detailId = ((orderedDetailIds[i] ?? 0) as num).toInt();
        final orderNumber = i + 1;

        final index = _paketList.indexWhere((e) => e.urutanId == detailId || e.paket.id == detailId);
        if (index != -1) {
          final targetItem = _paketList[index];
          localOrder[targetItem.paket.id] = orderNumber;
          newList.add(targetItem);
        }
      }

      for (var e in _paketList) {
        if (!localOrder.containsKey(e.paket.id)) {
          newList.add(e);
        }
      }

      if (!mounted || _isDisposed) return;

      _safeSetState(() {
        _localOrder
          ..clear()
          ..addAll(localOrder);
        _paketList = newList;
        currentList = paketUrutanPengantaran;
        selectedTab = 0;
        totalDistance = totalDist;
        totalDuration = totalMenit * 60;
        segments = segList;
        _savedPolyline = polylineStr;
        loadingText = "Menggambar rute di peta...";
      });

      // Langsung gambar rute optimal tanpa flicker dan tanpa titik biru
      await _renderOptimizedRoute();

      _showSnackBar("Optimasi ACO + 2-Opt berhasil! Tekan Simpan Hasil untuk menyimpan.");
    } catch (e) {
      print("ERROR OPTIMASI RUTE: $e");
      _showSnackBar("Gagal optimasi: $e", isError: true);
    } finally {
      _safeSetState(() {
        isOptimizing = false;
      });
    }
  }

  /// Helper aman untuk menghapus dan menambahkan layer polyline rute utama
  Future<void> _renderRouteMainLayer(List<List<double>> allCoords) async {
    if (mapboxMap == null || allCoords.isEmpty || !mounted || _isDisposed) return;

    try {
      if (await mapboxMap!.style.styleLayerExists("route_main")) {
        await mapboxMap!.style.removeStyleLayer("route_main");
      }
    } catch (_) {}

    try {
      if (await mapboxMap!.style.styleSourceExists("route_main")) {
        await mapboxMap!.style.removeStyleSource("route_main");
      }
    } catch (_) {}

    final geoJson = {
      "type": "Feature",
      "geometry": {
        "type": "LineString",
        "coordinates": allCoords
      }
    };

    try {
      await mapboxMap!.style.addSource(
        GeoJsonSource(id: "route_main", data: jsonEncode(geoJson)),
      );

      await mapboxMap!.style.addLayer(
        LineLayer(
          id: "route_main",
          sourceId: "route_main",
          lineColor: const Color(0xFF0288D1).toARGB32(),
          lineWidth: 5.5,
          lineJoin: LineJoin.ROUND,
          lineCap: LineCap.ROUND,
        ),
      );
    } catch (e) {
      print("Warning addLayer route_main: $e");
    }
  }

  /// ==========================================
  /// 🔥 SIMPAN HASIL OPTIMASI KE /api/drs/{id}/save-optimasi
  /// ==========================================
  Future<void> _simpanUrutan() async {
    if (isSaving) return;

    final urutanList = paketUrutanPengantaran;
    if (urutanList.isEmpty) {
      _showSnackBar("Belum ada urutan untuk disimpan. Lakukan optimasi dulu.",
          isError: true);
      return;
    }

    _safeSetState(() => isSaving = true);

    try {
      final savePayload = {
        "deliveryRunSheetId": widget.penugasanId,
        "totalJarakKm": totalDistance,
        "totalEstimasiMenit": totalDuration / 60.0,
        "polylineFull": _savedPolyline ?? "",
        "segments": segments
      };

      final res = await http.post(
        Uri.parse("$baseUrl/api/drs/${widget.penugasanId}/save-optimasi"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(savePayload),
      );

      final data = res.body.isNotEmpty ? jsonDecode(res.body) : null;
      final message = data is Map ? (data["message"] ?? "Hasil optimasi berhasil disimpan.") : "Hasil optimasi berhasil disimpan.";

      if (res.statusCode == 200) {
        _safeSetState(() => _localOrder.clear());
        _showSnackBar("$message ✓");
        try {
          await _loadData();
        } catch (e) {
          print("WARNING RELOAD SETELAH SIMPAN: $e");
        }
      } else {
        _showSnackBar("Gagal menyimpan: $message", isError: true);
      }
    } catch (e) {
      print("ERROR SIMPAN: $e");
      _showSnackBar("Terjadi error saat menyimpan: $e", isError: true);
    } finally {
      _safeSetState(() => isSaving = false);
    }
  }

  /// ==========================================
  /// 🔥 CLOSING PENUGASAN DRS
  /// ==========================================
  Future<void> _prosesClosingDrs() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Selesaikan Tugas (Closing)?"),
        content: const Text(
          "Apakah Anda yakin ingin menyelesaikan tugas penugasan ini? Status DRS akan diubah menjadi Completed dan rute akan diarsipkan.",
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Ya, Selesaikan", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted || _isDisposed) return;

    _safeSetState(() {
      isClosing = true;
      loadingText = "Menyelesaikan penugasan (Closing)...";
    });

    try {
      bool success = await _service.closingDrs(drsId: widget.penugasanId);
      if (!success) {
        success = await _service.selesaikanPenugasan(jadwalId: widget.penugasanId);
      }

      if (!success) {
        throw Exception("Gagal menyelesaikan penugasan DRS.");
      }

      if (mounted && !_isDisposed) {
        _showSnackBar("Tugas penugasan berhasil diselesaikan (Closing) ✓");
        Navigator.pop(context, true);
      }
    } catch (e) {
      print("ERROR CLOSING: $e");
      _showSnackBar("Gagal closing tugas: $e", isError: true);
    } finally {
      _safeSetState(() => isClosing = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted || _isDisposed) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// ============================
  /// 🔥 PIN GENERATOR & DECODER
  /// ============================
  Future<Uint8List> _createPin(int number) async {    
    if (_pinCache.containsKey(number)) {
      return _pinCache[number]!;
    }

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = const Color(0xFFE53935);
    const center = Offset(28, 28);

    canvas.drawCircle(center, 22, paint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: "$number",
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );

    final img = await recorder.endRecording().toImage(56, 56);
    final data = await img.toByteData(format: ImageByteFormat.png);
    final bytes = data!.buffer.asUint8List();

    _pinCache[number] = bytes;
    return bytes;
  }

  Future<Uint8List> _createDepotPin() async {
    if (_depotPinCache != null) return _depotPinCache!;
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = const Color(0xFF004B87);
    const center = Offset(28, 28);

    canvas.drawCircle(center, 24, paint);
    final textPainter = TextPainter(
      text: const TextSpan(
        text: "D",
        style: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
    final img = await recorder.endRecording().toImage(56, 56);
    final data = await img.toByteData(format: ImageByteFormat.png);
    _depotPinCache = data!.buffer.asUint8List();
    return _depotPinCache!;
  }

  List<List<double>> _decodePolyline(String encoded) {
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

  Future<void> _fitRoute(List<List<double>> coords) async {
    if (coords.isEmpty || mapboxMap == null || !mounted || _isDisposed) return;
    try {
      double minLng = coords[0][0];
      double maxLng = coords[0][0];
      double minLat = coords[0][1];
      double maxLat = coords[0][1];

      for (final c in coords) {
        if (c[0] < minLng) minLng = c[0];
        if (c[0] > maxLng) maxLng = c[0];
        if (c[1] < minLat) minLat = c[1];
        if (c[1] > maxLat) maxLat = c[1];
      }

      final centerLat = (minLat + maxLat) / 2;
      final centerLng = (minLng + maxLng) / 2;

      // Hitung delta untuk menentukan level zoom yang pas
      final deltaLat = (maxLat - minLat).abs();
      final deltaLng = (maxLng - minLng).abs();
      final maxDelta = deltaLat > deltaLng ? deltaLat : deltaLng;

      double zoom = 12.5;
      if (maxDelta > 0.5) {
        zoom = 9.5;
      } else if (maxDelta > 0.2) {
        zoom = 10.5;
      } else if (maxDelta > 0.1) {
        zoom = 11.5;
      } else if (maxDelta > 0.05) {
        zoom = 12.2;
      } else {
        zoom = 13.0;
      }

      await mapboxMap!.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(centerLng, centerLat)),
          zoom: zoom,
        ),
        MapAnimationOptions(duration: 700),
      );
    } catch (e) {
      print("Error _fitRoute: $e");
    }
  }

  void _onMapCreated(MapboxMap map) async {
    mapboxMap = map;
    pointManager = await mapboxMap!.annotations.createPointAnnotationManager();
    _isMapLoaded = true;
    await mapboxMap!.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(
          _kantorService.depotLon,
          _kantorService.depotLat,
        )),
        zoom: 12,
      ),
    );
    if (!isLoading && mounted && !_isDisposed) {
      await _renderMapContent();
    }
  }

  Future<void> _fitAllMarkers() async {
    if (_paketList.isEmpty || mapboxMap == null || !mounted || _isDisposed) return;
    double? minLat, maxLat, minLng, maxLng;

    for (var item in _paketList) {
      final lat = double.tryParse(item.paket.latitude.toString());
      final lng = double.tryParse(item.paket.longitude.toString());

      if (lat == null || lng == null) continue;

      minLat = (minLat == null) ? lat : (lat < minLat ? lat : minLat);
      maxLat = (maxLat == null) ? lat : (lat > maxLat ? lat : maxLat);
      minLng = (minLng == null) ? lng : (lng < minLng ? lng : minLng);
      maxLng = (maxLng == null) ? lng : (lng > maxLng ? lng : maxLng);
    }

    if (minLat == null || maxLat == null || minLng == null || maxLng == null) {
      await mapboxMap!.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(
            _kantorService.depotLon,
            _kantorService.depotLat,
          )),
          zoom: 12,
        ),
        MapAnimationOptions(duration: 600),
      );
      return;
    }

    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;

    await mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(centerLng, centerLat)),
        zoom: 12,
      ),
      MapAnimationOptions(duration: 600),
    );
  }

  double get totalWaktuFinal {
    return totalDuration + (_paketList.length * tambahanMenit * 60);
  }

  /// Warna & label chip status pengiriman
  Color _statusColor(String? status) {
    switch (status?.toLowerCase().trim()) {
      case "delivered":
        return const Color(0xFF2E7D32);
      case "on_delivery":
        return const Color(0xFFE65100);
      case "returned":
        return const Color(0xFFC62828);
      case "manifested":
        return const Color(0xFF004B87);
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String? status) {
    if (status == null || status.trim().isEmpty) {
      return "Tanpa Status";
    }
    switch (status.toLowerCase().trim()) {
      case "delivered":
        return "Delivered";
      case "on_delivery":
        return "On Delivery";
      case "returned":
        return "Returned";
      case "manifested":
        return "Manifested";
      default:
        return status;
    }
  }

  Widget _statusChip(String? status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Widget untuk menampilkan nomor urutan / icon status
  Widget _buildItemNumber(UrutanPengantaranModel item) {
    final isValid = isValidCoordinate(
      item.paket.latitude.toString(),
      item.paket.longitude.toString(),
    );

    // ✅ Tidak punya lokasi → icon abu-abu (jangan kasih nomor)
    if (!isValid) {
      return const CircleAvatar(
        backgroundColor: Colors.grey,
        child: Icon(Icons.location_off, size: 18, color: Colors.white),
      );
    }

    // ✅ Hasil optimasi terbaru (belum disimpan) → nomor dari urutan lokal
    final localOrder = _localOrder[item.paket.id];
    if (localOrder != null) {
      return CircleAvatar(
        backgroundColor: const Color(0xFF004B87),
        child: Text(
          "$localOrder",
          style: const TextStyle(color: Colors.white),
        ),
      );
    }

    // ✅ Sudah dioptimasi → tampilkan nomor urutan asli dari backend
    if (item.nomorUrutan != null && item.nomorUrutan! > 0) {
      return CircleAvatar(
        backgroundColor: const Color(0xFF004B87),
        child: Text(
          "${item.nomorUrutan}",
          style: const TextStyle(color: Colors.white),
        ),
      );
    }

    // ✅ Belum dioptimasi → icon pending (jangan kasih nomor)
    return const CircleAvatar(
      backgroundColor: Colors.orange,
      child: Icon(Icons.hourglass_empty, size: 18, color: Colors.white),
    );
  }

  /// ============================
  /// 🔥 UI (DESAIN TETAP DIPERTAHANKAN)
  /// ============================
  @override
  Widget build(BuildContext context) {
    final bool sudahAdaRute =
        totalDistance > 0 || totalDuration > 0;
    final bool isReadOnly = (widget.status?.toLowerCase() == 'selesai');

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Optimasi Rute",
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        backgroundColor: const Color(0xFF004B87),
        actions: [
          if (!isReadOnly)
            IconButton(
              icon: isClosing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline, color: Colors.white),
              tooltip: "Selesaikan Tugas (Closing)",
              onPressed: (isOptimizing || isSaving || isClosing) ? null : _prosesClosingDrs,
            ),
        ],
      ),
      body: Stack(
        children: [
          MapWidget(
            key: const ValueKey("mapWidget"),
            onMapCreated: _onMapCreated,
            onMapLoadedListener: (event) async {
              _isMapLoaded = true;
              if (!mounted || _isDisposed) return;
              if (!isLoading) {
                await _renderMapContent();
              }
            },
          ),
          if (isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.white.withValues(alpha: 0.85),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF004B87)),
                      SizedBox(height: 14),
                      Text(
                        "Memuat data rute pengantaran...",
                        style: TextStyle(
                          color: Color(0xFF004B87),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
                DraggableScrollableSheet(
                  initialChildSize: 0.25,
                  minChildSize: 0.15,
                  maxChildSize: 1.0,
                  builder: (context, scrollController) {
                    return Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: ListView(
                        controller: scrollController,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    /// 🔥 BUTTON OPTIMASI (REQUEST /run)
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: (isReadOnly || isOptimizing || isSaving || isClosing)
                                            ? null
                                            : _optimasiRute,
                                        icon: Icon(sudahDioptimasi ? Icons.refresh : Icons.route, size: 18),
                                        label: Text(sudahDioptimasi ? "Optimasi Ulang" : "Optimasi Rute"),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF004B87),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    /// 🔥 BUTTON SIMPAN HASIL (/save-urutan)
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: (isReadOnly || isOptimizing || isSaving || isClosing)
                                            ? null
                                            : _simpanUrutan,
                                        icon: const Icon(Icons.save_outlined,
                                            size: 18),
                                        label: Text(isSaving
                                            ? "Menyimpan..."
                                            : "Simpan Hasil"),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              const Color(0xFF004B87),
                                          side: const BorderSide(
                                              color: Color(0xFF004B87)),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                /// CARD INFO (Desain Baru)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF004B87).withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFF004B87).withValues(alpha: 0.12),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: const [
                                          Icon(Icons.route, size: 16, color: Color(0xFF004B87)),
                                          SizedBox(width: 6),
                                          Text(
                                            "INFORMASI PERJALANAN",
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.8,
                                              color: Color(0xFF004B87),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      /// STATUS RUTE (kartu berwarna agar jelas)
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: sudahDioptimasi
                                              ? const Color(0xFF2E7D32).withValues(alpha: 0.08)
                                              : const Color(0xFFC62828).withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: sudahDioptimasi
                                                ? const Color(0xFF2E7D32).withValues(alpha: 0.35)
                                                : const Color(0xFFC62828).withValues(alpha: 0.35),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              sudahDioptimasi
                                                  ? Icons.check_circle_rounded
                                                  : Icons.error_outline_rounded,
                                              size: 16,
                                              color: sudahDioptimasi
                                                  ? const Color(0xFF2E7D32)
                                                  : const Color(0xFFC62828),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                sudahDioptimasi
                                                    ? "Rute sudah dioptimasi"
                                                    : "Rute belum dioptimasi",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: sudahDioptimasi
                                                      ? const Color(0xFF2E7D32)
                                                      : const Color(0xFFC62828),
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      IntrinsicHeight(
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            Expanded(
                                              child: _summaryTile(
                                                Icons.straighten,
                                                "Total Jarak",
                                                sudahAdaRute
                                                    ? formatDistance(totalDistance)
                                                    : "-",
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: _summaryTile(
                                                Icons.timer_outlined,
                                                "Waktu Perjalanan",
                                                sudahAdaRute
                                                    ? _formatEstimasiWaktu(totalDuration)
                                                    : "-",
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                /// CARD RINCIAN WAKTU
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(top: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF004B87).withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFF004B87).withValues(alpha: 0.12),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: const [
                                          Icon(Icons.schedule, size: 16, color: Color(0xFF004B87)),
                                          SizedBox(width: 6),
                                          Text(
                                            "RINCIAN WAKTU",
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.8,
                                              color: Color(0xFF004B87),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      _waktuRow(
                                        Icons.directions_car_outlined,
                                        "Waktu Perjalanan",
                                        sudahAdaRute
                                            ? _formatEstimasiWaktu(totalDuration)
                                            : "-",
                                      ),
                                      const SizedBox(height: 8),
                                      _waktuRow(
                                        Icons.pause_circle_outline,
                                        "Waktu Berhenti (${_paketList.length} titik × $tambahanMenit menit)",
                                        sudahAdaRute
                                            ? _formatEstimasiWaktu(_paketList.length * tambahanMenit * 60)
                                            : "-",
                                      ),
                                      const SizedBox(height: 8),
                                      const Divider(color: Color(0xFF004B87)),
                                      const SizedBox(height: 8),
                                      _waktuRow(
                                        Icons.timer_outlined,
                                        "Total Estimasi Waktu",
                                        sudahAdaRute
                                            ? _formatEstimasiWaktu(totalWaktuFinal)
                                            : "-",
                                        isTotal: true,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  "Jumlah Kiriman: ${_paketList.length}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  if (sudahDioptimasi)
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          selectedTab = 0;
                                          currentList = paketUrutanPengantaran;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                        margin: const EdgeInsets.only(right: 6),
                                        decoration: BoxDecoration(
                                          color: selectedTab == 0 ? const Color(0xFF004B87) : Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          "Urutan Pengantaran (${paketUrutanPengantaran.length})",
                                          style: TextStyle(
                                            color: selectedTab == 0 ? Colors.white : Colors.black,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        selectedTab = 1;
                                        currentList = paketValid;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                      margin: const EdgeInsets.only(right: 6),
                                      decoration: BoxDecoration(
                                        color: selectedTab == 1 ? const Color(0xFF004B87) : Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        "Titik Lokasi Tersedia(${paketValid.length})",
                                        style: TextStyle(
                                          color: selectedTab == 1 ? Colors.white : Colors.black,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (paketBelumOptimasi.isNotEmpty)
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          selectedTab = 2;
                                          currentList = paketBelumOptimasi;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                        margin: const EdgeInsets.only(right: 6),
                                        decoration: BoxDecoration(
                                          color: selectedTab == 2 ? Colors.orange : Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          "Belum Di Optimasi (${paketBelumOptimasi.length})",
                                          style: TextStyle(
                                            color: selectedTab == 2 ? Colors.white : Colors.black,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        selectedTab = 3;
                                        currentList = paketTidakAdaLokasi;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: selectedTab == 3 ? Colors.red : Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        "Titik Lokasi Tidak Tersedia (${paketTidakAdaLokasi.length})",
                                        style: TextStyle(
                                          color: selectedTab == 3 ? Colors.white : Colors.black,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          Padding(
  padding: const EdgeInsets.symmetric(
    horizontal: 26,
    vertical: 5,
  ),
  child: Row(
    children: [

      // const Icon(
      //   Icons.route,
      //   size: 20,
      //   color: Color(0xff004B8D),
      // ),

      // const SizedBox(width: 8),

      // const Text(
      //   "Urutan Pengantaran",
      //   style: TextStyle(
      //     color: Color(0xff004B8D),
      //     fontWeight: FontWeight.bold,
      //     fontSize: 16,
      //   ),
      // ),

    ],
  ),
),

                          

                          /// 🔥 LIST PAKET
                          if (currentList.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                                    const SizedBox(height: 10),
                                    Text(
                                      _paketList.isEmpty
                                          ? "Belum ada kiriman dalam tugas ini."
                                          : "Tidak ada kiriman pada kategori tab ini.",
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: currentList.length,
                            itemBuilder: (context, index) {
                              final paket = currentList[index].paket;
                              final isValid = isValidCoordinate(
                                paket.latitude.toString(),
                                paket.longitude.toString(),
                              );
                              final bool hasPhone = paket.telepon != null && paket.telepon.toString().trim().isNotEmpty;
                              return GestureDetector(
                                onTap: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DetailPengantaranView(
                                        item: currentList[index],
                                      ),
                                    ),
                                  );
                                  if (result == true && mounted && !_isDisposed) {
                                    await _loadData();
                                  }
                                },
                                child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    )
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _statusChip(currentList[index].status),
                                    const SizedBox(height: 8),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildItemNumber(currentList[index]),
                                        const SizedBox(width: 12),
                                        Expanded(
                                            child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              paket.recipientName ?? "-",
                                              
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              paket.address ?? "-",
                                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                                            ),
                                            if (hasPhone) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                paket.telepon.toString(),
                                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                                              ),
                                            ],
                                            const SizedBox(height: 4),
                                            Text(
                                              isValid ? "📍 Titik lokasi Tersedia" : "⚠️ Belum ada Titik lokasi",
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isValid ? Colors.green : Colors.red,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        )),
                                         if (isValid && segments.isNotEmpty && index < segments.length)
                                           IntrinsicWidth(
                                             child: Column(
                                               crossAxisAlignment: CrossAxisAlignment.stretch,
                                               children: [
                                                 Text(
                                                   index == 0 ? "Dari Kantor" : "Dari Titik $index",
                                                   textAlign: TextAlign.right,
                                                   style: const TextStyle(fontSize: 10, color: Colors.grey),
                                                 ),
                                                 const SizedBox(height: 2),
                                                 Row(
                                                   children: [
                                                     const SizedBox(
                                                       width: 16,
                                                       child: Icon(Icons.route, size: 14, color: Color(0xFF004B87)),
                                                     ),
                                                     const SizedBox(width: 4),
                                                     Builder(
                                                       builder: (_) {
                                                         final seg = segments[index];
                                                         final distKm = (seg["jarakKm"] ?? seg["distance"] ?? 0) as num;
                                                         return Text(
                                                           formatDistance(distKm.toDouble()),
                                                           style: const TextStyle(fontSize: 12),
                                                         );
                                                       },
                                                     ),
                                                   ],
                                                 ),
                                                 const SizedBox(height: 4),
                                                 Row(
                                                   children: [
                                                     const SizedBox(
                                                       width: 16,
                                                       child: Icon(Icons.timer, size: 14, color: Color(0xFF004B87)),
                                                     ),
                                                     const SizedBox(width: 4),
                                                     Builder(
                                                       builder: (_) {
                                                         final seg = segments[index];
                                                         // Ambil detik murni jika tersedia, fallback ke estimasiWaktuMenit * 60
                                                         final durSeconds = seg["durasiDetik"] != null
                                                             ? (seg["durasiDetik"] as num).toDouble()
                                                             : (seg["duration"] != null
                                                                 ? (seg["duration"] as num).toDouble()
                                                                 : ((seg["estimasiWaktuMenit"] ?? 0) as num).toDouble() * 60);
                                                         return Text(
                                                           formatDuration(durSeconds),
                                                           style: const TextStyle(fontSize: 12),
                                                         );
                                                       },
                                                     ),
                                                   ],
                                                 ),
                                               ],
                                             ),
                                           ),
                                      ],
                                    ),
                                    const Divider(height: 24, thickness: 0.5),
                                    Padding(
                                        padding: const EdgeInsets.only(top: 0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            if (hasPhone)
                                              InkWell(
                                                onTap: () async {
                                                  final phone = paket.telepon.toString();
                                                  final Uri telUrl = Uri.parse('tel:$phone');
                                                  if (await canLaunchUrl(telUrl)) {
                                                    await launchUrl(telUrl);
                                                  }
                                                },
                                                borderRadius: BorderRadius.circular(8),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF004B87).withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.call, size: 16, color: Color(0xFF004B87)),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        "Telp",
                                                        style: TextStyle(fontSize: 11, color: Color(0xFF004B87), fontWeight: FontWeight.w600),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            if (hasPhone)
                                              const SizedBox(width: 8),
                                            if (hasPhone)
                                              InkWell(
                                                onTap: () async {
                                                  String phoneStr = paket.telepon.toString().replaceAll(RegExp(r'[^0-9]'), '');
                                                  if (phoneStr.startsWith('0')) {
                                                    phoneStr = '62${phoneStr.substring(1)}';
                                                  }
                                                  final Uri waUrl = Uri.parse('https://wa.me/$phoneStr');
                                                  if (await canLaunchUrl(waUrl)) {
                                                    await launchUrl(waUrl, mode: LaunchMode.externalApplication);
                                                  }
                                                },
                                                borderRadius: BorderRadius.circular(8),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF25D366).withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.chat_bubble_rounded, size: 16, color: Color(0xFF25D366)),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        "WA",
                                                        style: TextStyle(fontSize: 11, color: Color(0xFF25D366), fontWeight: FontWeight.w600),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            if (hasPhone && isValid)
                                              const SizedBox(width: 8),
                                            if (isValid)
                                              InkWell(
                                                onTap: () async {
                                                  final lat = paket.latitude;
                                                  final lng = paket.longitude;
                                                  if (lat != null && lng != null) {
                                                    final Uri mapUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                                                    if (await canLaunchUrl(mapUrl)) {
                                                      await launchUrl(mapUrl, mode: LaunchMode.externalApplication);
                                                    }
                                                  }
                                                },
                                                borderRadius: BorderRadius.circular(8),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF004B87).withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.location_on, size: 16, color: Color(0xFF004B87)),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        "Maps",
                                                        style: TextStyle(fontSize: 11, color: Color(0xFF004B87), fontWeight: FontWeight.w600),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            if (!isReadOnly) ...[
                                              if (hasPhone || isValid)
                                                const SizedBox(width: 8),
                                              InkWell(
                                                onTap: () async {
                                                  final result = await Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => EditLokasiView(
                                                        urutanId: currentList[index].urutanId,
                                                        paket: paket,
                                                      ),
                                                    ),
                                                  );
                                                  if (result == true && mounted && !_isDisposed) {
                                                    await _loadData();
                                                  }
                                                },
                                                borderRadius: BorderRadius.circular(8),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF004B87).withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.edit, size: 16, color: Color(0xFF004B87)),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        "Edit",
                                                        style: TextStyle(fontSize: 11, color: Color(0xFF004B87), fontWeight: FontWeight.w600),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
                if (isOptimizing || isClosing)
                  Container(
                    color: Colors.black.withValues(alpha: 0.4),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        margin: const EdgeInsets.symmetric(horizontal: 40),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(color: Color(0xFF004B87)),
                            const SizedBox(height: 16),
                            Text(
                              loadingText,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 6),
                            const Text("Mohon tunggu sebentar...", style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _waktuRow(
    IconData icon,
    String label,
    String value, {
    bool isTotal = false,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isTotal
              ? const Color(0xFF004B87)
              : Colors.grey.shade600,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight:
                  isTotal ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight:
                isTotal ? FontWeight.bold : FontWeight.w600,
            fontSize: isTotal ? 14 : 13,
            color: isTotal
                ? const Color(0xFF004B87)
                : Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  Widget _summaryTile(
    IconData icon,
    String title,
    String value, {
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF004B87).withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF004B87)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 9.5,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
