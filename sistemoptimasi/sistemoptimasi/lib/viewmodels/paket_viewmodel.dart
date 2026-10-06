import 'package:flutter/material.dart';
import '../models/paket_model.dart';
import '../services/paket_service.dart';

class PaketViewModel extends ChangeNotifier {

  final PaketService _service = PaketService();

  List<PaketModel> paketList = [];

  List<String> paketValid = [];

  bool isLoading = true;

  Future<void> loadPaket() async {

    paketList = await _service.getPaket();

    paketValid = paketList
          .map((e) => e.noKiriman)
          .where((e) => e != null && e.isNotEmpty)
          .cast<String>()
          .toList();

    isLoading = false;

    notifyListeners();
  }

}
