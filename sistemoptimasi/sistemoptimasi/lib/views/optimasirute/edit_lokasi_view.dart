import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:sisopt/models/paket_model.dart';
import 'package:sisopt/services/paket_service.dart';

class EditLokasiView extends StatefulWidget {
  final int? urutanId;
  final PaketModel paket;

  const EditLokasiView({
    super.key,
    this.urutanId,
    required this.paket,
  });

  @override
  State<EditLokasiView> createState() => _EditLokasiViewState();
}

class _EditLokasiViewState extends State<EditLokasiView> {
  static const String _googleApiKey = "AIzaSyBqkyOYHvgAZt-mpcn3V_14KoSJJ3Hr4MM";

  late TextEditingController _latController;
  late TextEditingController _lngController;
  late TextEditingController _searchController;
  bool _isSaving = false;
  bool _isSearching = false;

  GoogleMapController? _mapController;
  LatLng? _selectedLatLng;
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _latController = TextEditingController(
      text: widget.paket.latitude?.toString() ?? '',
    );
    _lngController = TextEditingController(
      text: widget.paket.longitude?.toString() ?? '',
    );
    _searchController = TextEditingController(
      text: widget.paket.address ?? '',
    );

    // Set marker awal jika sudah ada koordinat
    final lat = widget.paket.latitude;
    final lng = widget.paket.longitude;
    if (lat != null && lng != null && lat != 0 && lng != 0) {
      _selectedLatLng = LatLng(lat, lng);
      _markers.add(
        Marker(
          markerId: const MarkerId('selected-location'),
          position: LatLng(lat, lng),
          draggable: true,
          onDragEnd: _onMarkerDragEnd,
        ),
      );
    }
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapTapped(LatLng position) {
    setState(() {
      _selectedLatLng = position;
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('selected-location'),
          position: position,
          draggable: true,
          onDragEnd: _onMarkerDragEnd,
        ),
      );
      _latController.text = position.latitude.toStringAsFixed(6);
      _lngController.text = position.longitude.toStringAsFixed(6);
    });
  }

  void _onMarkerDragEnd(LatLng position) {
    setState(() {
      _selectedLatLng = position;
      _latController.text = position.latitude.toStringAsFixed(6);
      _lngController.text = position.longitude.toStringAsFixed(6);
    });
  }

  Future<void> _searchAddress() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(query)}&key=$_googleApiKey',
      );
      final response = await http.get(url);
      final data = jsonDecode(response.body);

      if (data['status'] == 'OK' && data['results'] != null && data['results'].isNotEmpty) {
        final location = data['results'][0]['geometry']['location'];
        final lat = location['lat'];
        final lng = location['lng'];

        final position = LatLng(lat.toDouble(), lng.toDouble());
        _onMapTapped(position);

        // Pindahkan kamera ke lokasi hasil pencarian
        await _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(position, 15),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Alamat tidak ditemukan'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mencari alamat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _centerToCoordinate() {
    final latText = _latController.text.trim();
    final lngText = _lngController.text.trim();
    if (latText.isEmpty || lngText.isEmpty) return;

    final lat = double.tryParse(latText);
    final lng = double.tryParse(lngText);
    if (lat == null || lng == null) return;

    final position = LatLng(lat, lng);
    _onMapTapped(position);
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(position, 15),
    );
  }

  Future<void> _save() async {
    final latText = _latController.text.trim();
    final lngText = _lngController.text.trim();

    if (latText.isEmpty || lngText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Latitude dan Longitude harus diisi')),
      );
      return;
    }

    final lat = double.tryParse(latText);
    final lng = double.tryParse(lngText);

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Format koordinat tidak valid')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final service = PaketService();
      final result = await service.updateLokasiPaket(
        idKiriman: widget.paket.id,
        latitude: lat,
        longitude: lng,
      );

      final message = result['message'] ?? '';

      if (message == 'Lokasi berhasil diperbarui') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lokasi berhasil diperbarui!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  LatLng _getInitialPosition() {
    final lat = widget.paket.latitude;
    final lng = widget.paket.longitude;
    if (lat != null && lng != null && lat != 0 && lng != 0) {
      return LatLng(lat, lng);
    }
    // Default: Jakarta Pusat
    return const LatLng(-6.2088, 106.8456);
  }

  @override
  Widget build(BuildContext context) {
    final paket = widget.paket;
    final mediaQuery = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Edit Lokasi',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        backgroundColor: const Color(0xff004B8D),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          /// ─── MAP AREA ────────────────────────────────────────────────
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _getInitialPosition(),
                    zoom: 14,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  markers: _markers,
                  onTap: _onMapTapped,
                  myLocationEnabled: false,
                  myLocationButtonEnabled: true,
                  mapToolbarEnabled: false,
                  zoomControlsEnabled: false,
                  mapType: MapType.normal,
                  padding: EdgeInsets.only(
                    bottom: mediaQuery.viewInsets.bottom > 0 ? 240 : 0,
                  ),
                ),

                /// Search Bar
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Material(
                    elevation: 6,
                    shadowColor: Colors.black26,
                    borderRadius: BorderRadius.circular(14),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Cari alamat...',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(12),
                          child: _isSearching
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: const Color(0xff004B8D),
                                  ),
                                )
                              : Icon(
                                  Icons.search_rounded,
                                  color: const Color(0xff004B8D).withValues(alpha: 0.7),
                                ),
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _searchAddress(),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),

                /// Hint tap peta
                if (_selectedLatLng == null)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.touch_app,
                              size: 15,
                              color: const Color(0xff004B8D).withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Tap pada peta untuk memilih lokasi',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xff004B8D).withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          /// ─── BOTTOM PANEL ─────────────────────────────────────────────
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x19000000),
                    blurRadius: 12,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// Drag handle
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    /// Info penerima
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xffF0F4F8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xff004B8D).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.person_outline_rounded,
                              color: Color(0xff004B8D),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  paket.recipientName ?? '-',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1A2530),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  paket.address ?? '-',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: const Color(0xff7D8A99).withValues(alpha: 0.9),
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    /// Label koordinat
                    Text(
                      'Koordinat Lokasi',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),

                    /// Input lat + lng + center button
                    Row(
                      children: [
                        Expanded(
                          child: _buildCoordinateField(
                            controller: _latController,
                            label: 'Latitude',
                            hint: '-6.2088',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildCoordinateField(
                            controller: _lngController,
                            label: 'Longitude',
                            hint: '106.8456',
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 48,
                          width: 48,
                          child: Material(
                            color: const Color(0xff004B8D),
                            borderRadius: BorderRadius.circular(12),
                            elevation: 0,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _centerToCoordinate,
                              child: const Center(
                                child: Icon(
                                  Icons.my_location_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    /// ─── TOMBOL SIMPAN (SATU-SATUNYA) ──────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff004B8D),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xff004B8D).withValues(alpha: 0.5),
                          disabledForegroundColor: Colors.white70,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                          shadowColor: const Color(0xff004B8D).withValues(alpha: 0.3),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.save_rounded, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Simpan Koordinat',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoordinateField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xff004B8D),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            ),
            onChanged: (value) {
              final lat = double.tryParse(_latController.text.trim());
              final lng = double.tryParse(_lngController.text.trim());
              if (lat != null && lng != null) {
                final position = LatLng(lat, lng);
                setState(() {
                  _selectedLatLng = position;
                  _markers.clear();
                  _markers.add(
                    Marker(
                      markerId: const MarkerId('selected-location'),
                      position: position,
                      draggable: true,
                      onDragEnd: _onMarkerDragEnd,
                    ),
                  );
                });
                _mapController?.animateCamera(
                  CameraUpdate.newLatLng(position),
                );
              }
            },
          ),
        ),
      ],
    );
  }
}
