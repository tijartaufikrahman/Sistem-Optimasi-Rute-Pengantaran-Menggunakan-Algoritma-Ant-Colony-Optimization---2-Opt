import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/paket_service.dart';
import '../../models/penugasan_model.dart';
import 'optimasi_rute_v2.dart';

class ListOptimasi extends StatefulWidget {
  const ListOptimasi({super.key});

  @override
  State<ListOptimasi> createState() => _LisOptimasiState();
}

class _LisOptimasiState extends State<ListOptimasi> {
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
          "Daftar Optimasi Rute",
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
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                              
                              /// 1. UBAH ICON DI SINI (Menjadi Icon Dokumen Penugasan)
                              leading: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: secondaryBlue,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.assignment_rounded, // <-- Cocok untuk penugasan/task
                                  color: primaryBlue,
                                  size: 24,
                                ),
                              ),
                              
                              /// 2. TAMBAH LABEL SEBELUM KODE PENUGASAN DI SINI
                              title: Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        "No. Penugasan: ${item.kodePenugasan}", 
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: textDark,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: (item.hasOptimasi || item.status == 'Sudah Dioptimasi')
                                            ? const Color(0xFFE8F5E9)
                                            : const Color(0xFFFFF3E0),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: (item.hasOptimasi || item.status == 'Sudah Dioptimasi')
                                              ? const Color(0xFF81C784)
                                              : const Color(0xFFFFB74D),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            (item.hasOptimasi || item.status == 'Sudah Dioptimasi')
                                                ? Icons.check_circle
                                                : Icons.hourglass_empty_rounded,
                                            size: 11,
                                            color: (item.hasOptimasi || item.status == 'Sudah Dioptimasi')
                                                ? const Color(0xFF2E7D32)
                                                : const Color(0xFFE65100),
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            (item.hasOptimasi || item.status == 'Sudah Dioptimasi')
                                                ? "Sudah Dioptimasi"
                                                : "Belum Dioptimasi",
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: (item.hasOptimasi || item.status == 'Sudah Dioptimasi')
                                                  ? const Color(0xFF2E7D32)
                                                  : const Color(0xFFE65100),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.person_outline_rounded, size: 14, color: textMuted),
                                      const SizedBox(width: 4),
                                      
                                      /// 3. UBAH NAMA KURIR MENJADI ORANGER ANTARAN DI SINI
                                      Text(
                                        "Oranger Antaran: ${item.namaKurir}", // <-- Diubah jadi Oranger Antaran
                                        style: TextStyle(color: textDark.withOpacity(0.8), fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.inventory_2_outlined, size: 14, color: textMuted),
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
                                ],
                              ),
                              trailing: Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 16,
                                color: textMuted.withOpacity(0.7),
                              ),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => OptimasiRuteV2(
                                      penugasanId: item.id,
                                      status: item.status,
                                    ),
                                  ),
                                );
                                _fetchPenugasan();
                              },
                            ),
                          );
                        },
                      )),
        ],
      ),
    );
  }
}
