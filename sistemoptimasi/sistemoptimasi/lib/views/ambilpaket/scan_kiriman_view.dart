import 'package:flutter/material.dart';
import '../../services/paket_service.dart';
import 'continuous_scanner_page.dart';

class ScanKirimanView extends StatefulWidget {
  final int drsId;
  final String noDrs;

  const ScanKirimanView({
    super.key,
    required this.drsId,
    required this.noDrs,
  });

  @override
  State<ScanKirimanView> createState() => _ScanKirimanViewState();
}

class _ScanKirimanViewState extends State<ScanKirimanView> {
  final PaketService _service = PaketService();
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isChecking = false;
  bool _isSubmitting = false;

  // Daftar antrean hasil scan sebelum disubmit ke DRS
  final List<Map<String, dynamic>> _scannedQueue = [];

  final Color primaryBlue = const Color(0xFF004B87);
  final Color backgroundGray = const Color(0xFFF8F9FA);
  final Color textDark = const Color(0xFF1A2530);
  final Color textMuted = const Color(0xFF7D8A99);

  // Fungsi Scan & Validasi ke DB
  Future<void> _scanAndValidate() async {
    final code = _inputController.text.trim();
    if (code.isEmpty) return;

    // 1. Cek apakah nomor sudah ada di daftar antrean sesi ini (Cegah Duplikat)
    final isAlreadyScanned = _scannedQueue.any((item) =>
        (item['nomorKiriman'] as String).toLowerCase() == code.toLowerCase());

    if (isAlreadyScanned) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Nomor kiriman '$code' sudah ada dalam daftar scan (duplikat)."),
          backgroundColor: Colors.orange.shade800,
          duration: const Duration(seconds: 2),
        ),
      );
      _inputController.clear();
      _focusNode.requestFocus();
      return;
    }

    setState(() => _isChecking = true);

    try {
      // 2. Cek validasi ke database (apakah kiriman terdaftar dan berstatus 'Manifest')
      final res = await _service.checkKiriman(
        drsId: widget.drsId,
        nomorKiriman: code,
      );

      if (res['success'] == true) {
        final data = res['data'] ?? {};
        setState(() {
          _scannedQueue.insert(0, {
            'id': data['id'],
            'nomorKiriman': data['nomorKiriman'] ?? code,
            'namaPenerima': data['namaPenerima'] ?? '-',
            'alamatTujuan': data['alamatTujuan'] ?? '-',
            'beratKg': data['beratKg'] ?? 0,
            'status': data['statusKiriman'] ?? 'Manifest',
          });
          _inputController.clear();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("✓ Kiriman '$code' valid & masuk ke antrean."),
              backgroundColor: const Color(0xFF2E7D32),
              duration: const Duration(milliseconds: 1500),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? "Nomor kiriman tidak valid di database"),
              backgroundColor: const Color(0xFFD32F2F),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal memvalidasi: $e"),
            backgroundColor: const Color(0xFFD32F2F),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
        _focusNode.requestFocus();
      }
    }
  }

  // Buka Scanner Kamera Kontinu (Bisa scan berulang kali tanpa keluar kamera)
  Future<void> _openCameraScanner() async {
    final result = await Navigator.push<List<Map<String, dynamic>>>(
      context,
      MaterialPageRoute(
        builder: (context) => ContinuousScannerPage(
          drsId: widget.drsId,
          noDrs: widget.noDrs,
          initialQueue: _scannedQueue,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _scannedQueue.clear();
        _scannedQueue.addAll(result);
      });
    }
  }

  // Hapus satu kiriman dari antrean hasil scan
  void _hapusDariAntrean(int index) {
    final removed = _scannedQueue[index];
    setState(() {
      _scannedQueue.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Kiriman '${removed['nomorKiriman']}' dihapus dari daftar scan."),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Submit seluruh antrean hasil scan ke DRS (Update status jadi On Delivery)
  Future<void> _submitAllToDrs() async {
    if (_scannedQueue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Belum ada kiriman yang di-scan untuk disubmit."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Simpan Kiriman ke DRS?"),
        content: Text(
          "Sebanyak ${_scannedQueue.length} kiriman yang telah di-scan akan dimasukkan ke dalam lembar DRS.\n\nStatus kiriman di database akan diubah menjadi 'On Delivery'.",
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: primaryBlue),
            child: const Text("Ya, Simpan Semua", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSubmitting = true);

    try {
      final numbers = _scannedQueue.map((e) => e['nomorKiriman'] as String).toList();
      final res = await _service.batchSubmitKiriman(
        drsId: widget.drsId,
        nomorKirimanList: numbers,
      );

      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? "Kiriman berhasil dimasukkan ke DRS!"),
              backgroundColor: const Color(0xFF2E7D32),
              duration: const Duration(seconds: 3),
            ),
          );
          Navigator.pop(context, true); // Kembali & refresh daftar
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? "Gagal menyimpan kiriman"),
              backgroundColor: const Color(0xFFD32F2F),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Terjadi kesalahan: $e"),
            backgroundColor: const Color(0xFFD32F2F),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundGray,
      appBar: AppBar(
        title: const Text(
          "Scan & Ambil Kiriman",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: primaryBlue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Tombol Buka Kamera Scanner
          IconButton(
            icon: const Icon(Icons.camera_alt, color: Colors.white),
            tooltip: "Buka Kamera Scan",
            onPressed: _openCameraScanner,
          ),
          if (_scannedQueue.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                setState(() => _scannedQueue.clear());
              },
              icon: const Icon(Icons.delete_sweep, color: Colors.white, size: 18),
              label: const Text("Reset", style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Header Info DRS
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.08),
              border: Border(bottom: BorderSide(color: primaryBlue.withOpacity(0.15))),
            ),
            child: Row(
              children: [
                Icon(Icons.assignment_outlined, color: primaryBlue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Lembar DRS: ${widget.noDrs}",
                        style: TextStyle(fontWeight: FontWeight.bold, color: primaryBlue, fontSize: 13),
                      ),
                      const Text(
                        "Scan QR / Barcode kiriman berstatus 'Manifest'",
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _scannedQueue.isEmpty ? Colors.grey : const Color(0xFF2E7D32),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${_scannedQueue.length} Siap Disimpan",
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Input Barcode / QR & Tombol Kamera
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _inputController,
                      focusNode: _focusNode,
                      autofocus: true,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _scanAndValidate(),
                      decoration: InputDecoration(
                        hintText: "Ketik No. Kiriman (POS...)",
                        hintStyle: TextStyle(color: textMuted, fontSize: 13),
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.edit_note, color: primaryBlue),
                        suffixIcon: _inputController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _inputController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                      onChanged: (val) => setState(() {}),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Tombol Kamera Langsung
                SizedBox(
                  height: 48,
                  width: 48,
                  child: ElevatedButton(
                    onPressed: _openCameraScanner,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: primaryBlue,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: primaryBlue.withOpacity(0.3), width: 1.5),
                      ),
                      elevation: 1,
                    ),
                    child: Icon(Icons.camera_alt, color: primaryBlue, size: 24),
                  ),
                ),
                const SizedBox(width: 8),
                // Tombol Check / Scan Submit
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isChecking ? null : _scanAndValidate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 1,
                    ),
                    child: _isChecking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text("Input", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),

          // Header List Antrean
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Daftar Kiriman Ter-Scan (${_scannedQueue.length})",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark),
                ),
                if (_scannedQueue.isNotEmpty)
                  Text(
                    "Bisa dihapus jika salah scan",
                    style: TextStyle(fontSize: 11, color: textMuted, fontStyle: FontStyle.italic),
                  ),
              ],
            ),
          ),

          // List Hasil Scan Antrean (Dengan tombol Hapus)
          Expanded(
            child: _scannedQueue.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_2_rounded, size: 80, color: textMuted.withOpacity(0.35)),
                        const SizedBox(height: 14),
                        Text(
                          "Belum ada kiriman yang di-scan",
                          style: TextStyle(color: textDark, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            "Arahkan pemindai barcode / QR atau ketik nomor kiriman di atas. Kiriman yang valid di database akan otomatis terkumpul di sini.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: textMuted, fontSize: 12, height: 1.4),
                          ),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          onPressed: _openCameraScanner,
                          icon: const Icon(Icons.camera_alt, color: Colors.white),
                          label: const Text(
                            "Buka Kamera Scan QR",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: _scannedQueue.length,
                    itemBuilder: (context, index) {
                      final item = _scannedQueue[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.shade100),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Nomor urut
                            Container(
                              width: 26,
                              height: 26,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: secondaryBlue,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                "${index + 1}",
                                style: TextStyle(
                                  color: primaryBlue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Detail Kiriman
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['nomorKiriman'] ?? '',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: primaryBlue,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    "Penerima: ${item['namaPenerima']}",
                                    style: TextStyle(fontSize: 12, color: textDark, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item['alamatTujuan'] ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 11, color: textMuted),
                                  ),
                                ],
                              ),
                            ),

                            // Tombol Hapus dari Scan
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.red, size: 20),
                              tooltip: "Hapus dari daftar scan",
                              onPressed: () => _hapusDariAntrean(index),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),

      // Bottom Bar Submit Sekaligus
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: (_scannedQueue.isEmpty || _isSubmitting) ? null : _submitAllToDrs,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined, color: Colors.white),
            label: Text(
              _isSubmitting
                  ? "Menyimpan ke DRS..."
                  : "Submit ${_scannedQueue.length} Kiriman ke DRS",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              disabledBackgroundColor: Colors.grey.shade300,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }

  Color get secondaryBlue => const Color(0xFFE6F0FA);
}
