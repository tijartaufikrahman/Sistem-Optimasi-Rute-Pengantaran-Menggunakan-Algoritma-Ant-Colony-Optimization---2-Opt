import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/Urutan_Pengantaran.dart';
import '../../services/paket_service.dart';

// POD
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../models/pod_model.dart';
import '../../config/api_config.dart';

class DetailPengantaranView extends StatefulWidget {
  final UrutanPengantaranModel item;

  const DetailPengantaranView({
    super.key,
    required this.item,
  });

  @override
  State<DetailPengantaranView> createState() =>
      _DetailPengantaranViewState();
}

class _DetailPengantaranViewState extends State<DetailPengantaranView> {

  

  final PaketService _service = PaketService();

  File? podPhoto;

// ===== ATTRIBUT BARU UNTUK API =====
double? podLatitude;
double? podLongitude;
DateTime? podDateTime;
// ================================

  bool isLoading = false;

  String selectedStatus = "delivered";

  String selectedPenerima =
      "DITERIMA YANG BERSANGKUTAN";

  final TextEditingController namaController =
      TextEditingController();

// ===== DATA POD YANG SUDAH ADA =====
  PodModel? pod;
  bool isCheckingPod = true;
  String? _apiBaseUrl;

  // Untuk cek ketersediaan foto (hindari error 404)
  bool _isPhotoChecking = false;
  bool _isPhotoAvailable = false;
// ====================================

  @override
  void initState() {
    super.initState();
    // Isi default nama penerima dari data paket,
    // supaya namaController tidak kosong saat submit.
    namaController.text = widget.item.paket.recipientName ?? "";
    _checkExistingPod();
  }

  Future<void> _checkExistingPod() async {
    try {
      final baseUrl = await ApiConfig.getApiUrl();
      final result = await _service.cekPod(
        kirimanId: widget.item.paket.id,
        baseUrl: baseUrl,
      );

      if (mounted) {
        setState(() {
          pod = result;
          _apiBaseUrl = result != null ? baseUrl : null;
          isCheckingPod = false;
        });
      }

      // Cek ketersediaan file foto sebelum ditampilkan,
      // supaya tidak ada request gambar yang gagal (404).
      if (result != null && result.fotoBukti != null) {
        if (mounted) {
          setState(() {
            _isPhotoChecking = true;
          });
        }
        final photoUrl =
            "$baseUrl/api/pod/view/${result.fotoBukti}";
        final exists = await _service.isPhotoAvailable(photoUrl);
        if (mounted) {
          setState(() {
            _isPhotoChecking = false;
            _isPhotoAvailable = exists;
          });
        }
      }
    } catch (e) {
      print("Gagal cek POD: $e");
      if (mounted) {
        setState(() {
          isCheckingPod = false;
          _isPhotoChecking = false;
        });
      }
    }
  }

  // ===== AKSI TOMBOL HEADER (Telepon / WhatsApp / Maps) =====

  Future<void> _callPhone() async {
    final phone = widget.item.paket.telepon;
    if (phone == null || phone.trim().isEmpty) {
      _showNoDataSnackbar("Nomor telepon tidak tersedia");
      return;
    }
    final Uri uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showNoDataSnackbar("Tidak dapat membuka aplikasi telepon");
    }
  }

  Future<void> _openWhatsApp() async {
    final phone = widget.item.paket.telepon;
    if (phone == null || phone.trim().isEmpty) {
      _showNoDataSnackbar("Nomor telepon tidak tersedia");
      return;
    }
    String phoneStr = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (phoneStr.startsWith('0')) {
      phoneStr = '62${phoneStr.substring(1)}';
    }
    final Uri uri = Uri.parse('https://wa.me/$phoneStr');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showNoDataSnackbar("WhatsApp tidak terpasang");
    }
  }

  Future<void> _openMaps() async {
    final lat = widget.item.paket.latitude;
    final lng = widget.item.paket.longitude;
    if (lat == null || lng == null) {
      _showNoDataSnackbar("Koordinat lokasi tidak tersedia");
      return;
    }
    final Uri uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showNoDataSnackbar("Tidak dapat membuka peta");
    }
  }

  void _showNoDataSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.grey.shade700,
      ),
    );
  }

  // ======================================================

  Future<void> _submitStatus() async {

    setState(() {
      isLoading = true;
    });

    try {

      // Jangan kirim nama penerima kosong/null ke API.
      // Jika user tidak mengisi, pakai nama penerima dari data paket.
      final namaPenerima = namaController.text.trim().isEmpty
          ? (widget.item.paket.recipientName ?? "")
          : namaController.text.trim();

      final success = await _service.updateStatusPengiriman(
        urutanId: widget.item.urutanId ?? widget.item.paket.id,
        status: selectedStatus,
        namaPenerima: namaPenerima,
        penerimaStatus: selectedPenerima,

        // ===== DATA POD =====
        podPhoto: podPhoto,
        podLatitude: podLatitude,
        podLongitude: podLongitude,
        podDateTime: podDateTime,
        // ====================
      );

      print("URUTAN ID:");
      print(widget.item.urutanId);

      if (!success) {
        throw Exception("Gagal update status");
      }

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Status pengiriman berhasil diperbarui",
            ),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, true);
      }

    } catch (e) {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );

    } finally {

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<Position> _getLocation() async {

  await Geolocator.requestPermission();

  return await Geolocator.getCurrentPosition();
}

  Future<File> _createPodPhoto(File original,) async {
    await initializeDateFormatting('id');

  final posisi = await _getLocation();

  podLatitude = posisi.latitude;
  podLongitude = posisi.longitude;
  podDateTime = DateTime.now();

  final bytes =await original.readAsBytes();
  final image =img.decodeImage(bytes)!;
  final now = DateTime.now();
  final jam =DateFormat("HH:mm").format(now);
  final tanggal =DateFormat("yyyy.MM.dd EEEE","id").format(now);
  final nama = namaController.text.isEmpty ? widget.item.paket.recipientName ?? "-" : namaController.text;

  final alamat = widget.item.paket.address ?? "-";

  img.drawString(
  image,
  jam,
  font: img.arial48,
  x: 40,
  y: 40,
);

img.drawString(
  image,
  tanggal,
  font: img.arial48,
  x: 40,
  y: 120,
);

img.drawString(
  image,
  "Penerima : $nama",
  font: img.arial48,
  x: 40,
  y: image.height - 240,
);

img.drawString(
  image,
  "Alamat : $alamat",
  font: img.arial48,
  x: 40,
  y: image.height - 160,
);

img.drawString(
  image,
  "${posisi.latitude}, ${posisi.longitude}",
  font: img.arial48,
  x: 40,
  y: image.height - 80,
);

  final dir =
      await getApplicationDocumentsDirectory();

  final output = File(
    "${dir.path}/POD_${DateTime.now().millisecondsSinceEpoch}.jpg",
  );

  await output.writeAsBytes(
    img.encodeJpg(image),
  );

  return output;
}

void _showPreview(File file) {

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => Scaffold(

        appBar: AppBar(
          title: const Text("Preview POD"),

          actions: [
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () {

                setState(() {
                  podPhoto = file;
                });

                Navigator.pop(context);
              },
            )
          ],
        ),

        body: SafeArea(
  child: SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [

        InteractiveViewer(
          minScale: 1,
          maxScale: 8,
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                file,
                width: MediaQuery.of(context).size.width - 32,
                fit: BoxFit.fitWidth,
              ),
            ),
          ),
        ),

        const SizedBox(height: 150),

      ],
    ),
  ),
),
      ),
    ),
  );
}
Future<void> _takePhoto() async {

  final picker = ImagePicker();

  final XFile? photo = await picker.pickImage(
    source: ImageSource.camera,
    imageQuality: 90,
  );

  if (photo == null) return;

  final podResult =
      await _createPodPhoto(
        File(photo.path),
      );

  _showPreview(podResult);
}

  @override
  Widget build(BuildContext context) {

print("=========== DETAIL ITEM ===========");
print(widget.item);
print("URUTAN ID:");
print(widget.item.urutanId);

print("PAKET ID:");
print(widget.item.paket.id);

print("STATUS:");
print(widget.item.status);

    final paket = widget.item.paket;

    final bool hasPhone = paket.telepon != null &&
        paket.telepon!.trim().isNotEmpty;
    final bool hasLocation =
        paket.latitude != null && paket.longitude != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Delivery Process"),
        backgroundColor: const Color(0xff02A8F4),

        actions: pod == null && !isCheckingPod ? [

          IconButton(

            icon: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.check),

            onPressed: isLoading
                ? null
                : () async {

                    final konfirmasi =
                        await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text(
                          "Konfirmasi",
                        ),
                        content: const Text(
                          "Apakah Anda yakin ingin menyimpan status pengiriman ini?",
                        ),
                        actions: [

                          TextButton(
                            onPressed: () =>
                                Navigator.pop(
                                  context,
                                  false,
                                ),
                            child: const Text(
                              "Batal",
                            ),
                          ),

                          ElevatedButton(
                            onPressed: () =>
                                Navigator.pop(
                                  context,
                                  true,
                                ),
                            child: const Text(
                              "Ya",
                            ),
                          ),
                        ],
                      ),
                    );

                    if (konfirmasi == true) {
                      _submitStatus();
                    }
                  },
          )
        ]
      : null,
      ),

      body: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 0,
        ),

        child: SingleChildScrollView(
          child: Column(
            children: [

              /// HEADER INFO
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [

                    _row(
                      "Nama Penerima",
                      paket.recipientName,
                    ),

                    _row(
                      "Alamat",
                      paket.address,
                    ),

                    _row(
                      "No Kiriman",
                      paket.noKiriman,
                    ),

                    // _row(
                    //   "Layanan",
                    //   "PE (Statik Ini Belum Dinamis)",
                    // ),

                    const SizedBox(height: 12),

                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,

                      children: [

                        const SizedBox(
                          width: 130,
                          child: Text(""),
                        ),

                        const Text(" "),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,

                            children: [

                              Row(
                                children: [

                                  _iconAction(
                                    Icons.call,
                                    Colors.blue,
                                    _callPhone,
                                    isActive: hasPhone,
                                  ),

                                  const SizedBox(
                                    width: 20,
                                  ),

                                  _iconAction(
                                    Icons.chat,
                                    Colors.green,
                                    _openWhatsApp,
                                    isActive: hasPhone,
                                  ),

                                  const SizedBox(
                                    width: 20,
                                  ),

                                  _iconAction(
                                    Icons.location_on,
                                    Colors.blue,
                                    _openMaps,
                                    isActive: hasLocation,
                                  ),
                                ],
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              if (isCheckingPod)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (pod != null)
                _buildPodInfoSection()
              else ...[
                /// DELIVERY INFO
                _sectionTitle(
                  "Delivery Information",
                ),

              _dropdownField(
                title: "Status Pengiriman",

                value: selectedStatus,

                items: const [

                  DropdownMenuItem(
                    value: "delivered",
                    child: Text("Delivered"),
                  ),

                  DropdownMenuItem(
                    value: "returned",
                    child: Text("Returned"),
                  ),
                ],

                onChanged: (val) =>
                    setState(() {
                  selectedStatus = val!;
                }),
              ),

              // _dropdownField(
              //   title: "Penerima",

              //   value: selectedPenerima,

              //   items: const [

              //     DropdownMenuItem(
              //       value:
              //           "DITERIMA YANG BERSANGKUTAN",
              //       child: Text(
              //         "DITERIMA YANG BERSANGKUTAN",
              //       ),
              //     ),

              //     DropdownMenuItem(
              //       value: "DITITIPKAN",
              //       child: Text("DITITIPKAN"),
              //     ),
              //   ],

              //   onChanged: (val) =>
              //       setState(() {
              //     selectedPenerima = val!;
              //   }),
              // ),

              _textField(
                "Nama Penerima",
                namaController,
              ),

              const SizedBox(height: 10),

              /// POD
              _sectionTitle(
                "Proof of Delivery",
              ),
             

             _podItem(
                "Photo",
                Icons.camera_alt,
                _takePhoto,
              ),

            if (podPhoto != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 12,
                    top: 8,
                    bottom: 8,
                  ),
                  child: Stack(
                    children: [

                      GestureDetector(
                        onTap: () {
                          _showPreview(podPhoto!);
                        },
                        child: Container(
                          width: 140,
                          // height: 120,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius:
                                BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.shade300,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(12),
                            child: Image.file(
                              podPhoto!,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),

                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: InkWell(
                            borderRadius:
                                BorderRadius.circular(20),
                            onTap: () {
                              setState(() {
                                podPhoto = null;
                              });
                            },
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ), 

                const SizedBox(height: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// ===== SECTION SAAT POD SUDAH ADA =====

  Widget _buildPodInfoSection() {
    final p = pod!;
    final statusKiriman =
        p.kirimanStatus ?? widget.item.status ?? "delivered";
    final waktu = p.waktuPengantaran != null
        ? DateFormat("dd/MM/yyyy HH:mm").format(
            p.waktuPengantaran!,
          )
        : "-";
    final koordinat = p.koordinat ?? "-";

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          _sectionTitle("Delivery Information"),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row("Status Pengiriman", statusKiriman),
                _row("Waktu Pengantaran", waktu),
                // _row("Nama Penerima", namaPenerima),
                _row("Koordinat", koordinat),
              ],
            ),
          ),

          const SizedBox(height: 10),

          _sectionTitle("Proof of Delivery"),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                _row("Foto Bukti", p.fotoBukti ?? "-"),

                const SizedBox(height: 12),

                if (_apiBaseUrl != null && p.fotoBukti != null)
                  if (_isPhotoChecking)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (_isPhotoAvailable)
                    _podPhotoThumbnail(
                      "$_apiBaseUrl/api/pod/view/${p.fotoBukti}",
                    )
                  else
                    _noPhotoPlaceholder("Foto tidak ditemukan")
                else
                  _noPhotoPlaceholder("Tidak ada foto bukti"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _noPhotoPlaceholder(String message) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _podPhotoThumbnail(String url) {
    return GestureDetector(
      onTap: () => _showPodPhotoPreview(url),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 340),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const SizedBox(
                height: 260,
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
            errorBuilder: (context, error, stack) =>
                _noPhotoPlaceholder("Foto tidak ditemukan"),
          ),
        ),
      ),
    );
  }

  void _showPodPhotoPreview(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text("Preview POD"),
            backgroundColor: const Color(0xff02A8F4),
          ),
          body: SafeArea(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 8,
              child: Center(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stack) =>
                      _noPhotoPlaceholder("Foto tidak ditemukan"),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// WIDGETS

  Widget _row(String title, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 4,
      ),

      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [

          SizedBox(
            width: 130,
            child: Text(title),
          ),

          const Text(": "),

          Expanded(
            child: Text(value ?? "-"),
          )
        ],
      ),
    );
  }

  Widget _iconAction(
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool isActive = true,
  }) {
    final Color iconColor =
        isActive ? color : Colors.grey.shade400;

    return GestureDetector(
      onTap: isActive ? onTap : null,
      child: Icon(
        icon,
        color: iconColor,
        size: 28,
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(12),

      color: Colors.grey.shade200,

      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _dropdownField({
    required String title,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [

          Text(title),

          DropdownButtonFormField<String>(
            value: value,
            items: items,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _textField(
    String title,
    TextEditingController controller,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),

      child: TextField(
        controller: controller,

        decoration: InputDecoration(
          labelText: title,
          border:
              const UnderlineInputBorder(),
        ),
      ),
    );
  }

  Widget _podItem(
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      title: Text(title),

      trailing: Icon(
        icon,
        color: const Color(0xff02A8F4),
      ),

      onTap: onTap,
    );
  }
}
