import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

class AuthViewModel extends ChangeNotifier {

  final AuthService _authService =
      AuthService();

  final StorageService _storage =
      StorageService();

  bool isLoading = false;

  UserModel? user;

  String? error;

  Future<bool> login(
    String username,
    String password,
  ) async {

    try {

      isLoading = true;
      error = null;

      notifyListeners();

      user = await _authService.login(
        username,
        password,
      );

      await _storage.saveLoginData(

        token: user!.token,

        id: user!.id.toString(),

        name: user!.name,

        role: user!.role,

      );

      isLoading = false;

      notifyListeners();

      return true;

    } catch (e) {

      error = e.toString();

      isLoading = false;

      notifyListeners();

      return false;

    }

  }

  Future<void> loadUserFromStorage() async {

    final data =
        await _storage.getLoginData();

    if (data["token"] != null) {

      user = UserModel(

        id: int.parse(
          data["id"]!,
        ),

        name: data["name"]!,

        role: data["role"]!,

        token: data["token"]!,

      );

      print(
        "LOAD USER: ${user!.name}",
      );

      notifyListeners();

    }

  }

  Future<void> logout() async {

    await _storage.clearLogin();

    user = null;

    notifyListeners();

  }

}
