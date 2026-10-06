import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/paket_service.dart';
import '../../models/penugasan_model.dart';
import 'paket_saya_view.dart';

class ListPenugasanView extends StatefulWidget {
  const ListPenugasanView({super.key});

  @override
  State<ListPenugasanView> createState() => _ListPenugasanViewState();
}

class _ListPenugasanViewState extends State<ListPenugasanView> {
  final PaketService _service = PaketService();
  List<PenugasanModel> _listPenugasan = [];
  bool _isLoading = false;

  // Set default ke tanggal saat ini WIB (UTC+7)
  DateTime _selectedDate = DateTime.now().toUtc().add(const Duration(hours: 7));

  // Tema Warna Korporat Pos (Minimalis & Profesional)
  final Color primaryBlue = const Color(0xFF004B87); // Biru Utama Pos IND
  final Color secondaryBlue = const Color(0xFFE6F0FA); // Biru muda transparan
  final Color backgroundGray = const Color(0xFFF8F9FA); // Background super light
  final Color textDark = const Color(0xFF1A2530); // Warna teks utama
  final Color textMuted = const Color(0xFF7D8A99); // Warna teks sekunder

  @override
  void initState() {
    super.initState();
    _fetchPenugasan();
  }

  Future<void> _fetchPenugasan() async {
    setState(() => _isLoading = true);
    
    String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);

    try {
      final result = await _service.getPenugasan(
        tglAwal: formattedDate,
        tglAkhir: formattedDate,
      );
      setState(() {
        _listPenugasan = result;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pilihTanggal() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryBlue,
              onPrimary: Colors.white,
              onSurface: textDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchPenugasan();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundGray,
      appBar: AppBar(
        title: const Text(
          "Daftar Penugasan",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: primaryBlue,
        elevation: 0,
      ),
      body: Column(
        children: [
          /// FILTER TANGGAL (MINIMALIS MODERN)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "TANGGAL PENUGASAN PENGANTARAN",
                      style: TextStyle(
                        fontSize: 11, 
                        fontWeight: FontWeight.bold,
                        color: textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      DateFormat('dd MMMM yyyy').format(_selectedDate),
                      style: TextStyle(
                        fontSize: 15, 
                        fontWeight: FontWeight.w700,
                        color: textDark,
                      ),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: _pilihTanggal,
                  icon: Icon(Icons.calendar_month_rounded, size: 18, color: primaryBlue),
                  label: Text(
                    "Ubah",
                    style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: primaryBlue.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ],
            ),
          ),

          /// LIST DATA PENUGASAN
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: primaryBlue))
                : _listPenugasan.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.document_scanner_outlined,
                              size: 70, 
                              color: textMuted.withOpacity(0.5),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              "Tidak ada penugasan di tanggal ini",
                              style: TextStyle(
                                color: textMuted,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _listPenugasan.length,
                        padding: const EdgeInsets.only(bottom: 16),
                        itemBuilder: (context, index) {
                          final item = _listPenugasan[index];
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: InkWell(
  borderRadius: BorderRadius.circular(12),

  onTap: () {
    final status = item.status?.toLowerCase() ?? '';
    if (status == 'assigned') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ Penugasan harus disetujui (Approve) terlebih dahulu sebelum dapat dibuka!"),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaketSayaView(
          penugasanId: item.id,
          item: item,
        ),
      ),
    ).then((_) => _fetchPenugasan());
  },

  child: Padding(
    padding: const EdgeInsets.all(16),

    child: Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [

        /// =========================
        /// KIRI
        /// =========================
        Column(
          children: [

            // STATUS
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: item.status?.toLowerCase() == "selesai" || item.status?.toLowerCase() == "completed"
                    ? const Color(0xFFE8F5E9)
                    : (item.status?.toLowerCase().contains("optimasi") == true
                        ? const Color(0xFFE0F2F1)
                        : const Color(0xFFFFF3E0)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                item.status?.toUpperCase() ?? "AKTIF",
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: item.status?.toLowerCase() == "selesai" || item.status?.toLowerCase() == "completed"
                      ? const Color(0xFF2E7D32)
                      : (item.status?.toLowerCase().contains("optimasi") == true
                          ? const Color(0xFF00796B)
                          : const Color(0xFFE65100)),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ICON
            Container(
              padding:
                  const EdgeInsets.all(12),

              decoration: BoxDecoration(
                color: secondaryBlue,

                borderRadius:
                    BorderRadius.circular(10),
              ),

              child: Icon(
                Icons.assignment_rounded,
                color: primaryBlue,
                size: 24,
              ),
            ),
          ],
        ),

        const SizedBox(width: 16),

        /// =========================
        /// KANAN
        /// =========================
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [

              // KODE PENUGASAN
              Text(
                "No. Penugasan: ${item.kodePenugasan}",

                style: TextStyle(
                  fontWeight:
                      FontWeight.w600,
                  fontSize: 15,
                  color: textDark,
                ),
              ),

              const SizedBox(height: 10),

              // KURIR
              Row(
                children: [

                  Icon(
                    Icons
                        .person_outline_rounded,
                    size: 14,
                    color: textMuted,
                  ),

                  const SizedBox(width: 4),

                  Expanded(
                    child: Text(
                      "Oranger Antaran: ${item.namaKurir}",

                      style: TextStyle(
                        color: textDark
                            .withOpacity(0.8),

                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // JUMLAH PAKET
              Row(
                children: [

                  Icon(
                    Icons
                        .inventory_2_outlined,
                    size: 14,
                    color: textMuted,
                  ),

                  const SizedBox(width: 4),

                  Text(
                    "${item.jumlahPaket} Kiriman",
                    style: TextStyle(
                      color: primaryBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Action Buttons: Approve Penugasan
              if (item.status?.toLowerCase() == 'assigned')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final ok = await _service.approveDrs(drsId: item.id);
                        if (ok) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("✓ DRS Berhasil Disetujui! Silakan buka detail untuk scan kiriman."),
                                backgroundColor: Color(0xFF2E7D32),
                              ),
                            );
                            _fetchPenugasan();
                          }
                        }
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.white),
                      label: const Text(
                        "Setujui Penugasan (Approve)",
                        style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),

            ],
          ),
        ),

        /// PANAH
        Padding(
          padding:
              const EdgeInsets.only(top: 8),

          child: Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color:
                textMuted.withOpacity(0.7),
          ),
        ),
      ],
    ),
  ),
),

                          );
                        },
                      )),
        ],
      ),
    );
  }
}
