import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/paket_service.dart';

class ContinuousScannerPage extends StatefulWidget {
  final int drsId;
  final String noDrs;
  final List<Map<String, dynamic>> initialQueue;

  const ContinuousScannerPage({
    super.key,
    required this.drsId,
    required this.noDrs,
    required this.initialQueue,
  });

  @override
  State<ContinuousScannerPage> createState() => _ContinuousScannerPageState();
}

class _ContinuousScannerPageState extends State<ContinuousScannerPage> {
  late final MobileScannerController _controller;
  final PaketService _service = PaketService();

  // Daftar antrean hasil scan
  final List<Map<String, dynamic>> _scannedQueue = [];

  // Mencegah duplicate request saat scan QR yang sama berulang-ulang dengan cepat
  final Set<String> _processedCodes = {};
  bool _isProcessingScan = false;
  bool _isTorchOn = false;

  // Banner status scan terakhir di layar kamera
  String? _lastScanMessage;
  bool _lastScanSuccess = true;
  Timer? _messageTimer;

  final Color primaryBlue = const Color(0xFF004B87);

  @override
  void initState() {
    super.initState();
    // Copy data awal dari halaman sebelumnya jika ada
    _scannedQueue.addAll(widget.initialQueue);
    for (var item in widget.initialQueue) {
      if (item['nomorKiriman'] != null) {
        _processedCodes.add((item['nomorKiriman'] as String).toLowerCase());
      }
    }

    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _showOverlayFeedback(String msg, bool isSuccess) {
    _messageTimer?.cancel();
    if (mounted) {
      setState(() {
        _lastScanMessage = msg;
        _lastScanSuccess = isSuccess;
      });
      _messageTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted) {
          setState(() {
            _lastScanMessage = null;
          });
        }
      });
    }
  }

  Future<void> _handleBarcodeDetected(String rawCode) async {
    final code = rawCode.trim();
    if (code.isEmpty) return;

    final lower = code.toLowerCase();

    // 1. Cek apakah sudah pernah di-scan sesi ini
    if (_processedCodes.contains(lower)) {
      _showOverlayFeedback("⚠️ '$code' sudah ada di daftar scan (duplikat)!", false);
      return;
    }

    if (_isProcessingScan) return;
    _isProcessingScan = true;

    try {
      // 2. Validasi ke backend database Azure
      final res = await _service.checkKiriman(
        drsId: widget.drsId,
        nomorKiriman: code,
      );

      if (res['success'] == true) {
        final data = res['data'] ?? {};
        setState(() {
          _processedCodes.add(lower);
          _scannedQueue.insert(0, {
            'id': data['id'],
            'nomorKiriman': data['nomorKiriman'] ?? code,
            'namaPenerima': data['namaPenerima'] ?? '-',
            'alamatTujuan': data['alamatTujuan'] ?? '-',
            'beratKg': data['beratKg'] ?? 0,
            'status': data['statusKiriman'] ?? 'Manifest',
          });
        });

        _showOverlayFeedback("✓ '$code' valid & ditambahkan!", true);
      } else {
        _showOverlayFeedback("❌ ${res['message'] ?? 'Kiriman tidak valid'}", false);
      }
    } catch (e) {
      _showOverlayFeedback("Gagal memvalidasi: $e", false);
    } finally {
      // Beri sedikit delay agar scanner kamera tidak menembak kode yang sama bertubi-tubi
      await Future.delayed(const Duration(milliseconds: 1000));
      _isProcessingScan = false;
    }
  }

  void _manualInputPrompt() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Input No. Kiriman Manual"),
        content: TextField(
          controller: textController,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: "Contoh: P2509030098314",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryBlue),
            onPressed: () {
              final val = textController.text.trim();
              if (val.isNotEmpty) {
                Navigator.pop(ctx);
                _handleBarcodeDetected(val);
              }
            },
            child: const Text("Scan", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Tampilkan Bottom Sheet untuk review daftar yang sudah di-scan & opsi hapus
  void _showScannedListSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(16),
              height: MediaQuery.of(context).size.height * 0.6,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Daftar Kiriman Ter-Scan (${_scannedQueue.length})",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: _scannedQueue.isEmpty
                        ? const Center(child: Text("Belum ada kiriman di-scan"))
                        : ListView.builder(
                            itemCount: _scannedQueue.length,
                            itemBuilder: (c, idx) {
                              final item = _scannedQueue[idx];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFFE6F0FA),
                                  child: Text(
                                    "${idx + 1}",
                                    style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(
                                  item['nomorKiriman'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                ),
                                subtitle: Text("${item['namaPenerima']} - ${item['alamatTujuan']}", maxLines: 1),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      final removed = _scannedQueue.removeAt(idx);
                                      _processedCodes.remove((removed['nomorKiriman'] as String).toLowerCase());
                                    });
                                    setModalState(() {});
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final boxSize = screenWidth * 0.72;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "Scanner Kamera - DRS ${widget.noDrs}",
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        actions: [
          // Senter / Flash
          IconButton(
            icon: Icon(
              _isTorchOn ? Icons.flash_on : Icons.flash_off,
              color: Colors.white,
            ),
            tooltip: "Senter",
            onPressed: () async {
              await _controller.toggleTorch();
              setState(() {
                _isTorchOn = !_isTorchOn;
              });
            },
          ),
          // Input Manual
          IconButton(
            icon: const Icon(Icons.keyboard, color: Colors.white),
            tooltip: "Input Manual",
            onPressed: _manualInputPrompt,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Scanner Viewfinder Kamera Real-time
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              for (final b in barcodes) {
                final val = b.rawValue ?? b.displayValue;
                if (val != null && val.trim().isNotEmpty) {
                  _handleBarcodeDetected(val);
                  break;
                }
              }
            },
          ),

          // 2. Bingkai Pemindai (Target Box)
          Center(
            child: Stack(
              children: [
                Container(
                  width: boxSize,
                  height: boxSize,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                // Sudut-sudut bidikan hijau
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Color(0xFF00FF7F), width: 4),
                        left: BorderSide(color: Color(0xFF00FF7F), width: 4),
                      ),
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(16)),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Color(0xFF00FF7F), width: 4),
                        right: BorderSide(color: Color(0xFF00FF7F), width: 4),
                      ),
                      borderRadius: BorderRadius.only(topRight: Radius.circular(16)),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFF00FF7F), width: 4),
                        left: BorderSide(color: Color(0xFF00FF7F), width: 4),
                      ),
                      borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16)),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFF00FF7F), width: 4),
                        right: BorderSide(color: Color(0xFF00FF7F), width: 4),
                      ),
                      borderRadius: BorderRadius.only(bottomRight: Radius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. BADGE COUNTER JUMLAH DI POJOK KANAN ATAS KAMERA
          Positioned(
            top: 16,
            right: 16,
            child: GestureDetector(
              onTap: _showScannedListSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      "${_scannedQueue.length} Kiriman",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 16),
                  ],
                ),
              ),
            ),
          ),

          // 4. Banner Pesan Hasil Scan (Sukses / Duplikat / Tidak Ditemukan)
          if (_lastScanMessage != null)
            Positioned(
              top: 72,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _lastScanSuccess
                      ? const Color(0xFF2E7D32).withOpacity(0.95)
                      : const Color(0xFFD32F2F).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      _lastScanSuccess ? Icons.check_circle : Icons.error_outline,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _lastScanMessage!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 5. Bottom Controls: Tombol Selesai & Kirim
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Row(
              children: [
                // Tombol Lihat List
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _showScannedListSheet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.list_alt),
                    label: Text(
                      "Lihat (${_scannedQueue.length})",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Tombol Selesai Scan
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context, _scannedQueue);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.done_all, color: Colors.white),
                    label: const Text(
                      "Selesai Scan",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
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
