import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; 
import '../../services/paket_service.dart';
import '../../models/Urutan_Pengantaran.dart';
import 'detail_pengantaran_view.dart';
import 'list_penugasan_view.dart';
import '../ambilpaket/scan_kiriman_view.dart';
import '../optimasirute/optimasi_rute_v2.dart';
import '../../models/penugasan_model.dart';

class PaketSayaView extends StatefulWidget {
  final PenugasanModel item;
  final int penugasanId;
  final int isClosed; // 1 = Selesai (Closing), 0 = Masih Aktif

  const PaketSayaView({
    super.key, 
    required this.item,
    required this.penugasanId,
    this.isClosed = 0, 
  }); 

  @override
  State<PaketSayaView> createState() => _PaketSayaViewState();
}

class _PaketSayaViewState extends State<PaketSayaView> {
  final PaketService _service = PaketService();

  List<UrutanPengantaranModel> _allData = [];
  List<UrutanPengantaranModel> _filteredData = [];
  bool isLoading = true;
  bool _isClosing = false; // State loading untuk tombol closing
  
  String _selectedStatusFilter = "all";
  String _currentKeyword = "";
  bool _isManifestExpanded = false;

  // Tema Warna Pembuat UI Premium
  final Color primaryBlue = const Color(0xFF004B87);    
  final Color secondaryBlue = const Color(0xFFE6F0FA);  
  final Color backgroundGray = const Color(0xFFF8F9FA); 
  final Color textDark = const Color(0xFF1A2530);       
  final Color textMuted = const Color(0xFF7D8A99);       

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final result = await _service.getPaketByKurir(penugasanId: widget.penugasanId); 

    setState(() {
      _allData = result;
      _applyFilterAndSearch();
      isLoading = false;
    });
  }

  void _applyFilterAndSearch() {
    List<UrutanPengantaranModel> result = _allData;

    if (_selectedStatusFilter != "all") {
      if (_selectedStatusFilter == "selesai") {
        result = result.where((item) {
          final status = item.status?.toLowerCase().trim();
          return status == "delivered" || status == "returned";
        }).toList();
      } else {
        result = result.where((item) => item.status == _selectedStatusFilter).toList();
      }
    }

    if (_currentKeyword.isNotEmpty) {
      result = result.where((item) {
        final paket = item.paket;
        return (paket.recipientName ?? "").toLowerCase().contains(_currentKeyword.toLowerCase()) ||
            (paket.noKiriman ?? "").toLowerCase().contains(_currentKeyword.toLowerCase()) ||
            (paket.address ?? "").toLowerCase().contains(_currentKeyword.toLowerCase());
      }).toList();
    }

    setState(() {
      _filteredData = result;
    });
  }

  int _getCountByStatus(String status) {
    if (status == "all") return _allData.length;
    return _allData.where((item) => item.status == status).length;
  }

  // Fungsi Logika untuk Proses Closing Penugasan
  Future<void> _prosesClosing() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Selesaikan Tugas?"),
        content: const Text("Apakah Anda yakin ingin menyelesaikan semua tugas pengantaran ini? Status yang sudah dikirim tidak dapat diubah kembali."),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)), 
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Ya, Selesai"),
          ),
        ],
      ),
    );

    if (confirm != true) return; 

    setState(() {
      _isClosing = true;
    });

    try {
      bool success = await _service.closingDrs(
        drsId: widget.penugasanId,
      );

      if (!success) {
        success = await _service.selesaikanPenugasan(
          jadwalId: widget.penugasanId,
        );
      }

      if (!success) {
        throw Exception("Gagal menyelesaikan penugasan DRS");
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Tugas pengantaran berhasil diselesaikan!"),
            backgroundColor: Color(0xFF2E7D32),
          )
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const ListPenugasanView(),
          ),
          (route) => false,
        );
      }

    }
    catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal menyelesaikan tugas: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isClosing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // PERBAIKAN UTAMA: Mengecek status item apakah "selesai" (abaikan case hurufnya) ATAU isClosed bernilai 1.
    final bool isReadOnly = (widget.item.status?.toLowerCase() == 'selesai') || widget.isClosed == 1;

    return Scaffold(
      backgroundColor: backgroundGray,
      appBar: AppBar(
        title: const Text(
          "Daftar Kiriman",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: primaryBlue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.alt_route, color: Colors.white),
            tooltip: "Optimasi Rute",
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OptimasiRuteV2(
                    penugasanId: widget.penugasanId,
                    status: widget.item.status,
                    initialPaketList: _allData,
                  ),
                ),
              );
              _loadData();
            },
          ),
          if (!isReadOnly) ...[
            IconButton(
              icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
              tooltip: "Scan Ambil Kiriman",
              onPressed: () async {
                final changed = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ScanKirimanView(
                      drsId: widget.penugasanId,
                      noDrs: widget.item.kodePenugasan,
                    ),
                  ),
                );
                if (changed == true) {
                  _loadData();
                }
              },
            ),
            IconButton(
              icon: _isClosing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline, color: Colors.white),
              tooltip: "Selesaikan Tugas (Closing)",
              onPressed: _isClosing ? null : _prosesClosing,
            ),
          ],
        ],
      ),
      
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryBlue))
          : Column(
              children: [
                /// BANNER NOTIFIKASI ARSIP
                if (isReadOnly)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3CD), 
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFECB5)), 
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Color(0xFF856404), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Penugasan telah selesai. Data kiriman pada halaman ini bersifat riwayat (arsip) dan tidak dapat diubah.",
                            style: TextStyle(
                              color: const Color(0xFF856404), 
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                              height: 1.4, 
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                /// 1. SEARCH BAR
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    onChanged: (value) {
                      _currentKeyword = value;
                      _applyFilterAndSearch();
                    },
                    decoration: InputDecoration(
                      hintText: "Cari nama / no kiriman / alamat...",
                      hintStyle: TextStyle(color: textMuted, fontSize: 14),
                      border: InputBorder.none,
                      icon: Icon(Icons.search_rounded, color: primaryBlue),
                    ),
                  ),
                ),

                /// 2. ACCORDION CARD INFORMASI PENGIRIMAN + BUTTON CLOSING
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryBlue.withOpacity(0.12)),
                  ),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            _isManifestExpanded = !_isManifestExpanded;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.assignment_rounded, color: primaryBlue, size: 20),
                                  const SizedBox(width: 10),
                                  Text(
                                    "INFORMASI PENGANTARAN",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: primaryBlue,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              Icon(
                                _isManifestExpanded 
                                    ? Icons.keyboard_arrow_up_rounded 
                                    : Icons.keyboard_arrow_down_rounded,
                                color: primaryBlue,
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      AnimatedCrossFade(
                        firstChild: const SizedBox.shrink(),
                        secondChild: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            children: [
                              const Divider(height: 1, thickness: 0.5),
                              const SizedBox(height: 12),
                              _infoItemVertical(Icons.scale_rounded, "Total Beban Muatan", "${widget.item.totalBeratKiriman} Kg"),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 6),
                                child: Divider(height: 1, thickness: 0.3),
                              ),
                              _infoItemVertical(Icons.inventory_rounded, "Jumlah Total Kiriman", "${_allData.length}"),
                              
                              /// TOMBOL CLOSING (Warna dan State menyesuaikan Mode Baca)
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: ElevatedButton(
                                  // PERBAIKAN TOMBOL: Jika isReadOnly = true, tombol di-disable otomatis (null)
                                  onPressed: (isReadOnly || _isClosing) ? null : _prosesClosing,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF9E2A2B), // Merah bata jika aktif
                                    disabledBackgroundColor: Colors.grey.shade300, // Abu-abu jika selesai/read-only
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 0,
                                  ),
                                  child: _isClosing
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            if (isReadOnly)
                                              Icon(Icons.check_circle_rounded, color: Colors.grey.shade600, size: 18),
                                            const SizedBox(width: 8),
                                            Text(
                                              // Teks berubah sesuai status Read Only
                                              isReadOnly ? "PENGANTARAN TELAH SELESAI" : "AKHIRI PENGANTARAN",
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: isReadOnly ? Colors.grey.shade600 : Colors.white,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        crossFadeState: _isManifestExpanded 
                            ? CrossFadeState.showSecond 
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 200),
                      ),
                    ],
                  ),
                ),

                /// 3. TOTAL DAFTAR KIRIMAN
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Menampilkan ${_filteredData.length} Kiriman",
                        style: TextStyle(fontWeight: FontWeight.bold, color: textDark, fontSize: 14),
                      ),
                      Icon(Icons.inventory_2_outlined, color: textMuted, size: 16)
                    ],
                  ),
                ),

                /// 4. BUTTON FILTER STATUS
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: Row(
                    children: [
                      _buildOutlineFilterButton(
                        label: "Semua", 
                        filterValue: "all", 
                        activeColor: primaryBlue,
                        count: _getCountByStatus("all"),
                      ),                      
                      const SizedBox(width: 8),
                      _buildOutlineFilterButton(
                        label: isReadOnly ? "Gagal Diantar" : "Diantar", // Kalau selesai jadi "Terkirim"
                        filterValue: "on_delivery", 
                        activeColor: const Color(0xFFE65100), 
                        count: _getCountByStatus("on_delivery"),
                      ),
                      const SizedBox(width: 8),
                      _buildOutlineFilterButton(
                        label: "Selesai", 
                        filterValue: "selesai", 
                        activeColor: const Color(0xFF2E7D32), 
                        count: _getCountByStatus("delivered") + _getCountByStatus("returned"),
                      ),
                    ],
                  ),
                ),
                
                /// 5. LIST DATA KIRIMAN
                Expanded(
                  child: _filteredData.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 60, color: textMuted.withOpacity(0.35)),
                              const SizedBox(height: 12),
                              Text(
                                "Belum Ada Kiriman di DRS Ini",
                                style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 32),
                                child: Text(
                                  "Gunakan tombol scan di pojok kanan atas untuk memindai resi kiriman yang akan diantar.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: textMuted, fontSize: 12),
                                ),
                              ),
                              if (!isReadOnly) ...[
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    final changed = await Navigator.push<bool>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ScanKirimanView(
                                          drsId: widget.penugasanId,
                                          noDrs: widget.item.kodePenugasan,
                                        ),
                                      ),
                                    );
                                    if (changed == true) {
                                      _loadData();
                                    }
                                  },
                                  icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                                  label: const Text(
                                    "Scan & Ambil Kiriman",
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryBlue,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredData.length,
                          padding: const EdgeInsets.only(bottom: 16),
                          itemBuilder: (context, index) {
                            final item = _filteredData[index];
                            return ItemPaketCard(
                              item: item,
                              // Lempar status isReadOnly yang baru ke Card agar tombol action-nya juga mati
                              isClosed: isReadOnly ? 1 : 0, 
                              primaryBlue: primaryBlue,
                              secondaryBlue: secondaryBlue,
                              textDark: textDark,
                              textMuted: textMuted,
                              backgroundGray: backgroundGray,
                            );
                          },
                        ),
                )
              ],
            ),
      bottomNavigationBar: (!isReadOnly && _allData.isNotEmpty)
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                child: ElevatedButton.icon(
                  onPressed: _isClosing ? null : _prosesClosing,
                  icon: _isClosing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  label: Text(
                    _isClosing ? "Memproses Closing..." : "Selesaikan Tugas Pengantaran",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildOutlineFilterButton({
    required String label, 
    required String filterValue, 
    required Color activeColor,
    required int count,
  }) {
    final bool isSelected = _selectedStatusFilter == filterValue;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedStatusFilter = filterValue;
            _applyFilterAndSearch();
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? activeColor : textMuted.withOpacity(0.25),
              width: isSelected ? 2.0 : 1.0, 
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? activeColor : textMuted,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? activeColor : textMuted.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : textDark.withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoItemVertical(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: backgroundGray, borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, size: 16, color: textMuted),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: textMuted, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
          ],
        ),
      ],
    );
  }
}

class ItemPaketCard extends StatelessWidget {
  final UrutanPengantaranModel item;
  final int isClosed; 
  final Color primaryBlue;
  final Color secondaryBlue;
  final Color textDark;
  final Color textMuted;
  final Color backgroundGray;

  const ItemPaketCard({
    super.key,
    required this.item,
    required this.isClosed, 
    required this.primaryBlue,
    required this.secondaryBlue,
    required this.textDark,
    required this.textMuted,
    required this.backgroundGray,
  });

  Color _getStatusColor(String? status) {
    if (status == null) return textMuted;
    switch (status.toLowerCase().trim()) {
      case "delivered": return const Color(0xFF2E7D32);
      case "on_delivery": return const Color(0xFFE65100);
      case "returned": return const Color(0xFFC62828);
      case "manifested": return primaryBlue;
      default: return primaryBlue;
    }
  }

  String _getStatusLabel(String? status) {
    if (status == null || status.isEmpty) return "Tanpa Status";
    switch (status.toLowerCase().trim()) {
      case "manifested": return "Manifested";
      case "on_delivery": return "On Delivery";
      case "delivered": return "Delivered";
      case "returned": return "Returned";
      default: return status;
    }
  }

  Widget _iconAction(IconData icon, Color activeColor, bool isActive, VoidCallback onTap) {
    final Color iconColor = isActive ? activeColor : textMuted.withOpacity(0.4);
    final Color bgColor = isActive ? activeColor.withOpacity(0.1) : backgroundGray;

    return GestureDetector(
      onTap: isActive ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 18, color: iconColor),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paket = item.paket;
    final bool hasLocation = paket.latitude != null && paket.longitude != null;
    final bool hasPhone = paket.telepon != null && paket.telepon!.toString().trim().isNotEmpty;

    return Opacity(
      opacity: isClosed == 1 ? 0.6 : 1.0, 
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 4, offset: const Offset(0, 1)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: isClosed == 1
              ? null // Tidak bisa diklik kalau history/selesai
              : () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetailPengantaranView(
                        item: item,
                      ),
                    ),
                  );

                  if (result == true) {
                    final state = context.findAncestorStateOfType<
                        _PaketSayaViewState>();
                    await state?._loadData();
                  }
                },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(item.status).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _getStatusLabel(item.status),
                          style: TextStyle(fontSize: 11, color: _getStatusColor(item.status), fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        "Order #${item.nomorUrutan ?? '-'}",
                        style: TextStyle(fontWeight: FontWeight.bold, color: primaryBlue, fontSize: 13),
                      )
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(color: secondaryBlue, borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.inventory_2_outlined, color: primaryBlue, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              paket.recipientName ?? "-",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textDark),
                            ),
                            const SizedBox(height: 2),
                            Text("No. Kiriman: ${paket.noKiriman ?? '-'}", style: TextStyle(fontSize: 12, color: textMuted)),
                            const SizedBox(height: 6),
                            Text(
                              paket.address ?? "-",
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: textDark.withOpacity(0.7), height: 1.3),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              paket.telepon ?? "Tidak ada nomor telepon",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: textDark.withOpacity(0.7), height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const Padding(
                    padding: EdgeInsets.only(top: 14, bottom: 10),
                    child: Divider(height: 1, thickness: 0.5),
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _iconAction(
                        Icons.directions_rounded, 
                        const Color(0xFF1A73E8), 
                        hasLocation && isClosed == 0, // Matikan tombol aksi jika status sudah read-only
                        () async {
                          final double? lat = double.tryParse(paket.latitude.toString());
                          final double? lng = double.tryParse(paket.longitude.toString());
                          
                          if (lat != null && lng != null) {
                            final Uri mapUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                            if (await canLaunchUrl(mapUrl)) {
                              await launchUrl(mapUrl, mode: LaunchMode.externalApplication);
                            }
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      
                      _iconAction(
                        Icons.call, 
                        primaryBlue, 
                        hasPhone && isClosed == 0,
                        () async {
                          final Uri phoneUrl = Uri.parse('tel:${paket.telepon}');
                          if (await canLaunchUrl(phoneUrl)) {
                            await launchUrl(phoneUrl);
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      
                      _iconAction(
                        Icons.chat_bubble_rounded, 
                        const Color(0xFF25D366), 
                        hasPhone && isClosed == 0,
                        () async {
                          String phoneStr = paket.telepon.toString().replaceAll(RegExp(r'[^0-9]'), '');
                          if (phoneStr.startsWith('0')) {
                            phoneStr = '62${phoneStr.substring(1)}';
                          }
                          
                          final Uri waUrl = Uri.parse('https://wa.me/$phoneStr');
                          if (await canLaunchUrl(waUrl)) {
                            await launchUrl(waUrl, mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
